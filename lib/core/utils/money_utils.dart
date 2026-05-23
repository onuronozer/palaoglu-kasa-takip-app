import 'package:intl/intl.dart';

class MoneyUtils {
  const MoneyUtils._();

  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: 'TL',
    decimalDigits: 0,
    customPattern: '#,##0 ¤',
  );

  static String format(num value) {
    return _formatter.format(value);
  }

  static double parse(String value) {
    final cleaned = value
        .replaceAll('₺', '')
        .replaceAll('TL', '')
        .replaceAll('tl', '')
        .replaceAll(' ', '')
        .trim();

    if (cleaned.isEmpty) {
      return 0;
    }

    final normalized = _normalizeNumberInput(cleaned);

    return double.tryParse(normalized) ?? 0;
  }

  static String _normalizeNumberInput(String value) {
    if (value.contains(',') && value.contains('.')) {
      return value.replaceAll('.', '').replaceAll(',', '.');
    }

    if (value.contains(',')) {
      return value.replaceAll(',', '.');
    }

    if (value.contains('.')) {
      final parts = value.split('.');
      final looksLikeThousands = parts.length > 1 &&
          parts.last.length == 3 &&
          parts.every((part) => part.isNotEmpty);
      if (looksLikeThousands) {
        return value.replaceAll('.', '');
      }
    }

    return value;
  }
}
