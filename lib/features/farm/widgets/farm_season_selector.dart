import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class FarmSeasonSelector extends StatelessWidget {
  const FarmSeasonSelector({
    required this.selectedSeason,
    required this.availableSeasons,
    required this.onChanged,
    super.key,
  });

  final int selectedSeason;
  final Iterable<int> availableSeasons;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().year;
    final seasons = {
      now - 1,
      now,
      now + 1,
      selectedSeason,
      ...availableSeasons.where((year) => year > 2000),
    }.toList()..sort((a, b) => b.compareTo(a));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonFormField<int>(
        value: seasons.contains(selectedSeason) ? selectedSeason : now,
        decoration: const InputDecoration(
          labelText: 'Sezon',
          prefixIcon: Icon(Icons.event_repeat_outlined),
        ),
        items: [
          for (final season in seasons)
            DropdownMenuItem(value: season, child: Text('$season Sezonu')),
        ],
        onChanged: (value) {
          if (value != null) {
            onChanged(value);
          }
        },
      ),
    );
  }
}
