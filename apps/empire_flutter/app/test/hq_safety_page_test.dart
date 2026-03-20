import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/modules/hq_admin/hq_safety_page.dart';

Widget _buildHarness(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
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
  testWidgets('HQ safety shows an explicit unavailable state instead of a fake empty feed',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildHarness(
        HqSafetyPage(
          incidentsLoader: () async {
            throw StateError('safety backend unavailable');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Safety incidents are temporarily unavailable'), findsOneWidget);
    expect(
      find.text('We could not load safety incidents right now. Retry to check the current state.'),
      findsOneWidget,
    );
    expect(find.text('No incidents found'), findsNothing);
  });

  testWidgets('HQ safety keeps stale incidents visible when a refresh fails',
      (WidgetTester tester) async {
    int loadCalls = 0;

    await tester.pumpWidget(
      _buildHarness(
        HqSafetyPage(
          incidentsLoader: () async {
            loadCalls += 1;
            if (loadCalls == 1) {
              return <String, dynamic>{
                'incidents': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'incident-1',
                    'title': 'Playground injury',
                    'siteName': 'Alpha Studio',
                    'severity': 'major',
                    'updatedAt': DateTime(2026, 3, 20, 9).toIso8601String(),
                  },
                ],
              };
            }
            throw StateError('safety refresh unavailable');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Playground injury'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.refresh_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Playground injury'), findsOneWidget);
    expect(
      find.text('Unable to refresh safety incidents right now. Showing the last successful data.'),
      findsOneWidget,
    );
    expect(find.text('No incidents found'), findsNothing);
  });
}
