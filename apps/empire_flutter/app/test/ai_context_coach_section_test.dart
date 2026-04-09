@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/runtime/ai_context_coach_section.dart';

void main() {
  group('AiContextCoachSection class', () {
    test('AiContextCoachSection type is correctly exported', () {
      expect(AiContextCoachSection, isA<Type>());
    });

    test('constructs with all required parameters', () {
      const AiContextCoachSection section = AiContextCoachSection(
        title: 'AI Coach',
        subtitle: 'Get help understanding the concept',
        module: 'missions',
        surface: 'mission_detail',
        actorRole: UserRole.learner,
      );

      expect(section.title, 'AI Coach');
      expect(section.subtitle, 'Get help understanding the concept');
      expect(section.module, 'missions');
      expect(section.surface, 'mission_detail');
      expect(section.actorRole, UserRole.learner);
      expect(section.conceptTags, isEmpty);
      expect(section.missionId, isNull);
      expect(section.checkpointId, isNull);
      expect(section.accentColor, isNull);
    });

    test('constructs with optional parameters', () {
      const AiContextCoachSection section = AiContextCoachSection(
        title: 'Review Coach',
        subtitle: 'AI-powered review feedback',
        module: 'educator_review',
        surface: 'rubric_application',
        actorRole: UserRole.educator,
        accentColor: Colors.blue,
        missionId: 'mission-abc',
        checkpointId: 'cp-001',
        conceptTags: <String>['algebra', 'linear_equations'],
      );

      expect(section.actorRole, UserRole.educator);
      expect(section.missionId, 'mission-abc');
      expect(section.checkpointId, 'cp-001');
      expect(section.conceptTags, hasLength(2));
      expect(section.conceptTags, contains('algebra'));
      expect(section.accentColor, Colors.blue);
    });

    test('concept tags default to empty list', () {
      const AiContextCoachSection section = AiContextCoachSection(
        title: 'Coach',
        subtitle: 'Help',
        module: 'test',
        surface: 'test_surface',
        actorRole: UserRole.learner,
      );
      expect(section.conceptTags, isA<List<String>>());
      expect(section.conceptTags, isEmpty);
    });
  });

  group('AiContextCoachSection role coverage', () {
    test('all six platform roles accepted as actorRole', () {
      const List<UserRole> allRoles = UserRole.values;
      expect(allRoles, hasLength(6));

      for (final UserRole role in allRoles) {
        final AiContextCoachSection section = AiContextCoachSection(
          title: 'Test',
          subtitle: 'Test',
          module: 'test',
          surface: 'test',
          actorRole: role,
        );
        expect(section.actorRole, role);
        expect(section.actorRole.name, isNotEmpty);
      }
    });

    test('learner role constructs correctly', () {
      const AiContextCoachSection section = AiContextCoachSection(
        title: 'T',
        subtitle: 'S',
        module: 'm',
        surface: 's',
        actorRole: UserRole.learner,
      );
      expect(section.actorRole, UserRole.learner);
    });

    test('educator role constructs correctly', () {
      const AiContextCoachSection section = AiContextCoachSection(
        title: 'T',
        subtitle: 'S',
        module: 'm',
        surface: 's',
        actorRole: UserRole.educator,
      );
      expect(section.actorRole, UserRole.educator);
    });
  });

  group('AiContextCoachSection concept tag enrichment', () {
    test('concept tags carry through from constructor', () {
      const List<String> tags = <String>['geometry', 'area', 'perimeter'];
      const AiContextCoachSection section = AiContextCoachSection(
        title: 'Math Coach',
        subtitle: 'Help with geometry',
        module: 'missions',
        surface: 'checkpoint',
        actorRole: UserRole.learner,
        conceptTags: tags,
      );
      expect(section.conceptTags, hasLength(3));
      expect(section.conceptTags, containsAll(<String>['geometry', 'area']));
    });

    test('empty concept tags produce a valid empty list', () {
      const AiContextCoachSection section = AiContextCoachSection(
        title: 'Coach',
        subtitle: 'Help',
        module: 'test',
        surface: 'test',
        actorRole: UserRole.learner,
        conceptTags: <String>[],
      );
      expect(section.conceptTags, isEmpty);
    });
  });

  group('AiContextCoachSection mission/checkpoint context', () {
    test('missionId and checkpointId are both nullable', () {
      const AiContextCoachSection section = AiContextCoachSection(
        title: 'T',
        subtitle: 'S',
        module: 'm',
        surface: 's',
        actorRole: UserRole.learner,
      );
      expect(section.missionId, isNull);
      expect(section.checkpointId, isNull);
    });

    test('missionId and checkpointId can be set together', () {
      const AiContextCoachSection section = AiContextCoachSection(
        title: 'T',
        subtitle: 'S',
        module: 'm',
        surface: 's',
        actorRole: UserRole.learner,
        missionId: 'mis-001',
        checkpointId: 'cp-001',
      );
      expect(section.missionId, 'mis-001');
      expect(section.checkpointId, 'cp-001');
    });
  });
}
