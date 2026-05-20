import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_utils.dart';
import '../../../core/utils/report_utils.dart';
import '../../dashboard/widgets/metric_card.dart';

class ReportSummaryCards extends StatelessWidget {
  const ReportSummaryCards({required this.summary, super.key});

  final FinancialSummary summary;

  @override
  Widget build(BuildContext context) {
    final commissionRemaining = summary.businessCommissionOverPaid > 0
        ? 'Fazla ${MoneyUtils.format(summary.businessCommissionOverPaid)}'
        : MoneyUtils.format(summary.businessCommissionDue);
    final cards = [
      MetricCard(
        title: 'Toplam Ciro',
        value: MoneyUtils.format(summary.monthlyCiro),
        icon: Icons.trending_up,
        color: AppColors.income,
      ),
      MetricCard(
        title: 'Toplam Masraf',
        value: MoneyUtils.format(summary.monthlyMasraf),
        icon: Icons.receipt_long,
        color: AppColors.expense,
      ),
      MetricCard(
        title: 'İşçi Ödemeleri',
        value: MoneyUtils.format(summary.employeePayments),
        icon: Icons.badge_outlined,
        color: AppColors.warning,
      ),
      MetricCard(
        title: 'Bankaya Yatan',
        value: MoneyUtils.format(summary.bankDeposits),
        icon: Icons.account_balance,
        color: AppColors.bank,
      ),
      MetricCard(
        title: 'Kar / Zarar',
        value: MoneyUtils.format(summary.profitLoss),
        icon: Icons.analytics_outlined,
        color: summary.profitLoss >= 0 ? AppColors.primary : AppColors.expense,
      ),
      MetricCard(
        title: 'İşletme Ortağı',
        value: MoneyUtils.format(summary.businessCommission),
        icon: Icons.percent_outlined,
        color: AppColors.primary,
      ),
      MetricCard(
        title: 'Ortağa Ödenen',
        value: MoneyUtils.format(summary.businessCommissionPayments),
        icon: Icons.payments_outlined,
        color: AppColors.warning,
      ),
      MetricCard(
        title: 'Ortak Kalan',
        value: commissionRemaining,
        icon: Icons.assignment_turned_in_outlined,
        color: summary.businessCommissionOverPaid > 0
            ? AppColors.warning
            : AppColors.turquoise,
      ),
      MetricCard(
        title: 'Kasa Nakit',
        value: MoneyUtils.format(summary.cashOnHand),
        icon: Icons.account_balance_wallet_outlined,
        color: AppColors.turquoise,
      ),
      MetricCard(
        title: 'Kasadan Ödenen',
        value: MoneyUtils.format(summary.cashPaidTotal),
        icon: Icons.point_of_sale_outlined,
        color: AppColors.primary,
      ),
      MetricCard(
        title: 'Şahsi Ödenen',
        value: MoneyUtils.format(summary.personalPaidTotal),
        icon: Icons.person_outline,
        color: AppColors.warning,
      ),
      MetricCard(
        title: 'Bankadan Ödenen',
        value: MoneyUtils.format(summary.bankPaidTotal),
        icon: Icons.account_balance_outlined,
        color: AppColors.bank,
      ),
      MetricCard(
        title: 'Kalan Borç',
        value: MoneyUtils.format(summary.remainingDebt),
        icon: Icons.handshake_outlined,
        color: AppColors.debt,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 132,
      ),
      itemBuilder: (context, index) => cards[index],
    );
  }
}
