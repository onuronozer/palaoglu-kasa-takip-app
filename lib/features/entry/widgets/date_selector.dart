import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';

class DateSelector extends StatelessWidget {
  const DateSelector({
    required this.selectedDate,
    required this.onChanged,
    super.key,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedMonth = DateTime(selectedDate.year, selectedDate.month);
    final days = AppDateUtils.daysInMonth(selectedMonth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Tarih',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              AppDateUtils.dateKey(selectedDate),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _QuickDateButton(
              label: 'Bugün',
              onTap: () => onChanged(DateTime.now()),
            ),
            _QuickDateButton(
              label: 'Dün',
              onTap: () {
                final now = DateTime.now();
                onChanged(now.subtract(const Duration(days: 1)));
              },
            ),
            _QuickDateButton(
              label: 'Ay Başı',
              onTap: () =>
                  onChanged(AppDateUtils.firstDayOfMonth(selectedMonth)),
            ),
            _QuickDateButton(
              label: 'Ay Sonu',
              onTap: () =>
                  onChanged(AppDateUtils.lastDayOfMonth(selectedMonth)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 7,
              mainAxisSpacing: 7,
              mainAxisExtent: 38,
            ),
            itemBuilder: (context, index) {
              final day = index + 1;
              final isSelected = selectedDate.day == day;
              return InkWell(
                onTap: () => onChanged(
                  DateTime(selectedMonth.year, selectedMonth.month, day),
                ),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Text(
                    '$day',
                    style: TextStyle(
                      color: isSelected ? AppColors.background : AppColors.text,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _QuickDateButton extends StatelessWidget {
  const _QuickDateButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(onPressed: onTap, child: Text(label));
  }
}
