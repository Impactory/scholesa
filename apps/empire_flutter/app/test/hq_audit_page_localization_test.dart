import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/modules/hq_admin/hq_audit_page.dart';

Widget _buildHarness(Locale locale) {
  return MaterialApp(
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
    home: const HqAuditPage(),
  );
}

void main() {
  group('HQ audit tri-locale coverage', () {
    testWidgets('hq audit page renders zh-CN copy',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildHarness(const Locale('zh', 'CN')));
      await tester.pumpAndSettle();

      expect(find.text('审计日志'), findsAtLeastNWidgets(1));
      expect(find.text('未找到审计日志'), findsOneWidget);
      expect(find.text('红队审查 (0)'), findsOneWidget);
      expect(find.text('暂无红队审查'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.filter_list_rounded));
      await tester.pumpAndSettle();

      expect(find.text('按类别筛选'), findsOneWidget);
      expect(find.text('认证'), findsWidgets);
      expect(find.text('数据'), findsOneWidget);
      expect(find.text('管理'), findsWidgets);
      expect(find.text('系统'), findsOneWidget);
    });

    testWidgets('hq audit review dialog renders zh-TW copy',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildHarness(const Locale('zh', 'TW')));
      await tester.pumpAndSettle();

      expect(find.text('稽核日誌'), findsAtLeastNWidgets(1));
      expect(find.text('找不到稽核日誌'), findsOneWidget);
      expect(find.text('紅隊審查 (0)'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add_task_rounded));
      await tester.pumpAndSettle();

      expect(find.text('建立審查'), findsAtLeastNWidgets(1));
      expect(find.text('標題'), findsOneWidget);
      expect(find.text('站點 ID'), findsOneWidget);
      expect(find.text('KPI 套件 ID'), findsOneWidget);
      expect(find.text('決策'), findsOneWidget);
      expect(find.text('合作夥伴狀態'), findsOneWidget);
      expect(find.text('建議'), findsOneWidget);
      expect(find.text('下一步行動'), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();

      expect(find.text('繼續'), findsWidgets);
      expect(find.text('穩定'), findsOneWidget);
      expect(find.text('介入'), findsOneWidget);

      await tester.tap(find.text('穩定').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();

      expect(find.text('活躍'), findsWidgets);
      expect(find.text('觀察'), findsOneWidget);
      expect(find.text('暫停'), findsOneWidget);
    });
  });
}