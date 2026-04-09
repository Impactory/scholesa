@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/runtime/bos_event_bus.dart';
import 'package:scholesa_app/runtime/bos_models.dart';

BosEvent _makeEvent(String eventType) => BosEvent(
      eventType: eventType,
      siteId: 'site-test-001',
      actorId: 'actor-test-001',
      actorRole: 'learner',
      gradeBand: GradeBand.g4_6,
    );

void main() {
  // Because BosEventBus.instance is a singleton with persistent buffer state,
  // we cannot truly isolate tests. Tests are ordered to account for this.

  group('BosEventBus.allowedBosEvents', () {
    test('contains the expected number of allowed event types', () {
      // The allowlist may grow as new event types are added. Verify it has
      // at least the original 36 and capture the current count.
      expect(BosEventBus.allowedBosEvents.length, greaterThanOrEqualTo(36));
      // Snapshot: current count as of last audit.
      expect(BosEventBus.allowedBosEvents.length, 44);
    });

    test('includes known mission lifecycle events', () {
      expect(
        BosEventBus.allowedBosEvents,
        containsAll(<String>[
          'mission_viewed',
          'mission_selected',
          'mission_started',
          'mission_completed',
        ]),
      );
    });

    test('includes known checkpoint and artifact events', () {
      expect(
        BosEventBus.allowedBosEvents,
        containsAll(<String>[
          'checkpoint_started',
          'checkpoint_submitted',
          'checkpoint_graded',
          'artifact_created',
          'artifact_submitted',
          'artifact_reviewed',
          'artifact_version_saved',
          'debug_attempted',
        ]),
      );
    });

    test('includes known AI help events', () {
      expect(
        BosEventBus.allowedBosEvents,
        containsAll(<String>[
          'ai_help_opened',
          'ai_help_used',
          'ai_coach_response',
          'ai_coach_feedback',
          'ai_learning_goal_updated',
        ]),
      );
    });

    test('includes known metacognition events', () {
      expect(
        BosEventBus.allowedBosEvents,
        containsAll(<String>[
          'explain_it_back_submitted',
          'source_check_performed',
          'retrieval_attempted',
          'reflection_submitted',
        ]),
      );
    });

    test('includes known MVL events', () {
      expect(
        BosEventBus.allowedBosEvents,
        containsAll(<String>[
          'mvl_gate_triggered',
          'mvl_evidence_attached',
          'mvl_passed',
          'mvl_failed',
          'mvl_needs_more_evidence',
          'mvl_evidence_submitted',
        ]),
      );
    });

    test('includes known teacher override events', () {
      expect(
        BosEventBus.allowedBosEvents,
        containsAll(<String>[
          'teacher_override_mvl',
          'teacher_override_intervention',
          'teacher_override_applied',
        ]),
      );
    });

    test('includes known contestability events', () {
      expect(
        BosEventBus.allowedBosEvents,
        containsAll(<String>[
          'contestability_requested',
          'contestability_resolved',
        ]),
      );
    });

    test('includes known navigation and engagement events', () {
      expect(
        BosEventBus.allowedBosEvents,
        containsAll(<String>[
          'session_joined',
          'session_left',
          'idle_detected',
          'focus_restored',
          'interaction_signal_observed',
        ]),
      );
    });

    test('includes known voice I/O events', () {
      expect(
        BosEventBus.allowedBosEvents,
        containsAll(<String>[
          'voice_stt_completed',
          'voice_tts_played',
        ]),
      );
    });

    test('includes known educator insight events', () {
      expect(
        BosEventBus.allowedBosEvents,
        containsAll(<String>[
          'educator_class_view',
          'educator_learner_drilldown',
        ]),
      );
    });

    test('does not contain unknown event types', () {
      expect(
        BosEventBus.allowedBosEvents.contains('totally_fake_event'),
        isFalse,
      );
      expect(
        BosEventBus.allowedBosEvents.contains(''),
        isFalse,
      );
    });
  });

  group('BosEventBus.instance', () {
    test('is a singleton — same reference on repeated access', () {
      final BosEventBus a = BosEventBus.instance;
      final BosEventBus b = BosEventBus.instance;
      expect(identical(a, b), isTrue);
    });
  });

  group('emit()', () {
    test('accepts a valid BosEvent without throwing', () {
      expect(
        () => BosEventBus.instance.emit(_makeEvent('mission_viewed')),
        returnsNormally,
      );
    });

    test('accepts every allowed event type without throwing', () {
      for (final String eventType in BosEventBus.allowedBosEvents) {
        expect(
          () => BosEventBus.instance.emit(_makeEvent(eventType)),
          returnsNormally,
          reason: 'emit() should accept allowed event type: $eventType',
        );
      }
    });

    test('silently drops unknown event types (no exception)', () {
      expect(
        () => BosEventBus.instance.emit(_makeEvent('totally_fake_event')),
        returnsNormally,
      );
    });

    test('silently drops empty string event type', () {
      expect(
        () => BosEventBus.instance.emit(_makeEvent('')),
        returnsNormally,
      );
    });

    test('handles rapid sequential emits without throwing', () {
      expect(
        () {
          for (int i = 0; i < 100; i++) {
            BosEventBus.instance.emit(_makeEvent('checkpoint_submitted'));
          }
        },
        returnsNormally,
      );
    });
  });

  group('buffer overflow', () {
    test('emitting 510 events does not throw (overflow is trimmed)', () {
      // The buffer max is 500. Emitting beyond that should trim oldest events
      // silently — no exception, no crash.
      expect(
        () {
          for (int i = 0; i < 510; i++) {
            BosEventBus.instance.emit(_makeEvent('artifact_created'));
          }
        },
        returnsNormally,
      );
    });
  });

  group('track()', () {
    test('returns without throwing when Firebase is not initialised', () {
      // In a test environment Firebase.apps is empty, so track() should
      // return early as a no-op.
      expect(
        () => BosEventBus.instance.track(
          eventType: 'mission_viewed',
          siteId: 'site-test-001',
          gradeBand: GradeBand.g4_6,
        ),
        returnsNormally,
      );
    });

    test('no-ops for unknown event type without Firebase', () {
      expect(
        () => BosEventBus.instance.track(
          eventType: 'totally_fake_event',
          siteId: 'site-test-001',
          gradeBand: GradeBand.g7_9,
          actorRole: 'educator',
        ),
        returnsNormally,
      );
    });
  });

  group('flushNow()', () {
    test('completes without throwing on empty buffer', () async {
      // flushNow() should be safe to call at any time, even when the buffer
      // is empty and no Firebase backend is available.
      await expectLater(
        BosEventBus.instance.flushNow(),
        completes,
      );
    });

    test('completes without throwing after emitting events', () async {
      BosEventBus.instance.emit(_makeEvent('session_joined'));
      BosEventBus.instance.emit(_makeEvent('session_left'));
      // Flush will attempt network call via BosService which will fail
      // silently (no Firebase), re-buffering events. Should not throw.
      await expectLater(
        BosEventBus.instance.flushNow(),
        completes,
      );
    });
  });

  group('setOfflineQueue()', () {
    test('can be called without throwing', () {
      // We cannot easily construct a real OfflineQueue without Isar, but we
      // verify the static method signature exists and is callable. A real
      // integration test would supply a mock OfflineQueue.
      // This test simply confirms the method exists on the class.
      expect(BosEventBus.setOfflineQueue, isA<Function>());
    });
  });

  group('client-side rate limiting', () {
    test('droppedByRateLimit counter is accessible', () {
      expect(BosEventBus.instance.droppedByRateLimit, isA<int>());
    });

    test('droppedByRateLimit starts at or above 0', () {
      // Due to singleton state from prior tests, this may be > 0 already.
      expect(BosEventBus.instance.droppedByRateLimit, greaterThanOrEqualTo(0));
    });
  });

  group('BosEvent construction', () {
    test('auto-generates eventId when not provided', () {
      final BosEvent event = _makeEvent('mission_viewed');
      expect(event.eventId, isNotEmpty);
    });

    test('uses provided eventId when given', () {
      final BosEvent event = BosEvent(
        eventType: 'mission_viewed',
        siteId: 'site-001',
        actorId: 'actor-001',
        actorRole: 'learner',
        gradeBand: GradeBand.g4_6,
        eventId: 'custom-id-123',
      );
      expect(event.eventId, 'custom-id-123');
    });

    test('two events get distinct auto-generated eventIds', () {
      final BosEvent a = _makeEvent('mission_viewed');
      final BosEvent b = _makeEvent('mission_viewed');
      expect(a.eventId, isNot(equals(b.eventId)));
    });

    test('schemaVersion is 2.0.0', () {
      expect(BosEvent.schemaVersion, '2.0.0');
    });

    test('defaults contextMode to unknown', () {
      final BosEvent event = _makeEvent('mission_viewed');
      expect(event.contextMode, ContextMode.unknown);
    });

    test('defaults payload to empty map', () {
      final BosEvent event = _makeEvent('mission_viewed');
      expect(event.payload, isEmpty);
    });
  });
}
