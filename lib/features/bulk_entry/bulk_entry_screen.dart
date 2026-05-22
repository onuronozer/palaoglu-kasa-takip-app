import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/categories.dart';
import '../../core/ocr/ocr_image_reader.dart';
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
  final List<TextEditingController> _creditCardControllers = [];
  final List<_MixedTransactionDraft> _mixedDrafts = [];
  final List<_DesktopKiraathaneDraft> _desktopDrafts = [];
  bool _isSavingCiro = false;
  bool _isSavingEmployees = false;
  bool _isSavingCreditCard = false;
  bool _isSavingMixed = false;
  bool _isSavingDesktop = false;
  bool _isReadingCreditCardOcr = false;

  @override
  void initState() {
    super.initState();
    _selectedMonth = AppDateUtils.monthFromKey(widget.initialMonthKey);
    _buildCiroControllers();
    _addCreditCardControllers(20);
    _employeeDrafts.add(_EmployeePaymentDraft(day: _defaultDay()));
    _mixedDrafts.add(_MixedTransactionDraft(day: _defaultDay()));
    _addDesktopRows(10);
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
    for (final controller in _creditCardControllers) {
      controller.dispose();
    }
    for (final draft in _mixedDrafts) {
      draft.dispose();
    }
    for (final draft in _desktopDrafts) {
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 900) {
              return activeEmployees.when(
                loading: () => const Center(
                    child: _StateCard(message: 'Personeller yükleniyor...')),
                error: (_, __) => const Center(
                  child: _StateCard(message: 'Personel listesi okunamadı.'),
                ),
                data: (employees) {
                  return _KiraathaneDesktopBulkPanel(
                    selectedMonth: _selectedMonth,
                    rows: _desktopDrafts,
                    employees: employees.map((item) => item.name).toList(),
                    isSaving: _isSavingDesktop,
                    isReadingOcr: _isReadingCreditCardOcr,
                    appUser: appUser,
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
                    onReadCreditCardOcr: _readCreditCardOcrToDesktopRows,
                    onSave:
                        appUser == null ? null : () => _saveDesktop(appUser),
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
                        onSave:
                            appUser == null ? null : () => _saveCiro(appUser),
                      ),
                      const SizedBox(height: 16),
                      _CreditCardBulkCard(
                        controllers: _creditCardControllers,
                        isSaving: _isSavingCreditCard,
                        isReadingOcr: _isReadingCreditCardOcr,
                        onReadOcr: _readCreditCardOcrToBoxes,
                        onAddBoxes: () {
                          setState(() {
                            _addCreditCardControllers(5);
                          });
                        },
                        onChanged: () => setState(() {}),
                        onSave: appUser == null
                            ? null
                            : () => _saveCreditCardExpenses(appUser),
                      ),
                      const SizedBox(height: 16),
                      activeEmployees.when(
                        loading: () => const _StateCard(
                          message: 'Personeller yükleniyor...',
                        ),
                        error: (_, __) => const _StateCard(
                          message: 'Personel listesi okunamadı.',
                        ),
                        data: (employees) {
                          return _EmployeeBulkCard(
                            selectedMonth: _selectedMonth,
                            employees:
                                employees.map((item) => item.name).toList(),
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
                            employees:
                                employees.map((item) => item.name).toList(),
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
            );
          },
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
          category:
              isPartnerPayment ? AppCategories.komisyon : AppCategories.isci,
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
    final date = DateTime(
      _selectedMonth.year,
      _selectedMonth.month,
      _defaultDay(),
    );

    for (final controller in _creditCardControllers) {
      final amount = MoneyUtils.parse(controller.text);
      if (amount <= 0) {
        continue;
      }

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
          description: 'Kredi kartı harcaması',
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
        for (final controller in _creditCardControllers) {
          controller.dispose();
        }
        _creditCardControllers.clear();
        _addCreditCardControllers(20);
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

  Future<void> _saveDesktop(AppUser appUser) async {
    final transactions = <TransactionModel>[];
    final employeeNames = ref
            .read(activeEmployeesProvider)
            .valueOrNull
            ?.map((e) => e.name)
            .toList() ??
        const <String>[];

    for (var index = 0; index < _desktopDrafts.length; index++) {
      final draft = _desktopDrafts[index];
      if (!draft.hasAmount) {
        continue;
      }

      final validationMessage = draft.validate(employeeNames);
      if (validationMessage != null) {
        _showSnack('${index + 1}. satır: $validationMessage');
        return;
      }

      final date = DateTime(
        _selectedMonth.year,
        _selectedMonth.month,
        draft.day,
      );
      transactions.add(draft.toTransaction(
        date: date,
        appUser: appUser,
      ));
    }

    if (transactions.isEmpty) {
      _showSnack('Kaydedilecek satır yok.');
      return;
    }

    setState(() => _isSavingDesktop = true);
    try {
      await ref
          .read(transactionRepositoryProvider)
          .addTransactions(transactions);
      setState(() {
        for (final draft in _desktopDrafts) {
          draft.dispose();
        }
        _desktopDrafts.clear();
        _addDesktopRows(10);
      });
      _showSnack('${transactions.length} kayıt eklendi.');
    } catch (_) {
      _showSnack('Bilgisayar hızlı giriş kayıtları kaydedilemedi.');
    } finally {
      if (mounted) {
        setState(() => _isSavingDesktop = false);
      }
    }
  }

  Future<void> _readCreditCardOcrToBoxes() async {
    final amounts = await _pickCreditCardOcrAmounts();
    if (amounts == null || amounts.isEmpty) {
      return;
    }

    setState(() {
      for (final amount in amounts) {
        var targetIndex = _creditCardControllers.indexWhere(
          (controller) => controller.text.trim().isEmpty,
        );
        if (targetIndex == -1) {
          _addCreditCardControllers(5);
          targetIndex = _creditCardControllers.indexWhere(
            (controller) => controller.text.trim().isEmpty,
          );
        }
        _creditCardControllers[targetIndex].text =
            _formatCreditCardOcrAmountInput(amount);
      }
    });
  }

  Future<void> _readCreditCardOcrToDesktopRows() async {
    final amounts = await _pickCreditCardOcrAmounts();
    if (amounts == null || amounts.isEmpty) {
      return;
    }

    setState(() {
      for (final amount in amounts) {
        final row = _findEmptyDesktopRowForOcr();
        row.day = _defaultDay();
        row.setType(_DesktopKiraathaneType.creditCard);
        row.amountController.text = _formatCreditCardOcrAmountInput(amount);
      }
    });
  }

  Future<List<double>?> _pickCreditCardOcrAmounts() async {
    if (_isReadingCreditCardOcr) {
      return null;
    }

    setState(() => _isReadingCreditCardOcr = true);
    try {
      final result = await pickImageAndReadOcrText();
      if (result == null) {
        _showSnack('Görsel seçilmedi.');
        return null;
      }

      final amounts = _extractCreditCardOcrAmounts(result.text);
      if (amounts.isEmpty) {
        _showSnack('OCR yazıyı okudu ama tutar bulamadı.');
        return const <double>[];
      }

      final total = amounts.fold<double>(0, (sum, amount) => sum + amount);
      _showSnack(
        '${amounts.length} tutar okundu. Toplam ${_formatCreditCardOcrTotal(total)}.',
      );
      return amounts;
    } catch (error) {
      _showSnack(_friendlyOcrError(error));
      return null;
    } finally {
      if (mounted) {
        setState(() => _isReadingCreditCardOcr = false);
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
      for (final draft in _mixedDrafts) {
        draft.day = draft.day
            .clamp(1, AppDateUtils.daysInMonth(_selectedMonth))
            .toInt();
      }
      for (final draft in _desktopDrafts) {
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

  void _addCreditCardControllers(int count) {
    _creditCardControllers.addAll(
      List.generate(count, (_) => TextEditingController()),
    );
  }

  void _addDesktopRows(int count) {
    _desktopDrafts.addAll(
      List.generate(count, (_) => _DesktopKiraathaneDraft(day: _defaultDay())),
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
      final kept = <_DesktopKiraathaneDraft>[];
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

  _DesktopKiraathaneDraft _findEmptyDesktopRowForOcr() {
    final existingIndex = _desktopDrafts.indexWhere((draft) => draft.isEmpty);
    if (existingIndex != -1) {
      return _desktopDrafts[existingIndex];
    }
    _addDesktopRows(5);
    return _desktopDrafts.firstWhere((draft) => draft.isEmpty);
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

final _creditCardOcrAmountPattern = RegExp(
  r'[-−]?\s*(?:\d{1,3}(?:[.\s]\d{3})+|\d+),\d{2}\s*(?:TL|tl|₺)?',
);
final _creditCardOcrTlPattern = RegExp('tl', caseSensitive: false);

List<double> _extractCreditCardOcrAmounts(String rawText) {
  final amounts = <double>[];
  final lines = rawText.split(RegExp(r'[\r\n]+'));

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || !_hasCreditCardOcrMoneySignal(trimmed)) {
      continue;
    }

    for (final match in _creditCardOcrAmountPattern.allMatches(trimmed)) {
      final amount = _parseCreditCardOcrAmount(match.group(0) ?? '');
      if (amount != null) {
        amounts.add(amount);
      }
    }
  }

  return amounts;
}

bool _hasCreditCardOcrMoneySignal(String line) {
  final lower = line.toLowerCase();
  return lower.contains('tl') ||
      line.contains('₺') ||
      _creditCardOcrAmountPattern.hasMatch(line);
}

double? _parseCreditCardOcrAmount(String rawAmount) {
  final cleaned = rawAmount
      .replaceAll('−', '-')
      .replaceAll(_creditCardOcrTlPattern, '')
      .replaceAll('₺', '')
      .replaceAll(' ', '')
      .trim();
  if (cleaned.isEmpty) {
    return null;
  }

  final normalized = cleaned.replaceAll('.', '').replaceAll(',', '.');
  final parsed = double.tryParse(normalized);
  if (parsed == null || parsed == 0) {
    return null;
  }

  return parsed.abs();
}

String _formatCreditCardOcrAmountInput(double amount) {
  return amount.toStringAsFixed(2).replaceAll('.', ',');
}

String _formatCreditCardOcrTotal(double amount) {
  return '${_formatCreditCardOcrAmountInput(amount)} TL';
}

String _friendlyOcrError(Object error) {
  return error
      .toString()
      .replaceFirst('Unsupported operation: ', '')
      .replaceFirst('Bad state: ', '');
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

class _KiraathaneDesktopBulkPanel extends StatelessWidget {
  const _KiraathaneDesktopBulkPanel({
    required this.selectedMonth,
    required this.rows,
    required this.employees,
    required this.isSaving,
    required this.isReadingOcr,
    required this.appUser,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onChanged,
    required this.onAddRows,
    required this.onCopyRow,
    required this.onRemoveRow,
    required this.onClearEmptyRows,
    required this.onReadCreditCardOcr,
    required this.onSave,
  });

  final DateTime selectedMonth;
  final List<_DesktopKiraathaneDraft> rows;
  final List<String> employees;
  final bool isSaving;
  final bool isReadingOcr;
  final AppUser? appUser;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onChanged;
  final VoidCallback onAddRows;
  final ValueChanged<int> onCopyRow;
  final ValueChanged<int> onRemoveRow;
  final VoidCallback onClearEmptyRows;
  final VoidCallback onReadCreditCardOcr;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final total = rows.fold<double>(
      0,
      (sum, row) => sum + MoneyUtils.parse(row.amountController.text),
    );
    final days = List.generate(
      AppDateUtils.daysInMonth(selectedMonth),
      (index) => index + 1,
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1320),
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
                  const Expanded(
                    child: _InfoCard(
                      title: 'Bilgisayar hızlı giriş',
                      message:
                          'Tab ve Enter ile hücreler arasında ilerleyip satır satır kayıt girebilirsin. Boş satırlar kaydedilmez.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DesktopShortcutPanel(
                monthKey: AppDateUtils.monthKey(selectedMonth),
              ),
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
                            'Tek Tablo Giriş',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        _DesktopTotalBadge(total: total),
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
                              _DesktopHeaderCell('Gün', width: 78),
                              _DesktopHeaderCell('İşlem', width: 160),
                              _DesktopHeaderCell(
                                'Kategori / Personel',
                                width: 280,
                              ),
                              _DesktopHeaderCell(
                                'Ödeme kaynağı',
                                width: 190,
                              ),
                              _DesktopHeaderCell('Açıklama', width: 280),
                              _DesktopHeaderCell('Tutar', width: 140),
                              _DesktopHeaderCell('İşlem', width: 100),
                            ],
                          ),
                          const SizedBox(height: 6),
                          for (var index = 0; index < rows.length; index++)
                            _KiraathaneDesktopRow(
                              index: index,
                              draft: rows[index],
                              days: days,
                              employees: employees,
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
                          onPressed:
                              isSaving || isReadingOcr ? null : onAddRows,
                          icon: const Icon(Icons.add),
                          label: const Text('5 satır ekle'),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: isSaving || isReadingOcr
                              ? null
                              : onClearEmptyRows,
                          icon: const Icon(Icons.cleaning_services_outlined),
                          label: const Text('Boşları temizle'),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: isSaving || isReadingOcr
                              ? null
                              : onReadCreditCardOcr,
                          icon: const Icon(Icons.document_scanner_outlined),
                          label: Text(
                            isReadingOcr
                                ? 'OCR okunuyor...'
                                : 'Kredi Kartı OCR',
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: isSaving || isReadingOcr || appUser == null
                              ? null
                              : onSave,
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

class _DesktopShortcutPanel extends StatelessWidget {
  const _DesktopShortcutPanel({required this.monthKey});

  final String monthKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Düzeltme ve silme için kayıt yönetimi',
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => context.push('/records?month=$monthKey'),
            icon: const Icon(Icons.list_alt_outlined),
            label: const Text('Kayıt Dökümü'),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: () => context.push('/report?month=$monthKey'),
            icon: const Icon(Icons.bar_chart_outlined),
            label: const Text('Aylık Rapor'),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: () => context.push('/employees'),
            icon: const Icon(Icons.people_outline),
            label: const Text('Personel Ayarları'),
          ),
        ],
      ),
    );
  }
}

class _KiraathaneDesktopRow extends StatelessWidget {
  const _KiraathaneDesktopRow({
    required this.index,
    required this.draft,
    required this.days,
    required this.employees,
    required this.enabled,
    required this.onChanged,
    required this.onCopy,
    required this.onRemove,
  });

  final int index;
  final _DesktopKiraathaneDraft draft;
  final List<int> days;
  final List<String> employees;
  final bool enabled;
  final VoidCallback onChanged;
  final VoidCallback onCopy;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1228,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: index.isEven ? AppColors.surfaceAlt : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _DesktopDropdownCell<int>(
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
          _DesktopDropdownCell<String>(
            width: 160,
            value: draft.type,
            enabled: enabled,
            items: [
              for (final type in _DesktopKiraathaneType.all)
                DropdownMenuItem(
                  value: type,
                  child: Text(_DesktopKiraathaneType.label(type)),
                ),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }
              draft.setType(value);
              onChanged();
            },
          ),
          SizedBox(width: 280, child: _subjectCell()),
          SizedBox(width: 190, child: _paymentSourceCell()),
          _DesktopTextCell(
            width: 280,
            controller: draft.descriptionController,
            enabled: enabled,
            hint: 'Açıklama',
            onChanged: onChanged,
          ),
          _DesktopTextCell(
            width: 140,
            controller: draft.amountController,
            enabled: enabled,
            hint: 'Tutar',
            prefix: '₺ ',
            isNumber: true,
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

  Widget _subjectCell() {
    switch (draft.type) {
      case TransactionTypes.masraf:
        return _DesktopDropdownCell<String>(
          width: 280,
          value: draft.category,
          enabled: enabled,
          items: [
            for (final category in AppCategories.expenseCategories)
              DropdownMenuItem(value: category, child: Text(category)),
          ],
          onChanged: (value) {
            draft.category = value;
            onChanged();
          },
        );
      case TransactionTypes.isci:
        return _DesktopDropdownCell<String>(
          width: 280,
          value: employees.contains(draft.employee) ? draft.employee : null,
          enabled: enabled && employees.isNotEmpty,
          items: [
            for (final employee in employees)
              DropdownMenuItem(value: employee, child: Text(employee)),
          ],
          hint: employees.isEmpty ? 'Personel yok' : 'Personel',
          onChanged: (value) {
            draft.employee = value;
            onChanged();
          },
        );
      case TransactionTypes.borc:
        return Row(
          children: [
            _DesktopDropdownCell<String>(
              width: 132,
              value: draft.category,
              enabled: enabled,
              items: [
                for (final category in AppCategories.debtCategories)
                  DropdownMenuItem(value: category, child: Text(category)),
              ],
              onChanged: (value) {
                draft.category = value;
                onChanged();
              },
            ),
            _DesktopTextCell(
              width: 148,
              controller: draft.personController,
              enabled: enabled,
              hint: 'Kişi',
              onChanged: onChanged,
            ),
          ],
        );
      case _DesktopKiraathaneType.creditCard:
        return const _DesktopStaticCell(width: 280, text: 'Kredi Kartı');
      default:
        return _DesktopStaticCell(
          width: 280,
          text: _DesktopKiraathaneType.label(draft.type),
        );
    }
  }

  Widget _paymentSourceCell() {
    if (draft.type == _DesktopKiraathaneType.creditCard) {
      return const _DesktopStaticCell(width: 190, text: 'Kredi Kartı');
    }
    if (draft.type == TransactionTypes.masraf ||
        draft.type == TransactionTypes.isci ||
        draft.type == TransactionTypes.komisyon) {
      return _DesktopDropdownCell<String>(
        width: 190,
        value: draft.paymentSource,
        enabled: enabled,
        items: [
          for (final source in PaymentSources.all)
            DropdownMenuItem(
              value: source,
              child: Text(PaymentSources.label(source)),
            ),
        ],
        onChanged: (value) {
          if (value == null) {
            return;
          }
          draft.paymentSource = value;
          onChanged();
        },
      );
    }
    return const _DesktopStaticCell(width: 190, text: '-');
  }
}

class _DesktopHeaderCell extends StatelessWidget {
  const _DesktopHeaderCell(this.label, {required this.width});

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

class _DesktopDropdownCell<T> extends StatelessWidget {
  const _DesktopDropdownCell({
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

class _DesktopTextCell extends StatelessWidget {
  const _DesktopTextCell({
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

class _DesktopStaticCell extends StatelessWidget {
  const _DesktopStaticCell({required this.width, required this.text});

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

class _DesktopTotalBadge extends StatelessWidget {
  const _DesktopTotalBadge({required this.total});

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
    required this.controllers,
    required this.isSaving,
    required this.isReadingOcr,
    required this.onReadOcr,
    required this.onAddBoxes,
    required this.onChanged,
    required this.onSave,
  });

  final List<TextEditingController> controllers;
  final bool isSaving;
  final bool isReadingOcr;
  final VoidCallback onReadOcr;
  final VoidCallback onAddBoxes;
  final VoidCallback onChanged;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final total = controllers.fold<double>(
      0,
      (sum, controller) => sum + MoneyUtils.parse(controller.text),
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
                tooltip: '5 kutucuk ekle',
                onPressed: isSaving || isReadingOcr ? null : onAddBoxes,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Mobil bankacılıktaki tutarları yazabilir veya ekran görüntüsünden okutabilirsin.',
            style: TextStyle(color: AppColors.mutedText, fontSize: 12),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: controllers.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 72,
            ),
            itemBuilder: (context, index) {
              return TextField(
                controller: controllers[index],
                enabled: !isSaving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => onChanged(),
                decoration: InputDecoration(
                  labelText: '${index + 1}. tutar',
                  prefixText: '₺ ',
                ),
              );
            },
          ),
          const SizedBox(height: 14),
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
            onPressed: isSaving || isReadingOcr ? null : onAddBoxes,
            icon: const Icon(Icons.add),
            label: const Text('5 Kutucuk Ekle'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: isSaving || isReadingOcr ? null : onReadOcr,
            icon: const Icon(Icons.document_scanner_outlined),
            label: Text(isReadingOcr ? 'OCR okunuyor...' : 'OCR ile Oku'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: isSaving || isReadingOcr ? null : onSave,
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

class _DesktopKiraathaneDraft {
  _DesktopKiraathaneDraft({required this.day});

  int day;
  String type = TransactionTypes.ciro;
  String? category = AppCategories.ciro;
  String? employee;
  String paymentSource = PaymentSources.cash;
  final personController = TextEditingController();
  final amountController = TextEditingController();
  final descriptionController = TextEditingController(text: 'Hızlı ciro');

  bool get hasAmount => MoneyUtils.parse(amountController.text) > 0;

  bool get isEmpty =>
      MoneyUtils.parse(amountController.text) <= 0 &&
      personController.text.trim().isEmpty &&
      (employee == null || employee!.trim().isEmpty);

  void setType(String value) {
    type = value;
    category = null;
    employee = null;
    personController.clear();

    switch (value) {
      case TransactionTypes.ciro:
        category = AppCategories.ciro;
        paymentSource = PaymentSources.cash;
        descriptionController.text = 'Hızlı ciro';
        break;
      case TransactionTypes.masraf:
        category = AppCategories.expenseCategories.first;
        paymentSource = PaymentSources.cash;
        descriptionController.text = 'Hızlı masraf';
        break;
      case TransactionTypes.isci:
        category = AppCategories.isci;
        paymentSource = PaymentSources.cash;
        descriptionController.text = 'Hızlı işçi ödemesi';
        break;
      case TransactionTypes.komisyon:
        category = AppCategories.komisyon;
        paymentSource = PaymentSources.cash;
        descriptionController.text = 'Hızlı işletme ortağı ödemesi';
        break;
      case _DesktopKiraathaneType.creditCard:
        category = AppCategories.creditCard;
        paymentSource = PaymentSources.bank;
        descriptionController.text = 'Kredi kartı harcaması';
        break;
      case TransactionTypes.banka:
        category = AppCategories.banka;
        paymentSource = PaymentSources.cash;
        descriptionController.text = 'Hızlı bankaya yatan';
        break;
      case TransactionTypes.borc:
        category = AppCategories.debtGiven;
        paymentSource = PaymentSources.cash;
        descriptionController.text = 'Hızlı borç / alacak';
        break;
    }
  }

  String? validate(List<String> employees) {
    if (MoneyUtils.parse(amountController.text) <= 0) {
      return 'Tutar 0’dan büyük olmalı.';
    }
    if (type == TransactionTypes.masraf &&
        (category == null || category!.trim().isEmpty)) {
      return 'Masraf kategorisi seçilmeli.';
    }
    if (type == TransactionTypes.isci) {
      if (employee == null || employee!.trim().isEmpty) {
        return 'İşçi seçilmeli.';
      }
      if (!employees.contains(employee)) {
        return 'Seçilen işçi aktif listede yok.';
      }
    }
    if (type == TransactionTypes.borc) {
      if (category == null || category!.trim().isEmpty) {
        return 'Borç / alacak tipi seçilmeli.';
      }
      if (personController.text.trim().isEmpty) {
        return 'Borç / alacak için kişi adı girilmeli.';
      }
    }
    return null;
  }

  TransactionModel toTransaction({
    required DateTime date,
    required AppUser appUser,
  }) {
    final saveType = type == _DesktopKiraathaneType.creditCard
        ? TransactionTypes.masraf
        : type;
    final description = descriptionController.text.trim();

    return TransactionModel(
      id: '',
      date: AppDateUtils.dateKey(date),
      monthKey: AppDateUtils.monthKey(date),
      type: saveType,
      category: _categoryForSave,
      person: _personForSave,
      amount: MoneyUtils.parse(amountController.text),
      paymentSource: _paymentSourceForSave,
      description: description.isEmpty ? _defaultDescription : description,
      createdByUid: appUser.uid,
      createdByName: appUser.displayName,
    );
  }

  String get _categoryForSave {
    switch (type) {
      case TransactionTypes.ciro:
        return AppCategories.ciro;
      case TransactionTypes.masraf:
        return category ?? AppCategories.expenseCategories.first;
      case TransactionTypes.isci:
        return AppCategories.isci;
      case TransactionTypes.komisyon:
        return AppCategories.komisyon;
      case _DesktopKiraathaneType.creditCard:
        return AppCategories.creditCard;
      case TransactionTypes.banka:
        return AppCategories.banka;
      case TransactionTypes.borc:
        return category ?? AppCategories.debtGiven;
      default:
        return category ?? type;
    }
  }

  String get _personForSave {
    if (type == TransactionTypes.isci) {
      return employee ?? '';
    }
    if (type == TransactionTypes.borc) {
      return personController.text.trim();
    }
    return '';
  }

  String get _paymentSourceForSave {
    if (type == _DesktopKiraathaneType.creditCard) {
      return PaymentSources.bank;
    }
    if (type == TransactionTypes.masraf ||
        type == TransactionTypes.isci ||
        type == TransactionTypes.komisyon) {
      return paymentSource;
    }
    return PaymentSources.cash;
  }

  String get _defaultDescription {
    switch (type) {
      case TransactionTypes.ciro:
        return 'Hızlı ciro';
      case TransactionTypes.masraf:
        return 'Hızlı masraf';
      case TransactionTypes.isci:
        return 'Hızlı işçi ödemesi';
      case TransactionTypes.komisyon:
        return 'Hızlı işletme ortağı ödemesi';
      case _DesktopKiraathaneType.creditCard:
        return 'Kredi kartı harcaması';
      case TransactionTypes.banka:
        return 'Hızlı bankaya yatan';
      case TransactionTypes.borc:
        return 'Hızlı borç / alacak';
      default:
        return 'Hızlı kayıt';
    }
  }

  _DesktopKiraathaneDraft copy() {
    final copied = _DesktopKiraathaneDraft(day: day)
      ..type = type
      ..category = category
      ..employee = employee
      ..paymentSource = paymentSource;
    copied.personController.text = personController.text;
    copied.amountController.text = amountController.text;
    copied.descriptionController.text = descriptionController.text;
    return copied;
  }

  void dispose() {
    personController.dispose();
    amountController.dispose();
    descriptionController.dispose();
  }
}

class _DesktopKiraathaneType {
  const _DesktopKiraathaneType._();

  static const creditCard = 'credit_card';

  static const all = [
    TransactionTypes.ciro,
    TransactionTypes.masraf,
    TransactionTypes.isci,
    TransactionTypes.komisyon,
    creditCard,
    TransactionTypes.banka,
    TransactionTypes.borc,
  ];

  static String label(String type) {
    if (type == creditCard) {
      return 'Kredi Kartı';
    }
    return TransactionTypes.label(type);
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
