import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/farm_categories.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/farm_apricot_variety_model.dart';
import '../../data/repositories/farm_repository.dart';

class FarmVarietyScreen extends ConsumerStatefulWidget {
  const FarmVarietyScreen({super.key});

  @override
  ConsumerState<FarmVarietyScreen> createState() => _FarmVarietyScreenState();
}

class _FarmVarietyScreenState extends ConsumerState<FarmVarietyScreen> {
  final _nameController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final varietiesState = ref.watch(farmApricotVarietiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kayısı Cinsleri'),
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
                  _AddVarietyCard(
                    controller: _nameController,
                    isSaving: _isSaving,
                    onSave: _saveVariety,
                  ),
                  const SizedBox(height: 16),
                  varietiesState.when(
                    loading: () => const _StateCard(
                      message: 'Kayısı cinsleri yükleniyor...',
                    ),
                    error: (_, __) => const _StateCard(
                      message: 'Kayısı cinsleri okunamadı.',
                    ),
                    data: (varieties) => _VarietyList(
                      varieties: varieties,
                      isSaving: _isSaving,
                      onSeedDefaults: _seedDefaults,
                      onEdit: _showEditDialog,
                      onToggle: _toggleVariety,
                      onDelete: _confirmDelete,
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

  Future<void> _saveVariety() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack('Kayısı cinsi boş olamaz.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(farmRepositoryProvider).addApricotVariety(name);
      _nameController.clear();
      _showSnack('Kayısı cinsi eklendi.');
    } catch (_) {
      _showSnack('Kayısı cinsi eklenemedi.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _seedDefaults() async {
    setState(() => _isSaving = true);
    try {
      final repository = ref.read(farmRepositoryProvider);
      final current = ref.read(farmApricotVarietiesProvider).valueOrNull ??
          const <FarmApricotVarietyModel>[];
      final existingNames = current
          .map((variety) => variety.name.trim().toLowerCase())
          .toSet();
      for (final name in ApricotVarieties.all) {
        if (existingNames.contains(name.trim().toLowerCase())) {
          continue;
        }
        await repository.addApricotVariety(name);
      }
      _showSnack('Varsayılan cinsler eklendi.');
    } catch (_) {
      _showSnack('Varsayılan cinsler eklenemedi.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _showEditDialog(FarmApricotVarietyModel variety) async {
    final controller = TextEditingController(text: variety.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Cinsi Düzenle'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Kayısı cinsi'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (name == null) {
      return;
    }
    if (name.trim().isEmpty) {
      _showSnack('Kayısı cinsi boş olamaz.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(farmRepositoryProvider)
          .updateApricotVariety(variety.copyWith(name: name.trim()));
      _showSnack('Kayısı cinsi güncellendi.');
    } catch (_) {
      _showSnack('Kayısı cinsi güncellenemedi.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _toggleVariety(FarmApricotVarietyModel variety) async {
    final nextActive = !variety.active;
    setState(() => _isSaving = true);
    try {
      await ref
          .read(farmRepositoryProvider)
          .setApricotVarietyActive(variety: variety, active: nextActive);
      _showSnack(nextActive ? 'Cins aktif edildi.' : 'Cins pasife alındı.');
    } catch (_) {
      _showSnack('Cins durumu güncellenemedi.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _confirmDelete(FarmApricotVarietyModel variety) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text('Kayısı cinsini sil'),
              content: Text(
                '${variety.name} silinsin mi? Eski satış kayıtlarındaki yazı korunur.',
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
      await ref.read(farmRepositoryProvider).deleteApricotVariety(variety.id);
      _showSnack('Kayısı cinsi silindi.');
    } catch (_) {
      _showSnack('Kayısı cinsi silinemedi.');
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

class _AddVarietyCard extends StatelessWidget {
  const _AddVarietyCard({
    required this.controller,
    required this.isSaving,
    required this.onSave,
  });

  final TextEditingController controller;
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
          Text('Yeni Kayısı Cinsi', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            enabled: !isSaving,
            decoration: const InputDecoration(
              labelText: 'Cins adı',
              prefixIcon: Icon(Icons.spa_outlined),
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: isSaving ? null : onSave,
            icon: const Icon(Icons.add),
            label: Text(isSaving ? 'Kaydediliyor...' : 'Cins Ekle'),
          ),
        ],
      ),
    );
  }
}

class _VarietyList extends StatelessWidget {
  const _VarietyList({
    required this.varieties,
    required this.isSaving,
    required this.onSeedDefaults,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final List<FarmApricotVarietyModel> varieties;
  final bool isSaving;
  final VoidCallback onSeedDefaults;
  final ValueChanged<FarmApricotVarietyModel> onEdit;
  final ValueChanged<FarmApricotVarietyModel> onToggle;
  final ValueChanged<FarmApricotVarietyModel> onDelete;

  @override
  Widget build(BuildContext context) {
    final existingNames = varieties
        .map((variety) => variety.name.trim().toLowerCase())
        .toSet();
    final hasMissingDefaults = ApricotVarieties.all.any(
      (name) => !existingNames.contains(name.trim().toLowerCase()),
    );

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
          Row(
            children: [
              Expanded(
                child: Text(
                  'Cins Listesi',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (hasMissingDefaults)
                TextButton.icon(
                  onPressed: isSaving ? null : onSeedDefaults,
                  icon: const Icon(Icons.playlist_add_outlined),
                  label: const Text('Varsayılanlar'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (varieties.isEmpty)
            const Text(
              'Liste boşsa satış ekranı eski varsayılan cinslerle çalışır. Buradan cins eklediğinde liste senin eklediklerine göre yönetilir.',
              style: TextStyle(color: AppColors.mutedText),
            )
          else
            for (final variety in varieties)
              _VarietyTile(
                variety: variety,
                isSaving: isSaving,
                onEdit: () => onEdit(variety),
                onToggle: () => onToggle(variety),
                onDelete: () => onDelete(variety),
              ),
        ],
      ),
    );
  }
}

class _VarietyTile extends StatelessWidget {
  const _VarietyTile({
    required this.variety,
    required this.isSaving,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final FarmApricotVarietyModel variety;
  final bool isSaving;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
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
                  variety.name,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  variety.active ? 'Aktif' : 'Pasif',
                  style: TextStyle(
                    color: variety.active
                        ? AppColors.primary
                        : AppColors.expense,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
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
            tooltip: variety.active ? 'Pasife Al' : 'Aktifleştir',
            onPressed: isSaving ? null : onToggle,
            icon: Icon(
              variety.active
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
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
