import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/app_state.dart';
import '../services/telemetry_service.dart';

const Map<String, String> _roleGateEs = <String, String>{
  'Access Denied': 'Acceso denegado',
  "You don't have permission to access this page.":
      'No tienes permiso para acceder a esta página.',
  'Your current role:': 'Tu rol actual:',
  'Go Back': 'Volver',
  'This feature requires an upgrade': 'Esta función requiere una mejora',
  'Contact your administrator for access.':
      'Contacta a tu administrador para obtener acceso.',
};

String _tRoleGate(BuildContext context, String input) {
  final String locale = Localizations.localeOf(context).languageCode;
  if (locale != 'es') return input;
  return _roleGateEs[input] ?? input;
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
          ],
        ),
      ),
    );
  }
}
