const PALAOGLU_MONTH_NAMES = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

const PALAOGLU_TIME_ZONE = 'Europe/Istanbul';
const PALAOGLU_TRIGGER_HANDLER = 'palaogluEnsureCurrentMonthSheet';

function onOpen() {
  SpreadsheetApp.getUi()
    .createMenu('Palaoğlu')
    .addItem('Bu ayın sayfasını oluştur', 'palaogluCreateCurrentMonthSheet')
    .addItem('Gelecek ayın sayfasını oluştur', 'palaogluCreateNextMonthSheet')
    .addSeparator()
    .addItem('Aylık otomasyonu kur', 'palaogluInstallMonthlyAutomation')
    .addToUi();
}

function palaogluCreateCurrentMonthSheet() {
  const now = new Date();
  const result = palaogluEnsureMonthSheet_(now.getFullYear(), now.getMonth());
  palaogluShowResult_(result);
}

function palaogluCreateNextMonthSheet() {
  const now = new Date();
  const nextMonth = new Date(now.getFullYear(), now.getMonth() + 1, 1);
  const result = palaogluEnsureMonthSheet_(
    nextMonth.getFullYear(),
    nextMonth.getMonth(),
  );
  palaogluShowResult_(result);
}

function palaogluEnsureCurrentMonthSheet() {
  const now = new Date();
  palaogluEnsureMonthSheet_(now.getFullYear(), now.getMonth());
}

function palaogluInstallMonthlyAutomation() {
  ScriptApp.getProjectTriggers()
    .filter(
      (trigger) =>
        trigger.getHandlerFunction() === PALAOGLU_TRIGGER_HANDLER,
    )
    .forEach((trigger) => ScriptApp.deleteTrigger(trigger));

  ScriptApp.newTrigger(PALAOGLU_TRIGGER_HANDLER)
    .timeBased()
    .atHour(1)
    .everyDays(1)
    .inTimezone(PALAOGLU_TIME_ZONE)
    .create();

  palaogluEnsureCurrentMonthSheet();
  SpreadsheetApp.getUi().alert(
    'Aylık otomasyon kuruldu. Yeni ay sayfası her ayın ilk günü otomatik hazırlanacak.',
  );
}

function palaogluEnsureMonthSheet_(year, monthIndex) {
  const spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
  const targetName = `${PALAOGLU_MONTH_NAMES[monthIndex]} ${year}`;
  const existing = spreadsheet.getSheetByName(targetName);
  if (existing) {
    return {created: false, sheetName: targetName};
  }

  const previous = new Date(year, monthIndex - 1, 1);
  const previousName =
    `${PALAOGLU_MONTH_NAMES[previous.getMonth()]} ${previous.getFullYear()}`;
  const source = spreadsheet.getSheetByName(previousName);
  if (!source) {
    throw new Error(
      `${previousName} sayfası bulunamadı. Yeni ay sayfası oluşturulamadı.`,
    );
  }

  const target = source.copyTo(spreadsheet).setName(targetName);
  palaogluResetMonthlyInputs_(target, year, monthIndex);
  spreadsheet.setActiveSheet(target);
  spreadsheet.moveActiveSheet(spreadsheet.getNumSheets());
  SpreadsheetApp.flush();

  return {created: true, sheetName: targetName};
}

function palaogluResetMonthlyInputs_(sheet, year, monthIndex) {
  const rangesToClear = [
    'B2:B50',
    'D2:E18',
    'C20:F33',
    'G10:G19',
    'K2:K6',
    'K10:K18',
    'H21:H26',
    'J21:K28',
  ];
  sheet.getRangeList(rangesToClear).clearContent();

  const lastDay = new Date(year, monthIndex + 1, 0).getDate();
  const dateValues = [];
  for (let day = 1; day <= 31; day += 1) {
    dateValues.push([
      day <= lastDay ? new Date(year, monthIndex, day, 12, 0, 0) : '',
    ]);
  }

  sheet.getRange('A2:A32').setValues(dateValues).setNumberFormat('dd/MM/yyyy');
}

function palaogluShowResult_(result) {
  const message = result.created
    ? `${result.sheetName} sayfası oluşturuldu.`
    : `${result.sheetName} sayfası zaten var.`;
  SpreadsheetApp.getUi().alert(message);
}
