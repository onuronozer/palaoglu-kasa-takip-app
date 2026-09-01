import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/utils/date_utils.dart';
import '../models/sheet_ciro_snapshot.dart';

final sheetCiroByMonthProvider =
    FutureProvider.autoDispose.family<SheetCiroSnapshot, String>(
  (ref, monthKey) {
    return SheetCiroRepository().fetchByMonth(monthKey);
  },
);

class SheetCiroRepository {
  static const _spreadsheetId = '1W6b9GxO6g-krIn_pXBidJpxhrPQypReLjocA3jq4bRQ';

  static const _gidsByMonth = {
    '2026-07': '1614156150',
    '2026-08': '1429067376',
  };

  Future<SheetCiroSnapshot> fetchByMonth(String monthKey) async {
    final gid = _gidsByMonth[monthKey];
    if (gid == null) {
      return SheetCiroSnapshot.noSource(monthKey);
    }

    final uri = Uri.https(
      'docs.google.com',
      '/spreadsheets/d/$_spreadsheetId/export',
      {
        'format': 'csv',
        'gid': gid,
        'v': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('E-tablo okunamadı.');
    }

    return SheetCiroSnapshot(
      monthKey: monthKey,
      hasSource: true,
      ciroByDate: _extractCiroByDate(response.body, monthKey),
    );
  }

  Map<String, double> _extractCiroByDate(String csvText, String monthKey) {
    final rows = _parseCsv(csvText);
    if (rows.length < 2) {
      return const {};
    }

    final ciroByDate = <String, double>{};
    for (final row in rows.skip(1)) {
      if (row.length < 2) {
        continue;
      }
      final dateKey = _parseDateKey(row[0]);
      if (dateKey == null || !dateKey.startsWith(monthKey)) {
        continue;
      }
      final amount = _parseSheetNumber(row[1]);
      if (amount <= 0) {
        continue;
      }
      ciroByDate[dateKey] = amount;
    }

    return ciroByDate;
  }
}

List<List<String>> _parseCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var inQuotes = false;

  for (var index = 0; index < text.length; index++) {
    final char = text[index];
    final next = index + 1 < text.length ? text[index + 1] : '';

    if (inQuotes) {
      if (char == '"' && next == '"') {
        cell.write('"');
        index++;
      } else if (char == '"') {
        inQuotes = false;
      } else {
        cell.write(char);
      }
      continue;
    }

    if (char == '"') {
      inQuotes = true;
    } else if (char == ',') {
      row.add(cell.toString());
      cell.clear();
    } else if (char == '\n') {
      row.add(cell.toString().replaceFirst(RegExp(r'\r$'), ''));
      rows.add(row);
      row = <String>[];
      cell.clear();
    } else {
      cell.write(char);
    }
  }

  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString().replaceFirst(RegExp(r'\r$'), ''));
    rows.add(row);
  }

  return rows;
}

String? _parseDateKey(String value) {
  final match = RegExp(
    r'^\s*(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})\s*$',
  ).firstMatch(value);
  if (match == null) {
    return null;
  }

  final day = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final rawYear = int.tryParse(match.group(3)!);
  final year = rawYear == null || rawYear >= 100 ? rawYear : 2000 + rawYear;
  if (day == null || month == null || year == null) {
    return null;
  }
  if (month < 1 || month > 12 || day < 1) {
    return null;
  }
  final lastDay = DateTime(year, month + 1, 0).day;
  if (day > lastDay) {
    return null;
  }

  return AppDateUtils.dateKey(DateTime(year, month, day));
}

double _parseSheetNumber(String value) {
  var cleaned = value
      .replaceAll('₺', '')
      .replaceAll('TL', '')
      .replaceAll('tl', '')
      .replaceAll(' ', '')
      .trim();
  if (cleaned.isEmpty) {
    return 0;
  }

  if (cleaned.contains(',') && cleaned.contains('.')) {
    cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
  } else if (cleaned.contains(',')) {
    cleaned = cleaned.replaceAll(',', '.');
  } else if (cleaned.contains('.')) {
    final parts = cleaned.split('.');
    final looksLikeThousands = parts.length > 1 &&
        parts.last.length == 3 &&
        parts.every((part) => part.isNotEmpty);
    if (looksLikeThousands) {
      cleaned = cleaned.replaceAll('.', '');
    }
  }

  return double.tryParse(cleaned) ?? 0;
}
