import 'ocr_image_reader_stub.dart'
    if (dart.library.html) 'ocr_image_reader_web.dart'
    if (dart.library.io) 'ocr_image_reader_mobile.dart' as implementation;
import 'ocr_image_result.dart';

export 'ocr_image_result.dart';

Future<OcrImageResult?> pickImageAndReadOcrText() {
  return implementation.pickImageAndReadOcrText();
}
