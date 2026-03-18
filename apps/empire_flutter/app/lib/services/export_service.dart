import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'export_service_stub.dart'
    if (dart.library.html) 'export_service_web.dart'
    if (dart.library.io) 'export_service_io.dart' as export_platform;

typedef DebugTextExportHandler = Future<String?> Function({
  required String fileName,
  required String content,
  required String mimeType,
});

class ExportService {
  ExportService._();

  static final ExportService instance = ExportService._();

  @visibleForTesting
  DebugTextExportHandler? debugSaveTextFile;

  Future<String?> saveTextFile({
    required String fileName,
    required String content,
    String mimeType = 'text/plain;charset=utf-8',
  }) async {
    final DebugTextExportHandler? handler = debugSaveTextFile;
    if (handler != null) {
      return handler(
        fileName: fileName,
        content: content,
        mimeType: mimeType,
      );
    }
    final Uint8List bytes = Uint8List.fromList(utf8.encode(content));
    return export_platform.saveExportFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
    );
  }
}
