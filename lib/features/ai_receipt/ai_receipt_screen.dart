import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/categories.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/money_utils.dart';
import '../../data/models/app_user.dart';
import '../../data/models/employee_model.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/employee_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../auth/auth_controller.dart';
import '../entry/widgets/date_selector.dart';
import '../entry/widgets/payment_source_selector.dart';

class AiReceiptScreen extends ConsumerStatefulWidget {
  const AiReceiptScreen({this.initialMonthKey, super.key});

  final String? initialMonthKey;

  @override
  ConsumerState<AiReceiptScreen> createState() => _AiReceiptScreenState();
}

class _AiReceiptScreenState extends ConsumerState<AiReceiptScreen> {
  static const _apiKeyPrefsKey = 'palaoglu_gemini_api_key_v1';
  static const _modelPrefsKey = 'palaoglu_gemini_model_v1';
  static const _defaultModel = 'gemini-2.5-flash-lite';
  static const _modelOptions = [
    'gemini-2.5-flash-lite',
    'gemini-2.5-flash',
    'gemini-2.0-flash',
  ];

  final _apiKeyController = TextEditingController();
  final _totalCiroController = TextEditingController();
  final _lunchCiroController = TextEditingController();
  final _bankController = TextEditingController();
  final _debtController = TextEditingController();
  final _debtPersonController = TextEditingController();
  final _picker = ImagePicker();
  final _expenses = <_ExpenseDraft>[];
  final _workers = <_WorkerDraft>[];

  DateTime? _selectedDate;
  Uint8List? _imageBytes;
  String? _imageName;
  String _model = _defaultModel;
  String _debtCategory = AppCategories.debtGiven;
  bool _apiSaved = false;
  bool _reading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = _initialDate();
    _loadApiSettings();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _totalCiroController.dispose();
    _lunchCiroController.dispose();
    _bankController.dispose();
    _debtController.dispose();
    _debtPersonController.dispose();
    _disposeDrafts();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appUser = ref.watch(currentAppUserProvider).valueOrNull;
    final employeesState = ref.watch(activeEmployeesProvider);
    final employees = employeesState.valueOrNull ?? const <EmployeeModel>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Fiş Oku'),
        leading: IconButton(
          tooltip: 'Geri',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go('/kiraathane');
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ApiCard(
                    apiKeyController: _apiKeyController,
                    model: _model,
                    apiSaved: _apiSaved,
                    onModelChanged: (value) {
                      if (value != null) {
                        setState(() => _model = value);
                      }
                    },
                    onSave: _saveApiSettings,
                    onClear: _clearApiSettings,
                  ),
                  const SizedBox(height: 16),
                  _ImageCard(
                    imageBytes: _imageBytes,
                    imageName: _imageName,
                    reading: _reading,
                    onPick: _pickImage,
                    onRead: employeesState.isLoading
                        ? null
                        : () => _readWithAi(employees),
                  ),
                  const SizedBox(height: 16),
                  _ReceiptFormCard(
                    selectedDate: _selectedDate ?? DateTime.now(),
                    totalCiroController: _totalCiroController,
                    lunchCiroController: _lunchCiroController,
                    bankController: _bankController,
                    debtController: _debtController,
                    debtPersonController: _debtPersonController,
                    debtCategory: _debtCategory,
                    expenses: _expenses,
                    workers: _workers,
                    employees: employees,
                    saving: _saving,
                    onDateChanged: (date) {
                      setState(() => _selectedDate = date);
                    },
                    onDebtCategoryChanged: (value) {
                      if (value != null) {
                        setState(() => _debtCategory = value);
                      }
                    },
                    onAddExpense: () {
                      setState(() => _expenses.add(_ExpenseDraft()));
                    },
                    onRemoveExpense: (draft) {
                      setState(() {
                        _expenses.remove(draft);
                        draft.dispose();
                      });
                    },
                    onAddWorker: () {
                      setState(() => _workers.add(_WorkerDraft()));
                    },
                    onRemoveWorker: (draft) {
                      setState(() {
                        _workers.remove(draft);
                        draft.dispose();
                      });
                    },
                    onSave: appUser == null ? null : () => _save(appUser),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  DateTime _initialDate() {
    final initialMonth = AppDateUtils.monthFromKey(widget.initialMonthKey);
    final now = DateTime.now();
    final day = initialMonth.year == now.year && initialMonth.month == now.month
        ? now.day
        : 1;
    return DateTime(initialMonth.year, initialMonth.month, day);
  }

  Future<void> _loadApiSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    final apiKey = prefs.getString(_apiKeyPrefsKey) ?? '';
    setState(() {
      _apiKeyController.text = apiKey;
      final savedModel = prefs.getString(_modelPrefsKey) ?? _defaultModel;
      _model = _modelOptions.contains(savedModel) ? savedModel : _defaultModel;
      _apiSaved = apiKey.isNotEmpty;
    });
  }

  Future<void> _saveApiSettings() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      _showSnack('API key boş.');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPrefsKey, apiKey);
    await prefs.setString(_modelPrefsKey, _model);
    if (!mounted) {
      return;
    }
    setState(() => _apiSaved = true);
    _showSnack('API kaydedildi.');
  }

  Future<void> _clearApiSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiKeyPrefsKey);
    if (!mounted) {
      return;
    }
    setState(() {
      _apiKeyController.clear();
      _apiSaved = false;
    });
    _showSnack('API silindi.');
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (image == null) {
      return;
    }
    final bytes = await image.readAsBytes();
    if (!mounted) {
      return;
    }
    setState(() {
      _imageBytes = bytes;
      _imageName = image.name;
    });
  }

  Future<void> _readWithAi(List<EmployeeModel> employees) async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      _showSnack('API key gerekli.');
      return;
    }
    if (_imageBytes == null) {
      _showSnack('Görsel seç.');
      return;
    }

    setState(() => _reading = true);
    try {
      final result = await _callGemini(
        apiKey: apiKey,
        imageBytes: _imageBytes!,
        mimeType: _mimeTypeForImageName(_imageName),
      );
      _applyResult(result, employees);
      _showSnack('Fiş okundu.');
    } catch (error) {
      _showSnack(_friendlyAiError(error));
    } finally {
      if (mounted) {
        setState(() => _reading = false);
      }
    }
  }

  Future<_AiReceiptResult> _callGemini({
    required String apiKey,
    required Uint8List imageBytes,
    required String mimeType,
  }) async {
    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/$_model:generateContent',
      {'key': apiKey},
    );
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': _promptText()},
                  {
                    'inline_data': {
                      'mime_type': mimeType,
                      'data': base64Encode(imageBytes),
                    },
                  },
                ],
              },
            ],
            'generationConfig': {
              'temperature': 0,
              'responseMimeType': 'application/json',
            },
          }),
        )
        .timeout(const Duration(seconds: 45));

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = payload['error'];
      if (error is Map<String, dynamic>) {
        throw StateError(error['message'] as String? ?? 'AI isteği başarısız.');
      }
      throw StateError('AI isteği başarısız.');
    }

    final candidates = payload['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw StateError('AI sonucu boş.');
    }
    final content = candidates.first['content'];
    final parts = content is Map<String, dynamic> ? content['parts'] : null;
    final text = parts is List && parts.isNotEmpty
        ? parts.first['text'] as String?
        : null;
    if (text == null || text.trim().isEmpty) {
      throw StateError('AI sonucu okunamadı.');
    }

    return _AiReceiptResult.fromJson(_decodeJsonObject(text));
  }

  String _promptText() {
    return [
      'Bu Palaoğlu Kıraathanesi günlük fişi.',
      'Sadece görselde görünen rakamları oku.',
      'Emin olmadığın alanları boş bırak.',
      'Tarih bitişik yazıldıysa 22526 veya 220526 gibi değerleri 22.05.2026 formatına çevir.',
      'İşçi adını okuyamıyorsan isim alanını boş bırak, tahmin etme.',
      'Bankaya yatan ve kasadan verilen borç kutusundaki tek tutarı varsayılan olarak bankayaYatan alanına yaz.',
      'Sadece kişi adı veya borç notu açıkça görünüyorsa borcAlacak alanını doldur.',
      '110.000 gibi noktalı el yazısı değerleri yüz on bin olarak yorumla.',
      'İşçi ödemesinde isim ve tutar varsa isciOdemeleri listesine yaz.',
      'JSON döndür.',
      '{',
      '  "tarih": "string",',
      '  "toplamCiro": "number|string",',
      '  "oglenCiro": "number|string",',
      '  "bankayaYatan": "number|string",',
      '  "borcAlacak": "number|string",',
      '  "masraflar": [{"ad":"string","tutar":"number|string","not":"string"}],',
      '  "isciOdemeleri": [{"ad":"string","tutar":"number|string"}]',
      '}',
    ].join('\n');
  }

  Map<String, dynamic> _decodeJsonObject(String text) {
    var cleaned = text.trim();
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7).trim();
    }
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3).trim();
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3).trim();
    }
    try {
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (_) {
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start >= 0 && end > start) {
        return jsonDecode(cleaned.substring(start, end + 1))
            as Map<String, dynamic>;
      }
      rethrow;
    }
  }

  void _applyResult(_AiReceiptResult result, List<EmployeeModel> employees) {
    _disposeDrafts();
    _expenses.clear();
    _workers.clear();

    final date = _dateFromAi(result.dateText);
    final nextExpenses = [
      for (final item in result.expenses)
        _ExpenseDraft(
          category: _guessExpenseCategory(item.name),
          description: item.name,
          amount: item.amount == 0 ? '' : _plainAmount(item.amount),
        ),
    ];
    final nextWorkers = [
      for (final item in result.workerPayments)
        _WorkerDraft(
          selectedEmployee: _matchEmployee(item.name, employees),
          originalName: item.name,
          amount: item.amount == 0 ? '' : _plainAmount(item.amount),
        ),
    ];

    setState(() {
      _selectedDate = date ?? _selectedDate;
      _totalCiroController.text =
          result.totalCiro == 0 ? '' : _plainAmount(result.totalCiro);
      _lunchCiroController.text =
          result.lunchCiro == 0 ? '' : _plainAmount(result.lunchCiro);
      _bankController.text =
          result.bankAmount == 0 ? '' : _plainAmount(result.bankAmount);
      _debtController.text =
          result.debtAmount == 0 ? '' : _plainAmount(result.debtAmount);
      _expenses.addAll(nextExpenses);
      _workers.addAll(nextWorkers);
    });
  }

  Future<void> _save(AppUser appUser) async {
    final date = _selectedDate ?? DateTime.now();
    final transactions = <TransactionModel>[];
    final errors = <String>[];
    final totalCiro = MoneyUtils.parse(_totalCiroController.text);
    final lunchCiro = MoneyUtils.parse(_lunchCiroController.text);
    final bankAmount = MoneyUtils.parse(_bankController.text);
    final debtAmount = MoneyUtils.parse(_debtController.text);

    if (totalCiro > 0) {
      transactions.add(
        _transaction(
          appUser: appUser,
          date: date,
          type: TransactionTypes.ciro,
          category: AppCategories.ciro,
          amount: totalCiro,
          description: lunchCiro > 0
              ? 'AI fiş - Öğlen ciro: ${MoneyUtils.format(lunchCiro)}'
              : 'AI fiş',
        ),
      );
    }

    for (var index = 0; index < _expenses.length; index++) {
      final draft = _expenses[index];
      final amount = MoneyUtils.parse(draft.amountController.text);
      if (amount <= 0) {
        continue;
      }
      if (draft.category.isEmpty) {
        errors.add('Masraf ${index + 1}: kategori seç.');
        continue;
      }
      transactions.add(
        _transaction(
          appUser: appUser,
          date: date,
          type: TransactionTypes.masraf,
          category: draft.category,
          amount: amount,
          description: draft.descriptionController.text.trim().isEmpty
              ? 'AI fiş'
              : draft.descriptionController.text.trim(),
          paymentSource: draft.paymentSource,
        ),
      );
    }

    for (var index = 0; index < _workers.length; index++) {
      final draft = _workers[index];
      final amount = MoneyUtils.parse(draft.amountController.text);
      if (amount <= 0) {
        continue;
      }
      if (draft.selectedEmployee == null || draft.selectedEmployee!.isEmpty) {
        errors.add('İşçi ${index + 1}: personel seç.');
        continue;
      }
      transactions.add(
        _transaction(
          appUser: appUser,
          date: date,
          type: TransactionTypes.isci,
          category: AppCategories.isci,
          person: draft.selectedEmployee!,
          amount: amount,
          description: draft.originalName.trim().isEmpty
              ? 'AI fiş'
              : 'AI fiş - ${draft.originalName.trim()}',
          paymentSource: draft.paymentSource,
        ),
      );
    }

    if (bankAmount > 0) {
      transactions.add(
        _transaction(
          appUser: appUser,
          date: date,
          type: TransactionTypes.banka,
          category: AppCategories.banka,
          amount: bankAmount,
          description: 'AI fiş',
        ),
      );
    }

    if (debtAmount > 0) {
      final person = _debtPersonController.text.trim();
      if (person.isEmpty) {
        errors.add('Borç / Alacak: kişi adı gir.');
      } else {
        transactions.add(
          _transaction(
            appUser: appUser,
            date: date,
            type: TransactionTypes.borc,
            category: _debtCategory,
            person: person,
            amount: debtAmount,
            description: 'AI fiş',
          ),
        );
      }
    }

    if (errors.isNotEmpty) {
      _showSnack(errors.first);
      return;
    }
    if (transactions.isEmpty) {
      _showSnack('Kaydedilecek kayıt yok.');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(transactionRepositoryProvider)
          .addTransactions(transactions);
      if (!mounted) {
        return;
      }
      _showSnack('${transactions.length} kayıt eklendi.');
      context.pop();
    } catch (_) {
      _showSnack('Kayıtlar eklenemedi.');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  TransactionModel _transaction({
    required AppUser appUser,
    required DateTime date,
    required String type,
    required String category,
    required double amount,
    required String description,
    String person = '',
    String paymentSource = PaymentSources.cash,
  }) {
    return TransactionModel(
      id: '',
      date: AppDateUtils.dateKey(date),
      monthKey: AppDateUtils.monthKey(date),
      type: type,
      category: category,
      person: person,
      amount: amount,
      description: description,
      createdByUid: appUser.uid,
      createdByName: appUser.displayName,
      paymentSource: paymentSource,
    );
  }

  String _plainAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.round().toString();
    }
    return amount.toStringAsFixed(2).replaceAll('.', ',');
  }

  String _mimeTypeForImageName(String? name) {
    final lower = (name ?? '').toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lower.endsWith('.heic')) {
      return 'image/heic';
    }
    if (lower.endsWith('.heif')) {
      return 'image/heif';
    }
    return 'image/jpeg';
  }

  String _guessExpenseCategory(String text) {
    final normalized = _normalizeText(text);
    if (normalized.contains('kira')) {
      return 'Kira';
    }
    if (normalized.contains('muhasebe')) {
      return 'Muhasebe';
    }
    return 'Genel Masraf';
  }

  String? _matchEmployee(String name, List<EmployeeModel> employees) {
    final normalized = _normalizeText(name);
    if (normalized.isEmpty) {
      return null;
    }
    for (final employee in employees) {
      final employeeName = _normalizeText(employee.name);
      if (normalized == employeeName) {
        return employee.name;
      }
    }
    for (final employee in employees) {
      final employeeName = _normalizeText(employee.name);
      if (normalized.contains(employeeName) ||
          employeeName.contains(normalized)) {
        return employee.name;
      }
    }
    return null;
  }

  DateTime? _dateFromAi(String value) {
    final normalized = _normalizeDateText(value);
    final parts = normalized.split('.');
    if (parts.length != 3) {
      return null;
    }
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) {
      return null;
    }
    return DateTime(year, month, day);
  }

  String _normalizeDateText(String value) {
    final text = value.trim();
    if (RegExp(r'^\d{1,2}[./-]\d{1,2}[./-]\d{2,4}$').hasMatch(text)) {
      final parts = text.split(RegExp(r'[./-]'));
      return _formatDateParts(parts[0], parts[1], parts[2]);
    }
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 5) {
      return _formatDateParts(
        digits.substring(0, 2),
        digits.substring(2, 3),
        digits.substring(3),
      );
    }
    if (digits.length == 6) {
      return _formatDateParts(
        digits.substring(0, 2),
        digits.substring(2, 4),
        digits.substring(4),
      );
    }
    if (digits.length == 8) {
      return _formatDateParts(
        digits.substring(0, 2),
        digits.substring(2, 4),
        digits.substring(4),
      );
    }
    return text;
  }

  String _formatDateParts(String day, String month, String year) {
    final dd = (int.tryParse(day) ?? 0).toString().padLeft(2, '0');
    final mm = (int.tryParse(month) ?? 0).toString().padLeft(2, '0');
    var yyyy = year.trim();
    if (yyyy.length == 1) {
      yyyy = '202$yyyy';
    } else if (yyyy.length == 2) {
      yyyy = '20$yyyy';
    }
    return '$dd.$mm.$yyyy';
  }

  String _normalizeText(String value) {
    return value
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  String _friendlyAiError(Object error) {
    final text = error.toString();
    if (text.contains('API key not valid') || text.contains('API_KEY')) {
      return 'API key hatalı.';
    }
    if (text.contains('quota') || text.contains('RESOURCE_EXHAUSTED')) {
      return 'AI kotası doldu.';
    }
    return 'Fiş okunamadı.';
  }

  void _disposeDrafts() {
    for (final draft in _expenses) {
      draft.dispose();
    }
    for (final draft in _workers) {
      draft.dispose();
    }
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _ApiCard extends StatelessWidget {
  const _ApiCard({
    required this.apiKeyController,
    required this.model,
    required this.apiSaved,
    required this.onModelChanged,
    required this.onSave,
    required this.onClear,
  });

  final TextEditingController apiKeyController;
  final String model;
  final bool apiSaved;
  final ValueChanged<String?> onModelChanged;
  final VoidCallback onSave;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'API Ayarı',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              _StatusPill(text: apiSaved ? 'API kayıtlı' : 'API yok'),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: apiKeyController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Gemini API Key'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: model,
            decoration: const InputDecoration(labelText: 'Model'),
            items: const [
              DropdownMenuItem(
                value: 'gemini-2.5-flash-lite',
                child: Text('gemini-2.5-flash-lite'),
              ),
              DropdownMenuItem(
                value: 'gemini-2.5-flash',
                child: Text('gemini-2.5-flash'),
              ),
              DropdownMenuItem(
                value: 'gemini-2.0-flash',
                child: Text('gemini-2.0-flash'),
              ),
            ],
            onChanged: onModelChanged,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save_outlined),
                label: const Text('API Kaydet'),
              ),
              OutlinedButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.delete_outline),
                label: const Text('API Sil'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImageCard extends StatelessWidget {
  const _ImageCard({
    required this.imageBytes,
    required this.imageName,
    required this.reading,
    required this.onPick,
    required this.onRead,
  });

  final Uint8List? imageBytes;
  final String? imageName;
  final bool reading;
  final VoidCallback onPick;
  final VoidCallback? onRead;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Görsel', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: reading ? null : onPick,
            icon: const Icon(Icons.image_outlined),
            label: Text(imageName == null ? 'Görsel Seç' : 'Görsel Değiştir'),
          ),
          if (imageBytes != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(
                imageBytes!,
                height: 260,
                fit: BoxFit.contain,
              ),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: reading ? null : onRead,
            icon: reading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_outlined),
            label: Text(reading ? 'Okunuyor' : 'Oku'),
          ),
        ],
      ),
    );
  }
}

class _ReceiptFormCard extends StatelessWidget {
  const _ReceiptFormCard({
    required this.selectedDate,
    required this.totalCiroController,
    required this.lunchCiroController,
    required this.bankController,
    required this.debtController,
    required this.debtPersonController,
    required this.debtCategory,
    required this.expenses,
    required this.workers,
    required this.employees,
    required this.saving,
    required this.onDateChanged,
    required this.onDebtCategoryChanged,
    required this.onAddExpense,
    required this.onRemoveExpense,
    required this.onAddWorker,
    required this.onRemoveWorker,
    required this.onSave,
  });

  final DateTime selectedDate;
  final TextEditingController totalCiroController;
  final TextEditingController lunchCiroController;
  final TextEditingController bankController;
  final TextEditingController debtController;
  final TextEditingController debtPersonController;
  final String debtCategory;
  final List<_ExpenseDraft> expenses;
  final List<_WorkerDraft> workers;
  final List<EmployeeModel> employees;
  final bool saving;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<String?> onDebtCategoryChanged;
  final VoidCallback onAddExpense;
  final ValueChanged<_ExpenseDraft> onRemoveExpense;
  final VoidCallback onAddWorker;
  final ValueChanged<_WorkerDraft> onRemoveWorker;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('AI Fiş Kontrol', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          DateSelector(selectedDate: selectedDate, onChanged: onDateChanged),
          const SizedBox(height: 14),
          _AmountField(label: 'Toplam Ciro', controller: totalCiroController),
          const SizedBox(height: 12),
          _AmountField(label: 'Öğlen Ciro', controller: lunchCiroController),
          const SizedBox(height: 12),
          _AmountField(label: 'Bankaya Yatan', controller: bankController),
          const SizedBox(height: 12),
          _DebtFields(
            amountController: debtController,
            personController: debtPersonController,
            category: debtCategory,
            onCategoryChanged: onDebtCategoryChanged,
          ),
          const SizedBox(height: 18),
          _SectionHeader(title: 'Masraflar', onAdd: onAddExpense),
          const SizedBox(height: 10),
          if (expenses.isEmpty)
            const _EmptyText(text: 'Masraf yok.')
          else
            for (final draft in expenses) ...[
              _ExpenseDraftCard(
                key: ValueKey(draft),
                draft: draft,
                onRemove: () => onRemoveExpense(draft),
              ),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 8),
          _SectionHeader(title: 'İşçi Ödemeleri', onAdd: onAddWorker),
          const SizedBox(height: 10),
          if (workers.isEmpty)
            const _EmptyText(text: 'İşçi ödemesi yok.')
          else
            for (final draft in workers) ...[
              _WorkerDraftCard(
                key: ValueKey(draft),
                draft: draft,
                employees: employees,
                onRemove: () => onRemoveWorker(draft),
              ),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(saving ? 'Kaydediliyor' : 'Kaydet'),
          ),
        ],
      ),
    );
  }
}

class _DebtFields extends StatelessWidget {
  const _DebtFields({
    required this.amountController,
    required this.personController,
    required this.category,
    required this.onCategoryChanged,
  });

  final TextEditingController amountController;
  final TextEditingController personController;
  final String category;
  final ValueChanged<String?> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AmountField(label: 'Borç / Alacak', controller: amountController),
        const SizedBox(height: 12),
        TextField(
          controller: personController,
          decoration: const InputDecoration(labelText: 'Kişi'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: category,
          decoration: const InputDecoration(labelText: 'Borç / Alacak Tipi'),
          items: [
            for (final item in AppCategories.debtCategories)
              DropdownMenuItem(value: item, child: Text(item)),
          ],
          onChanged: onCategoryChanged,
        ),
      ],
    );
  }
}

class _ExpenseDraftCard extends StatefulWidget {
  const _ExpenseDraftCard({
    required this.draft,
    required this.onRemove,
    super.key,
  });

  final _ExpenseDraft draft;
  final VoidCallback onRemove;

  @override
  State<_ExpenseDraftCard> createState() => _ExpenseDraftCardState();
}

class _ExpenseDraftCardState extends State<_ExpenseDraftCard> {
  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    return _MiniCard(
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: draft.category.isEmpty ? null : draft.category,
            decoration: const InputDecoration(labelText: 'Kategori'),
            items: [
              for (final item in AppCategories.expenseCategories)
                DropdownMenuItem(value: item, child: Text(item)),
            ],
            onChanged: (value) {
              setState(() => draft.category = value ?? '');
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: draft.descriptionController,
            decoration: const InputDecoration(labelText: 'Açıklama'),
          ),
          const SizedBox(height: 12),
          _AmountField(label: 'Tutar', controller: draft.amountController),
          const SizedBox(height: 12),
          PaymentSourceSelector(
            selected: draft.paymentSource,
            onChanged: (value) {
              setState(() => draft.paymentSource = value);
            },
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: widget.onRemove,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Sil'),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkerDraftCard extends StatefulWidget {
  const _WorkerDraftCard({
    required this.draft,
    required this.employees,
    required this.onRemove,
    super.key,
  });

  final _WorkerDraft draft;
  final List<EmployeeModel> employees;
  final VoidCallback onRemove;

  @override
  State<_WorkerDraftCard> createState() => _WorkerDraftCardState();
}

class _WorkerDraftCardState extends State<_WorkerDraftCard> {
  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    return _MiniCard(
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: draft.selectedEmployee,
            decoration: const InputDecoration(labelText: 'Personel'),
            items: [
              for (final employee in widget.employees)
                DropdownMenuItem(
                    value: employee.name, child: Text(employee.name)),
            ],
            onChanged: (value) {
              setState(() => draft.selectedEmployee = value);
            },
          ),
          const SizedBox(height: 12),
          if (draft.originalName.trim().isNotEmpty) ...[
            TextFormField(
              initialValue: draft.originalName,
              enabled: false,
              decoration: const InputDecoration(labelText: 'Okunan İsim'),
            ),
            const SizedBox(height: 12),
          ],
          _AmountField(label: 'Tutar', controller: draft.amountController),
          const SizedBox(height: 12),
          PaymentSourceSelector(
            selected: draft.paymentSource,
            onChanged: (value) {
              setState(() => draft.paymentSource = value);
            },
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: widget.onRemove,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Sil'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onAdd});

  final String title;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Ekle'),
        ),
      ],
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: AppColors.mutedText));
  }
}

class _ExpenseDraft {
  _ExpenseDraft({
    this.category = 'Genel Masraf',
    String description = '',
    String amount = '',
  }) {
    descriptionController.text = description;
    amountController.text = amount;
  }

  String category;
  String paymentSource = PaymentSources.cash;
  final descriptionController = TextEditingController();
  final amountController = TextEditingController();

  void dispose() {
    descriptionController.dispose();
    amountController.dispose();
  }
}

class _WorkerDraft {
  _WorkerDraft({
    this.selectedEmployee,
    this.originalName = '',
    String amount = '',
  }) {
    amountController.text = amount;
  }

  String? selectedEmployee;
  String originalName;
  String paymentSource = PaymentSources.cash;
  final amountController = TextEditingController();

  void dispose() {
    amountController.dispose();
  }
}

class _AiReceiptResult {
  const _AiReceiptResult({
    required this.dateText,
    required this.totalCiro,
    required this.lunchCiro,
    required this.bankAmount,
    required this.debtAmount,
    required this.expenses,
    required this.workerPayments,
  });

  final String dateText;
  final double totalCiro;
  final double lunchCiro;
  final double bankAmount;
  final double debtAmount;
  final List<_AiMoneyItem> expenses;
  final List<_AiMoneyItem> workerPayments;

  factory _AiReceiptResult.fromJson(Map<String, dynamic> json) {
    return _AiReceiptResult(
      dateText: _stringValue(json['tarih']),
      totalCiro: _moneyValue(json['toplamCiro']),
      lunchCiro: _moneyValue(json['oglenCiro']),
      bankAmount: _moneyValue(json['bankayaYatan']),
      debtAmount: _moneyValue(json['borcAlacak']),
      expenses: _items(json['masraflar']),
      workerPayments: _items(json['isciOdemeleri']),
    );
  }

  static List<_AiMoneyItem> _items(Object? value) {
    if (value is! List) {
      return const [];
    }
    return [
      for (final item in value)
        if (item is Map<String, dynamic>)
          _AiMoneyItem(
            name: _stringValue(
                item['ad'] ?? item['kategori'] ?? item['aciklama']),
            amount: _moneyValue(item['tutar'] ?? item['amount']),
          ),
    ];
  }

  static String _stringValue(Object? value) {
    return value == null ? '' : value.toString().trim();
  }

  static double _moneyValue(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return MoneyUtils.parse(value?.toString() ?? '');
  }
}

class _AiMoneyItem {
  const _AiMoneyItem({required this.name, required this.amount});

  final String name;
  final double amount;
}
