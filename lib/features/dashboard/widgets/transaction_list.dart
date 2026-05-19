import 'package:flutter/material.dart';

import '../../../core/constants/categories.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/money_utils.dart';
import '../../../data/models/transaction_model.dart';

class TransactionList extends StatelessWidget {
  const TransactionList({
    required this.transactions,
    required this.selectedMonth,
    required this.filter,
    required this.onFilterChanged,
    required this.onDelete,
    super.key,
  });

  final List<TransactionModel> transactions;
  final DateTime selectedMonth;
  final String filter;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<TransactionModel> onDelete;

  @override
  Widget build(BuildContext context) {
    final filtered = filter == 'all'
        ? transactions
        : transactions.where((item) => item.type == filter).toList();

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
            '${AppDateUtils.monthLabel(selectedMonth)} Kayıtları',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'Tümü',
                  selected: filter == 'all',
                  onTap: () => onFilterChanged('all'),
                ),
                for (final type in TransactionTypes.all)
                  _FilterChip(
                    label: TransactionTypes.label(type),
                    selected: filter == type,
                    onTap: () => onFilterChanged(type),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: Text(
                  'Bu ay için kayıt yok',
                  style: TextStyle(color: AppColors.mutedText),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 18),
              itemBuilder: (context, index) {
                final transaction = filtered[index];
                return _TransactionTile(
                  transaction: transaction,
                  onDelete: () => onDelete(transaction),
                );
              },
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

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.onDelete,
  });

  final TransactionModel transaction;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(transaction.type);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(_iconForType(transaction.type), color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      transaction.typeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    MoneyUtils.format(transaction.amount),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${transaction.date} • ${transaction.subjectLabel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
              ),
              if (transaction.description.trim().isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  transaction.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.text, fontSize: 12),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Kaydeden: ${transaction.createdByName}',
                style: const TextStyle(color: AppColors.mutedText, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Sil',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline, color: AppColors.expense),
        ),
      ],
    );
  }

  Color _colorForType(String type) {
    switch (type) {
      case TransactionTypes.ciro:
        return AppColors.income;
      case TransactionTypes.masraf:
      case TransactionTypes.isci:
        return AppColors.expense;
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
      case TransactionTypes.banka:
        return Icons.account_balance;
      case TransactionTypes.borc:
        return Icons.handshake_outlined;
      default:
        return Icons.payments_outlined;
    }
  }
}
