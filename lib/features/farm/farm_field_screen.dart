import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/money_utils.dart';
import '../../data/models/farm_field_model.dart';
import '../../data/repositories/farm_repository.dart';

class FarmFieldScreen extends ConsumerStatefulWidget {
  const FarmFieldScreen({super.key});

  @override
  ConsumerState<FarmFieldScreen> createState() => _FarmFieldScreenState();
}

class _FarmFieldScreenState extends ConsumerState<FarmFieldScreen> {
  final _nameController = TextEditingController();
  final _adaController = TextEditingController();
  final _parselController = TextEditingController();
  final _areaController = TextEditingController();
  final _treeController = TextEditingController();
  final _cropController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _adaController.dispose();
    _parselController.dispose();
    _areaController.dispose();
    _treeController.dispose();
    _cropController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fieldsState = ref.watch(farmFieldsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tarlalarım'),
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
                  _AddFieldCard(
                    nameController: _nameController,
                    adaController: _adaController,
                    parselController: _parselController,
                    areaController: _areaController,
                    treeController: _treeController,
                    cropController: _cropController,
                    noteController: _noteController,
                    isSaving: _isSaving,
                    onSave: _saveField,
                  ),
                  const SizedBox(height: 16),
                  fieldsState.when(
                    loading: () =>
                        const _StateCard(message: 'Tarlalar yükleniyor...'),
                    error: (_, __) =>
                        const _StateCard(message: 'Tarla listesi okunamadı.'),
                    data: (fields) => _FieldList(
                      fields: fields,
                      isSaving: _isSaving,
                      onEdit: _showEditDialog,
                      onToggle: _toggleField,
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

  Future<void> _saveField() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack('Tarla adı boş olamaz.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(farmRepositoryProvider)
          .addFarmField(
            FarmFieldModel(
              id: '',
              name: name,
              ada: _adaController.text.trim(),
              parsel: _parselController.text.trim(),
              areaSquareMeters: MoneyUtils.parse(_areaController.text),
              treeCount: MoneyUtils.parse(_treeController.text).round(),
              cropNotes: _cropController.text.trim(),
              note: _noteController.text.trim(),
              active: true,
            ),
          );
      _nameController.clear();
      _adaController.clear();
      _parselController.clear();
      _areaController.clear();
      _treeController.clear();
      _cropController.clear();
      _noteController.clear();
      _showSnack('Tarla eklendi.');
    } catch (_) {
      _showSnack('Tarla eklenemedi.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _showEditDialog(FarmFieldModel field) async {
    final nameController = TextEditingController(text: field.name);
    final adaController = TextEditingController(text: field.ada);
    final parselController = TextEditingController(text: field.parsel);
    final areaController = TextEditingController(
      text: _formatNumber(field.areaSquareMeters),
    );
    final treeController = TextEditingController(text: '${field.treeCount}');
    final cropController = TextEditingController(text: field.cropNotes);
    final noteController = TextEditingController(text: field.note);

    final result = await showDialog<_FieldEditResult>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Tarlayı Düzenle'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Tarla adı'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: adaController,
                          decoration: const InputDecoration(labelText: 'Ada'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: parselController,
                          decoration: const InputDecoration(
                            labelText: 'Parsel',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: areaController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Metrekare',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: treeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Ağaç sayısı',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: cropController,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Ürün / cinsler',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Not'),
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
                _FieldEditResult(
                  name: nameController.text.trim(),
                  ada: adaController.text.trim(),
                  parsel: parselController.text.trim(),
                  areaSquareMeters: MoneyUtils.parse(areaController.text),
                  treeCount: MoneyUtils.parse(treeController.text).round(),
                  cropNotes: cropController.text.trim(),
                  note: noteController.text.trim(),
                ),
              ),
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    adaController.dispose();
    parselController.dispose();
    areaController.dispose();
    treeController.dispose();
    cropController.dispose();
    noteController.dispose();

    if (result == null) {
      return;
    }
    if (result.name.isEmpty) {
      _showSnack('Tarla adı boş olamaz.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(farmRepositoryProvider)
          .updateFarmField(
            field.copyWith(
              name: result.name,
              ada: result.ada,
              parsel: result.parsel,
              areaSquareMeters: result.areaSquareMeters,
              treeCount: result.treeCount,
              cropNotes: result.cropNotes,
              note: result.note,
            ),
          );
      _showSnack('Tarla güncellendi.');
    } catch (_) {
      _showSnack('Tarla güncellenemedi.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _toggleField(FarmFieldModel field) async {
    final nextActive = !field.active;
    setState(() => _isSaving = true);
    try {
      await ref
          .read(farmRepositoryProvider)
          .setFarmFieldActive(field: field, active: nextActive);
      _showSnack(nextActive ? 'Tarla aktif edildi.' : 'Tarla pasife alındı.');
    } catch (_) {
      _showSnack('Tarla durumu güncellenemedi.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _confirmDelete(FarmFieldModel field) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text('Tarlayı sil'),
              content: Text(
                '${field.name} silinsin mi? Eski kayıtlarda tarla bağlantısı korunmayabilir.',
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
      await ref.read(farmRepositoryProvider).deleteFarmField(field.id);
      _showSnack('Tarla silindi.');
    } catch (_) {
      _showSnack('Tarla silinemedi.');
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

class _AddFieldCard extends StatelessWidget {
  const _AddFieldCard({
    required this.nameController,
    required this.adaController,
    required this.parselController,
    required this.areaController,
    required this.treeController,
    required this.cropController,
    required this.noteController,
    required this.isSaving,
    required this.onSave,
  });

  final TextEditingController nameController;
  final TextEditingController adaController;
  final TextEditingController parselController;
  final TextEditingController areaController;
  final TextEditingController treeController;
  final TextEditingController cropController;
  final TextEditingController noteController;
  final bool isSaving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return _FarmPanel(
      title: 'Yeni Tarla',
      child: Column(
        children: [
          TextField(
            controller: nameController,
            enabled: !isSaving,
            decoration: const InputDecoration(
              labelText: 'Tarla adı',
              prefixIcon: Icon(Icons.landscape_outlined),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: adaController,
                  enabled: !isSaving,
                  decoration: const InputDecoration(labelText: 'Ada'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: parselController,
                  enabled: !isSaving,
                  decoration: const InputDecoration(labelText: 'Parsel'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: areaController,
                  enabled: !isSaving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Metrekare'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: treeController,
                  enabled: !isSaving,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Ağaç sayısı'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: cropController,
            enabled: !isSaving,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Ürün / cinsler',
              prefixIcon: Icon(Icons.spa_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteController,
            enabled: !isSaving,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Not',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isSaving ? null : onSave,
              icon: const Icon(Icons.add),
              label: Text(isSaving ? 'Kaydediliyor...' : 'Tarla Ekle'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldList extends StatelessWidget {
  const _FieldList({
    required this.fields,
    required this.isSaving,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final List<FarmFieldModel> fields;
  final bool isSaving;
  final ValueChanged<FarmFieldModel> onEdit;
  final ValueChanged<FarmFieldModel> onToggle;
  final ValueChanged<FarmFieldModel> onDelete;

  @override
  Widget build(BuildContext context) {
    return _FarmPanel(
      title: 'Tarla Listesi',
      child: fields.isEmpty
          ? const _StateText('Henüz tarla kaydı yok.')
          : Column(
              children: [
                for (final field in fields)
                  _FieldTile(
                    field: field,
                    isSaving: isSaving,
                    onEdit: () => onEdit(field),
                    onToggle: () => onToggle(field),
                    onDelete: () => onDelete(field),
                  ),
              ],
            ),
    );
  }
}

class _FieldTile extends StatelessWidget {
  const _FieldTile({
    required this.field,
    required this.isSaving,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final FarmFieldModel field;
  final bool isSaving;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final details = [
      field.locationLabel,
      if (field.cropNotes.trim().isNotEmpty) field.cropNotes,
      if (field.areaSquareMeters > 0)
        '${_formatNumber(field.areaSquareMeters)} m2',
      if (field.treeCount > 0) '${field.treeCount} ağaç',
    ].join(' - ');

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
                  field.name,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  details,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 12,
                  ),
                ),
                if (field.note.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    field.note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 5),
                Text(
                  field.active ? 'Aktif' : 'Pasif',
                  style: TextStyle(
                    color: field.active ? AppColors.primary : AppColors.expense,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
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
            tooltip: field.active ? 'Pasife Al' : 'Aktifleştir',
            onPressed: isSaving ? null : onToggle,
            icon: Icon(
              field.active
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

class _FarmPanel extends StatelessWidget {
  const _FarmPanel({required this.title, required this.child});

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          child,
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

class _StateText extends StatelessWidget {
  const _StateText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(message, style: const TextStyle(color: AppColors.mutedText));
  }
}

class _FieldEditResult {
  const _FieldEditResult({
    required this.name,
    required this.ada,
    required this.parsel,
    required this.areaSquareMeters,
    required this.treeCount,
    required this.cropNotes,
    required this.note,
  });

  final String name;
  final String ada;
  final String parsel;
  final double areaSquareMeters;
  final int treeCount;
  final String cropNotes;
  final String note;
}

String _formatNumber(double value) {
  if (value % 1 == 0) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}
