import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'bos_models.dart';
import 'bos_event_bus.dart';
import '../services/federated_learning_runtime_adapter.dart';

// ──────────────────────────────────────────────────────
// Learning Runtime Provider
// Spec: BOS_MIA_HOW_TO_IMPLEMENT.md §2, §3
//
// Wraps the active learning session with:
//  ● Live orchestration state (x_hat, P) from Firestore
//  ● Active MVL episodes
//  ● Event bus shortcut methods
// ──────────────────────────────────────────────────────

/// Provider for active learning runtime context.
///
/// Consumers: LearnerMission screen, AI Chat, MVL Gate UI.
enum LearningRuntimeStateStatus {
  unavailable,
  ready,
  malformed,
}

class LearningRuntimeProvider extends ChangeNotifier {
  LearningRuntimeProvider({
    required this.siteId,
    required this.learnerId,
    required this.gradeBand,
    this.sessionOccurrenceId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String siteId;
  final String learnerId;
  final GradeBand gradeBand;
  final String? sessionOccurrenceId;
  final FirebaseFirestore _firestore;

  // ── Live state ────────────────────────────

  OrchestrationState? _state;
  OrchestrationState? get state => _state;

  LearningRuntimeStateStatus _stateStatus =
      LearningRuntimeStateStatus.unavailable;
  LearningRuntimeStateStatus get stateStatus => _stateStatus;

  String? _stateLoadIssue;
  String? get stateLoadIssue => _stateLoadIssue;

  bool get hasUsableState =>
      _stateStatus == LearningRuntimeStateStatus.ready && _state != null;

  MvlEpisode? _activeMvl;
  MvlEpisode? get activeMvl => _activeMvl;

  bool get hasMvlGate => _activeMvl != null && _activeMvl!.resolution == null;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _stateSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _mvlSub;

  // ── Lifecycle ─────────────────────────────

  /// Start real-time listeners.
  void startListening() {
    _listenOrchestrationState();
    _listenActiveMvl();
  }

  void _listenOrchestrationState() {
    if (sessionOccurrenceId == null) return;

    final String docId = '${learnerId}_$sessionOccurrenceId';
    _stateSub = _firestore
        .collection('orchestrationStates')
        .doc(docId)
        .snapshots()
        .listen((DocumentSnapshot<Map<String, dynamic>> snap) {
      if (snap.exists && snap.data() != null) {
        final OrchestrationState? parsed =
            OrchestrationState.tryFromMap(snap.data()!);
        if (parsed != null) {
          _state = parsed;
          _stateStatus = LearningRuntimeStateStatus.ready;
          _stateLoadIssue = null;
        } else {
          _state = null;
          _stateStatus = LearningRuntimeStateStatus.malformed;
          _stateLoadIssue = 'malformed_orchestration_state';
          debugPrint(
            '[BOS] Ignoring malformed orchestration state for $docId.',
          );
        }
      } else {
        _state = null;
        _stateStatus = LearningRuntimeStateStatus.unavailable;
        _stateLoadIssue = null;
      }
      notifyListeners();
    });
  }

  void _listenActiveMvl() {
    _mvlSub = _firestore
        .collection('mvlEpisodes')
        .where('learnerId', isEqualTo: learnerId)
        .where('siteId', isEqualTo: siteId)
        .where('resolution', isNull: true)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((QuerySnapshot<Map<String, dynamic>> snap) {
      if (snap.docs.isNotEmpty) {
        _activeMvl = MvlEpisode.tryFromDoc(snap.docs.first);
      } else {
        _activeMvl = null;
      }
      notifyListeners();
    });
  }

  // ── Event helpers ─────────────────────────

  /// Emit a BOS event scoped to this session.
  void trackEvent(
    String eventType, {
    String? missionId,
    String? checkpointId,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) {
    unawaited(FederatedLearningRuntimeAdapter.instance.handleRuntimeEvent(
      eventType: eventType,
      siteId: siteId,
      learnerId: learnerId,
      gradeBand: gradeBand,
      sessionOccurrenceId: sessionOccurrenceId,
      missionId: missionId,
      checkpointId: checkpointId,
      payload: payload,
    ));
    BosEventBus.instance.track(
      eventType: eventType,
      siteId: siteId,
      gradeBand: gradeBand,
      sessionOccurrenceId: sessionOccurrenceId,
      missionId: missionId,
      checkpointId: checkpointId,
      payload: payload,
    );
  }

  // ── Derived state helpers ─────────────────

  /// Current cognition level (0..1) or null if no state.
  double? get cognition => _state?.xHat.cognition;

  /// Current engagement level (0..1) or null if no state.
  double? get engagement => _state?.xHat.engagement;

  /// Current integrity level (0..1) or null if no state.
  double? get integrity => _state?.xHat.integrity;

  /// Overall confidence from the covariance summary.
  double? get confidence => _state?.p.confidence;

  // ── Cleanup ───────────────────────────────

  @override
  void dispose() {
    _stateSub?.cancel();
    _mvlSub?.cancel();
    unawaited(FederatedLearningRuntimeAdapter.instance.flushForContext(
      siteId: siteId,
      learnerId: learnerId,
      sessionOccurrenceId: sessionOccurrenceId,
    ));
    BosEventBus.instance.flushNow();
    super.dispose();
  }
}
