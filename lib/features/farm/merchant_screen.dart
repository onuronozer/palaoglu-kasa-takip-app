import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/money_utils.dart';
import '../../data/models/merchant_model.dart';
import '../../data/repositories/farm_repository.dart';

class MerchantScreen extends ConsumerStatefulWidget {
  const MerchantScreen({super.key});

  @override
  ConsumerState<MerchantScreen> createState() => _MerchantScreenState();
}

class _MerchantScreenState extends ConsumerState<MerchantScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final merchantsState = ref.watch(merchantsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tüccarlar'),
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
                  _AddMerchantCard(
                    nameController: _nameController,
                    phoneController: _phoneController,
                    isSaving: _isSaving,
                    onSave: _saveMerchant,
                  ),
                  const SizedBox(height: 16),
                  merchantsState.when(
                    loading: () =>
                        const _StateCard(message: 'Tüccarlar yükleniyor...'),
                    error: (_, __) =>
                        const _StateCard(message: 'Tüccarlar okunamadı.'),
                    data: (merchants) => _MerchantList(
                      merchants: merchants,
                      isSaving: _isSaving,
                      onEdit: _showEditMerchantDialog,
                      onDelete: _confirmDeleteMerchant,
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

  Future<void> _saveMerchant() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack('Tüccar adı boş olamaz.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(farmRepositoryProvider)
          .addMerchant(fullName: name, phone: _phoneController.text.trim());
      _nameController.clear();
      _phoneController.clear();
      _showSnack('Tüccar eklendi.');
    } catch (_) {
      _showSnack('Tüccar eklenemedi. İnternet bağlantısını kontrol edin.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _showEditMerchantDialog(MerchantModel merchant) async {
    final nameController = TextEditingController(text: merchant.fullName);
    final phoneController = TextEditingController(text: merchant.phone);

    final result = await showDialog<_MerchantEditResult>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Tüccarı Düzenle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Ad soyad'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Telefon'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                _MerchantEditResult(
                  nameController.text.trim(),
                  phoneController.text.trim(),
                ),
              ),
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();
    if (result == null) {
      return;
    }
    if (result.fullName.isEmpty) {
      _showSnack('Tüccar adı boş olamaz.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(farmRepositoryProvider)
          .updateMerchant(
            merchant.copyWith(fullName: result.fullName, phone: result.phone),
          );
      _showSnack('Tüccar güncellendi.');
    } catch (_) {
      _showSnack('Tüccar güncellenemedi.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _confirmDeleteMerchant(MerchantModel merchant) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text('Tüccarı sil'),
              content: Text(
                '${merchant.fullName} silinsin mi? Eski satış ve tahsilat kayıtları kalır.',
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
    if (!confirmed) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(farmRepositoryProvider).deleteMerchant(merchant.id);
      _showSnack('Tüccar silindi.');
    } catch (_) {
      _showSnack('Tüccar silinemedi.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
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

class _AddMerchantCard extends StatelessWidget {
  const _AddMerchantCard({
    required this.nameController,
    required this.phoneController,
    required this.isSaving,
    required this.onSave,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final bool isSaving;
  final VoidCallback onSave;

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Yeni Tüccar', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          TextField(
            controller: nameController,
            enabled: !isSaving,
            decoration: const InputDecoration(
              labelText: 'Ad soyad',
              prefixIcon: Icon(Icons.person_add_alt_1_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: phoneController,
            enabled: !isSaving,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Telefon',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: isSaving ? null : onSave,
            icon: const Icon(Icons.add),
            label: Text(isSaving ? 'Kaydediliyor...' : 'Tüccar Ekle'),
          ),
        ],
      ),
    );
  }
}

class _MerchantList extends StatelessWidget {
  const _MerchantList({
    required this.merchants,
    required this.isSaving,
    required this.onEdit,
    required this.onDelete,
  });

  final List<MerchantModel> merchants;
  final bool isSaving;
  final ValueChanged<MerchantModel> onEdit;
  final ValueChanged<MerchantModel> onDelete;

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
          Text('Cari Liste', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (merchants.isEmpty)
            const Text(
              'Henüz tüccar yok.',
              style: TextStyle(color: AppColors.mutedText),
            )
          else
            for (final merchant in merchants)
              _MerchantTile(
                merchant: merchant,
                isSaving: isSaving,
                onEdit: () => onEdit(merchant),
                onDelete: () => onDelete(merchant),
              ),
        ],
      ),
    );
  }
}

class _MerchantTile extends StatelessWidget {
  const _MerchantTile({
    required this.merchant,
    required this.isSaving,
    required this.onEdit,
    required this.onDelete,
  });

  final MerchantModel merchant;
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  merchant.fullName,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (merchant.phone.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    merchant.phone,
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            MoneyUtils.format(merchant.currentBalance),
            style: const TextStyle(
              color: AppColors.debt,
              fontWeight: FontWeight.w900,
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

class _MerchantEditResult {
  const _MerchantEditResult(this.fullName, this.phone);

  final String fullName;
  final String phone;
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.mutedText)),
    );
  }
}
