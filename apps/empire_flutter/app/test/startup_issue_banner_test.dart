import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/services/app_resilience.dart';
import 'package:scholesa_app/ui/error/startup_issue_banner.dart';

void main() {
  testWidgets('startup issue banner localizes zh-CN recovery copy',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          splashFactory: NoSplash.splashFactory,
        ),
        locale: const Locale('zh', 'CN'),
        supportedLocales: const <Locale>[
          Locale('en'),
          Locale('zh', 'CN'),
          Locale('zh', 'TW'),
        ],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: StartupIssueBanner(
            issues: <AppStartupIssue>[
              AppStartupIssue(
                serviceKey: 'localStorage',
                message: 'Local storage was unavailable during startup.',
              ),
              AppStartupIssue(
                serviceKey: 'firebase',
                message: 'Firebase services were unavailable during startup.',
              ),
            ],
            onDismiss: () {},
          ),
        ),
      ),
    );

    expect(find.text('Scholesa 以恢复模式启动'), findsOneWidget);
    expect(
      find.text('部分启动服务失败，因此在下次重启前，应用的某些功能可能不可用。'),
      findsOneWidget,
    );
    expect(find.textContaining('受影响的服务'), findsOneWidget);
    expect(find.textContaining('本地存储'), findsOneWidget);
    expect(find.textContaining('Firebase'), findsOneWidget);
  });

  testWidgets('startup issue banner dismisses when requested',
      (WidgetTester tester) async {
    bool dismissed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          splashFactory: NoSplash.splashFactory,
        ),
        supportedLocales: const <Locale>[
          Locale('en'),
          Locale('zh', 'CN'),
          Locale('zh', 'TW'),
        ],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: StartupIssueBanner(
            issues: <AppStartupIssue>[
              AppStartupIssue(
                serviceKey: 'authEmulator',
                message: 'The auth emulator connection failed during startup.',
              ),
            ],
            onDismiss: () {
              dismissed = true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Dismiss'));
    await tester.pump();

    expect(dismissed, isTrue);
  });
}
