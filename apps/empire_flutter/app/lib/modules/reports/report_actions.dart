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
    required String module,
    required String surface,
    required String copiedEventName,
    required String successMessage,
    required String copiedMessage,
    required String errorMessage,
    required String unsupportedLogMessage,
    String? learnerId,
    String? role,
    String? siteId,
    Map<String, dynamic> metadata = const <String, dynamic>{},
    Future<void> Function()? onDownloaded,
    Future<void> Function()? onCopied,
    bool showSuccessSnackBar = true,
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
        role: role,
        siteId: siteId,
        metadata: <String, dynamic>{
          'module': module,
          'surface': surface,
          if (learnerId != null) 'learner_id': learnerId,
          'file_name': fileName,
          ...metadata,
        },
      );
      await onDownloaded?.call();
      if (showSuccessSnackBar) {
        messenger.showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      }
    } on UnsupportedError catch (error) {
      debugPrint('$unsupportedLogMessage: $error');
      await Clipboard.setData(ClipboardData(text: content));
      TelemetryService.instance.logEvent(
        event: copiedEventName,
        role: role,
        siteId: siteId,
        metadata: <String, dynamic>{
          'module': module,
          'surface': surface,
          if (learnerId != null) 'learner_id': learnerId,
          'file_name': fileName,
          'fallback': 'clipboard',
          ...metadata,
        },
      );
      await onCopied?.call();
      if (!isMounted()) {
        return;
      }
      if (showSuccessSnackBar) {
        messenger.showSnackBar(
          SnackBar(content: Text(copiedMessage)),
        );
      }
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
    required String module,
    required String surface,
    required String cta,
    required String successMessage,
    required String errorMessage,
    String? learnerId,
    String? role,
    String? siteId,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    try {
      await Clipboard.setData(ClipboardData(text: content));
      TelemetryService.instance.logEvent(
        event: 'cta.clicked',
        role: role,
        siteId: siteId,
        metadata: <String, dynamic>{
          'cta': cta,
          if (learnerId != null) 'learner_id': learnerId,
          ...metadata,
        },
      );
      TelemetryService.instance.logEvent(
        event: 'notification.requested',
        role: role,
        siteId: siteId,
        metadata: <String, dynamic>{
          'module': module,
          'surface': surface,
          if (learnerId != null) 'learner_id': learnerId,
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
