import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/farm_categories.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/money_utils.dart';
import '../../data/models/farm_expense_model.dart';
import '../../data/models/farm_payment_model.dart';
import '../../data/models/farm_sale_model.dart';
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
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _drafts.add(_FarmBulkDraft(day: _defaultDay()));
  }

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final merchantsState = ref.watch(merchantsProvider);

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
        child: Center(
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
                    onNext: () =>
                        _changeMonth(AppDateUtils.nextMonth(_selectedMonth)),
                  ),
                  const SizedBox(height: 16),
                  _InfoCard(),
                  const SizedBox(height: 16),
                  merchantsState.when(
                    loading: () =>
                        const _StateCard(message: 'Tüccarlar yükleniyor...'),
                    error: (_, __) =>
                        const _StateCard(message: 'Tüccar listesi okunamadı.'),
                    data: (merchants) {
                      return Column(
                        children: [
                          for (var index = 0; index < _drafts.length; index++)
                            _BulkDraftCard(
                              index: index,
                              draft: _drafts[index],
                              merchants: merchants,
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
    });
  }

  int _defaultDay() {
    final now = DateTime.now();
    if (now.year == _selectedMonth.year && now.month == _selectedMonth.month) {
      return now.day;
    }
    return 1;
  }

  Future<void> _save() async {
    final repository = ref.read(farmRepositoryProvider);
    final validDrafts = <_FarmBulkDraft>[];

    for (final draft in _drafts) {
      if (!draft.hasAmount) {
        continue;
      }
      final validation = draft.validate();
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
            ),
          );
        } else if (draft.type == _FarmBulkType.payment) {
          await repository.addPayment(
            FarmPaymentModel(
              id: '',
              merchantId: draft.merchantId!,
              date: dateKey,
              amount: MoneyUtils.parse(draft.amountController.text),
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

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _BulkDraftCard extends StatelessWidget {
  const _BulkDraftCard({
    required this.index,
    required this.draft,
    required this.merchants,
    required this.selectedMonth,
    required this.enabled,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final _FarmBulkDraft draft;
  final List<MerchantModel> merchants;
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
                          draft.setType(value);
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
                      draft.setProduct(value);
                      onChanged();
                    }
                  : null,
            ),
            if (draft.product == FarmProducts.kayisi) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: draft.variety,
                decoration: const InputDecoration(labelText: 'Kayısı çeşidi'),
                items: [
                  for (final variety in ApricotVarieties.all)
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

class _FarmBulkDraft {
  _FarmBulkDraft({required this.day});

  int day;
  String type = _FarmBulkType.sale;
  String? merchantId;
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

  void setType(String value) {
    type = value;
    if (type == _FarmBulkType.sale) {
      product = FarmProducts.kayisi;
      variety = ApricotVarieties.all.first;
    }
  }

  void setProduct(String value) {
    product = value;
    variety = value == FarmProducts.kayisi ? ApricotVarieties.all.first : null;
  }

  String? validate() {
    if (type == _FarmBulkType.sale) {
      if (merchantId == null || merchantId!.isEmpty) {
        return 'Satış satırında tüccar seçilmeli.';
      }
      if (product == FarmProducts.kayisi &&
          (variety == null || variety!.isEmpty)) {
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
