import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/app_state.dart';

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
        title: const Text('Access Denied'),
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
                "You don't have permission to access this page.",
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your current role: ${role.name}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
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
              'This feature requires an upgrade',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Contact your administrator for access.',
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
