import 'package:flutter_test/flutter_test.dart';
import 'package:palaoglu_kasa_takip/core/utils/bulk_save_utils.dart';

void main() {
  test('başarılı satırları ayırır ve hatalı satırı yeniden denemeye bırakır',
      () async {
    final result = await saveBulkRows<int>(
      [1, 2, 3],
      save: (row) async {
        if (row == 2) {
          throw StateError('örnek hata');
        }
      },
      canContinue: () => true,
    );

    expect(result.saved, [1, 3]);
    expect(result.failed.keys, [2]);
  });
}
