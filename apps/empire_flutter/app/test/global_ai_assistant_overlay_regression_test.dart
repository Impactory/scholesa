import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/runtime/bos_models.dart';
import 'package:scholesa_app/runtime/global_ai_assistant_overlay.dart';
import 'package:scholesa_app/runtime/learning_runtime_provider.dart';
import 'package:scholesa_app/services/telemetry_service.dart';

class _FakeLearningRuntimeProvider extends LearningRuntimeProvider {
  _FakeLearningRuntimeProvider({
    required super.siteId,
    required super.learnerId,
    required super.gradeBand,
    super.sessionOccurrenceId,
  }) : super(firestore: FakeFirebaseFirestore());

  OrchestrationState? _fakeState;
  final List<Map<String, dynamic>> trackedEventPayloads = <Map<String, dynamic>>[];

  @override
  OrchestrationState? get state => _fakeState;

  @override
  void startListening() {}

  @override
  void trackEvent(
    String eventType, {
    String? missionId,
    String? checkpointId,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) {
    trackedEventPayloads.add(<String, dynamic>{
      'eventType': eventType,
      'missionId': missionId,
      'checkpointId': checkpointId,
      'payload': Map<String, dynamic>.from(payload),
    });
  }

  void emitHesitatingState() {
    _fakeState = OrchestrationState(
      siteId: siteId,
      learnerId: learnerId,
      sessionOccurrenceId: sessionOccurrenceId ?? 'occ_test',
      xHat: const XHat(cognition: 0.32, engagement: 0.34, integrity: 0.71),
      p: const CovarianceSummary(),
      model: const EstimatorModel(),
      fusion: const FusionInfo(),
    );
    notifyListeners();
  }
}

void main() {
  group('GlobalAiAssistantOverlay BOS auto-popup', () {
    testWidgets('logs bos_auto_popup trigger metadata when hesitation auto-opens',
        (WidgetTester tester) async {
      final AppState appState = AppState();
      appState.updateFromMeResponse(<String, dynamic>{
        'userId': 'learner_test',
        'email': 'learner@test.scholesa',
        'displayName': 'Learner Test',
        'role': 'learner',
        'activeSiteId': 'site_test',
        'siteIds': <String>['site_test'],
        'entitlements': <dynamic>[],
      });

      final _FakeLearningRuntimeProvider fakeRuntime =
          _FakeLearningRuntimeProvider(
        siteId: 'site_test',
        learnerId: 'learner_test',
        gradeBand: GradeBand.g4_6,
        sessionOccurrenceId: 'occ_test',
      );

      final List<Map<String, dynamic>> telemetryPayloads =
          <Map<String, dynamic>>[];
      int sheetOpenCount = 0;

      await TelemetryService.runWithDispatcher((Map<String, dynamic> payload) async {
        telemetryPayloads.add(payload);
      }, () async {
        await tester.pumpWidget(
          ChangeNotifierProvider<AppState>.value(
            value: appState,
            child: MaterialApp(
              home: Scaffold(
                body: GlobalAiAssistantOverlay(
                  runtimeFactory: ({
                    required String siteId,
                    required String learnerId,
                    required GradeBand gradeBand,
                    String? sessionOccurrenceId,
                  }) {
                    return fakeRuntime;
                  },
                  sessionOccurrenceResolver: (
                    BuildContext context, {
                    required String siteId,
                    required String learnerId,
                  }) async {
                    return 'occ_test';
                  },
                  sheetPresenter: (BuildContext context, Widget child) async {
                    sheetOpenCount += 1;
                  },
                  nowProvider: () => DateTime(2026, 1, 1, 12, 0),
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        fakeRuntime.emitHesitatingState();
        await tester.pump();
        await tester.pump();
      });

      expect(sheetOpenCount, equals(1));

      final Iterable<Map<String, dynamic>> ctaClickedEvents = telemetryPayloads
          .where((Map<String, dynamic> payload) => payload['event'] == 'cta.clicked');

      final bool hasBosAutoPopupOpenEvent = ctaClickedEvents.any(
        (Map<String, dynamic> payload) {
          final Map<String, dynamic> metadata =
              (payload['metadata'] as Map<String, dynamic>? ?? <String, dynamic>{});
          return metadata['cta'] == 'global_ai_assistant_open' &&
              metadata['surface'] == 'floating_assistant' &&
              metadata['trigger'] == 'bos_auto_popup';
        },
      );

      final bool hasBosAutoPopupCloseEvent = ctaClickedEvents.any(
        (Map<String, dynamic> payload) {
          final Map<String, dynamic> metadata =
              (payload['metadata'] as Map<String, dynamic>? ?? <String, dynamic>{});
          return metadata['cta'] == 'global_ai_assistant_close' &&
              metadata['surface'] == 'floating_assistant' &&
              metadata['trigger'] == 'bos_auto_popup';
        },
      );

      expect(hasBosAutoPopupOpenEvent, isTrue);
      expect(hasBosAutoPopupCloseEvent, isTrue);
    });

    testWidgets('does not open modal assistant on mouse hover',
        (WidgetTester tester) async {
      final AppState appState = AppState();
      appState.updateFromMeResponse(<String, dynamic>{
        'userId': 'learner_test',
        'email': 'learner@test.scholesa',
        'displayName': 'Learner Test',
        'role': 'site',
        'activeSiteId': 'site_test',
        'siteIds': <String>['site_test'],
        'entitlements': <dynamic>[],
      });

      int sheetOpenCount = 0;

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: Scaffold(
              body: GlobalAiAssistantOverlay(
                sessionOccurrenceResolver: (
                  BuildContext context, {
                  required String siteId,
                  required String learnerId,
                }) async {
                  return 'occ_test';
                },
                sheetPresenter: (BuildContext context, Widget child) async {
                  sheetOpenCount += 1;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      final Finder fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);

      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer();
      await mouse.moveTo(tester.getCenter(fab));
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('Click for AI help'), findsOneWidget);
      expect(sheetOpenCount, equals(0));
    });

    testWidgets('captures learner pointer summary when assistant opens',
        (WidgetTester tester) async {
      final AppState appState = AppState();
      appState.updateFromMeResponse(<String, dynamic>{
        'userId': 'learner_test',
        'email': 'learner@test.scholesa',
        'displayName': 'Learner Test',
        'role': 'learner',
        'activeSiteId': 'site_test',
        'siteIds': <String>['site_test'],
        'entitlements': <dynamic>[],
      });

      final _FakeLearningRuntimeProvider fakeRuntime = _FakeLearningRuntimeProvider(
        siteId: 'site_test',
        learnerId: 'learner_test',
        gradeBand: GradeBand.g4_6,
        sessionOccurrenceId: 'occ_test',
      );

      int sheetOpenCount = 0;

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: Scaffold(
              body: GlobalAiAssistantOverlay(
                runtimeFactory: ({
                  required String siteId,
                  required String learnerId,
                  required GradeBand gradeBand,
                  String? sessionOccurrenceId,
                }) {
                  return fakeRuntime;
                },
                sessionOccurrenceResolver: (
                  BuildContext context, {
                  required String siteId,
                  required String learnerId,
                }) async {
                  return 'occ_test';
                },
                sheetPresenter: (BuildContext context, Widget child) async {
                  sheetOpenCount += 1;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(sheetOpenCount, equals(1));
      expect(fakeRuntime.trackedEventPayloads, isNotEmpty);

      final Map<String, dynamic> payload = fakeRuntime.trackedEventPayloads.lastWhere(
        (Map<String, dynamic> entry) => entry['eventType'] == 'interaction_signal_observed',
      )['payload'] as Map<String, dynamic>;

      expect(payload['signalFamily'], equals('pointer'));
      expect(payload['source'], equals('global_ai_assistant_open'));
      expect(payload['target'], equals('assistant_fab'));
    });
  });
}
