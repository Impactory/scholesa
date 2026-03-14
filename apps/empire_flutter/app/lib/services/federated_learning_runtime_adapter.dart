import 'dart:async';
import 'dart:convert';

import '../auth/app_state.dart';
import '../domain/models.dart';
import '../runtime/bos_models.dart';
import 'federated_learning_prototype_uploader.dart';
import 'workflow_bridge_service.dart';

class FederatedLearningRuntimeAdapter {
  FederatedLearningRuntimeAdapter._();

  static final FederatedLearningRuntimeAdapter instance =
      FederatedLearningRuntimeAdapter._();

  static const String _schemaVersion = 'fl-prototype-bos-v1';
  static const Set<String> _flushTriggerEvents = <String>{
    'mission_completed',
    'checkpoint_submitted',
    'session_left',
  };
  static const Duration _assignmentCacheTtl = Duration(minutes: 5);
  static const int _maxBufferedSamples = 8;

  AppState? _appState;
  WorkflowBridgeService? _workflowBridge;
  FederatedLearningPrototypeUploader? _uploader;
  DateTime? _assignmentCacheLoadedAt;
  Map<String, List<FederatedLearningExperimentModel>> _assignmentCache =
      <String, List<FederatedLearningExperimentModel>>{};
  final Map<String, _RuntimeAggregationWindow> _windows =
      <String, _RuntimeAggregationWindow>{};

  void configure({
    required AppState appState,
    WorkflowBridgeService? workflowBridge,
  }) {
    final bool stateChanged = !identical(_appState, appState);
    final bool bridgeChanged =
        workflowBridge != null && workflowBridge != _workflowBridge;
    _appState = appState;
    _workflowBridge = workflowBridge ?? _workflowBridge;
    _uploader = FederatedLearningPrototypeUploader(
      appState: appState,
      workflowBridge: _workflowBridge,
    );
    if (stateChanged || bridgeChanged) {
      _assignmentCacheLoadedAt = null;
      _assignmentCache = <String, List<FederatedLearningExperimentModel>>{};
      _windows.clear();
    }
  }

  void resetForTesting() {
    _appState = null;
    _workflowBridge = null;
    _uploader = null;
    _assignmentCacheLoadedAt = null;
    _assignmentCache = <String, List<FederatedLearningExperimentModel>>{};
    _windows.clear();
  }

  Future<void> handleRuntimeEvent({
    required String eventType,
    required String siteId,
    required String learnerId,
    required GradeBand gradeBand,
    String? sessionOccurrenceId,
    String? missionId,
    String? checkpointId,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) async {
    if (_uploader == null) return;
    final String normalizedSiteId = siteId.trim();
    final String normalizedLearnerId = learnerId.trim();
    if (normalizedSiteId.isEmpty || normalizedLearnerId.isEmpty) return;

    final List<FederatedLearningExperimentModel> assignments =
        await _loadAssignmentsForSite(normalizedSiteId);
    if (assignments.isEmpty) return;

    final _RuntimeSample sample = _RuntimeSample(
      eventType: eventType,
      learnerId: normalizedLearnerId,
      sessionOccurrenceId: sessionOccurrenceId?.trim(),
      missionId: missionId?.trim(),
      checkpointId: checkpointId?.trim(),
      gradeBand: gradeBand.code,
      payload: Map<String, dynamic>.from(payload),
      capturedAt: DateTime.now().toUtc(),
    );

    for (final FederatedLearningExperimentModel experiment in assignments) {
      final String windowKey = _windowKey(
        experimentId: experiment.id,
        siteId: normalizedSiteId,
        learnerId: normalizedLearnerId,
        sessionOccurrenceId: sample.sessionOccurrenceId,
      );
      final _RuntimeAggregationWindow window = _windows.putIfAbsent(
          windowKey,
          () => _RuntimeAggregationWindow(
                experimentId: experiment.id,
                siteId: normalizedSiteId,
                learnerId: normalizedLearnerId,
                sessionOccurrenceId: sample.sessionOccurrenceId,
              ));
      window.samples.add(sample);

      if (_flushTriggerEvents.contains(eventType) ||
          window.samples.length >= _maxBufferedSamples) {
        await _flushWindow(experiment, windowKey, window);
      }
    }
  }

  Future<void> flushForContext({
    required String siteId,
    required String learnerId,
    String? sessionOccurrenceId,
  }) async {
    if (_uploader == null) return;
    final String normalizedSiteId = siteId.trim();
    final String normalizedLearnerId = learnerId.trim();
    if (normalizedSiteId.isEmpty || normalizedLearnerId.isEmpty) return;

    final List<FederatedLearningExperimentModel> assignments =
        await _loadAssignmentsForSite(normalizedSiteId);
    if (assignments.isEmpty) return;

    for (final FederatedLearningExperimentModel experiment in assignments) {
      final String windowKey = _windowKey(
        experimentId: experiment.id,
        siteId: normalizedSiteId,
        learnerId: normalizedLearnerId,
        sessionOccurrenceId: sessionOccurrenceId,
      );
      final _RuntimeAggregationWindow? window = _windows[windowKey];
      if (window == null) continue;
      await _flushWindow(experiment, windowKey, window);
    }
  }

  Future<List<FederatedLearningExperimentModel>> _loadAssignmentsForSite(
    String siteId,
  ) async {
    final DateTime now = DateTime.now().toUtc();
    if (_assignmentCacheLoadedAt != null &&
        now.difference(_assignmentCacheLoadedAt!) < _assignmentCacheTtl &&
        _assignmentCache.containsKey(siteId)) {
      return _assignmentCache[siteId] ??
          const <FederatedLearningExperimentModel>[];
    }

    final List<FederatedLearningExperimentModel> assignments =
        await _uploader!.listAssignments(siteId: siteId);
    _assignmentCacheLoadedAt = now;
    _assignmentCache[siteId] = assignments;
    return assignments;
  }

  Future<void> _flushWindow(
    FederatedLearningExperimentModel experiment,
    String windowKey,
    _RuntimeAggregationWindow window,
  ) async {
    if (window.samples.isEmpty) return;

    final List<_RuntimeSample> samples =
        List<_RuntimeSample>.from(window.samples);
    _windows.remove(windowKey);

    final List<String> eventTypes =
        samples.map((sample) => sample.eventType).toList(growable: false);
    final Set<String> vectorDimensions = <String>{
      ...eventTypes,
      ...samples
          .expand((sample) => sample.payload.keys)
          .map((String key) => 'payload:$key'),
    };
    final int estimatedBytes = utf8
        .encode(jsonEncode(samples.map((sample) => sample.signature).toList()))
        .length;
    final int payloadBytes = estimatedBytes > experiment.rawUpdateMaxBytes
        ? experiment.rawUpdateMaxBytes
        : estimatedBytes;
    final int digestValue = Object.hashAll(
      samples.map((sample) => Object.hashAll(<Object?>[
            sample.eventType,
            sample.gradeBand,
            sample.missionId,
            sample.checkpointId,
            sample.sessionOccurrenceId,
            sample.signature,
          ])),
    ).toUnsigned(32);
    final double updateNorm =
        samples.length + (vectorDimensions.length / 100.0);

    try {
      await _uploader!.uploadSummary(
        experiment: experiment,
        siteId: window.siteId,
        traceId:
            '${experiment.id}:${window.learnerId}:${window.sessionOccurrenceId ?? 'sessionless'}:${DateTime.now().toUtc().millisecondsSinceEpoch}',
        schemaVersion: _schemaVersion,
        sampleCount: samples.length,
        vectorLength: vectorDimensions.length.clamp(1, 100000),
        payloadBytes: payloadBytes.clamp(1, experiment.rawUpdateMaxBytes),
        updateNorm: updateNorm,
        payloadDigest: digestValue.toRadixString(16).padLeft(8, '0'),
        batteryState: 'unknown',
        networkType: 'unknown',
      );
    } catch (_) {
      _windows[windowKey] = _RuntimeAggregationWindow(
        experimentId: window.experimentId,
        siteId: window.siteId,
        learnerId: window.learnerId,
        sessionOccurrenceId: window.sessionOccurrenceId,
        samples: samples,
      );
    }
  }

  String _windowKey({
    required String experimentId,
    required String siteId,
    required String learnerId,
    String? sessionOccurrenceId,
  }) {
    return '$experimentId::$siteId::$learnerId::${(sessionOccurrenceId ?? '').trim()}';
  }
}

class _RuntimeAggregationWindow {
  _RuntimeAggregationWindow({
    required this.experimentId,
    required this.siteId,
    required this.learnerId,
    required this.sessionOccurrenceId,
    List<_RuntimeSample>? samples,
  }) : samples = samples ?? <_RuntimeSample>[];

  final String experimentId;
  final String siteId;
  final String learnerId;
  final String? sessionOccurrenceId;
  final List<_RuntimeSample> samples;
}

class _RuntimeSample {
  const _RuntimeSample({
    required this.eventType,
    required this.learnerId,
    required this.gradeBand,
    required this.payload,
    required this.capturedAt,
    this.sessionOccurrenceId,
    this.missionId,
    this.checkpointId,
  });

  final String eventType;
  final String learnerId;
  final String gradeBand;
  final String? sessionOccurrenceId;
  final String? missionId;
  final String? checkpointId;
  final Map<String, dynamic> payload;
  final DateTime capturedAt;

  String get signature => jsonEncode(<String, dynamic>{
        'eventType': eventType,
        'gradeBand': gradeBand,
        'sessionOccurrenceId': sessionOccurrenceId,
        'missionId': missionId,
        'checkpointId': checkpointId,
        'payloadKeys': payload.keys.toList()..sort(),
        'capturedAt': capturedAt.toIso8601String(),
      });
}
