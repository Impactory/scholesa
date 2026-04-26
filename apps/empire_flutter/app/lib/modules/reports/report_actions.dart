import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/export_service.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';

class ReportActions {
  const ReportActions._();

  static Future<void> exportText({
    required ScaffoldMessengerState messenger,
    required bool Function() isMounted,
    required String fileName,
    required String content,
    required String learnerId,
    required String module,
    required String surface,
    required String copiedEventName,
    required String successMessage,
    required String copiedMessage,
    required String errorMessage,
    required String unsupportedLogMessage,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    try {
      final String? savedLocation = await ExportService.instance.saveTextFile(
        fileName: fileName,
        content: content,
      );
      if (!isMounted() || savedLocation == null) {
        return;
      }
      TelemetryService.instance.logEvent(
        event: 'export.downloaded',
        metadata: <String, dynamic>{
          'module': module,
          'surface': surface,
          'learner_id': learnerId,
          'file_name': fileName,
          ...metadata,
        },
      );
      messenger.showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } on UnsupportedError catch (error) {
      debugPrint('$unsupportedLogMessage: $error');
      await Clipboard.setData(ClipboardData(text: content));
      TelemetryService.instance.logEvent(
        event: copiedEventName,
        metadata: <String, dynamic>{
          'learner_id': learnerId,
          'fallback': 'clipboard',
          ...metadata,
        },
      );
      if (!isMounted()) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(copiedMessage)),
      );
    } catch (_) {
      if (!isMounted()) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: ScholesaColors.error,
        ),
      );
    }
  }

  static Future<void> shareToClipboard({
    required ScaffoldMessengerState messenger,
    required bool Function() isMounted,
    required String content,
    required String learnerId,
    required String module,
    required String surface,
    required String cta,
    required String successMessage,
    required String errorMessage,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    try {
      await Clipboard.setData(ClipboardData(text: content));
      TelemetryService.instance.logEvent(
        event: 'cta.clicked',
        metadata: <String, dynamic>{
          'cta': cta,
          'learner_id': learnerId,
          ...metadata,
        },
      );
      TelemetryService.instance.logEvent(
        event: 'notification.requested',
        metadata: <String, dynamic>{
          'module': module,
          'surface': surface,
          'learner_id': learnerId,
          'delivery': 'clipboard',
          ...metadata,
        },
      );
      if (!isMounted()) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (_) {
      if (!isMounted()) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: ScholesaColors.error,
        ),
      );
    }
  }
}
