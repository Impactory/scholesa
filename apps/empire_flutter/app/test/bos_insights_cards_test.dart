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
                title: 'MiloOS Learning Loop',
                subtitle: 'Latest individual improvement signal',
                emptyLabel: 'No learner loop data yet',
                learnerId: 'learner-1',
                learnerName: 'Avery Chen',
                insightsLoader: ({
                  required String siteId,
                  required String learnerId,
                  required int lookbackDays,
                }) async => <String, dynamic>{
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

      expect(find.text('Verified signal unavailable'), findsOneWidget);
      expect(find.textContaining('Mastery Validation 0/0/0'), findsNothing);
      expect(find.textContaining('Improvement Score'), findsNothing);
    });

    testWidgets('class insights renders unavailable counts for malformed payload',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _testTheme,
          home: Scaffold(
            body: BosClassInsightsCard(
              title: 'MiloOS Class Insights',
              subtitle:
                  'FDM state estimate, BAE watchlist, and active MVL gates for this class',
              emptyLabel: 'No class insights yet',
              sessionOccurrenceId: 'occ-1',
              siteId: 'site-1',
              learnerNamesById: const <String, String>{},
              insightsLoader: ({
                required String sessionOccurrenceId,
                required String siteId,
              }) async => <String, dynamic>{
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
        find.textContaining('Learners Tracked Verified signal unavailable'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Active MVL Gates Verified signal unavailable'),
        findsOneWidget,
      );
      expect(find.text('BAE Watchlist'), findsOneWidget);
      expect(find.textContaining('Cognition 41%'), findsWidgets);
      expect(
        find.textContaining('Engagement Verified signal unavailable'),
        findsWidgets,
      );
    });
  });
}