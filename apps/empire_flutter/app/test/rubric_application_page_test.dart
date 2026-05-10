import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/educator/rubric_application_page.dart';
import 'package:scholesa_app/services/firestore_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _ThrowingFirestoreService extends FirestoreService {
  _ThrowingFirestoreService()
      : super(
          firestore: FakeFirebaseFirestore(),
          auth: _MockFirebaseAuth(),
        );

  @override
  Future<List<Map<String, dynamic>>> queryCollection(
    String collection, {
    List<List<dynamic>>? where,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) async {
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'failed-precondition',
      message:
          'The query requires an index. You can create it here: https://console.firebase.google.com/project/demo/firestore/indexes',
    );
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
    'entitlements': const <Map<String, dynamic>>[],
  });
  return state;
}

Widget _buildHarness({
  required AppState appState,
  required FirestoreService firestoreService,
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: appState),
      Provider<FirestoreService>.value(value: firestoreService),
    ],
    child: MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: const RubricApplicationPage(),
    ),
  );
}

void main() {
  testWidgets('rubric load failures show friendly setup guidance',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildHarness(
        appState: _buildEducatorState(),
        firestoreService: _ThrowingFirestoreService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Apply Rubric Judgments'), findsOneWidget);
    expect(
      find.text(
        'Rubric review needs a quick refresh. Try again, or reopen Apply Rubric Judgments from Today.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('console.firebase.google.com'), findsNothing);
    expect(find.textContaining('failed-precondition'), findsNothing);
  });
}
