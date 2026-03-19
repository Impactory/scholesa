import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/modules/hq_admin/hq_audit_page.dart';

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
  testWidgets('HQ audit shows a real load error instead of empty audit sections',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildHarness(
        HqAuditPage(
          auditLogsLoader: () async {
            throw StateError('audit backend unavailable');
          },
          redTeamReviewsLoader: () async => <Map<String, dynamic>>[],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Audit data is temporarily unavailable'), findsOneWidget);
    expect(
      find.text('We could not load audit records. Retry to check the current state.'),
      findsOneWidget,
    );
    expect(find.text('No audit logs found'), findsNothing);
    expect(find.text('No red team reviews yet'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });
}