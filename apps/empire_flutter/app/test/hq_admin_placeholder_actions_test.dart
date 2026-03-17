import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/hq_admin/hq_billing_page.dart';
import 'package:scholesa_app/modules/hq_admin/hq_safety_page.dart';
import 'package:scholesa_app/ui/theme/scholesa_theme.dart';

Widget _buildHarness({required Widget child, required AppState appState}) {
  return MultiProvider(
    providers: <ChangeNotifierProvider<dynamic>>[
      ChangeNotifierProvider<AppState>.value(value: appState),
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
      home: child,
    ),
  );
}

AppState _buildAppState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'hq-1',
    'email': 'hq-1@scholesa.test',
    'displayName': 'HQ User',
    'role': 'hq',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'localeCode': 'en',
    'entitlements': <Map<String, dynamic>>[],
  });
  return state;
}

void main() {
  testWidgets('HQ safety detail sheets remove the fake full report CTA',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1800));
    await tester.pumpWidget(
      _buildHarness(
        child: HqSafetyPage(
          incidentsLoader: () async => <String, dynamic>{
            'incidents': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'incident-1',
                'title': 'Minor playground incident',
                'siteName': 'Site One',
                'severity': 'major',
                'updatedAt': '2026-03-17T10:00:00.000Z',
                'isEscalated': true,
              },
            ],
          },
        ),
        appState: _buildAppState(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Minor playground incident').first);
    await tester.pumpAndSettle();

    expect(
      find.text('Full incident reports are not available in the app yet.'),
      findsOneWidget,
    );
    expect(find.text('View Full Report'), findsNothing);
  });

  testWidgets('HQ billing invoice cards remove the fake send invoice CTA',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1800));
    await tester.pumpWidget(
      _buildHarness(
        child: HqBillingPage(
          billingLoader: () async => <String, dynamic>{
            'siteOptions': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'all', 'label': 'All Sites'},
            ],
            'invoices': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'INV-1001',
                'parent': 'Parent One',
                'learner': 'Learner One',
                'site': 'Site One',
                'amount': 120.0,
                'status': 'pending',
                'date': '2026-03-17T10:00:00.000Z',
              },
            ],
            'payments': <Map<String, dynamic>>[],
            'subscriptions': <Map<String, dynamic>>[],
          },
        ),
        appState: _buildAppState(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('INV-1001'), findsOneWidget);
    expect(
      find.text('Invoice sending is not available in the app yet.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.send), findsNothing);

    final Finder viewInvoiceButton = find.byIcon(Icons.visibility);
    await tester.ensureVisible(viewInvoiceButton);
    await tester.tap(viewInvoiceButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Invoice INV-1001'), findsOneWidget);
  });
}
