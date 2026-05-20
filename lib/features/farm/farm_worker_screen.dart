import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/farm_worker_utils.dart';
import '../../core/utils/money_utils.dart';
import '../../data/models/farm_worker_model.dart';
import '../../data/models/farm_worker_payment_model.dart';
import '../../data/models/farm_worker_work_model.dart';
import '../../data/repositories/farm_repository.dart';
import '../dashboard/widgets/month_selector.dart';

class FarmWorkerScreen extends ConsumerStatefulWidget {
  const FarmWorkerScreen({super.key});

  @override
  ConsumerState<FarmWorkerScreen> createState() => _FarmWorkerScreenState();
}

class _FarmWorkerScreenState extends ConsumerState<FarmWorkerScreen> {
  final _nameController = TextEditingController();
  final _dailyWageController = TextEditingController();
  final _workDayCountController = TextEditingController(text: '1');
  final _workDailyWageController = TextEditingController();
  final _workDescriptionController = TextEditingController();
  final _paymentAmountController = TextEditingController();
  final _paymentDescriptionController = TextEditingController();

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int _workDay = DateTime.now().day;
  int _paymentDay = DateTime.now().day;
  String? _workWorkerId;
  String? _paymentWorkerId;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _dailyWageController.dispose();
    _workDayCountController.dispose();
    _workDailyWageController.dispose();
    _workDescriptionController.dispose();
    _paymentAmountController.dispose();
    _paymentDescriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workersState = ref.watch(farmWorkersProvider);
    final worksState = ref.watch(farmWorkerWorksProvider);
    final paymentsState = ref.watch(farmWorkerPaymentsProvider);

    final workers = workersState.valueOrNull ?? const <FarmWorkerModel>[];
    final activeWorkers = workers.where((worker) => worker.active).toList();
    final works = worksState.valueOrNull ?? const <FarmWorkerWorkModel>[];
    final payments =
        paymentsState.valueOrNull ?? const <FarmWorkerPaymentModel>[];
    final summaries = FarmWorkerUtils.summaries(
      workers: workers,
      works: works,
      payments: payments,
    );
    final loading =
        workersState.isLoading && workersState.valueOrNull == null ||
        worksState.isLoading && worksState.valueOrNull == null ||
        paymentsState.isLoading && paymentsState.valueOrNull == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tarım İşçileri'),
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
                  _InfoCard(loading: loading),
                  const SizedBox(height: 16),
                  _AddWorkerCard(
                    nameController: _nameController,
                    dailyWageController: _dailyWageController,
                    isSaving: _isSaving,
                    onSave: _saveWorker,
                  ),
                  const SizedBox(height: 16),
                  _WorkEntryCard(
                    workers: activeWorkers,
                    selectedMonth: _selectedMonth,
                    selectedDay: _workDay,
                    selectedWorkerId: _workWorkerId,
                    dayCountController: _workDayCountController,
                    dailyWageController: _workDailyWageController,
                    descriptionController: _workDescriptionController,
                    enabled: !_isSaving,
                    onDayChanged: (day) => setState(() => _workDay = day),
                    onWorkerChanged: (workerId) {
                      final worker = _workerById(activeWorkers, workerId);
                      setState(() {
                        _workWorkerId = workerId;
                        if (worker != null) {
                          _workDailyWageController.text =
                              worker.dailyWage.toStringAsFixed(0);
                        }
                      });
                    },
                    onChanged: () => setState(() {}),
                    onSave: _saveWork,
                  ),
                  const SizedBox(height: 16),
                  _PaymentEntryCard(
                    workers: activeWorkers,
                    selectedMonth: _selectedMonth,
                    selectedDay: _paymentDay,
                    selectedWorkerId: _paymentWorkerId,
                    amountController: _paymentAmountController,
                    descriptionController: _paymentDescriptionController,
                    enabled: !_isSaving,
                    onDayChanged: (day) => setState(() => _paymentDay = day),
                    onWorkerChanged: (workerId) =>
                        setState(() => _paymentWorkerId = workerId),
                    onSave: _savePayment,
                  ),
                  const SizedBox(height: 16),
                  _WorkerSummaryCard(
                    summaries: summaries,
                    workers: workers,
                    isSaving: _isSaving,
                    onEditWorker: _showEditWorkerDialog,
                    onToggleWorker: _confirmWorkerStatusChange,
                  ),
                  const SizedBox(height: 16),
                  _WorkerHistoryCard(
                    works: works,
                    payments: payments,
                    workers: workers,
                    isSaving: _isSaving,
                    onEditWork: _showEditWorkDialog,
                    onDeleteWork: _confirmDeleteWork,
                    onEditPayment: _showEditPaymentDialog,
                    onDeletePayment: _confirmDeletePayment,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _changeMonth(DateTime month) {
    setState(() {
      _selectedMonth = month;
      final maxDay = AppDateUtils.daysInMonth(month);
      _workDay = _workDay.clamp(1, maxDay).toInt();
      _paymentDay = _paymentDay.clamp(1, maxDay).toInt();
    });
  }

  FarmWorkerModel? _workerById(List<FarmWorkerModel> workers, String? id) {
    for (final worker in workers) {
      if (worker.id == id) {
        return worker;
      }
    }
    return null;
  }

  Future<void> _saveWorker() async {
    final name = _nameController.text.trim();
    final dailyWage = MoneyUtils.parse(_dailyWageController.text);
    if (name.isEmpty || dailyWage <= 0) {
      _showSnack(
        name.isEmpty ? 'İşçi adı boş olamaz.' : 'Yevmiye 0’dan büyük olmalı.',
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(farmRepositoryProvider)
          .addFarmWorker(fullName: name, dailyWage: dailyWage);
      _nameController.clear();
      _dailyWageController.clear();
      _showSnack('İşçi eklendi.');
    } catch (_) {
      _showSnack('İşçi eklenemedi. İnternet bağlantısını kontrol edin.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveWork() async {
    final dayCount = MoneyUtils.parse(_workDayCountController.text);
    final dailyWage = MoneyUtils.parse(_workDailyWageController.text);
    if (_workWorkerId == null || _workWorkerId!.isEmpty) {
      _showSnack('Gün girişi için işçi seçilmeli.');
      return;
    }
    if (dayCount <= 0 || dailyWage <= 0) {
      _showSnack('Gün sayısı ve yevmiye 0’dan büyük olmalı.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(farmRepositoryProvider)
          .addFarmWorkerWork(
            FarmWorkerWorkModel(
              id: '',
              workerId: _workWorkerId!,
              date: AppDateUtils.dateKey(
                DateTime(_selectedMonth.year, _selectedMonth.month, _workDay),
              ),
              dayCount: dayCount,
              dailyWage: dailyWage,
              totalEarned: dayCount * dailyWage,
              description: _workDescriptionController.text.trim(),
            ),
          );
      _workDayCountController.text = '1';
      _workDescriptionController.clear();
      _showSnack('İşçi günü eklendi.');
    } catch (_) {
      _showSnack('İşçi günü kaydedilemedi.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _savePayment() async {
    final amount = MoneyUtils.parse(_paymentAmountController.text);
    if (_paymentWorkerId == null || _paymentWorkerId!.isEmpty) {
      _showSnack('Ödeme için işçi seçilmeli.');
      return;
    }
    if (amount <= 0) {
      _showSnack('Ödeme tutarı 0’dan büyük olmalı.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(farmRepositoryProvider)
          .addFarmWorkerPayment(
            FarmWorkerPaymentModel(
              id: '',
              workerId: _paymentWorkerId!,
              date: AppDateUtils.dateKey(
                DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month,
                  _paymentDay,
                ),
              ),
              amount: amount,
              description: _paymentDescriptionController.text.trim(),
            ),
          );
      _paymentAmountController.clear();
      _paymentDescriptionController.clear();
      _showSnack('İşçi ödemesi eklendi.');
    } catch (_) {
      _showSnack('İşçi ödemesi kaydedilemedi.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _showEditWorkerDialog(FarmWorkerModel worker) async {
    final nameController = TextEditingController(text: worker.fullName);
    final wageController = TextEditingController(
      text: worker.dailyWage.toStringAsFixed(0),
    );

    final result = await showDialog<_WorkerEditResult>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('İşçiyi Düzenle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'İşçi adı'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: wageController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Yevmiye',
                  prefixText: '₺ ',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                _WorkerEditResult(
                  nameController.text.trim(),
                  MoneyUtils.parse(wageController.text),
                ),
              ),
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    wageController.dispose();

    if (result == null) {
      return;
    }
    if (result.name.isEmpty || result.dailyWage <= 0) {
      _showSnack('İşçi adı ve yevmiye doğru girilmeli.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(farmRepositoryProvider)
          .updateFarmWorker(
            worker.copyWith(
              fullName: result.name,
              dailyWage: result.dailyWage,
            ),
          );
      _showSnack('İşçi güncellendi.');
    } catch (_) {
      _showSnack('İşçi güncellenemedi.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _confirmWorkerStatusChange(FarmWorkerModel worker) async {
    final nextActive = !worker.active;
    var confirmed = true;
    if (!nextActive) {
      confirmed =
          await showDialog<bool>(
            context: context,
            builder: (context) {
              return AlertDialog(
                backgroundColor: AppColors.surface,
                title: Text('${worker.fullName} pasife alınsın mı?'),
                content: const Text(
                  'Pasif işçi yeni gün ve ödeme girişinde görünmez. Eski kayıtları ve alacak hesabı korunur.',
                  style: TextStyle(color: AppColors.mutedText),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Vazgeç'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Pasife Al'),
                  ),
                ],
              );
            },
          ) ??
          false;
    }
    if (!confirmed) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(farmRepositoryProvider)
          .setFarmWorkerActive(worker: worker, active: nextActive);
      _showSnack(nextActive ? 'İşçi aktif edildi.' : 'İşçi pasife alındı.');
    } catch (_) {
      _showSnack('İşçi durumu güncellenemedi.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _showEditWorkDialog(
    FarmWorkerWorkModel work,
    List<FarmWorkerModel> workers,
  ) async {
    final date = AppDateUtils.dateFromKey(work.date);
    var month = DateTime(date.year, date.month);
    var day = date.day;
    var workerId = work.workerId;
    final dayCountController = TextEditingController(
      text: work.dayCount.toStringAsFixed(work.dayCount % 1 == 0 ? 0 : 1),
    );
    final wageController = TextEditingController(
      text: work.dailyWage.toStringAsFixed(0),
    );
    final descriptionController = TextEditingController(text: work.description);

    final result = await showDialog<_WorkEditResult>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final maxDay = AppDateUtils.daysInMonth(month);
            day = day.clamp(1, maxDay).toInt();
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text('Gün Kaydını Düzenle'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MonthSelector(
                        selectedMonth: month,
                        onPrevious: () => setDialogState(
                          () => month = AppDateUtils.previousMonth(month),
                        ),
                        onNext: () => setDialogState(
                          () => month = AppDateUtils.nextMonth(month),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DayDropdown(
                        label: 'Gün',
                        month: month,
                        value: day,
                        enabled: true,
                        onChanged: (value) =>
                            setDialogState(() => day = value),
                      ),
                      const SizedBox(height: 12),
                      _WorkerDropdown(
                        workers: workers,
                        selectedId: workerId,
                        enabled: true,
                        onChanged: (value) =>
                            setDialogState(() => workerId = value),
                      ),
                      const SizedBox(height: 12),
                      _NumberField(
                        controller: dayCountController,
                        label: 'Gün sayısı',
                        enabled: true,
                        onChanged: (_) {},
                      ),
                      const SizedBox(height: 12),
                      _NumberField(
                        controller: wageController,
                        label: 'Yevmiye',
                        enabled: true,
                        prefix: '₺ ',
                        onChanged: (_) {},
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        decoration:
                            const InputDecoration(labelText: 'Açıklama'),
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
                    final dayCount = MoneyUtils.parse(
                      dayCountController.text,
                    );
                    final dailyWage = MoneyUtils.parse(wageController.text);
                    Navigator.of(context).pop(
                      _WorkEditResult(
                        workerId: workerId ?? '',
                        date: AppDateUtils.dateKey(
                          DateTime(month.year, month.month, day),
                        ),
                        dayCount: dayCount,
                        dailyWage: dailyWage,
                        description: descriptionController.text.trim(),
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

    dayCountController.dispose();
    wageController.dispose();
    descriptionController.dispose();

    if (result == null) {
      return;
    }
    if (result.workerId.isEmpty ||
        result.dayCount <= 0 ||
        result.dailyWage <= 0) {
      _showSnack('Gün kaydında işçi, gün sayısı ve yevmiye doğru olmalı.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(farmRepositoryProvider)
          .updateFarmWorkerWork(
            work.copyWith(
              workerId: result.workerId,
              date: result.date,
              dayCount: result.dayCount,
              dailyWage: result.dailyWage,
              totalEarned: result.dayCount * result.dailyWage,
              description: result.description,
            ),
          );
      _showSnack('Gün kaydı güncellendi.');
    } catch (_) {
      _showSnack('Gün kaydı güncellenemedi.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _showEditPaymentDialog(
    FarmWorkerPaymentModel payment,
    List<FarmWorkerModel> workers,
  ) async {
    final date = AppDateUtils.dateFromKey(payment.date);
    var month = DateTime(date.year, date.month);
    var day = date.day;
    var workerId = payment.workerId;
    final amountController = TextEditingController(
      text: payment.amount.toStringAsFixed(0),
    );
    final descriptionController = TextEditingController(
      text: payment.description,
    );

    final result = await showDialog<_PaymentEditResult>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final maxDay = AppDateUtils.daysInMonth(month);
            day = day.clamp(1, maxDay).toInt();
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text('Ödemeyi Düzenle'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MonthSelector(
                        selectedMonth: month,
                        onPrevious: () => setDialogState(
                          () => month = AppDateUtils.previousMonth(month),
                        ),
                        onNext: () => setDialogState(
                          () => month = AppDateUtils.nextMonth(month),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DayDropdown(
                        label: 'Gün',
                        month: month,
                        value: day,
                        enabled: true,
                        onChanged: (value) =>
                            setDialogState(() => day = value),
                      ),
                      const SizedBox(height: 12),
                      _WorkerDropdown(
                        workers: workers,
                        selectedId: workerId,
                        enabled: true,
                        onChanged: (value) =>
                            setDialogState(() => workerId = value),
                      ),
                      const SizedBox(height: 12),
                      _NumberField(
                        controller: amountController,
                        label: 'Ödenen tutar',
                        enabled: true,
                        prefix: '₺ ',
                        onChanged: (_) {},
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        decoration:
                            const InputDecoration(labelText: 'Açıklama'),
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
                    _PaymentEditResult(
                      workerId: workerId ?? '',
                      date: AppDateUtils.dateKey(
                        DateTime(month.year, month.month, day),
                      ),
                      amount: MoneyUtils.parse(amountController.text),
                      description: descriptionController.text.trim(),
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
    if (result.workerId.isEmpty || result.amount <= 0) {
      _showSnack('Ödeme kaydında işçi ve tutar doğru olmalı.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(farmRepositoryProvider)
          .updateFarmWorkerPayment(
            payment.copyWith(
              workerId: result.workerId,
              date: result.date,
              amount: result.amount,
              description: result.description,
            ),
          );
      _showSnack('Ödeme güncellendi.');
    } catch (_) {
      _showSnack('Ödeme güncellenemedi.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _confirmDeleteWork(FarmWorkerWorkModel work) async {
    final confirmed = await _confirmDelete('Bu gün kaydı silinsin mi?');
    if (!confirmed) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ref.read(farmRepositoryProvider).deleteFarmWorkerWork(work.id);
      _showSnack('Gün kaydı silindi.');
    } catch (_) {
      _showSnack('Gün kaydı silinemedi.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _confirmDeletePayment(FarmWorkerPaymentModel payment) async {
    final confirmed = await _confirmDelete('Bu ödeme kaydı silinsin mi?');
    if (!confirmed) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ref
          .read(farmRepositoryProvider)
          .deleteFarmWorkerPayment(payment.id);
      _showSnack('Ödeme kaydı silindi.');
    } catch (_) {
      _showSnack('Ödeme kaydı silinemedi.');
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.loading});

  final bool loading;

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
          const Icon(Icons.engineering_outlined, color: AppColors.turquoise),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              loading
                  ? 'İşçi kayıtları yükleniyor...'
                  : 'İşçi, yevmiye, geldiği gün, ödeme ve kalan alacak takibi.',
              style: const TextStyle(color: AppColors.mutedText),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddWorkerCard extends StatelessWidget {
  const _AddWorkerCard({
    required this.nameController,
    required this.dailyWageController,
    required this.isSaving,
    required this.onSave,
  });

  final TextEditingController nameController;
  final TextEditingController dailyWageController;
  final bool isSaving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return _FarmPanel(
      title: 'Yeni İşçi',
      child: Column(
        children: [
          TextField(
            controller: nameController,
            enabled: !isSaving,
            decoration: const InputDecoration(
              labelText: 'İşçi adı',
              prefixIcon: Icon(Icons.person_add_alt_1_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: dailyWageController,
            enabled: !isSaving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Yevmiye',
              prefixText: '₺ ',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isSaving ? null : onSave,
              icon: const Icon(Icons.add),
              label: Text(isSaving ? 'Kaydediliyor...' : 'İşçi Ekle'),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkEntryCard extends StatelessWidget {
  const _WorkEntryCard({
    required this.workers,
    required this.selectedMonth,
    required this.selectedDay,
    required this.selectedWorkerId,
    required this.dayCountController,
    required this.dailyWageController,
    required this.descriptionController,
    required this.enabled,
    required this.onDayChanged,
    required this.onWorkerChanged,
    required this.onChanged,
    required this.onSave,
  });

  final List<FarmWorkerModel> workers;
  final DateTime selectedMonth;
  final int selectedDay;
  final String? selectedWorkerId;
  final TextEditingController dayCountController;
  final TextEditingController dailyWageController;
  final TextEditingController descriptionController;
  final bool enabled;
  final ValueChanged<int> onDayChanged;
  final ValueChanged<String?> onWorkerChanged;
  final VoidCallback onChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final dayCount = MoneyUtils.parse(dayCountController.text);
    final dailyWage = MoneyUtils.parse(dailyWageController.text);
    final total = dayCount * dailyWage;

    return _FarmPanel(
      title: 'Gün Girişi',
      child: workers.isEmpty
          ? const _StateText('Önce aktif bir işçi ekleyin.')
          : Column(
              children: [
                _DayDropdown(
                  label: 'Gün',
                  month: selectedMonth,
                  value: selectedDay,
                  enabled: enabled,
                  onChanged: onDayChanged,
                ),
                const SizedBox(height: 12),
                _WorkerDropdown(
                  workers: workers,
                  selectedId: selectedWorkerId,
                  enabled: enabled,
                  onChanged: onWorkerChanged,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _NumberField(
                        controller: dayCountController,
                        label: 'Gün sayısı',
                        enabled: enabled,
                        onChanged: (_) => onChanged(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _NumberField(
                        controller: dailyWageController,
                        label: 'Yevmiye',
                        enabled: enabled,
                        prefix: '₺ ',
                        onChanged: (_) => onChanged(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  enabled: enabled,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                _TotalLine(label: 'Hakediş', amount: total),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: enabled ? onSave : null,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Günü Kaydet'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _PaymentEntryCard extends StatelessWidget {
  const _PaymentEntryCard({
    required this.workers,
    required this.selectedMonth,
    required this.selectedDay,
    required this.selectedWorkerId,
    required this.amountController,
    required this.descriptionController,
    required this.enabled,
    required this.onDayChanged,
    required this.onWorkerChanged,
    required this.onSave,
  });

  final List<FarmWorkerModel> workers;
  final DateTime selectedMonth;
  final int selectedDay;
  final String? selectedWorkerId;
  final TextEditingController amountController;
  final TextEditingController descriptionController;
  final bool enabled;
  final ValueChanged<int> onDayChanged;
  final ValueChanged<String?> onWorkerChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return _FarmPanel(
      title: 'Ara / Tam Ödeme',
      child: workers.isEmpty
          ? const _StateText('Ödeme için aktif işçi bulunmalı.')
          : Column(
              children: [
                _DayDropdown(
                  label: 'Gün',
                  month: selectedMonth,
                  value: selectedDay,
                  enabled: enabled,
                  onChanged: onDayChanged,
                ),
                const SizedBox(height: 12),
                _WorkerDropdown(
                  workers: workers,
                  selectedId: selectedWorkerId,
                  enabled: enabled,
                  onChanged: onWorkerChanged,
                ),
                const SizedBox(height: 12),
                _NumberField(
                  controller: amountController,
                  label: 'Ödenen tutar',
                  enabled: enabled,
                  prefix: '₺ ',
                  onChanged: (_) {},
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  enabled: enabled,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: enabled ? onSave : null,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Ödemeyi Kaydet'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _WorkerSummaryCard extends StatelessWidget {
  const _WorkerSummaryCard({
    required this.summaries,
    required this.workers,
    required this.isSaving,
    required this.onEditWorker,
    required this.onToggleWorker,
  });

  final List<FarmWorkerSummary> summaries;
  final List<FarmWorkerModel> workers;
  final bool isSaving;
  final ValueChanged<FarmWorkerModel> onEditWorker;
  final ValueChanged<FarmWorkerModel> onToggleWorker;

  @override
  Widget build(BuildContext context) {
    final workerById = {for (final worker in workers) worker.id: worker};
    return _FarmPanel(
      title: 'Hakediş Durumu',
      child: summaries.isEmpty
          ? const _StateText('Henüz işçi kaydı yok.')
          : Column(
              children: [
                for (final summary in summaries)
                  _WorkerSummaryTile(
                    summary: summary,
                    worker: workerById[summary.workerId],
                    isSaving: isSaving,
                    onEditWorker: onEditWorker,
                    onToggleWorker: onToggleWorker,
                  ),
              ],
            ),
    );
  }
}

class _WorkerSummaryTile extends StatelessWidget {
  const _WorkerSummaryTile({
    required this.summary,
    required this.worker,
    required this.isSaving,
    required this.onEditWorker,
    required this.onToggleWorker,
  });

  final FarmWorkerSummary summary;
  final FarmWorkerModel? worker;
  final bool isSaving;
  final ValueChanged<FarmWorkerModel> onEditWorker;
  final ValueChanged<FarmWorkerModel> onToggleWorker;

  @override
  Widget build(BuildContext context) {
    final remainingLabel = summary.isOverPaid ? 'Fazla ödeme' : 'Alacak';
    final remainingAmount =
        summary.isOverPaid ? summary.overPaid : summary.remaining;

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
                  summary.name,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              _StatusPill(active: summary.active),
            ],
          ),
          const SizedBox(height: 10),
          _MiniGrid(
            items: [
              _MiniGridItem('Gün', _formatNumber(summary.totalDays)),
              _MiniGridItem('Hakediş', MoneyUtils.format(summary.totalEarned)),
              _MiniGridItem('Ödenen', MoneyUtils.format(summary.totalPaid)),
              _MiniGridItem(remainingLabel, MoneyUtils.format(remainingAmount)),
            ],
          ),
          if (worker != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: isSaving ? null : () => onEditWorker(worker!),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Düzenle'),
                ),
                OutlinedButton.icon(
                  onPressed: isSaving ? null : () => onToggleWorker(worker!),
                  icon: Icon(
                    worker!.active
                        ? Icons.person_remove_outlined
                        : Icons.person_add_alt_outlined,
                    size: 18,
                  ),
                  label: Text(worker!.active ? 'Pasife Al' : 'Aktifleştir'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkerHistoryCard extends StatelessWidget {
  const _WorkerHistoryCard({
    required this.works,
    required this.payments,
    required this.workers,
    required this.isSaving,
    required this.onEditWork,
    required this.onDeleteWork,
    required this.onEditPayment,
    required this.onDeletePayment,
  });

  final List<FarmWorkerWorkModel> works;
  final List<FarmWorkerPaymentModel> payments;
  final List<FarmWorkerModel> workers;
  final bool isSaving;
  final void Function(FarmWorkerWorkModel work, List<FarmWorkerModel> workers)
      onEditWork;
  final ValueChanged<FarmWorkerWorkModel> onDeleteWork;
  final void Function(
    FarmWorkerPaymentModel payment,
    List<FarmWorkerModel> workers,
  ) onEditPayment;
  final ValueChanged<FarmWorkerPaymentModel> onDeletePayment;

  @override
  Widget build(BuildContext context) {
    final workerNames = {
      for (final worker in workers) worker.id: worker.fullName,
    };
    final movements = <_WorkerMovement>[
      for (final work in works) _WorkerMovement.work(work),
      for (final payment in payments) _WorkerMovement.payment(payment),
    ]..sort((a, b) => b.date.compareTo(a.date));
    final recent = movements.take(20).toList();

    return _FarmPanel(
      title: 'Son İşçi Hareketleri',
      child: recent.isEmpty
          ? const _StateText('Henüz işçi hareketi yok.')
          : Column(
              children: [
                for (final movement in recent)
                  _WorkerMovementTile(
                    movement: movement,
                    workerName: workerNames[movement.workerId] ?? 'Eski işçi',
                    isSaving: isSaving,
                    onEditWork: () => onEditWork(movement.work!, workers),
                    onDeleteWork: () => onDeleteWork(movement.work!),
                    onEditPayment: () =>
                        onEditPayment(movement.payment!, workers),
                    onDeletePayment: () => onDeletePayment(movement.payment!),
                  ),
              ],
            ),
    );
  }
}

class _WorkerMovementTile extends StatelessWidget {
  const _WorkerMovementTile({
    required this.movement,
    required this.workerName,
    required this.isSaving,
    required this.onEditWork,
    required this.onDeleteWork,
    required this.onEditPayment,
    required this.onDeletePayment,
  });

  final _WorkerMovement movement;
  final String workerName;
  final bool isSaving;
  final VoidCallback onEditWork;
  final VoidCallback onDeleteWork;
  final VoidCallback onEditPayment;
  final VoidCallback onDeletePayment;

  @override
  Widget build(BuildContext context) {
    final isWork = movement.work != null;
    final title = isWork
        ? '${_formatNumber(movement.work!.dayCount)} gün'
        : 'Ödeme';
    final description = isWork
        ? movement.work!.description
        : movement.payment!.description;
    final subtitle = description.trim().isEmpty
        ? '${movement.date} • $workerName'
        : '${movement.date} • $workerName • $description';
    final amount = isWork
        ? movement.work!.totalEarned
        : movement.payment!.amount;
    final color = isWork ? AppColors.expense : AppColors.primary;

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
                  title,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  MoneyUtils.format(amount),
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Düzenle',
            onPressed: isSaving ? null : (isWork ? onEditWork : onEditPayment),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Sil',
            onPressed:
                isSaving ? null : (isWork ? onDeleteWork : onDeletePayment),
            icon: const Icon(Icons.delete_outline, color: AppColors.expense),
          ),
        ],
      ),
    );
  }
}

class _DayDropdown extends StatelessWidget {
  const _DayDropdown({
    required this.label,
    required this.month,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final DateTime month;
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final days = List.generate(
      AppDateUtils.daysInMonth(month),
      (index) => index + 1,
    );
    final selected = value.clamp(1, days.length).toInt();
    return DropdownButtonFormField<int>(
      value: selected,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.calendar_month_outlined),
      ),
      items: [
        for (final day in days) DropdownMenuItem(value: day, child: Text('$day')),
      ],
      onChanged: enabled
          ? (value) {
              if (value != null) {
                onChanged(value);
              }
            }
          : null,
    );
  }
}

class _WorkerDropdown extends StatelessWidget {
  const _WorkerDropdown({
    required this.workers,
    required this.selectedId,
    required this.enabled,
    required this.onChanged,
  });

  final List<FarmWorkerModel> workers;
  final String? selectedId;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final value = workers.any((worker) => worker.id == selectedId)
        ? selectedId
        : null;
    return DropdownButtonFormField<String>(
      value: value,
      decoration: const InputDecoration(
        labelText: 'İşçi',
        prefixIcon: Icon(Icons.engineering_outlined),
      ),
      items: [
        for (final worker in workers)
          DropdownMenuItem(
            value: worker.id,
            child: Text(
              worker.active ? worker.fullName : '${worker.fullName} (Pasif)',
            ),
          ),
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
    required this.onChanged,
    this.prefix,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label, prefixText: prefix),
    );
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine({required this.label, required this.amount});

  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.expense.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.expense.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.mutedText),
            ),
          ),
          Text(
            MoneyUtils.format(amount),
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
            ),
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: active
            ? AppColors.primary.withOpacity(0.12)
            : AppColors.expense.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? 'Aktif' : 'Pasif',
        style: TextStyle(
          color: active ? AppColors.primary : AppColors.expense,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MiniGrid extends StatelessWidget {
  const _MiniGrid({required this.items});

  final List<_MiniGridItem> items;

  @override
  Widget build(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        mainAxisExtent: 58,
      ),
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                Text(
                  item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
      ],
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

class _MiniGridItem {
  const _MiniGridItem(this.label, this.value);

  final String label;
  final String value;
}

class _WorkerMovement {
  const _WorkerMovement._({
    required this.date,
    required this.workerId,
    this.work,
    this.payment,
  });

  factory _WorkerMovement.work(FarmWorkerWorkModel work) {
    return _WorkerMovement._(
      date: work.date,
      workerId: work.workerId,
      work: work,
    );
  }

  factory _WorkerMovement.payment(FarmWorkerPaymentModel payment) {
    return _WorkerMovement._(
      date: payment.date,
      workerId: payment.workerId,
      payment: payment,
    );
  }

  final String date;
  final String workerId;
  final FarmWorkerWorkModel? work;
  final FarmWorkerPaymentModel? payment;
}

class _WorkerEditResult {
  const _WorkerEditResult(this.name, this.dailyWage);

  final String name;
  final double dailyWage;
}

class _WorkEditResult {
  const _WorkEditResult({
    required this.workerId,
    required this.date,
    required this.dayCount,
    required this.dailyWage,
    required this.description,
  });

  final String workerId;
  final String date;
  final double dayCount;
  final double dailyWage;
  final String description;
}

class _PaymentEditResult {
  const _PaymentEditResult({
    required this.workerId,
    required this.date,
    required this.amount,
    required this.description,
  });

  final String workerId;
  final String date;
  final double amount;
  final String description;
}

String _formatNumber(double value) {
  if (value % 1 == 0) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}
