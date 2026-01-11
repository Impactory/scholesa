String normalizeRole(String role) {
  final normalized = role.trim().toLowerCase();
  final slug = normalized.replaceAll(RegExp(r'[^a-z0-9]'), '');
  switch (slug) {
    case 'superuser':
      return 'superuser';
    case 'hqadmin':
    case 'admin':
    case 'hq':
      return 'hq';
    case 'sitelead':
    case 'siteadmin':
    case 'siteleader':
    case 'site':
      return 'site';
    case 'guardian':
    case 'parentguardian':
    case 'parent':
      return 'parent';
    case 'teacher':
    case 'educator':
      return 'educator';
    case 'student':
    case 'learner':
      return 'learner';
    case 'partner':
      return 'partner';
    case 'hqrole':
      return 'hq';
    default:
      return slug.isEmpty ? normalized : slug;
  }
}

const Map<String, String> roleDashboardRoutes = <String, String>{
  'learner': '/dashboard/learner',
  'educator': '/dashboard/educator',
  'parent': '/dashboard/parent',
  'site': '/dashboard/site',
  'partner': '/dashboard/partner',
  'hq': '/dashboard/hq',
};

String dashboardRouteFor(String role) {
  final normalized = normalizeRole(role);
  if (normalized == 'superuser') return roleDashboardRoutes['hq']!;
  return roleDashboardRoutes[normalized] ?? roleDashboardRoutes['learner']!;
}

bool rolePermitted(String role, Set<String> entitlements) {
  if (entitlements.isEmpty) return false;
  final normalizedEntitlements = entitlements.map(normalizeRole).toSet();
  if (normalizedEntitlements.contains('superuser')) return true;
  return normalizedEntitlements.contains(normalizeRole(role));
}
