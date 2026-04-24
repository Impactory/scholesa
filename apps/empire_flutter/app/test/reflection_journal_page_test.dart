import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/learner/reflection_journal_page.dart';
import 'package:scholesa_app/services/firestore_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _CapturingFirestoreService extends FirestoreService {
  _CapturingFirestoreService()
      : super(
          firestore: FakeFirebaseFirestore(),
          auth: _MockFirebaseAuth(),
        );

  Map<String, dynamic>? lastSubmitPayload;

  @override
  Future<String> submitReflection({
    required String learnerId,
    required String siteId,
    String? sessionId,
    String? missionId,
    required String prompt,
    required String response,
    int? engagementRating,
    int? confidenceRating,
    bool? aiAssistanceUsed,
    String? aiAssistanceDetails,
  }) async {
    lastSubmitPayload = <String, dynamic>{
      'learnerId': learnerId,
      'siteId': siteId,
      'sessionId': sessionId,
      'missionId': missionId,
      'prompt': prompt,
      'response': response,
      'engagementRating': engagementRating,
      'confidenceRating': confidenceRating,
      'aiAssistanceUsed': aiAssistanceUsed,
      'aiAssistanceDetails': aiAssistanceDetails,
    };
    return 'reflection-1';
  }
}

AppState _buildLearnerState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'learner-1',
    'email': 'learner@scholesa.test',
    'displayName': 'Learner One',
    'role': 'learner',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'localeCode': 'en',
    'entitlements': const <Map<String, dynamic>>[],
  });
  return state;
}

Future<_CapturingFirestoreService> _pumpPage(WidgetTester tester) async {
  final _CapturingFirestoreService service = _CapturingFirestoreService();

  await tester.pumpWidget(
    MultiProvider(
      providers: <SingleChildWidget>[
        Provider<FirestoreService>.value(value: service),
        ChangeNotifierProvider<AppState>.value(value: _buildLearnerState()),
      ],
      child: const MaterialApp(
        home: ReflectionJournalPage(),
      ),
    ),
  );

  await tester.pumpAndSettle();
  return service;
}

void main() {
  testWidgets('reflection journal submits AI disclosure through the service',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final _CapturingFirestoreService service = await _pumpPage(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'What are you reflecting on?'),
      'What did I learn today that surprised me?',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Write your thoughts...'),
      'I learned that testing the evidence path catches drift quickly.',
    );

    await tester.ensureVisible(
      find.text('I used AI tools to help with this reflection'),
    );
    await tester.tap(find.text('I used AI tools to help with this reflection'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Which AI tools did you use? (optional)'),
      'Used Scholesa AI coach to draft my first outline.',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Save Reflection'));
    await tester.pumpAndSettle();

    expect(service.lastSubmitPayload, isNotNull);
    expect(service.lastSubmitPayload!['learnerId'], 'learner-1');
    expect(service.lastSubmitPayload!['siteId'], 'site-1');
    expect(service.lastSubmitPayload!['aiAssistanceUsed'], true);
    expect(
      service.lastSubmitPayload!['aiAssistanceDetails'],
      'Used Scholesa AI coach to draft my first outline.',
    );
  });
}
