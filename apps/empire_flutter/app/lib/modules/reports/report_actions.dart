import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/export_service.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';

class ReportActions {
  const ReportActions._();

  static const List<String> passportReportProvenanceSignals = <String>[
    'evidence',
    'growth',
    'portfolio',
    'mission',
    'proof',
    'aiDisclosure',
    'rubric',
    'reviewer',
    'verificationPrompt',
  ];

  static const List<String> familySummaryProvenanceSignals = <String>[
    'evidence',
    'growth',
    'portfolio',
    'proof',
    'aiDisclosure',
    'rubric',
    'reviewer',
    'verificationPrompt',
  ];

  static const List<String> portfolioReportProvenanceSignals = <String>[
    'evidence',
    'portfolio',
    'mission',
    'proof',
    'aiDisclosure',
    'rubric',
    'reviewer',
    'verificationPrompt',
  ];

  static const Map<String, Object> familyReportSharePolicy = <String, Object>{
    'audience': 'guardian',
    'visibility': 'family',
    'requiresEvidenceProvenance': true,
    'requiresGuardianContext': true,
    'allowsExternalSharing': false,
    'includesLearnerIdentifiers': true,
  };

  static const Map<String, Object> learnerPrivateReportSharePolicy =
      <String, Object>{
    'audience': 'learner',
    'visibility': 'private',
    'requiresEvidenceProvenance': true,
    'requiresGuardianContext': false,
    'allowsExternalSharing': false,
    'includesLearnerIdentifiers': true,
  };

  static Map<String, dynamic> reportProvenanceMetadata(
    String content, {
    Iterable<String> expectedSignals = const <String>[],
    Map<String, Object?> sharePolicy = const <String, Object?>{},
  }) {
    final String normalized = content.toLowerCase();
    final bool hasEvidence = _containsAny(normalized, const <String>[
      'evidence id',
      'evidence record',
      'evidence link',
      'linked evidence',
    ]);
    final bool hasGrowth = _containsAny(normalized, const <String>[
      'growth provenance',
      'growth timeline',
      'growth event',
      'recorded growth',
    ]);
    final bool hasPortfolio = _containsAny(normalized, const <String>[
      'portfolio evidence',
      'portfolio item',
      'portfolio artifact',
      'portfolio link',
    ]);
    final bool hasMission = _containsAny(normalized, const <String>[
      'mission attempt id',
      'mission attempt ids',
      'mission-linked',
      'mission link',
    ]);
    final bool hasProof = normalized.contains('proof of learning') ||
        normalized.contains('proof verified') ||
        normalized.contains('proof status') ||
        normalized.contains('proof detail') ||
        normalized.contains(' proof ');
    final bool hasAiDisclosure = normalized.contains('ai disclosure') ||
        normalized.contains('ai-assisted') ||
        normalized.contains('ai use') ||
        normalized.contains('learner ai');
    final bool hasRubric = normalized.contains('rubric score') ||
        normalized.contains('rubric level') ||
        normalized.contains('rubric ');
    final bool hasReviewer = normalized.contains('reviewed by') ||
        normalized.contains('educator review') ||
        normalized.contains('educator verifier');
    final bool hasVerificationPrompt =
        normalized.contains('verification prompt') ||
            normalized.contains('verify next') ||
            normalized.contains('next verification prompt');
    final Map<String, bool> signalPresence = <String, bool>{
      'evidence': hasEvidence,
      'growth': hasGrowth,
      'portfolio': hasPortfolio,
      'mission': hasMission,
      'proof': hasProof,
      'aiDisclosure': hasAiDisclosure,
      'rubric': hasRubric,
      'reviewer': hasReviewer,
      'verificationPrompt': hasVerificationPrompt,
    };
    final int signalCount =
        signalPresence.values.where((bool value) => value).length;
    final List<String> expected = expectedSignals
        .where((String signal) => signalPresence.containsKey(signal))
        .toSet()
        .toList(growable: false);
    final List<String> missing = expected
        .where((String signal) => signalPresence[signal] != true)
        .toList(growable: false);
    final bool sharePolicyDeclared = sharePolicy.isNotEmpty;
    final List<String> missingDeliveryFields =
        expected.isNotEmpty && !sharePolicyDeclared
            ? <String>['sharePolicy']
            : <String>[];
    final String visibility =
        sharePolicy['visibility'] as String? ?? 'unspecified';
    final bool allowsExternalSharing =
        sharePolicy['allowsExternalSharing'] == true;

    return <String, dynamic>{
      'report_provenance_signal_count': signalCount,
      'report_provenance_contract_required': expected.isNotEmpty,
      'report_has_evidence_signal': hasEvidence,
      'report_has_growth_signal': hasGrowth,
      'report_has_portfolio_signal': hasPortfolio,
      'report_has_mission_signal': hasMission,
      'report_has_proof_signal': hasProof,
      'report_has_ai_disclosure_signal': hasAiDisclosure,
      'report_has_rubric_signal': hasRubric,
      'report_has_reviewer_signal': hasReviewer,
      'report_has_verification_prompt_signal': hasVerificationPrompt,
      'report_expected_provenance_signals': expected,
      'report_missing_provenance_signals': missing,
      'report_meets_provenance_contract': missing.isEmpty,
      'report_share_policy_declared': sharePolicyDeclared,
      'report_share_audience': sharePolicy['audience'] ?? 'unspecified',
      'report_share_visibility': visibility,
      'report_share_requires_evidence_provenance':
          sharePolicy['requiresEvidenceProvenance'] == true,
      'report_share_requires_guardian_context':
          sharePolicy['requiresGuardianContext'] == true,
      'report_share_allows_external_sharing': allowsExternalSharing,
      'report_share_includes_learner_identifiers':
          sharePolicy['includesLearnerIdentifiers'] == true,
      'report_share_family_safe': sharePolicyDeclared &&
          !allowsExternalSharing &&
          visibility != 'external' &&
          visibility != 'public',
      'report_missing_delivery_contract_fields': missingDeliveryFields,
      'report_meets_delivery_contract':
          missing.isEmpty && missingDeliveryFields.isEmpty,
    };
  }

  static Map<String, dynamic> assertReportProvenanceContract(
    String content, {
    required Iterable<String> expectedSignals,
    String reportName = 'report',
  }) {
    final Map<String, dynamic> metadata = reportProvenanceMetadata(
      content,
      expectedSignals: expectedSignals,
    );
    if (metadata['report_meets_provenance_contract'] != true) {
      final Object? missing = metadata['report_missing_provenance_signals'];
      throw StateError(
        '$reportName is missing report provenance signals: $missing',
      );
    }
    return metadata;
  }

  static bool _containsAny(String normalized, List<String> terms) {
    return terms.any(normalized.contains);
  }

  static Future<void> exportText({
    required ScaffoldMessengerState messenger,
    required bool Function() isMounted,
    required String fileName,
    required String content,
    required String module,
    required String surface,
    required String copiedEventName,
    required String successMessage,
    required String copiedMessage,
    required String errorMessage,
    required String unsupportedLogMessage,
    String? learnerId,
    String? role,
    String? siteId,
    Iterable<String> expectedProvenanceSignals = const <String>[],
    bool enforceProvenanceContract = false,
    Map<String, Object?> sharePolicy = const <String, Object?>{},
    Map<String, dynamic> metadata = const <String, dynamic>{},
    Future<void> Function()? onDownloaded,
    Future<void> Function()? onCopied,
    bool showSuccessSnackBar = true,
  }) async {
    final Map<String, dynamic> provenanceMetadata = reportProvenanceMetadata(
      content,
      expectedSignals: expectedProvenanceSignals,
      sharePolicy: sharePolicy,
    );
    if (enforceProvenanceContract &&
        provenanceMetadata['report_meets_delivery_contract'] != true) {
      final bool missingSharePolicy =
          provenanceMetadata['report_share_policy_declared'] != true;
      TelemetryService.instance.logEvent(
        event: 'report.delivery_blocked',
        role: role,
        siteId: siteId,
        metadata: <String, dynamic>{
          'module': module,
          'surface': surface,
          if (learnerId != null) 'learner_id': learnerId,
          'file_name': fileName,
          ...provenanceMetadata,
          ...metadata,
          'report_action': 'export_text',
          'report_delivery': 'contract-failed',
          'report_block_reason': missingSharePolicy
              ? 'missing_share_policy'
              : 'missing_provenance',
        },
      );
      if (isMounted()) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              missingSharePolicy
                  ? 'Unable to export because this report is missing a sharing safety policy.'
                  : 'Unable to export because this report is missing evidence provenance.',
            ),
            backgroundColor: ScholesaColors.error,
          ),
        );
      }
      return;
    }

    try {
      final String? savedLocation = await ExportService.instance.saveTextFile(
        fileName: fileName,
        content: content,
      );
      if (!isMounted() || savedLocation == null) {
        return;
      }
      TelemetryService.instance.logEvent(
        event: 'export.downloaded',
        role: role,
        siteId: siteId,
        metadata: <String, dynamic>{
          'module': module,
          'surface': surface,
          if (learnerId != null) 'learner_id': learnerId,
          'file_name': fileName,
          ...provenanceMetadata,
          ...metadata,
        },
      );
      await onDownloaded?.call();
      if (showSuccessSnackBar) {
        messenger.showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      }
    } on UnsupportedError catch (error) {
      debugPrint('$unsupportedLogMessage: $error');
      await Clipboard.setData(ClipboardData(text: content));
      TelemetryService.instance.logEvent(
        event: copiedEventName,
        role: role,
        siteId: siteId,
        metadata: <String, dynamic>{
          'module': module,
          'surface': surface,
          if (learnerId != null) 'learner_id': learnerId,
          'file_name': fileName,
          'fallback': 'clipboard',
          ...provenanceMetadata,
          ...metadata,
        },
      );
      await onCopied?.call();
      if (!isMounted()) {
        return;
      }
      if (showSuccessSnackBar) {
        messenger.showSnackBar(
          SnackBar(content: Text(copiedMessage)),
        );
      }
    } catch (_) {
      if (!isMounted()) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: ScholesaColors.error,
        ),
      );
    }
  }

  static Future<void> shareToClipboard({
    required ScaffoldMessengerState messenger,
    required bool Function() isMounted,
    required String content,
    required String module,
    required String surface,
    required String cta,
    required String successMessage,
    required String errorMessage,
    String? learnerId,
    String? role,
    String? siteId,
    Iterable<String> expectedProvenanceSignals = const <String>[],
    bool enforceProvenanceContract = false,
    Map<String, Object?> sharePolicy = const <String, Object?>{},
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    final Map<String, dynamic> provenanceMetadata = reportProvenanceMetadata(
      content,
      expectedSignals: expectedProvenanceSignals,
      sharePolicy: sharePolicy,
    );
    if (enforceProvenanceContract &&
        provenanceMetadata['report_meets_delivery_contract'] != true) {
      final bool missingSharePolicy =
          provenanceMetadata['report_share_policy_declared'] != true;
      TelemetryService.instance.logEvent(
        event: 'report.delivery_blocked',
        role: role,
        siteId: siteId,
        metadata: <String, dynamic>{
          'module': module,
          'surface': surface,
          'cta': cta,
          if (learnerId != null) 'learner_id': learnerId,
          ...provenanceMetadata,
          ...metadata,
          'report_action': 'share',
          'report_delivery': 'contract-failed',
          'report_block_reason': missingSharePolicy
              ? 'missing_share_policy'
              : 'missing_provenance',
        },
      );
      if (isMounted()) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              missingSharePolicy
                  ? 'Unable to share because this report is missing a sharing safety policy.'
                  : 'Unable to share because this report is missing evidence provenance.',
            ),
            backgroundColor: ScholesaColors.error,
          ),
        );
      }
      return;
    }

    try {
      await Clipboard.setData(ClipboardData(text: content));
      TelemetryService.instance.logEvent(
        event: 'cta.clicked',
        role: role,
        siteId: siteId,
        metadata: <String, dynamic>{
          'cta': cta,
          if (learnerId != null) 'learner_id': learnerId,
          ...provenanceMetadata,
          ...metadata,
        },
      );
      TelemetryService.instance.logEvent(
        event: 'notification.requested',
        role: role,
        siteId: siteId,
        metadata: <String, dynamic>{
          'module': module,
          'surface': surface,
          if (learnerId != null) 'learner_id': learnerId,
          'delivery': 'clipboard',
          ...provenanceMetadata,
          ...metadata,
        },
      );
      if (!isMounted()) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (_) {
      if (!isMounted()) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: ScholesaColors.error,
        ),
      );
    }
  }
}
