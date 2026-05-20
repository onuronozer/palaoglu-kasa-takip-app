import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/money_utils.dart';
import '../../data/models/farm_expense_model.dart';
import '../../data/models/farm_payment_model.dart';
import '../../data/models/farm_sale_model.dart';
import '../../data/models/merchant_model.dart';
import '../../data/repositories/farm_repository.dart';
import '../dashboard/widgets/metric_card.dart';

class FarmReportScreen extends ConsumerWidget {
  const FarmReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merchantsState = ref.watch(merchantsProvider);
    final salesState = ref.watch(farmSalesProvider);
    final paymentsState = ref.watch(farmPaymentsProvider);
    final expensesState = ref.watch(farmExpensesProvider);

    final merchants = merchantsState.valueOrNull ?? const <MerchantModel>[];
    final sales = salesState.valueOrNull ?? const <FarmSaleModel>[];
    final payments = paymentsState.valueOrNull ?? const <FarmPaymentModel>[];
    final expenses = expensesState.valueOrNull ?? const <FarmExpenseModel>[];
    final loading =
        merchantsState.isLoading && merchantsState.valueOrNull == null ||
        salesState.isLoading && salesState.valueOrNull == null ||
        paymentsState.isLoading && paymentsState.valueOrNull == null ||
        expensesState.isLoading && expensesState.valueOrNull == null;

    final totalSales = sales.fold<double>(
      0,
      (sum, item) => sum + item.totalAmount,
    );
    final totalPayments = payments.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
    final totalExpenses = expenses.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
    final totalReceivable = merchants.fold<double>(
      0,
      (sum, item) => sum + item.currentBalance,
    );
    final net = totalSales - totalExpenses;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tarım Raporu'),
        leading: IconButton(
          tooltip: 'Geri',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ReportHeader(loading: loading),
                  const SizedBox(height: 16),
                  GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 132,
                        ),
                    children: [
                      MetricCard(
                        title: 'Satış Cirosu',
                        value: MoneyUtils.format(totalSales),
                        icon: Icons.trending_up,
                        color: AppColors.income,
                      ),
                      MetricCard(
                        title: 'Tahsilat',
                        value: MoneyUtils.format(totalPayments),
                        icon: Icons.payments_outlined,
                        color: AppColors.primary,
                      ),
                      MetricCard(
                        title: 'Kalan Alacak',
                        value: MoneyUtils.format(totalReceivable),
                        icon: Icons.account_balance_wallet_outlined,
                        color: AppColors.debt,
                      ),
                      MetricCard(
                        title: 'Net',
                        value: MoneyUtils.format(net),
                        icon: Icons.analytics_outlined,
                        color: net >= 0
                            ? AppColors.turquoise
                            : AppColors.expense,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _BreakdownCard(
                    title: 'Ürün Satışları',
                    emptyText: 'Henüz satış yok.',
                    lines: _productLines(sales),
                    total: totalSales,
                    color: AppColors.income,
                  ),
                  const SizedBox(height: 16),
                  _BreakdownCard(
                    title: 'Gider Kategorileri',
                    emptyText: 'Henüz gider yok.',
                    lines: _expenseLines(expenses),
                    total: totalExpenses,
                    color: AppColors.expense,
                  ),
                  const SizedBox(height: 16),
                  _MerchantReportCard(merchants: merchants),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<_BreakdownLineData> _productLines(List<FarmSaleModel> sales) {
    final totals = <String, double>{};
    for (final sale in sales) {
      totals[sale.productLabel] =
          (totals[sale.productLabel] ?? 0) + sale.totalAmount;
    }
    final lines = totals.entries
        .map((entry) => _BreakdownLineData(entry.key, entry.value))
        .toList();
    lines.sort((a, b) => b.amount.compareTo(a.amount));
    return lines;
  }

  List<_BreakdownLineData> _expenseLines(List<FarmExpenseModel> expenses) {
    final totals = <String, double>{};
    for (final expense in expenses) {
      totals[expense.category] =
          (totals[expense.category] ?? 0) + expense.amount;
    }
    final lines = totals.entries
        .map((entry) => _BreakdownLineData(entry.key, entry.value))
        .toList();
    lines.sort((a, b) => b.amount.compareTo(a.amount));
    return lines;
  }
}

class _ReportHeader extends StatelessWidget {
  const _ReportHeader({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.insert_chart_outlined, color: AppColors.turquoise),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              loading
                  ? 'Tarım raporu hazırlanıyor...'
                  : 'Satış, tahsilat, gider ve tüccar cari özeti.',
              style: const TextStyle(color: AppColors.mutedText),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({
    required this.title,
    required this.emptyText,
    required this.lines,
    required this.total,
    required this.color,
  });

  final String title;
  final String emptyText;
  final List<_BreakdownLineData> lines;
  final double total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (lines.isEmpty)
            Text(emptyText, style: const TextStyle(color: AppColors.mutedText))
          else
            for (final line in lines)
              _BreakdownLine(line: line, total: total, color: color),
        ],
      ),
    );
  }
}

class _BreakdownLine extends StatelessWidget {
  const _BreakdownLine({
    required this.line,
    required this.total,
    required this.color,
  });

  final _BreakdownLineData line;
  final double total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = total <= 0
        ? 0.0
        : (line.amount / total).clamp(0, 1).toDouble();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  line.label,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                MoneyUtils.format(line.amount),
                style: TextStyle(color: color, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress,
              backgroundColor: AppColors.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _MerchantReportCard extends StatelessWidget {
  const _MerchantReportCard({required this.merchants});

  final List<MerchantModel> merchants;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tüccar Cari', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (merchants.isEmpty)
            const Text(
              'Henüz tüccar yok.',
              style: TextStyle(color: AppColors.mutedText),
            )
          else
            for (final merchant in merchants)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        merchant.fullName,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      MoneyUtils.format(merchant.currentBalance),
                      style: const TextStyle(
                        color: AppColors.debt,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _BreakdownLineData {
  const _BreakdownLineData(this.label, this.amount);

  final String label;
  final double amount;
}
