import 'package:flutter/material.dart';

class AmountInput extends StatelessWidget {
  const AmountInput({
    required this.controller,
    required this.enabled,
    super.key,
  });

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Tutar',
        prefixIcon: Icon(Icons.payments_outlined),
        prefixText: '₺ ',
        hintText: '0',
      ),
    );
  }
}
