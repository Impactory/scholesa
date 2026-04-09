import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import '../auth/app_state.dart';
import '../domain/models.dart';
import '../runtime/runtime.dart';
import 'federated_learning_runtime_activation_reporter.dart';
import 'federated_learning_runtime_package_resolver.dart';
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
  static const String _optimizerStrategy =
      'bounded_runtime_vector_local_finetune_v1';

  AppState? _appState;
  WorkflowBridgeService? _workflowBridge;
  FederatedLearningPrototypeUploader? _uploader;
  FederatedLearningRuntimePackageResolver? _packageResolver;
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
    _packageResolver = FederatedLearningRuntimePackageResolver(
      appState: appState,
      workflowBridge: _workflowBridge,
      activationReporter: FederatedLearningRuntimeActivationReporter(
        appState: appState,
        workflowBridge: _workflowBridge,
      ),
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
    _packageResolver?.resetForTesting();
    _packageResolver = null;
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
    final FederatedLearningResolvedRuntimePackageModel? runtimePackage =
        _packageResolver == null
            ? null
            : await _packageResolver!.resolveActivePackage(
                siteId: window.siteId,
                experimentId: experiment.id,
                runtimeTarget: experiment.runtimeTarget,
              );
    final bool hasWarmStart =
        runtimePackage != null && runtimePackage.runtimeVector.isNotEmpty;
    final bool canFineTune =
        !experiment.requireWarmStartForTraining || hasWarmStart;
    final int localEpochCount = _deriveLocalEpochCount(
      sampleCount: samples.length,
      hasWarmStart: hasWarmStart,
      allowFineTuning: canFineTune,
      maxLocalEpochs: experiment.maxLocalEpochs,
      maxLocalSteps: experiment.maxLocalSteps,
    );
    final List<double> vectorSketch = _buildLocallyFineTunedVector(
      samples,
      runtimePackage: runtimePackage,
      localEpochCount: localEpochCount,
    );
    final double updateNorm = _calculateLocalUpdateNorm(
      vectorSketch,
      runtimePackage: runtimePackage,
    );
    final DateTime earliest = samples
        .map((sample) => sample.capturedAt)
        .reduce((DateTime a, DateTime b) => a.isBefore(b) ? a : b);
    final DateTime latest = samples
        .map((sample) => sample.capturedAt)
        .reduce((DateTime a, DateTime b) => a.isAfter(b) ? a : b);
    final int trainingWindowSeconds = canFineTune
      ? latest
        .difference(earliest)
        .inSeconds
        .clamp(0, experiment.maxTrainingWindowSeconds)
      : 0;
    final int localStepCount = canFineTune
      ? math.min(
        samples.length * localEpochCount,
        experiment.maxLocalSteps,
        )
      : 0;

    try {
      await _uploader!.uploadSummary(
        experiment: experiment,
        siteId: window.siteId,
        traceId:
            '${experiment.id}:${window.learnerId}:${window.sessionOccurrenceId ?? 'sessionless'}:${DateTime.now().toUtc().millisecondsSinceEpoch}',
        schemaVersion: _schemaVersion,
        sampleCount: samples.length,
        vectorLength: vectorSketch.length.clamp(1, 100000),
        vectorSketch: vectorSketch,
        payloadBytes: payloadBytes.clamp(1, experiment.rawUpdateMaxBytes),
        updateNorm: updateNorm,
        payloadDigest: _buildPayloadDigest(
          digestValue: digestValue,
          vectorSketch: vectorSketch,
          runtimeVectorDigest: runtimePackage?.runtimeVectorDigest,
        ),
        optimizerStrategy: canFineTune ? _optimizerStrategy : null,
        localEpochCount: localEpochCount,
        localStepCount: localStepCount,
        trainingWindowSeconds: trainingWindowSeconds,
        warmStartPackageId: runtimePackage?.candidateModelPackageId,
        warmStartDeliveryRecordId: runtimePackage?.deliveryRecordId,
        warmStartModelVersion: runtimePackage?.modelVersion,
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

  int _deriveLocalEpochCount({
    required int sampleCount,
    required bool hasWarmStart,
    required bool allowFineTuning,
    required int maxLocalEpochs,
    required int maxLocalSteps,
  }) {
    if (!allowFineTuning) {
      return 0;
    }
    if (sampleCount <= 0) {
      return 1;
    }
    final int stepBoundEpochs = math.max(1, maxLocalSteps ~/ sampleCount);
    if (!hasWarmStart) {
      return math.min(1, math.min(maxLocalEpochs, stepBoundEpochs));
    }
    final int desiredEpochCount;
    if (sampleCount >= 6) {
      desiredEpochCount = 3;
    } else if (sampleCount >= 2) {
      desiredEpochCount = 2;
    } else {
      desiredEpochCount = 1;
    }
    return math.max(1, math.min(desiredEpochCount, math.min(maxLocalEpochs, stepBoundEpochs)));
  }

  List<double> _buildLocallyFineTunedVector(
    List<_RuntimeSample> samples, {
    FederatedLearningResolvedRuntimePackageModel? runtimePackage,
    required int localEpochCount,
  }) {
    final List<double> trainingTargets = _buildTrainingTargets(
      samples,
      runtimePackage: runtimePackage,
    );
    if (localEpochCount <= 0) {
      return trainingTargets
          .map((double value) => double.parse(value.toStringAsFixed(6)))
          .toList(growable: false);
    }
    final List<double> warmStartVector =
        runtimePackage?.runtimeVector ?? const <double>[];
    final List<double> current = List<double>.generate(
      trainingTargets.length,
      (int index) => index < warmStartVector.length ? warmStartVector[index] : 0,
    );
    final double baseLearningRate = warmStartVector.isNotEmpty ? 0.35 : 0.5;
    for (int epoch = 0; epoch < localEpochCount; epoch += 1) {
      final double epochRate = baseLearningRate / (epoch + 1);
      for (int index = 0; index < current.length; index += 1) {
        final double gradient = trainingTargets[index] - current[index];
        current[index] = _clampUnitValue(current[index] + (gradient * epochRate));
      }
    }
    return current
        .map((double value) => double.parse(value.toStringAsFixed(6)))
        .toList(growable: false);
  }

  List<double> _buildTrainingTargets(
    List<_RuntimeSample> samples, {
    FederatedLearningResolvedRuntimePackageModel? runtimePackage,
  }) {
    final Map<String, int> eventCounts = <String, int>{};
    final Set<String> missionIds = <String>{};
    final Set<String> checkpointIds = <String>{};
    int payloadKeyCount = 0;
    for (final _RuntimeSample sample in samples) {
      eventCounts.update(sample.eventType, (value) => value + 1,
          ifAbsent: () => 1);
      if ((sample.missionId ?? '').isNotEmpty) {
        missionIds.add(sample.missionId!);
      }
      if ((sample.checkpointId ?? '').isNotEmpty) {
        checkpointIds.add(sample.checkpointId!);
      }
      payloadKeyCount += sample.payload.length;
    }

    final int sampleCount = samples.isEmpty ? 1 : samples.length;
    final List<double> baseVector = <double>[
      samples.length / _maxBufferedSamples,
      (eventCounts['mission_started'] ?? 0) / sampleCount,
      (eventCounts['checkpoint_submitted'] ?? 0) / sampleCount,
      (eventCounts['mission_completed'] ?? 0) / sampleCount,
      (eventCounts['session_left'] ?? 0) / sampleCount,
      missionIds.length / sampleCount,
      checkpointIds.length / sampleCount,
      payloadKeyCount / (sampleCount * 4),
    ];

    final List<double> runtimeVector = runtimePackage?.runtimeVector ?? const <double>[];
    final int targetLength = runtimeVector.isNotEmpty
        ? runtimeVector.length
        : baseVector.length;
    return List<double>.generate(targetLength, (int index) {
      final double baseValue = index < baseVector.length ? baseVector[index] : 0;
      return _clampUnitValue(baseValue);
    }, growable: false);
  }

  double _calculateLocalUpdateNorm(
    List<double> tunedVector, {
    FederatedLearningResolvedRuntimePackageModel? runtimePackage,
  }) {
    final List<double> warmStartVector =
        runtimePackage?.runtimeVector ?? const <double>[];
    final Iterable<double> squaredTerms = tunedVector.asMap().entries.map(
      (MapEntry<int, double> entry) {
        final double warmStart =
            entry.key < warmStartVector.length ? warmStartVector[entry.key] : 0;
        final double delta = entry.value - warmStart;
        return delta * delta;
      },
    );
    final double sumSquares = squaredTerms.fold<double>(
      0,
      (double total, double value) => total + value,
    );
    return double.parse(math.sqrt(sumSquares).toStringAsFixed(6));
  }

  double _clampUnitValue(double value) {
    if (value.isNaN) {
      return 0;
    }
    if (value < 0) {
      return 0;
    }
    if (value > 1) {
      return 1;
    }
    return value;
  }

  String _buildPayloadDigest({
    required int digestValue,
    required List<double> vectorSketch,
    String? runtimeVectorDigest,
  }) {
    final int payloadSignature = Object.hashAll(<Object?>[
      digestValue,
      runtimeVectorDigest,
      ...vectorSketch,
    ]);
    return payloadSignature.toUnsigned(32).toRadixString(16).padLeft(8, '0');
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
