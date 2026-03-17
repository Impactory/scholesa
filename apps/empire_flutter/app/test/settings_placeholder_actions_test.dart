import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/settings/settings_page.dart';
import 'package:scholesa_app/services/theme_service.dart';

AppState _buildAppState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'site-user-1',
    'email': 'site-user-1@scholesa.test',
    'displayName': 'Site Lead',
    'role': 'site',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'localeCode': 'en',
    'entitlements': <dynamic>[],
  });
  return state;
}

Widget _buildHarness({required List<SingleChildWidget> providers}) {
  return MultiProvider(
    providers: providers,
    child: MaterialApp(
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
      home: const SettingsPage(),
    ),
  );
}

Finder _tileTapTarget(String label) {
  return find.ancestor(
    of: find.text(label),
    matching: find.byType(InkWell),
  ).first;
}

void main() {
  testWidgets('settings shows explicit unavailable messaging for data export and rating',
      (WidgetTester tester) async {
    final AppState state = _buildAppState();
    final ThemeService themeService = ThemeService();
    await tester.binding.setSurfaceSize(const Size(1000, 1800));

    await tester.pumpWidget(
      _buildHarness(
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AppState>.value(value: state),
          ChangeNotifierProvider<ThemeService>.value(value: themeService),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Download My Data'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(_tileTapTarget('Download My Data'));
    await tester.pumpAndSettle();

    expect(find.text('Download My Data'), findsWidgets);
    expect(
      find.text(
        'Data export requests are not available in the app yet. Contact support with your site ID to request your data.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Close').last);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Rate the App'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(_tileTapTarget('Rate the App'));
    await tester.pumpAndSettle();

    expect(find.text('Rate the App'), findsWidgets);
    expect(
      find.text(
        'In-app rating is not available yet. Please rate Scholesa in your app store when the listing is live.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('settings feedback flow no longer claims feedback was sent',
      (WidgetTester tester) async {
    final AppState state = _buildAppState();
    final ThemeService themeService = ThemeService();
    await tester.binding.setSurfaceSize(const Size(1000, 1800));

    await tester.pumpWidget(
      _buildHarness(
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AppState>.value(value: state),
          ChangeNotifierProvider<ThemeService>.value(value: themeService),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Send Feedback'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(_tileTapTarget('Send Feedback'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Please improve the dashboard export flow.');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Feedback submission is not available in the app yet. Contact support if you need follow-up.',
      ),
      findsOneWidget,
    );
    expect(find.text('Feedback sent'), findsNothing);
  });
}
