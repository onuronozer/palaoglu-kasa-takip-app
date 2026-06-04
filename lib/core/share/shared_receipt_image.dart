import 'package:flutter_riverpod/flutter_riverpod.dart';

class SharedReceiptImage {
  const SharedReceiptImage({
    required this.id,
    required this.path,
    this.mimeType,
  });

  final int id;
  final String path;
  final String? mimeType;
}

final sharedReceiptImageProvider = StateProvider<SharedReceiptImage?>(
  (ref) => null,
);
