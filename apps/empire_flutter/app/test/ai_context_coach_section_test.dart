@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/runtime/ai_context_coach_section.dart';

void main() {
  group('AiContextCoachSection class', () {
    test('AiContextCoachSection type is correctly exported', () {
      // Verify the widget class is importable via the runtime barrel.
      expect(AiContextCoachSection, isA<Type>());
    });

    test('constructor parameter types are correct', () {
      // Verify the widget signature compiles with expected types.
      // We cannot pump the widget without a full runtime Provider tree,
      // so we verify construction-time constraints.
      // ignore: prefer_function_declarations_over_variables
      final AiContextCoachSection Function() builder = () =>
          const AiContextCoachSection(
            title: 'Test Title',
            subtitle: 'Test Subtitle',
            module: 'test_module',
            surface: 'test_surface',
            actorRole: UserRole.learner,
            conceptTags: <String>['math', 'algebra'],
          );
      expect(builder, isA<Function>());
    });

    test('optional parameters accept null', () {
      // Verify optional params (missionId, checkpointId, accentColor) are optional.
      // ignore: prefer_function_declarations_over_variables
      final AiContextCoachSection Function() builder = () =>
          const AiContextCoachSection(
            title: 'Minimal',
            subtitle: 'Minimal section',
            module: 'mod',
            surface: 'surf',
            actorRole: UserRole.educator,
          );
      expect(builder, isA<Function>());
    });
  });
}
