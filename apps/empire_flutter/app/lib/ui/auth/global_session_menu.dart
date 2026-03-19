import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../auth/app_state.dart';
import '../../auth/auth_service.dart';
import '../../services/telemetry_service.dart';
import '../../ui/localization/app_strings.dart';
import '../../ui/theme/scholesa_theme.dart';

const Map<String, String> _globalSessionMenuZhCn = <String, String>{
  'Account': '账户',
  'Account menu': '账户菜单',
  'Profile': '个人资料',
  'Settings': '设置',
  'Sign Out': '退出登录',
  'Cancel': '取消',
  'Sign out so another family member can switch accounts on this device?':
      '要退出登录，让其他家庭成员在这台设备上切换账户吗？',
};

const Map<String, String> _globalSessionMenuZhTw = <String, String>{
  'Account': '帳戶',
  'Account menu': '帳戶選單',
  'Profile': '個人資料',
  'Settings': '設定',
  'Sign Out': '登出',
  'Cancel': '取消',
  'Sign out so another family member can switch accounts on this device?':
      '要登出，讓其他家庭成員在這台裝置上切換帳戶嗎？',
};

String _tGlobalSessionMenu(BuildContext context, String input) {
  final Locale locale = Localizations.localeOf(context);
  if (locale.languageCode != 'zh') {
    return input;
  }
  if ((locale.countryCode ?? '').toUpperCase() == 'TW') {
    return _globalSessionMenuZhTw[input] ?? input;
  }
  return _globalSessionMenuZhCn[input] ?? input;
}

enum _GlobalSessionAction { profile, settings, signOut }

const Key _globalSessionMenuButtonKey = ValueKey<String>(
  'global_session_menu_button',
);

class GlobalSessionMenu extends StatelessWidget {
  const GlobalSessionMenu({
    super.key,
    this.navigatorKey,
  });

  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    if (!appState.isAuthenticated) {
      return const SizedBox.shrink();
    }

    final bool showLabel = MediaQuery.sizeOf(context).width >= 960;

    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 72, right: 12),
          child: Material(
            elevation: 6,
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(999),
            shadowColor: Colors.black.withValues(alpha: 0.14),
            child: Semantics(
              button: true,
              label: _tGlobalSessionMenu(context, 'Account menu'),
              child: InkWell(
                key: _globalSessionMenuButtonKey,
                borderRadius: BorderRadius.circular(999),
                onTap: () {
                  _openAccountSheet(context);
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: ExcludeSemantics(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.account_circle_outlined),
                        if (showLabel) ...<Widget>[
                          const SizedBox(width: 8),
                          Text(
                            _tGlobalSessionMenu(context, 'Account'),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openAccountSheet(BuildContext context) async {
    final BuildContext navigatorContext = navigatorKey?.currentContext ?? context;
    final _GlobalSessionAction? action =
        await showModalBottomSheet<_GlobalSessionAction>(
      context: navigatorContext,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: Text(_tGlobalSessionMenu(sheetContext, 'Profile')),
                  onTap: () => Navigator.pop(
                    sheetContext,
                    _GlobalSessionAction.profile,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: Text(_tGlobalSessionMenu(sheetContext, 'Settings')),
                  onTap: () => Navigator.pop(
                    sheetContext,
                    _GlobalSessionAction.settings,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.logout_rounded,
                    color: ScholesaColors.error,
                  ),
                  title: Text(
                    _tGlobalSessionMenu(sheetContext, 'Sign Out'),
                    style: const TextStyle(color: ScholesaColors.error),
                  ),
                  onTap: () => Navigator.pop(
                    sheetContext,
                    _GlobalSessionAction.signOut,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (action == null || navigatorKey?.currentContext == null) {
      return;
    }
    _handleAction(action);
  }

  void _handleAction(_GlobalSessionAction action) {
    final BuildContext? context = navigatorKey?.currentContext;
    if (context == null) {
      return;
    }
    switch (action) {
      case _GlobalSessionAction.profile:
        TelemetryService.instance.logEvent(
          event: 'cta.clicked',
          metadata: const <String, dynamic>{
            'cta': 'global_session_menu_profile',
          },
        );
        context.push('/profile');
        return;
      case _GlobalSessionAction.settings:
        TelemetryService.instance.logEvent(
          event: 'cta.clicked',
          metadata: const <String, dynamic>{
            'cta': 'global_session_menu_settings',
          },
        );
        context.push('/settings');
        return;
      case _GlobalSessionAction.signOut:
        _confirmSignOut(context);
        return;
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final AuthService authService = context.read<AuthService>();
    final GoRouter router = GoRouter.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String signOutFailedMessage =
        AppStrings.of(context, 'auth.error.signOutFailed');

    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{
        'cta': 'global_session_menu_open_sign_out_dialog',
      },
    );
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(_tGlobalSessionMenu(dialogContext, 'Sign Out')),
        content: Text(
          _tGlobalSessionMenu(
            dialogContext,
            'Sign out so another family member can switch accounts on this device?',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_tGlobalSessionMenu(dialogContext, 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ScholesaColors.error,
            ),
            child: Text(_tGlobalSessionMenu(dialogContext, 'Sign Out')),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      TelemetryService.instance.logEvent(
        event: 'cta.clicked',
        metadata: const <String, dynamic>{
          'cta': 'global_session_menu_cancel_sign_out',
        },
      );
      return;
    }

    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{
        'cta': 'global_session_menu_confirm_sign_out',
      },
    );
    try {
      await authService.signOut(source: 'global_session_menu');
      router.go(kIsWeb ? '/welcome' : '/login');
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(signOutFailedMessage),
        ),
      );
    }
  }
}
