import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;

import 'ocr_image_result.dart';

const _tesseractVersion = 'v5.0.0';
const _tesseractCdn =
    'https://cdn.jsdelivr.net/npm/tesseract.js@$_tesseractVersion/dist/tesseract.min.js';
const _tesseractWorkerCdn =
    'https://cdn.jsdelivr.net/npm/tesseract.js@$_tesseractVersion/dist/worker.min.js';
const _tesseractCoreCdn =
    'https://cdn.jsdelivr.net/npm/tesseract.js-core@$_tesseractVersion';
const _tesseractLangCdn = 'https://tessdata.projectnaptha.com/4.0.0';
const _ocrLanguage = 'eng';
const _maxOcrImageSide = 1100;
bool _hasRefreshedTesseractCache = false;

Future<OcrImageResult?> pickImageAndReadOcrText() async {
  final file = await _pickSingleImageFile();
  if (file == null) {
    return null;
  }

  final tesseract = await _loadTesseract();
  final imageDataUrl = await _prepareImageForOcr(file);
  final result = await _recognizeImage(tesseract, imageDataUrl).timeout(
    Duration(seconds: _isLikelyMobileBrowser() ? 150 : 90),
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

Future<html.File?> _pickSingleImageFile() async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/png,image/jpeg,image/webp,image/heic,image/heif,image/*'
    ..multiple = false;

  input.setAttribute('aria-hidden', 'true');
  input.style
    ..position = 'fixed'
    ..left = '0'
    ..top = '0'
    ..width = '1px'
    ..height = '1px'
    ..opacity = '0'
    ..pointerEvents = 'none'
    ..zIndex = '-1';

  html.document.body?.append(input);

  try {
    final selection = input.onChange.first
        .then<html.Event?>((event) => event)
        .timeout(const Duration(seconds: 90), onTimeout: () => null);
    input.click();
    final event = await selection;
    if (event == null) {
      return null;
    }

    final files = input.files;
    if (files == null || files.isEmpty) {
      return null;
    }

    return files.first;
  } finally {
    input.remove();
  }
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
  await reader.onLoad.first.timeout(const Duration(seconds: 20));
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
        _tesseractOptions(),
      ]);
      worker = await _promiseToJsObject(workerPromise).timeout(
        Duration(seconds: _isLikelyMobileBrowser() ? 75 : 45),
      );
      final resultPromise = worker.callMethod('recognize', [imageDataUrl]);
      final result = await _promiseToJsObject(resultPromise).timeout(
        Duration(seconds: _isLikelyMobileBrowser() ? 90 : 60),
      );
      _hasRefreshedTesseractCache = true;
      return result;
    } catch (_) {
      final result = await _recognizeDirect(tesseract, imageDataUrl).timeout(
        Duration(seconds: _isLikelyMobileBrowser() ? 90 : 45),
      );
      _hasRefreshedTesseractCache = true;
      return result;
    } finally {
      if (worker != null) {
        try {
          await _promiseToAny(worker.callMethod('terminate', [])).timeout(
            const Duration(seconds: 8),
          );
        } catch (_) {}
      }
    }
  }

  return _recognizeDirect(tesseract, imageDataUrl);
}

Future<js.JsObject> _recognizeDirect(
  js.JsObject tesseract,
  String imageDataUrl,
) {
  final promise = tesseract.callMethod('recognize', [
    imageDataUrl,
    _ocrLanguage,
    _tesseractOptions(),
  ]);
  return _promiseToJsObject(promise);
}

js.JsObject _tesseractOptions() {
  return js.JsObject.jsify({
    'workerPath': _tesseractWorkerCdn,
    'corePath': _tesseractCoreCdn,
    'langPath': _tesseractLangCdn,
    'cacheMethod': _hasRefreshedTesseractCache ? 'write' : 'refresh',
  });
}

bool _isLikelyMobileBrowser() {
  final userAgent = html.window.navigator.userAgent.toLowerCase();
  return userAgent.contains('iphone') ||
      userAgent.contains('ipad') ||
      userAgent.contains('android') ||
      userAgent.contains('mobile');
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
  script.setAttribute('crossorigin', 'anonymous');

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
    Duration(seconds: _isLikelyMobileBrowser() ? 35 : 20),
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
