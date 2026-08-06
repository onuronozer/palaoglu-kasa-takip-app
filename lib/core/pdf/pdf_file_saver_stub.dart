import 'dart:typed_data';

import 'package:printing/printing.dart';

Future<void> savePdfFile({
  required Uint8List bytes,
  required String filename,
}) {
  return Printing.sharePdf(bytes: bytes, filename: filename);
}
