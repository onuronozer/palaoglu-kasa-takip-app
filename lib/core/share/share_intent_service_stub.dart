import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'shared_receipt_image.dart';

final shareIntentServiceProvider = Provider<ShareIntentService>((ref) {
  return ShareIntentService();
});

class ShareIntentService {
  Stream<SharedReceiptImage> get images => const Stream.empty();

  Future<void> initialize() async {}
}
