import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/farm_categories.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/money_utils.dart';
import '../../data/models/farm_field_model.dart';
import '../../data/models/farm_sale_model.dart';
import '../../data/models/merchant_model.dart';
import '../../data/repositories/farm_repository.dart';
import '../entry/widgets/category_selector.dart';
import '../entry/widgets/date_selector.dart';

class FarmSaleScreen extends ConsumerStatefulWidget {
  const FarmSaleScreen({super.key});

  @override
  ConsumerState<FarmSaleScreen> createState() => _FarmSaleScreenState();
}

class _FarmSaleScreenState extends ConsumerState<FarmSaleScreen> {
  final _kgController = TextEditingController();
  final _priceController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _merchantId;
  String? _fieldId;
  String _product = FarmProducts.kayisi;
  String? _variety = ApricotVarieties.all.first;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _kgController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final merchantsState = ref.watch(merchantsProvider);
    final fieldsState = ref.watch(activeFarmFieldsProvider);
    final salesState = ref.watch(farmSalesProvider);
    final varietiesState = ref.watch(farmApricotVarietiesProvider);
    final merchants = merchantsState.valueOrNull ?? const <MerchantModel>[];
    final fields = fieldsState.valueOrNull ?? const <FarmFieldModel>[];
    final varietyDocs = varietiesState.valueOrNull;
    final apricotOptions = varietyDocs == null || varietyDocs.isEmpty
        ? ApricotVarieties.all
        : varietyDocs
              .where((variety) => variety.active)
              .map((variety) => variety.name)
              .where((name) => name.trim().isNotEmpty)
              .toList();
    final selectedVariety = apricotOptions.contains(_variety) ? _variety : null;
    final kg = MoneyUtils.parse(_kgController.text);
    final price = MoneyUtils.parse(_priceController.text);
    final total = kg * price;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tarım Satış Gir'),
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
                    title: 'Satış kaydı',
                    message:
                        'Kaydedilince satış tutarı otomatik tüccar bakiyesine eklenir.',
                    icon: Icons.add_chart,
                    color: AppColors.income,
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
                  CategorySelector(
                    title: 'Ürün',
                    options: FarmProducts.all,
                    selected: _product,
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _product = value;
                        _variety = value == FarmProducts.kayisi
                            ? apricotOptions.isEmpty
                                  ? null
                                  : apricotOptions.first
                            : null;
                      });
                    },
                  ),
                  if (_product == FarmProducts.kayisi) ...[
                    const SizedBox(height: 14),
                    CategorySelector(
                      title: 'Kayısı çeşidi',
                      options: apricotOptions,
                      selected: selectedVariety,
                      onChanged: (value) => setState(() => _variety = value),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    controller: _kgController,
                    enabled: !_isSaving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Miktar kg',
                      prefixIcon: Icon(Icons.scale_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _priceController,
                    enabled: !_isSaving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Kg fiyatı',
                      prefixText: '₺ ',
                      prefixIcon: Icon(Icons.sell_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _TotalCard(total: total),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    _ErrorCard(message: _error!),
                  ],
                  const SizedBox(height: 22),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(
                      _isSaving ? 'Kaydediliyor...' : 'Satışı Kaydet',
                    ),
                  ),
                  const SizedBox(height: 16),
                  salesState.when(
                    loading: () =>
                        const _StateCard(message: 'Satışlar yükleniyor...'),
                    error: (_, __) =>
                        const _StateCard(message: 'Satış listesi okunamadı.'),
                    data: (sales) => _SaleList(
                      sales: sales,
                      merchants: merchants,
                      fields: fields,
                      isSaving: _isSaving,
                      onEdit: (sale) =>
                          _showEditSaleDialog(sale, merchants, fields),
                      onDelete: _confirmDeleteSale,
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

    final kg = MoneyUtils.parse(_kgController.text);
    final price = MoneyUtils.parse(_priceController.text);
    final validation = _validate(kg, price, _activeApricotOptions());
    if (validation != null) {
      setState(() {
        _error = validation;
        _isSaving = false;
      });
      return;
    }

    try {
      await ref
          .read(farmRepositoryProvider)
          .addSale(
            FarmSaleModel(
              id: '',
              merchantId: _merchantId!,
              date: AppDateUtils.dateKey(_selectedDate),
              productName: _product,
              productVariety: _product == FarmProducts.kayisi
                  ? _variety ?? ''
                  : '',
              amountKg: kg,
              priceTl: price,
              totalAmount: kg * price,
              seasonYear: _selectedDate.year,
              fieldId: _fieldId ?? '',
            ),
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Satış kaydedildi.')));
      context.pop();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error =
            'Satış kaydedilemedi. Tüccar ve internet bağlantısını kontrol edin.';
        _isSaving = false;
      });
    }
  }

  Future<void> _showEditSaleDialog(
    FarmSaleModel sale,
    List<MerchantModel> merchants,
    List<FarmFieldModel> fields,
  ) async {
    var selectedDate = AppDateUtils.dateFromKey(sale.date);
    var merchantId = sale.merchantId;
    var fieldId = sale.fieldId;
    var product = sale.productName.isEmpty
        ? FarmProducts.kayisi
        : sale.productName;
    var variety = sale.productVariety;
    final kgController = TextEditingController(
      text: _formatNumber(sale.amountKg),
    );
    final priceController = TextEditingController(
      text: _formatNumber(sale.priceTl),
    );

    final result = await showDialog<FarmSaleModel>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final apricotOptions = _activeApricotOptions();
            final selectedVariety = apricotOptions.contains(variety)
                ? variety
                : null;
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text('Satışı Düzenle'),
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
                      _FieldDropdown(
                        fields: fields,
                        selectedId: fieldId,
                        enabled: true,
                        onChanged: (value) =>
                            setDialogState(() => fieldId = value ?? ''),
                      ),
                      const SizedBox(height: 12),
                      CategorySelector(
                        title: 'Ürün',
                        options: FarmProducts.all,
                        selected: product,
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setDialogState(() {
                            product = value;
                            variety = value == FarmProducts.kayisi
                                ? apricotOptions.isEmpty
                                      ? ''
                                      : apricotOptions.first
                                : '';
                          });
                        },
                      ),
                      if (product == FarmProducts.kayisi) ...[
                        const SizedBox(height: 12),
                        CategorySelector(
                          title: 'Kayısı çeşidi',
                          options: apricotOptions,
                          selected: selectedVariety,
                          onChanged: (value) =>
                              setDialogState(() => variety = value ?? ''),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: kgController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Miktar kg',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Kg fiyatı',
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
                  onPressed: () {
                    final kg = MoneyUtils.parse(kgController.text);
                    final price = MoneyUtils.parse(priceController.text);
                    Navigator.of(context).pop(
                      sale.copyWith(
                        merchantId: merchantId,
                        date: AppDateUtils.dateKey(selectedDate),
                        productName: product,
                        productVariety: product == FarmProducts.kayisi
                            ? variety
                            : '',
                        amountKg: kg,
                        priceTl: price,
                        totalAmount: kg * price,
                        seasonYear: selectedDate.year,
                        fieldId: fieldId,
                      ),
                    );
                  },
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );

    kgController.dispose();
    priceController.dispose();
    if (result == null) {
      return;
    }
    if (result.merchantId.isEmpty ||
        result.amountKg <= 0 ||
        result.priceTl <= 0 ||
        (result.productName == FarmProducts.kayisi &&
            result.productVariety.isEmpty)) {
      _showSnack('Satış bilgisinde tüccar, ürün, kg ve fiyat doğru olmalı.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(farmRepositoryProvider).updateSale(result);
      _showSnack('Satış güncellendi.');
    } catch (_) {
      _showSnack('Satış güncellenemedi.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _confirmDeleteSale(FarmSaleModel sale) async {
    final confirmed = await _confirmDelete('Bu satış kaydı silinsin mi?');
    if (!confirmed) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ref.read(farmRepositoryProvider).deleteSale(sale);
      _showSnack('Satış silindi.');
    } catch (_) {
      _showSnack('Satış silinemedi.');
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

  String? _validate(double kg, double price, List<String> apricotOptions) {
    if (_merchantId == null || _merchantId!.isEmpty) {
      return 'Tüccar seçilmeli.';
    }
    if (_product == FarmProducts.kayisi && apricotOptions.isEmpty) {
      return 'Aktif kayısı cinsi eklenmeli.';
    }
    if (_product == FarmProducts.kayisi &&
        (_variety == null ||
            _variety!.isEmpty ||
            !apricotOptions.contains(_variety))) {
      return 'Kayısı çeşidi seçilmeli.';
    }
    if (kg <= 0) {
      return 'Miktar 0’dan büyük olmalı.';
    }
    if (price <= 0) {
      return 'Fiyat 0’dan büyük olmalı.';
    }
    return null;
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

class _SaleList extends StatelessWidget {
  const _SaleList({
    required this.sales,
    required this.merchants,
    required this.fields,
    required this.isSaving,
    required this.onEdit,
    required this.onDelete,
  });

  final List<FarmSaleModel> sales;
  final List<MerchantModel> merchants;
  final List<FarmFieldModel> fields;
  final bool isSaving;
  final ValueChanged<FarmSaleModel> onEdit;
  final ValueChanged<FarmSaleModel> onDelete;

  @override
  Widget build(BuildContext context) {
    final merchantNames = {
      for (final merchant in merchants) merchant.id: merchant.fullName,
    };
    final fieldNames = {for (final field in fields) field.id: field.name};
    final shown = sales.take(25).toList();

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
          Text('Son Satışlar', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            const Text(
              'Henüz satış yok.',
              style: TextStyle(color: AppColors.mutedText),
            )
          else
            for (final sale in shown)
              _SaleTile(
                sale: sale,
                merchantName: merchantNames[sale.merchantId] ?? 'Tüccar',
                fieldName: fieldNames[sale.fieldId] ?? 'Genel',
                isSaving: isSaving,
                onEdit: () => onEdit(sale),
                onDelete: () => onDelete(sale),
              ),
        ],
      ),
    );
  }
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({
    required this.sale,
    required this.merchantName,
    required this.fieldName,
    required this.isSaving,
    required this.onEdit,
    required this.onDelete,
  });

  final FarmSaleModel sale;
  final String merchantName;
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
                  sale.productLabel,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${sale.date} • $merchantName • $fieldName • ${_formatNumber(sale.amountKg)} kg',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  MoneyUtils.format(sale.totalAmount),
                  style: const TextStyle(
                    color: AppColors.income,
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

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.income.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.income.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calculate_outlined, color: AppColors.income),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Toplam tutar',
              style: TextStyle(color: AppColors.mutedText),
            ),
          ),
          Text(
            MoneyUtils.format(total),
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color color;

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
          Icon(icon, color: color),
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
