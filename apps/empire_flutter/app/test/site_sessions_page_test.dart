import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scholesa_app/modules/site/site_sessions_page.dart';
import 'package:scholesa_app/ui/theme/scholesa_theme.dart';

bool _isSameCalendarDate(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

Widget _buildHarness({required SiteSessionsPage child}) {
  return MaterialApp(
    theme: ScholesaTheme.light.copyWith(
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
    home: child,
  );
}

DateTime _sameMonthDifferentWeekDate(DateTime baseDate) {
  final DateTime monthStart = DateTime(baseDate.year, baseDate.month, 1);
  final DateTime nextMonth = DateTime(baseDate.year, baseDate.month + 1, 1);
  final int daysInMonth = nextMonth.difference(monthStart).inDays;
  for (int offset = 8; offset < daysInMonth; offset += 1) {
    final DateTime candidate = monthStart.add(Duration(days: offset));
    if (candidate.month != baseDate.month) {
      break;
    }
    final bool sameWeek =
        candidate.subtract(Duration(days: candidate.weekday - 1)).day ==
            baseDate.subtract(Duration(days: baseDate.weekday - 1)).day &&
        candidate.subtract(Duration(days: candidate.weekday - 1)).month ==
            baseDate.subtract(Duration(days: baseDate.weekday - 1)).month;
    if (!sameWeek) {
      return candidate;
    }
  }
  return baseDate.add(const Duration(days: 14));
}

DateTime _sameWeekSameMonthDate(DateTime baseDate) {
  final DateTime weekStart =
      baseDate.subtract(Duration(days: baseDate.weekday - 1));
  for (int offset = 0; offset < 7; offset += 1) {
    final DateTime candidate = weekStart.add(Duration(days: offset));
    if (!_isSameCalendarDate(candidate, baseDate) &&
        candidate.month == baseDate.month) {
      return candidate;
    }
  }
  return baseDate;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
      'site sessions page shows an explicit load error instead of an empty schedule',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildHarness(
        child: SiteSessionsPage(
          sessionsLoader: (
            BuildContext context,
            DateTime selectedDate,
          ) async {
            throw StateError('schedule backend unavailable');
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Unable to load sessions'), findsOneWidget);
    expect(
      find.text('Failed to load sessions: Bad state: schedule backend unavailable'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('No sessions scheduled'), findsNothing);
  });

  testWidgets('site sessions page reloads data when navigating the calendar',
      (WidgetTester tester) async {
    final DateTime today = DateUtils.dateOnly(DateTime.now());
    final DateTime nextWeek = today.add(const Duration(days: 7));

    await tester.pumpWidget(
      _buildHarness(
        child: SiteSessionsPage(
          sessionsLoader: (
            BuildContext context,
            DateTime selectedDate,
          ) async {
            if (_isSameCalendarDate(selectedDate, nextWeek)) {
              return <String, List<SiteSessionData>>{
                '11:00 AM': const <SiteSessionData>[
                  SiteSessionData(
                    title: 'Next Week Lab',
                    educator: 'Educator Two',
                    room: 'Room B',
                    learnerCount: 18,
                    pillar: 'Impact',
                  ),
                ],
              };
            }

            if (!_isSameCalendarDate(selectedDate, today)) {
              return <String, List<SiteSessionData>>{};
            }

            return <String, List<SiteSessionData>>{
              '9:00 AM': const <SiteSessionData>[
                SiteSessionData(
                  title: 'Today Advisory',
                  educator: 'Educator One',
                  room: 'Room A',
                  learnerCount: 16,
                  pillar: 'Future Skills',
                ),
              ],
            };
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Today Advisory'), findsOneWidget);
    expect(find.text('Next Week Lab'), findsNothing);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Next Week Lab'), findsOneWidget);
    expect(find.text('Today Advisory'), findsNothing);
  });

  testWidgets(
      'site sessions page keeps the last loaded schedule visible when a later reload fails',
      (WidgetTester tester) async {
    int loadCount = 0;

    await tester.pumpWidget(
      _buildHarness(
        child: SiteSessionsPage(
          sessionsLoader: (
            BuildContext context,
            DateTime selectedDate,
          ) async {
            loadCount += 1;
            if (loadCount > 7) {
              throw StateError('next week temporarily unavailable');
            }
            if (!_isSameCalendarDate(
              selectedDate,
              DateUtils.dateOnly(DateTime.now()),
            )) {
              return <String, List<SiteSessionData>>{};
            }
            return <String, List<SiteSessionData>>{
              '9:00 AM': const <SiteSessionData>[
                SiteSessionData(
                  title: 'Today Advisory',
                  educator: 'Educator One',
                  room: 'Room A',
                  learnerCount: 16,
                  pillar: 'Future Skills',
                ),
              ],
            };
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Today Advisory'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Showing last loaded session schedule.'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Failed to load sessions: Bad state: next week temporarily unavailable',
      ),
      findsOneWidget,
    );
    expect(find.text('Today Advisory'), findsOneWidget);
    expect(loadCount, 8);
  });

  testWidgets(
      'site sessions view mode changes visible schedule content and persists on reopen',
      (WidgetTester tester) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final DateTime today = DateUtils.dateOnly(DateTime.now());
    final DateTime weekDate = _sameWeekSameMonthDate(today);
    final DateTime monthDate = _sameMonthDifferentWeekDate(today);

    SiteSessionsPage buildPage() {
      return SiteSessionsPage(
        sharedPreferences: prefs,
        sessionsLoader: (
          BuildContext context,
          DateTime selectedDate,
        ) async {
          if (_isSameCalendarDate(selectedDate, today)) {
            return <String, List<SiteSessionData>>{
              '9:00 AM': const <SiteSessionData>[
                SiteSessionData(
                  title: 'Today Advisory',
                  educator: 'Educator One',
                  room: 'Room A',
                  learnerCount: 16,
                  pillar: 'Future Skills',
                ),
              ],
            };
          }
          if (_isSameCalendarDate(selectedDate, weekDate)) {
            return <String, List<SiteSessionData>>{
              '11:00 AM': const <SiteSessionData>[
                SiteSessionData(
                  title: 'Week Studio',
                  educator: 'Educator Two',
                  room: 'Room B',
                  learnerCount: 18,
                  pillar: 'Leadership',
                ),
              ],
            };
          }
          if (_isSameCalendarDate(selectedDate, monthDate)) {
            return <String, List<SiteSessionData>>{
              '1:30 PM': const <SiteSessionData>[
                SiteSessionData(
                  title: 'Month Showcase',
                  educator: 'Educator Three',
                  room: 'Room C',
                  learnerCount: 24,
                  pillar: 'Impact',
                ),
              ],
            };
          }
          return <String, List<SiteSessionData>>{};
        },
      );
    }

    await tester.pumpWidget(
      _buildHarness(
        child: buildPage(),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Today Advisory'), findsOneWidget);
    expect(find.text('Week Studio'), findsOneWidget);
    expect(find.text('Month Showcase'), findsNothing);

    await tester.tap(find.text('Day'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Today Advisory'), findsOneWidget);
    expect(find.text('Week Studio'), findsNothing);
    expect(find.text('Month Showcase'), findsNothing);

    await tester.tap(find.text('Month'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Month Showcase'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      _buildHarness(
        child: buildPage(),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Month Showcase'), findsOneWidget);
  });
}
