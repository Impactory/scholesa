import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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

class AppStartupIssue {
  AppStartupIssue({
    required this.serviceKey,
    required this.message,
    this.context,
    DateTime? occurredAt,
  }) : occurredAt = occurredAt ?? DateTime.now();

  final String serviceKey;
  final String message;
  final String? context;
  final DateTime occurredAt;
}

class AppResilience {
  AppResilience({AppFailureSink? sink}) : _sink = sink ?? _defaultSink;

  final AppFailureSink _sink;

  static const Map<String, String> _widgetErrorTitle = <String, String>{
    'en': 'This section could not load',
    'zh-CN': '此部分无法加载',
    'zh-TW': '此部分無法載入',
  };
  static const Map<String, String> _widgetErrorBody = <String, String>{
    'en': 'Scholesa kept running, but this part of the screen failed.',
    'zh-CN': 'Scholesa 仍在运行，但这一部分界面加载失败。',
    'zh-TW': 'Scholesa 仍在運行，但這一部分畫面載入失敗。',
  };

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

  Future<void> captureFailure({
    required String source,
    required Object error,
    required StackTrace stackTrace,
    String? context,
  }) async {
    await _capture(
      AppFailureReport(
        source: source,
        error: error,
        stackTrace: stackTrace,
        occurredAt: DateTime.now(),
        context: context,
      ),
    );
  }

  Future<void> captureFlutterError(FlutterErrorDetails details) async {
    final String? library = details.library;
    final String? contextDescription = details.context?.toDescription();
    final String context = <String>[
      if ((library ?? '').isNotEmpty) library!,
      if ((contextDescription ?? '').isNotEmpty) contextDescription!,
    ].join(' | ');

    await captureFailure(
      source: 'flutter',
      error: details.exception,
      stackTrace: details.stack ?? StackTrace.current,
      context: context.isEmpty ? null : context,
    );
  }

  Future<bool> capturePlatformError(
    Object error,
    StackTrace stackTrace,
  ) async {
    await captureFailure(
      source: 'platform_dispatcher',
      error: error,
      stackTrace: stackTrace,
    );
    return true;
  }

  Future<void> captureZoneError(
    Object error,
    StackTrace stackTrace,
  ) async {
    await captureFailure(
      source: 'zone',
      error: error,
      stackTrace: stackTrace,
    );
  }

  void installGlobalHandlers() {
    final FlutterExceptionHandler? previousFlutterHandler =
        FlutterError.onError;
    final ErrorCallback? previousPlatformHandler =
        PlatformDispatcher.instance.onError;
    final ErrorWidgetBuilder previousErrorWidgetBuilder = ErrorWidget.builder;

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

    ErrorWidget.builder = (FlutterErrorDetails details) {
      try {
        return buildErrorWidget(details);
      } catch (error, stackTrace) {
        debugPrint('ErrorWidget builder failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        return previousErrorWidgetBuilder(details);
      }
    };
  }

  Future<void> runGuardedStartup({
    required Future<void> Function() initialize,
    required FutureOr<void> Function() launch,
  }) async {
    bool didLaunch = false;

    Future<void> launchSafely() async {
      if (didLaunch) {
        return;
      }
      didLaunch = true;
      try {
        await Future<void>.sync(launch);
      } catch (error, stackTrace) {
        await captureFailure(
          source: 'launch',
          error: error,
          stackTrace: stackTrace,
        );
        rethrow;
      }
    }

    await runZonedGuarded(
      () async {
        try {
          await initialize();
        } catch (error, stackTrace) {
          await captureZoneError(error, stackTrace);
        } finally {
          await launchSafely();
        }
      },
      (Object error, StackTrace stackTrace) {
        unawaited(captureZoneError(error, stackTrace));
      },
    );
  }

  Widget buildErrorWidget(FlutterErrorDetails details) {
    final String localeCode = _normalizedLocaleCode();
    return Material(
      color: Colors.transparent,
      child: Semantics(
        container: true,
        liveRegion: true,
        label: _widgetErrorTitle[localeCode] ?? _widgetErrorTitle['en']!,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4E5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE3A008)),
          ),
          child: DefaultTextStyle(
            style: const TextStyle(
              color: Color(0xFF7A4B00),
              fontSize: 14,
              height: 1.35,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFB45309),
                ),
                const SizedBox(height: 8),
                Text(
                  _widgetErrorTitle[localeCode] ?? _widgetErrorTitle['en']!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _widgetErrorBody[localeCode] ?? _widgetErrorBody['en']!,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _normalizedLocaleCode() {
    final Locale locale = PlatformDispatcher.instance.locale;
    final String languageCode = locale.languageCode.toLowerCase();
    final String countryCode = locale.countryCode?.toUpperCase() ?? '';
    if (languageCode == 'zh' && countryCode == 'CN') {
      return 'zh-CN';
    }
    if (languageCode == 'zh' && countryCode == 'TW') {
      return 'zh-TW';
    }
    return 'en';
  }
}
