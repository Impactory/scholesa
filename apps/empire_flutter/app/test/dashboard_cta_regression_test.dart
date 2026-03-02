import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/dashboards/role_dashboard.dart';
import 'package:scholesa_app/modules/site/site_dashboard_page.dart';

final ThemeData _testTheme = ThemeData(
  useMaterial3: true,
  splashFactory: InkRipple.splashFactory,
);

void main() {
  group('Dashboard CTA regressions', () {
    testWidgets('role dashboard View All opens quick actions sheet',
        (WidgetTester tester) async {
      final AppState appState = AppState()
        ..updateFromMeResponse(<String, dynamic>{
          'userId': 'u-1',
          'email': 'site@scholesa.dev',
          'displayName': 'Site Admin',
          'role': 'site',
          'activeSiteId': 'site-1',
          'siteIds': <String>['site-1'],
          'entitlements': <Map<String, dynamic>>[],
        });

      await tester.binding.setSurfaceSize(const Size(1280, 1800));
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            theme: _testTheme,
            home: RoleDashboard(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('View All').first);
      await tester.pumpAndSettle();

      expect(find.text('All Quick Actions'), findsOneWidget);
      expect(find.byType(ListTile), findsWidgets);
    });

    testWidgets('site dashboard export CTA runs dialog flow',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1800));
      await tester.pumpWidget(
        MaterialApp(
          theme: _testTheme,
          home: SiteDashboardPage(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.download));
      await tester.pumpAndSettle();

      expect(find.text('Export Site Report'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Generate'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('report prepared for download'),
        findsOneWidget,
      );
    });

    testWidgets('site dashboard activity View All opens bottom sheet',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1800));
      await tester.pumpWidget(
        MaterialApp(
          theme: _testTheme,
          home: SiteDashboardPage(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('View All').first);
      await tester.pumpAndSettle();

      expect(find.text('All Recent Activity'), findsOneWidget);
      expect(find.text('New enrollment'), findsWidgets);
    });
  });
}
