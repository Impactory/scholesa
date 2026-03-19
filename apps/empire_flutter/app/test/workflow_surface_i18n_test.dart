import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/i18n/workflow_surface_i18n.dart';

Widget _buildHarness(Locale locale) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      splashFactory: NoSplash.splashFactory,
    ),
    locale: locale,
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
    home: Builder(
      builder: (BuildContext context) {
        return Column(
          children: <Widget>[
            Text(WorkflowSurfaceI18n.text(context, 'Billing Management')),
            Text(WorkflowSurfaceI18n.text(context, 'My Missions')),
            Text(WorkflowSurfaceI18n.text(context, 'Profile')),
            Text(WorkflowSurfaceI18n.text(context, 'Provisioning')),
          ],
        );
      },
    ),
  );
}

void main() {
  group('Workflow surface i18n', () {
    testWidgets('renders zh-CN workflow labels', (WidgetTester tester) async {
      await tester.pumpWidget(_buildHarness(const Locale('zh', 'CN')));
      await tester.pumpAndSettle();

      expect(find.text('账单管理'), findsOneWidget);
      expect(find.text('我的任务'), findsOneWidget);
      expect(find.text('档案'), findsOneWidget);
      expect(find.text('开通配置'), findsOneWidget);
    });

    testWidgets('renders zh-TW workflow labels', (WidgetTester tester) async {
      await tester.pumpWidget(_buildHarness(const Locale('zh', 'TW')));
      await tester.pumpAndSettle();

      expect(find.text('帳務管理'), findsOneWidget);
      expect(find.text('我的任務'), findsOneWidget);
      expect(find.text('個人檔案'), findsOneWidget);
      expect(find.text('開通配置'), findsOneWidget);
    });
  });
}
