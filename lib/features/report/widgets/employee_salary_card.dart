import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_utils.dart';
import '../../../core/utils/report_utils.dart';

class EmployeeSalaryCard extends StatelessWidget {
  const EmployeeSalaryCard({required this.employees, super.key});

  final List<EmployeeSalarySummary> employees;

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
          Text(
            'İşçi Ödemeleri ve Maaş Baremi',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          if (employees.isEmpty)
            const Text(
              'Personel kaydı yok.',
              style: TextStyle(color: AppColors.mutedText),
            )
          else
            for (final employee in employees)
              _EmployeeSalaryLine(employee: employee),
        ],
      ),
    );
  }
}

class _EmployeeSalaryLine extends StatelessWidget {
  const _EmployeeSalaryLine({required this.employee});

  final EmployeeSalarySummary employee;

  @override
  Widget build(BuildContext context) {
    final color = employee.isOverPaid
        ? AppColors.warning
        : employee.isComplete
        ? AppColors.income
        : AppColors.turquoise;
    final progress = employee.salary <= 0
        ? (employee.paid > 0 ? 1.0 : 0.0)
        : math.min(employee.paid / employee.salary, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  employee.name,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  employee.status,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: AppColors.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _SmallInfo(
                label: 'Barem',
                value: MoneyUtils.format(employee.salary),
              ),
              _SmallInfo(
                label: 'Ödenen',
                value: MoneyUtils.format(employee.paid),
              ),
              if (employee.isOverPaid)
                _SmallInfo(
                  label: 'Fazla',
                  value: MoneyUtils.format(employee.overPaid),
                  color: AppColors.warning,
                )
              else
                _SmallInfo(
                  label: 'Kalan',
                  value: MoneyUtils.format(employee.remaining),
                  color: employee.isComplete
                      ? AppColors.income
                      : AppColors.text,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallInfo extends StatelessWidget {
  const _SmallInfo({
    required this.label,
    required this.value,
    this.color = AppColors.text,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: '$label: ',
        style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
        children: [
          TextSpan(
            text: value,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
