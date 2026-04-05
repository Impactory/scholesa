import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/router/app_router.dart';

void main() {
  group('Evidence chain routes in kKnownRoutes', () {
    test('learner evidence routes are registered', () {
      expect(kKnownRoutes['/learner/checkpoints'], isTrue);
      expect(kKnownRoutes['/learner/reflections'], isTrue);
      expect(kKnownRoutes['/learner/proof-assembly'], isTrue);
      expect(kKnownRoutes['/learner/peer-feedback'], isTrue);
    });

    test('educator evidence routes are registered', () {
      expect(kKnownRoutes['/educator/observations'], isTrue);
      expect(kKnownRoutes['/educator/rubrics/apply'], isTrue);
      expect(kKnownRoutes['/educator/proof-review'], isTrue);
    });

    test('parent evidence routes are registered', () {
      expect(kKnownRoutes['/parent/growth-timeline'], isTrue);
    });

    test('hq evidence routes are registered', () {
      expect(kKnownRoutes['/hq/capability-frameworks'], isTrue);
      expect(kKnownRoutes['/hq/rubric-builder'], isTrue);
    });

    test('all 10 evidence chain routes exist', () {
      final List<String> evidenceRoutes = <String>[
        '/learner/checkpoints',
        '/learner/reflections',
        '/learner/proof-assembly',
        '/learner/peer-feedback',
        '/educator/observations',
        '/educator/rubrics/apply',
        '/educator/proof-review',
        '/parent/growth-timeline',
        '/hq/capability-frameworks',
        '/hq/rubric-builder',
      ];
      for (final String route in evidenceRoutes) {
        expect(kKnownRoutes.containsKey(route), isTrue,
            reason: 'Missing route: $route');
        expect(kKnownRoutes[route], isTrue,
            reason: 'Route disabled: $route');
      }
    });
  });
}
