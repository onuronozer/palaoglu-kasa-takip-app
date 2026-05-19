import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';

class MonthSelector extends StatelessWidget {
  const MonthSelector({
    required this.selectedMonth,
    required this.onPrevious,
    required this.onNext,
    super.key,
  });

  final DateTime selectedMonth;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Önceki Ay',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              AppDateUtils.monthLabel(selectedMonth),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Sonraki Ay',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
