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
            'Palaoğlu Kıraathanesi',
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
    final metrics = [
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
        title: 'Toplam İşçi',
        value: MoneyUtils.format(summary.employeePayments),
        icon: Icons.badge_outlined,
        color: AppColors.warning,
      ),
      MetricCard(
        title: 'Kasa Nakit',
        value: MoneyUtils.format(summary.cashOnHand),
        icon: Icons.account_balance_wallet_outlined,
        color: AppColors.turquoise,
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
    final quickActions = [
      _ActionItem(
        title: 'Ciro Gir',
        icon: Icons.add_chart,
        color: AppColors.income,
        onTap: () => context.push('/entry/ciro?month=$monthKey'),
      ),
      _ActionItem(
        title: 'Masraf Gir',
        icon: Icons.receipt_long,
        color: AppColors.expense,
        onTap: () => context.push('/entry/masraf?month=$monthKey'),
      ),
      _ActionItem(
        title: 'İşçi Ödemesi',
        icon: Icons.badge_outlined,
        color: AppColors.warning,
        onTap: () => context.push('/entry/isci?month=$monthKey'),
      ),
    ];

    final recordActions = [
      _ActionItem(
        title: 'Kayıt Dökümü',
        icon: Icons.list_alt_outlined,
        color: AppColors.turquoise,
        onTap: () => context.push('/records?month=$monthKey'),
      ),
      _ActionItem(
        title: 'Aylık Rapor',
        icon: Icons.insert_chart_outlined,
        color: AppColors.turquoise,
        onTap: () => context.push('/report?month=$monthKey'),
      ),
      _ActionItem(
        title: 'Toplu Giriş',
        icon: Icons.playlist_add,
        color: AppColors.primary,
        onTap: () => context.push('/bulk-entry?month=$monthKey'),
      ),
    ];

    final otherActions = [
      _ActionItem(
        title: 'Bankaya Yatan',
        icon: Icons.account_balance,
        color: AppColors.bank,
        onTap: () => context.push('/entry/banka?month=$monthKey'),
      ),
      _ActionItem(
        title: 'Borç / Alacak',
        icon: Icons.handshake_outlined,
        color: AppColors.debt,
        onTap: () => context.push('/entry/borc?month=$monthKey'),
      ),
      if (isAdmin)
        _ActionItem(
          title: 'Personel Ayarları',
          icon: Icons.manage_accounts_outlined,
          color: AppColors.primary,
          onTap: () => context.push('/employees'),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ActionSection(title: 'Hızlı İşlemler', actions: quickActions),
        const SizedBox(height: 18),
        _ActionSection(title: 'Kayıt ve Rapor', actions: recordActions),
        const SizedBox(height: 18),
        _ActionSection(title: 'Diğer', actions: otherActions),
      ],
    );
  }
}

class _ActionSection extends StatelessWidget {
  const _ActionSection({required this.title, required this.actions});

  final String title;
  final List<_ActionItem> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 78,
          ),
          itemBuilder: (context, index) {
            final action = actions[index];
            return ActionCard(
              title: action.title,
              icon: action.icon,
              color: action.color,
              onTap: action.onTap,
            );
          },
        ),
      ],
    );
  }
}

class _ActionItem {
  const _ActionItem({
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
