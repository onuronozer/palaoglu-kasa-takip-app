import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/branding/app_assets.dart';
import '../../core/constants/categories.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/money_utils.dart';
import '../../core/utils/report_utils.dart';
import '../../data/models/transaction_model.dart';

Future<Uint8List> buildKiraathaneMonthlyReportPdf({
  required DateTime month,
  required String monthLabel,
  required FinancialSummary summary,
  required List<TransactionModel> transactions,
  required List<EmployeeSalarySummary> employeeSummaries,
  required List<DebtPersonSummary> debts,
  required PdfPageFormat pageFormat,
}) async {
  final logoBytes = await rootBundle.load(AppAssets.palaogluLogo);
  final fonts = await _PdfFonts.load();
  final document = pw.Document(
    theme: pw.ThemeData.withFont(
      base: fonts.regular,
      bold: fonts.bold,
    ),
  );

  final dailyCiro = _dailyTotals(
    transactions.where((item) => item.type == TransactionTypes.ciro),
  );
  final expenseRows = _transactionRows(
    transactions.where((item) => item.type == TransactionTypes.masraf),
  );
  final personalRows = _transactionRows(
    transactions.where(
      (item) =>
          item.usesPaymentSource &&
          item.paymentSource == PaymentSources.personal,
    ),
  );
  final bankRows = _transactionRows(
    transactions.where((item) => item.type == TransactionTypes.banka),
  );
  final creditCardRows = _transactionRows(
    transactions.where(
      (item) =>
          item.usesPaymentSource && item.paymentSource == PaymentSources.bank,
    ),
  );
  final workerRows = _workerRows(transactions, employeeSummaries, summary);
  final debtRows = debts
      .where((item) => item.remaining != 0)
      .map(
        (item) => [
          item.person,
          MoneyUtils.format(item.given),
          MoneyUtils.format(item.paid),
          MoneyUtils.format(item.remaining),
        ],
      )
      .toList();

  document.addPage(
    pw.MultiPage(
      pageFormat: pageFormat,
      margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 28),
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox.shrink()
          : _smallHeader(monthLabel),
      footer: (context) => _footer(context),
      build: (context) => [
        _mainHeader(
          logoBytes: logoBytes.buffer.asUint8List(),
          monthLabel: monthLabel,
        ),
        pw.SizedBox(height: 14),
        _summaryGrid(summary),
        pw.SizedBox(height: 14),
        _sectionTitle('Günlük Ciro Dökümü'),
        _dailyCiroGrid(
          rows: dailyCiro,
          totalValue: MoneyUtils.format(summary.monthlyCiro),
        ),
        pw.SizedBox(height: 12),
        _sectionTitle('Masraf Dökümü'),
        _table(
          headers: const ['Tarih', 'Kalem', 'Ödeme', 'Tutar'],
          rows: expenseRows,
          totalLabel: 'Toplam Masraf',
          totalValue: MoneyUtils.format(summary.monthlyMasraf),
          flexes: const [1, 3, 2, 1],
        ),
        pw.SizedBox(height: 12),
        _twoColumnSections(
          leftTitle: 'Şahsi Hesaptan Ödenenler',
          leftRows: personalRows,
          leftTotal: MoneyUtils.format(summary.personalPaidTotal),
          rightTitle: 'Bankaya Yatanlar',
          rightRows: bankRows,
          rightTotal: MoneyUtils.format(summary.bankDeposits),
        ),
        pw.SizedBox(height: 12),
        _sectionTitle('İşçi ve İşletme Ortağı'),
        _table(
          headers: const ['Ad / Tip', 'Barem', 'Ödenen', 'Kalan'],
          rows: workerRows,
          totalLabel: 'Toplam İşçi ve Ortak Ödemesi',
          totalValue: MoneyUtils.format(
            summary.employeePayments + summary.businessCommissionPayments,
          ),
          flexes: const [3, 1, 1, 1],
        ),
        pw.SizedBox(height: 12),
        _sectionTitle('Kredi Kartı Kalemleri'),
        _table(
          headers: const ['Tarih', 'Kalem', 'Açıklama', 'Tutar'],
          rows: creditCardRows,
          totalLabel: 'Toplam Kredi Kartı',
          totalValue: MoneyUtils.format(summary.bankPaidTotal),
          flexes: const [1, 2, 3, 1],
        ),
        if (debtRows.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          _sectionTitle('Borç / Alacak'),
          _table(
            headers: const ['Kişi', 'Verilen', 'Alınan', 'Kalan'],
            rows: debtRows,
            totalLabel: 'Kalan Borç',
            totalValue: MoneyUtils.format(summary.remainingDebt),
            flexes: const [2, 1, 1, 1],
          ),
        ],
        pw.SizedBox(height: 12),
        _cashControl(summary),
      ],
    ),
  );

  return document.save();
}

class _PdfFonts {
  const _PdfFonts({required this.regular, required this.bold});

  final pw.Font regular;
  final pw.Font bold;

  static Future<_PdfFonts> load() async {
    try {
      return _PdfFonts(
        regular: await PdfGoogleFonts.robotoRegular(),
        bold: await PdfGoogleFonts.robotoBold(),
      );
    } catch (_) {
      return _PdfFonts(
        regular: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      );
    }
  }
}

class _DailyTotal {
  const _DailyTotal({required this.date, required this.amount});

  final String date;
  final double amount;
}

pw.Widget _mainHeader({
  required Uint8List logoBytes,
  required String monthLabel,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 14),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFB7791F), width: 1.2),
      ),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          width: 110,
          height: 78,
          child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
        ),
        pw.SizedBox(width: 18),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'PALAOĞLU KIRAATHANESİ',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: _navy,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Aylık Kasa Raporu',
                style: pw.TextStyle(
                  fontSize: 13,
                  color: _gold,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: pw.BoxDecoration(
                  color: _navy,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  monthLabel,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        pw.Text(
          'Oluşturma: ${_shortDate(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 8, color: _muted),
        ),
      ],
    ),
  );
}

pw.Widget _smallHeader(String monthLabel) {
  return pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 8),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFE5E7EB), width: 0.8),
      ),
    ),
    child: pw.Row(
      children: [
        pw.Text(
          'Palaoğlu Kıraathanesi',
          style: pw.TextStyle(
            fontSize: 9,
            color: _navy,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Spacer(),
        pw.Text(
          '$monthLabel Aylık Kasa Raporu',
          style: const pw.TextStyle(fontSize: 8, color: _muted),
        ),
      ],
    ),
  );
}

pw.Widget _summaryGrid(FinancialSummary summary) {
  final items = [
    _SummaryItem('Toplam Ciro', MoneyUtils.format(summary.monthlyCiro), _green),
    _SummaryItem(
        'Toplam Masraf', MoneyUtils.format(summary.monthlyMasraf), _red),
    _SummaryItem(
        'İşçi Ödemeleri', MoneyUtils.format(summary.employeePayments), _orange),
    _SummaryItem(
        'Bankaya Yatan', MoneyUtils.format(summary.bankDeposits), _blue),
    _SummaryItem('Kasa Nakit', MoneyUtils.format(summary.cashOnHand), _teal),
    _SummaryItem('Kar / Zarar', MoneyUtils.format(summary.profitLoss), _gold),
    _SummaryItem(
        'İşletme Ortağı', MoneyUtils.format(summary.businessCommission), _navy),
    _SummaryItem('Ortağa Ödenen',
        MoneyUtils.format(summary.businessCommissionPayments), _orange),
    _SummaryItem('Ortak Kalan',
        MoneyUtils.format(summary.businessCommissionRemaining), _teal),
  ];

  return pw.Wrap(
    spacing: 7,
    runSpacing: 7,
    children: [
      for (final item in items)
        pw.Container(
          width: 170,
          padding: const pw.EdgeInsets.all(9),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _line),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                item.label,
                style: const pw.TextStyle(fontSize: 8, color: _muted),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                item.value,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: item.color,
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

class _SummaryItem {
  const _SummaryItem(this.label, this.value, this.color);

  final String label;
  final String value;
  final PdfColor color;
}

pw.Widget _sectionTitle(String title) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: pw.BoxDecoration(
      color: _navy,
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Text(
      title,
      style: pw.TextStyle(
        color: PdfColors.white,
        fontWeight: pw.FontWeight.bold,
        fontSize: 10,
      ),
    ),
  );
}

pw.Widget _dailyCiroGrid({
  required List<_DailyTotal> rows,
  required String totalValue,
}) {
  if (rows.isEmpty) {
    return pw.Column(
      children: [
        _tableRow(const ['Kayıt yok', ''], const [2, 1]),
        _tableRow(['Toplam Ciro', totalValue], const [2, 1], total: true),
      ],
    );
  }

  const columnCount = 3;
  final rowGroups = <List<_DailyTotal>>[];
  for (var index = 0; index < rows.length; index += columnCount) {
    rowGroups.add(rows.skip(index).take(columnCount).toList());
  }

  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _line, width: 0.5),
    ),
    child: pw.Column(
      children: [
        for (final group in rowGroups) _dailyCiroGridRow(group, columnCount),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          decoration: const pw.BoxDecoration(color: _lightGold),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  'Toplam Ciro',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: _navy,
                  ),
                ),
              ),
              pw.Text(
                totalValue,
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: _navy,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _dailyCiroGridRow(List<_DailyTotal> group, int columnCount) {
  return pw.Row(
    children: [
      for (var index = 0; index < columnCount; index++)
        pw.Expanded(
          child: _dailyCiroGridCell(
            index < group.length ? group[index] : null,
            showRightBorder: index < columnCount - 1,
          ),
        ),
    ],
  );
}

pw.Widget _dailyCiroGridCell(
  _DailyTotal? item, {
  required bool showRightBorder,
}) {
  return pw.Container(
    height: 20,
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    decoration: pw.BoxDecoration(
      border: pw.Border(
        right: showRightBorder
            ? const pw.BorderSide(color: _line, width: 0.5)
            : pw.BorderSide.none,
        bottom: const pw.BorderSide(color: _line, width: 0.5),
      ),
    ),
    child: item == null
        ? pw.SizedBox.shrink()
        : pw.Row(
            children: [
              pw.Text(
                _dateLabel(item.date),
                style: const pw.TextStyle(fontSize: 7, color: _muted),
              ),
              pw.Spacer(),
              pw.Text(
                MoneyUtils.format(item.amount),
                style: pw.TextStyle(
                  fontSize: 7.4,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
  );
}

pw.Widget _table({
  required List<String> headers,
  required List<List<String>> rows,
  required String totalLabel,
  required String totalValue,
  required List<int> flexes,
}) {
  final visibleRows = rows.isEmpty
      ? [
          List.generate(
              headers.length, (index) => index == 0 ? 'Kayıt yok' : '')
        ]
      : rows;

  return pw.Column(
    children: [
      _tableRow(headers, flexes, header: true),
      for (final row in visibleRows) _tableRow(row, flexes),
      _tableRow(
        [totalLabel, ...List.filled(headers.length - 2, ''), totalValue],
        flexes,
        total: true,
      ),
    ],
  );
}

pw.Widget _tableRow(
  List<String> cells,
  List<int> flexes, {
  bool header = false,
  bool total = false,
}) {
  return pw.Container(
    decoration: pw.BoxDecoration(
      color: header
          ? _lightBlue
          : total
              ? _lightGold
              : PdfColors.white,
      border: const pw.Border(
        left: pw.BorderSide(color: _line, width: 0.5),
        right: pw.BorderSide(color: _line, width: 0.5),
        bottom: pw.BorderSide(color: _line, width: 0.5),
      ),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < flexes.length; index++)
          pw.Expanded(
            flex: flexes[index],
            child: pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              decoration: index == flexes.length - 1
                  ? null
                  : const pw.BoxDecoration(
                      border: pw.Border(
                        right: pw.BorderSide(color: _line, width: 0.5),
                      ),
                    ),
              child: pw.Text(
                index < cells.length ? cells[index] : '',
                textAlign: index == flexes.length - 1
                    ? pw.TextAlign.right
                    : pw.TextAlign.left,
                style: pw.TextStyle(
                  fontSize: header || total ? 7.8 : 7.3,
                  fontWeight: header || total
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                  color: total ? _navy : PdfColors.black,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

pw.Widget _twoColumnSections({
  required String leftTitle,
  required List<List<String>> leftRows,
  required String leftTotal,
  required String rightTitle,
  required List<List<String>> rightRows,
  required String rightTotal,
}) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: pw.Column(
          children: [
            _sectionTitle(leftTitle),
            _table(
              headers: const ['Tarih', 'Kalem', 'Ödeme', 'Tutar'],
              rows: leftRows,
              totalLabel: 'Toplam',
              totalValue: leftTotal,
              flexes: const [1, 2, 2, 1],
            ),
          ],
        ),
      ),
      pw.SizedBox(width: 10),
      pw.Expanded(
        child: pw.Column(
          children: [
            _sectionTitle(rightTitle),
            _table(
              headers: const ['Tarih', 'Açıklama', 'Ödeme', 'Tutar'],
              rows: rightRows,
              totalLabel: 'Toplam',
              totalValue: rightTotal,
              flexes: const [1, 2, 2, 1],
            ),
          ],
        ),
      ),
    ],
  );
}

pw.Widget _cashControl(FinancialSummary summary) {
  final rows = [
    ['Toplam Ciro', MoneyUtils.format(summary.monthlyCiro)],
    ['Kasadan Masraf', '-${MoneyUtils.format(summary.cashPaidMasraf)}'],
    ['Kasadan İşçi', '-${MoneyUtils.format(summary.cashPaidEmployees)}'],
    ['Kasadan Ortağa', '-${MoneyUtils.format(summary.cashPaidCommission)}'],
    ['Bankaya Yatan', '-${MoneyUtils.format(summary.bankDeposits)}'],
    ['Beklenen Kasa Nakit', MoneyUtils.format(summary.cashOnHand)],
  ];

  return pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: _lightBlue,
      borderRadius: pw.BorderRadius.circular(6),
      border: pw.Border.all(color: _line),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Ay Sonu Kasa Kontrolü',
          style: pw.TextStyle(
            color: _navy,
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 7),
        for (final row in rows)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child:
                      pw.Text(row[0], style: const pw.TextStyle(fontSize: 8)),
                ),
                pw.Text(
                  row[1],
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: row[0] == 'Beklenen Kasa Nakit'
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal,
                    color: row[0] == 'Beklenen Kasa Nakit'
                        ? _teal
                        : PdfColors.black,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

pw.Widget _footer(pw.Context context) {
  return pw.Row(
    children: [
      pw.Text(
        'Tüm tutarlar Türk Lirası (TL) cinsindendir.',
        style: const pw.TextStyle(fontSize: 7, color: _muted),
      ),
      pw.Spacer(),
      pw.Text(
        'Sayfa ${context.pageNumber} / ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 7, color: _muted),
      ),
    ],
  );
}

List<_DailyTotal> _dailyTotals(Iterable<TransactionModel> transactions) {
  final totals = <String, double>{};
  for (final transaction in transactions) {
    totals[transaction.date] =
        (totals[transaction.date] ?? 0) + transaction.amount;
  }
  final result = totals.entries
      .map((entry) => _DailyTotal(date: entry.key, amount: entry.value))
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  return result;
}

List<List<String>> _transactionRows(Iterable<TransactionModel> transactions) {
  final items = transactions.toList()
    ..sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) {
        return byDate;
      }
      return a.type.compareTo(b.type);
    });

  return items
      .map(
        (item) => [
          _dateLabel(item.date),
          _subject(item),
          item.usesPaymentSource ? item.paymentSourceLabel : item.typeLabel,
          MoneyUtils.format(item.amount),
        ],
      )
      .toList();
}

List<List<String>> _workerRows(
  List<TransactionModel> transactions,
  List<EmployeeSalarySummary> employeeSummaries,
  FinancialSummary summary,
) {
  final rows = employeeSummaries
      .where((item) => item.paid > 0 || item.salary > 0)
      .map(
        (item) => [
          item.name,
          item.salary > 0 ? MoneyUtils.format(item.salary) : '-',
          MoneyUtils.format(item.paid),
          item.remaining > 0 ? MoneyUtils.format(item.remaining) : item.status,
        ],
      )
      .toList();

  if (summary.businessCommission > 0 ||
      summary.businessCommissionPayments > 0) {
    rows.add([
      'İşletme Ortağı',
      MoneyUtils.format(summary.businessCommission),
      MoneyUtils.format(summary.businessCommissionPayments),
      MoneyUtils.format(summary.businessCommissionRemaining),
    ]);
  }

  return rows;
}

String _subject(TransactionModel item) {
  final parts = [
    if (item.subjectLabel.trim().isNotEmpty) item.subjectLabel.trim(),
    if (item.description.trim().isNotEmpty) item.description.trim(),
  ];
  if (parts.isEmpty) {
    return item.typeLabel;
  }
  return parts.join(' / ');
}

String _dateLabel(String dateKey) {
  final date = AppDateUtils.dateFromKey(dateKey);
  return '${date.day} ${AppDateUtils.monthNames[date.month - 1]}';
}

String _shortDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}

const _navy = PdfColor.fromInt(0xFF0F1E33);
const _gold = PdfColor.fromInt(0xFFB7791F);
const _green = PdfColor.fromInt(0xFF15803D);
const _red = PdfColor.fromInt(0xFFB91C1C);
const _orange = PdfColor.fromInt(0xFFC2410C);
const _blue = PdfColor.fromInt(0xFF1D4ED8);
const _teal = PdfColor.fromInt(0xFF0F766E);
const _muted = PdfColor.fromInt(0xFF64748B);
const _line = PdfColor.fromInt(0xFFD7DEE8);
const _lightBlue = PdfColor.fromInt(0xFFF1F5F9);
const _lightGold = PdfColor.fromInt(0xFFFFF7ED);
