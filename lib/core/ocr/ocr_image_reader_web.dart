import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;

import 'ocr_image_result.dart';

const _tesseractCdn =
    'https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/tesseract.min.js';

Future<OcrImageResult?> pickImageAndReadOcrText() async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..multiple = false;

  input.click();
  await input.onChange.first;

  final files = input.files;
  if (files == null || files.isEmpty) {
    return null;
  }

  final file = files.first;
  final tesseract = await _loadTesseract();
  final promise = tesseract.callMethod('recognize', [file, 'tur+eng']);
  final result = await _promiseToJsObject(promise);
  final data = result['data'];
  final text = data is js.JsObject ? data['text']?.toString() ?? '' : '';

  return OcrImageResult(fileName: file.name, text: text);
}

Future<js.JsObject> _loadTesseract() async {
  final existing = js.context['Tesseract'];
  if (existing is js.JsObject) {
    return existing;
  }

  final completer = Completer<void>();
  final script = html.ScriptElement()
    ..src = _tesseractCdn
    ..async = true;

  script.onLoad.first.then((_) {
    if (!completer.isCompleted) {
      completer.complete();
    }
  });
  script.onError.first.then((_) {
    if (!completer.isCompleted) {
      completer.completeError(
        StateError('OCR motoru yüklenemedi. İnternet bağlantısını kontrol et.'),
      );
    }
  });

  html.document.head?.append(script);
  await completer.future.timeout(
    const Duration(seconds: 20),
    onTimeout: () => throw StateError('OCR motoru çok geç yüklendi.'),
  );

  final loaded = js.context['Tesseract'];
  if (loaded is! js.JsObject) {
    throw StateError('OCR motoru hazır değil.');
  }
  return loaded;
}

Future<js.JsObject> _promiseToJsObject(Object promise) {
  final completer = Completer<js.JsObject>();
  if (promise is! js.JsObject) {
    return Future.error(StateError('OCR sonucu okunamadı.'));
  }

  promise.callMethod('then', [
    (Object result) {
      if (!completer.isCompleted && result is js.JsObject) {
        completer.complete(result);
      } else if (!completer.isCompleted) {
        completer.completeError(StateError('OCR sonucu boş geldi.'));
      }
    },
    (Object error) {
      if (!completer.isCompleted) {
        completer.completeError(StateError(error.toString()));
      }
    },
  ]);

  return completer.future;
}
