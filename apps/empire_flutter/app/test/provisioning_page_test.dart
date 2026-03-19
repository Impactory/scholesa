import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/provisioning/provisioning_models.dart';
import 'package:scholesa_app/modules/provisioning/provisioning_page.dart';
import 'package:scholesa_app/modules/provisioning/provisioning_service.dart';
import 'package:scholesa_app/services/api_client.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _FakeProvisioningService extends ProvisioningService {
  _FakeProvisioningService({
    List<LearnerProfile>? learners,
    this.loadError,
  })  : _learnersValue = learners ?? <LearnerProfile>[],
        super(
          apiClient: ApiClient(
            auth: _MockFirebaseAuth(),
            baseUrl: 'http://localhost',
          ),
          firestore: FakeFirebaseFirestore(),
          auth: _MockFirebaseAuth(),
          useProvisioningApi: false,
        );

  final List<LearnerProfile> _learnersValue;
  final String? loadError;

  bool _isLoadingValue = false;
  String? _errorValue;

  @override
  List<LearnerProfile> get learners => _learnersValue;

  @override
  List<ParentProfile> get parents => const <ParentProfile>[];

  @override
  List<GuardianLink> get guardianLinks => const <GuardianLink>[];

  @override
  List<CohortLaunch> get cohortLaunches => const <CohortLaunch>[];

  @override
  bool get isLoading => _isLoadingValue;

  @override
  String? get error => _errorValue;

  @override
  Future<void> loadLearners(String siteId) async {
    _isLoadingValue = true;
    _errorValue = null;
    notifyListeners();
    await Future<void>.delayed(Duration.zero);
    _errorValue = loadError;
    _isLoadingValue = false;
    notifyListeners();
  }

  @override
  Future<void> loadParents(String siteId) async {}

  @override
  Future<void> loadGuardianLinks(String siteId) async {}

  @override
  Future<void> loadCohortLaunches(String siteId) async {}
}

AppState _buildSiteState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'site-admin-1',
    'email': 'site-admin@scholesa.test',
    'displayName': 'Site Admin',
    'role': 'site',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'localeCode': 'en',
    'entitlements': const <Map<String, dynamic>>[],
  });
  return state;
}

Widget _buildHarness({required ProvisioningService service}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: _buildSiteState()),
      ChangeNotifierProvider<ProvisioningService>.value(value: service),
    ],
    child: MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        splashFactory: NoSplash.splashFactory,
      ),
      locale: const Locale('en'),
      supportedLocales: const <Locale>[
        Locale('en'),
        Locale('zh', 'CN'),
        Locale('zh', 'TW'),
      ],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const ProvisioningPage(),
    ),
  );
}

void main() {
  testWidgets(
      'provisioning page shows an explicit learner load error instead of an empty state',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildHarness(
        service: _FakeProvisioningService(
          loadError: 'Failed to load learners from test',
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('Unable to load learners'), findsOneWidget);
    expect(find.text('Failed to load learners from test'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('No learners yet'), findsNothing);
  });

  testWidgets(
      'provisioning page keeps loaded learners visible behind a stale-data banner',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildHarness(
        service: _FakeProvisioningService(
          learners: const <LearnerProfile>[
            LearnerProfile(
              id: 'learner-1',
              siteId: 'site-1',
              userId: 'learner-user-1',
              displayName: 'Learner One',
              gradeLevel: 6,
            ),
          ],
          loadError: 'Failed to refresh learners from test',
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(
      find.text(
        'Showing last loaded provisioning data. Failed to refresh learners from test',
      ),
      findsOneWidget,
    );
    expect(find.text('Learner One'), findsOneWidget);
    expect(find.text('Grade 6'), findsOneWidget);
  });
}
