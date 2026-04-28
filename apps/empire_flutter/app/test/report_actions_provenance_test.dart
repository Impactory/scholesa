import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/modules/reports/report_actions.dart';
import 'package:scholesa_app/services/telemetry_service.dart';

const String _richEvidenceReport = '''
Family Dashboard Summary
Recent growth provenance:
- Evidence-backed reasoning • Proficient • rubric 3/4 • reviewed by Coach Rivera • 1 evidence records linked • 1 portfolio artifacts linked • proof verified
Featured portfolio evidence:
- Prototype Evidence • Reviewed • 1 evidence records linked • mission-linked • proof verified • reviewed by Coach Rivera • rubric 3/4
AI Disclosure: Learner declared no AI support used
Evidence IDs: ev-1
Mission Attempt ID: attempt-1
Verification Prompt: Explain the prototype tradeoff.
''';

void main() {
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('report provenance metadata detects evidence-chain signals', () {
    final Map<String, dynamic> metadata =
        ReportActions.reportProvenanceMetadata(
      _richEvidenceReport,
      expectedSignals: ReportActions.passportReportProvenanceSignals,
    );

    expect(metadata['report_provenance_signal_count'], 9);
    expect(metadata['report_has_evidence_signal'], isTrue);
    expect(metadata['report_has_growth_signal'], isTrue);
    expect(metadata['report_has_portfolio_signal'], isTrue);
    expect(metadata['report_has_mission_signal'], isTrue);
    expect(metadata['report_has_proof_signal'], isTrue);
    expect(metadata['report_has_ai_disclosure_signal'], isTrue);
    expect(metadata['report_has_rubric_signal'], isTrue);
    expect(metadata['report_has_reviewer_signal'], isTrue);
    expect(metadata['report_has_verification_prompt_signal'], isTrue);
    expect(metadata['report_expected_provenance_signals'],
        ReportActions.passportReportProvenanceSignals);
    expect(metadata['report_missing_provenance_signals'], isEmpty);
    expect(metadata['report_meets_provenance_contract'], isTrue);
  });

  test('report provenance metadata exposes missing required signals', () {
    final Map<String, dynamic> metadata =
        ReportActions.reportProvenanceMetadata(
      'Family summary\nReviewed evidence: 1 evidence record',
      expectedSignals: ReportActions.familySummaryProvenanceSignals,
    );

    expect(metadata['report_has_evidence_signal'], isTrue);
    expect(metadata['report_meets_provenance_contract'], isFalse);
    expect(
      metadata['report_missing_provenance_signals'],
      containsAll(<String>[
        'growth',
        'portfolio',
        'proof',
        'aiDisclosure',
        'rubric',
        'reviewer',
        'verificationPrompt',
      ]),
    );
  });

  test('report provenance metadata stays quiet for operational exports', () {
    final Map<String, dynamic> metadata =
        ReportActions.reportProvenanceMetadata(
      'Billing export\nInvoice total: 100\nStatus: Paid',
    );

    expect(metadata['report_provenance_signal_count'], 0);
    expect(metadata['report_has_evidence_signal'], isFalse);
    expect(metadata['report_has_growth_signal'], isFalse);
    expect(metadata['report_has_portfolio_signal'], isFalse);
    expect(metadata['report_has_mission_signal'], isFalse);
  });

  testWidgets('clipboard report telemetry includes provenance signal metadata',
      (WidgetTester tester) async {
    final List<Map<String, dynamic>> events = <Map<String, dynamic>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async => null,
    );

    late ScaffoldMessengerState messenger;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              messenger = ScaffoldMessenger.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    await TelemetryService.runWithDispatcher(
      (Map<String, dynamic> payload) async {
        events.add(payload);
      },
      () async {
        await ReportActions.shareToClipboard(
          messenger: messenger,
          isMounted: () => true,
          content: _richEvidenceReport,
          module: 'parent_summary',
          surface: 'family_dashboard',
          cta: 'parent_summary_share_family_summary',
          successMessage: 'Copied.',
          errorMessage: 'Unable to copy.',
          learnerId: 'learner-1',
          expectedProvenanceSignals:
              ReportActions.passportReportProvenanceSignals,
        );
      },
    );

    final Map<String, dynamic> ctaEvent = events.firstWhere(
      (Map<String, dynamic> payload) => payload['event'] == 'cta.clicked',
    );
    final Map<String, dynamic> ctaMetadata =
        ctaEvent['metadata'] as Map<String, dynamic>;
    expect(ctaMetadata['report_provenance_signal_count'], 9);
    expect(ctaMetadata['report_has_evidence_signal'], isTrue);
    expect(ctaMetadata['report_has_portfolio_signal'], isTrue);
    expect(ctaMetadata['report_has_mission_signal'], isTrue);
    expect(ctaMetadata['report_has_verification_prompt_signal'], isTrue);
    expect(ctaMetadata['report_meets_provenance_contract'], isTrue);
    expect(ctaMetadata['report_missing_provenance_signals'], isEmpty);

    final Map<String, dynamic> notificationEvent = events.firstWhere(
      (Map<String, dynamic> payload) =>
          payload['event'] == 'notification.requested',
    );
    final Map<String, dynamic> notificationMetadata =
        notificationEvent['metadata'] as Map<String, dynamic>;
    expect(notificationMetadata['module'], 'parent_summary');
    expect(notificationMetadata['surface'], 'family_dashboard');
    expect(notificationMetadata['report_has_growth_signal'], isTrue);
    expect(notificationMetadata['report_has_ai_disclosure_signal'], isTrue);
  });
}
