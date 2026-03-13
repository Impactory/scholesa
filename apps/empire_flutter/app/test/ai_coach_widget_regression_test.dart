import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/runtime/ai_coach_widget.dart';
import 'package:scholesa_app/runtime/bos_models.dart';
import 'package:scholesa_app/runtime/learning_runtime_provider.dart';

final ThemeData _testTheme = ThemeData(
  useMaterial3: true,
  splashFactory: InkRipple.splashFactory,
);

void main() {
  group('AiCoachWidget conversational goals regressions', () {
    late LearningRuntimeProvider runtime;

    setUp(() {
      runtime = LearningRuntimeProvider(
        siteId: 'site_test',
        learnerId: 'learner_test',
        gradeBand: GradeBand.g4_6,
      );
    });

    tearDown(() {
      runtime.dispose();
    });

    Future<void> pumpCoach(
      WidgetTester tester, {
      required UserRole role,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _testTheme,
          home: Scaffold(
            body: AiCoachWidget(
              runtime: runtime,
              actorRole: role,
              conceptTags: const <String>['regression-test'],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> addGoalLikeInput(WidgetTester tester) async {
      await tester.enterText(
        find.byType(TextField),
        'I want to debug this mission checkpoint quickly.',
      );
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
    }

    testWidgets('shows current goals row after goal-like learner input',
        (WidgetTester tester) async {
      await pumpCoach(tester, role: UserRole.learner);

      await addGoalLikeInput(tester);

      expect(find.text('Current goals'), findsOneWidget);
      expect(find.byType(Chip), findsWidgets);
    });

    testWidgets('clear goals action hidden for learner role',
        (WidgetTester tester) async {
      await pumpCoach(tester, role: UserRole.learner);
      await addGoalLikeInput(tester);

      expect(find.text('Current goals'), findsOneWidget);
      expect(find.text('Clear goals'), findsNothing);
    });

    testWidgets('educator clear goals cancel keeps goals',
        (WidgetTester tester) async {
      await pumpCoach(tester, role: UserRole.educator);
      await addGoalLikeInput(tester);

      expect(find.text('Clear goals'), findsOneWidget);

      await tester.tap(find.text('Clear goals'));
      await tester.pumpAndSettle();

      expect(find.text('Clear current goals?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Current goals'), findsOneWidget);
      expect(find.byType(Chip), findsWidgets);
    });

    testWidgets('educator clear goals confirm removes goals',
        (WidgetTester tester) async {
      await pumpCoach(tester, role: UserRole.educator);
      await addGoalLikeInput(tester);

      expect(find.text('Clear goals'), findsOneWidget);

      await tester.tap(find.text('Clear goals'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(find.text('Current goals'), findsNothing);
      expect(find.byType(Chip), findsNothing);
    });

    testWidgets('auto greeting proactively speaks on open',
        (WidgetTester tester) async {
      final List<String> spoken = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          theme: _testTheme,
          home: Scaffold(
            body: AiCoachWidget(
              runtime: runtime,
              actorRole: UserRole.learner,
              autoSpeakGreeting: true,
              skipVoiceInitializationForTesting: true,
              onSpeakOverride: (String text) async {
                spoken.add(text);
              },
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 320));

      expect(spoken, isNotEmpty);
      expect(
        spoken.first.toLowerCase(),
        contains('ai coach'),
      );
    });

    testWidgets('proactive BOS hesitation triggers voiced auto-assist',
        (WidgetTester tester) async {
      final _FakeRuntime fakeRuntime = _FakeRuntime();
      final List<String> spoken = <String>[];

      addTearDown(fakeRuntime.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: _testTheme,
          home: Scaffold(
            body: AiCoachWidget(
              runtime: fakeRuntime,
              actorRole: UserRole.learner,
              autoAssistOnHesitation: true,
              hesitationInactivityThreshold: Duration.zero,
              autoAssistCooldown: const Duration(milliseconds: 50),
              proactiveScanInterval: const Duration(milliseconds: 40),
              skipVoiceInitializationForTesting: true,
              onSpeakOverride: (String text) async {
                spoken.add(text);
              },
              onAutoResponseRequest:
                  (String prompt, AiCoachMode mode) async {
                return AiCoachResponse.fromMap(<String, dynamic>{
                  'message': 'Try one tiny next step now.',
                  'mode': mode.name,
                  'meta': <String, dynamic>{'version': 'test'},
                });
              },
            ),
          ),
        ),
      );

      fakeRuntime.setHesitatingState();
      await tester.pump(const Duration(milliseconds: 220));

      expect(spoken.any((String text) => text.contains('Try one tiny next step now.')), isTrue);
      expect(fakeRuntime.trackedEvents, contains('idle_detected'));
      expect(fakeRuntime.trackedEvents, contains('ai_help_opened'));
      expect(fakeRuntime.trackedEvents, contains('ai_help_used'));
      expect(find.textContaining('Try one tiny next step now.'), findsOneWidget);
    });

    testWidgets('voice-only mode hides text input and send button',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _testTheme,
          home: Scaffold(
            body: AiCoachWidget(
              runtime: runtime,
              actorRole: UserRole.learner,
              voiceOnlyConversation: true,
              skipVoiceInitializationForTesting: true,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 240));

      expect(find.byType(TextField), findsNothing);
      expect(find.byIcon(Icons.send), findsNothing);
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      expect(find.textContaining('BOS-MIA'), findsOneWidget);
    });

    testWidgets('captures privacy-safe keystroke summaries for learner typing',
        (WidgetTester tester) async {
      final _FakeRuntime fakeRuntime = _FakeRuntime();

      addTearDown(fakeRuntime.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: _testTheme,
          home: Scaffold(
            body: AiCoachWidget(
              runtime: fakeRuntime,
              actorRole: UserRole.learner,
              skipVoiceInitializationForTesting: true,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Need help with fractions');
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));

      expect(fakeRuntime.trackedEvents, contains('interaction_signal_observed'));

      final Map<String, dynamic> payload = fakeRuntime.eventPayloads.lastWhere(
        (Map<String, dynamic> entry) => entry['eventType'] == 'interaction_signal_observed',
      )['payload'] as Map<String, dynamic>;

      expect(payload['signalFamily'], equals('keystroke'));
      expect(payload['source'], equals('ai_coach_input'));
      expect(payload['charsAdded'], greaterThan(0));
      expect(payload['textLengthBucket'], isNotEmpty);
    });
  });
}

class _FakeRuntime extends LearningRuntimeProvider {
  _FakeRuntime()
      : super(
          siteId: 'site_fake',
          learnerId: 'learner_fake',
          gradeBand: GradeBand.g4_6,
        );

  OrchestrationState? _fakeState;
  final List<String> trackedEvents = <String>[];
  final List<Map<String, dynamic>> eventPayloads = <Map<String, dynamic>>[];

  @override
  OrchestrationState? get state => _fakeState;

  void setHesitatingState() {
    _fakeState = OrchestrationState(
      siteId: siteId,
      learnerId: learnerId,
      sessionOccurrenceId: 'occ_test',
      xHat: const XHat(cognition: 0.32, engagement: 0.29, integrity: 0.71),
      p: const CovarianceSummary(),
      model: const EstimatorModel(),
      fusion: const FusionInfo(),
    );
    notifyListeners();
  }

  @override
  void trackEvent(
    String eventType, {
    String? missionId,
    String? checkpointId,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) {
    trackedEvents.add(eventType);
    eventPayloads.add(<String, dynamic>{
      'eventType': eventType,
      'missionId': missionId,
      'checkpointId': checkpointId,
      'payload': Map<String, dynamic>.from(payload),
    });
  }
}
