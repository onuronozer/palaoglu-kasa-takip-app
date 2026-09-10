import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:palaoglu_kasa_takip/data/repositories/sheet_ciro_repository.dart';

void main() {
  test('yeni bir ayı kod değişikliği olmadan okur', () {
    final snapshot = SheetCiroRepository.parseSnapshot(
      _snapshot({
        '2026-10': {
          'sheetTitle': 'Ekim 2026',
          'ciroByDate': {'2026-10-01': 12345.0},
          'invalidDateCount': 0,
        },
      }),
      '2026-10',
    );

    expect(snapshot.hasSource, isTrue);
    expect(snapshot.ciroByDate['2026-10-01'], 12345);
    expect(snapshot.checkedAt, isNotNull);
  });

  test('sekme adıyla tarihleri uyuşmayan ayı reddeder', () {
    expect(
      () => SheetCiroRepository.parseSnapshot(
        _snapshot({
          '2026-10': {
            'sheetTitle': 'Ekim 2026',
            'ciroByDate': const <String, double>{},
            'invalidDateCount': 1,
          },
        }),
        '2026-10',
      ),
      throwsFormatException,
    );
  });

  test('henüz bulunmayan ayı veri kaynağı yok olarak döndürür', () {
    final snapshot = SheetCiroRepository.parseSnapshot(
      _snapshot(const {}),
      '2026-11',
    );

    expect(snapshot.hasSource, isFalse);
    expect(snapshot.ciroByDate, isEmpty);
  });
}

String _snapshot(Map<String, Object> months) {
  return jsonEncode({
    'version': 1,
    'spreadsheetId': SheetCiroRepository.spreadsheetId,
    'checkedAt': '2026-09-10T12:00:00Z',
    'months': months,
  });
}
