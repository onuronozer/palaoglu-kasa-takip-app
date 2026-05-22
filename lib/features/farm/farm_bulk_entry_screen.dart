import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/farm_categories.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/money_utils.dart';
import '../../data/models/farm_expense_model.dart';
import '../../data/models/farm_field_model.dart';
import '../../data/models/farm_payment_model.dart';
import '../../data/models/farm_sale_model.dart';
import '../../data/models/farm_worker_model.dart';
import '../../data/models/farm_worker_payment_model.dart';
import '../../data/models/farm_worker_work_model.dart';
import '../../data/models/merchant_model.dart';
import '../../data/repositories/farm_repository.dart';
import '../dashboard/widgets/month_selector.dart';

class FarmBulkEntryScreen extends ConsumerStatefulWidget {
  const FarmBulkEntryScreen({super.key});

  @override
  ConsumerState<FarmBulkEntryScreen> createState() =>
      _FarmBulkEntryScreenState();
}

class _FarmBulkEntryScreenState extends ConsumerState<FarmBulkEntryScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  final List<_FarmBulkDraft> _drafts = [];
  final List<_FarmDesktopDraft> _desktopDrafts = [];
  bool _isSaving = false;
  bool _isSavingDesktop = false;

  @override
  void initState() {
    super.initState();
    _drafts.add(_FarmBulkDraft(day: _defaultDay()));
    _addDesktopRows(10);
  }

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    for (final draft in _desktopDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final merchantsState = ref.watch(merchantsProvider);
    final fieldsState = ref.watch(activeFarmFieldsProvider);
    final workersState = ref.watch(activeFarmWorkersProvider);
    final varietiesState = ref.watch(farmApricotVarietiesProvider);
    final fields = fieldsState.valueOrNull ?? const <FarmFieldModel>[];
    final workers = workersState.valueOrNull ?? const <FarmWorkerModel>[];
    final varietyDocs = varietiesState.valueOrNull;
    final apricotOptions = varietyDocs == null || varietyDocs.isEmpty
        ? ApricotVarieties.all
        : varietyDocs
            .where((variety) => variety.active)
            .map((variety) => variety.name)
            .where((name) => name.trim().isNotEmpty)
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tarım Toplu Giriş'),
        leading: IconButton(
          tooltip: 'Geri',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 900) {
              return merchantsState.when(
                loading: () => const Center(
                    child: _StateCard(message: 'Tüccarlar yükleniyor...')),
                error: (_, __) => const Center(
                  child: _StateCard(message: 'Tüccar listesi okunamadı.'),
                ),
                data: (merchants) {
                  return _FarmDesktopBulkPanel(
                    selectedMonth: _selectedMonth,
                    rows: _desktopDrafts,
                    merchants: merchants,
                    fields: fields,
                    workers: workers,
                    apricotOptions: apricotOptions,
                    isSaving: _isSavingDesktop,
                    onPreviousMonth: () => _changeMonth(
                      AppDateUtils.previousMonth(_selectedMonth),
                    ),
                    onNextMonth: () => _changeMonth(
                      AppDateUtils.nextMonth(_selectedMonth),
                    ),
                    onChanged: () => setState(() {}),
                    onAddRows: () => setState(() => _addDesktopRows(5)),
                    onCopyRow: _copyDesktopRow,
                    onRemoveRow: _removeDesktopRow,
                    onClearEmptyRows: _clearEmptyDesktopRows,
                    onSave: _isSavingDesktop ? null : _saveDesktop,
                  );
                },
              );
            }

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MonthSelector(
                        selectedMonth: _selectedMonth,
                        onPrevious: () => _changeMonth(
                          AppDateUtils.previousMonth(_selectedMonth),
                        ),
                        onNext: () => _changeMonth(
                          AppDateUtils.nextMonth(_selectedMonth),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _InfoCard(),
                      const SizedBox(height: 16),
                      merchantsState.when(
                        loading: () => const _StateCard(
                          message: 'Tüccarlar yükleniyor...',
                        ),
                        error: (_, __) => const _StateCard(
                          message: 'Tüccar listesi okunamadı.',
                        ),
                        data: (merchants) {
                          return Column(
                            children: [
                              for (var index = 0;
                                  index < _drafts.length;
                                  index++)
                                _BulkDraftCard(
                                  index: index,
                                  draft: _drafts[index],
                                  merchants: merchants,
                                  fields: fields,
                                  apricotOptions: apricotOptions,
                                  selectedMonth: _selectedMonth,
                                  enabled: !_isSaving,
                                  canRemove: _drafts.length > 1,
                                  onChanged: () => setState(() {}),
                                  onRemove: () => _removeRow(index),
                                ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: _isSaving ? null : _addRow,
                                icon: const Icon(Icons.add),
                                label: const Text('Satır Ekle'),
                              ),
                              const SizedBox(height: 14),
                              ElevatedButton.icon(
                                onPressed: _isSaving ? null : _save,
                                icon: const Icon(Icons.save_outlined),
                                label: Text(
                                  _isSaving
                                      ? 'Kaydediliyor...'
                                      : 'Toplu Kayıtları Kaydet',
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _addRow() {
    setState(() => _drafts.add(_FarmBulkDraft(day: _defaultDay())));
  }

  void _removeRow(int index) {
    setState(() {
      final removed = _drafts.removeAt(index);
      removed.dispose();
      if (_drafts.isEmpty) {
        _drafts.add(_FarmBulkDraft(day: _defaultDay()));
      }
    });
  }

  void _changeMonth(DateTime month) {
    setState(() {
      _selectedMonth = month;
      final maxDay = AppDateUtils.daysInMonth(month);
      for (final draft in _drafts) {
        draft.day = draft.day.clamp(1, maxDay).toInt();
      }
      for (final draft in _desktopDrafts) {
        draft.day = draft.day.clamp(1, maxDay).toInt();
      }
    });
  }

  int _defaultDay() {
    final now = DateTime.now();
    if (now.year == _selectedMonth.year && now.month == _selectedMonth.month) {
      return now.day;
    }
    return 1;
  }

  void _addDesktopRows(int count) {
    _desktopDrafts.addAll(
      List.generate(count, (_) => _FarmDesktopDraft(day: _defaultDay())),
    );
  }

  void _copyDesktopRow(int index) {
    setState(() {
      _desktopDrafts.insert(index + 1, _desktopDrafts[index].copy());
    });
  }

  void _removeDesktopRow(int index) {
    setState(() {
      final removed = _desktopDrafts.removeAt(index);
      removed.dispose();
      if (_desktopDrafts.isEmpty) {
        _addDesktopRows(10);
      }
    });
  }

  void _clearEmptyDesktopRows() {
    setState(() {
      final kept = <_FarmDesktopDraft>[];
      for (final draft in _desktopDrafts) {
        if (draft.isEmpty) {
          draft.dispose();
        } else {
          kept.add(draft);
        }
      }
      _desktopDrafts
        ..clear()
        ..addAll(kept);
      if (_desktopDrafts.isEmpty) {
        _addDesktopRows(10);
      }
    });
  }

  Future<void> _save() async {
    final repository = ref.read(farmRepositoryProvider);
    final validDrafts = <_FarmBulkDraft>[];
    final apricotOptions = _activeApricotOptions();

    for (final draft in _drafts) {
      if (!draft.hasAmount) {
        continue;
      }
      final validation = draft.validate(apricotOptions);
      if (validation != null) {
        _showSnack(validation);
        return;
      }
      validDrafts.add(draft);
    }

    if (validDrafts.isEmpty) {
      _showSnack('Kaydedilecek satır yok.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      for (final draft in validDrafts) {
        final date = DateTime(
          _selectedMonth.year,
          _selectedMonth.month,
          draft.day,
        );
        final dateKey = AppDateUtils.dateKey(date);

        if (draft.type == _FarmBulkType.sale) {
          final kg = MoneyUtils.parse(draft.kgController.text);
          final price = MoneyUtils.parse(draft.priceController.text);
          await repository.addSale(
            FarmSaleModel(
              id: '',
              merchantId: draft.merchantId!,
              date: dateKey,
              productName: draft.product,
              productVariety: draft.product == FarmProducts.kayisi
                  ? draft.variety ?? ''
                  : '',
              amountKg: kg,
              priceTl: price,
              totalAmount: kg * price,
              seasonYear: _selectedMonth.year,
              fieldId: draft.fieldId ?? '',
            ),
          );
        } else if (draft.type == _FarmBulkType.payment) {
          await repository.addPayment(
            FarmPaymentModel(
              id: '',
              merchantId: draft.merchantId!,
              date: dateKey,
              amount: MoneyUtils.parse(draft.amountController.text),
              seasonYear: _selectedMonth.year,
            ),
          );
        } else {
          await repository.addExpense(
            FarmExpenseModel(
              id: '',
              date: dateKey,
              category: draft.expenseCategory,
              amount: MoneyUtils.parse(draft.amountController.text),
              description: draft.descriptionController.text.trim(),
              seasonYear: _selectedMonth.year,
              fieldId: draft.fieldId ?? '',
            ),
          );
        }
      }

      if (!mounted) {
        return;
      }
      setState(() {
        for (final draft in _drafts) {
          draft.dispose();
        }
        _drafts
          ..clear()
          ..add(_FarmBulkDraft(day: _defaultDay()));
      });
      _showSnack('${validDrafts.length} kayıt eklendi.');
    } catch (_) {
      _showSnack(
        'Toplu kayıt tamamlanamadı. İnternet bağlantısını kontrol edin.',
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveDesktop() async {
    final repository = ref.read(farmRepositoryProvider);
    final merchants =
        ref.read(merchantsProvider).valueOrNull ?? const <MerchantModel>[];
    final workers = ref.read(activeFarmWorkersProvider).valueOrNull ??
        const <FarmWorkerModel>[];
    final apricotOptions = _activeApricotOptions();
    final validDrafts = <_FarmDesktopDraft>[];

    for (var index = 0; index < _desktopDrafts.length; index++) {
      final draft = _desktopDrafts[index];
      if (!draft.hasEntry) {
        continue;
      }
      final validation = draft.validate(
        merchants: merchants,
        workers: workers,
        apricotOptions: apricotOptions,
      );
      if (validation != null) {
        _showSnack('${index + 1}. satır: $validation');
        return;
      }
      validDrafts.add(draft);
    }

    if (validDrafts.isEmpty) {
      _showSnack('Kaydedilecek satır yok.');
      return;
    }

    setState(() => _isSavingDesktop = true);
    try {
      for (final draft in validDrafts) {
        final date = DateTime(
          _selectedMonth.year,
          _selectedMonth.month,
          draft.day,
        );
        final dateKey = AppDateUtils.dateKey(date);

        switch (draft.type) {
          case _FarmDesktopType.sale:
            final kg = MoneyUtils.parse(draft.kgController.text);
            final price = MoneyUtils.parse(draft.priceController.text);
            await repository.addSale(
              FarmSaleModel(
                id: '',
                merchantId: draft.merchantId!,
                date: dateKey,
                productName: draft.product,
                productVariety: draft.product == FarmProducts.kayisi
                    ? draft.variety ?? ''
                    : '',
                amountKg: kg,
                priceTl: price,
                totalAmount: kg * price,
                seasonYear: _selectedMonth.year,
                fieldId: draft.fieldId ?? '',
              ),
            );
            break;
          case _FarmDesktopType.payment:
            await repository.addPayment(
              FarmPaymentModel(
                id: '',
                merchantId: draft.merchantId!,
                date: dateKey,
                amount: MoneyUtils.parse(draft.amountController.text),
                seasonYear: _selectedMonth.year,
              ),
            );
            break;
          case _FarmDesktopType.expense:
            await repository.addExpense(
              FarmExpenseModel(
                id: '',
                date: dateKey,
                category: draft.expenseCategory,
                amount: MoneyUtils.parse(draft.amountController.text),
                description: draft.descriptionController.text.trim(),
                seasonYear: _selectedMonth.year,
                fieldId: draft.fieldId ?? '',
              ),
            );
            break;
          case _FarmDesktopType.workerWork:
            final dayCount = MoneyUtils.parse(draft.dayCountController.text);
            final dailyWage = MoneyUtils.parse(draft.dailyWageController.text);
            await repository.addFarmWorkerWork(
              FarmWorkerWorkModel(
                id: '',
                workerId: draft.workerId!,
                date: dateKey,
                dayCount: dayCount,
                dailyWage: dailyWage,
                totalEarned: dayCount * dailyWage,
                description: draft.descriptionController.text.trim(),
                seasonYear: _selectedMonth.year,
                fieldId: draft.fieldId ?? '',
              ),
            );
            break;
          case _FarmDesktopType.workerPayment:
            await repository.addFarmWorkerPayment(
              FarmWorkerPaymentModel(
                id: '',
                workerId: draft.workerId!,
                date: dateKey,
                amount: MoneyUtils.parse(draft.amountController.text),
                description: draft.descriptionController.text.trim(),
                seasonYear: _selectedMonth.year,
              ),
            );
            break;
        }
      }

      if (!mounted) {
        return;
      }
      setState(() {
        for (final draft in _desktopDrafts) {
          draft.dispose();
        }
        _desktopDrafts.clear();
        _addDesktopRows(10);
      });
      _showSnack('${validDrafts.length} kayıt eklendi.');
    } catch (_) {
      _showSnack('Bilgisayar hızlı giriş kayıtları kaydedilemedi.');
    } finally {
      if (mounted) {
        setState(() => _isSavingDesktop = false);
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

  List<String> _activeApricotOptions() {
    final varietyDocs = ref.read(farmApricotVarietiesProvider).valueOrNull;
    if (varietyDocs == null || varietyDocs.isEmpty) {
      return ApricotVarieties.all;
    }
    return varietyDocs
        .where((variety) => variety.active)
        .map((variety) => variety.name)
        .where((name) => name.trim().isNotEmpty)
        .toList();
  }
}

class _BulkDraftCard extends StatelessWidget {
  const _BulkDraftCard({
    required this.index,
    required this.draft,
    required this.merchants,
    required this.fields,
    required this.apricotOptions,
    required this.selectedMonth,
    required this.enabled,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final _FarmBulkDraft draft;
  final List<MerchantModel> merchants;
  final List<FarmFieldModel> fields;
  final List<String> apricotOptions;
  final DateTime selectedMonth;
  final bool enabled;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final days = List.generate(
      AppDateUtils.daysInMonth(selectedMonth),
      (index) => index + 1,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${index + 1}. satır',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Satırı sil',
                onPressed: enabled && canRemove ? onRemove : null,
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.expense,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: draft.day,
                  decoration: const InputDecoration(labelText: 'Gün'),
                  items: [
                    for (final day in days)
                      DropdownMenuItem(value: day, child: Text('$day')),
                  ],
                  onChanged: enabled
                      ? (value) {
                          if (value == null) {
                            return;
                          }
                          draft.day = value;
                          onChanged();
                        }
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: draft.type,
                  decoration: const InputDecoration(labelText: 'İşlem'),
                  items: const [
                    DropdownMenuItem(
                      value: _FarmBulkType.sale,
                      child: Text('Satış'),
                    ),
                    DropdownMenuItem(
                      value: _FarmBulkType.payment,
                      child: Text('Tahsilat'),
                    ),
                    DropdownMenuItem(
                      value: _FarmBulkType.expense,
                      child: Text('Gider'),
                    ),
                  ],
                  onChanged: enabled
                      ? (value) {
                          if (value == null) {
                            return;
                          }
                          draft.setType(value, apricotOptions);
                          onChanged();
                        }
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (draft.type == _FarmBulkType.sale) ...[
            _MerchantDropdown(
              merchants: merchants,
              value: draft.merchantId,
              enabled: enabled,
              onChanged: (value) {
                draft.merchantId = value;
                onChanged();
              },
            ),
            const SizedBox(height: 10),
            _FieldDropdown(
              fields: fields,
              value: draft.fieldId,
              enabled: enabled,
              onChanged: (value) {
                draft.fieldId = value;
                onChanged();
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: draft.product,
              decoration: const InputDecoration(labelText: 'Ürün'),
              items: [
                for (final product in FarmProducts.all)
                  DropdownMenuItem(value: product, child: Text(product)),
              ],
              onChanged: enabled
                  ? (value) {
                      if (value == null) {
                        return;
                      }
                      draft.setProduct(value, apricotOptions);
                      onChanged();
                    }
                  : null,
            ),
            if (draft.product == FarmProducts.kayisi) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: apricotOptions.contains(draft.variety)
                    ? draft.variety
                    : null,
                decoration: const InputDecoration(labelText: 'Kayısı çeşidi'),
                items: [
                  for (final variety in apricotOptions)
                    DropdownMenuItem(value: variety, child: Text(variety)),
                ],
                onChanged: enabled
                    ? (value) {
                        draft.variety = value;
                        onChanged();
                      }
                    : null,
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    controller: draft.kgController,
                    label: 'Kg',
                    enabled: enabled,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _NumberField(
                    controller: draft.priceController,
                    label: 'Kg fiyatı',
                    enabled: enabled,
                    prefix: '₺ ',
                  ),
                ),
              ],
            ),
          ] else if (draft.type == _FarmBulkType.payment) ...[
            _MerchantDropdown(
              merchants: merchants,
              value: draft.merchantId,
              enabled: enabled,
              onChanged: (value) {
                draft.merchantId = value;
                onChanged();
              },
            ),
            const SizedBox(height: 10),
            _NumberField(
              controller: draft.amountController,
              label: 'Alınan tutar',
              enabled: enabled,
              prefix: '₺ ',
            ),
          ] else ...[
            DropdownButtonFormField<String>(
              value: draft.expenseCategory,
              decoration: const InputDecoration(labelText: 'Gider kategorisi'),
              items: [
                for (final category in FarmExpenseCategories.all)
                  DropdownMenuItem(value: category, child: Text(category)),
              ],
              onChanged: enabled
                  ? (value) {
                      if (value == null) {
                        return;
                      }
                      draft.expenseCategory = value;
                      onChanged();
                    }
                  : null,
            ),
            const SizedBox(height: 10),
            _FieldDropdown(
              fields: fields,
              value: draft.fieldId,
              enabled: enabled,
              onChanged: (value) {
                draft.fieldId = value;
                onChanged();
              },
            ),
            const SizedBox(height: 10),
            _NumberField(
              controller: draft.amountController,
              label: 'Tutar',
              enabled: enabled,
              prefix: '₺ ',
            ),
            const SizedBox(height: 10),
            TextField(
              controller: draft.descriptionController,
              enabled: enabled,
              decoration: const InputDecoration(
                labelText: 'Açıklama',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MerchantDropdown extends StatelessWidget {
  const _MerchantDropdown({
    required this.merchants,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final List<MerchantModel> merchants;
  final String? value;
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
      value: value,
      decoration: const InputDecoration(labelText: 'Tüccar'),
      items: [
        for (final merchant in merchants)
          DropdownMenuItem(value: merchant.id, child: Text(merchant.fullName)),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }
}

class _FieldDropdown extends StatelessWidget {
  const _FieldDropdown({
    required this.fields,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final List<FarmFieldModel> fields;
  final String? value;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: fields.any((field) => field.id == value) ? value : '',
      decoration: const InputDecoration(labelText: 'Tarla'),
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

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.enabled,
    this.prefix,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, prefixText: prefix),
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
      child: const Text(
        'Satır satır satış, tahsilat veya gider gir. Tutar yazılmayan satırlar kaydedilmez.',
        style: TextStyle(color: AppColors.mutedText),
      ),
    );
  }
}

class _FarmDesktopBulkPanel extends StatelessWidget {
  const _FarmDesktopBulkPanel({
    required this.selectedMonth,
    required this.rows,
    required this.merchants,
    required this.fields,
    required this.workers,
    required this.apricotOptions,
    required this.isSaving,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onChanged,
    required this.onAddRows,
    required this.onCopyRow,
    required this.onRemoveRow,
    required this.onClearEmptyRows,
    required this.onSave,
  });

  final DateTime selectedMonth;
  final List<_FarmDesktopDraft> rows;
  final List<MerchantModel> merchants;
  final List<FarmFieldModel> fields;
  final List<FarmWorkerModel> workers;
  final List<String> apricotOptions;
  final bool isSaving;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onChanged;
  final VoidCallback onAddRows;
  final ValueChanged<int> onCopyRow;
  final ValueChanged<int> onRemoveRow;
  final VoidCallback onClearEmptyRows;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final total = rows.fold<double>(0, (sum, row) => sum + row.totalAmount);
    final days = List.generate(
      AppDateUtils.daysInMonth(selectedMonth),
      (index) => index + 1,
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 420,
                    child: MonthSelector(
                      selectedMonth: selectedMonth,
                      onPrevious: onPreviousMonth,
                      onNext: onNextMonth,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: _InfoCard()),
                ],
              ),
              const SizedBox(height: 16),
              const _FarmDesktopShortcutPanel(),
              const SizedBox(height: 16),
              Container(
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
                            'Tarım Bilgisayar Girişi',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        _FarmDesktopTotalBadge(total: total),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              _FarmDesktopHeaderCell('Gün', width: 78),
                              _FarmDesktopHeaderCell('İşlem', width: 160),
                              _FarmDesktopHeaderCell(
                                'Tüccar / İşçi',
                                width: 220,
                              ),
                              _FarmDesktopHeaderCell('Tarla', width: 190),
                              _FarmDesktopHeaderCell(
                                'Ürün / Kategori',
                                width: 160,
                              ),
                              _FarmDesktopHeaderCell('Cins', width: 150),
                              _FarmDesktopHeaderCell('Kg / Gün', width: 120),
                              _FarmDesktopHeaderCell(
                                'Fiyat / Yevmiye',
                                width: 140,
                              ),
                              _FarmDesktopHeaderCell('Tutar', width: 140),
                              _FarmDesktopHeaderCell('Açıklama', width: 230),
                              _FarmDesktopHeaderCell('İşlem', width: 100),
                            ],
                          ),
                          const SizedBox(height: 6),
                          for (var index = 0; index < rows.length; index++)
                            _FarmDesktopRow(
                              index: index,
                              draft: rows[index],
                              days: days,
                              merchants: merchants,
                              fields: fields,
                              workers: workers,
                              apricotOptions: apricotOptions,
                              enabled: !isSaving,
                              onChanged: onChanged,
                              onCopy: () => onCopyRow(index),
                              onRemove: () => onRemoveRow(index),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: isSaving ? null : onAddRows,
                          icon: const Icon(Icons.add),
                          label: const Text('5 satır ekle'),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: isSaving ? null : onClearEmptyRows,
                          icon: const Icon(Icons.cleaning_services_outlined),
                          label: const Text('Boşları temizle'),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: isSaving ? null : onSave,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(
                            isSaving ? 'Kaydediliyor...' : 'Satırları Kaydet',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FarmDesktopShortcutPanel extends StatelessWidget {
  const _FarmDesktopShortcutPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Text(
              'Ekle / düzenle / sil',
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          _FarmDesktopShortcutButton(
            label: 'Tüccarlar',
            icon: Icons.storefront_outlined,
            route: '/farm/merchants',
          ),
          _FarmDesktopShortcutButton(
            label: 'Tarlalar',
            icon: Icons.terrain_outlined,
            route: '/farm/fields',
          ),
          _FarmDesktopShortcutButton(
            label: 'İşçiler',
            icon: Icons.groups_outlined,
            route: '/farm/workers',
          ),
          _FarmDesktopShortcutButton(
            label: 'Kayısı Cinsleri',
            icon: Icons.eco_outlined,
            route: '/farm/varieties',
          ),
          _FarmDesktopShortcutButton(
            label: 'Satış',
            icon: Icons.scale_outlined,
            route: '/farm/sale',
          ),
          _FarmDesktopShortcutButton(
            label: 'Tahsilat',
            icon: Icons.payments_outlined,
            route: '/farm/payment',
          ),
          _FarmDesktopShortcutButton(
            label: 'Gider',
            icon: Icons.receipt_long_outlined,
            route: '/farm/expense',
          ),
        ],
      ),
    );
  }
}

class _FarmDesktopShortcutButton extends StatelessWidget {
  const _FarmDesktopShortcutButton({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => context.push(route),
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _FarmDesktopRow extends StatelessWidget {
  const _FarmDesktopRow({
    required this.index,
    required this.draft,
    required this.days,
    required this.merchants,
    required this.fields,
    required this.workers,
    required this.apricotOptions,
    required this.enabled,
    required this.onChanged,
    required this.onCopy,
    required this.onRemove,
  });

  final int index;
  final _FarmDesktopDraft draft;
  final List<int> days;
  final List<MerchantModel> merchants;
  final List<FarmFieldModel> fields;
  final List<FarmWorkerModel> workers;
  final List<String> apricotOptions;
  final bool enabled;
  final VoidCallback onChanged;
  final VoidCallback onCopy;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1688,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: index.isEven ? AppColors.surfaceAlt : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _FarmDesktopDropdownCell<int>(
            width: 78,
            value: draft.day,
            enabled: enabled,
            items: [
              for (final day in days)
                DropdownMenuItem(value: day, child: Text('$day')),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }
              draft.day = value;
              onChanged();
            },
          ),
          _FarmDesktopDropdownCell<String>(
            width: 160,
            value: draft.type,
            enabled: enabled,
            items: [
              for (final type in _FarmDesktopType.all)
                DropdownMenuItem(
                  value: type,
                  child: Text(_FarmDesktopType.label(type)),
                ),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }
              draft.setType(value, apricotOptions);
              onChanged();
            },
          ),
          SizedBox(width: 220, child: _partyCell()),
          SizedBox(width: 190, child: _fieldCell()),
          SizedBox(width: 160, child: _productOrCategoryCell()),
          SizedBox(width: 150, child: _varietyCell()),
          SizedBox(width: 120, child: _quantityCell()),
          SizedBox(width: 140, child: _priceCell()),
          SizedBox(width: 140, child: _amountCell()),
          _FarmDesktopTextCell(
            width: 230,
            controller: draft.descriptionController,
            enabled: enabled,
            hint: 'Açıklama',
            onChanged: onChanged,
          ),
          SizedBox(
            width: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Satırı kopyala',
                  onPressed: enabled ? onCopy : null,
                  icon: const Icon(Icons.copy_all_outlined, size: 20),
                ),
                IconButton(
                  tooltip: 'Satırı sil',
                  onPressed: enabled ? onRemove : null,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.expense,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _partyCell() {
    if (draft.type == _FarmDesktopType.sale ||
        draft.type == _FarmDesktopType.payment) {
      return _FarmDesktopDropdownCell<String>(
        width: 220,
        value: merchants.any((merchant) => merchant.id == draft.merchantId)
            ? draft.merchantId
            : null,
        enabled: enabled && merchants.isNotEmpty,
        hint: merchants.isEmpty ? 'Tüccar yok' : 'Tüccar',
        items: [
          for (final merchant in merchants)
            DropdownMenuItem(
                value: merchant.id, child: Text(merchant.fullName)),
        ],
        onChanged: (value) {
          draft.merchantId = value;
          onChanged();
        },
      );
    }
    if (draft.type == _FarmDesktopType.workerWork ||
        draft.type == _FarmDesktopType.workerPayment) {
      return _FarmDesktopDropdownCell<String>(
        width: 220,
        value: workers.any((worker) => worker.id == draft.workerId)
            ? draft.workerId
            : null,
        enabled: enabled && workers.isNotEmpty,
        hint: workers.isEmpty ? 'İşçi yok' : 'İşçi',
        items: [
          for (final worker in workers)
            DropdownMenuItem(value: worker.id, child: Text(worker.fullName)),
        ],
        onChanged: (value) {
          draft.setWorker(value, workers);
          onChanged();
        },
      );
    }
    return const _FarmDesktopStaticCell(width: 220, text: '-');
  }

  Widget _fieldCell() {
    if (draft.type == _FarmDesktopType.sale ||
        draft.type == _FarmDesktopType.expense ||
        draft.type == _FarmDesktopType.workerWork) {
      return _FarmDesktopDropdownCell<String>(
        width: 190,
        value: fields.any((field) => field.id == draft.fieldId)
            ? draft.fieldId
            : '',
        enabled: enabled,
        items: [
          const DropdownMenuItem(value: '', child: Text('Genel')),
          for (final field in fields)
            DropdownMenuItem(value: field.id, child: Text(field.name)),
        ],
        onChanged: (value) {
          draft.fieldId = value == null || value.isEmpty ? null : value;
          onChanged();
        },
      );
    }
    return const _FarmDesktopStaticCell(width: 190, text: '-');
  }

  Widget _productOrCategoryCell() {
    if (draft.type == _FarmDesktopType.sale) {
      return _FarmDesktopDropdownCell<String>(
        width: 160,
        value: draft.product,
        enabled: enabled,
        items: [
          for (final product in FarmProducts.all)
            DropdownMenuItem(value: product, child: Text(product)),
        ],
        onChanged: (value) {
          if (value == null) {
            return;
          }
          draft.setProduct(value, apricotOptions);
          onChanged();
        },
      );
    }
    if (draft.type == _FarmDesktopType.expense) {
      return _FarmDesktopDropdownCell<String>(
        width: 160,
        value: draft.expenseCategory,
        enabled: enabled,
        items: [
          for (final category in FarmExpenseCategories.all)
            DropdownMenuItem(value: category, child: Text(category)),
        ],
        onChanged: (value) {
          if (value == null) {
            return;
          }
          draft.expenseCategory = value;
          onChanged();
        },
      );
    }
    return _FarmDesktopStaticCell(
      width: 160,
      text: _FarmDesktopType.label(draft.type),
    );
  }

  Widget _varietyCell() {
    if (draft.type == _FarmDesktopType.sale &&
        draft.product == FarmProducts.kayisi) {
      return _FarmDesktopDropdownCell<String>(
        width: 150,
        value: apricotOptions.contains(draft.variety) ? draft.variety : null,
        enabled: enabled,
        items: [
          for (final variety in apricotOptions)
            DropdownMenuItem(value: variety, child: Text(variety)),
        ],
        onChanged: (value) {
          draft.variety = value;
          onChanged();
        },
      );
    }
    return const _FarmDesktopStaticCell(width: 150, text: '-');
  }

  Widget _quantityCell() {
    if (draft.type == _FarmDesktopType.sale) {
      return _FarmDesktopTextCell(
        width: 120,
        controller: draft.kgController,
        enabled: enabled,
        hint: 'Kg',
        isNumber: true,
        onChanged: onChanged,
      );
    }
    if (draft.type == _FarmDesktopType.workerWork) {
      return _FarmDesktopTextCell(
        width: 120,
        controller: draft.dayCountController,
        enabled: enabled,
        hint: 'Gün',
        isNumber: true,
        onChanged: onChanged,
      );
    }
    return const _FarmDesktopStaticCell(width: 120, text: '-');
  }

  Widget _priceCell() {
    if (draft.type == _FarmDesktopType.sale) {
      return _FarmDesktopTextCell(
        width: 140,
        controller: draft.priceController,
        enabled: enabled,
        hint: 'Fiyat',
        prefix: '₺ ',
        isNumber: true,
        onChanged: onChanged,
      );
    }
    if (draft.type == _FarmDesktopType.workerWork) {
      return _FarmDesktopTextCell(
        width: 140,
        controller: draft.dailyWageController,
        enabled: enabled,
        hint: 'Yevmiye',
        prefix: '₺ ',
        isNumber: true,
        onChanged: onChanged,
      );
    }
    return const _FarmDesktopStaticCell(width: 140, text: '-');
  }

  Widget _amountCell() {
    if (draft.type == _FarmDesktopType.payment ||
        draft.type == _FarmDesktopType.expense ||
        draft.type == _FarmDesktopType.workerPayment) {
      return _FarmDesktopTextCell(
        width: 140,
        controller: draft.amountController,
        enabled: enabled,
        hint: 'Tutar',
        prefix: '₺ ',
        isNumber: true,
        onChanged: onChanged,
      );
    }
    return _FarmDesktopStaticCell(
      width: 140,
      text: draft.totalAmount <= 0 ? '-' : MoneyUtils.format(draft.totalAmount),
    );
  }
}

class _FarmDesktopHeaderCell extends StatelessWidget {
  const _FarmDesktopHeaderCell(this.label, {required this.width});

  final String label;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.mutedText,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _FarmDesktopDropdownCell<T> extends StatelessWidget {
  const _FarmDesktopDropdownCell({
    required this.width,
    required this.value,
    required this.enabled,
    required this.items,
    required this.onChanged,
    this.hint,
  });

  final double width;
  final T? value;
  final bool enabled;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: DropdownButtonFormField<T>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 12,
            ),
          ),
          items: items,
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}

class _FarmDesktopTextCell extends StatelessWidget {
  const _FarmDesktopTextCell({
    required this.width,
    required this.controller,
    required this.enabled,
    required this.hint,
    required this.onChanged,
    this.prefix,
    this.isNumber = false,
  });

  final double width;
  final TextEditingController controller;
  final bool enabled;
  final String hint;
  final VoidCallback onChanged;
  final String? prefix;
  final bool isNumber;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: isNumber
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          textInputAction: TextInputAction.next,
          onChanged: (_) => onChanged(),
          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefix,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _FarmDesktopStaticCell extends StatelessWidget {
  const _FarmDesktopStaticCell({required this.width, required this.text});

  final double width;
  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Container(
          height: 48,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.mutedText),
          ),
        ),
      ),
    );
  }
}

class _FarmDesktopTotalBadge extends StatelessWidget {
  const _FarmDesktopTotalBadge({required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withOpacity(0.35)),
      ),
      child: Text(
        'Toplam ${MoneyUtils.format(total)}',
        style: const TextStyle(
          color: AppColors.text,
          fontWeight: FontWeight.w900,
        ),
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

class _FarmDesktopDraft {
  _FarmDesktopDraft({required this.day});

  int day;
  String type = _FarmDesktopType.sale;
  String? merchantId;
  String? workerId;
  String? fieldId;
  String product = FarmProducts.kayisi;
  String? variety = ApricotVarieties.all.first;
  String expenseCategory = FarmExpenseCategories.all.first;
  final kgController = TextEditingController();
  final priceController = TextEditingController();
  final amountController = TextEditingController();
  final dayCountController = TextEditingController();
  final dailyWageController = TextEditingController();
  final descriptionController = TextEditingController();

  bool get hasEntry {
    switch (type) {
      case _FarmDesktopType.sale:
        return MoneyUtils.parse(kgController.text) > 0 ||
            MoneyUtils.parse(priceController.text) > 0;
      case _FarmDesktopType.workerWork:
        return MoneyUtils.parse(dayCountController.text) > 0 ||
            MoneyUtils.parse(dailyWageController.text) > 0;
      default:
        return MoneyUtils.parse(amountController.text) > 0;
    }
  }

  bool get isEmpty => !hasEntry && descriptionController.text.trim().isEmpty;

  double get totalAmount {
    switch (type) {
      case _FarmDesktopType.sale:
        return MoneyUtils.parse(kgController.text) *
            MoneyUtils.parse(priceController.text);
      case _FarmDesktopType.workerWork:
        return MoneyUtils.parse(dayCountController.text) *
            MoneyUtils.parse(dailyWageController.text);
      default:
        return MoneyUtils.parse(amountController.text);
    }
  }

  void setType(String value, List<String> apricotOptions) {
    type = value;
    if (type == _FarmDesktopType.sale) {
      product = FarmProducts.kayisi;
      variety = apricotOptions.isEmpty ? null : apricotOptions.first;
      descriptionController.text = 'Hızlı satış';
    } else if (type == _FarmDesktopType.payment) {
      descriptionController.text = 'Hızlı tahsilat';
    } else if (type == _FarmDesktopType.expense) {
      expenseCategory = FarmExpenseCategories.all.first;
      descriptionController.text = 'Hızlı gider';
    } else if (type == _FarmDesktopType.workerWork) {
      descriptionController.text = 'Hızlı işçi günü';
    } else if (type == _FarmDesktopType.workerPayment) {
      descriptionController.text = 'Hızlı işçi ödemesi';
    }
  }

  void setProduct(String value, List<String> apricotOptions) {
    product = value;
    variety = value == FarmProducts.kayisi
        ? apricotOptions.isEmpty
            ? null
            : apricotOptions.first
        : null;
  }

  void setWorker(String? value, List<FarmWorkerModel> workers) {
    workerId = value;
    FarmWorkerModel? worker;
    for (final item in workers) {
      if (item.id == value) {
        worker = item;
        break;
      }
    }
    if (worker != null &&
        (dailyWageController.text.trim().isEmpty ||
            MoneyUtils.parse(dailyWageController.text) <= 0)) {
      dailyWageController.text = _formatNumber(worker.dailyWage);
    }
  }

  String? validate({
    required List<MerchantModel> merchants,
    required List<FarmWorkerModel> workers,
    required List<String> apricotOptions,
  }) {
    if (type == _FarmDesktopType.sale) {
      if (merchantId == null || merchantId!.isEmpty) {
        return 'Satış için tüccar seçilmeli.';
      }
      if (!merchants.any((merchant) => merchant.id == merchantId)) {
        return 'Seçilen tüccar bulunamadı.';
      }
      if (product == FarmProducts.kayisi &&
          (apricotOptions.isEmpty ||
              variety == null ||
              variety!.isEmpty ||
              !apricotOptions.contains(variety))) {
        return 'Kayısı satışında cins seçilmeli.';
      }
      if (MoneyUtils.parse(kgController.text) <= 0 ||
          MoneyUtils.parse(priceController.text) <= 0) {
        return 'Satışta kg ve fiyat 0’dan büyük olmalı.';
      }
    } else if (type == _FarmDesktopType.payment) {
      if (merchantId == null || merchantId!.isEmpty) {
        return 'Tahsilat için tüccar seçilmeli.';
      }
      if (MoneyUtils.parse(amountController.text) <= 0) {
        return 'Tahsilat tutarı 0’dan büyük olmalı.';
      }
    } else if (type == _FarmDesktopType.expense) {
      if (expenseCategory.trim().isEmpty) {
        return 'Gider kategorisi seçilmeli.';
      }
      if (MoneyUtils.parse(amountController.text) <= 0) {
        return 'Gider tutarı 0’dan büyük olmalı.';
      }
    } else if (type == _FarmDesktopType.workerWork) {
      if (workerId == null || workerId!.isEmpty) {
        return 'İşçi günü için işçi seçilmeli.';
      }
      if (!workers.any((worker) => worker.id == workerId)) {
        return 'Seçilen işçi aktif listede yok.';
      }
      if (MoneyUtils.parse(dayCountController.text) <= 0 ||
          MoneyUtils.parse(dailyWageController.text) <= 0) {
        return 'İşçi gününde gün ve yevmiye 0’dan büyük olmalı.';
      }
    } else if (type == _FarmDesktopType.workerPayment) {
      if (workerId == null || workerId!.isEmpty) {
        return 'İşçi ödemesi için işçi seçilmeli.';
      }
      if (MoneyUtils.parse(amountController.text) <= 0) {
        return 'İşçi ödeme tutarı 0’dan büyük olmalı.';
      }
    }
    return null;
  }

  _FarmDesktopDraft copy() {
    final copied = _FarmDesktopDraft(day: day)
      ..type = type
      ..merchantId = merchantId
      ..workerId = workerId
      ..fieldId = fieldId
      ..product = product
      ..variety = variety
      ..expenseCategory = expenseCategory;
    copied.kgController.text = kgController.text;
    copied.priceController.text = priceController.text;
    copied.amountController.text = amountController.text;
    copied.dayCountController.text = dayCountController.text;
    copied.dailyWageController.text = dailyWageController.text;
    copied.descriptionController.text = descriptionController.text;
    return copied;
  }

  void dispose() {
    kgController.dispose();
    priceController.dispose();
    amountController.dispose();
    dayCountController.dispose();
    dailyWageController.dispose();
    descriptionController.dispose();
  }
}

class _FarmDesktopType {
  const _FarmDesktopType._();

  static const sale = 'sale';
  static const payment = 'payment';
  static const expense = 'expense';
  static const workerWork = 'worker_work';
  static const workerPayment = 'worker_payment';

  static const all = [sale, payment, expense, workerWork, workerPayment];

  static String label(String type) {
    switch (type) {
      case sale:
        return 'Satış';
      case payment:
        return 'Tahsilat';
      case expense:
        return 'Gider';
      case workerWork:
        return 'İşçi Günü';
      case workerPayment:
        return 'İşçi Ödemesi';
      default:
        return type;
    }
  }
}

class _FarmBulkDraft {
  _FarmBulkDraft({required this.day});

  int day;
  String type = _FarmBulkType.sale;
  String? merchantId;
  String? fieldId;
  String product = FarmProducts.kayisi;
  String? variety = ApricotVarieties.all.first;
  String expenseCategory = FarmExpenseCategories.all.first;
  final kgController = TextEditingController();
  final priceController = TextEditingController();
  final amountController = TextEditingController();
  final descriptionController = TextEditingController();

  bool get hasAmount {
    if (type == _FarmBulkType.sale) {
      return MoneyUtils.parse(kgController.text) > 0 ||
          MoneyUtils.parse(priceController.text) > 0;
    }
    return MoneyUtils.parse(amountController.text) > 0;
  }

  void setType(String value, List<String> apricotOptions) {
    type = value;
    if (type == _FarmBulkType.sale) {
      product = FarmProducts.kayisi;
      variety = apricotOptions.isEmpty ? null : apricotOptions.first;
    }
  }

  void setProduct(String value, List<String> apricotOptions) {
    product = value;
    variety = value == FarmProducts.kayisi
        ? apricotOptions.isEmpty
            ? null
            : apricotOptions.first
        : null;
  }

  String? validate(List<String> apricotOptions) {
    if (type == _FarmBulkType.sale) {
      if (merchantId == null || merchantId!.isEmpty) {
        return 'Satış satırında tüccar seçilmeli.';
      }
      if (product == FarmProducts.kayisi &&
          (apricotOptions.isEmpty ||
              variety == null ||
              variety!.isEmpty ||
              !apricotOptions.contains(variety))) {
        return 'Kayısı satışında çeşit seçilmeli.';
      }
      if (MoneyUtils.parse(kgController.text) <= 0 ||
          MoneyUtils.parse(priceController.text) <= 0) {
        return 'Satış satırında kg ve fiyat 0’dan büyük olmalı.';
      }
    } else if (type == _FarmBulkType.payment) {
      if (merchantId == null || merchantId!.isEmpty) {
        return 'Tahsilat satırında tüccar seçilmeli.';
      }
      if (MoneyUtils.parse(amountController.text) <= 0) {
        return 'Tahsilat tutarı 0’dan büyük olmalı.';
      }
    } else if (MoneyUtils.parse(amountController.text) <= 0) {
      return 'Gider tutarı 0’dan büyük olmalı.';
    }
    return null;
  }

  void dispose() {
    kgController.dispose();
    priceController.dispose();
    amountController.dispose();
    descriptionController.dispose();
  }
}

class _FarmBulkType {
  const _FarmBulkType._();

  static const sale = 'sale';
  static const payment = 'payment';
  static const expense = 'expense';
}

String _formatNumber(double value) {
  if (value % 1 == 0) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}
