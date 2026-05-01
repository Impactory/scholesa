import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/site/site_dashboard_page.dart';
import 'package:scholesa_app/services/export_service.dart';
import 'package:scholesa_app/services/firestore_service.dart';
import 'package:scholesa_app/ui/theme/scholesa_theme.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

String? _savedFileName;
String? _savedFileContent;

AppState _buildSiteState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'site-admin-1',
    'email': 'site@scholesa.test',
    'displayName': 'Site Admin',
    'role': 'site',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'entitlements': <Map<String, dynamic>>[],
  });
  return state;
}

Widget _buildHarness({
  required FirestoreService firestoreService,
  required AppState appState,
  SharedPreferences? sharedPreferences,
  Widget? page,
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      Provider<FirestoreService>.value(value: firestoreService),
      ChangeNotifierProvider<AppState>.value(value: appState),
    ],
    child: MaterialApp(
      theme: ScholesaTheme.light,
      home: page ?? SiteDashboardPage(sharedPreferences: sharedPreferences),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _savedFileName = null;
    _savedFileContent = null;
    ExportService.instance.debugSaveTextFile = null;
  });

  testWidgets('site dashboard hides disconnected pillar telemetry card',
      (WidgetTester tester) async {
    final FirestoreService firestoreService = FirestoreService(
      firestore: FakeFirebaseFirestore(),
      auth: _MockFirebaseAuth(),
    );

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        appState: _buildSiteState(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Site Dashboard'), findsOneWidget);
    expect(find.text('Recent Activity'), findsOneWidget);
    expect(find.text('Pillar Progress (Site Average)'), findsNothing);
    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
  });

  testWidgets(
      'site dashboard shows site-scoped MiloOS support health without mastery claims',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await firestore.collection('interactionEvents').add(<String, dynamic>{
      'siteId': 'site-1',
      'actorId': 'learner-1',
      'eventType': 'ai_help_opened',
    });
    await firestore.collection('interactionEvents').add(<String, dynamic>{
      'siteId': 'site-1',
      'actorId': 'learner-1',
      'eventType': 'ai_help_opened',
    });
    await firestore.collection('interactionEvents').add(<String, dynamic>{
      'siteId': 'site-1',
      'actorId': 'learner-1',
      'eventType': 'ai_help_used',
    });
    await firestore.collection('interactionEvents').add(<String, dynamic>{
      'siteId': 'site-1',
      'actorId': 'learner-1',
      'eventType': 'explain_it_back_submitted',
    });
    await firestore.collection('interactionEvents').add(<String, dynamic>{
      'siteId': 'site-1',
      'actorId': 'learner-2',
      'eventType': 'ai_help_opened',
    });
    await firestore.collection('interactionEvents').add(<String, dynamic>{
      'siteId': 'site-1',
      'actorId': 'learner-2',
      'eventType': 'explain_it_back_submitted',
    });
    await firestore.collection('interactionEvents').add(<String, dynamic>{
      'siteId': 'other-site',
      'actorId': 'learner-3',
      'eventType': 'ai_help_opened',
    });
    await firestore.collection('interactionEvents').add(<String, dynamic>{
      'actorId': 'learner-missing-site',
      'eventType': 'ai_help_opened',
    });
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        appState: _buildSiteState(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MiloOS Support Health'), findsOneWidget);
    expect(
      find.text(
          'Site-scoped support provenance and explain-back debt. Not capability mastery.'),
      findsOneWidget,
    );
    expect(find.text('Learners with support: 2'), findsOneWidget);
    expect(find.text('Learners pending: 1'), findsOneWidget);
    expect(find.text('Opened: 3'), findsOneWidget);
    expect(find.text('Used: 1'), findsOneWidget);
    expect(find.text('Explained: 2'), findsOneWidget);
    expect(find.text('Opened: 4'), findsNothing);
    expect(find.text('Opened: 5'), findsNothing);
    expect(find.textContaining('mastery: 100'), findsNothing);
  });

  testWidgets('site dashboard exports a real report when activity exists',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await firestore.collection('siteOpsEvents').doc('event-1').set(
      <String, dynamic>{
        'siteId': 'site-1',
        'action': 'Check-in',
        'createdAt': DateTime(2026, 3, 18, 10).millisecondsSinceEpoch,
      },
    );
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    ExportService.instance.debugSaveTextFile = ({
      required String fileName,
      required String content,
      required String mimeType,
    }) async {
      _savedFileName = fileName;
      _savedFileContent = content;
      return '/tmp/$fileName';
    };

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        appState: _buildSiteState(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.download));
    await tester.pumpAndSettle();

    expect(find.text('Site report exported.'), findsOneWidget);
    expect(_savedFileName, contains('site-dashboard'));
    expect(_savedFileContent, contains('Check-in'));
  });

  testWidgets('site dashboard copies report when file export is unsupported',
      (WidgetTester tester) async {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          final Object? args = methodCall.arguments;
          if (args is Map) {
            copiedText = args['text'] as String?;
          }
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await firestore.collection('siteOpsEvents').doc('event-1').set(
      <String, dynamic>{
        'siteId': 'site-1',
        'action': 'Check-in',
        'createdAt': DateTime(2026, 3, 18, 10).millisecondsSinceEpoch,
      },
    );
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    ExportService.instance.debugSaveTextFile = ({
      required String fileName,
      required String content,
      required String mimeType,
    }) async {
      throw UnsupportedError('File export is not supported on this platform.');
    };

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        appState: _buildSiteState(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.download));
    await tester.pumpAndSettle();

    expect(find.text('Site report copied for sharing.'), findsOneWidget);
    expect(copiedText, contains('Export Site Report'));
    expect(copiedText, contains('Check-in'));

    final QuerySnapshot<Map<String, dynamic>> events =
        await firestore.collection('siteOpsEvents').get();
    expect(
      events.docs.any(
        (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
            doc.data()['action'] == 'Export Site Report' &&
            doc.data()['status'] == 'copied',
      ),
      isTrue,
    );
  });

  testWidgets('site dashboard restores the selected period on reopen',
      (WidgetTester tester) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final FirestoreService firestoreService = FirestoreService(
      firestore: FakeFirebaseFirestore(),
      auth: _MockFirebaseAuth(),
    );
    final AppState appState = _buildSiteState();

    Widget buildHome() => _buildHarness(
          firestoreService: firestoreService,
          appState: appState,
          sharedPreferences: prefs,
        );

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    await tester.pumpWidget(buildHome());
    await tester.pumpAndSettle();

    final Finder termChip = find.text('Term');
    await tester.tap(termChip);
    await tester.pumpAndSettle();

    final Finder selectedTermChip = find.ancestor(
      of: termChip,
      matching: find.byWidgetPredicate(
        (Widget widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == ScholesaColors.site,
      ),
    );
    expect(selectedTermChip, findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await tester.pumpWidget(buildHome());
    await tester.pumpAndSettle();

    expect(
      find.ancestor(
        of: find.text('Term'),
        matching: find.byWidgetPredicate(
          (Widget widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color == ScholesaColors.site,
        ),
      ),
      findsWidgets,
    );
  });

  testWidgets('site dashboard shows a real KPI error instead of fake emptiness',
      (WidgetTester tester) async {
    final FirestoreService firestoreService = FirestoreService(
      firestore: FakeFirebaseFirestore(),
      auth: _MockFirebaseAuth(),
    );

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          Provider<FirestoreService>.value(value: firestoreService),
          ChangeNotifierProvider<AppState>.value(value: _buildSiteState()),
        ],
        child: MaterialApp(
          theme: ScholesaTheme.light,
          home: SiteDashboardPage(
            kpiPacksLoader: (String? siteId, int limit) async {
              throw StateError('kpi unavailable');
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('KPI packs are temporarily unavailable'), findsOneWidget);
    expect(
      find.text(
          'We could not load KPI packs right now. Retry to check the current state.'),
      findsOneWidget,
    );
    expect(find.text('No KPI packs yet'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets(
      'site dashboard keeps stale KPI pack visible after refresh failure',
      (WidgetTester tester) async {
    final FirestoreService firestoreService = FirestoreService(
      firestore: FakeFirebaseFirestore(),
      auth: _MockFirebaseAuth(),
    );
    int loadCount = 0;

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          Provider<FirestoreService>.value(value: firestoreService),
          ChangeNotifierProvider<AppState>.value(value: _buildSiteState()),
        ],
        child: MaterialApp(
          theme: ScholesaTheme.light,
          home: SiteDashboardPage(
            kpiPacksLoader: (String? siteId, int limit) async {
              loadCount += 1;
              if (loadCount == 1) {
                return <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'pack-1',
                    'title': 'March KPI Pack',
                    'period': 'month',
                    'recommendation': 'Keep evidence capture tight',
                    'status': 'ready',
                    'fidelityScore': 0.82,
                    'portfolioQualityGrade': 'A',
                    'updatedAt': '2026-03-18T10:00:00.000Z',
                  },
                ];
              }
              throw StateError('kpi refresh unavailable');
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('March KPI Pack'), findsOneWidget);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text(
          'Unable to refresh KPI packs right now. Showing the last successful data.'),
      findsOneWidget,
    );
    expect(find.text('March KPI Pack'), findsOneWidget);
    expect(find.text('No KPI packs yet'), findsNothing);
  });

  testWidgets(
      'site dashboard shows recent activity unavailable instead of fake emptiness',
      (WidgetTester tester) async {
    final FirestoreService firestoreService = FirestoreService(
      firestore: FakeFirebaseFirestore(),
      auth: _MockFirebaseAuth(),
    );

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        appState: _buildSiteState(),
        page: SiteDashboardPage(
          recentActivityLoader: (String siteId) async {
            throw StateError('activity unavailable');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recent activity is temporarily unavailable'),
        findsOneWidget);
    expect(
      find.text(
          'We could not load recent activity right now. Retry to check the current state.'),
      findsOneWidget,
    );
    expect(find.text('No recent activity yet'), findsNothing);
    expect(find.text('Retry'), findsWidgets);
  });

  testWidgets(
      'site dashboard keeps stale recent activity visible after refresh failure',
      (WidgetTester tester) async {
    final FirestoreService firestoreService = FirestoreService(
      firestore: FakeFirebaseFirestore(),
      auth: _MockFirebaseAuth(),
    );
    int loadCount = 0;

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        appState: _buildSiteState(),
        page: SiteDashboardPage(
          recentActivityLoader: (String siteId) async {
            loadCount += 1;
            if (loadCount == 1) {
              return <Map<String, dynamic>>[
                <String, dynamic>{
                  'icon': 'warning',
                  'color': 'warning',
                  'title': 'Incident reported',
                  'subtitle': 'Microscope kit spill in Studio B',
                  'time': 'just now',
                },
              ];
            }
            throw StateError('activity refresh unavailable');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Microscope kit spill in Studio B'), findsOneWidget);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text(
          'Unable to refresh recent activity right now. Showing the last successful data.'),
      findsOneWidget,
    );
    expect(find.text('Microscope kit spill in Studio B'), findsOneWidget);
    expect(find.text('No recent activity yet'), findsNothing);
  });
}
