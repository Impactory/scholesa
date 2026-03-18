import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/services/app_resilience.dart';

void main() {
  group('AppResilience', () {
    test('captureFlutterError records context for diagnostics', () async {
      final List<AppFailureReport> reports = <AppFailureReport>[];
      final AppResilience resilience = AppResilience(
        sink: (AppFailureReport report) async {
          reports.add(report);
        },
      );

      await resilience.captureFlutterError(
        FlutterErrorDetails(
          exception: StateError('flutter boom'),
          stack: StackTrace.current,
          library: 'widgets',
          context: ErrorDescription('while building shell'),
        ),
      );

      expect(reports, hasLength(1));
      expect(reports.single.source, 'flutter');
      expect(reports.single.error, isA<StateError>());
      expect(reports.single.context, contains('widgets'));
      expect(reports.single.context, contains('while building shell'));
    });

    test('capturePlatformError returns handled true and reports once',
        () async {
      final List<AppFailureReport> reports = <AppFailureReport>[];
      final AppResilience resilience = AppResilience(
        sink: (AppFailureReport report) async {
          reports.add(report);
        },
      );

      final bool handled = await resilience.capturePlatformError(
        StateError('platform boom'),
        StackTrace.current,
      );

      expect(handled, isTrue);
      expect(reports, hasLength(1));
      expect(reports.single.source, 'platform_dispatcher');
    });

    test('runGuardedStartup captures uncaught async zone failures', () async {
      final List<AppFailureReport> reports = <AppFailureReport>[];
      final Completer<void> captured = Completer<void>();
      final AppResilience resilience = AppResilience(
        sink: (AppFailureReport report) async {
          reports.add(report);
          if (!captured.isCompleted) {
            captured.complete();
          }
        },
      );

      await resilience.runGuardedStartup(
        initialize: () async {},
        launch: () {
          Future<void>.microtask(() {
            throw StateError('zone boom');
          });
        },
      );

      await captured.future.timeout(const Duration(seconds: 2));

      expect(reports, hasLength(1));
      expect(reports.single.source, 'zone');
      expect(reports.single.error.toString(), contains('zone boom'));
    });

    test('runGuardedStartup still launches after initialization failure',
        () async {
      final List<AppFailureReport> reports = <AppFailureReport>[];
      bool launched = false;
      final AppResilience resilience = AppResilience(
        sink: (AppFailureReport report) async {
          reports.add(report);
        },
      );

      await resilience.runGuardedStartup(
        initialize: () async {
          throw StateError('bootstrap boom');
        },
        launch: () {
          launched = true;
        },
      );

      expect(launched, isTrue);
      expect(reports, hasLength(1));
      expect(reports.single.source, 'zone');
      expect(reports.single.error.toString(), contains('bootstrap boom'));
    });

    test('sink failures are swallowed so reporting never crashes the app',
        () async {
      final AppResilience resilience = AppResilience(
        sink: (_) async {
          throw StateError('sink boom');
        },
      );

      await resilience.captureZoneError(
        StateError('original boom'),
        StackTrace.current,
      );
    });

    testWidgets('buildErrorWidget renders honest fallback copy',
        (WidgetTester tester) async {
      final AppResilience resilience = AppResilience(
        sink: (_) async {},
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: resilience.buildErrorWidget(
            FlutterErrorDetails(
              exception: StateError('build boom'),
              stack: StackTrace.current,
            ),
          ),
        ),
      );

      expect(find.text('This section could not load'), findsOneWidget);
      expect(
        find.text('Scholesa kept running, but this part of the screen failed.'),
        findsOneWidget,
      );
    });
  });
}
