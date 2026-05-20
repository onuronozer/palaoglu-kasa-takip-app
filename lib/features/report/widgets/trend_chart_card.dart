import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_utils.dart';
import '../../../core/utils/report_utils.dart';

class TrendChartCard extends StatelessWidget {
  const TrendChartCard({required this.trends, super.key});

  final List<DailyTrend> trends;

  @override
  Widget build(BuildContext context) {
    final maxValue = trends.fold<double>(
      0,
      (current, day) =>
          [current, day.ciro, day.gider].reduce((a, b) => a > b ? a : b),
    );

    return _ReportCard(
      title: 'Ciro - Masraf Trendi',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              _Legend(color: AppColors.income, label: 'Ciro'),
              SizedBox(width: 14),
              _Legend(color: AppColors.expense, label: 'Gider'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 174,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final trend in trends)
                    _DayBars(
                      trend: trend,
                      maxValue: maxValue == 0 ? 1 : maxValue,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'En yüksek gün: ${MoneyUtils.format(maxValue)}',
            style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _DayBars extends StatelessWidget {
  const _DayBars({required this.trend, required this.maxValue});

  final DailyTrend trend;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    final ciroHeight = (trend.ciro / maxValue * 120).clamp(4, 120).toDouble();
    final giderHeight = (trend.gider / maxValue * 120).clamp(4, 120).toDouble();

    return SizedBox(
      width: 34,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: 128,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Bar(
                  height: trend.ciro == 0 ? 4 : ciroHeight,
                  color: AppColors.income,
                ),
                const SizedBox(width: 3),
                _Bar(
                  height: trend.gider == 0 ? 4 : giderHeight,
                  color: AppColors.expense,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${trend.day}',
            style: const TextStyle(color: AppColors.mutedText, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.height, required this.color});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppColors.mutedText)),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.title, required this.child});

  final String title;
  final Widget child;

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
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
