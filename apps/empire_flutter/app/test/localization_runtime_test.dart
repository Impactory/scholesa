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
    required this.sessionLoopTitle,
    required this.sessionLoopSubtitle,
    required this.accessDeniedTitle,
    required this.accessDeniedBody,
  });

  final Locale locale;
  final String signInLabel;
  final String sessionLoopTitle;
  final String sessionLoopSubtitle;
  final String accessDeniedTitle;
  final String accessDeniedBody;
}

Widget _buildLocaleHarness(Locale locale) {
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
    home: Builder(
      builder: (BuildContext context) {
        return Scaffold(
          body: Column(
            children: <Widget>[
              Text(AppStrings.of(context, 'auth.signIn')),
              Text(BosCoachingI18n.sessionLoopTitle(context)),
              Text(BosCoachingI18n.sessionLoopSubtitle(context)),
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
      sessionLoopTitle: 'BOS/MIA Session Loop',
      sessionLoopSubtitle:
          'Latest individual improvement signal for this session',
      accessDeniedTitle: 'Access Denied',
      accessDeniedBody: "You don't have permission to access this page.",
    ),
    const _LocaleCase(
      locale: Locale('zh', 'CN'),
      signInLabel: '登录',
      sessionLoopTitle: 'BOS/MIA 课堂循环',
      sessionLoopSubtitle: '本次课堂最新的个人成长信号',
      accessDeniedTitle: '拒绝访问',
      accessDeniedBody: '你没有权限访问此页面。',
    ),
    const _LocaleCase(
      locale: Locale('zh', 'TW'),
      signInLabel: '登入',
      sessionLoopTitle: 'BOS/MIA 課堂循環',
      sessionLoopSubtitle: '本次課堂最新的個人成長訊號',
      accessDeniedTitle: '拒絕存取',
      accessDeniedBody: '你沒有權限存取此頁面。',
    ),
  ];

  group('Runtime localization', () {
    for (final _LocaleCase localeCase in cases) {
      testWidgets('resolves auth, BOS, and role-gate copy for ${localeCase.locale}',
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
        expect(find.text(localeCase.sessionLoopTitle), findsOneWidget);
        expect(find.text(localeCase.sessionLoopSubtitle), findsOneWidget);

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