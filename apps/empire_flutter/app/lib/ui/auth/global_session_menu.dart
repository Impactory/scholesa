import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../auth/app_state.dart';
import '../../services/telemetry_service.dart';
import 'sign_out_flow.dart';
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

class SessionMenuButton extends StatelessWidget {
  const SessionMenuButton({
    super.key,
    this.navigatorKey,
    this.foregroundColor,
    this.showLabel = false,
    this.buttonKey,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  });

  final GlobalKey<NavigatorState>? navigatorKey;
  final Color? foregroundColor;
  final bool showLabel;
  final Key? buttonKey;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final Color resolvedForeground =
        foregroundColor ?? Theme.of(context).colorScheme.onSurface;
    return Material(
      elevation: 0,
      color: Colors.transparent,
      child: Semantics(
        button: true,
        label: _tGlobalSessionMenu(context, 'Account menu'),
        child: InkWell(
          key: buttonKey,
          borderRadius: BorderRadius.circular(999),
          onTap: () => _openGlobalSessionMenu(
            context: context,
            navigatorKey: navigatorKey,
          ),
          child: Padding(
            padding: padding,
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.account_circle_outlined, color: resolvedForeground),
                  if (showLabel) ...<Widget>[
                    const SizedBox(width: 8),
                    Text(
                      _tGlobalSessionMenu(context, 'Account'),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: resolvedForeground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SessionMenuHeaderAction extends StatelessWidget {
  const SessionMenuHeaderAction({
    super.key,
    this.navigatorKey,
    this.foregroundColor,
    this.backgroundColor,
  });

  final GlobalKey<NavigatorState>? navigatorKey;
  final Color? foregroundColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final bool showLabel = MediaQuery.sizeOf(context).width >= 720;
    final Color resolvedBackground = backgroundColor ??
        Theme.of(context).colorScheme.surface.withValues(alpha: 0.92);

    return Material(
      elevation: 0,
      color: resolvedBackground,
      borderRadius: BorderRadius.circular(999),
      child: SessionMenuButton(
        navigatorKey: navigatorKey,
        foregroundColor: foregroundColor,
        showLabel: showLabel,
      ),
    );
  }
}

class SessionSignOutButton extends StatelessWidget {
  const SessionSignOutButton({
    super.key,
    this.navigatorKey,
    this.foregroundColor,
    this.backgroundColor,
    this.showLabel = true,
  });

  final GlobalKey<NavigatorState>? navigatorKey;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final Color resolvedForeground =
        foregroundColor ?? Theme.of(context).colorScheme.error;
    final Color resolvedBackground = backgroundColor ??
        Theme.of(context).colorScheme.surface.withValues(alpha: 0.96);

    return Material(
      elevation: 0,
      color: resolvedBackground,
      borderRadius: BorderRadius.circular(999),
      child: Semantics(
        button: true,
        label: _tGlobalSessionMenu(context, 'Sign Out'),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () async {
            final BuildContext effectiveContext =
                navigatorKey?.currentContext ?? context;
            if (!effectiveContext.mounted) {
              return;
            }
            await _confirmGlobalSessionSignOut(effectiveContext);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.logout_rounded, color: resolvedForeground),
                  if (showLabel) ...<Widget>[
                    const SizedBox(width: 8),
                    Text(
                      _tGlobalSessionMenu(context, 'Sign Out'),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: resolvedForeground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GlobalSessionMenu extends StatelessWidget {
  const GlobalSessionMenu({
    super.key,
    this.navigatorKey,
    this.topPadding = 16,
  });

  final GlobalKey<NavigatorState>? navigatorKey;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    if (!appState.isAuthenticated) {
      return const SizedBox.shrink();
    }

    final double width = MediaQuery.sizeOf(context).width;
    final bool showLabel = width >= 720;
    final bool showExplicitSignOut = kIsWeb || width >= 960;

    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: EdgeInsets.only(top: topPadding, right: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (showExplicitSignOut) ...<Widget>[
                SessionSignOutButton(
                  navigatorKey: navigatorKey,
                  showLabel: showLabel,
                ),
                const SizedBox(width: 8),
              ],
              Material(
                elevation: 6,
                color: Theme.of(context)
                    .colorScheme
                    .surface
                    .withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(999),
                shadowColor: Colors.black.withValues(alpha: 0.14),
                child: SessionMenuButton(
                  navigatorKey: navigatorKey,
                  showLabel: showLabel,
                  buttonKey: _globalSessionMenuButtonKey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _openGlobalSessionMenu({
  required BuildContext context,
  GlobalKey<NavigatorState>? navigatorKey,
}) async {
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
  if (action == null) {
    return;
  }

  if (!context.mounted) {
    return;
  }

  final BuildContext effectiveContext = navigatorKey?.currentContext ?? context;
  if (!effectiveContext.mounted) {
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
      effectiveContext.push('/profile');
      return;
    case _GlobalSessionAction.settings:
      TelemetryService.instance.logEvent(
        event: 'cta.clicked',
        metadata: const <String, dynamic>{
          'cta': 'global_session_menu_settings',
        },
      );
      effectiveContext.push('/settings');
      return;
    case _GlobalSessionAction.signOut:
      await _confirmGlobalSessionSignOut(effectiveContext);
      return;
  }
}

Future<void> _confirmGlobalSessionSignOut(BuildContext context) async {
  await runSharedSignOutFlow(
    context: context,
    source: 'global_session_menu',
    title: _tGlobalSessionMenu(context, 'Sign Out'),
    message: _tGlobalSessionMenu(
      context,
      'Sign out so another family member can switch accounts on this device?',
    ),
    cancelLabel: _tGlobalSessionMenu(context, 'Cancel'),
    confirmLabel: _tGlobalSessionMenu(context, 'Sign Out'),
    openTelemetryCta: 'global_session_menu_open_sign_out_dialog',
    cancelTelemetryCta: 'global_session_menu_cancel_sign_out',
    confirmTelemetryCta: 'global_session_menu_confirm_sign_out',
  );
}
