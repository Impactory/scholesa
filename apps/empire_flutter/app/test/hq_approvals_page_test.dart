import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/modules/hq_admin/hq_approvals_page.dart';

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
  testWidgets('HQ approvals shows a real load error instead of a fake empty queue',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildHarness(
        HqApprovalsPage(
          loadApprovals: () async {
            throw StateError('approvals backend unavailable');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('Approvals are temporarily unavailable'), findsOneWidget);
    expect(
      find.text('We could not load the approvals queue. Retry to check the current state.'),
      findsOneWidget,
    );
    expect(find.text('No pending approvals'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });
}