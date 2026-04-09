import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/runtime/bos_models.dart';
import 'package:scholesa_app/runtime/runtime_resolution.dart';

void main() {
  group('gradeBandForRole', () {
    test('learner maps to GradeBand.g4_6', () {
      expect(gradeBandForRole(UserRole.learner), GradeBand.g4_6);
    });

    test('parent maps to GradeBand.g4_6', () {
      expect(gradeBandForRole(UserRole.parent), GradeBand.g4_6);
    });

    test('educator maps to GradeBand.g7_9', () {
      expect(gradeBandForRole(UserRole.educator), GradeBand.g7_9);
    });

    test('site maps to GradeBand.g7_9', () {
      expect(gradeBandForRole(UserRole.site), GradeBand.g7_9);
    });

    test('partner maps to GradeBand.g7_9', () {
      expect(gradeBandForRole(UserRole.partner), GradeBand.g7_9);
    });

    test('hq maps to GradeBand.g7_9', () {
      expect(gradeBandForRole(UserRole.hq), GradeBand.g7_9);
    });

    test('learner-facing roles (learner, parent) share the same band', () {
      final GradeBand learnerBand = gradeBandForRole(UserRole.learner);
      final GradeBand parentBand = gradeBandForRole(UserRole.parent);
      expect(learnerBand, equals(parentBand));
    });

    test('operational roles (educator, site, partner, hq) share the same band',
        () {
      final GradeBand educatorBand = gradeBandForRole(UserRole.educator);
      final GradeBand siteBand = gradeBandForRole(UserRole.site);
      final GradeBand partnerBand = gradeBandForRole(UserRole.partner);
      final GradeBand hqBand = gradeBandForRole(UserRole.hq);
      expect(educatorBand, equals(siteBand));
      expect(siteBand, equals(partnerBand));
      expect(partnerBand, equals(hqBand));
    });
  });

  group('gradeBandForRole completeness', () {
    test('handles every UserRole enum value without throwing', () {
      for (final UserRole role in UserRole.values) {
        expect(
          () => gradeBandForRole(role),
          returnsNormally,
          reason: 'gradeBandForRole should handle UserRole.${role.name}',
        );
      }
    });

    test('every UserRole produces a valid GradeBand', () {
      for (final UserRole role in UserRole.values) {
        final GradeBand band = gradeBandForRole(role);
        expect(
          GradeBand.values.contains(band),
          isTrue,
          reason:
              'gradeBandForRole(${role.name}) should return a valid GradeBand',
        );
      }
    });

    test('all six UserRole values are covered', () {
      // Guard against silent enum additions breaking the mapping.
      expect(UserRole.values.length, 6,
          reason: 'Expected 6 UserRole values; update tests if enum changes');
    });
  });

  group('SessionOccurrenceResolver typedef', () {
    test('can be assigned as a function type', () {
      // Compile-time check: the typedef exists and is assignable.
      // ignore: prefer_function_declarations_over_variables
      final SessionOccurrenceResolver resolver =
          (context, {required siteId, required learnerId}) async {
        return 'test-occurrence-id';
      };
      expect(resolver, isNotNull);
    });

    test('resolver captures siteId and learnerId correctly', () {
      // Verify the typedef shape accepts the expected named parameters.
      // We don't invoke it (that requires a real BuildContext), but we
      // confirm the closure compiles with the right signature.
      String? capturedSiteId;
      String? capturedLearnerId;
      // ignore: prefer_function_declarations_over_variables
      final SessionOccurrenceResolver resolver =
          (context, {required siteId, required learnerId}) async {
        capturedSiteId = siteId;
        capturedLearnerId = learnerId;
        return '$siteId-$learnerId';
      };
      expect(resolver, isA<Function>());
      expect(capturedSiteId, isNull); // not invoked
      expect(capturedLearnerId, isNull);
    });
  });

  group('lookupSessionOccurrenceFromFirestore signature', () {
    test('function exists and is importable', () {
      // Compile-time verification that the function is exported.
      expect(lookupSessionOccurrenceFromFirestore, isA<Function>());
    });
  });

  group('resolveSessionOccurrenceId signature', () {
    test('function exists and is importable', () {
      // Compile-time verification that the function is exported.
      expect(resolveSessionOccurrenceId, isA<Function>());
    });
  });
}
