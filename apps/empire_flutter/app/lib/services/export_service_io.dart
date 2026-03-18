import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<String?> saveExportFile({
  required String fileName,
  required Uint8List bytes,
  required String mimeType,
}) async {
  final String extension = _fileExtension(fileName);
  final bool writeViaPicker = Platform.isAndroid || Platform.isIOS;
  final String? selectedPath = await FilePicker.platform.saveFile(
    dialogTitle: 'Save export file',
    fileName: fileName,
    type: extension.isEmpty ? FileType.any : FileType.custom,
    allowedExtensions: extension.isEmpty ? null : <String>[extension],
    bytes: writeViaPicker ? bytes : null,
  );
  if (selectedPath == null) {
    return null;
  }
  if (!writeViaPicker) {
    final File file = File(selectedPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }
  return selectedPath;
}

String _fileExtension(String fileName) {
  final int dotIndex = fileName.lastIndexOf('.');
  if (dotIndex <= 0 || dotIndex == fileName.length - 1) {
    return '';
  }
  return fileName.substring(dotIndex + 1).toLowerCase();
}
