import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/educator/educator_models.dart';
import 'package:scholesa_app/modules/educator/educator_service.dart';
import 'package:scholesa_app/modules/educator/educator_today_page.dart';
import 'package:scholesa_app/ui/theme/scholesa_theme.dart';

class _MockEducatorService extends Mock implements EducatorService {}

AppState _buildAppState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'educator-1',
    'email': 'educator-1@scholesa.test',
    'displayName': 'Educator One',
    'role': 'educator',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'entitlements': <Map<String, dynamic>>[],
  });
  return state;
}

Widget _buildHarness({
  required AppState appState,
  required EducatorService educatorService,
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: appState),
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
      home: EducatorTodayPage(
        classInsightsLoader: ({
          required String sessionOccurrenceId,
          required String siteId,
        }) async =>
            <String, dynamic>{
          'sessionOccurrenceId': sessionOccurrenceId,
          'siteId': siteId,
          'learners': <Map<String, dynamic>>[],
        },
      ),
    ),
  );
}

void main() {
  testWidgets(
      'educator today shows honest empty schedule and unavailable stats on mobile',
      (WidgetTester tester) async {
    final AppState appState = _buildAppState();
    final _MockEducatorService educatorService = _MockEducatorService();

    when(() => educatorService.loadTodaySchedule()).thenAnswer((_) async {});
    when(() => educatorService.loadLearners()).thenAnswer((_) async {});
    when(() => educatorService.isLoading).thenReturn(false);
    when(() => educatorService.todayClasses).thenReturn(const <TodayClass>[]);
    when(() => educatorService.currentClass).thenReturn(null);
    when(() => educatorService.learners)
        .thenReturn(const <EducatorLearner>[]);
    when(() => educatorService.dayStats).thenReturn(null);
    when(() => educatorService.siteId).thenReturn('site-1');

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      _buildHarness(
        appState: appState,
        educatorService: educatorService,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('No class in progress'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('No class in progress'), findsOneWidget);
    expect(
      find.text('Your next class will appear here when schedule data syncs.'),
      findsOneWidget,
    );
    expect(find.text('--'), findsNWidgets(3));
    expect(find.text('0/0'), findsNothing);
    expect(find.text('0%'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('No classes scheduled yet'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('No classes scheduled yet'), findsOneWidget);
    expect(
      find.text('Add or sync classes to populate today’s schedule.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'educator today review dialog reflects zero pending reviews without fake backlog',
      (WidgetTester tester) async {
    final AppState appState = _buildAppState();
    final _MockEducatorService educatorService = _MockEducatorService();

    when(() => educatorService.loadTodaySchedule()).thenAnswer((_) async {});
    when(() => educatorService.loadLearners()).thenAnswer((_) async {});
    when(() => educatorService.isLoading).thenReturn(false);
    when(() => educatorService.todayClasses).thenReturn(const <TodayClass>[]);
    when(() => educatorService.currentClass).thenReturn(null);
    when(() => educatorService.learners)
        .thenReturn(const <EducatorLearner>[]);
    when(() => educatorService.dayStats).thenReturn(
      const EducatorDayStats(
        totalClasses: 0,
        completedClasses: 0,
        totalLearners: 0,
        presentLearners: 0,
        missionsToReview: 0,
        unreadMessages: 0,
      ),
    );
    when(() => educatorService.siteId).thenReturn('site-1');

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      _buildHarness(
        appState: appState,
        educatorService: educatorService,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Review Missions'));
    await tester.pumpAndSettle();

    expect(find.text('Mission Review Queue'), findsOneWidget);
    expect(find.text('You have 0 missions pending review today.'), findsOneWidget);
    expect(find.text('Open Queue'), findsOneWidget);
  });

  testWidgets(
      'educator today shows schedule load failure instead of fake empty schedule',
      (WidgetTester tester) async {
    final AppState appState = _buildAppState();
    final _MockEducatorService educatorService = _MockEducatorService();

    when(() => educatorService.loadTodaySchedule()).thenAnswer((_) async {});
    when(() => educatorService.loadLearners()).thenAnswer((_) async {});
    when(() => educatorService.isLoading).thenReturn(false);
    when(() => educatorService.todayClasses).thenReturn(const <TodayClass>[]);
    when(() => educatorService.currentClass).thenReturn(null);
    when(() => educatorService.learners)
        .thenReturn(const <EducatorLearner>[]);
    when(() => educatorService.dayStats).thenReturn(null);
    when(() => educatorService.error)
        .thenReturn('Failed to load schedule from test');
    when(() => educatorService.siteId).thenReturn('site-1');

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      _buildHarness(
        appState: appState,
        educatorService: educatorService,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text("Unable to load today's schedule"),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text("Unable to load today's schedule"), findsOneWidget);
    expect(
      find.text(
          "We could not load today's schedule right now. Retry to check the current state."),
      findsOneWidget,
    );
    expect(find.text('Failed to load schedule from test'), findsOneWidget);
    expect(find.text('No classes scheduled yet'), findsNothing);
    expect(find.byTooltip('Refresh'), findsOneWidget);
  });

  testWidgets(
      'educator today keeps stale schedule visible after refresh failure',
      (WidgetTester tester) async {
    final AppState appState = _buildAppState();
    final _MockEducatorService educatorService = _MockEducatorService();
    final TodayClass staleClass = TodayClass(
      id: 'occ-1',
      sessionId: 'session-1',
      title: 'Robotics Studio',
      startTime: DateTime(2026, 3, 21, 9),
      endTime: DateTime(2026, 3, 21, 10),
      enrolledCount: 12,
      presentCount: 10,
      status: 'upcoming',
    );

    when(() => educatorService.loadTodaySchedule()).thenAnswer((_) async {});
    when(() => educatorService.loadLearners()).thenAnswer((_) async {});
    when(() => educatorService.isLoading).thenReturn(false);
    when(() => educatorService.todayClasses).thenReturn(<TodayClass>[staleClass]);
    when(() => educatorService.currentClass).thenReturn(null);
    when(() => educatorService.learners)
        .thenReturn(const <EducatorLearner>[]);
    when(() => educatorService.dayStats).thenReturn(
      const EducatorDayStats(
        totalClasses: 1,
        completedClasses: 0,
        totalLearners: 12,
        presentLearners: 10,
        missionsToReview: 1,
        unreadMessages: 0,
      ),
    );
    when(() => educatorService.error)
        .thenReturn('Failed to refresh schedule from test');
    when(() => educatorService.siteId).thenReturn('site-1');

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      _buildHarness(
        appState: appState,
        educatorService: educatorService,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(
      find.text(
        "Unable to refresh today's schedule right now. Showing the last successful data. Failed to refresh schedule from test",
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Robotics Studio'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Robotics Studio'), findsOneWidget);
    expect(find.text('No classes scheduled yet'), findsNothing);
  });
}
