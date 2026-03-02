import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/runtime/ai_coach_widget.dart';
import 'package:scholesa_app/runtime/bos_models.dart';
import 'package:scholesa_app/runtime/learning_runtime_provider.dart';

void main() {
  group('AI Coach runtime integration', () {
    testWidgets('renders core coach controls for floating assistant',
        (tester) async {
      final LearningRuntimeProvider runtime = LearningRuntimeProvider(
        siteId: 'site_test',
        learnerId: 'learner_test',
        gradeBand: GradeBand.g4_6,
      );

      addTearDown(runtime.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiCoachWidget(
              runtime: runtime,
              actorRole: UserRole.learner,
              allowBosFallback: true,
              conceptTags: const <String>['integration-test'],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('AI Coach'), findsOneWidget);
      expect(find.text('Hint'), findsOneWidget);
      expect(find.text('Verify'), findsOneWidget);
      expect(find.text('Explain'), findsOneWidget);
      expect(find.text('Debug'), findsOneWidget);
      expect(find.byIcon(Icons.send), findsOneWidget);
    });
  });
}
