import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/categories.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/farm_worker_utils.dart';
import '../../core/utils/money_utils.dart';
import '../../core/utils/report_utils.dart';
import '../../data/models/farm_expense_model.dart';
import '../../data/models/farm_payment_model.dart';
import '../../data/models/farm_sale_model.dart';
import '../../data/models/farm_worker_model.dart';
import '../../data/models/farm_worker_payment_model.dart';
import '../../data/models/farm_worker_work_model.dart';
import '../../data/models/market_rate_model.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/farm_repository.dart';
import '../../data/repositories/market_rates_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../auth/auth_controller.dart';
import '../dashboard/widgets/metric_card.dart';
import '../farm/widgets/farm_season_selector.dart';

class BusinessOverviewScreen extends ConsumerWidget {
  const BusinessOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(currentAppUserProvider).valueOrNull;
    if (appUser?.isAdmin != true) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Tüm İşletmelerim'),
          leading: IconButton(
            tooltip: 'Geri',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
        ),
        body: const Center(
          child: _StateCard(
            icon: Icons.lock_outline,
            title: 'Yönetici yetkisi gerekli',
            message: 'Giriş yetkisi yok.',
          ),
        ),
      );
    }

    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final monthKey = AppDateUtils.monthKey(currentMonth);
    final recentStart = now.subtract(const Duration(days: 2));
    final recentQuery = DateRangeQuery(
      startDate: AppDateUtils.dateKey(recentStart),
      endDate: AppDateUtils.dateKey(now),
    );

    final monthTransactionsState = ref.watch(
      transactionsByMonthProvider(monthKey),
    );
    final recentTransactionsState = ref.watch(
      transactionsByDateRangeProvider(recentQuery),
    );
    final salesState = ref.watch(farmSalesProvider);
    final paymentsState = ref.watch(farmPaymentsProvider);
    final expensesState = ref.watch(farmExpensesProvider);
    final workersState = ref.watch(farmWorkersProvider);
    final workerWorksState = ref.watch(farmWorkerWorksProvider);
    final workerPaymentsState = ref.watch(farmWorkerPaymentsProvider);
    final marketRatesState = ref.watch(marketRatesProvider);

    final monthTransactions =
        monthTransactionsState.valueOrNull ?? const <TransactionModel>[];
    final recentTransactions =
        recentTransactionsState.valueOrNull ?? const <TransactionModel>[];
    final sales = salesState.valueOrNull ?? const <FarmSaleModel>[];
    final payments = paymentsState.valueOrNull ?? const <FarmPaymentModel>[];
    final expenses = expensesState.valueOrNull ?? const <FarmExpenseModel>[];
    final workers = workersState.valueOrNull ?? const <FarmWorkerModel>[];
    final workerWorks =
        workerWorksState.valueOrNull ?? const <FarmWorkerWorkModel>[];
    final workerPayments =
        workerPaymentsState.valueOrNull ?? const <FarmWorkerPaymentModel>[];

    final loading = monthTransactionsState.isLoading ||
        recentTransactionsState.isLoading ||
        salesState.isLoading ||
        paymentsState.isLoading ||
        expensesState.isLoading ||
        workersState.isLoading ||
        workerWorksState.isLoading ||
        workerPaymentsState.isLoading;

    final summary = ReportUtils.summarize(
      monthTransactions,
      todayKey: AppDateUtils.dateKey(now),
    );
    final threeDayCiro = recentTransactions.fold<double>(
      0,
      (sum, item) =>
          item.type == TransactionTypes.ciro ? sum + item.amount : sum,
    );

    final selectedSeason = ref.watch(selectedFarmSeasonProvider);
    final seasonSales = sales
        .where((sale) => sale.resolvedSeasonYear == selectedSeason)
        .toList();
    final seasonPayments = payments
        .where((payment) => payment.resolvedSeasonYear == selectedSeason)
        .toList();
    final seasonExpenses = expenses
        .where((expense) => expense.resolvedSeasonYear == selectedSeason)
        .toList();
    final seasonWorkerWorks = workerWorks
        .where((work) => work.resolvedSeasonYear == selectedSeason)
        .toList();
    final seasonWorkerPayments = workerPayments
        .where((payment) => payment.resolvedSeasonYear == selectedSeason)
        .toList();
    final workerSummaries = FarmWorkerUtils.summaries(
      workers: workers,
      works: seasonWorkerWorks,
      payments: seasonWorkerPayments,
    );
    final totalFarmSales = seasonSales.fold<double>(
      0,
      (sum, item) => sum + item.totalAmount,
    );
    final totalFarmPayments = seasonPayments.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
    final farmReceivable = totalFarmSales - totalFarmPayments;
    final farmExpenseTotal = seasonExpenses.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
    final farmWorkerEarned = workerSummaries.fold<double>(
      0,
      (sum, item) => sum + item.totalEarned,
    );
    final farmTotalExpense = farmExpenseTotal + farmWorkerEarned;
    final availableSeasons = _availableSeasons(
      sales: sales,
      payments: payments,
      expenses: expenses,
      works: workerWorks,
      workerPayments: workerPayments,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tüm İşletmelerim'),
        leading: IconButton(
          tooltip: 'Geri',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _OverviewHeader(loading: loading),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Palaoğlu Kıraathanesi',
                    subtitle: AppDateUtils.monthLabel(currentMonth),
                    actionLabel: 'Aç',
                    onAction: () => context.go('/kiraathane'),
                    child: _MetricGrid(
                      children: [
                        MetricCard(
                          title: '3 Günlük Ciro',
                          value: MoneyUtils.format(threeDayCiro),
                          icon: Icons.date_range_outlined,
                          color: AppColors.income,
                        ),
                        MetricCard(
                          title: 'Toplam Ciro',
                          value: MoneyUtils.format(summary.monthlyCiro),
                          icon: Icons.trending_up,
                          color: AppColors.income,
                        ),
                        MetricCard(
                          title: 'Kasa Nakit',
                          value: MoneyUtils.format(summary.cashOnHand),
                          icon: Icons.account_balance_wallet_outlined,
                          color: AppColors.turquoise,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Palaoğlu Tarım',
                    subtitle: '$selectedSeason sezonu',
                    actionLabel: 'Aç',
                    onAction: () => context.go('/farm'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FarmSeasonSelector(
                          selectedSeason: selectedSeason,
                          availableSeasons: availableSeasons,
                          onChanged: (season) => ref
                              .read(selectedFarmSeasonProvider.notifier)
                              .state = season,
                        ),
                        const SizedBox(height: 12),
                        _MetricGrid(
                          children: [
                            MetricCard(
                              title: 'Toplam Gelir',
                              value: MoneyUtils.format(totalFarmSales),
                              icon: Icons.trending_up,
                              color: AppColors.income,
                            ),
                            MetricCard(
                              title: 'Toplam Gider',
                              value: MoneyUtils.format(farmTotalExpense),
                              icon: Icons.receipt_long,
                              color: AppColors.expense,
                            ),
                            MetricCard(
                              title: 'Kalan Alacak',
                              value: MoneyUtils.format(farmReceivable),
                              icon: Icons.account_balance_wallet_outlined,
                              color: AppColors.debt,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _MarketRatesPanel(ratesState: marketRatesState),
                  const SizedBox(height: 16),
                  _AdminActionGrid(
                    actions: [
                      _AdminAction(
                        title: 'Duyuru Gönder',
                        icon: Icons.campaign_outlined,
                        color: AppColors.warning,
                        onTap: () => context.push('/admin/announcements'),
                      ),
                      _AdminAction(
                        title: 'Kullanıcı Yönetimi',
                        icon: Icons.manage_accounts_outlined,
                        color: AppColors.bank,
                        onTap: () => context.push('/admin/users'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarketRatesPanel extends StatelessWidget {
  const _MarketRatesPanel({required this.ratesState});

  final AsyncValue<List<MarketRateModel>> ratesState;

  @override
  Widget build(BuildContext context) {
    final rates = ratesState.valueOrNull ?? const <MarketRateModel>[];
    final loading = ratesState.isLoading && rates.isEmpty;
    final hasError = ratesState.hasError && rates.isEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Piyasa',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 520 ? 3 : 1;
              return GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 118,
                ),
                children: [
                  _RateTile(
                    title: 'Gram Altın',
                    icon: Icons.workspace_premium_outlined,
                    color: AppColors.warning,
                    rate: _rateByCode(rates, 'ALTIN'),
                    loading: loading,
                    hasError: hasError,
                  ),
                  _RateTile(
                    title: 'Dolar',
                    icon: Icons.attach_money,
                    color: AppColors.income,
                    rate: _rateByCode(rates, 'USDTRY'),
                    loading: loading,
                    hasError: hasError,
                  ),
                  _RateTile(
                    title: 'Euro',
                    icon: Icons.euro,
                    color: AppColors.bank,
                    rate: _rateByCode(rates, 'EURTRY'),
                    loading: loading,
                    hasError: hasError,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RateTile extends StatelessWidget {
  const _RateTile({
    required this.title,
    required this.icon,
    required this.color,
    required this.rate,
    required this.loading,
    required this.hasError,
  });

  final String title;
  final IconData icon;
  final Color color;
  final MarketRateModel? rate;
  final bool loading;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final value = rate == null
        ? loading
            ? '...'
            : '-'
        : _formatMarketRate(rate!.sell, rate!.code);
    final detail = rate == null
        ? hasError
            ? 'Bağlantı yok'
            : ''
        : 'Alış ${_formatMarketRate(rate!.buy, rate!.code)}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(
                _rateDirectionIcon(rate?.direction),
                size: 17,
                color: _rateDirectionColor(rate?.direction),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader({required this.loading});

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
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.dashboard_customize_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Genel Yönetim',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (loading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final String actionLabel;
  final VoidCallback onAction;

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: AppColors.mutedText),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(actionLabel),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 520;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: children.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: twoColumns ? 3 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 132,
          ),
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
}

class _AdminAction {
  const _AdminAction({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _AdminActionGrid extends StatelessWidget {
  const _AdminActionGrid({required this.actions});

  final List<_AdminAction> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 3 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 92,
          ),
          itemBuilder: (context, index) {
            final action = actions[index];
            return Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              child: InkWell(
                onTap: action.onTap,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: action.color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(action.icon, color: action.color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          action.title,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: action.color),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 34),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.mutedText),
          ),
        ],
      ),
    );
  }
}

MarketRateModel? _rateByCode(List<MarketRateModel> rates, String code) {
  for (final rate in rates) {
    if (rate.code == code) {
      return rate;
    }
  }
  return null;
}

String _formatMarketRate(double value, String code) {
  final fractionDigits = code == 'ALTIN' ? 2 : 4;
  final formatter = NumberFormat.decimalPattern('tr_TR')
    ..minimumFractionDigits = fractionDigits
    ..maximumFractionDigits = fractionDigits;
  return '${formatter.format(value)} TL';
}

IconData _rateDirectionIcon(String? direction) {
  switch (direction) {
    case 'up':
      return Icons.trending_up;
    case 'down':
      return Icons.trending_down;
    default:
      return Icons.remove;
  }
}

Color _rateDirectionColor(String? direction) {
  switch (direction) {
    case 'up':
      return AppColors.income;
    case 'down':
      return AppColors.expense;
    default:
      return AppColors.mutedText;
  }
}

List<int> _availableSeasons({
  required List<FarmSaleModel> sales,
  required List<FarmPaymentModel> payments,
  required List<FarmExpenseModel> expenses,
  required List<FarmWorkerWorkModel> works,
  required List<FarmWorkerPaymentModel> workerPayments,
}) {
  final years = <int>{DateTime.now().year};
  years.addAll(sales.map((sale) => sale.resolvedSeasonYear));
  years.addAll(payments.map((payment) => payment.resolvedSeasonYear));
  years.addAll(expenses.map((expense) => expense.resolvedSeasonYear));
  years.addAll(works.map((work) => work.resolvedSeasonYear));
  years.addAll(workerPayments.map((payment) => payment.resolvedSeasonYear));
  final result = years.where((year) => year > 0).toList()..sort();
  return result.reversed.toList();
}
