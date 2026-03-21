import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/domain/repositories.dart';
import 'package:scholesa_app/modules/hq_admin/hq_approvals_page.dart';
import 'package:scholesa_app/modules/partner/partner_models.dart';
import 'package:scholesa_app/modules/partner/partner_contracts_page.dart';
import 'package:scholesa_app/modules/partner/partner_service.dart';
import 'package:scholesa_app/services/firestore_service.dart';
import 'package:scholesa_app/services/telemetry_service.dart';
import 'package:scholesa_app/services/workflow_bridge_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _FakeWorkflowBridgeService extends WorkflowBridgeService {
  _FakeWorkflowBridgeService({List<Map<String, dynamic>>? launches})
      : _launches = List<Map<String, dynamic>>.from(
          launches ?? <Map<String, dynamic>>[],
        ),
        super(functions: null);

  final List<Map<String, dynamic>> _launches;

  @override
  Future<List<Map<String, dynamic>>> listPartnerLaunches({
    String? siteId,
    int limit = 80,
  }) async {
    final Iterable<Map<String, dynamic>> scoped =
        (siteId == null || siteId.isEmpty)
            ? _launches
            : _launches.where(
                (Map<String, dynamic> launch) => launch['siteId'] == siteId,
              );
    return scoped
        .take(limit)
        .map((Map<String, dynamic> launch) => Map<String, dynamic>.from(launch))
        .toList();
  }
}

class _FakePartnerService extends PartnerService {
  _FakePartnerService({
    required super.firestoreService,
    required this.failContracts,
    required this.failLaunches,
    this.failContractsOnRefresh = false,
    this.failLaunchesOnRefresh = false,
    List<PartnerContract>? contracts,
    List<PartnerLaunch>? launches,
  })  : _contractsValue = List<PartnerContract>.from(
          contracts ?? <PartnerContract>[],
        ),
        _launchesValue = List<PartnerLaunch>.from(launches ?? <PartnerLaunch>[]),
        super(
          partnerId: 'partner-1',
          workflowBridgeService: _FakeWorkflowBridgeService(),
        );

  final bool failContracts;
  final bool failLaunches;
  final bool failContractsOnRefresh;
  final bool failLaunchesOnRefresh;
  List<PartnerContract> _contractsValue;
  List<PartnerLaunch> _launchesValue;
  bool _isLoadingValue = false;
  String? _errorValue;
  int _contractsLoadCount = 0;
  int _launchesLoadCount = 0;

  @override
  List<PartnerContract> get contracts => _contractsValue;

  @override
  List<PartnerLaunch> get partnerLaunches => _launchesValue;

  @override
  bool get isLoading => _isLoadingValue;

  @override
  String? get error => _errorValue;

  @override
  Future<void> loadContracts() async {
    _contractsLoadCount += 1;
    _isLoadingValue = true;
    _errorValue = null;
    notifyListeners();

    await Future<void>.delayed(Duration.zero);

    if (failContracts || (failContractsOnRefresh && _contractsLoadCount > 1)) {
      _errorValue = 'Failed to load contracts';
    }

    _isLoadingValue = false;
    notifyListeners();
  }

  @override
  Future<void> loadPartnerLaunches() async {
    _launchesLoadCount += 1;
    _isLoadingValue = true;
    if (!failContracts) {
      _errorValue = null;
    }
    notifyListeners();

    await Future<void>.delayed(Duration.zero);

    if (failLaunches || (failLaunchesOnRefresh && _launchesLoadCount > 1)) {
      _errorValue = 'Failed to load partner launches';
    }

    _isLoadingValue = false;
    notifyListeners();
  }
}

Widget _buildHarness({
  required Widget child,
  required List<SingleChildWidget> providers,
}) {
  final Widget app = MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      splashFactory: NoSplash.splashFactory,
    ),
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
    home: child,
  );

  if (providers.isEmpty) {
    return app;
  }

  return MultiProvider(providers: providers, child: app);
}

void main() {
  testWidgets('partner contracts dashboard renders contracts and launches',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await firestore.collection('partnerContracts').doc('contract-1').set(
      <String, dynamic>{
        'partnerId': 'partner-1',
        'siteId': 'site-1',
        'title': 'Studio Launch Agreement',
        'status': 'submitted',
        'totalValue': 2400,
      },
    );

    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final PartnerService partnerService = PartnerService(
      firestoreService: firestoreService,
      partnerId: 'partner-1',
      workflowBridgeService: _FakeWorkflowBridgeService(
        launches: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'launch-1',
            'partnerId': 'partner-1',
            'siteId': 'site-1',
            'partnerName': 'North Hub',
            'region': 'APAC',
            'locale': 'en',
            'dueDiligenceStatus': 'approved',
            'contractStatus': 'submitted',
            'planningWorkshopStatus': 'scheduled',
            'trainerOfTrainersStatus': 'planned',
            'kpiLoggingStatus': 'ready',
            'review90DayStatus': 'pending',
            'pilotCohortCount': 2,
            'status': 'planning',
            'updatedAt': DateTime(2026, 3, 14).toIso8601String(),
          },
        ],
      ),
    );

    await tester.pumpWidget(
      _buildHarness(
        child: const PartnerContractsPage(),
        providers: <SingleChildWidget>[
          Provider<FirestoreService>.value(value: firestoreService),
          ChangeNotifierProvider<PartnerService>.value(value: partnerService),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('Partner Workflows'), findsOneWidget);
    expect(find.text('Studio Launch Agreement'), findsOneWidget);
    expect(find.text('Site: site-1'), findsOneWidget);
    expect(find.text('Submitted'), findsOneWidget);

    await tester.tap(find.text('Launches'));
    await tester.pumpAndSettle();

    expect(find.text('North Hub'), findsOneWidget);
    expect(find.text('APAC • en'), findsOneWidget);
    expect(find.text('Pilot Cohorts: 2'), findsOneWidget);
  });

  testWidgets(
      'partner contracts route shows an explicit error instead of empty launches on load failure',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final PartnerService partnerService = _FakePartnerService(
      firestoreService: firestoreService,
      failContracts: false,
      failLaunches: true,
      contracts: <PartnerContract>[
        const PartnerContract(
          id: 'contract-1',
          partnerId: 'partner-1',
          siteId: 'site-1',
          title: 'Studio Launch Agreement',
          status: ContractStatus.submitted,
          totalValue: 2400,
        ),
      ],
    );

    await tester.pumpWidget(
      _buildHarness(
        child: const PartnerContractsPage(),
        providers: <SingleChildWidget>[
          Provider<FirestoreService>.value(value: firestoreService),
          ChangeNotifierProvider<PartnerService>.value(value: partnerService),
        ],
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('Studio Launch Agreement'), findsOneWidget);
    expect(find.textContaining('Showing last loaded workflow data.'), findsOneWidget);

    await tester.tap(find.text('Launches'));
    await tester.pumpAndSettle();

    expect(find.text('Unable to load partner workflows'), findsOneWidget);
    expect(find.text('Failed to load partner launches'), findsOneWidget);
    expect(find.text('No Launches Yet'), findsNothing);
  });

  testWidgets('partner contracts keeps stale contracts visible after refresh failure',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final PartnerService partnerService = _FakePartnerService(
      firestoreService: firestoreService,
      failContracts: false,
      failLaunches: false,
      failContractsOnRefresh: true,
      contracts: <PartnerContract>[
        const PartnerContract(
          id: 'contract-1',
          partnerId: 'partner-1',
          siteId: 'site-1',
          title: 'Studio Launch Agreement',
          status: ContractStatus.submitted,
          totalValue: 2400,
        ),
      ],
    );

    await tester.pumpWidget(
      _buildHarness(
        child: const PartnerContractsPage(),
        providers: <SingleChildWidget>[
          Provider<FirestoreService>.value(value: firestoreService),
          ChangeNotifierProvider<PartnerService>.value(value: partnerService),
        ],
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Studio Launch Agreement'), findsOneWidget);

    await tester.drag(find.byType(RefreshIndicator).first, const Offset(0, 300));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('Showing last loaded workflow data.'), findsOneWidget);
    expect(find.text('Studio Launch Agreement'), findsOneWidget);
  });

  testWidgets('partner contracts keeps stale launches visible after refresh failure',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final PartnerService partnerService = _FakePartnerService(
      firestoreService: firestoreService,
      failContracts: false,
      failLaunches: false,
      failLaunchesOnRefresh: true,
      launches: <PartnerLaunch>[
        PartnerLaunch(
          id: 'launch-1',
          partnerId: 'partner-1',
          siteId: 'site-1',
          partnerName: 'North Hub',
          region: 'APAC',
          locale: 'en',
          dueDiligenceStatus: 'approved',
          contractStatus: 'submitted',
          planningWorkshopStatus: 'scheduled',
          trainerOfTrainersStatus: 'planned',
          kpiLoggingStatus: 'ready',
          review90DayStatus: 'pending',
          pilotCohortCount: 2,
          status: 'planning',
          updatedAt: DateTime(2026, 3, 14),
        ),
      ],
    );

    await tester.pumpWidget(
      _buildHarness(
        child: const PartnerContractsPage(),
        providers: <SingleChildWidget>[
          Provider<FirestoreService>.value(value: firestoreService),
          ChangeNotifierProvider<PartnerService>.value(value: partnerService),
        ],
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Launches'));
    await tester.pumpAndSettle();

    expect(find.text('North Hub'), findsOneWidget);

    await tester.drag(find.byType(RefreshIndicator).first, const Offset(0, 300));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('Showing last loaded workflow data.'), findsOneWidget);
    expect(find.text('North Hub'), findsOneWidget);
  });

  testWidgets('hq approvals surface loads and approves workflow items',
      (WidgetTester tester) async {
    final List<Map<String, dynamic>> decisionCalls = <Map<String, dynamic>>[];

    await tester.pumpWidget(
      _buildHarness(
        child: HqApprovalsPage(
          loadApprovals: () async => <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'partnerContracts:contract-1',
              'title': 'Studio Launch Agreement',
              'submittedBy': 'Ops',
              'status': 'pending',
              'sourceCollection': 'partnerContracts',
              'updatedAt': DateTime(2026, 3, 14).toIso8601String(),
            },
          ],
          decideApproval: ({required String id, required String status}) async {
            decisionCalls.add(<String, dynamic>{'id': id, 'status': status});
          },
        ),
        providers: const <SingleChildWidget>[],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Approvals'), findsOneWidget);
    expect(find.text('Studio Launch Agreement'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(decisionCalls, hasLength(1));
    expect(decisionCalls.first['id'], 'partnerContracts:contract-1');
    expect(decisionCalls.first['status'], 'approved');
    expect(find.text('Approved: Studio Launch Agreement'), findsOneWidget);
  });

  test('partner workflow repositories persist approvals, payouts, and audit evidence',
      () async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final AuditLogRepository auditLogRepository =
        AuditLogRepository(firestore: firestore);
    final PartnerContractRepository contractRepository =
        PartnerContractRepository(firestore: firestore);
    final PartnerDeliverableRepository deliverableRepository =
        PartnerDeliverableRepository(
      firestore: firestore,
      auditLogRepository: auditLogRepository,
    );
    final PayoutRepository payoutRepository =
        PayoutRepository(firestore: firestore);
    final List<Map<String, dynamic>> telemetryPayloads =
        <Map<String, dynamic>>[];

    await TelemetryService.runWithDispatcher((Map<String, dynamic> payload) async {
      telemetryPayloads.add(payload);
    }, () async {
      final String contractId = await contractRepository.createDraft(
        partnerOrgId: 'partner-org-1',
        title: 'Studio Launch Agreement',
        amount: '2400',
        currency: 'USD',
        createdBy: 'partner-1',
      );
      await firestore.collection('partnerContracts').doc(contractId).set(
        <String, dynamic>{'siteId': 'site-1'},
        SetOptions(merge: true),
      );

      final pendingContracts = await contractRepository.listPendingApproval();
      expect(pendingContracts.map((contract) => contract.id).toList(),
          <String>[contractId]);

      await contractRepository.approve(id: contractId, approvedBy: 'hq-1');

      final approvedContract =
          await firestore.collection('partnerContracts').doc(contractId).get();
      expect(approvedContract.data()?['status'], 'approved');
      expect(approvedContract.data()?['approvedBy'], 'hq-1');

      final String deliverableId = await deliverableRepository.submit(
        contractId: contractId,
        title: 'Evidence Pack',
        description: 'Pilot session assets and attendance summary',
        evidenceUrl: 'https://files.scholesa.test/evidence-pack.pdf',
        submittedBy: 'partner-1',
      );

      final pendingDeliverables =
          await deliverableRepository.listPendingAcceptance();
      expect(pendingDeliverables.map((deliverable) => deliverable.id).toList(),
          <String>[deliverableId]);

      await deliverableRepository.accept(id: deliverableId, acceptedBy: 'hq-1');

      final acceptedDeliverable = await firestore
          .collection('partnerDeliverables')
          .doc(deliverableId)
          .get();
      expect(acceptedDeliverable.data()?['status'], 'accepted');
      expect(acceptedDeliverable.data()?['acceptedBy'], 'hq-1');
      expect(acceptedDeliverable.data()?['evidenceUrl'],
          'https://files.scholesa.test/evidence-pack.pdf');

      final String payoutId = await payoutRepository.createPending(
        contractId: contractId,
        amount: '600',
        currency: 'USD',
        createdBy: 'hq-1',
      );
      await firestore.collection('payouts').doc(payoutId).set(
        <String, dynamic>{'siteId': 'site-1'},
        SetOptions(merge: true),
      );

      final pendingPayouts = await payoutRepository.listPendingApproval();
      expect(pendingPayouts.map((payout) => payout.id).toList(), <String>[payoutId]);

      await payoutRepository.approve(id: payoutId, approvedBy: 'hq-1');

      final approvedPayout =
          await firestore.collection('payouts').doc(payoutId).get();
      expect(approvedPayout.data()?['status'], 'approved');
      expect(approvedPayout.data()?['approvedBy'], 'hq-1');

      final auditLogs = await firestore.collection('auditLogs').get();
      expect(auditLogs.docs, hasLength(2));
      expect(
        auditLogs.docs.map((doc) => doc.data()['action']).toSet(),
        <String>{'deliverable.submit', 'deliverable.accept'},
      );

      expect(
        telemetryPayloads.map((Map<String, dynamic> payload) => payload['event']).toList(),
        containsAll(<String>[
          'contract.created',
          'contract.approved',
          'deliverable.submitted',
          'deliverable.accepted',
          'payout.approved',
        ]),
      );
      expect(
        telemetryPayloads.where(
          (Map<String, dynamic> payload) =>
              payload['event'] == 'payout.approved' &&
              payload['siteId'] == 'site-1',
        ),
        hasLength(1),
      );
    });
  });
}
