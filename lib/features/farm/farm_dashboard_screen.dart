import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/farm_worker_utils.dart';
import '../../core/utils/money_utils.dart';
import '../../data/models/farm_expense_model.dart';
import '../../data/models/farm_payment_model.dart';
import '../../data/models/farm_sale_model.dart';
import '../../data/models/farm_worker_model.dart';
import '../../data/models/farm_worker_payment_model.dart';
import '../../data/models/farm_worker_work_model.dart';
import '../../data/models/merchant_model.dart';
import '../../data/repositories/farm_repository.dart';
import '../dashboard/widgets/action_card.dart';
import '../dashboard/widgets/metric_card.dart';

class FarmDashboardScreen extends ConsumerWidget {
  const FarmDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merchantsState = ref.watch(merchantsProvider);
    final salesState = ref.watch(farmSalesProvider);
    final paymentsState = ref.watch(farmPaymentsProvider);
    final expensesState = ref.watch(farmExpensesProvider);
    final workersState = ref.watch(farmWorkersProvider);
    final workerWorksState = ref.watch(farmWorkerWorksProvider);
    final workerPaymentsState = ref.watch(farmWorkerPaymentsProvider);

    final merchants = merchantsState.valueOrNull ?? const <MerchantModel>[];
    final sales = salesState.valueOrNull ?? const <FarmSaleModel>[];
    final payments = paymentsState.valueOrNull ?? const <FarmPaymentModel>[];
    final expenses = expensesState.valueOrNull ?? const <FarmExpenseModel>[];
    final workers = workersState.valueOrNull ?? const <FarmWorkerModel>[];
    final workerWorks =
        workerWorksState.valueOrNull ?? const <FarmWorkerWorkModel>[];
    final workerPayments =
        workerPaymentsState.valueOrNull ?? const <FarmWorkerPaymentModel>[];
    final loading =
        merchantsState.isLoading && merchantsState.valueOrNull == null ||
        salesState.isLoading && salesState.valueOrNull == null ||
        paymentsState.isLoading && paymentsState.valueOrNull == null ||
        expensesState.isLoading && expensesState.valueOrNull == null ||
        workersState.isLoading && workersState.valueOrNull == null ||
        workerWorksState.isLoading && workerWorksState.valueOrNull == null ||
        workerPaymentsState.isLoading &&
            workerPaymentsState.valueOrNull == null;
    final hasError =
        merchantsState.hasError ||
        salesState.hasError ||
        paymentsState.hasError ||
        expensesState.hasError ||
        workersState.hasError ||
        workerWorksState.hasError ||
        workerPaymentsState.hasError;

    final totalSales = sales.fold<double>(
      0,
      (sum, item) => sum + item.totalAmount,
    );
    final totalPayments = payments.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
    final totalReceivable = merchants.fold<double>(
      0,
      (sum, item) => sum + item.currentBalance,
    );
    final totalExpenses = expenses.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
    final workerSummaries = FarmWorkerUtils.summaries(
      workers: workers,
      works: workerWorks,
      payments: workerPayments,
    );
    final totalWorkerEarned = workerSummaries.fold<double>(
      0,
      (sum, item) => sum + item.totalEarned,
    );
    final totalWorkerRemaining = workerSummaries.fold<double>(
      0,
      (sum, item) => sum + (item.remaining > 0 ? item.remaining : 0),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Palaoğlu Tarım'),
        leading: IconButton(
          tooltip: 'İşletmeler',
          icon: const Icon(Icons.apps_outlined),
          onPressed: () => context.go('/'),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/kiraathane'),
            icon: const Icon(Icons.storefront_outlined, size: 18),
            label: const Text('Kıraathane'),
          ),
          const SizedBox(width: 8),
        ],
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
                  _HeaderCard(loading: loading, hasError: hasError),
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
                        title: 'Toplam Satış',
                        value: MoneyUtils.format(totalSales),
                        icon: Icons.trending_up,
                        color: AppColors.income,
                      ),
                      MetricCard(
                        title: 'Tahsil Edilen',
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
                        title: 'Bahçe Gideri',
                        value: MoneyUtils.format(totalExpenses),
                        icon: Icons.receipt_long,
                        color: AppColors.expense,
                      ),
                      MetricCard(
                        title: 'İşçi Hakediş',
                        value: MoneyUtils.format(totalWorkerEarned),
                        icon: Icons.engineering_outlined,
                        color: AppColors.expense,
                      ),
                      MetricCard(
                        title: 'İşçi Alacağı',
                        value: MoneyUtils.format(totalWorkerRemaining),
                        icon: Icons.account_balance_outlined,
                        color: totalWorkerRemaining >= 0
                            ? AppColors.debt
                            : AppColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _ActionGrid(),
                  const SizedBox(height: 16),
                  _MerchantBalanceCard(merchants: merchants),
                  const SizedBox(height: 16),
                  _WorkerBalanceCard(summaries: workerSummaries),
                  const SizedBox(height: 16),
                  _RecentSalesCard(sales: sales, merchants: merchants),
                  const SizedBox(height: 16),
                  _RecentExpensesCard(expenses: expenses),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.loading, required this.hasError});

  final bool loading;
  final bool hasError;

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
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.turquoise.withOpacity(0.14),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.agriculture_outlined,
              color: AppColors.turquoise,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tarım Takip',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  hasError
                      ? 'Bazı veriler okunamadı.'
                      : loading
                      ? 'Veriler yükleniyor...'
                      : 'Satış, tahsilat, tüccar, işçi ve bahçe giderleri.',
                  style: const TextStyle(color: AppColors.mutedText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 82,
      ),
      children: [
        ActionCard(
          title: 'Tüccarlar',
          icon: Icons.groups_outlined,
          color: AppColors.turquoise,
          onTap: () => context.push('/farm/merchants'),
        ),
        ActionCard(
          title: 'Satış Gir',
          icon: Icons.add_chart,
          color: AppColors.income,
          onTap: () => context.push('/farm/sale'),
        ),
        ActionCard(
          title: 'Toplu Giriş',
          icon: Icons.playlist_add,
          color: AppColors.turquoise,
          onTap: () => context.push('/farm/bulk-entry'),
        ),
        ActionCard(
          title: 'Tahsilat Gir',
          icon: Icons.payments_outlined,
          color: AppColors.primary,
          onTap: () => context.push('/farm/payment'),
        ),
        ActionCard(
          title: 'Gider Gir',
          icon: Icons.receipt_long,
          color: AppColors.expense,
          onTap: () => context.push('/farm/expense'),
        ),
        ActionCard(
          title: 'İşçiler',
          icon: Icons.engineering_outlined,
          color: AppColors.turquoise,
          onTap: () => context.push('/farm/workers'),
        ),
        ActionCard(
          title: 'Kayısı Cinsleri',
          icon: Icons.spa_outlined,
          color: AppColors.income,
          onTap: () => context.push('/farm/varieties'),
        ),
        ActionCard(
          title: 'Tarım Raporu',
          icon: Icons.insert_chart_outlined,
          color: AppColors.debt,
          onTap: () => context.push('/farm/report'),
        ),
      ],
    );
  }
}

class _MerchantBalanceCard extends StatelessWidget {
  const _MerchantBalanceCard({required this.merchants});

  final List<MerchantModel> merchants;

  @override
  Widget build(BuildContext context) {
    return _FarmCard(
      title: 'Tüccar Cari Hesap',
      child: merchants.isEmpty
          ? const _EmptyText('Henüz tüccar yok.')
          : Column(
              children: [
                for (final merchant in merchants)
                  _InfoLine(
                    title: merchant.fullName,
                    subtitle: merchant.phone.isEmpty
                        ? 'Telefon yok'
                        : merchant.phone,
                    amount: MoneyUtils.format(merchant.currentBalance),
                    color: merchant.currentBalance >= 0
                        ? AppColors.debt
                        : AppColors.primary,
                  ),
              ],
            ),
    );
  }
}

class _WorkerBalanceCard extends StatelessWidget {
  const _WorkerBalanceCard({required this.summaries});

  final List<FarmWorkerSummary> summaries;

  @override
  Widget build(BuildContext context) {
    final shown = summaries.take(5).toList();
    return _FarmCard(
      title: 'İşçi Hakedişleri',
      child: shown.isEmpty
          ? const _EmptyText('Henüz işçi kaydı yok.')
          : Column(
              children: [
                for (final summary in shown)
                  _InfoLine(
                    title: summary.name,
                    subtitle:
                        '${_formatDays(summary.totalDays)} gün • Ödenen ${MoneyUtils.format(summary.totalPaid)}',
                    amount: summary.remaining >= 0
                        ? MoneyUtils.format(summary.remaining)
                        : 'Fazla ${MoneyUtils.format(summary.overPaid)}',
                    color: summary.remaining >= 0
                        ? AppColors.debt
                        : AppColors.primary,
                  ),
              ],
            ),
    );
  }
}

class _RecentSalesCard extends StatelessWidget {
  const _RecentSalesCard({required this.sales, required this.merchants});

  final List<FarmSaleModel> sales;
  final List<MerchantModel> merchants;

  @override
  Widget build(BuildContext context) {
    final merchantNames = {
      for (final merchant in merchants) merchant.id: merchant.fullName,
    };
    final recent = sales.take(5).toList();

    return _FarmCard(
      title: 'Son Satışlar',
      child: recent.isEmpty
          ? const _EmptyText('Henüz satış yok.')
          : Column(
              children: [
                for (final sale in recent)
                  _InfoLine(
                    title: sale.productLabel,
                    subtitle:
                        '${sale.date} • ${merchantNames[sale.merchantId] ?? 'Tüccar'} • ${sale.amountKg.toStringAsFixed(0)} kg',
                    amount: MoneyUtils.format(sale.totalAmount),
                    color: AppColors.income,
                  ),
              ],
            ),
    );
  }
}

class _RecentExpensesCard extends StatelessWidget {
  const _RecentExpensesCard({required this.expenses});

  final List<FarmExpenseModel> expenses;

  @override
  Widget build(BuildContext context) {
    final recent = expenses.take(5).toList();
    return _FarmCard(
      title: 'Son Giderler',
      child: recent.isEmpty
          ? const _EmptyText('Henüz gider yok.')
          : Column(
              children: [
                for (final expense in recent)
                  _InfoLine(
                    title: expense.category,
                    subtitle: expense.description.trim().isEmpty
                        ? expense.date
                        : '${expense.date} • ${expense.description}',
                    amount: MoneyUtils.format(expense.amount),
                    color: AppColors.expense,
                  ),
              ],
            ),
    );
  }
}

class _FarmCard extends StatelessWidget {
  const _FarmCard({required this.title, required this.child});

  final String title;
  final Widget child;

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
          child,
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.color,
  });

  final String title;
  final String subtitle;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            amount,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: AppColors.mutedText));
  }
}

String _formatDays(double value) {
  if (value % 1 == 0) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}
