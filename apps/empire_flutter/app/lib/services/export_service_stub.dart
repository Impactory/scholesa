import 'dart:typed_data';

Future<String?> saveExportFile({
  required String fileName,
  required Uint8List bytes,
  required String mimeType,
}) {
  throw UnsupportedError('File export is not supported on this platform.');
}
