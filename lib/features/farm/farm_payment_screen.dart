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
    final paymentsState = ref.watch(farmPaymentsProvider);
    final merchants = merchantsState.valueOrNull ?? const <MerchantModel>[];

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
                  const SizedBox(height: 16),
                  paymentsState.when(
                    loading: () =>
                        const _StateCard(message: 'Tahsilatlar yükleniyor...'),
                    error: (_, __) => const _StateCard(
                      message: 'Tahsilat listesi okunamadı.',
                    ),
                    data: (payments) => _PaymentList(
                      payments: payments,
                      merchants: merchants,
                      isSaving: _isSaving,
                      onEdit: (payment) =>
                          _showEditPaymentDialog(payment, merchants),
                      onDelete: _confirmDeletePayment,
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
              seasonYear: _selectedDate.year,
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

  Future<void> _showEditPaymentDialog(
    FarmPaymentModel payment,
    List<MerchantModel> merchants,
  ) async {
    var selectedDate = AppDateUtils.dateFromKey(payment.date);
    var merchantId = payment.merchantId;
    final amountController = TextEditingController(
      text: _formatNumber(payment.amount),
    );

    final result = await showDialog<FarmPaymentModel>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text('Tahsilatı Düzenle'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DateSelector(
                        selectedDate: selectedDate,
                        onChanged: (date) =>
                            setDialogState(() => selectedDate = date),
                      ),
                      const SizedBox(height: 12),
                      _MerchantDropdown(
                        merchants: merchants,
                        selectedId: merchantId,
                        enabled: true,
                        onChanged: (value) => setDialogState(
                          () => merchantId = value ?? merchantId,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Alınan tutar',
                          prefixText: '₺ ',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Vazgeç'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    payment.copyWith(
                      merchantId: merchantId,
                      date: AppDateUtils.dateKey(selectedDate),
                      amount: MoneyUtils.parse(amountController.text),
                      seasonYear: selectedDate.year,
                    ),
                  ),
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );

    amountController.dispose();
    if (result == null) {
      return;
    }
    if (result.merchantId.isEmpty || result.amount <= 0) {
      _showSnack('Tahsilatta tüccar ve tutar doğru olmalı.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(farmRepositoryProvider).updatePayment(result);
      _showSnack('Tahsilat güncellendi.');
    } catch (_) {
      _showSnack('Tahsilat güncellenemedi.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _confirmDeletePayment(FarmPaymentModel payment) async {
    final confirmed = await _confirmDelete('Bu tahsilat kaydı silinsin mi?');
    if (!confirmed) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ref.read(farmRepositoryProvider).deletePayment(payment);
      _showSnack('Tahsilat silindi.');
    } catch (_) {
      _showSnack('Tahsilat silinemedi.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<bool> _confirmDelete(String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text('Kaydı sil'),
              content: Text(
                message,
                style: const TextStyle(color: AppColors.mutedText),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Vazgeç'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Sil'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

class _PaymentList extends StatelessWidget {
  const _PaymentList({
    required this.payments,
    required this.merchants,
    required this.isSaving,
    required this.onEdit,
    required this.onDelete,
  });

  final List<FarmPaymentModel> payments;
  final List<MerchantModel> merchants;
  final bool isSaving;
  final ValueChanged<FarmPaymentModel> onEdit;
  final ValueChanged<FarmPaymentModel> onDelete;

  @override
  Widget build(BuildContext context) {
    final merchantNames = {
      for (final merchant in merchants) merchant.id: merchant.fullName,
    };
    final shown = payments.take(25).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Son Tahsilatlar',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            const Text(
              'Henüz tahsilat yok.',
              style: TextStyle(color: AppColors.mutedText),
            )
          else
            for (final payment in shown)
              _PaymentTile(
                payment: payment,
                merchantName: merchantNames[payment.merchantId] ?? 'Tüccar',
                isSaving: isSaving,
                onEdit: () => onEdit(payment),
                onDelete: () => onDelete(payment),
              ),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.payment,
    required this.merchantName,
    required this.isSaving,
    required this.onEdit,
    required this.onDelete,
  });

  final FarmPaymentModel payment;
  final String merchantName;
  final bool isSaving;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  merchantName,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  payment.date,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  MoneyUtils.format(payment.amount),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Düzenle',
            onPressed: isSaving ? null : onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Sil',
            onPressed: isSaving ? null : onDelete,
            icon: const Icon(Icons.delete_outline, color: AppColors.expense),
          ),
        ],
      ),
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

String _formatNumber(double value) {
  if (value % 1 == 0) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}
