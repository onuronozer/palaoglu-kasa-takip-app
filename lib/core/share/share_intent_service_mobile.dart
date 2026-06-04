import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_intent_package/share_intent_package.dart';

import 'shared_receipt_image.dart';

final shareIntentServiceProvider = Provider<ShareIntentService>((ref) {
  return ShareIntentService();
});

class ShareIntentService {
  static final StreamController<SharedReceiptImage> _imagesController =
      StreamController<SharedReceiptImage>.broadcast();
  static StreamSubscription<SharedData>? _subscription;
  static bool _initialized = false;
  static bool _initialChecked = false;
  static int _counter = 0;

  Stream<SharedReceiptImage> get images => _imagesController.stream;

  Future<void> initialize() async {
    if (!_initialized) {
      await ShareIntentPackage.instance.init(
        appGroupId: 'group.com.palaoglu.kasatakip',
      );
      _subscription ??= ShareIntentPackage.instance
          .getMediaStream()
          .listen(_handleSharedData);
      _initialized = true;
    }

    if (!_initialChecked) {
      _initialChecked = true;
      final initial = await ShareIntentPackage.instance.getInitialSharing();
      if (_handleSharedData(initial)) {
        await ShareIntentPackage.instance.reset();
      }
    }
  }

  bool _handleSharedData(SharedData? data) {
    if (data == null || data.filePaths.isEmpty) {
      return false;
    }

    final isImageMime = data.mimeType?.startsWith('image/') ?? false;
    final path = data.filePaths.firstWhere(
      (path) => isImageMime || _looksLikeImage(path),
      orElse: () => '',
    );
    if (path.isEmpty) {
      return false;
    }

    _imagesController.add(
      SharedReceiptImage(
        id: ++_counter,
        path: path,
        mimeType: data.mimeType,
      ),
    );
    unawaited(ShareIntentPackage.instance.reset());
    return true;
  }

  bool _looksLikeImage(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.heif');
  }
}
