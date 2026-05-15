import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/modules/reports/report_actions.dart';
import 'package:scholesa_app/services/export_service.dart';
import 'package:scholesa_app/services/report_delivery_audit_service.dart';
import 'package:scholesa_app/services/report_share_request_service.dart';
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
    ExportService.instance.debugSaveTextFile = null;
  });

  test('report provenance metadata detects evidence-chain signals', () {
    final Map<String, dynamic> metadata =
        ReportActions.reportProvenanceMetadata(
      _richEvidenceReport,
      expectedSignals: ReportActions.passportReportProvenanceSignals,
      sharePolicy: ReportActions.familyReportSharePolicy,
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
    expect(metadata['report_provenance_contract_required'], isTrue);
    expect(metadata['report_share_policy_declared'], isTrue);
    expect(metadata['report_share_audience'], 'guardian');
    expect(metadata['report_share_visibility'], 'family');
    expect(metadata['report_share_requires_guardian_context'], isTrue);
    expect(metadata['report_share_family_safe'], isTrue);
    expect(metadata['report_missing_delivery_contract_fields'], isEmpty);
    expect(metadata['report_meets_delivery_contract'], isTrue);
  });

  test('report provenance metadata exposes missing required signals', () {
    final Map<String, dynamic> metadata =
        ReportActions.reportProvenanceMetadata(
      'Family summary\nReviewed evidence: 1 evidence record',
      expectedSignals: ReportActions.familySummaryProvenanceSignals,
    );

    expect(metadata['report_has_evidence_signal'], isTrue);
    expect(metadata['report_meets_provenance_contract'], isFalse);
    expect(metadata['report_provenance_contract_required'], isTrue);
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
    expect(metadata['report_provenance_contract_required'], isFalse);
    expect(metadata['report_share_policy_declared'], isFalse);
    expect(metadata['report_meets_delivery_contract'], isTrue);
  });

  test('report provenance contract assertion supports release gates', () {
    expect(
      () => ReportActions.assertReportProvenanceContract(
        _richEvidenceReport,
        expectedSignals: ReportActions.passportReportProvenanceSignals,
        reportName: 'learner passport',
      ),
      returnsNormally,
    );

    expect(
      () => ReportActions.assertReportProvenanceContract(
        'Family summary\nReviewed evidence: 1 evidence record',
        expectedSignals: ReportActions.familySummaryProvenanceSignals,
        reportName: 'weak family summary',
      ),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message,
          'message',
          contains('weak family summary is missing report provenance signals'),
        ),
      ),
    );
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
          sharePolicy: ReportActions.familyReportSharePolicy,
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
    expect(ctaMetadata['report_share_audience'], 'guardian');
    expect(ctaMetadata['report_share_visibility'], 'family');
    expect(ctaMetadata['report_share_family_safe'], isTrue);
    expect(ctaMetadata['report_meets_delivery_contract'], isTrue);
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

  testWidgets('clipboard report delivery writes durable audit payload',
      (WidgetTester tester) async {
    final List<Map<String, dynamic>> auditCalls = <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> shareRequestCalls =
        <Map<String, dynamic>>[];
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

    await ReportShareRequestService.runWithCallableInvoker(
      (String callableName, Map<String, dynamic> payload) async {
        shareRequestCalls.add(<String, dynamic>{
          'callableName': callableName,
          'payload': payload,
        });
        return <String, dynamic>{'id': 'share-request-1'};
      },
      () => ReportDeliveryAuditService.runWithCallableInvoker(
        (String callableName, Map<String, dynamic> payload) async {
          auditCalls.add(<String, dynamic>{
            'callableName': callableName,
            'payload': payload,
          });
        },
        () => TelemetryService.runWithDispatcher(
          (_) async {},
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
              role: 'parent',
              siteId: 'site-1',
              expectedProvenanceSignals:
                  ReportActions.passportReportProvenanceSignals,
              enforceProvenanceContract: true,
              sharePolicy: ReportActions.familyReportSharePolicy,
            );
            await tester.pump();
            await tester.pump();
          },
        ),
      ),
    );

    expect(shareRequestCalls, hasLength(1));
    expect(
      shareRequestCalls.single['callableName'],
      'createReportShareRequest',
    );
    final Map<String, dynamic> sharePayload =
        shareRequestCalls.single['payload'] as Map<String, dynamic>;
    expect(sharePayload['siteId'], 'site-1');
    expect(sharePayload['learnerId'], 'learner-1');
    expect(sharePayload['reportAction'], 'share');
    expect(sharePayload['reportDelivery'], 'copied');
    expect(sharePayload['audience'], 'guardian');
    expect(sharePayload['visibility'], 'family');
    expect(auditCalls, hasLength(1));
    expect(auditCalls.single['callableName'], 'recordReportDeliveryAudit');
    final Map<String, dynamic> payload =
        auditCalls.single['payload'] as Map<String, dynamic>;
    expect(payload['siteId'], 'site-1');
    expect(payload['learnerId'], 'learner-1');
    expect(payload['reportAction'], 'share');
    expect(payload['reportDelivery'], 'copied');
    expect(payload['reportBlockReason'], isNull);
    expect(payload['shareRequestId'], 'share-request-1');
    expect(payload['module'], 'parent_summary');
    expect(payload['surface'], 'family_dashboard');
    expect(payload['cta'], 'parent_summary_share_family_summary');
    final Map<String, dynamic> metadata =
        payload['metadata'] as Map<String, dynamic>;
    expect(metadata['report_share_policy_declared'], isTrue);
    expect(metadata['report_meets_delivery_contract'], isTrue);
    expect(metadata['report_has_verification_prompt_signal'], isTrue);
  });

  testWidgets('enforced provenance contract blocks weak report delivery',
      (WidgetTester tester) async {
    final List<Map<String, dynamic>> events = <Map<String, dynamic>>[];
    int clipboardWrites = 0;
    int exportAttempts = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          clipboardWrites += 1;
        }
        return null;
      },
    );
    ExportService.instance.debugSaveTextFile = ({
      required String fileName,
      required String content,
      required String mimeType,
    }) async {
      exportAttempts += 1;
      return '/tmp/$fileName';
    };

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
          content: 'Family summary\nReviewed evidence: 1 evidence record',
          module: 'parent_summary',
          surface: 'family_dashboard',
          cta: 'parent_summary_share_family_summary',
          successMessage: 'Copied.',
          errorMessage: 'Unable to copy.',
          expectedProvenanceSignals:
              ReportActions.familySummaryProvenanceSignals,
          enforceProvenanceContract: true,
          sharePolicy: ReportActions.familyReportSharePolicy,
        );
      },
    );
    await tester.pump();

    expect(clipboardWrites, 0);
    expect(
      find.text(
        'Unable to share because this report is missing evidence provenance.',
      ),
      findsOneWidget,
    );
    messenger.hideCurrentSnackBar();
    await tester.pumpAndSettle();

    await TelemetryService.runWithDispatcher(
      (Map<String, dynamic> payload) async {
        events.add(payload);
      },
      () async {
        await ReportActions.exportText(
          messenger: messenger,
          isMounted: () => true,
          fileName: 'weak-passport.txt',
          content: 'Family summary\nReviewed evidence: 1 evidence record',
          module: 'parent_summary',
          surface: 'family_dashboard',
          copiedEventName: 'parent.summary_export.copied',
          successMessage: 'Exported.',
          copiedMessage: 'Copied.',
          errorMessage: 'Unable to export.',
          unsupportedLogMessage: 'Unsupported export',
          expectedProvenanceSignals:
              ReportActions.passportReportProvenanceSignals,
          enforceProvenanceContract: true,
          sharePolicy: ReportActions.learnerPrivateReportSharePolicy,
        );
      },
    );
    await tester.pump();

    expect(exportAttempts, 0);
    expect(
      find.text(
        'Unable to export because this report is missing evidence provenance.',
      ),
      findsOneWidget,
    );
    final List<Map<String, dynamic>> blockedEvents = events
        .where(
          (Map<String, dynamic> payload) =>
              payload['event'] == 'report.delivery_blocked',
        )
        .toList(growable: false);
    expect(blockedEvents, hasLength(2));
    expect(
      (blockedEvents.first['metadata']
          as Map<String, dynamic>)['report_block_reason'],
      'missing_provenance',
    );
    expect(
      (blockedEvents.last['metadata']
          as Map<String, dynamic>)['report_delivery'],
      'contract-failed',
    );
  });

  testWidgets('enforced reports block rich content without a share policy',
      (WidgetTester tester) async {
    final List<Map<String, dynamic>> events = <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> auditCalls = <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> shareRequestCalls =
        <Map<String, dynamic>>[];
    int clipboardWrites = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          clipboardWrites += 1;
        }
        return null;
      },
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

    await ReportShareRequestService.runWithCallableInvoker(
      (String callableName, Map<String, dynamic> payload) async {
        shareRequestCalls.add(<String, dynamic>{
          'callableName': callableName,
          'payload': payload,
        });
        return <String, dynamic>{'id': 'share-request-1'};
      },
      () => ReportDeliveryAuditService.runWithCallableInvoker(
        (String callableName, Map<String, dynamic> payload) async {
          auditCalls.add(<String, dynamic>{
            'callableName': callableName,
            'payload': payload,
          });
        },
        () => TelemetryService.runWithDispatcher(
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
              siteId: 'site-1',
              expectedProvenanceSignals:
                  ReportActions.passportReportProvenanceSignals,
              enforceProvenanceContract: true,
            );
            await tester.pump();
            await tester.pump();
          },
        ),
      ),
    );
    await tester.pump();

    expect(clipboardWrites, 0);
    expect(
      find.text(
        'Unable to share because this report is missing a sharing safety policy.',
      ),
      findsOneWidget,
    );
    final Map<String, dynamic> blockedEvent = events.firstWhere(
      (Map<String, dynamic> payload) =>
          payload['event'] == 'report.delivery_blocked',
    );
    final Map<String, dynamic> blockedMetadata =
        blockedEvent['metadata'] as Map<String, dynamic>;
    expect(blockedMetadata['report_meets_provenance_contract'], isTrue);
    expect(blockedMetadata['report_meets_delivery_contract'], isFalse);
    expect(blockedMetadata['report_block_reason'], 'missing_share_policy');
    expect(shareRequestCalls, isEmpty);
    expect(auditCalls, hasLength(1));
    expect(auditCalls.single['callableName'], 'recordReportDeliveryAudit');
    final Map<String, dynamic> auditPayload =
        auditCalls.single['payload'] as Map<String, dynamic>;
    expect(auditPayload['reportDelivery'], 'contract-failed');
    expect(auditPayload['reportBlockReason'], 'missing_share_policy');
    expect(auditPayload['learnerId'], 'learner-1');
    expect(auditPayload['siteId'], 'site-1');
    final Map<String, dynamic> auditMetadata =
        auditPayload['metadata'] as Map<String, dynamic>;
    expect(auditMetadata['report_share_policy_declared'], isFalse);
    expect(
      auditMetadata['report_missing_delivery_contract_fields'],
      <String>['sharePolicy'],
    );
  });

  testWidgets('clipboard share failures are logged and audited',
      (WidgetTester tester) async {
    final List<Map<String, dynamic>> events = <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> auditCalls = <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> shareRequestCalls =
        <Map<String, dynamic>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          throw PlatformException(code: 'clipboard-denied');
        }
        return null;
      },
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

    await ReportShareRequestService.runWithCallableInvoker(
      (String callableName, Map<String, dynamic> payload) async {
        shareRequestCalls.add(<String, dynamic>{
          'callableName': callableName,
          'payload': payload,
        });
        return <String, dynamic>{'id': 'share-request-1'};
      },
      () => ReportDeliveryAuditService.runWithCallableInvoker(
        (String callableName, Map<String, dynamic> payload) async {
          auditCalls.add(<String, dynamic>{
            'callableName': callableName,
            'payload': payload,
          });
        },
        () => TelemetryService.runWithDispatcher(
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
              role: 'parent',
              siteId: 'site-1',
              expectedProvenanceSignals:
                  ReportActions.passportReportProvenanceSignals,
              enforceProvenanceContract: true,
              sharePolicy: ReportActions.familyReportSharePolicy,
            );
            await tester.pump();
            await tester.pump();
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Unable to copy.'), findsOneWidget);
    expect(shareRequestCalls, isEmpty);
    final Map<String, dynamic> failedEvent = events.firstWhere(
      (Map<String, dynamic> payload) =>
          payload['event'] == 'report.delivery_failed',
    );
    final Map<String, dynamic> failedMetadata =
        failedEvent['metadata'] as Map<String, dynamic>;
    expect(failedMetadata['report_action'], 'share');
    expect(failedMetadata['report_delivery'], 'failed');
    expect(failedMetadata['failure_stage'], 'clipboard');
    expect(failedMetadata['error_type'], 'PlatformException');
    expect(failedMetadata.containsKey('content'), isFalse);
    expect(auditCalls, hasLength(1));
    final Map<String, dynamic> auditPayload =
        auditCalls.single['payload'] as Map<String, dynamic>;
    expect(auditPayload['reportDelivery'], 'failed');
    expect(auditPayload['shareRequestId'], isNull);
    final Map<String, dynamic> auditMetadata =
        auditPayload['metadata'] as Map<String, dynamic>;
    expect(auditMetadata['failure_stage'], 'clipboard');
    expect(auditMetadata.containsKey('content'), isFalse);
  });

  testWidgets('export failures are logged and audited',
      (WidgetTester tester) async {
    final List<Map<String, dynamic>> events = <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> auditCalls = <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> shareRequestCalls =
        <Map<String, dynamic>>[];
    ExportService.instance.debugSaveTextFile = ({
      required String fileName,
      required String content,
      required String mimeType,
    }) async {
      throw StateError('disk unavailable');
    };

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

    await ReportShareRequestService.runWithCallableInvoker(
      (String callableName, Map<String, dynamic> payload) async {
        shareRequestCalls.add(<String, dynamic>{
          'callableName': callableName,
          'payload': payload,
        });
        return <String, dynamic>{'id': 'share-request-1'};
      },
      () => ReportDeliveryAuditService.runWithCallableInvoker(
        (String callableName, Map<String, dynamic> payload) async {
          auditCalls.add(<String, dynamic>{
            'callableName': callableName,
            'payload': payload,
          });
        },
        () => TelemetryService.runWithDispatcher(
          (Map<String, dynamic> payload) async {
            events.add(payload);
          },
          () async {
            await ReportActions.exportText(
              messenger: messenger,
              isMounted: () => true,
              fileName: 'family-summary.txt',
              content: _richEvidenceReport,
              module: 'parent_summary',
              surface: 'family_dashboard',
              copiedEventName: 'parent.summary_export.copied',
              successMessage: 'Exported.',
              copiedMessage: 'Copied.',
              errorMessage: 'Unable to export.',
              unsupportedLogMessage: 'Unsupported export',
              learnerId: 'learner-1',
              role: 'parent',
              siteId: 'site-1',
              expectedProvenanceSignals:
                  ReportActions.passportReportProvenanceSignals,
              enforceProvenanceContract: true,
              sharePolicy: ReportActions.familyReportSharePolicy,
            );
            await tester.pump();
            await tester.pump();
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Unable to export.'), findsOneWidget);
    expect(shareRequestCalls, isEmpty);
    final Map<String, dynamic> failedEvent = events.firstWhere(
      (Map<String, dynamic> payload) =>
          payload['event'] == 'report.delivery_failed',
    );
    final Map<String, dynamic> failedMetadata =
        failedEvent['metadata'] as Map<String, dynamic>;
    expect(failedMetadata['report_action'], 'export_text');
    expect(failedMetadata['report_delivery'], 'failed');
    expect(failedMetadata['failure_stage'], 'export_or_clipboard_fallback');
    expect(failedMetadata['error_type'], 'StateError');
    expect(failedMetadata.containsKey('content'), isFalse);
    expect(auditCalls, hasLength(1));
    final Map<String, dynamic> auditPayload =
        auditCalls.single['payload'] as Map<String, dynamic>;
    expect(auditPayload['reportDelivery'], 'failed');
    expect(auditPayload['shareRequestId'], isNull);
    final Map<String, dynamic> auditMetadata =
        auditPayload['metadata'] as Map<String, dynamic>;
    expect(auditMetadata['failure_stage'], 'export_or_clipboard_fallback');
    expect(auditMetadata.containsKey('content'), isFalse);
  });
}
