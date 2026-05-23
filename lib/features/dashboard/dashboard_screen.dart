import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/categories.dart';
import '../../core/ocr/ocr_image_reader.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/money_utils.dart';
import '../../core/utils/report_utils.dart';
import '../../data/models/app_user.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/employee_repository.dart';
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
  bool _isReadingOcr = false;

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
                                isReadingOcr: _isReadingOcr,
                                onReadOcr: () => _openOcrMenu(appUser),
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

  Future<void> _openOcrMenu(AppUser? appUser) async {
    if (_isReadingOcr) {
      return;
    }

    final choice = await showModalBottomSheet<_DashboardOcrChoice>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'OCR Oku',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _OcrChoiceTile(
                  icon: Icons.credit_card_outlined,
                  title: 'Kredi Kartı',
                  subtitle: 'Kart ekstresi fotoğrafından tutarları alır.',
                  onTap: () =>
                      Navigator.of(context).pop(_DashboardOcrChoice.creditCard),
                ),
                const SizedBox(height: 10),
                _OcrChoiceTile(
                  icon: Icons.receipt_long_outlined,
                  title: 'Günlük Fiş',
                  subtitle: 'Günlük fiş fotoğrafından taslak kayıt çıkarır.',
                  onTap: () => Navigator.of(context)
                      .pop(_DashboardOcrChoice.dailyReceipt),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (choice == null) {
      return;
    }
    if (appUser == null) {
      _showSnack('Bu işlem için önce giriş yapılmalı.');
      return;
    }

    switch (choice) {
      case _DashboardOcrChoice.creditCard:
        await _readCreditCardOcr(appUser);
        break;
      case _DashboardOcrChoice.dailyReceipt:
        await _readDailyReceiptOcr(appUser);
        break;
    }
  }

  Future<void> _readCreditCardOcr(AppUser appUser) async {
    final text = await _pickOcrText();
    if (text == null) {
      return;
    }

    final amounts = _extractCreditCardOcrAmounts(text);
    if (amounts.isEmpty) {
      _showSnack('OCR yazıyı okudu ama kredi kartı tutarı bulamadı.');
      return;
    }
    if (!mounted) {
      return;
    }

    final draft = await showDialog<_CreditCardOcrSaveDraft>(
      context: context,
      builder: (context) {
        return _CreditCardOcrReviewDialog(
          selectedMonth: _selectedMonth,
          amounts: amounts,
        );
      },
    );
    if (draft == null) {
      return;
    }

    final transactions = [
      for (final amount in draft.amounts)
        TransactionModel(
          id: '',
          date: AppDateUtils.dateKey(draft.date),
          monthKey: AppDateUtils.monthKey(draft.date),
          type: TransactionTypes.masraf,
          category: AppCategories.creditCard,
          person: '',
          amount: amount,
          paymentSource: PaymentSources.bank,
          description: 'Kredi kartı harcaması',
          createdByUid: appUser.uid,
          createdByName: appUser.displayName,
        ),
    ];

    if (transactions.isEmpty) {
      _showSnack('Kaydedilecek kredi kartı tutarı yok.');
      return;
    }

    try {
      await ref
          .read(transactionRepositoryProvider)
          .addTransactions(transactions);
      final total =
          transactions.fold<double>(0, (sum, item) => sum + item.amount);
      _showSnack(
        '${transactions.length} kredi kartı kaydı eklendi. Toplam ${MoneyUtils.format(total)}.',
      );
    } catch (_) {
      _showSnack('Kredi kartı kayıtları kaydedilemedi.');
    }
  }

  Future<void> _readDailyReceiptOcr(AppUser appUser) async {
    final text = await _pickOcrText();
    if (text == null) {
      return;
    }

    final employees = _employeeNamesForOcr();
    final initialDraft = _parseDailyReceiptOcr(
      rawText: text,
      selectedMonth: _selectedMonth,
      employees: employees,
    );
    if (!mounted) {
      return;
    }

    final draft = await showDialog<_DailyReceiptSaveDraft>(
      context: context,
      builder: (context) {
        return _DailyReceiptReviewDialog(
          initialDraft: initialDraft,
          employees: employees,
        );
      },
    );
    if (draft == null) {
      return;
    }

    final transactions = <TransactionModel>[];

    if (draft.totalCiro > 0) {
      transactions.add(
        TransactionModel(
          id: '',
          date: AppDateUtils.dateKey(draft.date),
          monthKey: AppDateUtils.monthKey(draft.date),
          type: TransactionTypes.ciro,
          category: AppCategories.ciro,
          person: '',
          amount: draft.totalCiro,
          description: 'Günlük fiş ciro',
          createdByUid: appUser.uid,
          createdByName: appUser.displayName,
        ),
      );
    }

    if (draft.employeePayment > 0) {
      transactions.add(
        TransactionModel(
          id: '',
          date: AppDateUtils.dateKey(draft.date),
          monthKey: AppDateUtils.monthKey(draft.date),
          type: TransactionTypes.isci,
          category: AppCategories.isci,
          person: draft.employeeName,
          amount: draft.employeePayment,
          paymentSource: PaymentSources.cash,
          description: 'Günlük fiş işçi ödemesi',
          createdByUid: appUser.uid,
          createdByName: appUser.displayName,
        ),
      );
    }

    if (draft.expenseAmount > 0) {
      transactions.add(
        TransactionModel(
          id: '',
          date: AppDateUtils.dateKey(draft.date),
          monthKey: AppDateUtils.monthKey(draft.date),
          type: TransactionTypes.masraf,
          category: draft.expenseCategory,
          person: '',
          amount: draft.expenseAmount,
          paymentSource: PaymentSources.cash,
          description: draft.expenseDescription.isEmpty
              ? 'Günlük fiş masraf'
              : draft.expenseDescription,
          createdByUid: appUser.uid,
          createdByName: appUser.displayName,
        ),
      );
    }

    if (draft.bankOrDebtAmount > 0) {
      final isDebt = draft.bankOrDebtType == TransactionTypes.borc;
      transactions.add(
        TransactionModel(
          id: '',
          date: AppDateUtils.dateKey(draft.date),
          monthKey: AppDateUtils.monthKey(draft.date),
          type: isDebt ? TransactionTypes.borc : TransactionTypes.banka,
          category: isDebt ? AppCategories.debtGiven : AppCategories.banka,
          person: isDebt ? draft.debtPerson : '',
          amount: draft.bankOrDebtAmount,
          description:
              isDebt ? 'Günlük fiş verilen borç' : 'Günlük fiş bankaya yatan',
          createdByUid: appUser.uid,
          createdByName: appUser.displayName,
        ),
      );
    }

    if (transactions.isEmpty) {
      _showSnack('Kaydedilecek günlük fiş kaydı yok.');
      return;
    }

    try {
      await ref
          .read(transactionRepositoryProvider)
          .addTransactions(transactions);
      _showSnack('${transactions.length} günlük fiş kaydı eklendi.');
    } catch (_) {
      _showSnack('Günlük fiş kayıtları kaydedilemedi.');
    }
  }

  Future<String?> _pickOcrText() async {
    if (_isReadingOcr) {
      return null;
    }

    setState(() => _isReadingOcr = true);
    try {
      final result = await pickImageAndReadOcrText();
      if (result == null) {
        _showSnack('Görsel seçilmedi.');
        return null;
      }
      return result.text;
    } catch (error) {
      _showSnack(_friendlyOcrError(error));
      return null;
    } finally {
      if (mounted) {
        setState(() => _isReadingOcr = false);
      }
    }
  }

  List<String> _employeeNamesForOcr() {
    final activeEmployees = ref.read(activeEmployeesProvider).valueOrNull;
    if (activeEmployees != null && activeEmployees.isNotEmpty) {
      return activeEmployees.map((employee) => employee.name).toList();
    }
    return AppCategories.defaultEmployees
        .map((employee) => employee.name)
        .toList();
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
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.apps_outlined, size: 18),
                label: const Text('İşletmelerim'),
              ),
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
  const _ActionGrid({
    required this.monthKey,
    required this.isAdmin,
    required this.isReadingOcr,
    required this.onReadOcr,
  });

  final String monthKey;
  final bool isAdmin;
  final bool isReadingOcr;
  final VoidCallback onReadOcr;

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
      _ActionItem(
        title: isReadingOcr ? 'OCR Okunuyor' : 'OCR Oku',
        icon: Icons.document_scanner_outlined,
        color: AppColors.primary,
        onTap: onReadOcr,
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

enum _DashboardOcrChoice { creditCard, dailyReceipt }

class _OcrChoiceTile extends StatelessWidget {
  const _OcrChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreditCardOcrReviewDialog extends StatefulWidget {
  const _CreditCardOcrReviewDialog({
    required this.selectedMonth,
    required this.amounts,
  });

  final DateTime selectedMonth;
  final List<double> amounts;

  @override
  State<_CreditCardOcrReviewDialog> createState() =>
      _CreditCardOcrReviewDialogState();
}

class _CreditCardOcrReviewDialogState
    extends State<_CreditCardOcrReviewDialog> {
  late int _day;
  late final List<TextEditingController> _amountControllers;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _day = _defaultDayForMonth(widget.selectedMonth);
    _amountControllers = [
      for (final amount in widget.amounts)
        TextEditingController(text: _formatOcrAmountInput(amount)),
    ];
    if (_amountControllers.isEmpty) {
      _amountControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    for (final controller in _amountControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = List.generate(
      AppDateUtils.daysInMonth(widget.selectedMonth),
      (index) => index + 1,
    );
    final total = _amountControllers.fold<double>(
      0,
      (sum, controller) => sum + MoneyUtils.parse(controller.text),
    );

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Kredi kartı OCR'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<int>(
                value: _day,
                decoration: const InputDecoration(labelText: 'Kayıt günü'),
                items: [
                  for (final day in days)
                    DropdownMenuItem(value: day, child: Text('$day')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _day = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              for (var index = 0; index < _amountControllers.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _amountControllers[index],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: '${index + 1}. tutar',
                            prefixText: '₺ ',
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tutarı sil',
                        onPressed: _amountControllers.length == 1
                            ? null
                            : () {
                                setState(() {
                                  final removed =
                                      _amountControllers.removeAt(index);
                                  removed.dispose();
                                });
                              },
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppColors.expense,
                        ),
                      ),
                    ],
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _amountControllers.add(TextEditingController());
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Tutar Ekle'),
              ),
              const SizedBox(height: 12),
              _OcrTotalBox(label: 'Toplam', value: MoneyUtils.format(total)),
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.expense),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        ElevatedButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Kaydet'),
        ),
      ],
    );
  }

  void _save() {
    final amounts = _amountControllers
        .map((controller) => MoneyUtils.parse(controller.text))
        .where((amount) => amount > 0)
        .toList();

    if (amounts.isEmpty) {
      setState(() => _errorMessage = 'Kaydedilecek tutar yok.');
      return;
    }

    Navigator.of(context).pop(
      _CreditCardOcrSaveDraft(
        date: DateTime(
            widget.selectedMonth.year, widget.selectedMonth.month, _day),
        amounts: amounts,
      ),
    );
  }
}

class _DailyReceiptReviewDialog extends StatefulWidget {
  const _DailyReceiptReviewDialog({
    required this.initialDraft,
    required this.employees,
  });

  final _DailyReceiptInitialDraft initialDraft;
  final List<String> employees;

  @override
  State<_DailyReceiptReviewDialog> createState() =>
      _DailyReceiptReviewDialogState();
}

class _DailyReceiptReviewDialogState extends State<_DailyReceiptReviewDialog> {
  late int _day;
  late String _employeeName;
  late String _expenseCategory;
  late String _bankOrDebtType;
  late final TextEditingController _ciroController;
  late final TextEditingController _employeePaymentController;
  late final TextEditingController _expenseAmountController;
  late final TextEditingController _expenseDescriptionController;
  late final TextEditingController _bankOrDebtAmountController;
  late final TextEditingController _debtPersonController;
  bool _showRawText = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final draft = widget.initialDraft;
    _day =
        draft.date.day.clamp(1, AppDateUtils.daysInMonth(draft.date)).toInt();
    _employeeName = draft.employeeName ?? '';
    _expenseCategory = AppCategories.expenseCategories.contains('Genel Masraf')
        ? 'Genel Masraf'
        : AppCategories.expenseCategories.first;
    _bankOrDebtType = TransactionTypes.banka;
    _ciroController = TextEditingController(
      text: _formatOcrAmountInput(draft.totalCiro),
    );
    _employeePaymentController = TextEditingController(
      text: _formatOcrAmountInput(draft.employeePayment),
    );
    _expenseAmountController = TextEditingController(
      text: _formatOcrAmountInput(draft.expenseAmount),
    );
    _expenseDescriptionController = TextEditingController();
    _bankOrDebtAmountController = TextEditingController(
      text: _formatOcrAmountInput(draft.bankOrDebtAmount),
    );
    _debtPersonController = TextEditingController();
  }

  @override
  void dispose() {
    _ciroController.dispose();
    _employeePaymentController.dispose();
    _expenseAmountController.dispose();
    _expenseDescriptionController.dispose();
    _bankOrDebtAmountController.dispose();
    _debtPersonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedMonth = DateTime(
      widget.initialDraft.date.year,
      widget.initialDraft.date.month,
    );
    final days = List.generate(
      AppDateUtils.daysInMonth(selectedMonth),
      (index) => index + 1,
    );
    final employees = {
      ...widget.employees,
      if (_employeeName.trim().isNotEmpty) _employeeName,
    }.toList();

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Günlük fiş OCR'),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<int>(
                value: _day,
                decoration: InputDecoration(
                  labelText: 'Gün (${AppDateUtils.monthLabel(selectedMonth)})',
                ),
                items: [
                  for (final day in days)
                    DropdownMenuItem(value: day, child: Text('$day')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _day = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ciroController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Toplam ciro',
                  prefixText: '₺ ',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _employeeName,
                decoration: const InputDecoration(labelText: 'İşçi'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Seçilmedi')),
                  for (final employee in employees)
                    DropdownMenuItem(value: employee, child: Text(employee)),
                ],
                onChanged: (value) {
                  setState(() => _employeeName = value ?? '');
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _employeePaymentController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'İşçi ödemesi',
                  prefixText: '₺ ',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _expenseCategory,
                decoration:
                    const InputDecoration(labelText: 'Masraf kategorisi'),
                items: [
                  for (final category in AppCategories.expenseCategories)
                    DropdownMenuItem(value: category, child: Text(category)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _expenseCategory = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _expenseAmountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Masraf tutarı',
                  prefixText: '₺ ',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _expenseDescriptionController,
                decoration:
                    const InputDecoration(labelText: 'Masraf açıklaması'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _bankOrDebtType,
                decoration: const InputDecoration(
                  labelText: 'Bankaya yatan / borç',
                ),
                items: const [
                  DropdownMenuItem(
                    value: TransactionTypes.banka,
                    child: Text('Bankaya Yatan'),
                  ),
                  DropdownMenuItem(
                    value: TransactionTypes.borc,
                    child: Text('Kasadan Verilen Borç'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _bankOrDebtType = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bankOrDebtAmountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Bankaya yatan / borç tutarı',
                  prefixText: '₺ ',
                ),
              ),
              if (_bankOrDebtType == TransactionTypes.borc) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _debtPersonController,
                  decoration:
                      const InputDecoration(labelText: 'Borç verilen kişi'),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => setState(() => _showRawText = !_showRawText),
                icon: Icon(
                  _showRawText
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                label: Text(
                    _showRawText ? 'Ham yazıyı gizle' : 'Ham yazıyı göster'),
              ),
              if (_showRawText) ...[
                const SizedBox(height: 10),
                SelectableText(
                  widget.initialDraft.rawText.trim().isEmpty
                      ? 'OCR yazısı boş geldi.'
                      : widget.initialDraft.rawText,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 12,
                  ),
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.expense),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        ElevatedButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Kaydet'),
        ),
      ],
    );
  }

  void _save() {
    final date = DateTime(
      widget.initialDraft.date.year,
      widget.initialDraft.date.month,
      _day,
    );
    final totalCiro = MoneyUtils.parse(_ciroController.text);
    final employeePayment = MoneyUtils.parse(_employeePaymentController.text);
    final expenseAmount = MoneyUtils.parse(_expenseAmountController.text);
    final bankOrDebtAmount = MoneyUtils.parse(_bankOrDebtAmountController.text);
    final debtPerson = _debtPersonController.text.trim();

    if (employeePayment > 0 && _employeeName.trim().isEmpty) {
      setState(() => _errorMessage = 'İşçi ödemesi için işçi seçilmeli.');
      return;
    }
    if (_bankOrDebtType == TransactionTypes.borc &&
        bankOrDebtAmount > 0 &&
        debtPerson.isEmpty) {
      setState(() => _errorMessage = 'Borç için kişi adı girilmeli.');
      return;
    }
    if (totalCiro <= 0 &&
        employeePayment <= 0 &&
        expenseAmount <= 0 &&
        bankOrDebtAmount <= 0) {
      setState(() => _errorMessage = 'Kaydedilecek tutar yok.');
      return;
    }

    Navigator.of(context).pop(
      _DailyReceiptSaveDraft(
        date: date,
        totalCiro: totalCiro,
        employeeName: _employeeName.trim(),
        employeePayment: employeePayment,
        expenseAmount: expenseAmount,
        expenseCategory: _expenseCategory,
        expenseDescription: _expenseDescriptionController.text.trim(),
        bankOrDebtType: _bankOrDebtType,
        bankOrDebtAmount: bankOrDebtAmount,
        debtPerson: debtPerson,
      ),
    );
  }
}

class _OcrTotalBox extends StatelessWidget {
  const _OcrTotalBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditCardOcrSaveDraft {
  const _CreditCardOcrSaveDraft({
    required this.date,
    required this.amounts,
  });

  final DateTime date;
  final List<double> amounts;
}

class _DailyReceiptInitialDraft {
  const _DailyReceiptInitialDraft({
    required this.date,
    required this.rawText,
    this.totalCiro = 0,
    this.employeeName,
    this.employeePayment = 0,
    this.expenseAmount = 0,
    this.bankOrDebtAmount = 0,
  });

  final DateTime date;
  final String rawText;
  final double totalCiro;
  final String? employeeName;
  final double employeePayment;
  final double expenseAmount;
  final double bankOrDebtAmount;
}

class _DailyReceiptSaveDraft {
  const _DailyReceiptSaveDraft({
    required this.date,
    required this.totalCiro,
    required this.employeeName,
    required this.employeePayment,
    required this.expenseAmount,
    required this.expenseCategory,
    required this.expenseDescription,
    required this.bankOrDebtType,
    required this.bankOrDebtAmount,
    required this.debtPerson,
  });

  final DateTime date;
  final double totalCiro;
  final String employeeName;
  final double employeePayment;
  final double expenseAmount;
  final String expenseCategory;
  final String expenseDescription;
  final String bankOrDebtType;
  final double bankOrDebtAmount;
  final String debtPerson;
}

_DailyReceiptInitialDraft _parseDailyReceiptOcr({
  required String rawText,
  required DateTime selectedMonth,
  required List<String> employees,
}) {
  final date = _parseDailyReceiptDate(rawText, selectedMonth);
  final ciroSegment = _segmentByLabels(
    rawText,
    starts: const ['toplam ciro'],
    ends: const ['masraflar', 'isci odemesi', 'ana kasa'],
  );
  final employeeSegment = _segmentByLabels(
    rawText,
    starts: const ['isci odemesi', 'isci odeme'],
    ends: const ['bankaya', 'verilen borc', 'masraflar'],
  );
  final expenseSegment = _segmentByLabels(
    rawText,
    starts: const ['masraflar'],
    ends: const ['isci odemesi', 'bankaya', 'ana kasa'],
  );
  final bankSegment = _segmentByLabels(
    rawText,
    starts: const ['bankaya', 'verilen borc'],
    ends: const [],
  );

  return _DailyReceiptInitialDraft(
    date: date,
    rawText: rawText,
    totalCiro: _firstLooseAmount(ciroSegment),
    employeeName: _matchEmployeeName(rawText, employees),
    employeePayment: _firstLooseAmount(employeeSegment),
    expenseAmount: _firstLooseAmount(expenseSegment),
    bankOrDebtAmount: _firstLooseAmount(bankSegment),
  );
}

String _segmentByLabels(
  String rawText, {
  required List<String> starts,
  required List<String> ends,
}) {
  final lines = rawText.split(RegExp(r'[\r\n]+'));
  var startIndex = -1;
  for (var index = 0; index < lines.length; index++) {
    final folded = _foldOcrText(lines[index]);
    if (starts.any(folded.contains)) {
      startIndex = index;
      break;
    }
  }
  if (startIndex == -1) {
    return '';
  }

  var endIndex = lines.length;
  for (var index = startIndex + 1; index < lines.length; index++) {
    final folded = _foldOcrText(lines[index]);
    if (ends.any(folded.contains)) {
      endIndex = index;
      break;
    }
  }
  return lines.sublist(startIndex, endIndex).join('\n');
}

DateTime _parseDailyReceiptDate(String rawText, DateTime selectedMonth) {
  final dateSegment = _segmentByLabels(
    rawText,
    starts: const ['tarih'],
    ends: const ['oglen ciro', 'toplam ciro', 'ana kasa', 'masraflar'],
  );
  return _parseDateFromText(dateSegment) ??
      _parseDateFromText(rawText) ??
      DateTime(
        selectedMonth.year,
        selectedMonth.month,
        _defaultDayForMonth(selectedMonth),
      );
}

DateTime? _parseDateFromText(String text) {
  final separatedPattern = RegExp(
    r'\b(\d{1,2})\D{1,3}(\d{1,2})\D{1,3}(\d{2,4})\b',
  );
  for (final match in separatedPattern.allMatches(text)) {
    final parsed = _dateFromParts(
      match.group(1),
      match.group(2),
      match.group(3),
    );
    if (parsed != null) {
      return parsed;
    }
  }

  final compactPattern = RegExp(r'\b(\d{5,6})\b');
  for (final match in compactPattern.allMatches(text)) {
    final value = match.group(1) ?? '';
    final day = value.substring(0, 2);
    final year = value.substring(value.length - 2);
    final month = value.substring(2, value.length - 2);
    final parsed = _dateFromParts(day, month, year);
    if (parsed != null) {
      return parsed;
    }
  }

  return null;
}

DateTime? _dateFromParts(String? dayText, String? monthText, String? yearText) {
  final day = int.tryParse(dayText ?? '');
  final month = int.tryParse(monthText ?? '');
  var year = int.tryParse(yearText ?? '');
  if (day == null || month == null || year == null) {
    return null;
  }
  if (year < 100) {
    year += 2000;
  }
  if (year < 2020 || year > 2035 || month < 1 || month > 12 || day < 1) {
    return null;
  }
  final daysInMonth = AppDateUtils.daysInMonth(DateTime(year, month));
  if (day > daysInMonth) {
    return null;
  }
  return DateTime(year, month, day);
}

String? _matchEmployeeName(String rawText, List<String> employees) {
  final foldedText =
      _foldOcrText(rawText).replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
  final sortedEmployees = [...employees]
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final employee in sortedEmployees) {
    final foldedEmployee =
        _foldOcrText(employee).replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
    if (foldedEmployee.isNotEmpty && foldedText.contains(foldedEmployee)) {
      return employee;
    }
  }
  return null;
}

final _looseAmountPattern = RegExp(
  r'(?:^|[^\d])((?:\d{1,3}(?:[.\s]\d{3})+|\d{4,7}|\d+,\d{2})(?:\s*(?:TL|tl|₺))?)',
);

double _firstLooseAmount(String text) {
  final amounts = _extractLooseAmounts(text);
  if (amounts.isEmpty) {
    return 0;
  }
  return amounts.first;
}

List<double> _extractLooseAmounts(String text) {
  final amounts = <double>[];
  for (final match in _looseAmountPattern.allMatches(text)) {
    final amount = _parseLooseOcrAmount(match.group(1) ?? '');
    if (amount != null) {
      amounts.add(amount);
    }
  }
  return amounts;
}

double? _parseLooseOcrAmount(String rawAmount) {
  final cleaned = rawAmount
      .replaceAll('−', '-')
      .replaceAll(RegExp('tl', caseSensitive: false), '')
      .replaceAll('₺', '')
      .replaceAll(RegExp(r'[^0-9,.\s-]'), '')
      .trim();
  if (cleaned.isEmpty) {
    return null;
  }

  final normalized = cleaned.contains(',')
      ? cleaned.replaceAll('.', '').replaceAll(' ', '').replaceAll(',', '.')
      : cleaned.replaceAll(RegExp(r'[.\s]'), '');
  final parsed = double.tryParse(normalized);
  if (parsed == null || parsed <= 0 || parsed > 10000000) {
    return null;
  }
  return parsed.abs();
}

final _creditCardOcrAmountPattern = RegExp(
  r'[-−]?\s*(?:\d{1,3}(?:[.\s]\d{3})+|\d+),\d{2}\s*(?:TL|tl|₺)?',
);
final _creditCardOcrTlPattern = RegExp('tl', caseSensitive: false);

List<double> _extractCreditCardOcrAmounts(String rawText) {
  final amounts = <double>[];
  final lines = rawText.split(RegExp(r'[\r\n]+'));

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || !_hasCreditCardOcrMoneySignal(trimmed)) {
      continue;
    }

    for (final match in _creditCardOcrAmountPattern.allMatches(trimmed)) {
      final amount = _parseCreditCardOcrAmount(match.group(0) ?? '');
      if (amount != null) {
        amounts.add(amount);
      }
    }
  }

  return amounts;
}

bool _hasCreditCardOcrMoneySignal(String line) {
  final lower = line.toLowerCase();
  return lower.contains('tl') ||
      line.contains('₺') ||
      _creditCardOcrAmountPattern.hasMatch(line);
}

double? _parseCreditCardOcrAmount(String rawAmount) {
  final cleaned = rawAmount
      .replaceAll('−', '-')
      .replaceAll(_creditCardOcrTlPattern, '')
      .replaceAll('₺', '')
      .replaceAll(' ', '')
      .trim();
  if (cleaned.isEmpty) {
    return null;
  }

  final normalized = cleaned.replaceAll('.', '').replaceAll(',', '.');
  final parsed = double.tryParse(normalized);
  if (parsed == null || parsed == 0) {
    return null;
  }

  return parsed.abs();
}

String _formatOcrAmountInput(double amount) {
  if (amount <= 0) {
    return '';
  }
  if (amount == amount.roundToDouble()) {
    return amount.toStringAsFixed(0);
  }
  return amount.toStringAsFixed(2).replaceAll('.', ',');
}

String _friendlyOcrError(Object error) {
  return error
      .toString()
      .replaceFirst('Unsupported operation: ', '')
      .replaceFirst('Bad state: ', '');
}

String _foldOcrText(String value) {
  return value
      .toLowerCase()
      .replaceAll('ç', 'c')
      .replaceAll('ğ', 'g')
      .replaceAll('ı', 'i')
      .replaceAll('i̇', 'i')
      .replaceAll('ö', 'o')
      .replaceAll('ş', 's')
      .replaceAll('ü', 'u');
}

int _defaultDayForMonth(DateTime month) {
  final now = DateTime.now();
  if (now.year == month.year && now.month == month.month) {
    return now.day;
  }
  return 1;
}
