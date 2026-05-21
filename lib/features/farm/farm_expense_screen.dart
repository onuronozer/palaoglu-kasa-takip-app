import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/farm_categories.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/money_utils.dart';
import '../../data/models/farm_expense_model.dart';
import '../../data/models/farm_field_model.dart';
import '../../data/repositories/farm_repository.dart';
import '../entry/widgets/category_selector.dart';
import '../entry/widgets/date_selector.dart';

class FarmExpenseScreen extends ConsumerStatefulWidget {
  const FarmExpenseScreen({super.key});

  @override
  ConsumerState<FarmExpenseScreen> createState() => _FarmExpenseScreenState();
}

class _FarmExpenseScreenState extends ConsumerState<FarmExpenseScreen> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _category = FarmExpenseCategories.all.first;
  String? _fieldId;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fieldsState = ref.watch(activeFarmFieldsProvider);
    final expensesState = ref.watch(farmExpensesProvider);
    final fields = fieldsState.valueOrNull ?? const <FarmFieldModel>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bahçe Gideri Gir'),
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
                  _InfoCard(),
                  const SizedBox(height: 16),
                  DateSelector(
                    selectedDate: _selectedDate,
                    onChanged: (date) => setState(() => _selectedDate = date),
                  ),
                  const SizedBox(height: 14),
                  CategorySelector(
                    title: 'Gider kategorisi',
                    options: FarmExpenseCategories.all,
                    selected: _category,
                    onChanged: (value) => setState(() => _category = value),
                  ),
                  const SizedBox(height: 14),
                  fieldsState.when(
                    loading: () =>
                        const _StateCard(message: 'Tarlalar yükleniyor...'),
                    error: (_, __) =>
                        const _StateCard(message: 'Tarla listesi okunamadı.'),
                    data: (fields) => _FieldDropdown(
                      fields: fields,
                      selectedId: _fieldId,
                      enabled: !_isSaving,
                      onChanged: (value) => setState(() => _fieldId = value),
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
                      labelText: 'Tutar',
                      prefixText: '₺ ',
                      prefixIcon: Icon(Icons.receipt_long),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _descriptionController,
                    enabled: !_isSaving,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Açıklama',
                      prefixIcon: Icon(Icons.notes_outlined),
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
                      _isSaving ? 'Kaydediliyor...' : 'Gideri Kaydet',
                    ),
                  ),
                  const SizedBox(height: 16),
                  expensesState.when(
                    loading: () =>
                        const _StateCard(message: 'Giderler yükleniyor...'),
                    error: (_, __) =>
                        const _StateCard(message: 'Gider listesi okunamadı.'),
                    data: (expenses) => _ExpenseList(
                      expenses: expenses,
                      fields: fields,
                      isSaving: _isSaving,
                      onEdit: (expense) =>
                          _showEditExpenseDialog(expense, fields),
                      onDelete: _confirmDeleteExpense,
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
    if (_category == null || _category!.isEmpty || amount <= 0) {
      setState(() {
        _error = _category == null || _category!.isEmpty
            ? 'Gider kategorisi seçilmeli.'
            : 'Tutar 0’dan büyük olmalı.';
        _isSaving = false;
      });
      return;
    }

    try {
      await ref.read(farmRepositoryProvider).addExpense(
            FarmExpenseModel(
              id: '',
              date: AppDateUtils.dateKey(_selectedDate),
              category: _category!,
              amount: amount,
              description: _descriptionController.text.trim(),
              seasonYear: _selectedDate.year,
              fieldId: _fieldId ?? '',
            ),
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gider kaydedildi.')));
      context.pop();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Gider kaydedilemedi. İnternet bağlantısını kontrol edin.';
        _isSaving = false;
      });
    }
  }

  Future<void> _showEditExpenseDialog(
    FarmExpenseModel expense,
    List<FarmFieldModel> fields,
  ) async {
    var selectedDate = AppDateUtils.dateFromKey(expense.date);
    var category = expense.category.isEmpty
        ? FarmExpenseCategories.all.first
        : expense.category;
    var fieldId = expense.fieldId;
    final amountController = TextEditingController(
      text: _formatNumber(expense.amount),
    );
    final descriptionController = TextEditingController(
      text: expense.description,
    );

    final result = await showDialog<FarmExpenseModel>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text('Gideri Düzenle'),
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
                      CategorySelector(
                        title: 'Gider kategorisi',
                        options: FarmExpenseCategories.all,
                        selected: category,
                        onChanged: (value) =>
                            setDialogState(() => category = value ?? category),
                      ),
                      const SizedBox(height: 12),
                      _FieldDropdown(
                        fields: fields,
                        selectedId: fieldId,
                        enabled: true,
                        onChanged: (value) =>
                            setDialogState(() => fieldId = value ?? ''),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Tutar',
                          prefixText: '₺ ',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Açıklama',
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
                    expense.copyWith(
                      date: AppDateUtils.dateKey(selectedDate),
                      category: category,
                      amount: MoneyUtils.parse(amountController.text),
                      description: descriptionController.text.trim(),
                      seasonYear: selectedDate.year,
                      fieldId: fieldId,
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
    descriptionController.dispose();
    if (result == null) {
      return;
    }
    if (result.category.isEmpty || result.amount <= 0) {
      _showSnack('Giderde kategori ve tutar doğru olmalı.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(farmRepositoryProvider).updateExpense(result);
      _showSnack('Gider güncellendi.');
    } catch (_) {
      _showSnack('Gider güncellenemedi.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _confirmDeleteExpense(FarmExpenseModel expense) async {
    final confirmed = await _confirmDelete('Bu gider kaydı silinsin mi?');
    if (!confirmed) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ref.read(farmRepositoryProvider).deleteExpense(expense.id);
      _showSnack('Gider silindi.');
    } catch (_) {
      _showSnack('Gider silinemedi.');
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

class _FieldDropdown extends StatelessWidget {
  const _FieldDropdown({
    required this.fields,
    required this.selectedId,
    required this.enabled,
    required this.onChanged,
  });

  final List<FarmFieldModel> fields;
  final String? selectedId;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: fields.any((field) => field.id == selectedId) ? selectedId : '',
      decoration: const InputDecoration(
        labelText: 'Tarla',
        prefixIcon: Icon(Icons.landscape_outlined),
      ),
      items: [
        const DropdownMenuItem(value: '', child: Text('Genel / tarla yok')),
        for (final field in fields)
          DropdownMenuItem(value: field.id, child: Text(field.name)),
      ],
      onChanged: enabled
          ? (value) => onChanged(value == null || value.isEmpty ? null : value)
          : null,
    );
  }
}

class _ExpenseList extends StatelessWidget {
  const _ExpenseList({
    required this.expenses,
    required this.fields,
    required this.isSaving,
    required this.onEdit,
    required this.onDelete,
  });

  final List<FarmExpenseModel> expenses;
  final List<FarmFieldModel> fields;
  final bool isSaving;
  final ValueChanged<FarmExpenseModel> onEdit;
  final ValueChanged<FarmExpenseModel> onDelete;

  @override
  Widget build(BuildContext context) {
    final fieldNames = {for (final field in fields) field.id: field.name};
    final shown = expenses.take(25).toList();

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
          Text('Son Giderler', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            const Text(
              'Henüz gider yok.',
              style: TextStyle(color: AppColors.mutedText),
            )
          else
            for (final expense in shown)
              _ExpenseTile(
                expense: expense,
                fieldName: fieldNames[expense.fieldId] ?? 'Genel',
                isSaving: isSaving,
                onEdit: () => onEdit(expense),
                onDelete: () => onDelete(expense),
              ),
        ],
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({
    required this.expense,
    required this.fieldName,
    required this.isSaving,
    required this.onEdit,
    required this.onDelete,
  });

  final FarmExpenseModel expense;
  final String fieldName;
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
                  expense.category,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  expense.description.trim().isEmpty
                      ? '${expense.date} • $fieldName'
                      : '${expense.date} • $fieldName • ${expense.description}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  MoneyUtils.format(expense.amount),
                  style: const TextStyle(
                    color: AppColors.expense,
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
          const Icon(Icons.receipt_long, color: AppColors.expense),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bahçe gideri',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Mazot, ilaç, gübre, budama, işçilik, su ve elektrik giderleri.',
                  style: TextStyle(color: AppColors.mutedText),
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
