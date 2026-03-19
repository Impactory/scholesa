import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

const Uuid _uuid = Uuid();

double? _readFiniteDouble(Map<String, dynamic> source, String key) {
  final dynamic value = source[key];
  if (value is! num) {
    return null;
  }
  final double converted = value.toDouble();
  return converted.isFinite ? converted : null;
}

List<double>? _readFiniteDoubleList(Map<String, dynamic> source, String key) {
  final dynamic value = source[key];
  if (value is! List<dynamic>) {
    return null;
  }
  final List<double> converted = <double>[];
  for (final dynamic entry in value) {
    if (entry is! num) {
      return null;
    }
    final double numeric = entry.toDouble();
    if (!numeric.isFinite) {
      return null;
    }
    converted.add(numeric);
  }
  return converted;
}

Map<String, dynamic>? _asStringDynamicMap(dynamic value) {
  if (value is! Map<dynamic, dynamic>) {
    return null;
  }
  return value.map(
    (dynamic key, dynamic val) => MapEntry(key.toString(), val),
  );
}

String? _readTrimmedString(Map<String, dynamic> source, String key) {
  final dynamic value = source[key];
  if (value is! String) {
    return null;
  }
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

// ──────────────────────────────────────────────────────
// BOS+MIA Core Models
// Spec: BOS_MIA_MATH_CONTRACT.md §1–§8
// ──────────────────────────────────────────────────────

/// Grade bands per BOS spec §4.2
enum GradeBand {
  g1_3('G1_3'),
  g4_6('G4_6'),
  g7_9('G7_9'),
  g10_12('G10_12');

  const GradeBand(this.code);
  final String code;

  static GradeBand fromString(String s) {
    switch (s.toUpperCase()) {
      case 'G1_3':
        return GradeBand.g1_3;
      case 'G4_6':
        return GradeBand.g4_6;
      case 'G7_9':
        return GradeBand.g7_9;
      case 'G10_12':
        return GradeBand.g10_12;
      default:
        return GradeBand.g4_6;
    }
  }
}

// ──── §1.1  Latent learner state x_t ────

/// Collapsed 3D state estimate (Math Contract §1.1).
@immutable
class XHat {
  const XHat({
    this.cognition = 0.5,
    this.engagement = 0.5,
    this.integrity = 0.5,
  });

  /// Proxy for c_t — mastery/cognition (0..1)
  final double cognition;

  /// Proxy for a_t — affect & engagement (0..1)
  final double engagement;

  /// Proxy for m_t — metacognitive integrity (0..1)
  final double integrity;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'cognition': cognition,
        'engagement': engagement,
        'integrity': integrity,
      };

  factory XHat.fromMap(Map<String, dynamic> m) {
    final XHat? parsed = XHat.tryFromMap(m);
    if (parsed == null) {
      throw const FormatException('Malformed XHat payload.');
    }
    return parsed;
  }

  static XHat? tryFromMap(Map<String, dynamic>? m) {
    if (m == null) {
      return null;
    }
    final double? cognition = _readFiniteDouble(m, 'cognition');
    final double? engagement = _readFiniteDouble(m, 'engagement');
    final double? integrity = _readFiniteDouble(m, 'integrity');
    if (cognition == null || engagement == null || integrity == null) {
      return null;
    }
    return XHat(
      cognition: cognition.clamp(0.0, 1.0).toDouble(),
      engagement: engagement.clamp(0.0, 1.0).toDouble(),
      integrity: integrity.clamp(0.0, 1.0).toDouble(),
    );
  }

  List<double> toVec() => <double>[cognition, engagement, integrity];
}

// ──── §3.2  Covariance summary P ────

/// Uncertainty / covariance summary (Math Contract §3.2).
@immutable
class CovarianceSummary {
  const CovarianceSummary({
    this.diag = const <double>[1.0, 1.0, 1.0],
    this.trace = 3.0,
    this.confidence = 0.0,
  });

  /// Diagonal elements of P matrix
  final List<double> diag;

  /// tr(P)
  final double trace;

  /// 1 − tr(P)/d  (higher = more confident)
  final double confidence;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'diag': diag,
        'trace': trace,
        'confidence': confidence,
      };

  factory CovarianceSummary.fromMap(Map<String, dynamic> m) {
    final CovarianceSummary? parsed = CovarianceSummary.tryFromMap(m);
    if (parsed == null) {
      throw const FormatException('Malformed covariance summary payload.');
    }
    return parsed;
  }

  static CovarianceSummary? tryFromMap(Map<String, dynamic>? m) {
    if (m == null) {
      return null;
    }
    final List<double>? diag = _readFiniteDoubleList(m, 'diag');
    final double? trace = _readFiniteDouble(m, 'trace') ??
        (diag != null && diag.isNotEmpty
            ? diag.reduce((double sum, double entry) => sum + entry)
            : null);
    final double? confidence = _readFiniteDouble(m, 'confidence') ??
        (trace != null ? 1 - (trace / 3) : null);
    if (trace == null || confidence == null) {
      return null;
    }
    return CovarianceSummary(
      diag: diag ?? const <double>[],
      trace: trace,
      confidence: confidence.clamp(0.0, 1.0).toDouble(),
    );
  }
}

// ──── §3.2  Orchestration state composite ────

/// Full orchestration state document (Math Contract §3.2).
@immutable
class OrchestrationState {
  const OrchestrationState({
    required this.siteId,
    required this.learnerId,
    required this.sessionOccurrenceId,
    required this.xHat,
    required this.p,
    this.model,
    this.fusion,
    this.lastUpdatedAt,
  });

  final String siteId;
  final String learnerId;
  final String sessionOccurrenceId;
  final XHat xHat;
  final CovarianceSummary p;
  final EstimatorModel? model;
  final FusionInfo? fusion;
  final Timestamp? lastUpdatedAt;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'siteId': siteId,
        'learnerId': learnerId,
        'sessionOccurrenceId': sessionOccurrenceId,
        'x_hat': xHat.toMap(),
        'P': p.toMap(),
        if (model != null) 'model': model!.toMap(),
        if (fusion != null) 'fusion': fusion!.toMap(),
        'lastUpdatedAt': lastUpdatedAt ?? FieldValue.serverTimestamp(),
      };

  factory OrchestrationState.fromMap(Map<String, dynamic> m) {
    final OrchestrationState? parsed = OrchestrationState.tryFromMap(m);
    if (parsed == null) {
      throw const FormatException('Malformed orchestration state payload.');
    }
    return parsed;
  }

  static OrchestrationState? tryFromMap(Map<String, dynamic>? m) {
    if (m == null) {
      return null;
    }
    final String? siteId = _readTrimmedString(m, 'siteId');
    final String? learnerId = _readTrimmedString(m, 'learnerId');
    final String? sessionOccurrenceId =
        _readTrimmedString(m, 'sessionOccurrenceId');
    final XHat? xHat = XHat.tryFromMap(_asStringDynamicMap(m['x_hat']));
    final CovarianceSummary? p =
        CovarianceSummary.tryFromMap(_asStringDynamicMap(m['P']));
    if (siteId == null ||
        learnerId == null ||
        sessionOccurrenceId == null ||
        xHat == null ||
        p == null) {
      return null;
    }
    return OrchestrationState(
      siteId: siteId,
      learnerId: learnerId,
      sessionOccurrenceId: sessionOccurrenceId,
      xHat: xHat,
      p: p,
      model: EstimatorModel.tryFromMap(
        _asStringDynamicMap(m['model']),
      ),
      fusion: FusionInfo.tryFromMap(
        _asStringDynamicMap(m['fusion']),
      ),
      lastUpdatedAt: m['lastUpdatedAt'] as Timestamp?,
    );
  }
}

@immutable
class EstimatorModel {
  const EstimatorModel({
    this.estimator = 'ekf-lite',
    this.version = '0.1.0',
    this.qVersion = 'v1',
    this.rVersion = 'v1',
  });

  final String estimator;
  final String version;
  final String qVersion;
  final String rVersion;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'estimator': estimator,
        'version': version,
        'Q_version': qVersion,
        'R_version': rVersion,
      };

  factory EstimatorModel.fromMap(Map<String, dynamic> m) {
    final EstimatorModel? parsed = EstimatorModel.tryFromMap(m);
    if (parsed == null) {
      throw const FormatException('Malformed estimator model payload.');
    }
    return parsed;
  }

  static EstimatorModel? tryFromMap(Map<String, dynamic>? m) {
    if (m == null) {
      return null;
    }
    final String? estimator = _readTrimmedString(m, 'estimator');
    final String? version = _readTrimmedString(m, 'version');
    final String? qVersion = _readTrimmedString(m, 'Q_version');
    final String? rVersion = _readTrimmedString(m, 'R_version');
    if (estimator == null || version == null || qVersion == null || rVersion == null) {
      return null;
    }
    return EstimatorModel(
      estimator: estimator,
      version: version,
      qVersion: qVersion,
      rVersion: rVersion,
    );
  }
}

@immutable
class FusionInfo {
  const FusionInfo({
    this.familiesPresent = const <String>[],
    this.sensorFusionMet = false,
  });

  final List<String> familiesPresent;
  final bool sensorFusionMet;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'familiesPresent': familiesPresent,
        'sensorFusionMet': sensorFusionMet,
      };

  factory FusionInfo.fromMap(Map<String, dynamic> m) {
    final FusionInfo? parsed = FusionInfo.tryFromMap(m);
    if (parsed == null) {
      throw const FormatException('Malformed fusion info payload.');
    }
    return parsed;
  }

  static FusionInfo? tryFromMap(Map<String, dynamic>? m) {
    if (m == null) {
      return null;
    }
    final List<String>? familiesPresent = (m['familiesPresent'] as List<dynamic>?)
        ?.whereType<String>()
        .map((String family) => family.trim())
        .where((String family) => family.isNotEmpty)
        .toList();
    final bool? sensorFusionMet = m['sensorFusionMet'] as bool?;
    if (familiesPresent == null || sensorFusionMet == null) {
      return null;
    }
    return FusionInfo(
      familiesPresent: familiesPresent,
      sensorFusionMet: sensorFusionMet,
    );
  }
}

// ──── §1.2  Control input u_t / Intervention ────

/// BOS Intervention (Math Contract §1.2 + §4.3).
@immutable
class BosIntervention {
  const BosIntervention({
    required this.type,
    required this.salience,
    this.mode,
    this.reasonCodes = const <String>[],
    this.policy,
    this.outcome,
    this.supervision,
  });

  final InterventionType type;
  final Salience salience;
  final AiCoachMode? mode;
  final List<String> reasonCodes;
  final PolicyTerms? policy;
  final String? outcome; // accepted | dismissed | completed | timeout
  final SupervisoryControl? supervision;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'type': type.name,
        'salience': salience.name,
        if (mode != null) 'mode': mode!.name,
        'reasonCodes': reasonCodes,
        if (policy != null) 'policy': policy!.toMap(),
        if (outcome != null) 'outcome': outcome,
        if (supervision != null) 'supervision': supervision!.toMap(),
      };

  factory BosIntervention.fromMap(Map<String, dynamic> m) => BosIntervention(
        type: InterventionType.values.firstWhere(
          (InterventionType e) => e.name == m['type'],
          orElse: () => InterventionType.nudge,
        ),
        salience: Salience.values.firstWhere(
          (Salience e) => e.name == m['salience'],
          orElse: () => Salience.low,
        ),
        mode: m['mode'] != null
            ? AiCoachMode.values.firstWhere(
                (AiCoachMode e) => e.name == m['mode'],
                orElse: () => AiCoachMode.hint,
              )
            : null,
        reasonCodes: ((m['reasonCodes'] as List<dynamic>?)?.cast<String>()) ??
            <String>[],
        policy: PolicyTerms.tryFromMap(_asStringDynamicMap(m['policy'])),
        outcome: m['outcome'] as String?,
        supervision: m['supervision'] != null
            ? SupervisoryControl.fromMap(
                m['supervision'] as Map<String, dynamic>)
            : null,
      );
}

enum InterventionType { nudge, scaffold, handoff, revisit, pace }

enum Salience { low, medium, high }

enum AiCoachMode { hint, verify, explain, debug }

// ──── §4.3  Policy terms ────

/// Policy terms for audit (Math Contract §4.3).
@immutable
class PolicyTerms {
  const PolicyTerms({
    this.lambda = 0.5,
    this.mDagger = 0.6,
    this.highAssist = false,
    this.omega = 0.0,
  });

  final double lambda;
  final double mDagger;
  final bool highAssist;
  final double omega;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'lambda': lambda,
        'm_dagger': mDagger,
        'highAssist': highAssist,
        'omega': omega,
      };

  factory PolicyTerms.fromMap(Map<String, dynamic> m) {
    final PolicyTerms? parsed = PolicyTerms.tryFromMap(m);
    if (parsed == null) {
      throw const FormatException('Malformed policy terms payload.');
    }
    return parsed;
  }

  static PolicyTerms? tryFromMap(Map<String, dynamic>? m) {
    if (m == null) {
      return null;
    }
    final double? lambda = _readFiniteDouble(m, 'lambda');
    final double? mDagger = _readFiniteDouble(m, 'm_dagger');
    final bool? highAssist = m['highAssist'] is bool ? m['highAssist'] as bool : null;
    final double? omega = _readFiniteDouble(m, 'omega');
    if (lambda == null || mDagger == null || highAssist == null || omega == null) {
      return null;
    }
    return PolicyTerms(
      lambda: lambda,
      mDagger: mDagger,
      highAssist: highAssist,
      omega: omega,
    );
  }
}

// ──── §5  Teacher override / supervisory control ────

/// Supervisory control g_t (Math Contract §5).
@immutable
class SupervisoryControl {
  const SupervisoryControl({
    required this.g,
    this.uBos,
    this.uTeacher,
    this.reason,
  });

  /// 0 = BOS control, 1 = teacher override
  final int g;
  final Map<String, dynamic>? uBos;
  final Map<String, dynamic>? uTeacher;
  final String? reason;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'g': g,
        if (uBos != null) 'u_bos': uBos,
        if (uTeacher != null) 'u_teacher': uTeacher,
        if (reason != null) 'reason': reason,
      };

  factory SupervisoryControl.fromMap(Map<String, dynamic> m) {
    final SupervisoryControl? parsed = SupervisoryControl.tryFromMap(m);
    if (parsed == null) {
      throw const FormatException('Malformed supervisory control payload.');
    }
    return parsed;
  }

  static SupervisoryControl? tryFromMap(Map<String, dynamic>? m) {
    if (m == null) {
      return null;
    }
    final dynamic rawG = m['g'];
    if (rawG is! int || (rawG != 0 && rawG != 1)) {
      return null;
    }
    return SupervisoryControl(
      g: rawG,
      uBos: _asStringDynamicMap(m['u_bos']),
      uTeacher: _asStringDynamicMap(m['u_teacher']),
      reason: _readTrimmedString(m, 'reason'),
    );
  }
}

// ──── §1.3  Observation vector y_t ────

/// Feature window (Math Contract §1.3).
@immutable
class FeatureWindow {
  const FeatureWindow({
    required this.window,
    this.features = const <String, dynamic>{},
    this.yVec,
    this.quality,
  });

  final String window; // '30s' | '5m' | 'session'
  final Map<String, dynamic> features;
  final List<double>? yVec;
  final FeatureQuality? quality;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'window': window,
        'features': features,
        if (yVec != null) 'y_vec': yVec,
        if (quality != null) 'quality': quality!.toMap(),
      };

    factory FeatureWindow.fromMap(Map<String, dynamic> m) => FeatureWindow(
      window: _readTrimmedString(m, 'window') ?? 'session',
      features: _asStringDynamicMap(m['features']) ?? <String, dynamic>{},
      yVec: (m['y_vec'] as List<dynamic>?)
        ?.whereType<num>()
        .map((num e) => e.toDouble())
        .toList(),
      quality: FeatureQuality.tryFromMap(_asStringDynamicMap(m['quality'])),
      );
}

@immutable
class FeatureQuality {
  const FeatureQuality({
    this.missingness = 0.0,
    this.driftFlag = false,
    this.fusionFamiliesPresent = const <String>[],
  });

  final double missingness;
  final bool driftFlag;
  final List<String> fusionFamiliesPresent;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'missingness': missingness,
        'driftFlag': driftFlag,
        'fusionFamiliesPresent': fusionFamiliesPresent,
      };

  factory FeatureQuality.fromMap(Map<String, dynamic> m) {
    final FeatureQuality? parsed = FeatureQuality.tryFromMap(m);
    if (parsed == null) {
      throw const FormatException('Malformed feature quality payload.');
    }
    return parsed;
  }

  static FeatureQuality? tryFromMap(Map<String, dynamic>? m) {
    if (m == null) {
      return null;
    }
    final double? missingness = _readFiniteDouble(m, 'missingness');
    final bool? driftFlag = m['driftFlag'] is bool ? m['driftFlag'] as bool : null;
    final dynamic familiesValue = m['fusionFamiliesPresent'];
    if (missingness == null || driftFlag == null) {
      return null;
    }
    final List<String> fusionFamiliesPresent = familiesValue is List<dynamic>
        ? familiesValue.whereType<String>().toList(growable: false)
        : const <String>[];
    return FeatureQuality(
      missingness: missingness,
      driftFlag: driftFlag,
      fusionFamiliesPresent: fusionFamiliesPresent,
    );
  }
}

// ──── §6  Reliability risk (semantic entropy) ────

@immutable
class ReliabilityRisk {
  const ReliabilityRisk({
    this.method = 'sep',
    this.k = 0,
    this.m = 0,
    this.hSem = 0.0,
    this.riskScore = 0.0,
    this.threshold = 0.5,
  });

  final String method; // 'semantic-entropy' | 'sep'
  final int k;
  final int m;
  final double hSem;
  final double riskScore;
  final double threshold;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'method': method,
        'K': k,
        'M': m,
        'H_sem': hSem,
        'riskScore': riskScore,
        'threshold': threshold,
      };

  factory ReliabilityRisk.fromMap(Map<String, dynamic> m2) {
    final ReliabilityRisk? parsed = ReliabilityRisk.tryFromMap(m2);
    if (parsed == null) {
      throw const FormatException('Malformed reliability risk payload.');
    }
    return parsed;
  }

  static ReliabilityRisk? tryFromMap(Map<String, dynamic>? m) {
    if (m == null) {
      return null;
    }

    final double? riskScore = _readFiniteDouble(m, 'riskScore');
    final double? threshold = _readFiniteDouble(m, 'threshold');
    if (riskScore == null || threshold == null) {
      return null;
    }

    return ReliabilityRisk(
      method: m['method'] as String? ?? 'sep',
      k: (m['K'] as num?)?.toInt() ?? 0,
      m: (m['M'] as num?)?.toInt() ?? 0,
      hSem: _readFiniteDouble(m, 'H_sem') ?? 0.0,
      riskScore: riskScore,
      threshold: threshold,
    );
  }
}

// ──── §7  Autonomy risk ────

@immutable
class AutonomyRisk {
  const AutonomyRisk({
    this.signals = const <String>[],
    this.riskScore = 0.0,
    this.threshold = 0.5,
  });

  final List<String> signals; // 'rapid_submit', 'verification_gap', etc.
  final double riskScore;
  final double threshold;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'signals': signals,
        'riskScore': riskScore,
        'threshold': threshold,
      };

  factory AutonomyRisk.fromMap(Map<String, dynamic> m) {
    final AutonomyRisk? parsed = AutonomyRisk.tryFromMap(m);
    if (parsed == null) {
      throw const FormatException('Malformed autonomy risk payload.');
    }
    return parsed;
  }

  static AutonomyRisk? tryFromMap(Map<String, dynamic>? m) {
    if (m == null) {
      return null;
    }

    final double? riskScore = _readFiniteDouble(m, 'riskScore');
    final double? threshold = _readFiniteDouble(m, 'threshold');
    if (riskScore == null || threshold == null) {
      return null;
    }

    return AutonomyRisk(
      signals: ((m['signals'] as List<dynamic>?)?.cast<String>()) ?? <String>[],
      riskScore: riskScore,
      threshold: threshold,
    );
  }
}

// ──── §8  MVL Episode ────

/// MVL episode (Math Contract §8 + HOW_TO §4 endpoint 4).
@immutable
class MvlEpisode {
  const MvlEpisode({
    required this.id,
    required this.siteId,
    required this.learnerId,
    required this.sessionOccurrenceId,
    required this.triggerReason,
    this.reliabilityRisk,
    this.autonomyRisk,
    this.evidenceEventIds = const <String>[],
    this.resolution,
    this.resolvedAt,
    this.createdAt,
  });

  final String id;
  final String siteId;
  final String learnerId;
  final String sessionOccurrenceId;
  final String triggerReason;
  final ReliabilityRisk? reliabilityRisk;
  final AutonomyRisk? autonomyRisk;
  final List<String> evidenceEventIds;
  final String? resolution; // 'passed' | 'failed' | 'needs_more_evidence'
  final Timestamp? resolvedAt;
  final Timestamp? createdAt;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'siteId': siteId,
        'learnerId': learnerId,
        'sessionOccurrenceId': sessionOccurrenceId,
        'triggerReason': triggerReason,
        if (reliabilityRisk != null) 'reliability': reliabilityRisk!.toMap(),
        if (autonomyRisk != null) 'autonomy': autonomyRisk!.toMap(),
        'evidenceEventIds': evidenceEventIds,
        if (resolution != null) 'resolution': resolution,
        if (resolvedAt != null) 'resolvedAt': resolvedAt,
        'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      };

  factory MvlEpisode.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final MvlEpisode? parsed = MvlEpisode.tryFromDoc(doc);
    if (parsed == null) {
      throw const FormatException('Malformed MVL episode payload.');
    }
    return parsed;
  }

  static MvlEpisode? tryFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic>? m = doc.data();
    if (m == null) {
      return null;
    }
    final String? siteId = _readTrimmedString(m, 'siteId');
    final String? learnerId = _readTrimmedString(m, 'learnerId');
    final String? sessionOccurrenceId =
        _readTrimmedString(m, 'sessionOccurrenceId');
    final String? triggerReason = _readTrimmedString(m, 'triggerReason');
    if (siteId == null ||
        learnerId == null ||
        sessionOccurrenceId == null ||
        triggerReason == null) {
      return null;
    }
    return MvlEpisode(
      id: doc.id,
      siteId: siteId,
      learnerId: learnerId,
      sessionOccurrenceId: sessionOccurrenceId,
      triggerReason: triggerReason,
      reliabilityRisk: ReliabilityRisk.tryFromMap(
        _asStringDynamicMap(m['reliability']),
      ),
      autonomyRisk: AutonomyRisk.tryFromMap(
        _asStringDynamicMap(m['autonomy']),
      ),
      evidenceEventIds:
          ((m['evidenceEventIds'] as List<dynamic>?)?.cast<String>()) ??
              <String>[],
      resolution: m['resolution'] as String?,
      resolvedAt: m['resolvedAt'] as Timestamp?,
      createdAt: m['createdAt'] as Timestamp?,
    );
  }
}

// ──── BOS Event Envelope (Event Schema) ────

/// Context mode: whether the learner event occurs in-class or during homework.
enum ContextMode {
  inClass('in_class'),
  homework('homework'),
  unknown('unknown');

  const ContextMode(this.code);
  final String code;

  static ContextMode fromString(String s) {
    switch (s) {
      case 'in_class':
        return ContextMode.inClass;
      case 'homework':
        return ContextMode.homework;
      default:
        return ContextMode.unknown;
    }
  }
}

/// Client metadata attached to every event for reproducibility.
@immutable
class ClientInfo {
  const ClientInfo({
    required this.appVersion,
    required this.platform,
    this.buildNumber,
  });

  final String appVersion;
  final String platform; // 'ios', 'android', 'web', 'macos', 'windows'
  final String? buildNumber;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'appVersion': appVersion,
        'platform': platform,
        if (buildNumber != null) 'buildNumber': buildNumber,
      };
}

/// Current app-level client info (set once at startup).
ClientInfo? _globalClientInfo;

/// Set the global client info at app startup.
void setBosClientInfo(ClientInfo info) => _globalClientInfo = info;

/// Standardized BOS event envelope (Vibe Master §D / research-grade).
///
/// Required fields for research export:
/// - [eventId]: Client-generated UUID (unique per event)
/// - [schemaVersion]: Envelope schema version for forward compatibility
/// - [actorIdPseudo]: Pseudonymised learner ID (derived from actorId + site salt)
/// - [contextMode]: Whether event is in_class or homework
/// - [client]: App version + platform metadata
@immutable
class BosEvent {
  BosEvent({
    required this.eventType,
    required this.siteId,
    required this.actorId,
    required this.actorRole,
    required this.gradeBand,
    this.sessionOccurrenceId,
    this.missionId,
    this.checkpointId,
    this.payload = const <String, dynamic>{},
    this.contextMode = ContextMode.unknown,
    this.actorIdPseudo,
    this.assignmentId,
    this.lessonId,
    String? eventId,
  }) : eventId = eventId ?? _uuid.v4();

  /// Client-generated UUID — unique per event (research traceability).
  final String eventId;

  /// Envelope schema version for forward-compatible parsing.
  static const String schemaVersion = '2.0.0';

  final String eventType;
  final String siteId;
  final String actorId;
  final String actorRole;
  final GradeBand gradeBand;
  final String? sessionOccurrenceId;
  final String? missionId;
  final String? checkpointId;
  final Map<String, dynamic> payload;

  /// Whether event occurred in_class or during homework.
  final ContextMode contextMode;

  /// Pseudonymised actor ID for research export (generated server-side or via site-salt hash).
  final String? actorIdPseudo;

  /// Optional assignment ID for research linking.
  final String? assignmentId;

  /// Optional lesson ID for research linking.
  final String? lessonId;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'eventId': eventId,
        'schemaVersion': schemaVersion,
        'eventType': eventType,
        'siteId': siteId,
        'actorId': actorId,
        'actorRole': actorRole,
        'gradeBand': gradeBand.code,
        'contextMode': contextMode.code,
        if (actorIdPseudo != null) 'actorIdPseudo': actorIdPseudo,
        if (sessionOccurrenceId != null)
          'sessionOccurrenceId': sessionOccurrenceId,
        if (missionId != null) 'missionId': missionId,
        if (checkpointId != null) 'checkpointId': checkpointId,
        if (assignmentId != null) 'assignmentId': assignmentId,
        if (lessonId != null) 'lessonId': lessonId,
        'payload': payload,
        if (_globalClientInfo != null) 'client': _globalClientInfo!.toMap(),
        'timestamp': FieldValue.serverTimestamp(),
      };
}

// ──── §4.2  Grade-band policy thresholds ────

/// M_DAGGER thresholds per grade band (Math Contract §4.2).
class GradeBandPolicy {
  GradeBandPolicy._();

  static const Map<GradeBand, double> mDagger = <GradeBand, double>{
    GradeBand.g1_3: 0.55,
    GradeBand.g4_6: 0.60,
    GradeBand.g7_9: 0.65,
    GradeBand.g10_12: 0.70,
  };

  /// Returns true if the intervention is "high assist"
  static bool isHighAssist(BosIntervention intervention) {
    if (intervention.salience == Salience.high) return true;
    if (intervention.type == InterventionType.scaffold &&
        intervention.mode == AiCoachMode.hint) {
      return true;
    }
    return false;
  }

  /// Compute autonomy cost Ω(u_t, x_t) per Math Contract §4.2
  static double autonomyCost({
    required BosIntervention intervention,
    required XHat xHat,
    required GradeBand gradeBand,
  }) {
    if (!isHighAssist(intervention)) return 0.0;
    final double mDaggerVal = mDagger[gradeBand] ?? 0.6;
    final double gap = mDaggerVal - xHat.integrity;
    return gap > 0 ? gap : 0.0;
  }
}

// ──── AI Coach Request/Response ────

/// AI Coach request (HOW_TO §5).
@immutable
class AiCoachRequest {
  const AiCoachRequest({
    required this.siteId,
    required this.learnerId,
    required this.gradeBand,
    required this.mode,
    this.sessionOccurrenceId,
    this.missionId,
    this.checkpointId,
    this.conceptTags = const <String>[],
    this.learnerState,
    this.recentEventsRef = const <String>[],
    this.studentInput,
    this.personaInstructions,
  });

  final String siteId;
  final String learnerId;
  final GradeBand gradeBand;
  final AiCoachMode mode;
  final String? sessionOccurrenceId;
  final String? missionId;
  final String? checkpointId;
  final List<String> conceptTags;
  final XHat? learnerState;
  final List<String> recentEventsRef;
  final String? studentInput;
  final String? personaInstructions;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'siteId': siteId,
        'learnerId': learnerId,
        'gradeBand': gradeBand.code,
        'mode': mode.name,
        if (sessionOccurrenceId != null)
          'sessionOccurrenceId': sessionOccurrenceId,
        if (missionId != null) 'missionId': missionId,
        if (checkpointId != null) 'checkpointId': checkpointId,
        'conceptTags': conceptTags,
        if (learnerState != null) 'learnerState': learnerState!.toMap(),
        'recentEventsRef': recentEventsRef,
        'context': <String, dynamic>{
          if (missionId != null) 'missionId': missionId,
          if (checkpointId != null) 'checkpointId': checkpointId,
          'conceptTags': conceptTags,
          if (learnerState != null) 'learnerState': learnerState!.toMap(),
          'recentEventsRef': recentEventsRef,
        },
        if (studentInput != null) 'studentInput': studentInput,
        if (personaInstructions != null)
          'personaInstructions': personaInstructions,
      };
}

@immutable
class AiCoachResponse {
  const AiCoachResponse({
    required this.message,
    required this.mode,
    this.requiresExplainBack = false,
    this.suggestedNextSteps = const <String>[],
    this.learnerState,
    this.reliabilityRisk,
    this.autonomyRisk,
    this.mvlGateActive = false,
    this.mvlEpisodeId,
    this.mvlReason,
    this.version,
    this.aiHelpOpenedEventId,
    this.traceId,
    this.policyVersion,
    this.safetyOutcome,
    this.safetyReasonCode,
    this.modelVersion,
    this.voiceAudioUrl,
    this.voiceAvailable = false,
  });

  final String message;
  final AiCoachMode mode;
  final bool requiresExplainBack;
  final List<String> suggestedNextSteps;
  final XHat? learnerState;
  final ReliabilityRisk? reliabilityRisk;
  final AutonomyRisk? autonomyRisk;
  final bool mvlGateActive;
  final String? mvlEpisodeId;
  final String? mvlReason;
  final String? version;
  final String? aiHelpOpenedEventId;
  final String? traceId;
  final String? policyVersion;
  final String? safetyOutcome;
  final String? safetyReasonCode;
  final String? modelVersion;
  final String? voiceAudioUrl;
  final bool voiceAvailable;

  AiCoachResponse copyWith({
    String? message,
    AiCoachMode? mode,
    bool? requiresExplainBack,
    List<String>? suggestedNextSteps,
    XHat? learnerState,
    ReliabilityRisk? reliabilityRisk,
    AutonomyRisk? autonomyRisk,
    bool? mvlGateActive,
    String? mvlEpisodeId,
    String? mvlReason,
    String? version,
    String? aiHelpOpenedEventId,
    String? traceId,
    String? policyVersion,
    String? safetyOutcome,
    String? safetyReasonCode,
    String? modelVersion,
    String? voiceAudioUrl,
    bool? voiceAvailable,
  }) {
    return AiCoachResponse(
      message: message ?? this.message,
      mode: mode ?? this.mode,
      requiresExplainBack: requiresExplainBack ?? this.requiresExplainBack,
      suggestedNextSteps: suggestedNextSteps ?? this.suggestedNextSteps,
      learnerState: learnerState ?? this.learnerState,
      reliabilityRisk: reliabilityRisk ?? this.reliabilityRisk,
      autonomyRisk: autonomyRisk ?? this.autonomyRisk,
      mvlGateActive: mvlGateActive ?? this.mvlGateActive,
      mvlEpisodeId: mvlEpisodeId ?? this.mvlEpisodeId,
      mvlReason: mvlReason ?? this.mvlReason,
      version: version ?? this.version,
      aiHelpOpenedEventId: aiHelpOpenedEventId ?? this.aiHelpOpenedEventId,
      traceId: traceId ?? this.traceId,
      policyVersion: policyVersion ?? this.policyVersion,
      safetyOutcome: safetyOutcome ?? this.safetyOutcome,
      safetyReasonCode: safetyReasonCode ?? this.safetyReasonCode,
      modelVersion: modelVersion ?? this.modelVersion,
      voiceAudioUrl: voiceAudioUrl ?? this.voiceAudioUrl,
      voiceAvailable: voiceAvailable ?? this.voiceAvailable,
    );
  }

  factory AiCoachResponse.fromMap(Map<String, dynamic> m) {
    final Map<String, dynamic>? risk = m['risk'] as Map<String, dynamic>?;
    final Map<String, dynamic>? mvl = m['mvl'] as Map<String, dynamic>?;
    final Map<String, dynamic>? meta = m['meta'] as Map<String, dynamic>?;
    final Map<String, dynamic>? metadata =
        m['metadata'] as Map<String, dynamic>?;
    final Map<String, dynamic>? tts = m['tts'] as Map<String, dynamic>?;

    return AiCoachResponse(
      message: m['message'] as String? ?? '',
      mode: AiCoachMode.values.firstWhere(
        (AiCoachMode e) => e.name == m['mode'],
        orElse: () => AiCoachMode.hint,
      ),
      requiresExplainBack: m['requiresExplainBack'] as bool? ?? false,
      suggestedNextSteps:
          ((m['suggestedNextSteps'] as List<dynamic>?)?.cast<String>()) ??
              <String>[],
      learnerState: m['learnerState'] != null
          ? XHat.fromMap(m['learnerState'] as Map<String, dynamic>)
          : null,
      reliabilityRisk: risk != null && risk['reliability'] != null
          ? ReliabilityRisk.tryFromMap(
              _asStringDynamicMap(risk['reliability']),
            )
          : null,
      autonomyRisk: risk != null && risk['autonomy'] != null
          ? AutonomyRisk.tryFromMap(
              _asStringDynamicMap(risk['autonomy']),
            )
          : null,
      mvlGateActive: mvl?['gateActive'] as bool? ?? false,
      mvlEpisodeId: mvl?['episodeId'] as String?,
      mvlReason: mvl?['reason'] as String?,
      version: meta != null ? _readTrimmedString(meta, 'version') : null,
      aiHelpOpenedEventId: meta?['aiHelpOpenedEventId'] as String?,
      traceId: (metadata?['traceId'] ?? meta?['traceId']) as String?,
      policyVersion: metadata?['policyVersion'] as String?,
      safetyOutcome: metadata?['safetyOutcome'] as String?,
      safetyReasonCode: metadata?['safetyReasonCode'] as String?,
      modelVersion: metadata?['modelVersion'] as String?,
      voiceAudioUrl: tts?['audioUrl'] as String?,
      voiceAvailable: tts?['available'] as bool? ?? false,
    );
  }
}
