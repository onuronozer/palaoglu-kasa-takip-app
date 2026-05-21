import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/farm_worker_utils.dart';
import '../../core/utils/money_utils.dart';
import '../../data/models/farm_expense_model.dart';
import '../../data/models/farm_field_model.dart';
import '../../data/models/farm_payment_model.dart';
import '../../data/models/farm_sale_model.dart';
import '../../data/models/farm_worker_model.dart';
import '../../data/models/farm_worker_payment_model.dart';
import '../../data/models/farm_worker_work_model.dart';
import '../../data/models/merchant_model.dart';
import '../../data/repositories/farm_repository.dart';
import '../dashboard/widgets/metric_card.dart';
import 'widgets/farm_season_selector.dart';

class FarmReportScreen extends ConsumerWidget {
  const FarmReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merchantsState = ref.watch(merchantsProvider);
    final salesState = ref.watch(farmSalesProvider);
    final paymentsState = ref.watch(farmPaymentsProvider);
    final expensesState = ref.watch(farmExpensesProvider);
    final fieldsState = ref.watch(farmFieldsProvider);
    final workersState = ref.watch(farmWorkersProvider);
    final workerWorksState = ref.watch(farmWorkerWorksProvider);
    final workerPaymentsState = ref.watch(farmWorkerPaymentsProvider);

    final merchants = merchantsState.valueOrNull ?? const <MerchantModel>[];
    final sales = salesState.valueOrNull ?? const <FarmSaleModel>[];
    final payments = paymentsState.valueOrNull ?? const <FarmPaymentModel>[];
    final expenses = expensesState.valueOrNull ?? const <FarmExpenseModel>[];
    final fields = fieldsState.valueOrNull ?? const <FarmFieldModel>[];
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
        fieldsState.isLoading && fieldsState.valueOrNull == null ||
        workersState.isLoading && workersState.valueOrNull == null ||
        workerWorksState.isLoading && workerWorksState.valueOrNull == null ||
        workerPaymentsState.isLoading &&
            workerPaymentsState.valueOrNull == null;

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
    final merchantBalances = _merchantBalances(
      sales: seasonSales,
      payments: seasonPayments,
    );
    final availableSeasons = _availableSeasons(
      sales: sales,
      payments: payments,
      expenses: expenses,
      works: workerWorks,
      workerPayments: workerPayments,
    );

    final totalSales = seasonSales.fold<double>(
      0,
      (sum, item) => sum + item.totalAmount,
    );
    final totalPayments = seasonPayments.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
    final totalExpenses = seasonExpenses.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
    final totalReceivable = merchantBalances.values.fold<double>(
      0,
      (sum, item) => sum + item,
    );
    final workerSummaries = FarmWorkerUtils.summaries(
      workers: workers,
      works: seasonWorkerWorks,
      payments: seasonWorkerPayments,
    );
    final totalWorkerEarned = workerSummaries.fold<double>(
      0,
      (sum, item) => sum + item.totalEarned,
    );
    final totalWorkerPaid = workerSummaries.fold<double>(
      0,
      (sum, item) => sum + item.totalPaid,
    );
    final totalWorkerRemaining = workerSummaries.fold<double>(
      0,
      (sum, item) => sum + (item.remaining > 0 ? item.remaining : 0),
    );
    final net = totalSales - totalExpenses - totalWorkerEarned;

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
                  FarmSeasonSelector(
                    selectedSeason: selectedSeason,
                    availableSeasons: availableSeasons,
                    onChanged: (season) =>
                        ref.read(selectedFarmSeasonProvider.notifier).state =
                            season,
                  ),
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
                      MetricCard(
                        title: 'İşçi Hakediş',
                        value: MoneyUtils.format(totalWorkerEarned),
                        icon: Icons.engineering_outlined,
                        color: AppColors.expense,
                      ),
                      MetricCard(
                        title: 'İşçi Ödenen',
                        value: MoneyUtils.format(totalWorkerPaid),
                        icon: Icons.payments_outlined,
                        color: AppColors.primary,
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
                  _BreakdownCard(
                    title: 'Ürün Satışları',
                    emptyText: 'Henüz satış yok.',
                    lines: _productLines(seasonSales),
                    total: totalSales,
                    color: AppColors.income,
                  ),
                  const SizedBox(height: 16),
                  _BreakdownCard(
                    title: 'Gider Kategorileri',
                    emptyText: 'Henüz gider yok.',
                    lines: _expenseLines(seasonExpenses),
                    total: totalExpenses,
                    color: AppColors.expense,
                  ),
                  const SizedBox(height: 16),
                  _FieldReportCard(
                    fields: fields,
                    sales: seasonSales,
                    expenses: seasonExpenses,
                    works: seasonWorkerWorks,
                  ),
                  const SizedBox(height: 16),
                  _WorkerReportCard(summaries: workerSummaries),
                  const SizedBox(height: 16),
                  _MerchantReportCard(
                    merchants: merchants,
                    balances: merchantBalances,
                  ),
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

class _FieldReportCard extends StatelessWidget {
  const _FieldReportCard({
    required this.fields,
    required this.sales,
    required this.expenses,
    required this.works,
  });

  final List<FarmFieldModel> fields;
  final List<FarmSaleModel> sales;
  final List<FarmExpenseModel> expenses;
  final List<FarmWorkerWorkModel> works;

  @override
  Widget build(BuildContext context) {
    final lines = _fieldLines(
      fields: fields,
      sales: sales,
      expenses: expenses,
      works: works,
    );

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
          Text('Tarla Analizi', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (lines.isEmpty)
            const Text(
              'Bu sezonda tarla bağlantılı kayıt yok.',
              style: TextStyle(color: AppColors.mutedText),
            )
          else
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            line.name,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          MoneyUtils.format(line.net),
                          style: TextStyle(
                            color: line.net >= 0
                                ? AppColors.income
                                : AppColors.expense,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatDays(line.workerDays)} işçi günü • ${line.soldKg.toStringAsFixed(0)} kg • Satış ${MoneyUtils.format(line.salesAmount)} • Gider ${MoneyUtils.format(line.expenseAmount)}',
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                    if (line.treeCount > 0) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Ağaç başı gelir ${MoneyUtils.format(line.salesAmount / line.treeCount)}',
                        style: const TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _WorkerReportCard extends StatelessWidget {
  const _WorkerReportCard({required this.summaries});

  final List<FarmWorkerSummary> summaries;

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
          Text(
            'İşçi Hakedişleri',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (summaries.isEmpty)
            const Text(
              'Henüz işçi kaydı yok.',
              style: TextStyle(color: AppColors.mutedText),
            )
          else
            for (final summary in summaries)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            summary.name,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          summary.remaining >= 0
                              ? MoneyUtils.format(summary.remaining)
                              : 'Fazla ${MoneyUtils.format(summary.overPaid)}',
                          style: TextStyle(
                            color: summary.remaining >= 0
                                ? AppColors.debt
                                : AppColors.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatDays(summary.totalDays)} gün • Hakediş ${MoneyUtils.format(summary.totalEarned)} • Ödenen ${MoneyUtils.format(summary.totalPaid)}',
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 12,
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

class _MerchantReportCard extends StatelessWidget {
  const _MerchantReportCard({required this.merchants, required this.balances});

  final List<MerchantModel> merchants;
  final Map<String, double> balances;

  @override
  Widget build(BuildContext context) {
    final shown = merchants
        .where((merchant) => (balances[merchant.id] ?? 0) != 0)
        .toList();
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
          if (shown.isEmpty)
            const Text(
              'Bu sezonda tüccar hareketi yok.',
              style: TextStyle(color: AppColors.mutedText),
            )
          else
            for (final merchant in shown)
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
                      MoneyUtils.format(balances[merchant.id] ?? 0),
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

String _formatDays(double value) {
  if (value % 1 == 0) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}

Set<int> _availableSeasons({
  required List<FarmSaleModel> sales,
  required List<FarmPaymentModel> payments,
  required List<FarmExpenseModel> expenses,
  required List<FarmWorkerWorkModel> works,
  required List<FarmWorkerPaymentModel> workerPayments,
}) {
  return {
    DateTime.now().year,
    for (final sale in sales) sale.resolvedSeasonYear,
    for (final payment in payments) payment.resolvedSeasonYear,
    for (final expense in expenses) expense.resolvedSeasonYear,
    for (final work in works) work.resolvedSeasonYear,
    for (final payment in workerPayments) payment.resolvedSeasonYear,
  };
}

Map<String, double> _merchantBalances({
  required List<FarmSaleModel> sales,
  required List<FarmPaymentModel> payments,
}) {
  final balances = <String, double>{};
  for (final sale in sales) {
    balances[sale.merchantId] =
        (balances[sale.merchantId] ?? 0) + sale.totalAmount;
  }
  for (final payment in payments) {
    balances[payment.merchantId] =
        (balances[payment.merchantId] ?? 0) - payment.amount;
  }
  return balances;
}

List<_FieldReportLine> _fieldLines({
  required List<FarmFieldModel> fields,
  required List<FarmSaleModel> sales,
  required List<FarmExpenseModel> expenses,
  required List<FarmWorkerWorkModel> works,
}) {
  final fieldById = {for (final field in fields) field.id: field};
  final salesByField = <String, double>{};
  final kgByField = <String, double>{};
  final expenseByField = <String, double>{};
  final daysByField = <String, double>{};
  final laborByField = <String, double>{};

  for (final sale in sales) {
    if (sale.fieldId.isEmpty) {
      continue;
    }
    salesByField[sale.fieldId] =
        (salesByField[sale.fieldId] ?? 0) + sale.totalAmount;
    kgByField[sale.fieldId] = (kgByField[sale.fieldId] ?? 0) + sale.amountKg;
  }
  for (final expense in expenses) {
    if (expense.fieldId.isEmpty) {
      continue;
    }
    expenseByField[expense.fieldId] =
        (expenseByField[expense.fieldId] ?? 0) + expense.amount;
  }
  for (final work in works) {
    if (work.fieldId.isEmpty) {
      continue;
    }
    daysByField[work.fieldId] =
        (daysByField[work.fieldId] ?? 0) + work.dayCount;
    laborByField[work.fieldId] =
        (laborByField[work.fieldId] ?? 0) + work.totalEarned;
  }

  final ids = <String>{
    ...salesByField.keys,
    ...kgByField.keys,
    ...expenseByField.keys,
    ...daysByField.keys,
    ...laborByField.keys,
  };
  final lines = [
    for (final id in ids)
      _FieldReportLine(
        name: fieldById[id]?.name ?? 'Eski tarla',
        treeCount: fieldById[id]?.treeCount ?? 0,
        salesAmount: salesByField[id] ?? 0,
        soldKg: kgByField[id] ?? 0,
        expenseAmount: expenseByField[id] ?? 0,
        workerDays: daysByField[id] ?? 0,
        laborAmount: laborByField[id] ?? 0,
      ),
  ];
  lines.sort((a, b) => b.salesAmount.compareTo(a.salesAmount));
  return lines;
}

class _FieldReportLine {
  const _FieldReportLine({
    required this.name,
    required this.treeCount,
    required this.salesAmount,
    required this.soldKg,
    required this.expenseAmount,
    required this.workerDays,
    required this.laborAmount,
  });

  final String name;
  final int treeCount;
  final double salesAmount;
  final double soldKg;
  final double expenseAmount;
  final double workerDays;
  final double laborAmount;

  double get net => salesAmount - expenseAmount - laborAmount;
}
