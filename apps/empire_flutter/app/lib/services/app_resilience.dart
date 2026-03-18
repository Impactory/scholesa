import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'telemetry_service.dart';

typedef AppFailureSink = Future<void> Function(AppFailureReport report);

class AppFailureReport {
  AppFailureReport({
    required this.source,
    required this.error,
    required this.stackTrace,
    required this.occurredAt,
    this.context,
  });

  final String source;
  final Object error;
  final StackTrace stackTrace;
  final DateTime occurredAt;
  final String? context;

  Map<String, dynamic> toTelemetryMetadata() {
    final String stackText = stackTrace.toString();
    return <String, dynamic>{
      'source': source,
      'error': error.toString(),
      'context': context,
      'occurredAt': occurredAt.toIso8601String(),
      'stackTrace':
          stackText.length <= 4000 ? stackText : stackText.substring(0, 4000),
    };
  }
}

class AppResilience {
  AppResilience({AppFailureSink? sink}) : _sink = sink ?? _defaultSink;

  final AppFailureSink _sink;

  static Future<void> _defaultSink(AppFailureReport report) async {
    debugPrint(
      'Unhandled app failure [${report.source}]: ${report.error}',
    );
    if ((report.context ?? '').isNotEmpty) {
      debugPrint('Failure context: ${report.context}');
    }
    debugPrintStack(stackTrace: report.stackTrace);
    await TelemetryService.instance.logEvent(
      event: 'app.unhandled_error',
      metadata: report.toTelemetryMetadata(),
    );
  }

  Future<void> _capture(AppFailureReport report) async {
    try {
      await _sink(report);
    } catch (error, stackTrace) {
      debugPrint('AppResilience sink failure: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> captureFlutterError(FlutterErrorDetails details) async {
    final String? library = details.library;
    final String? contextDescription = details.context?.toDescription();
    final String context = <String>[
      if ((library ?? '').isNotEmpty) library!,
      if ((contextDescription ?? '').isNotEmpty) contextDescription!,
    ].join(' | ');

    await _capture(
      AppFailureReport(
        source: 'flutter',
        error: details.exception,
        stackTrace: details.stack ?? StackTrace.current,
        occurredAt: DateTime.now(),
        context: context.isEmpty ? null : context,
      ),
    );
  }

  Future<bool> capturePlatformError(
    Object error,
    StackTrace stackTrace,
  ) async {
    await _capture(
      AppFailureReport(
        source: 'platform_dispatcher',
        error: error,
        stackTrace: stackTrace,
        occurredAt: DateTime.now(),
      ),
    );
    return true;
  }

  Future<void> captureZoneError(
    Object error,
    StackTrace stackTrace,
  ) async {
    await _capture(
      AppFailureReport(
        source: 'zone',
        error: error,
        stackTrace: stackTrace,
        occurredAt: DateTime.now(),
      ),
    );
  }

  void installGlobalHandlers() {
    final FlutterExceptionHandler? previousFlutterHandler =
        FlutterError.onError;
    final ErrorCallback? previousPlatformHandler =
        PlatformDispatcher.instance.onError;

    FlutterError.onError = (FlutterErrorDetails details) {
      if (previousFlutterHandler != null) {
        previousFlutterHandler(details);
      } else {
        FlutterError.presentError(details);
      }
      unawaited(captureFlutterError(details));
    };

    PlatformDispatcher.instance.onError = (
      Object error,
      StackTrace stackTrace,
    ) {
      try {
        previousPlatformHandler?.call(error, stackTrace);
      } catch (previousHandlerError, previousHandlerStackTrace) {
        debugPrint(
          'Previous platform error handler failed: $previousHandlerError',
        );
        debugPrintStack(stackTrace: previousHandlerStackTrace);
      }
      unawaited(capturePlatformError(error, stackTrace));
      return true;
    };
  }

  Future<void> runGuardedStartup({
    required Future<void> Function() initialize,
    required void Function() launch,
  }) async {
    await runZonedGuarded(
      () async {
        try {
          await initialize();
          launch();
        } catch (error, stackTrace) {
          await captureZoneError(error, stackTrace);
        }
      },
      (Object error, StackTrace stackTrace) {
        unawaited(captureZoneError(error, stackTrace));
      },
    );
  }
}
