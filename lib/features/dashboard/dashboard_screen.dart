import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/categories.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/money_utils.dart';
import '../../core/utils/report_utils.dart';
import '../../data/models/app_user.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/transaction_repository.dart';
import '../auth/auth_controller.dart';
import 'widgets/action_card.dart';
import 'widgets/metric_card.dart';
import 'widgets/month_selector.dart';
import 'widgets/transaction_list.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late DateTime _selectedMonth;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final appUser = ref.watch(currentAppUserProvider).valueOrNull;
    final monthKey = AppDateUtils.monthKey(_selectedMonth);
    final transactionsState = ref.watch(transactionsByMonthProvider(monthKey));

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _Header(user: appUser),
                      const SizedBox(height: 18),
                      MonthSelector(
                        selectedMonth: _selectedMonth,
                        onPrevious: () {
                          setState(() {
                            _selectedMonth = AppDateUtils.previousMonth(
                              _selectedMonth,
                            );
                          });
                        },
                        onNext: () {
                          setState(() {
                            _selectedMonth = AppDateUtils.nextMonth(
                              _selectedMonth,
                            );
                          });
                        },
                      ),
                      const SizedBox(height: 18),
                      transactionsState.when(
                        loading: () => const _DashboardLoading(),
                        error: (_, __) => const _ErrorCard(
                          message:
                              'Kayıtlar alınamadı. İnternet bağlantısını kontrol edin.',
                        ),
                        data: (transactions) {
                          final summary = ReportUtils.summarize(
                            transactions,
                            todayKey: AppDateUtils.dateKey(DateTime.now()),
                          );

                          return Column(
                            children: [
                              _MetricGrid(summary: summary),
                              const SizedBox(height: 18),
                              _ActionGrid(
                                monthKey: monthKey,
                                isAdmin: appUser?.isAdmin ?? false,
                              ),
                              const SizedBox(height: 18),
                              TransactionList(
                                transactions: transactions,
                                selectedMonth: _selectedMonth,
                                filter: _filter,
                                onFilterChanged: (filter) {
                                  setState(() => _filter = filter);
                                },
                                onEdit: (transaction) {
                                  context.push(
                                    '/edit/${transaction.id}?month=$monthKey',
                                  );
                                },
                                onDelete: (transaction) {
                                  if (appUser == null) {
                                    _showSnack('Bu işlem için yetkiniz yok');
                                    return;
                                  }
                                  _confirmDelete(transaction, appUser);
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    TransactionModel transaction,
    AppUser appUser,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Kaydı sil'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bu kayıt silinmeden önce arşive taşınacak.',
                style: TextStyle(color: AppColors.mutedText),
              ),
              const SizedBox(height: 14),
              _DialogLine(label: 'Tarih', value: transaction.date),
              _DialogLine(label: 'İşlem', value: transaction.typeLabel),
              _DialogLine(
                label: 'Tutar',
                value: MoneyUtils.format(transaction.amount),
              ),
              _DialogLine(
                label: 'Açıklama',
                value: transaction.description.isEmpty
                    ? '-'
                    : transaction.description,
              ),
              _DialogLine(label: 'Kaydeden', value: transaction.createdByName),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.expense,
                foregroundColor: AppColors.text,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await ref
          .read(transactionRepositoryProvider)
          .deleteTransaction(transaction: transaction, deletedBy: appUser);
      _showSnack('Kayıt silindi ve arşive taşındı.');
    } catch (_) {
      _showSnack('Kayıt silinemedi. İnternet bağlantısını kontrol edin.');
    }
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            color: AppColors.primary.withOpacity(0.1),
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
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: const Center(
                  child: Text(
                    '₺',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 28,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  ref.read(authControllerProvider.notifier).signOut();
                },
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Çıkış Yap'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Palaoğlu Kasa Takip',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Kasanız net, işleriniz kontrol altında.',
            style: TextStyle(color: AppColors.mutedText, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _UserPill(
                icon: Icons.person_outline,
                label: 'Kullanıcı: ${user?.displayName ?? '-'}',
              ),
              _UserPill(
                icon: Icons.verified_user_outlined,
                label: 'Rol: ${user?.roleLabel ?? '-'}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserPill extends StatelessWidget {
  const _UserPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: AppColors.text, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.summary});

  final FinancialSummary summary;

  @override
  Widget build(BuildContext context) {
    final commissionRemaining = summary.businessCommissionOverPaid > 0
        ? 'Fazla ${MoneyUtils.format(summary.businessCommissionOverPaid)}'
        : MoneyUtils.format(summary.businessCommissionDue);
    final metrics = [
      MetricCard(
        title: 'Bugünkü Ciro',
        value: MoneyUtils.format(summary.todayCiro),
        icon: Icons.today_outlined,
        color: AppColors.income,
      ),
      MetricCard(
        title: 'Bugünkü Gider',
        value: MoneyUtils.format(summary.todayGider),
        icon: Icons.payments_outlined,
        color: AppColors.expense,
      ),
      MetricCard(
        title: 'Aylık Ciro',
        value: MoneyUtils.format(summary.monthlyCiro),
        icon: Icons.trending_up,
        color: AppColors.income,
      ),
      MetricCard(
        title: 'Aylık Masraf',
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
        title: 'İşletme Komisyonu',
        value: MoneyUtils.format(summary.businessCommission),
        icon: Icons.percent_outlined,
        color: AppColors.primary,
      ),
      MetricCard(
        title: 'Komisyon Ödenen',
        value: MoneyUtils.format(summary.businessCommissionPayments),
        icon: Icons.payments_outlined,
        color: AppColors.warning,
      ),
      MetricCard(
        title: 'Komisyon Kalan',
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
        title: 'Kalan Borç',
        value: MoneyUtils.format(summary.remainingDebt),
        icon: Icons.handshake_outlined,
        color: AppColors.debt,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 132,
      ),
      itemBuilder: (context, index) => metrics[index],
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.monthKey, required this.isAdmin});

  final String monthKey;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final actions = [
      ActionCard(
        title: 'Ciro Gir',
        icon: Icons.add_chart,
        color: AppColors.income,
        onTap: () => context.push('/entry/ciro?month=$monthKey'),
      ),
      ActionCard(
        title: 'Toplu Giriş',
        icon: Icons.playlist_add,
        color: AppColors.primary,
        onTap: () => context.push('/bulk-entry?month=$monthKey'),
      ),
      ActionCard(
        title: 'Kayıt Dökümü',
        icon: Icons.list_alt_outlined,
        color: AppColors.turquoise,
        onTap: () => context.push('/records?month=$monthKey'),
      ),
      ActionCard(
        title: 'Masraf Gir',
        icon: Icons.receipt_long,
        color: AppColors.expense,
        onTap: () => context.push('/entry/masraf?month=$monthKey'),
      ),
      ActionCard(
        title: 'İşçi Ödemesi',
        icon: Icons.badge_outlined,
        color: AppColors.warning,
        onTap: () => context.push('/entry/isci?month=$monthKey'),
      ),
      ActionCard(
        title: 'Komisyon Gir',
        icon: Icons.percent_outlined,
        color: AppColors.primary,
        onTap: () => context.push('/entry/komisyon?month=$monthKey'),
      ),
      ActionCard(
        title: 'Bankaya Yatan',
        icon: Icons.account_balance,
        color: AppColors.bank,
        onTap: () => context.push('/entry/banka?month=$monthKey'),
      ),
      ActionCard(
        title: 'Borç / Alacak',
        icon: Icons.handshake_outlined,
        color: AppColors.debt,
        onTap: () => context.push('/entry/borc?month=$monthKey'),
      ),
      ActionCard(
        title: 'Aylık Rapor',
        icon: Icons.insert_chart_outlined,
        color: AppColors.turquoise,
        onTap: () => context.push('/report?month=$monthKey'),
      ),
      if (isAdmin)
        ActionCard(
          title: 'Personel Ayarları',
          icon: Icons.manage_accounts_outlined,
          color: AppColors.primary,
          onTap: () => context.push('/employees'),
        ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 78,
      ),
      itemBuilder: (context, index) => actions[index],
    );
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 80),
      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.mutedText)),
    );
  }
}

class _DialogLine extends StatelessWidget {
  const _DialogLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.mutedText),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
