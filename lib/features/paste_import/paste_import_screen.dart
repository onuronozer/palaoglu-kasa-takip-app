import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/categories.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/money_utils.dart';
import '../../data/models/app_user.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/transaction_repository.dart';
import '../auth/auth_controller.dart';
import '../dashboard/widgets/month_selector.dart';

class PasteImportScreen extends ConsumerStatefulWidget {
  const PasteImportScreen({this.initialMonthKey, super.key});

  final String? initialMonthKey;

  @override
  ConsumerState<PasteImportScreen> createState() => _PasteImportScreenState();
}

class _PasteImportScreenState extends ConsumerState<PasteImportScreen> {
  final _pasteController = TextEditingController();
  late DateTime _selectedMonth;
  List<_PasteImportRow> _rows = const [];
  Set<int> _selectedRowIndexes = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedMonth = AppDateUtils.monthFromKey(widget.initialMonthKey);
  }

  @override
  void dispose() {
    _pasteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appUser = ref.watch(currentAppUserProvider).valueOrNull;
    final monthKey = AppDateUtils.monthKey(_selectedMonth);
    final transactionsState = ref.watch(transactionsByMonthProvider(monthKey));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yapıştırarak Giriş'),
        leading: IconButton(
          tooltip: 'Geri',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: transactionsState.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (_, __) => const Center(
            child: _StateCard(message: 'Ay kayıtları okunamadı.'),
          ),
          data: (transactions) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
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
                      _PasteInputCard(
                        controller: _pasteController,
                        isSaving: _isSaving,
                        onAnalyze: () => _analyze(transactions),
                        onChanged: _clearAnalysis,
                        onClear: _clear,
                        onPaste: _pasteFromClipboard,
                      ),
                      const SizedBox(height: 16),
                      _ImportSummaryCard(
                        rows: _rows,
                        selectedRowIndexes: _selectedRowIndexes,
                        isSaving: _isSaving,
                        onSave: appUser == null
                            ? null
                            : () => _save(appUser, transactions),
                      ),
                      if (_rows.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _PreviewCard(
                          rows: _rows,
                          selectedRowIndexes: _selectedRowIndexes,
                          onSelectionChanged: (index, selected) {
                            setState(() {
                              if (selected) {
                                _selectedRowIndexes.add(index);
                              } else {
                                _selectedRowIndexes.remove(index);
                              }
                            });
                          },
                        ),
                      ],
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

  void _changeMonth(DateTime month) {
    setState(() {
      _selectedMonth = month;
      _rows = const [];
      _selectedRowIndexes = {};
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      _showSnack('Panoda metin yok.');
      return;
    }
    setState(() {
      _pasteController.text = text;
      _rows = const [];
      _selectedRowIndexes = {};
    });
  }

  void _clear() {
    setState(() {
      _pasteController.clear();
      _rows = const [];
      _selectedRowIndexes = {};
    });
  }

  void _clearAnalysis() {
    if (_rows.isEmpty && _selectedRowIndexes.isEmpty) {
      return;
    }
    setState(() {
      _rows = const [];
      _selectedRowIndexes = {};
    });
  }

  void _analyze(List<TransactionModel> transactions) {
    final result = _buildRows(
      rawText: _pasteController.text,
      selectedMonth: _selectedMonth,
      transactions: transactions,
    );

    setState(() {
      _rows = result.rows;
      _selectedRowIndexes = result.selectedIndexes;
    });

    if (result.rows.isEmpty) {
      _showSnack('Kontrol edilecek satır bulunamadı.');
    }
  }

  Future<void> _save(
    AppUser appUser,
    List<TransactionModel> transactions,
  ) async {
    final result = _buildRows(
      rawText: _pasteController.text,
      selectedMonth: _selectedMonth,
      transactions: transactions,
    );
    final selectedReadyRows = <_PasteImportRow>[];
    for (var index = 0; index < result.rows.length; index++) {
      final row = result.rows[index];
      if (_selectedRowIndexes.contains(index) && row.canSave) {
        selectedReadyRows.add(row);
      }
    }

    if (selectedReadyRows.isEmpty) {
      setState(() {
        _rows = result.rows;
        _selectedRowIndexes = result.selectedIndexes;
      });
      _showSnack('Kaydedilecek yeni kayıt yok.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final records = [
        for (final row in selectedReadyRows)
          TransactionModel(
            id: '',
            date: AppDateUtils.dateKey(row.date!),
            monthKey: AppDateUtils.monthKey(row.date!),
            type: row.type,
            category: row.category,
            person: row.person,
            amount: row.amount,
            description: row.description,
            createdByUid: appUser.uid,
            createdByName: appUser.displayName,
            paymentSource: row.paymentSource,
          ),
      ];

      await ref.read(transactionRepositoryProvider).addTransactions(records);

      if (!mounted) {
        return;
      }
      _showSnack(
        '${records.length} kayıt eklendi. Toplam ${MoneyUtils.format(_sumRows(selectedReadyRows))}.',
      );
      setState(() {
        _pasteController.clear();
        _rows = const [];
        _selectedRowIndexes = {};
      });
    } catch (_) {
      if (mounted) {
        _showSnack('Kayıtlar kaydedilemedi.');
      }
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

class _PasteInputCard extends StatelessWidget {
  const _PasteInputCard({
    required this.controller,
    required this.isSaving,
    required this.onAnalyze,
    required this.onChanged,
    required this.onClear,
    required this.onPaste,
  });

  final TextEditingController controller;
  final bool isSaving;
  final VoidCallback onAnalyze;
  final VoidCallback onChanged;
  final VoidCallback onClear;
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _IconBox(icon: Icons.content_paste_go_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Kayıt listesi',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            enabled: !isSaving,
            minLines: 9,
            maxLines: 16,
            keyboardType: TextInputType.multiline,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              labelText: 'Gün, işlem, konu ve tutar',
              hintText:
                  '01;ciro;;19450\n01;masraf;Çay;1250\n01;isci;Mehmet;2000',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.table_rows_outlined),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: isSaving ? null : onAnalyze,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Kontrol Et'),
              ),
              OutlinedButton.icon(
                onPressed: isSaving ? null : onPaste,
                icon: const Icon(Icons.content_paste_outlined),
                label: const Text('Panodan Al'),
              ),
              TextButton.icon(
                onPressed: isSaving ? null : onClear,
                icon: const Icon(Icons.clear),
                label: const Text('Temizle'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImportSummaryCard extends StatelessWidget {
  const _ImportSummaryCard({
    required this.rows,
    required this.selectedRowIndexes,
    required this.isSaving,
    required this.onSave,
  });

  final List<_PasteImportRow> rows;
  final Set<int> selectedRowIndexes;
  final bool isSaving;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final saveRows = [
      for (var index = 0; index < rows.length; index++)
        if (selectedRowIndexes.contains(index) && rows[index].canSave)
          rows[index],
    ];
    final readyCount =
        rows.where((row) => row.status == _PasteRowStatus.ready).length;
    final conflictCount =
        rows.where((row) => row.status == _PasteRowStatus.conflict).length;
    final duplicateCount =
        rows.where((row) => row.status == _PasteRowStatus.duplicate).length;
    final invalidCount =
        rows.where((row) => row.status == _PasteRowStatus.invalid).length;
    final total = _sumRows(saveRows);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SummaryPill(
                label: 'Eklenecek',
                value: '$readyCount',
                color: AppColors.income,
              ),
              _SummaryPill(
                label: 'Çakışma',
                value: '$conflictCount',
                color: AppColors.warning,
              ),
              _SummaryPill(
                label: 'Zaten var',
                value: '$duplicateCount',
                color: AppColors.turquoise,
              ),
              _SummaryPill(
                label: 'Hatalı',
                value: '$invalidCount',
                color: AppColors.expense,
              ),
              _SummaryPill(
                label: 'Toplam',
                value: MoneyUtils.format(total),
                color: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: isSaving || saveRows.isEmpty ? null : onSave,
            icon: const Icon(Icons.save_outlined),
            label:
                Text(isSaving ? 'Kaydediliyor...' : 'Seçili Kayıtları Kaydet'),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.rows,
    required this.selectedRowIndexes,
    required this.onSelectionChanged,
  });

  final List<_PasteImportRow> rows;
  final Set<int> selectedRowIndexes;
  final void Function(int index, bool selected) onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Kontrol sonucu', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 720) {
                return _PreviewTable(
                  rows: rows,
                  selectedRowIndexes: selectedRowIndexes,
                  onSelectionChanged: onSelectionChanged,
                );
              }
              return Column(
                children: [
                  for (var index = 0; index < rows.length; index++) ...[
                    _PreviewTile(
                      index: index,
                      row: rows[index],
                      selected: selectedRowIndexes.contains(index),
                      onChanged: (selected) {
                        onSelectionChanged(index, selected);
                      },
                    ),
                    if (index != rows.length - 1) const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PreviewTable extends StatelessWidget {
  const _PreviewTable({
    required this.rows,
    required this.selectedRowIndexes,
    required this.onSelectionChanged,
  });

  final List<_PasteImportRow> rows;
  final Set<int> selectedRowIndexes;
  final void Function(int index, bool selected) onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        dataRowMinHeight: 52,
        dataRowMaxHeight: 68,
        headingTextStyle: const TextStyle(
          color: AppColors.mutedText,
          fontWeight: FontWeight.w800,
        ),
        columns: const [
          DataColumn(label: Text('Seç')),
          DataColumn(label: Text('Satır')),
          DataColumn(label: Text('Gün')),
          DataColumn(label: Text('İşlem')),
          DataColumn(label: Text('Konu')),
          DataColumn(label: Text('Tutar')),
          DataColumn(label: Text('Ödeme')),
          DataColumn(label: Text('Durum')),
        ],
        rows: [
          for (var index = 0; index < rows.length; index++)
            DataRow(
              selected: selectedRowIndexes.contains(index),
              cells: [
                DataCell(
                  Checkbox(
                    value: selectedRowIndexes.contains(index),
                    onChanged: rows[index].canSave
                        ? (value) => onSelectionChanged(index, value ?? false)
                        : null,
                  ),
                ),
                DataCell(Text('${rows[index].sourceLine}')),
                DataCell(Text(rows[index].dateLabel)),
                DataCell(Text(rows[index].typeLabel)),
                DataCell(Text(rows[index].subjectLabel)),
                DataCell(Text(rows[index].amountLabel)),
                DataCell(Text(rows[index].paymentSourceLabel)),
                DataCell(_StatusPill(row: rows[index])),
              ],
            ),
        ],
      ),
    );
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({
    required this.index,
    required this.row,
    required this.selected,
    required this.onChanged,
  });

  final int index;
  final _PasteImportRow row;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Checkbox(
            value: selected,
            onChanged:
                row.canSave ? (value) => onChanged(value ?? false) : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${row.dateLabel} - ${row.typeLabel} - ${row.amountLabel}',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (row.subjectLabel != '-') ...[
                  const SizedBox(height: 3),
                  Text(
                    row.subjectLabel,
                    style: const TextStyle(color: AppColors.mutedText),
                  ),
                ],
                const SizedBox(height: 6),
                _StatusPill(row: row),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.row});

  final _PasteImportRow row;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: row.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: row.color.withValues(alpha: 0.35)),
      ),
      child: Text(
        row.message,
        style: TextStyle(
          color: row.color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.mutedText,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: AppColors.primary),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
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

class _BuildRowsResult {
  const _BuildRowsResult({
    required this.rows,
    required this.selectedIndexes,
  });

  final List<_PasteImportRow> rows;
  final Set<int> selectedIndexes;
}

class _PasteImportRow {
  const _PasteImportRow({
    required this.sourceLine,
    required this.rawText,
    required this.date,
    required this.type,
    required this.category,
    required this.person,
    required this.amount,
    required this.paymentSource,
    required this.description,
    required this.status,
    required this.message,
  });

  final int sourceLine;
  final String rawText;
  final DateTime? date;
  final String type;
  final String category;
  final String person;
  final double amount;
  final String paymentSource;
  final String description;
  final _PasteRowStatus status;
  final String message;

  bool get canSave => status == _PasteRowStatus.ready;

  String get dateLabel {
    if (date == null) {
      return '-';
    }
    return AppDateUtils.dateKey(date!);
  }

  String get amountLabel {
    if (amount <= 0) {
      return '-';
    }
    return MoneyUtils.format(amount);
  }

  String get typeLabel {
    if (type.isEmpty) {
      return '-';
    }
    return TransactionTypes.label(type);
  }

  String get subjectLabel {
    if (type == TransactionTypes.isci) {
      return person.isEmpty ? '-' : person;
    }
    if (type == TransactionTypes.masraf) {
      return category.isEmpty ? '-' : category;
    }
    return category.isEmpty ? '-' : category;
  }

  String get paymentSourceLabel {
    if (paymentSource.isEmpty) {
      return '-';
    }
    return PaymentSources.label(paymentSource);
  }

  Color get color {
    switch (status) {
      case _PasteRowStatus.ready:
        return AppColors.income;
      case _PasteRowStatus.duplicate:
        return AppColors.turquoise;
      case _PasteRowStatus.conflict:
        return AppColors.warning;
      case _PasteRowStatus.invalid:
        return AppColors.expense;
    }
  }
}

enum _PasteRowStatus { ready, duplicate, conflict, invalid }

_BuildRowsResult _buildRows({
  required String rawText,
  required DateTime selectedMonth,
  required List<TransactionModel> transactions,
}) {
  final rows = <_PasteImportRow>[];
  final selectedIndexes = <int>{};
  final existingCiroByDate = <String, double>{};
  final existingExactRows = <String>{};
  for (final transaction in transactions) {
    if (transaction.type == TransactionTypes.ciro) {
      existingCiroByDate.update(
        transaction.date,
        (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }
    existingExactRows.add(_transactionSignature(transaction));
  }

  final seenPasteRows = <String>{};
  final lines = rawText.split(RegExp(r'\r?\n'));
  for (var index = 0; index < lines.length; index++) {
    final rawLine = lines[index].trim();
    if (_shouldSkipLine(rawLine)) {
      continue;
    }

    final parsed = _parseLine(rawLine, selectedMonth);
    if (parsed.error != null) {
      rows.add(
        _rowFromParsed(
          sourceLine: index + 1,
          rawText: rawLine,
          status: _PasteRowStatus.invalid,
          message: parsed.error!,
          parsed: parsed,
        ),
      );
      continue;
    }

    final date = parsed.date!;
    final dateKey = AppDateUtils.dateKey(date);
    if (date.year != selectedMonth.year || date.month != selectedMonth.month) {
      rows.add(
        _rowFromParsed(
          sourceLine: index + 1,
          rawText: rawLine,
          status: _PasteRowStatus.invalid,
          message: 'Seçili ay dışında',
          parsed: parsed,
        ),
      );
      continue;
    }

    final pasteSignature = _parsedSignature(parsed);
    final pasteDuplicateKey = parsed.type == TransactionTypes.ciro
        ? '${TransactionTypes.ciro}|$dateKey'
        : pasteSignature;
    if (seenPasteRows.contains(pasteDuplicateKey)) {
      rows.add(
        _rowFromParsed(
          sourceLine: index + 1,
          rawText: rawLine,
          status: _PasteRowStatus.conflict,
          message: parsed.type == TransactionTypes.ciro
              ? 'Listede aynı gün tekrar var'
              : 'Listede aynı kayıt tekrar var',
          parsed: parsed,
        ),
      );
      continue;
    }
    seenPasteRows.add(pasteDuplicateKey);

    final existingAmount = parsed.type == TransactionTypes.ciro
        ? existingCiroByDate[dateKey]
        : null;
    if (parsed.type == TransactionTypes.ciro && existingAmount != null) {
      final sameAmount = (existingAmount - parsed.amount).abs() < 0.01;
      rows.add(
        _rowFromParsed(
          sourceLine: index + 1,
          rawText: rawLine,
          status:
              sameAmount ? _PasteRowStatus.duplicate : _PasteRowStatus.conflict,
          message: sameAmount
              ? 'Zaten var'
              : 'Mevcut ${MoneyUtils.format(existingAmount)}',
          parsed: parsed,
        ),
      );
      continue;
    }

    if (existingExactRows.contains(pasteSignature)) {
      rows.add(
        _rowFromParsed(
          sourceLine: index + 1,
          rawText: rawLine,
          status: _PasteRowStatus.duplicate,
          message: 'Zaten var',
          parsed: parsed,
        ),
      );
      continue;
    }

    rows.add(
      _rowFromParsed(
        sourceLine: index + 1,
        rawText: rawLine,
        status: _PasteRowStatus.ready,
        message: 'Eklenecek',
        parsed: parsed,
      ),
    );
    selectedIndexes.add(rows.length - 1);
  }

  return _BuildRowsResult(rows: rows, selectedIndexes: selectedIndexes);
}

_PasteImportRow _rowFromParsed({
  required int sourceLine,
  required String rawText,
  required _PasteRowStatus status,
  required String message,
  required _ParsedLine parsed,
}) {
  return _PasteImportRow(
    sourceLine: sourceLine,
    rawText: rawText,
    date: parsed.date,
    type: parsed.type,
    category: parsed.category,
    person: parsed.person,
    amount: parsed.amount,
    paymentSource: parsed.paymentSource,
    description: parsed.description,
    status: status,
    message: message,
  );
}

bool _shouldSkipLine(String line) {
  if (line.isEmpty) {
    return true;
  }
  final folded = _foldTurkish(line).replaceAll(RegExp(r'\s+'), ' ');
  return folded == 'gun ciro' ||
      folded == 'tarih ciro' ||
      folded == 'gun tutar' ||
      folded == 'tarih tutar' ||
      folded == 'gun islem konu tutar' ||
      folded == 'tarih islem konu tutar';
}

class _ParsedLine {
  const _ParsedLine({
    required this.date,
    required this.type,
    required this.category,
    required this.person,
    required this.amount,
    required this.paymentSource,
    required this.description,
    this.error,
  });

  final DateTime? date;
  final String type;
  final String category;
  final String person;
  final double amount;
  final String paymentSource;
  final String description;
  final String? error;
}

_ParsedLine _parseLine(String line, DateTime selectedMonth) {
  final hasDelimiter = RegExp(r'[;\t|]').hasMatch(line);
  if (hasDelimiter) {
    final delimitedParts =
        line.split(RegExp(r'[;\t|]')).map((item) => item.trim()).toList();
    return _parseDelimitedLine(delimitedParts, selectedMonth);
  }

  final typedLine = _parseTypedSpaceLine(line, selectedMonth);
  if (typedLine != null) {
    return typedLine;
  }

  final isoMatch = RegExp(r'^\s*(\d{4})[-./](\d{1,2})[-./](\d{1,2})\s+(.+)$')
      .firstMatch(line);
  if (isoMatch != null) {
    final date = _dateFromParts(
      year: int.tryParse(isoMatch.group(1)!),
      month: int.tryParse(isoMatch.group(2)!),
      day: int.tryParse(isoMatch.group(3)!),
    );
    return _parseCiroForDate(date, isoMatch.group(4) ?? '');
  }

  final dateMatch =
      RegExp(r'^\s*(\d{1,2})[./-](\d{1,2})(?:[./-](\d{2,4}))?\s+(.+)$')
          .firstMatch(line);
  if (dateMatch != null) {
    final yearText = dateMatch.group(3);
    final year = yearText == null
        ? selectedMonth.year
        : _normalizeYear(int.tryParse(yearText));
    final date = _dateFromParts(
      year: year,
      month: int.tryParse(dateMatch.group(2)!),
      day: int.tryParse(dateMatch.group(1)!),
    );
    return _parseCiroForDate(date, dateMatch.group(4) ?? '');
  }

  final dayMatch = RegExp(r'^\s*(\d{1,2})\s*[,;:-]?\s+(.+)$').firstMatch(line);
  if (dayMatch != null) {
    final date = _dateFromParts(
      year: selectedMonth.year,
      month: selectedMonth.month,
      day: int.tryParse(dayMatch.group(1)!),
    );
    return _parseCiroForDate(date, dayMatch.group(2) ?? '');
  }

  return _invalidParsedLine('Gün okunamadı');
}

_ParsedLine _parseDelimitedLine(
  List<String> parts,
  DateTime selectedMonth,
) {
  final compactParts = parts.where((part) => part.isNotEmpty).toList();
  if (compactParts.length < 2) {
    return _invalidParsedLine('Satır okunamadı');
  }

  final firstType = _parseTransactionType(compactParts[0]);
  if (firstType != null) {
    return _parseTypedParts(
      type: firstType,
      dateText: compactParts.length > 1 ? compactParts[1] : '',
      subjectText: compactParts.length > 2 ? compactParts[2] : '',
      amountText: compactParts.length > 3 ? compactParts[3] : '',
      paymentSourceText: compactParts.length > 4 ? compactParts[4] : '',
      selectedMonth: selectedMonth,
    );
  }

  final secondType =
      compactParts.length > 1 ? _parseTransactionType(compactParts[1]) : null;
  if (secondType == null) {
    return _parseCiroForDate(
      _parseDateText(compactParts.first, selectedMonth),
      compactParts.sublist(1).join(' '),
    );
  }

  return _parseTypedParts(
    type: secondType,
    dateText: compactParts.first,
    subjectText: compactParts.length > 2 ? compactParts[2] : '',
    amountText: compactParts.length > 3 ? compactParts[3] : '',
    paymentSourceText: compactParts.length > 4 ? compactParts[4] : '',
    selectedMonth: selectedMonth,
  );
}

_ParsedLine? _parseTypedSpaceLine(String line, DateTime selectedMonth) {
  final tokens = line.split(RegExp(r'\s+')).where((item) => item.isNotEmpty);
  final parts = tokens.toList();
  if (parts.length < 3) {
    return null;
  }

  final firstType = _parseTransactionType(parts[0]);
  if (firstType != null) {
    return _parseTypedFreeText(
      type: firstType,
      dateText: parts[1],
      bodyText: parts.sublist(2).join(' '),
      selectedMonth: selectedMonth,
    );
  }

  final secondType = _parseTransactionType(parts[1]);
  if (secondType != null) {
    return _parseTypedFreeText(
      type: secondType,
      dateText: parts[0],
      bodyText: parts.sublist(2).join(' '),
      selectedMonth: selectedMonth,
    );
  }

  return null;
}

_ParsedLine _parseTypedFreeText({
  required String type,
  required String dateText,
  required String bodyText,
  required DateTime selectedMonth,
}) {
  final split = _splitSubjectAndAmount(bodyText);
  return _parseTypedParts(
    type: type,
    dateText: dateText,
    subjectText: split.subject,
    amountText: split.amountText,
    paymentSourceText: '',
    selectedMonth: selectedMonth,
  );
}

_ParsedLine _parseTypedParts({
  required String type,
  required String dateText,
  required String subjectText,
  required String amountText,
  required String paymentSourceText,
  required DateTime selectedMonth,
}) {
  final date = _parseDateText(dateText, selectedMonth);
  if (date == null) {
    return _invalidParsedLine('Tarih hatalı');
  }

  var subject = subjectText.trim();
  var amountSource = amountText.trim();
  if (amountSource.isEmpty && type == TransactionTypes.ciro) {
    amountSource = subject;
    subject = '';
  }
  if (amountSource.isEmpty && type != TransactionTypes.ciro) {
    final split = _splitSubjectAndAmount(subject);
    subject = split.subject;
    amountSource = split.amountText;
  }

  final amount = _extractAmount(amountSource);
  if (amount <= 0) {
    return _ParsedLine(
      date: date,
      type: type,
      category: _categoryFor(type, subject),
      person: _personFor(type, subject),
      amount: 0,
      paymentSource: PaymentSources.cash,
      description: '',
      error: 'Tutar okunamadı',
    );
  }

  if (type == TransactionTypes.isci && subject.isEmpty) {
    return _ParsedLine(
      date: date,
      type: type,
      category: AppCategories.isci,
      person: '',
      amount: amount,
      paymentSource: PaymentSources.cash,
      description: '',
      error: 'Personel okunamadı',
    );
  }

  return _ParsedLine(
    date: date,
    type: type,
    category: _categoryFor(type, subject),
    person: _personFor(type, subject),
    amount: amount,
    paymentSource: _parsePaymentSource(paymentSourceText),
    description: _descriptionFor(type),
  );
}

_ParsedLine _parseCiroForDate(DateTime? date, String amountText) {
  if (date == null) {
    return _invalidParsedLine('Tarih hatalı');
  }

  final amount = _extractAmount(amountText);
  if (amount <= 0) {
    return _ParsedLine(
      date: date,
      type: TransactionTypes.ciro,
      category: AppCategories.ciro,
      person: '',
      amount: 0,
      paymentSource: PaymentSources.cash,
      description: 'Yapıştırarak ciro girişi',
      error: 'Tutar okunamadı',
    );
  }

  return _ParsedLine(
    date: date,
    type: TransactionTypes.ciro,
    category: AppCategories.ciro,
    person: '',
    amount: amount,
    paymentSource: PaymentSources.cash,
    description: 'Yapıştırarak ciro girişi',
  );
}

DateTime? _parseDateText(String dateText, DateTime selectedMonth) {
  final text = dateText.trim();
  final isoMatch =
      RegExp(r'^(\d{4})[-./](\d{1,2})[-./](\d{1,2})$').firstMatch(text);
  if (isoMatch != null) {
    return _dateFromParts(
      year: int.tryParse(isoMatch.group(1)!),
      month: int.tryParse(isoMatch.group(2)!),
      day: int.tryParse(isoMatch.group(3)!),
    );
  }

  final dateMatch =
      RegExp(r'^(\d{1,2})[./-](\d{1,2})(?:[./-](\d{2,4}))?$').firstMatch(text);
  if (dateMatch != null) {
    final yearText = dateMatch.group(3);
    return _dateFromParts(
      year: yearText == null
          ? selectedMonth.year
          : _normalizeYear(int.tryParse(yearText)),
      month: int.tryParse(dateMatch.group(2)!),
      day: int.tryParse(dateMatch.group(1)!),
    );
  }

  return _dateFromParts(
    year: selectedMonth.year,
    month: selectedMonth.month,
    day: int.tryParse(text),
  );
}

double _extractAmount(String text) {
  final match = _moneyPattern.firstMatch(text);
  if (match == null) {
    return 0;
  }
  return MoneyUtils.parse(match.group(0) ?? '');
}

_SubjectAmountSplit _splitSubjectAndAmount(String text) {
  final matches = _moneyPattern.allMatches(text).toList();
  if (matches.isEmpty) {
    return _SubjectAmountSplit(subject: text.trim(), amountText: '');
  }
  final match = matches.last;
  final subject =
      '${text.substring(0, match.start)} ${text.substring(match.end)}'.trim();
  return _SubjectAmountSplit(
    subject: subject,
    amountText: match.group(0) ?? '',
  );
}

String? _parseTransactionType(String value) {
  final folded = _foldTurkish(value);
  if (folded == 'ciro' || folded == 'gelir') {
    return TransactionTypes.ciro;
  }
  if (folded == 'masraf' || folded == 'gider' || folded == 'harcama') {
    return TransactionTypes.masraf;
  }
  if (folded == 'isci' ||
      folded == 'isçi' ||
      folded == 'personel' ||
      folded == 'calisan') {
    return TransactionTypes.isci;
  }
  return null;
}

String _categoryFor(String type, String subject) {
  if (type == TransactionTypes.ciro) {
    return AppCategories.ciro;
  }
  if (type == TransactionTypes.isci) {
    return AppCategories.isci;
  }
  final trimmed = subject.trim();
  return trimmed.isEmpty ? 'Genel Masraf' : trimmed;
}

String _personFor(String type, String subject) {
  if (type == TransactionTypes.isci) {
    return subject.trim();
  }
  return '';
}

String _descriptionFor(String type) {
  if (type == TransactionTypes.ciro) {
    return 'Yapıştırarak ciro girişi';
  }
  if (type == TransactionTypes.isci) {
    return 'Yapıştırarak işçi ödemesi';
  }
  return 'Yapıştırarak masraf girişi';
}

String _parsePaymentSource(String value) {
  final folded = _foldTurkish(value);
  if (folded.contains('sahsi') ||
      folded.contains('kisisel') ||
      folded.contains('cebim')) {
    return PaymentSources.personal;
  }
  if (folded.contains('kredi') ||
      folded.contains('kart') ||
      folded.contains('banka')) {
    return PaymentSources.bank;
  }
  return PaymentSources.cash;
}

String _transactionSignature(TransactionModel transaction) {
  return _signature(
    date: transaction.date,
    type: transaction.type,
    category: transaction.category,
    person: transaction.person,
    amount: transaction.amount,
  );
}

String _parsedSignature(_ParsedLine parsed) {
  return _signature(
    date: AppDateUtils.dateKey(parsed.date!),
    type: parsed.type,
    category: parsed.category,
    person: parsed.person,
    amount: parsed.amount,
  );
}

String _signature({
  required String date,
  required String type,
  required String category,
  required String person,
  required double amount,
}) {
  final subject = type == TransactionTypes.isci ? person : category;
  return '$date|$type|${_foldTurkish(subject)}|${amount.toStringAsFixed(2)}';
}

_ParsedLine _invalidParsedLine(String error) {
  return _ParsedLine(
    date: null,
    type: '',
    category: '',
    person: '',
    amount: 0,
    paymentSource: '',
    description: '',
    error: error,
  );
}

class _SubjectAmountSplit {
  const _SubjectAmountSplit({
    required this.subject,
    required this.amountText,
  });

  final String subject;
  final String amountText;
}

final _moneyPattern = RegExp(
  r'[-+]?\s*(?:\d{1,3}(?:[.\s]\d{3})+(?:,\d{1,2})?|\d+(?:[.,]\d{1,2})?)',
);

DateTime? _dateFromParts({
  required int? year,
  required int? month,
  required int? day,
}) {
  if (year == null || month == null || day == null) {
    return null;
  }
  if (month < 1 || month > 12 || day < 1) {
    return null;
  }
  final lastDay = DateTime(year, month + 1, 0).day;
  if (day > lastDay) {
    return null;
  }
  return DateTime(year, month, day);
}

int? _normalizeYear(int? year) {
  if (year == null) {
    return null;
  }
  if (year < 100) {
    return 2000 + year;
  }
  return year;
}

double _sumRows(Iterable<_PasteImportRow> rows) {
  return rows.fold<double>(0, (sum, row) => sum + row.amount);
}

String _foldTurkish(String value) {
  final buffer = StringBuffer();
  for (final rune in value.toLowerCase().runes) {
    switch (rune) {
      case 0x00E7:
        buffer.write('c');
        break;
      case 0x011F:
        buffer.write('g');
        break;
      case 0x0131:
        buffer.write('i');
        break;
      case 0x0307:
        break;
      case 0x00F6:
        buffer.write('o');
        break;
      case 0x015F:
        buffer.write('s');
        break;
      case 0x00FC:
        buffer.write('u');
        break;
      default:
        buffer.writeCharCode(rune);
    }
  }
  return buffer.toString().trim();
}
