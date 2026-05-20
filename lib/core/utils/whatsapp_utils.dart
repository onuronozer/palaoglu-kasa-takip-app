import 'package:url_launcher/url_launcher.dart';

import 'money_utils.dart';
import 'report_utils.dart';

class WhatsAppUtils {
  const WhatsAppUtils._();

  static String buildMonthlySummaryText({
    required String monthLabel,
    required FinancialSummary summary,
    required List<EmployeeSalarySummary> employeeSummaries,
  }) {
    final commissionRemaining = summary.businessCommissionOverPaid > 0
        ? 'Fazla ${MoneyUtils.format(summary.businessCommissionOverPaid)}'
        : MoneyUtils.format(summary.businessCommissionDue);
    final buffer = StringBuffer()
      ..writeln('Palaoğlu Kasa Takip')
      ..writeln('$monthLabel Özeti')
      ..writeln()
      ..writeln('Toplam Ciro: ${MoneyUtils.format(summary.monthlyCiro)}')
      ..writeln('Toplam Masraf: ${MoneyUtils.format(summary.monthlyMasraf)}')
      ..writeln(
        'İşçi Ödemeleri: ${MoneyUtils.format(summary.employeePayments)}',
      )
      ..writeln('Bankaya Yatan: ${MoneyUtils.format(summary.bankDeposits)}')
      ..writeln('Kar / Zarar: ${MoneyUtils.format(summary.profitLoss)}')
      ..writeln(
        'İşletme Komisyonu: ${MoneyUtils.format(summary.businessCommission)}',
      )
      ..writeln(
        'Komisyon Ödenen: ${MoneyUtils.format(summary.businessCommissionPayments)}',
      )
      ..writeln('Komisyon Kalan: $commissionRemaining')
      ..writeln('Kasa Nakit: ${MoneyUtils.format(summary.cashOnHand)}')
      ..writeln('Kasadan Ödenen: ${MoneyUtils.format(summary.cashPaidTotal)}')
      ..writeln('Şahsi Ödenen: ${MoneyUtils.format(summary.personalPaidTotal)}')
      ..writeln('Bankadan Ödenen: ${MoneyUtils.format(summary.bankPaidTotal)}')
      ..writeln('Kalan Borç: ${MoneyUtils.format(summary.remainingDebt)}')
      ..writeln()
      ..writeln('İşçi Ödemeleri:');

    for (final employee in employeeSummaries) {
      if (employee.paid == 0 && employee.salary == 0) {
        continue;
      }

      final detail = employee.isOverPaid
          ? 'Fazla ${MoneyUtils.format(employee.overPaid)}'
          : employee.isComplete
          ? 'Tamamlandı'
          : 'Kalan ${MoneyUtils.format(employee.remaining)}';

      buffer.writeln(
        '${employee.name}: ${MoneyUtils.format(employee.paid)} / '
        'Barem ${MoneyUtils.format(employee.salary)} - $detail',
      );
    }

    return buffer.toString().trim();
  }

  static Future<bool> openMonthlySummary({
    required String monthLabel,
    required FinancialSummary summary,
    required List<EmployeeSalarySummary> employeeSummaries,
  }) async {
    final text = buildMonthlySummaryText(
      monthLabel: monthLabel,
      summary: summary,
      employeeSummaries: employeeSummaries,
    );
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    return launchUrl(uri, mode: LaunchMode.platformDefault);
  }
}
