import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/i18n/bos_coaching_i18n.dart';
import 'package:scholesa_app/router/role_gate.dart';
import 'package:scholesa_app/ui/localization/app_strings.dart';

class _LocaleCase {
  const _LocaleCase({
    required this.locale,
    required this.signInLabel,
    required this.learnerLoopTitle,
    required this.learnerLoopSubtitle,
    required this.sessionLoopTitle,
    required this.sessionLoopSubtitle,
    required this.learnerUnavailable,
    required this.accessDeniedTitle,
    required this.accessDeniedBody,
  });

  final Locale locale;
  final String signInLabel;
  final String learnerLoopTitle;
  final String learnerLoopSubtitle;
  final String sessionLoopTitle;
  final String sessionLoopSubtitle;
  final String learnerUnavailable;
  final String accessDeniedTitle;
  final String accessDeniedBody;
}

Widget _buildLocaleHarness(Locale locale) {
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
        return Scaffold(
          body: Column(
            children: <Widget>[
              Text(AppStrings.of(context, 'auth.signIn')),
              Text(BosCoachingI18n.learnerLoopTitle(context)),
              Text(BosCoachingI18n.learnerLoopSubtitle(context)),
              Text(BosCoachingI18n.sessionLoopTitle(context)),
              Text(BosCoachingI18n.sessionLoopSubtitle(context)),
              Text(BosCoachingI18n.learnerUnavailable(context)),
            ],
          ),
        );
      },
    ),
  );
}

Widget _buildRoleGateHarness(Locale locale, AppState appState) {
  return ChangeNotifierProvider<AppState>.value(
    value: appState,
    child: MaterialApp(
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
      home: const RoleGate(
        allowedRoles: <UserRole>[UserRole.educator],
        child: SizedBox.shrink(),
      ),
    ),
  );
}

void main() {
  final List<_LocaleCase> cases = <_LocaleCase>[
    const _LocaleCase(
      locale: Locale('en'),
      signInLabel: 'Sign In',
      learnerLoopTitle: 'Learning Support Snapshot',
      learnerLoopSubtitle: 'Current learning signals for this learner',
      sessionLoopTitle: 'Session Support Snapshot',
      sessionLoopSubtitle: 'Current learning signals for this session',
      learnerUnavailable: 'Learner unavailable',
      accessDeniedTitle: 'Access Denied',
      accessDeniedBody: "You don't have permission to access this page.",
    ),
    const _LocaleCase(
      locale: Locale('zh', 'CN'),
      signInLabel: '登录',
      learnerLoopTitle: '学习支持概览',
      learnerLoopSubtitle: '该学习者当前学习信号',
      sessionLoopTitle: '课堂支持概览',
      sessionLoopSubtitle: '本次课堂当前学习信号',
      learnerUnavailable: '学习者信息不可用',
      accessDeniedTitle: '拒绝访问',
      accessDeniedBody: '你没有权限访问此页面。',
    ),
    const _LocaleCase(
      locale: Locale('zh', 'TW'),
      signInLabel: '登入',
      learnerLoopTitle: '學習支持概覽',
      learnerLoopSubtitle: '該學習者目前學習訊號',
      sessionLoopTitle: '課堂支持概覽',
      sessionLoopSubtitle: '本次課堂目前學習訊號',
      learnerUnavailable: '學習者資訊不可用',
      accessDeniedTitle: '拒絕存取',
      accessDeniedBody: '你沒有權限存取此頁面。',
    ),
  ];

  group('Runtime localization', () {
    for (final _LocaleCase localeCase in cases) {
      testWidgets(
          'resolves auth, AI help, and role-gate copy for ${localeCase.locale}',
          (WidgetTester tester) async {
        final AppState appState = AppState()
          ..updateFromMeResponse(<String, dynamic>{
            'userId': 'learner-1',
            'email': 'learner@scholesa.dev',
            'displayName': 'Learner One',
            'role': 'learner',
            'activeSiteId': 'site-1',
            'siteIds': <String>['site-1'],
            'localeCode': localeCase.locale.languageCode == 'zh'
                ? 'zh-${localeCase.locale.countryCode}'
                : 'en',
          });

        await tester.pumpWidget(_buildLocaleHarness(localeCase.locale));
        await tester.pumpAndSettle();

        expect(find.text(localeCase.signInLabel), findsOneWidget);
        expect(find.text(localeCase.learnerLoopTitle), findsOneWidget);
        expect(find.text(localeCase.learnerLoopSubtitle), findsOneWidget);
        expect(find.text(localeCase.sessionLoopTitle), findsOneWidget);
        expect(find.text(localeCase.sessionLoopSubtitle), findsOneWidget);
        expect(find.text(localeCase.learnerUnavailable), findsOneWidget);

        await tester.pumpWidget(
          _buildRoleGateHarness(localeCase.locale, appState),
        );
        await tester.pumpAndSettle();

        expect(find.text(localeCase.accessDeniedTitle), findsOneWidget);
        expect(find.text(localeCase.accessDeniedBody), findsOneWidget);
      });
    }
  });
}
