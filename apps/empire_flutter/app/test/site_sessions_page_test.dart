import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
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

void main() {
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
            if (loadCount > 1) {
              throw StateError('next week temporarily unavailable');
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
    expect(loadCount, 2);
  });
}
