import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/farm_categories.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/money_utils.dart';
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
    final varietiesState = ref.watch(farmApricotVarietiesProvider);
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
