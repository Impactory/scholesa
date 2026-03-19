import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/educator/educator_models.dart';
import 'package:scholesa_app/modules/educator/educator_service.dart';
import 'package:scholesa_app/modules/educator/educator_sessions_page.dart';
import 'package:scholesa_app/services/firestore_service.dart';
import 'package:scholesa_app/ui/theme/scholesa_theme.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _FakeEducatorService extends EducatorService {
  _FakeEducatorService({required FirestoreService firestoreService})
      : super(
          firestoreService: firestoreService,
          educatorId: 'educator-1',
          siteId: 'site-1',
        );

  List<EducatorSession> _sessionsValue = <EducatorSession>[];
  List<EducatorLearner> _learnersValue = <EducatorLearner>[];
  bool _isLoadingValue = false;
  String? _errorValue;

  @override
  List<EducatorSession> get sessions => _sessionsValue;

  @override
  List<EducatorLearner> get learners => _learnersValue;

  @override
  bool get isLoading => _isLoadingValue;

  @override
  String? get error => _errorValue;

  @override
  Future<void> loadSessions() async {
    _isLoadingValue = true;
    _errorValue = null;
    notifyListeners();

    await Future<void>.delayed(Duration.zero);

    _sessionsValue = <EducatorSession>[];
    _errorValue = 'Failed to load sessions';
    _isLoadingValue = false;
    notifyListeners();
  }

  @override
  Future<void> loadLearners() async {
    _learnersValue = <EducatorLearner>[];
    notifyListeners();
  }
}

AppState _buildEducatorState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'educator-1',
    'email': 'educator-1@scholesa.test',
    'displayName': 'Educator One',
    'role': 'educator',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'localeCode': 'en',
    'entitlements': <Map<String, dynamic>>[],
  });
  return state;
}

Widget _buildHarness({required EducatorService educatorService}) {
  final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
  final FirestoreService firestoreService = FirestoreService(
    firestore: firestore,
    auth: _MockFirebaseAuth(),
  );

  return MultiProvider(
    providers: <SingleChildWidget>[
      Provider<FirestoreService>.value(value: firestoreService),
      ChangeNotifierProvider<AppState>.value(value: _buildEducatorState()),
      ChangeNotifierProvider<EducatorService>.value(value: educatorService),
    ],
    child: MaterialApp(
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
      home: const EducatorSessionsPage(),
    ),
  );
}

void main() {
  testWidgets(
      'educator sessions page shows an explicit load error instead of an empty state',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final EducatorService educatorService =
        _FakeEducatorService(firestoreService: firestoreService);

    await tester.pumpWidget(
      _buildHarness(educatorService: educatorService),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Unable to load sessions'), findsOneWidget);
    expect(find.text('Failed to load sessions'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('No sessions yet'), findsNothing);
  });
}