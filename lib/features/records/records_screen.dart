import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/categories.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/money_utils.dart';
import '../../data/models/app_user.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/transaction_repository.dart';
import '../auth/auth_controller.dart';
import '../dashboard/widgets/month_selector.dart';

class RecordsScreen extends ConsumerStatefulWidget {
  const RecordsScreen({this.initialMonthKey, super.key});

  final String? initialMonthKey;

  @override
  ConsumerState<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends ConsumerState<RecordsScreen> {
  late DateTime _selectedMonth;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _selectedMonth = AppDateUtils.monthFromKey(widget.initialMonthKey);
  }

  @override
  Widget build(BuildContext context) {
    final appUser = ref.watch(currentAppUserProvider).valueOrNull;
    final monthKey = AppDateUtils.monthKey(_selectedMonth);
    final transactionsState = ref.watch(transactionsByMonthProvider(monthKey));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kayıt Dökümü'),
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
                        _selectedMonth = AppDateUtils.previousMonth(
                          _selectedMonth,
                        );
                      });
                    },
                    onNext: () {
                      setState(() {
                        _selectedMonth = AppDateUtils.nextMonth(_selectedMonth);
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  _FilterBar(
                    selected: _filter,
                    onChanged: (value) => setState(() => _filter = value),
                  ),
                  const SizedBox(height: 14),
                  transactionsState.when(
                    loading: () =>
                        const _StateCard(message: 'Kayıtlar yükleniyor...'),
                    error: (_, __) => const _StateCard(
                      message:
                          'Kayıtlar okunamadı. İnternet bağlantısını kontrol edin.',
                    ),
                    data: (transactions) {
                      final filtered = _filter == 'all'
                          ? transactions
                          : transactions
                                .where((item) => item.type == _filter)
                                .toList();

                      return _RecordsList(
                        records: filtered,
                        monthKey: monthKey,
                        onDelete: (transaction) {
                          if (appUser == null) {
                            _showSnack('Bu işlem için yetkiniz yok');
                            return;
                          }
                          _confirmDelete(transaction, appUser);
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

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: 'Tümü',
            selected: selected == 'all',
            onTap: () => onChanged('all'),
          ),
          for (final type in TransactionTypes.all)
            _FilterChip(
              label: TransactionTypes.label(type),
              selected: selected == type,
              onTap: () => onChanged(type),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _RecordsList extends StatelessWidget {
  const _RecordsList({
    required this.records,
    required this.monthKey,
    required this.onDelete,
  });

  final List<TransactionModel> records;
  final String monthKey;
  final ValueChanged<TransactionModel> onDelete;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const _StateCard(message: 'Bu seçimde kayıt yok.');
    }

    return Column(
      children: [
        for (final record in records)
          _RecordCard(
            record: record,
            monthKey: monthKey,
            onDelete: () => onDelete(record),
          ),
      ],
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.record,
    required this.monthKey,
    required this.onDelete,
  });

  final TransactionModel record;
  final String monthKey;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(record.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_iconForType(record.type), color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.typeLabel,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      record.date,
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                MoneyUtils.format(record.amount),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _DetailLine(label: 'Kategori / Kişi', value: record.subjectLabel),
          if (record.type == TransactionTypes.masraf ||
              record.type == TransactionTypes.isci ||
              record.type == TransactionTypes.komisyon)
            _DetailLine(
              label: 'Ödeme kaynağı',
              value: record.paymentSourceLabel,
            ),
          _DetailLine(
            label: 'Açıklama',
            value: record.description.trim().isEmpty ? '-' : record.description,
          ),
          _DetailLine(label: 'Kaydeden', value: record.createdByName),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    context.push('/edit/${record.id}?month=$monthKey');
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Düzenle'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.expense,
                    side: BorderSide(color: AppColors.expense.withOpacity(0.6)),
                  ),
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Sil'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForType(String type) {
    switch (type) {
      case TransactionTypes.ciro:
        return AppColors.income;
      case TransactionTypes.masraf:
      case TransactionTypes.isci:
        return AppColors.expense;
      case TransactionTypes.komisyon:
        return AppColors.primary;
      case TransactionTypes.banka:
        return AppColors.bank;
      case TransactionTypes.borc:
        return AppColors.debt;
      default:
        return AppColors.primary;
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case TransactionTypes.ciro:
        return Icons.trending_up;
      case TransactionTypes.masraf:
        return Icons.receipt_long;
      case TransactionTypes.isci:
        return Icons.badge_outlined;
      case TransactionTypes.komisyon:
        return Icons.percent_outlined;
      case TransactionTypes.banka:
        return Icons.account_balance;
      case TransactionTypes.borc:
        return Icons.handshake_outlined;
      default:
        return Icons.payments_outlined;
    }
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
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

class _StateCard extends StatelessWidget {
  const _StateCard({required this.message});

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
