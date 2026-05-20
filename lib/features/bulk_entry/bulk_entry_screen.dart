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
import '../dashboard/widgets/month_selector.dart';

class BulkEntryScreen extends ConsumerStatefulWidget {
  const BulkEntryScreen({this.initialMonthKey, super.key});

  final String? initialMonthKey;

  @override
  ConsumerState<BulkEntryScreen> createState() => _BulkEntryScreenState();
}

class _BulkEntryScreenState extends ConsumerState<BulkEntryScreen> {
  late DateTime _selectedMonth;
  late List<TextEditingController> _ciroControllers;
  final _ciroDescriptionController = TextEditingController(
    text: 'Toplu ciro girişi',
  );
  final List<_EmployeePaymentDraft> _employeeDrafts = [];
  final List<_CreditCardExpenseDraft> _creditCardDrafts = [];
  final List<_MixedTransactionDraft> _mixedDrafts = [];
  bool _isSavingCiro = false;
  bool _isSavingEmployees = false;
  bool _isSavingCreditCard = false;
  bool _isSavingMixed = false;

  @override
  void initState() {
    super.initState();
    _selectedMonth = AppDateUtils.monthFromKey(widget.initialMonthKey);
    _buildCiroControllers();
    _employeeDrafts.add(_EmployeePaymentDraft(day: _defaultDay()));
    _creditCardDrafts.add(_CreditCardExpenseDraft(day: _defaultDay()));
    _mixedDrafts.add(_MixedTransactionDraft(day: _defaultDay()));
  }

  @override
  void dispose() {
    for (final controller in _ciroControllers) {
      controller.dispose();
    }
    _ciroDescriptionController.dispose();
    for (final draft in _employeeDrafts) {
      draft.dispose();
    }
    for (final draft in _creditCardDrafts) {
      draft.dispose();
    }
    for (final draft in _mixedDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appUser = ref.watch(currentAppUserProvider).valueOrNull;
    final activeEmployees = ref.watch(activeEmployeesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Toplu Giriş'),
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
                  _InfoCard(
                    title: 'Toplu kayıt',
                    message:
                        'Ciroda sadece tutar yazılan günler kaydedilir. İşçi, işletme ortağı ve kredi kartı harcamalarında satır ekleyebilirsin.',
                  ),
                  const SizedBox(height: 16),
                  _CiroBulkCard(
                    selectedMonth: _selectedMonth,
                    controllers: _ciroControllers,
                    descriptionController: _ciroDescriptionController,
                    isSaving: _isSavingCiro,
                    onSave: appUser == null ? null : () => _saveCiro(appUser),
                  ),
                  const SizedBox(height: 16),
                  _CreditCardBulkCard(
                    selectedMonth: _selectedMonth,
                    drafts: _creditCardDrafts,
                    isSaving: _isSavingCreditCard,
                    onAddRow: () {
                      setState(() {
                        _creditCardDrafts.add(
                          _CreditCardExpenseDraft(day: _defaultDay()),
                        );
                      });
                    },
                    onRemoveRow: (index) {
                      setState(() {
                        final removed = _creditCardDrafts.removeAt(index);
                        removed.dispose();
                        if (_creditCardDrafts.isEmpty) {
                          _creditCardDrafts.add(
                            _CreditCardExpenseDraft(day: _defaultDay()),
                          );
                        }
                      });
                    },
                    onChanged: () => setState(() {}),
                    onSave: appUser == null
                        ? null
                        : () => _saveCreditCardExpenses(appUser),
                  ),
                  const SizedBox(height: 16),
                  activeEmployees.when(
                    loading: () =>
                        const _StateCard(message: 'Personeller yükleniyor...'),
                    error: (_, __) => const _StateCard(
                      message: 'Personel listesi okunamadı.',
                    ),
                    data: (employees) {
                      return _EmployeeBulkCard(
                        selectedMonth: _selectedMonth,
                        employees: employees.map((item) => item.name).toList(),
                        drafts: _employeeDrafts,
                        isSaving: _isSavingEmployees,
                        onAddRow: () {
                          setState(() {
                            _employeeDrafts.add(
                              _EmployeePaymentDraft(day: _defaultDay()),
                            );
                          });
                        },
                        onRemoveRow: (index) {
                          setState(() {
                            final removed = _employeeDrafts.removeAt(index);
                            removed.dispose();
                            if (_employeeDrafts.isEmpty) {
                              _employeeDrafts.add(
                                _EmployeePaymentDraft(day: _defaultDay()),
                              );
                            }
                          });
                        },
                        onChanged: () => setState(() {}),
                        onSave: appUser == null
                            ? null
                            : () => _saveEmployeePayments(appUser),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  activeEmployees.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (employees) {
                      return _MixedBulkCard(
                        selectedMonth: _selectedMonth,
                        employees: employees.map((item) => item.name).toList(),
                        drafts: _mixedDrafts,
                        isSaving: _isSavingMixed,
                        onAddRow: () {
                          setState(() {
                            _mixedDrafts.add(
                              _MixedTransactionDraft(day: _defaultDay()),
                            );
                          });
                        },
                        onRemoveRow: (index) {
                          setState(() {
                            final removed = _mixedDrafts.removeAt(index);
                            removed.dispose();
                            if (_mixedDrafts.isEmpty) {
                              _mixedDrafts.add(
                                _MixedTransactionDraft(day: _defaultDay()),
                              );
                            }
                          });
                        },
                        onChanged: () => setState(() {}),
                        onSave: appUser == null
                            ? null
                            : () => _saveMixed(appUser),
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

  Future<void> _saveCiro(AppUser appUser) async {
    final transactions = <TransactionModel>[];
    final description = _ciroDescriptionController.text.trim();

    for (var index = 0; index < _ciroControllers.length; index++) {
      final amount = MoneyUtils.parse(_ciroControllers[index].text);
      if (amount <= 0) {
        continue;
      }

      final date = DateTime(
        _selectedMonth.year,
        _selectedMonth.month,
        index + 1,
      );
      transactions.add(
        TransactionModel(
          id: '',
          date: AppDateUtils.dateKey(date),
          monthKey: AppDateUtils.monthKey(date),
          type: TransactionTypes.ciro,
          category: AppCategories.ciro,
          person: '',
          amount: amount,
          description: description.isEmpty ? 'Toplu ciro girişi' : description,
          createdByUid: appUser.uid,
          createdByName: appUser.displayName,
        ),
      );
    }

    if (transactions.isEmpty) {
      _showSnack('Kaydedilecek ciro tutarı yok.');
      return;
    }

    setState(() => _isSavingCiro = true);
    try {
      await ref
          .read(transactionRepositoryProvider)
          .addTransactions(transactions);
      for (final controller in _ciroControllers) {
        controller.clear();
      }
      _showSnack('${transactions.length} ciro kaydı eklendi.');
    } catch (_) {
      _showSnack(
        'Toplu ciro kaydedilemedi. İnternet bağlantısını kontrol edin.',
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingCiro = false);
      }
    }
  }

  Future<void> _saveEmployeePayments(AppUser appUser) async {
    final transactions = <TransactionModel>[];

    for (final draft in _employeeDrafts) {
      final amount = MoneyUtils.parse(draft.amountController.text);
      if (amount <= 0) {
        continue;
      }

      if (draft.employee == null || draft.employee!.trim().isEmpty) {
        _showSnack(
          'Tutar girilen her satırda personel veya işletme ortağı seçilmeli.',
        );
        return;
      }

      final isPartnerPayment = draft.employee == AppCategories.komisyon;
      final date = DateTime(
        _selectedMonth.year,
        _selectedMonth.month,
        draft.day,
      );
      final description = draft.descriptionController.text.trim();
      final defaultDescription = isPartnerPayment
          ? 'Toplu işletme ortağı ödemesi'
          : 'Toplu işçi ödemesi girişi';
      transactions.add(
        TransactionModel(
          id: '',
          date: AppDateUtils.dateKey(date),
          monthKey: AppDateUtils.monthKey(date),
          type: isPartnerPayment
              ? TransactionTypes.komisyon
              : TransactionTypes.isci,
          category: isPartnerPayment
              ? AppCategories.komisyon
              : AppCategories.isci,
          person: isPartnerPayment ? '' : draft.employee!,
          amount: amount,
          paymentSource: draft.paymentSource,
          description: description.isEmpty ? defaultDescription : description,
          createdByUid: appUser.uid,
          createdByName: appUser.displayName,
        ),
      );
    }

    if (transactions.isEmpty) {
      _showSnack('Kaydedilecek işçi ödemesi yok.');
      return;
    }

    setState(() => _isSavingEmployees = true);
    try {
      await ref
          .read(transactionRepositoryProvider)
          .addTransactions(transactions);
      setState(() {
        for (final draft in _employeeDrafts) {
          draft.dispose();
        }
        _employeeDrafts
          ..clear()
          ..add(_EmployeePaymentDraft(day: _defaultDay()));
      });
      _showSnack('${transactions.length} işçi ödemesi eklendi.');
    } catch (_) {
      _showSnack('Toplu işçi ödemesi kaydedilemedi.');
    } finally {
      if (mounted) {
        setState(() => _isSavingEmployees = false);
      }
    }
  }

  Future<void> _saveCreditCardExpenses(AppUser appUser) async {
    final transactions = <TransactionModel>[];

    for (final draft in _creditCardDrafts) {
      final amount = MoneyUtils.parse(draft.amountController.text);
      if (amount <= 0) {
        continue;
      }

      final date = DateTime(
        _selectedMonth.year,
        _selectedMonth.month,
        draft.day,
      );
      final description = draft.descriptionController.text.trim();
      transactions.add(
        TransactionModel(
          id: '',
          date: AppDateUtils.dateKey(date),
          monthKey: AppDateUtils.monthKey(date),
          type: TransactionTypes.masraf,
          category: AppCategories.creditCard,
          person: '',
          amount: amount,
          paymentSource: PaymentSources.bank,
          description: description.isEmpty
              ? 'Kredi kartı harcaması'
              : description,
          createdByUid: appUser.uid,
          createdByName: appUser.displayName,
        ),
      );
    }

    if (transactions.isEmpty) {
      _showSnack('Kaydedilecek kredi kartı harcaması yok.');
      return;
    }

    setState(() => _isSavingCreditCard = true);
    try {
      await ref
          .read(transactionRepositoryProvider)
          .addTransactions(transactions);
      setState(() {
        for (final draft in _creditCardDrafts) {
          draft.dispose();
        }
        _creditCardDrafts
          ..clear()
          ..add(_CreditCardExpenseDraft(day: _defaultDay()));
      });
      _showSnack('${transactions.length} kredi kartı harcaması eklendi.');
    } catch (_) {
      _showSnack('Kredi kartı harcamaları kaydedilemedi.');
    } finally {
      if (mounted) {
        setState(() => _isSavingCreditCard = false);
      }
    }
  }

  Future<void> _saveMixed(AppUser appUser) async {
    final transactions = <TransactionModel>[];

    for (final draft in _mixedDrafts) {
      final amount = MoneyUtils.parse(draft.amountController.text);
      if (amount <= 0) {
        continue;
      }

      final validationMessage = draft.validate();
      if (validationMessage != null) {
        _showSnack(validationMessage);
        return;
      }

      final date = DateTime(
        _selectedMonth.year,
        _selectedMonth.month,
        draft.day,
      );
      final description = draft.descriptionController.text.trim();
      transactions.add(
        TransactionModel(
          id: '',
          date: AppDateUtils.dateKey(date),
          monthKey: AppDateUtils.monthKey(date),
          type: draft.type,
          category: draft.categoryForSave,
          person: draft.personForSave,
          amount: amount,
          paymentSource: draft.paymentSourceForSave,
          description: description.isEmpty ? 'Toplu kayıt' : description,
          createdByUid: appUser.uid,
          createdByName: appUser.displayName,
        ),
      );
    }

    if (transactions.isEmpty) {
      _showSnack('Kaydedilecek toplu işlem yok.');
      return;
    }

    setState(() => _isSavingMixed = true);
    try {
      await ref
          .read(transactionRepositoryProvider)
          .addTransactions(transactions);
      setState(() {
        for (final draft in _mixedDrafts) {
          draft.dispose();
        }
        _mixedDrafts
          ..clear()
          ..add(_MixedTransactionDraft(day: _defaultDay()));
      });
      _showSnack('${transactions.length} toplu işlem eklendi.');
    } catch (_) {
      _showSnack('Toplu işlemler kaydedilemedi.');
    } finally {
      if (mounted) {
        setState(() => _isSavingMixed = false);
      }
    }
  }

  void _changeMonth(DateTime month) {
    setState(() {
      _selectedMonth = month;
      for (final controller in _ciroControllers) {
        controller.dispose();
      }
      _buildCiroControllers();
      for (final draft in _employeeDrafts) {
        draft.day = draft.day
            .clamp(1, AppDateUtils.daysInMonth(_selectedMonth))
            .toInt();
      }
      for (final draft in _creditCardDrafts) {
        draft.day = draft.day
            .clamp(1, AppDateUtils.daysInMonth(_selectedMonth))
            .toInt();
      }
      for (final draft in _mixedDrafts) {
        draft.day = draft.day
            .clamp(1, AppDateUtils.daysInMonth(_selectedMonth))
            .toInt();
      }
    });
  }

  void _buildCiroControllers() {
    _ciroControllers = List.generate(
      AppDateUtils.daysInMonth(_selectedMonth),
      (_) => TextEditingController(),
    );
  }

  int _defaultDay() {
    final now = DateTime.now();
    if (now.year == _selectedMonth.year && now.month == _selectedMonth.month) {
      return now.day;
    }
    return 1;
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.message});

  final String title;
  final String message;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.playlist_add, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 5),
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

class _CiroBulkCard extends StatelessWidget {
  const _CiroBulkCard({
    required this.selectedMonth,
    required this.controllers,
    required this.descriptionController,
    required this.isSaving,
    required this.onSave,
  });

  final DateTime selectedMonth;
  final List<TextEditingController> controllers;
  final TextEditingController descriptionController;
  final bool isSaving;
  final VoidCallback? onSave;

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
          Text('Günlük Ciro', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: descriptionController,
            enabled: !isSaving,
            decoration: const InputDecoration(
              labelText: 'Açıklama',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: controllers.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 74,
            ),
            itemBuilder: (context, index) {
              return TextField(
                controller: controllers[index],
                enabled: !isSaving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: '${index + 1}. gün',
                  prefixText: '₺ ',
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: isSaving ? null : onSave,
            icon: const Icon(Icons.save_outlined),
            label: Text(
              isSaving ? 'Kaydediliyor...' : 'Ciro Kayıtlarını Kaydet',
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeBulkCard extends StatelessWidget {
  const _EmployeeBulkCard({
    required this.selectedMonth,
    required this.employees,
    required this.drafts,
    required this.isSaving,
    required this.onAddRow,
    required this.onRemoveRow,
    required this.onChanged,
    required this.onSave,
  });

  final DateTime selectedMonth;
  final List<String> employees;
  final List<_EmployeePaymentDraft> drafts;
  final bool isSaving;
  final VoidCallback onAddRow;
  final ValueChanged<int> onRemoveRow;
  final VoidCallback onChanged;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final days = List.generate(
      AppDateUtils.daysInMonth(selectedMonth),
      (index) => index + 1,
    );
    final employeeOptions = [AppCategories.komisyon, ...employees];

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
                  'İşçi Ödemeleri',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Satır ekle',
                onPressed: isSaving ? null : onAddRow,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < drafts.length; index++)
            _EmployeePaymentRow(
              draft: drafts[index],
              days: days,
              employees: employeeOptions,
              index: index,
              isSaving: isSaving,
              onRemove: () => onRemoveRow(index),
              onChanged: onChanged,
            ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: isSaving ? null : onAddRow,
            icon: const Icon(Icons.add),
            label: const Text('Satır Ekle'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: isSaving ? null : onSave,
            icon: const Icon(Icons.save_outlined),
            label: Text(
              isSaving ? 'Kaydediliyor...' : 'Ödemeleri Kaydet',
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeePaymentRow extends StatelessWidget {
  const _EmployeePaymentRow({
    required this.draft,
    required this.days,
    required this.employees,
    required this.index,
    required this.isSaving,
    required this.onRemove,
    required this.onChanged,
  });

  final _EmployeePaymentDraft draft;
  final List<int> days;
  final List<String> employees;
  final int index;
  final bool isSaving;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${index + 1}. ödeme',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Satırı kaldır',
                onPressed: isSaving ? null : onRemove,
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
                  onChanged: isSaving
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          draft.day = value;
                          onChanged();
                        },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: draft.employee,
                  decoration: const InputDecoration(
                    labelText: 'Personel / Ortak',
                  ),
                  items: [
                    for (final employee in employees)
                      DropdownMenuItem(value: employee, child: Text(employee)),
                  ],
                  onChanged: isSaving
                      ? null
                      : (value) {
                          draft.employee = value;
                          onChanged();
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: draft.amountController,
            enabled: !isSaving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Tutar',
              prefixText: '₺ ',
            ),
          ),
          const SizedBox(height: 10),
          _PaymentSourceDropdown(
            value: draft.paymentSource,
            enabled: !isSaving,
            onChanged: (value) {
              draft.paymentSource = value;
              onChanged();
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: draft.descriptionController,
            enabled: !isSaving,
            decoration: const InputDecoration(
              labelText: 'Açıklama',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditCardBulkCard extends StatelessWidget {
  const _CreditCardBulkCard({
    required this.selectedMonth,
    required this.drafts,
    required this.isSaving,
    required this.onAddRow,
    required this.onRemoveRow,
    required this.onChanged,
    required this.onSave,
  });

  final DateTime selectedMonth;
  final List<_CreditCardExpenseDraft> drafts;
  final bool isSaving;
  final VoidCallback onAddRow;
  final ValueChanged<int> onRemoveRow;
  final VoidCallback onChanged;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final days = List.generate(
      AppDateUtils.daysInMonth(selectedMonth),
      (index) => index + 1,
    );
    final total = drafts.fold<double>(
      0,
      (sum, draft) => sum + MoneyUtils.parse(draft.amountController.text),
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
                  'Kredi Kartı Harcamaları',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Satır ekle',
                onPressed: isSaving ? null : onAddRow,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Mobil bankacılıktaki kredi kartı kalemlerini buraya yaz; toplamı uygulama hesaplar.',
            style: TextStyle(color: AppColors.mutedText, fontSize: 12),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < drafts.length; index++)
            _CreditCardExpenseRow(
              draft: drafts[index],
              days: days,
              index: index,
              isSaving: isSaving,
              onRemove: () => onRemoveRow(index),
              onChanged: onChanged,
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Toplam Kredi Kartı',
                    style: TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  MoneyUtils.format(total),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: isSaving ? null : onAddRow,
            icon: const Icon(Icons.add),
            label: const Text('Satır Ekle'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: isSaving ? null : onSave,
            icon: const Icon(Icons.save_outlined),
            label: Text(
              isSaving ? 'Kaydediliyor...' : 'Kredi Kartını Kaydet',
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditCardExpenseRow extends StatelessWidget {
  const _CreditCardExpenseRow({
    required this.draft,
    required this.days,
    required this.index,
    required this.isSaving,
    required this.onRemove,
    required this.onChanged,
  });

  final _CreditCardExpenseDraft draft;
  final List<int> days;
  final int index;
  final bool isSaving;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${index + 1}. harcama',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Satırı kaldır',
                onPressed: isSaving ? null : onRemove,
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
                  onChanged: isSaving
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          draft.day = value;
                          onChanged();
                        },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: draft.amountController,
                  enabled: !isSaving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => onChanged(),
                  decoration: const InputDecoration(
                    labelText: 'Tutar',
                    prefixText: '₺ ',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: draft.descriptionController,
            enabled: !isSaving,
            decoration: const InputDecoration(
              labelText: 'Açıklama',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
        ],
      ),
    );
  }
}

class _MixedBulkCard extends StatelessWidget {
  const _MixedBulkCard({
    required this.selectedMonth,
    required this.employees,
    required this.drafts,
    required this.isSaving,
    required this.onAddRow,
    required this.onRemoveRow,
    required this.onChanged,
    required this.onSave,
  });

  final DateTime selectedMonth;
  final List<String> employees;
  final List<_MixedTransactionDraft> drafts;
  final bool isSaving;
  final VoidCallback onAddRow;
  final ValueChanged<int> onRemoveRow;
  final VoidCallback onChanged;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final days = List.generate(
      AppDateUtils.daysInMonth(selectedMonth),
      (index) => index + 1,
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
                  'Karışık Toplu Giriş',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Satır ekle',
                onPressed: isSaving ? null : onAddRow,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Masraf, bankaya yatan, borç/alacak, ciro, işçi ödemesi ve işletme ortağı ödemesini aynı listede toplu kaydedebilirsin.',
            style: TextStyle(color: AppColors.mutedText, fontSize: 12),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < drafts.length; index++)
            _MixedTransactionRow(
              draft: drafts[index],
              days: days,
              employees: employees,
              index: index,
              isSaving: isSaving,
              onRemove: () => onRemoveRow(index),
              onChanged: onChanged,
            ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: isSaving ? null : onAddRow,
            icon: const Icon(Icons.add),
            label: const Text('Satır Ekle'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: isSaving ? null : onSave,
            icon: const Icon(Icons.save_outlined),
            label: Text(
              isSaving ? 'Kaydediliyor...' : 'Toplu İşlemleri Kaydet',
            ),
          ),
        ],
      ),
    );
  }
}

class _MixedTransactionRow extends StatelessWidget {
  const _MixedTransactionRow({
    required this.draft,
    required this.days,
    required this.employees,
    required this.index,
    required this.isSaving,
    required this.onRemove,
    required this.onChanged,
  });

  final _MixedTransactionDraft draft;
  final List<int> days;
  final List<String> employees;
  final int index;
  final bool isSaving;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${index + 1}. işlem',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Satırı kaldır',
                onPressed: isSaving ? null : onRemove,
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
                  onChanged: isSaving
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          draft.day = value;
                          onChanged();
                        },
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
                      value: TransactionTypes.ciro,
                      child: Text('Ciro'),
                    ),
                    DropdownMenuItem(
                      value: TransactionTypes.masraf,
                      child: Text('Masraf'),
                    ),
                    DropdownMenuItem(
                      value: TransactionTypes.isci,
                      child: Text('İşçi'),
                    ),
                    DropdownMenuItem(
                      value: TransactionTypes.komisyon,
                      child: Text('İşletme Ortağı'),
                    ),
                    DropdownMenuItem(
                      value: TransactionTypes.banka,
                      child: Text('Banka'),
                    ),
                    DropdownMenuItem(
                      value: TransactionTypes.borc,
                      child: Text('Borç'),
                    ),
                  ],
                  onChanged: isSaving
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          draft.setType(value);
                          onChanged();
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (draft.type == TransactionTypes.masraf)
            DropdownButtonFormField<String>(
              value: draft.category,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: [
                for (final category in AppCategories.expenseCategories)
                  DropdownMenuItem(value: category, child: Text(category)),
              ],
              onChanged: isSaving
                  ? null
                  : (value) {
                      draft.category = value;
                      onChanged();
                    },
            ),
          if (draft.type == TransactionTypes.isci)
            DropdownButtonFormField<String>(
              value: draft.employee,
              decoration: const InputDecoration(labelText: 'Personel'),
              items: [
                for (final employee in employees)
                  DropdownMenuItem(value: employee, child: Text(employee)),
              ],
              onChanged: isSaving
                  ? null
                  : (value) {
                      draft.employee = value;
                      onChanged();
                    },
            ),
          if (draft.type == TransactionTypes.masraf ||
              draft.type == TransactionTypes.isci ||
              draft.type == TransactionTypes.komisyon) ...[
            const SizedBox(height: 10),
            _PaymentSourceDropdown(
              value: draft.paymentSource,
              enabled: !isSaving,
              onChanged: (value) {
                draft.paymentSource = value;
                onChanged();
              },
            ),
          ],
          if (draft.type == TransactionTypes.borc) ...[
            DropdownButtonFormField<String>(
              value: draft.category,
              decoration: const InputDecoration(labelText: 'Borç tipi'),
              items: const [
                DropdownMenuItem(
                  value: AppCategories.debtGiven,
                  child: Text('Verilen Borç'),
                ),
                DropdownMenuItem(
                  value: AppCategories.debtPayment,
                  child: Text('Alınan Ödeme'),
                ),
              ],
              onChanged: isSaving
                  ? null
                  : (value) {
                      draft.category = value;
                      onChanged();
                    },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: draft.personController,
              enabled: !isSaving,
              decoration: const InputDecoration(
                labelText: 'Kişi adı',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
          ],
          if (draft.type == TransactionTypes.masraf ||
              draft.type == TransactionTypes.isci ||
              draft.type == TransactionTypes.komisyon ||
              draft.type == TransactionTypes.borc)
            const SizedBox(height: 10),
          TextField(
            controller: draft.amountController,
            enabled: !isSaving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Tutar',
              prefixText: '₺ ',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: draft.descriptionController,
            enabled: !isSaving,
            decoration: const InputDecoration(
              labelText: 'Açıklama',
              prefixIcon: Icon(Icons.notes_outlined),
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

class _EmployeePaymentDraft {
  _EmployeePaymentDraft({required this.day, this.employee});

  int day;
  String? employee;
  String paymentSource = PaymentSources.cash;
  final amountController = TextEditingController();
  final descriptionController = TextEditingController(
    text: 'Toplu işçi ödemesi',
  );

  void dispose() {
    amountController.dispose();
    descriptionController.dispose();
  }
}

class _CreditCardExpenseDraft {
  _CreditCardExpenseDraft({required this.day});

  int day;
  final amountController = TextEditingController();
  final descriptionController = TextEditingController();

  void dispose() {
    amountController.dispose();
    descriptionController.dispose();
  }
}

class _MixedTransactionDraft {
  _MixedTransactionDraft({required this.day});

  int day;
  String type = TransactionTypes.masraf;
  String? category = AppCategories.expenseCategories.first;
  String? employee;
  String paymentSource = PaymentSources.cash;
  final personController = TextEditingController();
  final amountController = TextEditingController();
  final descriptionController = TextEditingController();

  void setType(String value) {
    type = value;
    employee = null;
    personController.clear();

    switch (value) {
      case TransactionTypes.ciro:
        category = AppCategories.ciro;
        paymentSource = PaymentSources.cash;
        descriptionController.text = 'Toplu ciro';
        break;
      case TransactionTypes.masraf:
        category = AppCategories.expenseCategories.first;
        paymentSource = PaymentSources.cash;
        descriptionController.text = 'Toplu masraf';
        break;
      case TransactionTypes.isci:
        category = AppCategories.isci;
        paymentSource = PaymentSources.cash;
        descriptionController.text = 'Toplu işçi ödemesi';
        break;
      case TransactionTypes.komisyon:
        category = AppCategories.komisyon;
        paymentSource = PaymentSources.cash;
        descriptionController.text = 'Toplu işletme ortağı ödemesi';
        break;
      case TransactionTypes.banka:
        category = AppCategories.banka;
        paymentSource = PaymentSources.cash;
        descriptionController.text = 'Toplu bankaya yatan';
        break;
      case TransactionTypes.borc:
        category = AppCategories.debtGiven;
        paymentSource = PaymentSources.cash;
        descriptionController.text = 'Toplu borç / alacak';
        break;
    }
  }

  String get categoryForSave {
    switch (type) {
      case TransactionTypes.ciro:
        return AppCategories.ciro;
      case TransactionTypes.masraf:
        return category ?? AppCategories.expenseCategories.first;
      case TransactionTypes.isci:
        return AppCategories.isci;
      case TransactionTypes.komisyon:
        return AppCategories.komisyon;
      case TransactionTypes.banka:
        return AppCategories.banka;
      case TransactionTypes.borc:
        return category ?? AppCategories.debtGiven;
      default:
        return category ?? type;
    }
  }

  String get personForSave {
    if (type == TransactionTypes.isci) {
      return employee ?? '';
    }
    if (type == TransactionTypes.borc) {
      return personController.text.trim();
    }
    return '';
  }

  String get paymentSourceForSave {
    if (type == TransactionTypes.masraf ||
        type == TransactionTypes.isci ||
        type == TransactionTypes.komisyon) {
      return paymentSource;
    }
    return PaymentSources.cash;
  }

  String? validate() {
    if (type == TransactionTypes.masraf &&
        (category == null || category!.isEmpty)) {
      return 'Masraf satırında kategori seçilmeli.';
    }

    if (type == TransactionTypes.isci &&
        (employee == null || employee!.isEmpty)) {
      return 'İşçi satırında personel seçilmeli.';
    }

    if (type == TransactionTypes.borc) {
      if (category == null || category!.isEmpty) {
        return 'Borç satırında işlem tipi seçilmeli.';
      }
      if (personController.text.trim().isEmpty) {
        return 'Borç satırında kişi adı girilmeli.';
      }
    }

    return null;
  }

  void dispose() {
    personController.dispose();
    amountController.dispose();
    descriptionController.dispose();
  }
}

class _PaymentSourceDropdown extends StatelessWidget {
  const _PaymentSourceDropdown({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: const InputDecoration(labelText: 'Ödeme kaynağı'),
      items: [
        for (final source in PaymentSources.all)
          DropdownMenuItem(
            value: source,
            child: Text(PaymentSources.label(source)),
          ),
      ],
      onChanged: enabled
          ? (value) {
              if (value == null) {
                return;
              }
              onChanged(value);
            }
          : null,
    );
  }
}
