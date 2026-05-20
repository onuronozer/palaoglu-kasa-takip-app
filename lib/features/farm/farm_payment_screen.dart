import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/money_utils.dart';
import '../../data/models/farm_payment_model.dart';
import '../../data/models/merchant_model.dart';
import '../../data/repositories/farm_repository.dart';
import '../entry/widgets/date_selector.dart';

class FarmPaymentScreen extends ConsumerStatefulWidget {
  const FarmPaymentScreen({super.key});

  @override
  ConsumerState<FarmPaymentScreen> createState() => _FarmPaymentScreenState();
}

class _FarmPaymentScreenState extends ConsumerState<FarmPaymentScreen> {
  final _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _merchantId;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final merchantsState = ref.watch(merchantsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tahsilat Gir'),
        leading: IconButton(
          tooltip: 'Geri',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _InfoCard(
                    title: 'Tahsilat kaydı',
                    message:
                        'Kaydedilince alınan tutar tüccarın cari bakiyesinden düşer.',
                  ),
                  const SizedBox(height: 16),
                  DateSelector(
                    selectedDate: _selectedDate,
                    onChanged: (date) => setState(() => _selectedDate = date),
                  ),
                  const SizedBox(height: 14),
                  merchantsState.when(
                    loading: () =>
                        const _StateCard(message: 'Tüccarlar yükleniyor...'),
                    error: (_, __) =>
                        const _StateCard(message: 'Tüccar listesi okunamadı.'),
                    data: (merchants) => _MerchantDropdown(
                      merchants: merchants,
                      selectedId: _merchantId,
                      enabled: !_isSaving,
                      onChanged: (value) => setState(() => _merchantId = value),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _amountController,
                    enabled: !_isSaving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Alınan tutar',
                      prefixText: '₺ ',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    _ErrorCard(message: _error!),
                  ],
                  const SizedBox(height: 22),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(
                      _isSaving ? 'Kaydediliyor...' : 'Tahsilatı Kaydet',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() {
      _error = null;
      _isSaving = true;
    });

    final amount = MoneyUtils.parse(_amountController.text);
    if (_merchantId == null || _merchantId!.isEmpty || amount <= 0) {
      setState(() {
        _error = _merchantId == null || _merchantId!.isEmpty
            ? 'Tüccar seçilmeli.'
            : 'Alınan tutar 0’dan büyük olmalı.';
        _isSaving = false;
      });
      return;
    }

    try {
      await ref
          .read(farmRepositoryProvider)
          .addPayment(
            FarmPaymentModel(
              id: '',
              merchantId: _merchantId!,
              date: AppDateUtils.dateKey(_selectedDate),
              amount: amount,
            ),
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tahsilat kaydedildi.')));
      context.pop();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Tahsilat kaydedilemedi. İnternet bağlantısını kontrol edin.';
        _isSaving = false;
      });
    }
  }
}

class _MerchantDropdown extends StatelessWidget {
  const _MerchantDropdown({
    required this.merchants,
    required this.selectedId,
    required this.enabled,
    required this.onChanged,
  });

  final List<MerchantModel> merchants;
  final String? selectedId;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (merchants.isEmpty) {
      return const _StateCard(
        message: 'Önce Tüccarlar ekranından tüccar ekleyin.',
      );
    }

    return DropdownButtonFormField<String>(
      value: selectedId,
      decoration: const InputDecoration(
        labelText: 'Tüccar',
        prefixIcon: Icon(Icons.groups_outlined),
      ),
      items: [
        for (final merchant in merchants)
          DropdownMenuItem(value: merchant.id, child: Text(merchant.fullName)),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.payments_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(color: AppColors.mutedText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.mutedText)),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.expense.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.expense.withOpacity(0.35)),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.text)),
    );
  }
}
