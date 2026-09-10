import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/utils/date_utils.dart';
import '../models/sheet_ciro_snapshot.dart';

final sheetCiroRepositoryProvider = Provider<SheetCiroRepository>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return SheetCiroRepository(client);
});

final sheetCiroByMonthProvider =
    FutureProvider.autoDispose.family<SheetCiroSnapshot, String>(
  (ref, monthKey) {
    final refresh = Timer(const Duration(minutes: 15), ref.invalidateSelf);
    ref.onDispose(refresh.cancel);
    return ref.watch(sheetCiroRepositoryProvider).fetchByMonth(monthKey);
  },
);

class SheetCiroRepository {
  SheetCiroRepository(this._client, {Uri? snapshotUri})
      : _snapshotUri = snapshotUri ??
            Uri.parse(
              'https://onuronozer.github.io/'
              'palaoglu-kasa-takip-app/data/sheet-ciro.json',
            );

  static const spreadsheetId = '1W6b9GxO6g-krIn_pXBidJpxhrPQypReLjocA3jq4bRQ';

  final http.Client _client;
  final Uri _snapshotUri;

  Future<SheetCiroSnapshot> fetchByMonth(String monthKey) async {
    final uri = _snapshotUri.replace(
      queryParameters: {
        ..._snapshotUri.queryParameters,
        'v': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );
    final response =
        await _client.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('E-tablo okunamadı.');
    }
    return parseSnapshot(response.body, monthKey);
  }

  static SheetCiroSnapshot parseSnapshot(String body, String monthKey) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic> ||
        decoded['version'] != 1 ||
        decoded['spreadsheetId'] != spreadsheetId) {
      throw const FormatException('E-tablo veri biçimi geçersiz.');
    }

    final checkedAt = DateTime.tryParse(decoded['checkedAt']?.toString() ?? '');
    final months = decoded['months'];
    if (checkedAt == null || months is! Map<String, dynamic>) {
      throw const FormatException('E-tablo kontrol bilgisi eksik.');
    }

    final month = months[monthKey];
    if (month == null) {
      return SheetCiroSnapshot.noSource(monthKey, checkedAt: checkedAt);
    }
    if (month is! Map<String, dynamic> ||
        month['ciroByDate'] is! Map<String, dynamic> ||
        (month['invalidDateCount'] as num? ?? 0) > 0) {
      throw const FormatException('Aylık e-tablo verileri doğrulanamadı.');
    }

    final ciroByDate = <String, double>{};
    for (final entry in (month['ciroByDate'] as Map<String, dynamic>).entries) {
      final date = DateTime.tryParse(entry.key);
      final value = entry.value;
      if (date == null ||
          value is! num ||
          !value.isFinite ||
          value <= 0 ||
          !entry.key.startsWith(monthKey) ||
          AppDateUtils.dateKey(date) != entry.key) {
        throw const FormatException('E-tablo satırlarından biri geçersiz.');
      }
      ciroByDate[entry.key] = value.toDouble();
    }

    return SheetCiroSnapshot(
      monthKey: monthKey,
      hasSource: true,
      ciroByDate: ciroByDate,
      checkedAt: checkedAt,
    );
  }
}
