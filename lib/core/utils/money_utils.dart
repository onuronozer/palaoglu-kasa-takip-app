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

    final normalized = cleaned.contains(',') && cleaned.contains('.')
        ? cleaned.replaceAll('.', '').replaceAll(',', '.')
        : cleaned.replaceAll(',', '.');

    return double.tryParse(normalized) ?? 0;
  }
}
