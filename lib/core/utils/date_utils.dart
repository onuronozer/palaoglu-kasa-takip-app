import 'package:intl/intl.dart';

class AppDateUtils {
  const AppDateUtils._();

  static const monthNames = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  static String dateKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  static String monthKey(DateTime date) {
    return DateFormat('yyyy-MM').format(date);
  }

  static DateTime monthFromKey(String? key) {
    if (key == null || key.length != 7) {
      final now = DateTime.now();
      return DateTime(now.year, now.month);
    }

    final year = int.tryParse(key.substring(0, 4));
    final month = int.tryParse(key.substring(5, 7));
    if (year == null || month == null || month < 1 || month > 12) {
      final now = DateTime.now();
      return DateTime(now.year, now.month);
    }

    return DateTime(year, month);
  }

  static DateTime dateFromKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) {
      return DateTime.now();
    }

    return DateTime(
      int.tryParse(parts[0]) ?? DateTime.now().year,
      int.tryParse(parts[1]) ?? DateTime.now().month,
      int.tryParse(parts[2]) ?? DateTime.now().day,
    );
  }

  static String monthLabel(DateTime month) {
    return '${monthNames[month.month - 1]} ${month.year}';
  }

  static String monthLabelFromKey(String key) {
    return monthLabel(monthFromKey(key));
  }

  static DateTime previousMonth(DateTime month) {
    return DateTime(month.year, month.month - 1);
  }

  static DateTime nextMonth(DateTime month) {
    return DateTime(month.year, month.month + 1);
  }

  static int daysInMonth(DateTime month) {
    return DateTime(month.year, month.month + 1, 0).day;
  }

  static DateTime firstDayOfMonth(DateTime month) {
    return DateTime(month.year, month.month);
  }

  static DateTime lastDayOfMonth(DateTime month) {
    return DateTime(month.year, month.month, daysInMonth(month));
  }
}
