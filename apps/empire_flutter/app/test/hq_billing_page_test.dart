import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/modules/hq_admin/hq_billing_page.dart';

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
  testWidgets('HQ billing shows a real load error instead of empty finance tabs',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildHarness(
        HqBillingPage(
          billingLoader: () async {
            throw StateError('billing backend unavailable');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Billing data is temporarily unavailable'), findsOneWidget);
    expect(
      find.text('We could not load billing records. Retry to check the current state.'),
      findsWidgets,
    );
    expect(find.text('No invoices found'), findsNothing);
    expect(find.text('No payments found'), findsNothing);
    expect(find.text('No subscriptions found'), findsNothing);
    expect(find.text('Retry'), findsWidgets);
  });
}