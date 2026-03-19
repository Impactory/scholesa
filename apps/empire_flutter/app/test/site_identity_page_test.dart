import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/site/site_identity_page.dart';

AppState _buildSiteState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'site-1-admin',
    'email': 'site-admin@scholesa.test',
    'displayName': 'Site Admin',
    'role': 'site',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'localeCode': 'en',
    'entitlements': const <Map<String, dynamic>>[],
  });
  return state;
}

Widget _buildHarness(Widget child) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: _buildSiteState()),
    ],
    child: MaterialApp(
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
    ),
  );
}

void main() {
  testWidgets(
      'site identity shows a real load error instead of claiming all identities are resolved',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildHarness(
        SiteIdentityPage(
          identityLoader: (String _) async {
            throw StateError('identity backend unavailable');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Identity matches are temporarily unavailable'),
      findsOneWidget,
    );
    expect(
      find.text('We could not load the identity review queue. Retry to check the current state.'),
      findsOneWidget,
    );
    expect(find.text('All Identities Resolved'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });
}