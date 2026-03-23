import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/site/site_sessions_page.dart';
import 'package:scholesa_app/services/firestore_service.dart';
import 'package:scholesa_app/ui/theme/scholesa_theme.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

bool _isSameCalendarDate(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

Widget _buildHarness({required Widget child}) {
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

AppState _buildSiteState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'site-admin-1',
    'email': 'site-admin-1@scholesa.test',
    'displayName': 'Site Admin',
    'role': 'site',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'localeCode': 'en',
    'entitlements': <Map<String, dynamic>>[],
  });
  return state;
}

Future<void> _seedSessionCreateOptions(FakeFirebaseFirestore firestore) async {
  await firestore.collection('users').doc('educator-1').set(<String, dynamic>{
    'displayName': 'Coach Ada',
    'email': 'ada@scholesa.test',
    'role': 'educator',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
  });
  await firestore.collection('rooms').doc('room-1').set(<String, dynamic>{
    'siteId': 'site-1',
    'name': 'Lab 1',
  });
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

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('Unable to load sessions'), findsOneWidget);
    expect(
      find.text(
          'We could not load sessions right now. Retry to check the current state.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsOneWidget);
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

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
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
      find.text(
        'Unable to refresh sessions right now. Showing the last successful data.',
      ),
      findsOneWidget,
    );
    expect(find.text('Today Advisory'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsOneWidget);
    expect(loadCount, 8);
  });

  testWidgets(
      'site sessions view mode changes visible schedule content and persists on reopen',
      (WidgetTester tester) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final DateTime today = DateUtils.dateOnly(DateTime.now());
    final DateTime monthDate = _sameMonthDifferentWeekDate(today);
    final DateTime weekStart =
        today.subtract(Duration(days: today.weekday - 1));
    final DateTime weekEnd = weekStart.add(const Duration(days: 6));

    bool _isSameWeek(DateTime candidate) {
      final DateTime normalized = DateUtils.dateOnly(candidate);
      return !normalized.isBefore(weekStart) && !normalized.isAfter(weekEnd);
    }

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
          if (_isSameWeek(selectedDate)) {
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
    expect(find.text('Month Showcase'), findsNothing);

    await tester.tap(find.text('Day'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Today Advisory'), findsOneWidget);
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

  testWidgets(
      'site sessions create persists and reloads the authoritative schedule state',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));

    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedSessionCreateOptions(firestore);
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final AppState appState = _buildSiteState();
    int loadCount = 0;

    await tester.pumpWidget(
      _buildHarness(
        child: MultiProvider(
          providers: <SingleChildWidget>[
            Provider<FirestoreService>.value(value: firestoreService),
            ChangeNotifierProvider<AppState>.value(value: appState),
          ],
          child: SiteSessionsPage(
            sessionsLoader: (
              BuildContext context,
              DateTime selectedDate,
            ) async {
              loadCount += 1;
              final QuerySnapshot<Map<String, dynamic>> snapshot =
                  await firestore.collection('sessions').get();
              final Map<String, List<SiteSessionData>> grouped =
                  <String, List<SiteSessionData>>{};
              for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                  in snapshot.docs) {
                final Map<String, dynamic> data = doc.data();
                if ((data['siteId'] as String?) != 'site-1') {
                  continue;
                }
                final Timestamp? startTime = data['startTime'] as Timestamp?;
                final DateTime? sessionDate = startTime?.toDate();
                if (sessionDate == null ||
                    !_isSameCalendarDate(sessionDate, selectedDate)) {
                  continue;
                }
                final String slot =
                    (data['timeSlot'] as String?)?.trim().isNotEmpty == true
                        ? (data['timeSlot'] as String).trim()
                        : '4:00 PM';
                grouped.putIfAbsent(slot, () => <SiteSessionData>[]).add(
                      SiteSessionData(
                        title: '${data['title']} (persisted)',
                        educator:
                            (data['educatorName'] as String?) ?? 'Unassigned',
                        room: (data['room'] as String?) ?? 'Unassigned',
                        learnerCount: data['learnerCount'] as int? ?? 0,
                        pillar: (data['pillar'] as String?) ?? 'Future Skills',
                      ),
                    );
              }
              return grouped;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final int initialLoadCount = loadCount;

    await tester.tap(find.text('New Session'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Session Title'),
      'Evidence Studio',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Learner Count'),
      '12',
    );

    final Finder createButton =
        find.widgetWithText(ElevatedButton, 'Create Session');
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Evidence Studio (persisted)'), findsOneWidget);
    expect(find.text('Session created successfully'), findsOneWidget);
    expect(loadCount, greaterThan(initialLoadCount));

    final QuerySnapshot<Map<String, dynamic>> persistedSessions =
        await firestore
            .collection('sessions')
            .where('siteId', isEqualTo: 'site-1')
            .get();
    expect(persistedSessions.docs, hasLength(1));
    expect(persistedSessions.docs.single.data()['title'], 'Evidence Studio');
    expect(persistedSessions.docs.single.data()['createdBy'], 'site-admin-1');
    expect(persistedSessions.docs.single.data()['learnerCount'], 12);

    final QuerySnapshot<Map<String, dynamic>> persistedOccurrences =
        await firestore
            .collection('sessionOccurrences')
            .where('siteId', isEqualTo: 'site-1')
            .get();
    expect(persistedOccurrences.docs, hasLength(1));
    expect(
      persistedOccurrences.docs.single.data()['sessionId'],
      persistedSessions.docs.single.id,
    );
    expect(persistedOccurrences.docs.single.data()['title'], 'Evidence Studio');
    expect(
      persistedOccurrences.docs.single.data()['roomName'],
      persistedSessions.docs.single.data()['room'],
    );
  });

  testWidgets(
      'site sessions create failure stays explicit and does not append a fake session',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));

    final DateTime today = DateUtils.dateOnly(DateTime.now());
    int loadCount = 0;

    await tester.pumpWidget(
      _buildHarness(
        child: SiteSessionsPage(
          sessionsLoader: (
            BuildContext context,
            DateTime selectedDate,
          ) async {
            loadCount += 1;
            if (!_isSameCalendarDate(selectedDate, today)) {
              return <String, List<SiteSessionData>>{};
            }
            return <String, List<SiteSessionData>>{
              '9:00 AM': const <SiteSessionData>[
                SiteSessionData(
                  title: 'Existing Advisory',
                  educator: 'Coach Ada',
                  room: 'Lab 1',
                  learnerCount: 14,
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

    expect(find.text('Existing Advisory'), findsOneWidget);
    final int initialLoadCount = loadCount;

    await tester.tap(find.text('New Session'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Session Title'),
      'Failed Session',
    );

    final Finder createButton =
        find.widgetWithText(ElevatedButton, 'Create Session');
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Unable to create session right now'), findsOneWidget);
    expect(find.text('Session created successfully'), findsNothing);
    expect(find.text('Existing Advisory'), findsOneWidget);
    expect(find.text('Failed Session'), findsNothing);
    expect(loadCount, initialLoadCount);
  });

  testWidgets(
      'site sessions submits a persisted HQ mapping request for blocked sessions',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final AppState appState = _buildSiteState();

    await tester.pumpWidget(
      _buildHarness(
        child: MultiProvider(
          providers: <SingleChildWidget>[
            Provider<FirestoreService>.value(value: firestoreService),
            ChangeNotifierProvider<AppState>.value(value: appState),
          ],
          child: SiteSessionsPage(
            sessionsLoader: (
              BuildContext context,
              DateTime selectedDate,
            ) async {
              return <String, List<SiteSessionData>>{
                '9:00 AM': const <SiteSessionData>[
                  SiteSessionData(
                    id: 'session-1',
                    title: 'Impact Studio',
                    educator: 'Coach Ada',
                    room: 'Lab 1',
                    learnerCount: 14,
                    pillar: 'Impact',
                    mappedCapabilityCount: 0,
                  ),
                ],
              };
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Upcoming sessions blocked by capability mapping'),
        findsOneWidget);

    final Finder requestButton =
        find.widgetWithText(OutlinedButton, 'Request HQ mapping').first;
    await tester.ensureVisible(requestButton);
    await tester.tap(requestButton);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('HQ mapping request submitted.'), findsOneWidget);
    expect(find.text('HQ mapping request open'), findsWidgets);

    final QuerySnapshot<Map<String, dynamic>> supportRequests =
        await firestore.collection('supportRequests').get();
    expect(supportRequests.docs, hasLength(1));
    expect(
      supportRequests.docs.single.data()['requestType'],
      'session_capability_mapping',
    );
    expect(
      supportRequests.docs.single.data()['subject'],
      'Session capability mapping request: Impact Studio',
    );
    expect(
      (supportRequests.docs.single.data()['metadata']
          as Map<String, dynamic>)['sessionId'],
      'session-1',
    );
  });

  testWidgets(
      'site sessions surface a resolved HQ mapping handoff once capability coverage is available',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final AppState appState = _buildSiteState();
    final DateTime today = DateUtils.dateOnly(DateTime.now());

    await firestore.collection('sessions').doc('session-ready').set(
      <String, dynamic>{
        'siteId': 'site-1',
        'title': 'Future Skills Lab',
        'educatorName': 'Coach Ada',
        'room': 'Lab 1',
        'learnerCount': 16,
        'pillar': 'Future Skills',
        'startTime': Timestamp.fromDate(today.add(const Duration(hours: 9))),
      },
    );
    await firestore.collection('capabilities').doc('capability-1').set(
      <String, dynamic>{
        'title': 'Systems thinking',
        'pillarCode': 'FS',
        'siteId': 'site-1',
      },
    );
    await firestore.collection('supportRequests').doc('request-1').set(
      <String, dynamic>{
        'requestType': 'session_capability_mapping',
        'siteId': 'site-1',
        'userName': 'Site Admin',
        'role': 'site',
        'subject': 'Session capability mapping request: Future Skills Lab',
        'status': 'resolved',
        'submittedAt':
            Timestamp.fromDate(today.subtract(const Duration(days: 1))),
        'resolvedAt': Timestamp.fromDate(today),
        'updatedAt': Timestamp.fromDate(today),
        'resolutionSupportingCapabilityCount': 1,
        'resolutionSupportingCapabilityTitles': <String>['Systems thinking'],
        'metadata': <String, dynamic>{
          'sessionId': 'session-ready',
          'sessionTitle': 'Future Skills Lab',
          'pillar': 'Future Skills',
        },
      },
    );

    await tester.pumpWidget(
      _buildHarness(
        child: MultiProvider(
          providers: <SingleChildWidget>[
            Provider<FirestoreService>.value(value: firestoreService),
            ChangeNotifierProvider<AppState>.value(value: appState),
          ],
          child: const SiteSessionsPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Future Skills Lab'), findsOneWidget);
    expect(find.text('HQ resolved'), findsOneWidget);
    expect(
      find.text(
          'HQ resolved this request. Confirmed capabilities: Systems thinking'),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Request HQ mapping'),
        findsNothing);
  });
}
