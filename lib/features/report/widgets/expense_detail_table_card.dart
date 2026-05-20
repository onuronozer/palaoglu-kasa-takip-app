import 'package:flutter/material.dart';

import '../../../core/constants/categories.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_utils.dart';
import '../../../data/models/transaction_model.dart';

class ExpenseDetailTableCard extends StatelessWidget {
  const ExpenseDetailTableCard({required this.transactions, super.key});

  final List<TransactionModel> transactions;

  @override
  Widget build(BuildContext context) {
    final expenses =
        transactions
            .where((transaction) => transaction.type == TransactionTypes.masraf)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

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
          Text('Masraf Dökümü', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Ay içindeki masraflar kalem kalem, açıklamalarıyla birlikte.',
            style: TextStyle(color: AppColors.mutedText, fontSize: 12),
          ),
          const SizedBox(height: 14),
          if (expenses.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'Bu ay masraf kaydı yok.',
                style: TextStyle(color: AppColors.mutedText),
              ),
            )
          else
            Column(
              children: [
                for (final expense in expenses) _ExpenseLine(expense: expense),
              ],
            ),
        ],
      ),
    );
  }
}

class _ExpenseLine extends StatelessWidget {
  const _ExpenseLine({required this.expense});

  final TransactionModel expense;

  @override
  Widget build(BuildContext context) {
    final description = expense.description.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withOpacity(0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  expense.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                MoneyUtils.format(expense.amount),
                style: const TextStyle(
                  color: AppColors.expense,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description.isEmpty ? 'Açıklama yok' : description,
            style: TextStyle(
              color: description.isEmpty ? AppColors.mutedText : AppColors.text,
              fontSize: 12,
              fontWeight: description.isEmpty
                  ? FontWeight.w500
                  : FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _InfoPill(
                icon: Icons.calendar_today_outlined,
                text: expense.date,
              ),
              _InfoPill(
                icon: Icons.account_balance_wallet_outlined,
                text: expense.paymentSourceLabel,
              ),
              if (expense.createdByName.trim().isNotEmpty)
                _InfoPill(
                  icon: Icons.person_outline,
                  text: expense.createdByName,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.mutedText,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
