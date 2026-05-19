import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_utils.dart';
import '../../../core/utils/report_utils.dart';

class DebtSummaryCard extends StatelessWidget {
  const DebtSummaryCard({
    required this.debts,
    super.key,
  });

  final List<DebtPersonSummary> debts;

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
          Text('Borç / Alacak', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          if (debts.isEmpty)
            const Text(
              'Borç / alacak kaydı yok.',
              style: TextStyle(color: AppColors.mutedText),
            )
          else
            for (final debt in debts)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        debt.person,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          _DebtChip(
                            label: 'Verilen',
                            value: MoneyUtils.format(debt.given),
                            color: AppColors.debt,
                          ),
                          _DebtChip(
                            label: 'Alınan',
                            value: MoneyUtils.format(debt.paid),
                            color: AppColors.income,
                          ),
                          _DebtChip(
                            label: 'Kalan',
                            value: MoneyUtils.format(debt.remaining),
                            color: debt.remaining > 0
                                ? AppColors.warning
                                : AppColors.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _DebtChip extends StatelessWidget {
  const _DebtChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
