import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/dashboards/role_dashboard.dart';
import 'package:scholesa_app/modules/educator/educator_models.dart';
import 'package:scholesa_app/modules/educator/educator_service.dart';
import 'package:scholesa_app/modules/educator/educator_today_page.dart';
import 'package:scholesa_app/modules/messages/message_service.dart';
import 'package:scholesa_app/runtime/bos_class_insights_card.dart';
import 'package:scholesa_app/modules/site/site_dashboard_page.dart';
import 'package:scholesa_app/services/export_service.dart';
import 'package:scholesa_app/services/firestore_service.dart';
import 'package:scholesa_app/ui/theme/scholesa_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ThemeData _testTheme = ScholesaTheme.light;

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockEducatorService extends Mock implements EducatorService {}

String? _savedFileName;
String? _savedFileContent;

void main() {
  group('Dashboard CTA regressions', () {
    setUp(() {
      _savedFileName = null;
      _savedFileContent = null;
      ExportService.instance.debugSaveTextFile = null;
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    testWidgets('role dashboard View All opens quick actions sheet',
        (WidgetTester tester) async {
      final AppState appState = AppState()
        ..updateFromMeResponse(<String, dynamic>{
          'userId': 'u-1',
          'email': 'site@scholesa.dev',
          'displayName': 'Site Admin',
          'role': 'site',
          'activeSiteId': 'site-1',
          'siteIds': <String>['site-1'],
          'entitlements': <Map<String, dynamic>>[],
        });
      final FirestoreService firestoreService = FirestoreService(
        firestore: FakeFirebaseFirestore(),
        auth: _MockFirebaseAuth(),
      );
      final MessageService messageService = MessageService(
        firestoreService: firestoreService,
        userId: appState.userId ?? 'u-1',
      );

      await tester.binding.setSurfaceSize(const Size(1280, 1800));
      await tester.pumpWidget(
        MultiProvider(
          providers: <SingleChildWidget>[
            Provider<FirestoreService>.value(value: firestoreService),
            ChangeNotifierProvider<AppState>.value(value: appState),
            ChangeNotifierProvider<MessageService>.value(value: messageService),
          ],
          child: MaterialApp(
            theme: _testTheme,
            home: RoleDashboard(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('View All').first);
      await tester.pumpAndSettle();

      expect(find.text('All Quick Actions'), findsOneWidget);
      expect(find.byType(ListTile), findsWidgets);
      expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    });

    testWidgets('site dashboard export CTA downloads a real report when data exists',
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
      final AppState appState = AppState()
        ..updateFromMeResponse(<String, dynamic>{
          'userId': 'site-1-admin',
          'email': 'site@scholesa.dev',
          'displayName': 'Site Admin',
          'role': 'site',
          'activeSiteId': 'site-1',
          'siteIds': <String>['site-1'],
          'entitlements': <Map<String, dynamic>>[],
        });
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
        MultiProvider(
          providers: <SingleChildWidget>[
            Provider<FirestoreService>.value(value: firestoreService),
            ChangeNotifierProvider<AppState>.value(value: appState),
          ],
          child: MaterialApp(
            theme: _testTheme,
            home: SiteDashboardPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.download));
      await tester.pumpAndSettle();

      expect(find.text('Site report exported.'), findsOneWidget);
      expect(_savedFileName, contains('site-dashboard'));
      expect(_savedFileContent, isNotNull);
      expect(_savedFileContent, contains('Export Site Report'));
      expect(_savedFileContent, contains('Recent Activity'));
      expect(_savedFileContent, contains('Check-in'));
    });

    testWidgets('site dashboard export CTA copies report when file export is unsupported',
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
      final AppState appState = AppState()
        ..updateFromMeResponse(<String, dynamic>{
          'userId': 'site-1-admin',
          'email': 'site@scholesa.dev',
          'displayName': 'Site Admin',
          'role': 'site',
          'activeSiteId': 'site-1',
          'siteIds': <String>['site-1'],
          'entitlements': <Map<String, dynamic>>[],
        });
      ExportService.instance.debugSaveTextFile = ({
        required String fileName,
        required String content,
        required String mimeType,
      }) async {
        throw UnsupportedError('File export is not supported on this platform.');
      };
      await tester.binding.setSurfaceSize(const Size(1280, 1800));
      await tester.pumpWidget(
        MultiProvider(
          providers: <SingleChildWidget>[
            Provider<FirestoreService>.value(value: firestoreService),
            ChangeNotifierProvider<AppState>.value(value: appState),
          ],
          child: MaterialApp(
            theme: _testTheme,
            home: SiteDashboardPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.download));
      await tester.pumpAndSettle();

      expect(find.text('Site report copied for sharing.'), findsOneWidget);
      expect(copiedText, contains('Export Site Report'));
      expect(copiedText, contains('Check-in'));
    });

    testWidgets('site dashboard activity View All opens bottom sheet',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1800));
      await tester.pumpWidget(
        MaterialApp(
          theme: _testTheme,
          home: SiteDashboardPage(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('View All').first);
      await tester.pumpAndSettle();

      expect(find.text('All Recent Activity'), findsOneWidget);
      expect(find.text('No recent activity yet'), findsNWidgets(2));
    });

    testWidgets('site dashboard hides disconnected pillar telemetry card',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1800));
      await tester.pumpWidget(
        MaterialApp(
          theme: _testTheme,
          home: SiteDashboardPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pillar Progress (Site Average)'), findsNothing);
      expect(
        find.text(
            'Pillar progress telemetry is not available for this site yet.'),
        findsNothing,
      );
      expect(
        find.text(
          'This breakdown will appear after learner progress telemetry is connected.',
        ),
        findsNothing,
      );
    });

    testWidgets('site dashboard empty analytics cards render in dark theme',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1800));
      await tester.pumpWidget(
        MaterialApp(
          theme: ScholesaTheme.dark,
          home: SiteDashboardPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Telemetry KPIs'), findsOneWidget);
      expect(
        find.text('Waiting for first app telemetry sync.'),
        findsOneWidget,
      );
      expect(find.text('KPI Packs'), findsOneWidget);
    });

    testWidgets('educator today page shows BOS class insights watchlist',
        (WidgetTester tester) async {
      final _MockEducatorService educatorService = _MockEducatorService();
      final AppState appState = AppState()
        ..updateFromMeResponse(<String, dynamic>{
          'userId': 'educator-1',
          'email': 'educator@scholesa.dev',
          'displayName': 'Educator',
          'role': 'educator',
          'activeSiteId': 'site-1',
          'siteIds': <String>['site-1'],
          'entitlements': <Map<String, dynamic>>[],
        });

      final TodayClass todayClass = TodayClass(
        id: 'occ-1',
        sessionId: 'session-1',
        title: 'Future Skills Studio',
        startTime: DateTime(2026, 3, 13, 9),
        endTime: DateTime(2026, 3, 13, 10),
        enrolledCount: 12,
        presentCount: 10,
        status: 'in_progress',
      );
      final List<EducatorLearner> learners = <EducatorLearner>[
        const EducatorLearner(
          id: 'learner-1',
          name: 'Avery Chen',
          email: 'avery@scholesa.test',
          attendanceRate: 92,
          missionsCompleted: 7,
          pillarProgress: <String, double>{},
          enrolledSessionIds: <String>['session-1'],
        ),
        const EducatorLearner(
          id: 'learner-2',
          name: 'Noah Lin',
          email: 'noah@scholesa.test',
          attendanceRate: 88,
          missionsCompleted: 5,
          pillarProgress: <String, double>{},
          enrolledSessionIds: <String>['session-1'],
        ),
      ];

      when(() => educatorService.loadTodaySchedule()).thenAnswer((_) async {});
      when(() => educatorService.loadLearners()).thenAnswer((_) async {});
      when(() => educatorService.isLoading).thenReturn(false);
      when(() => educatorService.todayClasses)
          .thenReturn(<TodayClass>[todayClass]);
      when(() => educatorService.currentClass).thenReturn(todayClass);
      when(() => educatorService.learners).thenReturn(learners);
      when(() => educatorService.dayStats).thenReturn(
        const EducatorDayStats(
          totalClasses: 1,
          completedClasses: 0,
          totalLearners: 12,
          presentLearners: 10,
          missionsToReview: 3,
          unreadMessages: 1,
        ),
      );
      when(() => educatorService.siteId).thenReturn('site-1');

      await tester.binding.setSurfaceSize(const Size(1280, 1800));
      await tester.pumpWidget(
        MultiProvider(
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<AppState>.value(value: appState),
            ChangeNotifierProvider<EducatorService>.value(
                value: educatorService),
          ],
          child: MaterialApp(
            theme: _testTheme,
            home: EducatorTodayPage(
              classInsightsLoader: ({
                required String sessionOccurrenceId,
                required String siteId,
              }) async =>
                  <String, dynamic>{
                'sessionOccurrenceId': sessionOccurrenceId,
                'siteId': siteId,
                'learnerCount': 2,
                'activeMvlCount': 1,
                'averages': <String, double>{
                  'cognition': 0.58,
                  'engagement': 0.49,
                  'integrity': 0.71,
                },
                'learners': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'learnerId': 'learner-1',
                    'x_hat': <String, double>{
                      'cognition': 0.32,
                      'engagement': 0.41,
                      'integrity': 0.62,
                    },
                  },
                  <String, dynamic>{
                    'learnerId': 'learner-2',
                    'x_hat': <String, double>{
                      'cognition': 0.84,
                      'engagement': 0.66,
                      'integrity': 0.76,
                    },
                  },
                ],
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
      expect(find.text('Class Support Snapshot'), findsOneWidget);
      expect(find.text('Learners Who May Need Support'), findsOneWidget);
      expect(find.textContaining('Avery Chen'), findsOneWidget);
      expect(find.text('View Support List'), findsOneWidget);

      await tester.tap(find.text('View Support List'));
      await tester.pumpAndSettle();

      expect(
          find.text('Support recommended for these learners'), findsOneWidget);
      expect(find.text('Avery Chen'), findsWidgets);
    });

    testWidgets('educator today page renders on mobile without overflow',
        (WidgetTester tester) async {
      final _MockEducatorService educatorService = _MockEducatorService();
      final AppState appState = AppState()
        ..updateFromMeResponse(<String, dynamic>{
          'userId': 'educator-1',
          'email': 'educator@scholesa.dev',
          'displayName': 'Educator',
          'role': 'educator',
          'activeSiteId': 'site-1',
          'siteIds': <String>['site-1'],
          'entitlements': <Map<String, dynamic>>[],
        });

      final TodayClass todayClass = TodayClass(
        id: 'occ-1',
        sessionId: 'session-1',
        title: 'Future Skills Studio',
        location: 'Room A - Robotics Wing',
        startTime: DateTime(2026, 3, 13, 9),
        endTime: DateTime(2026, 3, 13, 10),
        enrolledCount: 12,
        presentCount: 10,
        status: 'in_progress',
      );
      final List<EducatorLearner> learners = <EducatorLearner>[
        const EducatorLearner(
          id: 'learner-1',
          name: 'Avery Chen',
          email: 'avery@scholesa.test',
          attendanceRate: 92,
          missionsCompleted: 7,
          pillarProgress: <String, double>{},
          enrolledSessionIds: <String>['session-1'],
        ),
      ];

      when(() => educatorService.loadTodaySchedule()).thenAnswer((_) async {});
      when(() => educatorService.loadLearners()).thenAnswer((_) async {});
      when(() => educatorService.isLoading).thenReturn(false);
      when(() => educatorService.todayClasses)
          .thenReturn(<TodayClass>[todayClass]);
      when(() => educatorService.currentClass).thenReturn(todayClass);
      when(() => educatorService.learners).thenReturn(learners);
      when(() => educatorService.dayStats).thenReturn(
        const EducatorDayStats(
          totalClasses: 1,
          completedClasses: 0,
          totalLearners: 12,
          presentLearners: 10,
          missionsToReview: 3,
          unreadMessages: 1,
        ),
      );
      when(() => educatorService.siteId).thenReturn('site-1');

      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(
        MultiProvider(
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<AppState>.value(value: appState),
            ChangeNotifierProvider<EducatorService>.value(
                value: educatorService),
          ],
          child: MaterialApp(
            theme: _testTheme,
            home: EducatorTodayPage(
              classInsightsLoader: ({
                required String sessionOccurrenceId,
                required String siteId,
              }) async =>
                  <String, dynamic>{
                'sessionOccurrenceId': sessionOccurrenceId,
                'siteId': siteId,
                'learnerCount': 1,
                'activeMvlCount': 0,
                'averages': <String, double>{
                  'cognition': 0.41,
                  'engagement': 0.52,
                  'integrity': 0.63,
                },
                'learners': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'learnerId': 'learner-1',
                    'x_hat': <String, double>{
                      'cognition': 0.32,
                      'engagement': 0.41,
                      'integrity': 0.62,
                    },
                  },
                ],
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
      expect(find.byType(EducatorTodayPage), findsOneWidget);
      expect(find.text('Class Support Snapshot'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'class insights uses learner unavailable when identity is missing',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(
        MaterialApp(
          theme: _testTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: BosClassInsightsCard(
                title: 'Class Support Snapshot',
                subtitle:
                  'Class learning signals, learners who may need support, and active understanding checks',
                emptyLabel: 'No class insights yet',
                sessionOccurrenceId: 'occ-1',
                siteId: 'site-1',
                learnerNamesById: const <String, String>{},
                insightsLoader: ({
                  required String sessionOccurrenceId,
                  required String siteId,
                }) async =>
                    <String, dynamic>{
                  'sessionOccurrenceId': sessionOccurrenceId,
                  'siteId': siteId,
                  'learnerCount': 1,
                  'activeMvlCount': 0,
                  'averages': <String, double>{
                    'cognition': 0.41,
                    'engagement': 0.52,
                    'integrity': 0.63,
                  },
                  'learners': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'learnerId': 'anon-7f9c',
                      'x_hat': <String, double>{
                        'cognition': 0.32,
                        'engagement': 0.41,
                        'integrity': 0.62,
                      },
                    },
                  ],
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.textContaining('Learner unavailable'), findsOneWidget);
      expect(find.text('Learner 7f9c'), findsNothing);
      await tester.tap(find.text('View Support List'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Learner unavailable'), findsWidgets);
      expect(find.text('Learner 7f9c'), findsNothing);
    });
  });
}
