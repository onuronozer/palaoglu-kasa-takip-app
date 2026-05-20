import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/categories.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/money_utils.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/employee_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../entry/widgets/category_selector.dart';
import '../entry/widgets/date_selector.dart';
import '../entry/widgets/payment_source_selector.dart';

class EditTransactionScreen extends ConsumerWidget {
  const EditTransactionScreen({
    required this.transactionId,
    this.initialMonthKey,
    super.key,
  });

  final String transactionId;
  final String? initialMonthKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionState = ref.watch(transactionByIdProvider(transactionId));

    return transactionState.when(
      loading: () => const _LoadingScaffold(message: 'Kayıt yükleniyor...'),
      error: (_, __) => const _LoadingScaffold(
        message: 'Kayıt okunamadı. İnternet bağlantısını kontrol edin.',
      ),
      data: (transaction) {
        if (transaction == null) {
          return const _LoadingScaffold(message: 'Kayıt bulunamadı.');
        }

        return _EditTransactionForm(
          transaction: transaction,
          initialMonthKey: initialMonthKey,
        );
      },
    );
  }
}

class _EditTransactionForm extends ConsumerStatefulWidget {
  const _EditTransactionForm({required this.transaction, this.initialMonthKey});

  final TransactionModel transaction;
  final String? initialMonthKey;

  @override
  ConsumerState<_EditTransactionForm> createState() =>
      _EditTransactionFormState();
}

class _EditTransactionFormState extends ConsumerState<_EditTransactionForm> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _personController = TextEditingController();

  late DateTime _selectedDate;
  late String _type;
  String? _category;
  String? _employee;
  late String _paymentSource;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    _selectedDate = AppDateUtils.dateFromKey(transaction.date);
    _type = transaction.type;
    _category = transaction.category;
    _employee = transaction.type == TransactionTypes.isci
        ? transaction.person
        : null;
    _paymentSource = transaction.paymentSource;
    _amountController.text = transaction.amount.toStringAsFixed(0);
    _descriptionController.text = transaction.description;
    _personController.text = transaction.type == TransactionTypes.borc
        ? transaction.person
        : '';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _personController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final employees = ref.watch(activeEmployeesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kaydı Düzenle'),
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
                  _InfoCard(transaction: widget.transaction),
                  const SizedBox(height: 16),
                  DateSelector(
                    selectedDate: _selectedDate,
                    onChanged: (date) => setState(() => _selectedDate = date),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _type,
                    decoration: const InputDecoration(labelText: 'İşlem tipi'),
                    items: const [
                      DropdownMenuItem(
                        value: TransactionTypes.ciro,
                        child: Text('Ciro'),
                      ),
                      DropdownMenuItem(
                        value: TransactionTypes.masraf,
                        child: Text('Masraf'),
                      ),
                      DropdownMenuItem(
                        value: TransactionTypes.isci,
                        child: Text('İşçi Ödemesi'),
                      ),
                      DropdownMenuItem(
                        value: TransactionTypes.komisyon,
                        child: Text('İşletme Ortağı'),
                      ),
                      DropdownMenuItem(
                        value: TransactionTypes.banka,
                        child: Text('Bankaya Yatan'),
                      ),
                      DropdownMenuItem(
                        value: TransactionTypes.borc,
                        child: Text('Borç / Alacak'),
                      ),
                    ],
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _type = value;
                              _resetFieldsForType(value);
                            });
                          },
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
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_type == TransactionTypes.masraf) ...[
                    CategorySelector(
                      title: 'Masraf kategorisi',
                      options: AppCategories.expenseCategories,
                      selected: _category,
                      onChanged: (value) => setState(() => _category = value),
                    ),
                    const SizedBox(height: 14),
                    PaymentSourceSelector(
                      selected: _paymentSource,
                      onChanged: (value) {
                        setState(() => _paymentSource = value);
                      },
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (_type == TransactionTypes.isci) ...[
                    employees.when(
                      loading: () => const _StateCard(
                        message: 'Personeller yükleniyor...',
                      ),
                      error: (_, __) => const _StateCard(
                        message: 'Personel listesi okunamadı.',
                      ),
                      data: (items) {
                        final names = items.map((item) => item.name).toList();
                        final options = {
                          if (_employee != null && _employee!.isNotEmpty)
                            _employee!,
                          ...names,
                        }.toList();
                        return CategorySelector(
                          title: 'Personel',
                          options: options,
                          selected: _employee,
                          onChanged: (value) {
                            setState(() => _employee = value);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    PaymentSourceSelector(
                      selected: _paymentSource,
                      onChanged: (value) {
                        setState(() => _paymentSource = value);
                      },
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (_type == TransactionTypes.komisyon) ...[
                    PaymentSourceSelector(
                      selected: _paymentSource,
                      onChanged: (value) {
                        setState(() => _paymentSource = value);
                      },
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (_type == TransactionTypes.borc) ...[
                    TextField(
                      controller: _personController,
                      enabled: !_isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Kişi adı',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                    CategorySelector(
                      title: 'Borç / alacak tipi',
                      options: AppCategories.debtCategories,
                      selected: _category,
                      onChanged: (value) => setState(() => _category = value),
                    ),
                    const SizedBox(height: 14),
                  ],
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
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.expense.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.expense.withOpacity(0.35),
                        ),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.text),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(
                      _isSaving ? 'Kaydediliyor...' : 'Değişiklikleri Kaydet',
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
    final validationMessage = _validate(amount);
    if (validationMessage != null) {
      setState(() {
        _error = validationMessage;
        _isSaving = false;
      });
      return;
    }

    final updated = widget.transaction.copyWith(
      date: AppDateUtils.dateKey(_selectedDate),
      monthKey: AppDateUtils.monthKey(_selectedDate),
      type: _type,
      category: _categoryForSave(),
      person: _personForSave(),
      amount: amount,
      description: _descriptionController.text.trim(),
      paymentSource: _paymentSourceForSave(),
    );

    try {
      await ref.read(transactionRepositoryProvider).updateTransaction(updated);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Kayıt güncellendi.')));
      context.pop();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Kayıt güncellenemedi. İnternet bağlantısını kontrol edin.';
        _isSaving = false;
      });
    }
  }

  String? _validate(double amount) {
    if (amount <= 0) {
      return 'Tutar 0’dan büyük olmalı.';
    }
    if (_type == TransactionTypes.masraf &&
        (_category == null || _category!.isEmpty)) {
      return 'Masraf kategorisi seçilmeli.';
    }
    if (_type == TransactionTypes.isci &&
        (_employee == null || _employee!.isEmpty)) {
      return 'İşçi ödemesinde personel seçilmeli.';
    }
    if (_type == TransactionTypes.borc) {
      if (_personController.text.trim().isEmpty) {
        return 'Borç / alacak için kişi adı girilmeli.';
      }
      if (_category == null || _category!.isEmpty) {
        return 'Borç / alacak tipi seçilmeli.';
      }
    }
    return null;
  }

  void _resetFieldsForType(String type) {
    _employee = null;
    _personController.clear();
    _paymentSource = PaymentSources.cash;
    switch (type) {
      case TransactionTypes.ciro:
        _category = AppCategories.ciro;
        break;
      case TransactionTypes.masraf:
        _category = AppCategories.expenseCategories.first;
        break;
      case TransactionTypes.isci:
        _category = AppCategories.isci;
        break;
      case TransactionTypes.komisyon:
        _category = AppCategories.komisyon;
        break;
      case TransactionTypes.banka:
        _category = AppCategories.banka;
        break;
      case TransactionTypes.borc:
        _category = AppCategories.debtGiven;
        break;
    }
  }

  String _categoryForSave() {
    switch (_type) {
      case TransactionTypes.ciro:
        return AppCategories.ciro;
      case TransactionTypes.masraf:
        return _category ?? AppCategories.expenseCategories.first;
      case TransactionTypes.isci:
        return AppCategories.isci;
      case TransactionTypes.komisyon:
        return AppCategories.komisyon;
      case TransactionTypes.banka:
        return AppCategories.banka;
      case TransactionTypes.borc:
        return _category ?? AppCategories.debtGiven;
      default:
        return _category ?? _type;
    }
  }

  String _personForSave() {
    if (_type == TransactionTypes.isci) {
      return _employee ?? '';
    }
    if (_type == TransactionTypes.borc) {
      return _personController.text.trim();
    }
    return '';
  }

  String _paymentSourceForSave() {
    if (_type == TransactionTypes.masraf ||
        _type == TransactionTypes.isci ||
        _type == TransactionTypes.komisyon) {
      return _paymentSource;
    }
    return PaymentSources.cash;
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.transaction});

  final TransactionModel transaction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kayıt bilgisi', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            '${transaction.date} • ${transaction.typeLabel} • ${MoneyUtils.format(transaction.amount)}',
            style: const TextStyle(color: AppColors.mutedText),
          ),
        ],
      ),
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.mutedText),
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
