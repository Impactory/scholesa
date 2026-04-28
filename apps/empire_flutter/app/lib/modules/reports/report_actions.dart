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

  static Map<String, dynamic> reportProvenanceMetadata(
    String content, {
    Iterable<String> expectedSignals = const <String>[],
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

    return <String, dynamic>{
      'report_provenance_signal_count': signalCount,
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
    };
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
    Map<String, dynamic> metadata = const <String, dynamic>{},
    Future<void> Function()? onDownloaded,
    Future<void> Function()? onCopied,
    bool showSuccessSnackBar = true,
  }) async {
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
          ...reportProvenanceMetadata(
            content,
            expectedSignals: expectedProvenanceSignals,
          ),
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
          ...reportProvenanceMetadata(
            content,
            expectedSignals: expectedProvenanceSignals,
          ),
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
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    try {
      await Clipboard.setData(ClipboardData(text: content));
      TelemetryService.instance.logEvent(
        event: 'cta.clicked',
        role: role,
        siteId: siteId,
        metadata: <String, dynamic>{
          'cta': cta,
          if (learnerId != null) 'learner_id': learnerId,
          ...reportProvenanceMetadata(
            content,
            expectedSignals: expectedProvenanceSignals,
          ),
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
          ...reportProvenanceMetadata(
            content,
            expectedSignals: expectedProvenanceSignals,
          ),
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
