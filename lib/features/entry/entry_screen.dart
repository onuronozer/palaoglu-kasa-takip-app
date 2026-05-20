import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/categories.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/money_utils.dart';
import '../../data/models/app_user.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/employee_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../auth/auth_controller.dart';
import 'widgets/amount_input.dart';
import 'widgets/category_selector.dart';
import 'widgets/date_selector.dart';
import 'widgets/payment_source_selector.dart';

class EntryScreen extends ConsumerStatefulWidget {
  const EntryScreen({required this.entryType, this.initialMonthKey, super.key});

  final String entryType;
  final String? initialMonthKey;

  @override
  ConsumerState<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends ConsumerState<EntryScreen> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _personController = TextEditingController();

  late DateTime _selectedDate;
  String? _selectedCategory;
  String? _selectedEmployee;
  String _paymentSource = PaymentSources.cash;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initialMonth = AppDateUtils.monthFromKey(widget.initialMonthKey);
    final now = DateTime.now();
    final day = initialMonth.year == now.year && initialMonth.month == now.month
        ? now.day
        : 1;
    _selectedDate = DateTime(initialMonth.year, initialMonth.month, day);

    if (widget.entryType == TransactionTypes.borc) {
      _selectedCategory = AppCategories.debtGiven;
    }
    if (widget.entryType == TransactionTypes.komisyon) {
      _selectedEmployee = AppCategories.komisyon;
    }
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
    final appUser = ref.watch(currentAppUserProvider).valueOrNull;
    final title = _titleForType(widget.entryType);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
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
                  _IntroCard(title: title),
                  const SizedBox(height: 16),
                  DateSelector(
                    selectedDate: _selectedDate,
                    onChanged: (date) {
                      setState(() => _selectedDate = date);
                    },
                  ),
                  const SizedBox(height: 18),
                  AmountInput(
                    controller: _amountController,
                    enabled: !_isSubmitting,
                  ),
                  const SizedBox(height: 14),
                  if (widget.entryType == TransactionTypes.masraf) ...[
                    CategorySelector(
                      title: 'Masraf kategorisi',
                      options: AppCategories.expenseCategories,
                      selected: _selectedCategory,
                      onChanged: (value) {
                        setState(() => _selectedCategory = value);
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
                  if (widget.entryType == TransactionTypes.isci ||
                      widget.entryType == TransactionTypes.komisyon) ...[
                    _EmployeeSelector(
                      selectedEmployee: _selectedEmployee,
                      onChanged: (value) {
                        setState(() => _selectedEmployee = value);
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
                  if (widget.entryType == TransactionTypes.borc) ...[
                    TextField(
                      controller: _personController,
                      enabled: !_isSubmitting,
                      decoration: const InputDecoration(
                        labelText: 'Kişi adı',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                    CategorySelector(
                      title: 'Borç / alacak tipi',
                      options: AppCategories.debtCategories,
                      selected: _selectedCategory,
                      onChanged: (value) {
                        setState(() => _selectedCategory = value);
                      },
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextField(
                    controller: _descriptionController,
                    enabled: !_isSubmitting,
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
                  ElevatedButton(
                    onPressed: _isSubmitting || appUser == null
                        ? null
                        : () => _save(appUser),
                    child: Text(_isSubmitting ? 'Kaydediliyor...' : 'Kaydet'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save(AppUser appUser) async {
    setState(() {
      _error = null;
      _isSubmitting = true;
    });

    final amount = MoneyUtils.parse(_amountController.text);
    final validationMessage = _validate(amount);
    if (validationMessage != null) {
      setState(() {
        _error = validationMessage;
        _isSubmitting = false;
      });
      return;
    }

    final transaction = TransactionModel(
      id: '',
      date: AppDateUtils.dateKey(_selectedDate),
      monthKey: AppDateUtils.monthKey(_selectedDate),
      type: _typeForSave(),
      category: _categoryForSave(),
      person: _personForSave(),
      amount: amount,
      description: _descriptionController.text.trim(),
      createdByUid: appUser.uid,
      createdByName: appUser.displayName,
      paymentSource: _paymentSourceForSave(),
    );

    try {
      await ref.read(transactionRepositoryProvider).addTransaction(transaction);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Kayıt eklendi.')));
      context.pop();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Kayıt eklenemedi. İnternet bağlantısını kontrol edin.';
        _isSubmitting = false;
      });
    }
  }

  String? _validate(double amount) {
    if (amount <= 0) {
      return 'Tutar 0’dan büyük olmalı.';
    }

    if (widget.entryType == TransactionTypes.masraf &&
        (_selectedCategory == null || _selectedCategory!.isEmpty)) {
      return 'Masraf kategorisi seçilmeli.';
    }

    if ((widget.entryType == TransactionTypes.isci ||
            widget.entryType == TransactionTypes.komisyon) &&
        (_selectedEmployee == null || _selectedEmployee!.isEmpty)) {
      return 'İşçi ödemesinde personel veya işletme ortağı seçilmeli.';
    }

    if (widget.entryType == TransactionTypes.borc) {
      if (_personController.text.trim().isEmpty) {
        return 'Borç / alacak için kişi adı girilmeli.';
      }
      if (_selectedCategory == null || _selectedCategory!.isEmpty) {
        return 'Borç / alacak tipi seçilmeli.';
      }
    }

    return null;
  }

  String _categoryForSave() {
    switch (_typeForSave()) {
      case TransactionTypes.ciro:
        return AppCategories.ciro;
      case TransactionTypes.masraf:
        return _selectedCategory ?? '';
      case TransactionTypes.isci:
        return AppCategories.isci;
      case TransactionTypes.komisyon:
        return AppCategories.komisyon;
      case TransactionTypes.banka:
        return AppCategories.banka;
      case TransactionTypes.borc:
        return _selectedCategory ?? AppCategories.debtGiven;
      default:
        return widget.entryType;
    }
  }

  String _personForSave() {
    if (_typeForSave() == TransactionTypes.isci) {
      return _selectedEmployee ?? '';
    }
    if (_typeForSave() == TransactionTypes.borc) {
      return _personController.text.trim();
    }
    return '';
  }

  String _paymentSourceForSave() {
    final type = _typeForSave();
    if (type == TransactionTypes.masraf ||
        type == TransactionTypes.isci ||
        type == TransactionTypes.komisyon) {
      return _paymentSource;
    }
    return PaymentSources.cash;
  }

  String _typeForSave() {
    if ((widget.entryType == TransactionTypes.isci ||
            widget.entryType == TransactionTypes.komisyon) &&
        _selectedEmployee == AppCategories.komisyon) {
      return TransactionTypes.komisyon;
    }
    return widget.entryType;
  }

  String _titleForType(String type) {
    switch (type) {
      case TransactionTypes.ciro:
        return 'Ciro Gir';
      case TransactionTypes.masraf:
        return 'Masraf Gir';
      case TransactionTypes.isci:
        return 'İşçi Ödemesi Gir';
      case TransactionTypes.komisyon:
        return 'İşletme Ortağı Gir';
      case TransactionTypes.banka:
        return 'Bankaya Yatan Gir';
      case TransactionTypes.borc:
        return 'Borç / Alacak Gir';
      default:
        return 'Kayıt Gir';
    }
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.edit_note, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                const Text(
                  'Kaydı tek kez oluşturmak için buton işlem bitene kadar kilitlenir.',
                  style: TextStyle(color: AppColors.mutedText, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeSelector extends ConsumerWidget {
  const _EmployeeSelector({
    required this.selectedEmployee,
    required this.onChanged,
  });

  final String? selectedEmployee;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesState = ref.watch(activeEmployeesProvider);
    return employeesState.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (_, __) => const Text(
        'Personel listesi okunamadı.',
        style: TextStyle(color: AppColors.expense),
      ),
      data: (employees) {
        final options = [
          AppCategories.komisyon,
          ...employees.map((employee) => employee.name),
        ];

        return CategorySelector(
          title: 'Personel / İşletme Ortağı',
          options: options,
          selected: selectedEmployee,
          onChanged: onChanged,
        );
      },
    );
  }
}
