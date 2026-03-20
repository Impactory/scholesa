import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/domain/models.dart';
import 'package:scholesa_app/domain/repositories.dart';
import 'package:scholesa_app/modules/hq_admin/hq_feature_flags_page.dart';
import 'package:scholesa_app/services/workflow_bridge_service.dart';
import 'package:scholesa_app/ui/theme/scholesa_theme.dart';

class _FakeWorkflowBridgeService extends WorkflowBridgeService {
  _FakeWorkflowBridgeService({
    List<Map<String, dynamic>>? flags,
    this.failOnUpsertFeatureFlag = false,
  }) : _flags =
            List<Map<String, dynamic>>.from(flags ?? <Map<String, dynamic>>[]);

  final List<Map<String, dynamic>> _flags;
  final bool failOnUpsertFeatureFlag;
  final List<Map<String, dynamic>> recordedFlagUpdates =
      <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> listFeatureFlags({int limit = 300}) async =>
      _flags
          .take(limit)
          .map((Map<String, dynamic> row) => Map<String, dynamic>.from(row))
          .toList();

  @override
  Future<List<Map<String, dynamic>>> listFederatedLearningExperiments({
    int limit = 120,
  }) async =>
      <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>>
      listFederatedLearningExperimentReviewRecords({
    String? experimentId,
    int limit = 120,
  }) async =>
          <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> listFederatedLearningAggregationRuns({
    String? experimentId,
    int limit = 60,
  }) async =>
      <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> listFederatedLearningMergeArtifacts({
    String? experimentId,
    int limit = 60,
  }) async =>
      <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>>
      listFederatedLearningCandidateModelPackages({
    String? experimentId,
    int limit = 60,
  }) async =>
          <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> listFederatedLearningPilotEvidenceRecords({
    String? experimentId,
    String? candidateModelPackageId,
    int limit = 60,
  }) async =>
      <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>>
      listFederatedLearningPilotApprovalRecords({
    String? experimentId,
    String? candidateModelPackageId,
    int limit = 60,
  }) async =>
          <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>>
      listFederatedLearningPilotExecutionRecords({
    String? experimentId,
    String? candidateModelPackageId,
    int limit = 60,
  }) async =>
          <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>>
      listFederatedLearningRuntimeDeliveryRecords({
    String? experimentId,
    String? candidateModelPackageId,
    int limit = 60,
  }) async =>
          <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>>
      listFederatedLearningRuntimeActivationRecords({
    String? experimentId,
    String? candidateModelPackageId,
    String? siteId,
    int limit = 60,
  }) async =>
          <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>>
      listFederatedLearningRuntimeRolloutAlertRecords({
    String? experimentId,
    String? candidateModelPackageId,
    String? deliveryRecordId,
    String? status,
    int limit = 60,
  }) async =>
          <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>>
      listFederatedLearningRuntimeRolloutEscalationRecords({
    String? experimentId,
    String? candidateModelPackageId,
    String? deliveryRecordId,
    String? status,
    int limit = 60,
  }) async =>
          <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>>
      listFederatedLearningRuntimeRolloutControlRecords({
    String? experimentId,
    String? candidateModelPackageId,
    String? deliveryRecordId,
    String? mode,
    int limit = 60,
  }) async =>
          <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>>
      listFederatedLearningCandidatePromotionRecords({
    String? experimentId,
    String? candidateModelPackageId,
    int limit = 60,
  }) async =>
          <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>>
      listFederatedLearningCandidatePromotionRevocationRecords({
    String? experimentId,
    String? candidateModelPackageId,
    int limit = 60,
  }) async =>
          <Map<String, dynamic>>[];

  @override
  Future<String?> upsertFeatureFlag(Map<String, dynamic> data) async {
    if (failOnUpsertFeatureFlag) {
      throw Exception('feature flag save failed');
    }
    final Map<String, dynamic> normalized = Map<String, dynamic>.from(data);
    recordedFlagUpdates.add(normalized);
    final String id = normalized['id'] as String? ?? 'flag-${_flags.length + 1}';
    final int existingIndex =
        _flags.indexWhere((Map<String, dynamic> row) => row['id'] == id);
    final Map<String, dynamic> persisted = <String, dynamic>{
      ...normalized,
      'id': id,
    };
    if (existingIndex >= 0) {
      _flags[existingIndex] = persisted;
    } else {
      _flags.add(persisted);
    }
    return id;
  }
}

class _FakeUpdateSummaryRepository
    extends FederatedLearningUpdateSummaryRepository {
  _FakeUpdateSummaryRepository() : super(firestore: FakeFirebaseFirestore());

  @override
  Future<List<FederatedLearningUpdateSummaryModel>> listByIds(
    List<String> ids,
  ) async =>
      const <FederatedLearningUpdateSummaryModel>[];
}

void main() {
  Widget buildHarness({
    required _FakeWorkflowBridgeService workflowBridge,
  }) {
    return MaterialApp(
      theme: ScholesaTheme.light,
      locale: const Locale('en'),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[
        Locale('en'),
        Locale('zh', 'CN'),
        Locale('zh', 'TW'),
      ],
      home: HqFeatureFlagsPage(
        workflowBridge: workflowBridge,
        updateSummaryRepository: _FakeUpdateSummaryRepository(),
      ),
    );
  }

  testWidgets('hq feature flags page shows honest empty states',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      buildHarness(workflowBridge: _FakeWorkflowBridgeService()),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('Feature Flags'), findsOneWidget);
    expect(find.text('No feature flags found'), findsOneWidget);
    expect(
      find.text('No federated-learning experiments are configured yet.'),
      findsOneWidget,
    );
  });

  testWidgets('hq feature flags page persists a toggle change',
      (WidgetTester tester) async {
    final _FakeWorkflowBridgeService workflowBridge =
        _FakeWorkflowBridgeService(
      flags: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'flag-1',
          'name': 'ai_help_loop',
          'description': 'Enable spoken AI help loop runtime',
          'enabled': false,
          'scope': 'global',
        },
      ],
    );

    await tester.pumpWidget(buildHarness(workflowBridge: workflowBridge));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(workflowBridge.recordedFlagUpdates, hasLength(1));
    expect(workflowBridge.recordedFlagUpdates.single['enabled'], isTrue);
    expect(workflowBridge.recordedFlagUpdates.single['name'], 'ai_help_loop');
    expect(find.text('ai_help_loop enabled'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets(
      'hq feature flags page canonicalizes legacy loop names at the rendered surface',
      (WidgetTester tester) async {
    final _FakeWorkflowBridgeService workflowBridge =
        _FakeWorkflowBridgeService(
      flags: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'flag-1',
          'name': 'miloos_loop',
          'description': 'Enable spoken AI help loop runtime',
          'enabled': false,
          'scope': 'global',
        },
      ],
    );

    await tester.pumpWidget(buildHarness(workflowBridge: workflowBridge));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('ai_help_loop'), findsOneWidget);
    expect(find.text('miloos_loop'), findsNothing);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(workflowBridge.recordedFlagUpdates, hasLength(1));
    expect(workflowBridge.recordedFlagUpdates.single['name'], 'ai_help_loop');
    expect(find.text('ai_help_loop enabled'), findsOneWidget);
    expect(find.text('miloos_loop enabled'), findsNothing);
  });

  testWidgets(
      'hq feature flags page keeps the prior toggle state when save fails',
      (WidgetTester tester) async {
    final _FakeWorkflowBridgeService workflowBridge =
        _FakeWorkflowBridgeService(
      flags: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'flag-1',
          'name': 'ai_help_loop',
          'description': 'Enable spoken AI help loop runtime',
          'enabled': false,
          'scope': 'global',
        },
      ],
      failOnUpsertFeatureFlag: true,
    );

    await tester.pumpWidget(buildHarness(workflowBridge: workflowBridge));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(workflowBridge.recordedFlagUpdates, isEmpty);
    expect(find.text('Feature flag update failed'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });
}
