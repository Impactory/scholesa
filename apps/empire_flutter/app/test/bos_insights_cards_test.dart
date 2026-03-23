import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/runtime/bos_class_insights_card.dart';
import 'package:scholesa_app/runtime/bos_learner_loop_insights_card.dart';

final ThemeData _testTheme = ThemeData(
  useMaterial3: true,
  splashFactory: InkRipple.splashFactory,
);

AppState _buildLearnerState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'learner-1',
    'email': 'learner@scholesa.dev',
    'displayName': 'Avery Chen',
    'role': 'learner',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'entitlements': <dynamic>[],
  });
  return state;
}

void main() {
  group('BOS insights cards', () {
    testWidgets('learner loop fails closed on malformed runtime payload',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<AppState>.value(value: _buildLearnerState()),
          ],
          child: MaterialApp(
            theme: _testTheme,
            home: Scaffold(
              body: BosLearnerLoopInsightsCard(
                title: 'Learning Support Snapshot',
                subtitle: 'Current learning signals for this learner',
                emptyLabel: 'No learning support snapshot yet',
                learnerId: 'learner-1',
                learnerName: 'Avery Chen',
                insightsLoader: ({
                  required String siteId,
                  required String learnerId,
                  required int lookbackDays,
                }) async =>
                    <String, dynamic>{
                  'state': <String, dynamic>{
                    'cognition': 'bad',
                  },
                  'trend': <String, dynamic>{
                    'engagementDelta': 'bad',
                  },
                  'mvl': <String, dynamic>{
                    'active': 'bad',
                    'passed': null,
                  },
                  'activeGoals': <dynamic>[7, null],
                  'stateAvailability': <String, dynamic>{
                    'hasCurrentState': 'bad',
                    'hasTrendBaseline': 'bad',
                  },
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.text('No current learning signals yet'), findsOneWidget);
      expect(find.textContaining('Mastery Validation 0/0/0'), findsNothing);
      expect(find.textContaining('Growth Trend'), findsNothing);
    });

    testWidgets(
        'class insights renders unavailable counts for malformed payload',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _testTheme,
          home: Scaffold(
            body: BosClassInsightsCard(
              title: 'Class Support Snapshot',
              subtitle:
                  'Current class learning signals, learners who may need support, and active understanding checks',
              emptyLabel: 'No class support snapshot yet',
              sessionOccurrenceId: 'occ-1',
              siteId: 'site-1',
              learnerNamesById: const <String, String>{},
              insightsLoader: ({
                required String sessionOccurrenceId,
                required String siteId,
              }) async =>
                  <String, dynamic>{
                'learnerCount': 'bad',
                'activeMvlCount': 'bad',
                'averages': <String, dynamic>{
                  'cognition': 0.41,
                  'engagement': 'bad',
                  'integrity': 0.63,
                },
                'coverage': <String, dynamic>{
                  'cognition': 'bad',
                },
                'watchlist': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'learnerId': 'learner-1',
                    'x_hat': <String, dynamic>{
                      'cognition': 0.32,
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

      expect(
        find.textContaining('Learners Tracked No current learning signals yet'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
            'Active Understanding Checks No current learning signals yet'),
        findsOneWidget,
      );
      expect(find.text('Learners Who May Need Support'), findsOneWidget);
      expect(find.textContaining('Cognition 41%'), findsWidgets);
      expect(
        find.textContaining('Engagement No current learning signals yet'),
        findsWidgets,
      );
    });

    testWidgets('learner loop discloses synthetic preview payloads',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<AppState>.value(value: _buildLearnerState()),
          ],
          child: MaterialApp(
            theme: _testTheme,
            home: Scaffold(
              body: BosLearnerLoopInsightsCard(
                title: 'Learning Support Snapshot',
                subtitle: 'Current learning signals for this learner',
                emptyLabel: 'No learning support snapshot yet',
                learnerId: 'learner-1',
                learnerName: 'Avery Chen',
                insightsLoader: ({
                  required String siteId,
                  required String learnerId,
                  required int lookbackDays,
                }) async =>
                    <String, dynamic>{
                  'synthetic': true,
                  'state': <String, dynamic>{
                    'cognition': 0.72,
                    'engagement': 0.68,
                    'integrity': 0.91,
                  },
                  'trend': <String, dynamic>{
                    'improvementScore': 0.08,
                    'cognitionDelta': 0.04,
                    'engagementDelta': 0.02,
                    'integrityDelta': 0.01,
                  },
                  'mvl': <String, dynamic>{
                    'active': 1,
                    'passed': 2,
                    'failed': 0,
                  },
                  'activeGoals': <String>['Prototype feedback loop'],
                  'stateAvailability': <String, dynamic>{
                    'hasCurrentState': true,
                    'hasTrendBaseline': true,
                  },
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Synthetic preview only. Do not treat this as classroom evidence or learner growth.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('class insights discloses synthetic preview payloads',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _testTheme,
          home: Scaffold(
            body: BosClassInsightsCard(
              title: 'Class Support Snapshot',
              subtitle:
                  'Verified class learning signals, learners who may need support, and active understanding checks',
              emptyLabel: 'No class support snapshot yet',
              sessionOccurrenceId: 'occ-1',
              siteId: 'site-1',
              learnerNamesById: const <String, String>{
                'learner-1': 'Avery Chen',
              },
              insightsLoader: ({
                required String sessionOccurrenceId,
                required String siteId,
              }) async =>
                  <String, dynamic>{
                'synthetic': true,
                'learnerCount': 1,
                'activeMvlCount': 0,
                'averages': <String, dynamic>{
                  'cognition': 0.61,
                  'engagement': 0.57,
                  'integrity': 0.88,
                },
                'coverage': <String, dynamic>{
                  'cognition': 1,
                  'engagement': 1,
                  'integrity': 1,
                },
                'watchlist': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'learnerId': 'learner-1',
                    'x_hat': <String, dynamic>{
                      'cognition': 0.41,
                      'engagement': 0.44,
                      'integrity': 0.9,
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

      expect(
        find.text(
          'Synthetic preview only. Do not treat this as classroom evidence or learner growth.',
        ),
        findsOneWidget,
      );
    });
  });
}
