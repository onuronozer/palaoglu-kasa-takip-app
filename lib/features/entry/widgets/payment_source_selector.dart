import 'package:flutter/material.dart';

import '../../../core/constants/categories.dart';

class PaymentSourceSelector extends StatelessWidget {
  const PaymentSourceSelector({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ödeme kaynağı', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final source in PaymentSources.all)
              ChoiceChip(
                label: Text(PaymentSources.label(source)),
                selected: selected == source,
                onSelected: (_) => onChanged(source),
              ),
          ],
        ),
      ],
    );
  }
}
