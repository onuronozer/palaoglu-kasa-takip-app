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
import '../dashboard/widgets/action_card.dart';
import '../dashboard/widgets/metric_card.dart';
import 'widgets/farm_season_selector.dart';

class FarmDashboardScreen extends ConsumerWidget {
  const FarmDashboardScreen({super.key});

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
    final totalReceivable = merchantBalances.values.fold<double>(
      0,
      (sum, item) => sum + item,
    );
    final totalExpenses = seasonExpenses.fold<double>(
      0,
      (sum, item) => sum + item.amount,
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
    final totalWorkerRemaining = workerSummaries.fold<double>(
      0,
      (sum, item) => sum + (item.remaining > 0 ? item.remaining : 0),
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _HeaderCard(),
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
                  _MerchantBalanceCard(
                    merchants: merchants,
                    balances: merchantBalances,
                  ),
                  const SizedBox(height: 16),
                  _WorkerBalanceCard(summaries: workerSummaries),
                  const SizedBox(height: 16),
                  _FieldSeasonCard(
                    fields: fields,
                    sales: seasonSales,
                    works: seasonWorkerWorks,
                  ),
                  const SizedBox(height: 16),
                  _RecentSalesCard(
                    sales: seasonSales,
                    merchants: merchants,
                    fields: fields,
                  ),
                  const SizedBox(height: 16),
                  _RecentExpensesCard(expenses: seasonExpenses, fields: fields),
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
  const _HeaderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceAlt, AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.turquoise.withOpacity(0.1),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.turquoise.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: const Icon(
                  Icons.agriculture_outlined,
                  color: AppColors.turquoise,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.apps_outlined, size: 18),
                label: const Text('İşletmelerim'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Palaoğlu Tarım',
            style: Theme.of(context).textTheme.headlineMedium,
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
          title: 'Tarlalarım',
          icon: Icons.landscape_outlined,
          color: AppColors.turquoise,
          onTap: () => context.push('/farm/fields'),
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
  const _MerchantBalanceCard({required this.merchants, required this.balances});

  final List<MerchantModel> merchants;
  final Map<String, double> balances;

  @override
  Widget build(BuildContext context) {
    final shown = merchants
        .where((merchant) => (balances[merchant.id] ?? 0) != 0)
        .toList();
    return _FarmCard(
      title: 'Tüccar Cari Hesap',
      child: shown.isEmpty
          ? const _EmptyText('Bu sezonda tüccar hareketi yok.')
          : Column(
              children: [
                for (final merchant in shown)
                  _InfoLine(
                    title: merchant.fullName,
                    subtitle: merchant.phone.isEmpty
                        ? 'Telefon yok'
                        : merchant.phone,
                    amount: MoneyUtils.format(balances[merchant.id] ?? 0),
                    color: (balances[merchant.id] ?? 0) >= 0
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

class _FieldSeasonCard extends StatelessWidget {
  const _FieldSeasonCard({
    required this.fields,
    required this.sales,
    required this.works,
  });

  final List<FarmFieldModel> fields;
  final List<FarmSaleModel> sales;
  final List<FarmWorkerWorkModel> works;

  @override
  Widget build(BuildContext context) {
    final lines = _fieldLines(fields: fields, sales: sales, works: works);
    return _FarmCard(
      title: 'Tarla Özeti',
      child: lines.isEmpty
          ? const _EmptyText('Bu sezonda tarla bağlantılı kayıt yok.')
          : Column(
              children: [
                for (final line in lines.take(5))
                  _InfoLine(
                    title: line.name,
                    subtitle:
                        '${_formatDays(line.workerDays)} işçi günü • ${line.soldKg.toStringAsFixed(0)} kg',
                    amount: MoneyUtils.format(line.salesAmount),
                    color: AppColors.income,
                  ),
              ],
            ),
    );
  }
}

class _RecentSalesCard extends StatelessWidget {
  const _RecentSalesCard({
    required this.sales,
    required this.merchants,
    required this.fields,
  });

  final List<FarmSaleModel> sales;
  final List<MerchantModel> merchants;
  final List<FarmFieldModel> fields;

  @override
  Widget build(BuildContext context) {
    final merchantNames = {
      for (final merchant in merchants) merchant.id: merchant.fullName,
    };
    final fieldNames = {for (final field in fields) field.id: field.name};
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
                        '${sale.date} • ${merchantNames[sale.merchantId] ?? 'Tüccar'} • ${fieldNames[sale.fieldId] ?? 'Genel'} • ${sale.amountKg.toStringAsFixed(0)} kg',
                    amount: MoneyUtils.format(sale.totalAmount),
                    color: AppColors.income,
                  ),
              ],
            ),
    );
  }
}

class _RecentExpensesCard extends StatelessWidget {
  const _RecentExpensesCard({required this.expenses, required this.fields});

  final List<FarmExpenseModel> expenses;
  final List<FarmFieldModel> fields;

  @override
  Widget build(BuildContext context) {
    final recent = expenses.take(5).toList();
    final fieldNames = {for (final field in fields) field.id: field.name};
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
                        ? '${expense.date} • ${fieldNames[expense.fieldId] ?? 'Genel'}'
                        : '${expense.date} • ${fieldNames[expense.fieldId] ?? 'Genel'} • ${expense.description}',
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

List<_FieldLine> _fieldLines({
  required List<FarmFieldModel> fields,
  required List<FarmSaleModel> sales,
  required List<FarmWorkerWorkModel> works,
}) {
  final names = {for (final field in fields) field.id: field.name};
  final salesByField = <String, double>{};
  final kgByField = <String, double>{};
  final daysByField = <String, double>{};

  for (final sale in sales) {
    if (sale.fieldId.isEmpty) {
      continue;
    }
    salesByField[sale.fieldId] =
        (salesByField[sale.fieldId] ?? 0) + sale.totalAmount;
    kgByField[sale.fieldId] = (kgByField[sale.fieldId] ?? 0) + sale.amountKg;
  }
  for (final work in works) {
    if (work.fieldId.isEmpty) {
      continue;
    }
    daysByField[work.fieldId] =
        (daysByField[work.fieldId] ?? 0) + work.dayCount;
  }

  final ids = <String>{
    ...salesByField.keys,
    ...kgByField.keys,
    ...daysByField.keys,
  };
  final lines = [
    for (final id in ids)
      _FieldLine(
        id: id,
        name: names[id] ?? 'Eski tarla',
        salesAmount: salesByField[id] ?? 0,
        soldKg: kgByField[id] ?? 0,
        workerDays: daysByField[id] ?? 0,
      ),
  ];
  lines.sort((a, b) => b.salesAmount.compareTo(a.salesAmount));
  return lines;
}

class _FieldLine {
  const _FieldLine({
    required this.id,
    required this.name,
    required this.salesAmount,
    required this.soldKg,
    required this.workerDays,
  });

  final String id;
  final String name;
  final double salesAmount;
  final double soldKg;
  final double workerDays;
}
