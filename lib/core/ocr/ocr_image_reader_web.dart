import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;

import 'ocr_image_result.dart';

const _tesseractCdn =
    'https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/tesseract.min.js';
const _tesseractWorkerCdn =
    'https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/worker.min.js';
const _tesseractLangCdn = 'https://tessdata.projectnaptha.com/4.0.0';
const _ocrLanguage = 'eng';
const _maxOcrImageSide = 1600;

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
  final imageDataUrl = await _prepareImageForOcr(file);
  final result = await _recognizeImage(tesseract, imageDataUrl).timeout(
    const Duration(seconds: 90),
    onTimeout: () {
      throw StateError(
        'OCR uzun sürdü ve durduruldu. Tekrar OCR ile Oku düğmesine basabilirsin.',
      );
    },
  );
  final data = result['data'];
  final text = data is js.JsObject ? data['text']?.toString() ?? '' : '';

  return OcrImageResult(fileName: file.name, text: text);
}

Future<String> _prepareImageForOcr(html.File file) async {
  final originalDataUrl = await _readFileAsDataUrl(file);
  try {
    final image = html.ImageElement(src: originalDataUrl);
    await image.onLoad.first.timeout(const Duration(seconds: 12));

    final width = image.naturalWidth;
    final height = image.naturalHeight;
    if (width <= 0 || height <= 0) {
      return originalDataUrl;
    }

    final longestSide = width > height ? width : height;
    final scale =
        longestSide > _maxOcrImageSide ? _maxOcrImageSide / longestSide : 1.0;
    final targetWidth = (width * scale).round();
    final targetHeight = (height * scale).round();

    final canvas = html.CanvasElement(
      width: targetWidth,
      height: targetHeight,
    );
    final context = canvas.context2D;
    context
      ..fillStyle = 'white'
      ..fillRect(0, 0, targetWidth, targetHeight)
      ..drawImageScaled(image, 0, 0, targetWidth, targetHeight);

    return canvas.toDataUrl('image/jpeg', 0.88);
  } catch (_) {
    return originalDataUrl;
  }
}

Future<String> _readFileAsDataUrl(html.File file) async {
  final reader = html.FileReader();
  reader.readAsDataUrl(file);
  await reader.onLoad.first;
  final result = reader.result?.toString();
  if (result == null || result.isEmpty) {
    throw StateError('Görsel tekrar okunamadı. Dosyayı yeniden seç.');
  }
  return result;
}

Future<js.JsObject> _recognizeImage(
  js.JsObject tesseract,
  String imageDataUrl,
) async {
  final createWorker = tesseract['createWorker'];
  if (createWorker != null) {
    js.JsObject? worker;
    try {
      final workerPromise = tesseract.callMethod('createWorker', [
        _ocrLanguage,
        1,
        js.JsObject.jsify({
          'workerPath': _tesseractWorkerCdn,
          'langPath': _tesseractLangCdn,
        }),
      ]);
      worker = await _promiseToJsObject(workerPromise);
      final resultPromise = worker.callMethod('recognize', [imageDataUrl]);
      return await _promiseToJsObject(resultPromise);
    } finally {
      if (worker != null) {
        await _promiseToAny(worker.callMethod('terminate', []));
      }
    }
  }

  final promise = tesseract.callMethod('recognize', [
    imageDataUrl,
    _ocrLanguage,
  ]);
  return _promiseToJsObject(promise);
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

Future<Object?> _promiseToAny(Object promise) {
  final completer = Completer<Object?>();
  if (promise is! js.JsObject) {
    return Future.value(promise);
  }

  final then = promise['then'];
  if (then == null) {
    return Future.value(promise);
  }

  promise.callMethod('then', [
    (Object? result) {
      if (!completer.isCompleted) {
        completer.complete(result);
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
