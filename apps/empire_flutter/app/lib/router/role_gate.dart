import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/app_state.dart';
import '../services/firestore_service.dart';
import '../services/telemetry_service.dart';
import '../ui/localization/inline_locale_text.dart';

const Map<String, String> _roleGateZhCn = <String, String>{
  'Access Denied': '拒绝访问',
  "You don't have permission to access this page.": '你没有权限访问此页面。',
  'Your current role:': '你当前的角色：',
  'Go Back': '返回',
  'This feature requires an upgrade': '此功能需要升级',
  'Contact your administrator for access.': '请联系管理员获取访问权限。',
  'Request Access Review': '请求访问审核',
  'Access review request submitted.': '访问审核请求已提交。',
  'Support requests are unavailable right now.': '当前无法提交支持请求。',
  'Unable to submit support request right now.': '当前无法提交支持请求。',
};

const Map<String, String> _roleGateZhTw = <String, String>{
  'Access Denied': '拒絕存取',
  "You don't have permission to access this page.": '你沒有權限存取此頁面。',
  'Your current role:': '你目前的角色：',
  'Go Back': '返回',
  'This feature requires an upgrade': '此功能需要升級',
  'Contact your administrator for access.': '請聯絡管理員取得存取權限。',
  'Request Access Review': '請求存取審核',
  'Access review request submitted.': '存取審核請求已提交。',
  'Support requests are unavailable right now.': '目前無法提交支援請求。',
  'Unable to submit support request right now.': '目前無法提交支援請求。',
};

String _tRoleGate(BuildContext context, String input) {
  return InlineLocaleText.of(
    context,
    input,
    zhCn: _roleGateZhCn,
    zhTw: _roleGateZhTw,
  );
}

/// Gate that restricts access to routes based on user role
class RoleGate extends StatelessWidget {
  const RoleGate({
    super.key,
    required this.allowedRoles,
    required this.child,
    this.accessDeniedWidget,
  });
  final List<UserRole> allowedRoles;
  final Widget child;
  final Widget? accessDeniedWidget;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (BuildContext context, AppState appState, _) {
        final UserRole? role = appState.role;

        if (role == null) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (!allowedRoles.contains(role)) {
          return accessDeniedWidget ?? _AccessDeniedScreen(role: role);
        }

        return child;
      },
    );
  }
}

class _AccessDeniedScreen extends StatelessWidget {
  const _AccessDeniedScreen({required this.role});
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tRoleGate(context, 'Access Denied')),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(
                Icons.lock_outline,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                _tRoleGate(
                    context, "You don't have permission to access this page."),
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '${_tRoleGate(context, 'Your current role:')} ${role.name}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  TelemetryService.instance.logEvent(
                    event: 'cta.clicked',
                    metadata: <String, dynamic>{
                      'cta': 'role_gate_go_back',
                      'role': role.name
                    },
                  );
                  Navigator.of(context).pop();
                },
                child: Text(_tRoleGate(context, 'Go Back')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Entitlement gate for feature-gated content
class EntitlementGate extends StatelessWidget {
  const EntitlementGate({
    super.key,
    required this.feature,
    required this.child,
    this.lockedWidget,
  });
  final String feature;
  final Widget child;
  final Widget? lockedWidget;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (BuildContext context, AppState appState, _) {
        if (appState.hasEntitlement(feature)) {
          return child;
        }

        return lockedWidget ?? _LockedFeatureCard(feature: feature);
      },
    );
  }
}

class _LockedFeatureCard extends StatelessWidget {
  const _LockedFeatureCard({required this.feature});
  final String feature;

  FirestoreService? _maybeFirestoreService(BuildContext context) {
    try {
      return context.read<FirestoreService>();
    } catch (_) {
      return null;
    }
  }

  Future<void> _requestAccessReview(BuildContext context) async {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'entitlement_gate_request_access_review',
        'feature': feature,
      },
    );

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final FirestoreService? firestoreService = _maybeFirestoreService(context);
    if (firestoreService == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _tRoleGate(context, 'Support requests are unavailable right now.'),
          ),
        ),
      );
      return;
    }

    final AppState appState = context.read<AppState>();
    try {
      final String requestId = await firestoreService.submitSupportRequest(
        requestType: 'feature_access_review',
        source: 'entitlement_gate_request_access_review',
        siteId: appState.activeSiteId?.trim().isNotEmpty == true
            ? appState.activeSiteId!.trim()
            : 'Not set',
        userId: appState.userId?.trim().isNotEmpty == true
            ? appState.userId!.trim()
            : 'Not set',
        userEmail: appState.email?.trim().isNotEmpty == true
            ? appState.email!.trim()
            : 'Not set',
        userName: appState.displayName?.trim().isNotEmpty == true
            ? appState.displayName!.trim()
            : 'Not set',
        role: appState.role?.name ?? 'unknown',
        subject: 'Feature access review request: $feature',
        message: <String>[
          'Please review access for this gated feature.',
          '',
          'Feature: $feature',
          'Current Role: ${appState.role?.name ?? 'unknown'}',
          'Actual Role: ${appState.actualRole?.name ?? appState.role?.name ?? 'unknown'}',
          'Active Site: ${appState.activeSiteId?.trim().isNotEmpty == true ? appState.activeSiteId!.trim() : 'Not set'}',
        ].join('\n'),
        metadata: <String, dynamic>{
          'feature': feature,
          'effectiveRole': appState.role?.name,
          'actualRole': appState.actualRole?.name,
          'isImpersonating': appState.isImpersonating,
          'activeSiteId': appState.activeSiteId,
        },
      );
      TelemetryService.instance.logEvent(
        event: 'entitlement_gate.access_review_submitted',
        metadata: <String, dynamic>{
          'feature': feature,
          'request_id': requestId,
        },
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _tRoleGate(context, 'Access review request submitted.'),
          ),
        ),
      );
    } catch (error) {
      TelemetryService.instance.logEvent(
        event: 'entitlement_gate.access_review_failed',
        metadata: <String, dynamic>{
          'feature': feature,
          'error': error.toString(),
        },
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _tRoleGate(context, 'Unable to submit support request right now.'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.lock,
              size: 32,
              color: Colors.amber,
            ),
            const SizedBox(height: 8),
            Text(
              _tRoleGate(context, 'This feature requires an upgrade'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              _tRoleGate(context, 'Contact your administrator for access.'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _requestAccessReview(context),
              child: Text(_tRoleGate(context, 'Request Access Review')),
            ),
          ],
        ),
      ),
    );
  }
}
