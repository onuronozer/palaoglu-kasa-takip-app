import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/report_utils.dart';
import '../../core/utils/whatsapp_utils.dart';
import '../../data/repositories/employee_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../dashboard/widgets/month_selector.dart';
import 'widgets/debt_summary_card.dart';
import 'widgets/employee_salary_card.dart';
import 'widgets/expense_category_chart.dart';
import 'widgets/report_summary_cards.dart';
import 'widgets/trend_chart_card.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({
    this.initialMonthKey,
    super.key,
  });

  final String? initialMonthKey;

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = AppDateUtils.monthFromKey(widget.initialMonthKey);
  }

  @override
  Widget build(BuildContext context) {
    final monthKey = AppDateUtils.monthKey(_selectedMonth);
    final monthLabel = AppDateUtils.monthLabel(_selectedMonth);
    final transactionsState = ref.watch(transactionsByMonthProvider(monthKey));
    final employeesState = ref.watch(employeesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('$monthLabel Rapor'),
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
                  MonthSelector(
                    selectedMonth: _selectedMonth,
                    onPrevious: () {
                      setState(() {
                        _selectedMonth =
                            AppDateUtils.previousMonth(_selectedMonth);
                      });
                    },
                    onNext: () {
                      setState(() {
                        _selectedMonth = AppDateUtils.nextMonth(_selectedMonth);
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  transactionsState.when(
                    loading: () => const _LoadingCard(message: 'Rapor hazırlanıyor...'),
                    error: (_, __) => const _LoadingCard(
                      message:
                          'Rapor alınamadı. İnternet bağlantısını kontrol edin.',
                    ),
                    data: (transactions) {
                      return employeesState.when(
                        loading: () => const _LoadingCard(
                          message: 'Personel baremleri okunuyor...',
                        ),
                        error: (_, __) => const _LoadingCard(
                          message: 'Personel bilgileri okunamadı.',
                        ),
                        data: (employees) {
                          final summary = ReportUtils.summarize(
                            transactions,
                            todayKey: AppDateUtils.dateKey(DateTime.now()),
                          );
                          final employeeSummaries =
                              ReportUtils.employeeSalarySummaries(
                            employees,
                            transactions,
                          );
                          final debts = ReportUtils.debtByPerson(transactions);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _ReportHeader(
                                monthLabel: monthLabel,
                                onWhatsapp: () async {
                                  final opened =
                                      await WhatsAppUtils.openMonthlySummary(
                                    monthLabel: monthLabel,
                                    summary: summary,
                                    employeeSummaries: employeeSummaries,
                                  );
                                  if (!mounted) {
                                    return;
                                  }
                                  if (!opened) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'WhatsApp bağlantısı açılamadı.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                              const SizedBox(height: 16),
                              ReportSummaryCards(summary: summary),
                              const SizedBox(height: 16),
                              TrendChartCard(
                                trends: ReportUtils.dailyTrend(
                                  transactions,
                                  _selectedMonth,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ExpenseCategoryChart(
                                categories: ReportUtils.expenseCategories(
                                  transactions,
                                ),
                              ),
                              const SizedBox(height: 16),
                              EmployeeSalaryCard(employees: employeeSummaries),
                              const SizedBox(height: 16),
                              DebtSummaryCard(debts: debts),
                            ],
                          );
                        },
                      );
                    },
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

class _ReportHeader extends StatelessWidget {
  const _ReportHeader({
    required this.monthLabel,
    required this.onWhatsapp,
  });

  final String monthLabel;
  final VoidCallback onWhatsapp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$monthLabel Rapor', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text(
            'Aylık ciro, gider, kasa, borç ve maaş baremi görünümü.',
            style: TextStyle(color: AppColors.mutedText),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onWhatsapp,
            icon: const Icon(Icons.send_outlined),
            label: const Text('WhatsApp Ay Özeti Gönder'),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.mutedText),
            ),
          ),
        ],
      ),
    );
  }
}
