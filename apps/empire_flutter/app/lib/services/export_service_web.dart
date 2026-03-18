import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<String?> saveExportFile({
  required String fileName,
  required Uint8List bytes,
  required String mimeType,
}) async {
  final web.Blob blob = web.Blob(
    <JSUint8Array>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final String url = web.URL.createObjectURL(blob);
  final web.HTMLAnchorElement anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..download = fileName
    ..style.display = 'none';
  final web.HTMLBodyElement? body = web.document.body;
  if (body == null) {
    web.URL.revokeObjectURL(url);
    return null;
  }
  body.appendChild(anchor);
  anchor.click();
  body.removeChild(anchor);
  web.URL.revokeObjectURL(url);
  return fileName;
}
