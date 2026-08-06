import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

Future<void> savePdfFile({
  required Uint8List bytes,
  required String filename,
}) async {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..target = '_blank'
    ..rel = 'noopener'
    ..style.display = 'none';

  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();

  await Future<void>.delayed(const Duration(seconds: 3));
  html.Url.revokeObjectUrl(url);
}
