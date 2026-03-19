import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/domain/models.dart';
import 'package:scholesa_app/domain/repositories.dart';
import 'package:scholesa_app/modules/hq_admin/hq_feature_flags_page.dart';
import 'package:scholesa_app/services/workflow_bridge_service.dart';
import 'package:scholesa_app/ui/theme/scholesa_theme.dart';

class _FakeWorkflowBridgeService extends WorkflowBridgeService {
  @override
  Future<List<Map<String, dynamic>>> listFeatureFlags({int limit = 300}) async =>
      <Map<String, dynamic>>[];

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
}

class _FakeUpdateSummaryRepository
    extends FederatedLearningUpdateSummaryRepository {
  @override
  Future<List<FederatedLearningUpdateSummaryModel>> listByIds(
    List<String> ids,
  ) async =>
      const <FederatedLearningUpdateSummaryModel>[];
}

void main() {
  testWidgets('hq feature flags page shows honest empty states',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
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
          workflowBridge: _FakeWorkflowBridgeService(),
          updateSummaryRepository: _FakeUpdateSummaryRepository(),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Feature Flags'), findsOneWidget);
    expect(find.text('No feature flags found'), findsOneWidget);
    expect(
      find.text('No federated-learning experiments are configured yet.'),
      findsOneWidget,
    );
  });
}