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
              allowBosFallback: role == UserRole.learner,
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
  });
}
