import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/modules/checkin/checkin_page.dart';
import 'package:scholesa_app/modules/checkin/checkin_service.dart';
import 'package:scholesa_app/services/firestore_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

Future<void> _pumpCheckinPage(
  WidgetTester tester, {
  required FakeFirebaseFirestore firestore,
}) async {
  final FirestoreService firestoreService = FirestoreService(
    firestore: firestore,
    auth: _MockFirebaseAuth(),
  );
  final CheckinService checkinService = CheckinService(
    firestoreService: firestoreService,
    siteId: 'site-1',
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: <SingleChildWidget>[
        Provider<FirestoreService>.value(value: firestoreService),
        ChangeNotifierProvider<CheckinService>.value(value: checkinService),
      ],
      child: MaterialApp(
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
        home: const CheckinPage(),
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'checkin QR dialog shows explicit unavailable copy without fake actions',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('learner-1').set(<String, dynamic>{
      'role': 'learner',
      'displayName': 'Ava Learner',
      'siteIds': <String>['site-1'],
    });

    await _pumpCheckinPage(tester, firestore: firestore);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Scan QR'), findsWidgets);
    expect(
      find.textContaining('QR scanning is not available in the app yet'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
          'Manual pickup code entry is not available in the app yet'),
      findsOneWidget,
    );
    expect(find.text('Use Camera'), findsNothing);
    expect(find.text('Enter Code'), findsNothing);
  });
}
