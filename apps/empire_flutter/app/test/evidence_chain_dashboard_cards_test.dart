import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/router/app_router.dart';

/// Tests that the dashboard card routes are wired to valid kKnownRoutes entries.
/// This ensures no broken links between dashboard cards and the router.
void main() {
  group('Dashboard evidence chain cards route validity', () {
    // All routes referenced by new dashboard cards must exist in kKnownRoutes
    final Map<String, String> cardRoutes = <String, String>{
      'learner_checkpoints': '/learner/checkpoints',
      'learner_reflections': '/learner/reflections',
      'learner_proof': '/learner/proof-assembly',
      'learner_peer_feedback': '/learner/peer-feedback',
      'educator_observations': '/educator/observations',
      'educator_rubrics': '/educator/rubrics/apply',
      'educator_proof_verification': '/educator/proof-review',
      'parent_growth_timeline': '/parent/growth-timeline',
      'hq_capability_framework': '/hq/capability-frameworks',
      'hq_rubric_builder': '/hq/rubric-builder',
    };

    for (final MapEntry<String, String> entry in cardRoutes.entries) {
      test('${entry.key} card route ${entry.value} is a known route', () {
        expect(kKnownRoutes.containsKey(entry.value), isTrue,
            reason:
                'Dashboard card ${entry.key} references unknown route ${entry.value}');
      });
    }

    test('all 10 evidence chain card routes are enabled', () {
      for (final String route in cardRoutes.values) {
        expect(kKnownRoutes[route], isTrue,
            reason: 'Route $route is disabled but has a dashboard card');
      }
    });
  });
}
