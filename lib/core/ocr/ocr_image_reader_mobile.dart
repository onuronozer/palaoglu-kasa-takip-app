import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import 'ocr_image_result.dart';

Future<OcrImageResult?> pickImageAndReadOcrText() async {
  final image = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    imageQuality: 100,
  );
  if (image == null) {
    return null;
  }

  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final inputImage = InputImage.fromFilePath(image.path);
    final recognizedText = await recognizer.processImage(inputImage);
    return OcrImageResult(fileName: image.name, text: recognizedText.text);
  } finally {
    await recognizer.close();
  }
}
