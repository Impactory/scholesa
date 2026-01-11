import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/app_state.dart';
import '../auth/role_routes.dart';

const Map<String, String> roles = <String, String>{
  'learner': 'Learner',
  'educator': 'Educator',
  'parent': 'Parent',
  'site': 'Site Lead',
  'partner': 'Partner',
  'hq': 'HQ',
};

class RoleSelectorPage extends StatefulWidget {
  const RoleSelectorPage({super.key});

  @override
  State<RoleSelectorPage> createState() => _RoleSelectorPageState();
}

class _RoleSelectorPageState extends State<RoleSelectorPage> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (FirebaseAuth.instance.currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final entitlements = context.watch<AppState>().entitlements;
    final normalizedEntitlements = entitlements.map(normalizeRole).toSet();
    final hasSuperuser = normalizedEntitlements.contains('superuser');
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B1224), Color(0xFF0F172A), Color(0xFF0B1224)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose your role',
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Switch between dashboards for learners, educators, parents, sites, partners, and HQ.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: MediaQuery.of(context).size.width > 640 ? 3 : 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.1,
                    children: roles.entries.map((MapEntry<String, String> entry) {
                      final enabled = hasSuperuser || normalizedEntitlements.contains(entry.key);
                      return _RoleCard(
                        label: entry.value,
                        enabled: enabled,
                        onTap: () {
                          final normalized = normalizeRole(entry.key);
                          context.read<AppState>().setRole(normalized);
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            dashboardRouteFor(normalized),
                            (route) => false,
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.label, required this.enabled, required this.onTap});

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFF38BDF8),
      const Color(0xFF6366F1),
      const Color(0xFFF59E0B),
      const Color(0xFFF472B6),
      const Color(0xFF22C55E),
      const Color(0xFF0EA5E9),
    ];
    final color = colors[label.hashCode % colors.length];
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.85), color.withValues(alpha: 0.55)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 10))],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                ),
                Icon(Icons.chevron_right, color: enabled ? Colors.white : Colors.white38),
              ],
            ),
            const Spacer(),
            Text(
              enabled ? 'Enabled' : 'Not enabled',
              style: TextStyle(color: enabled ? Colors.white : Colors.white60),
            ),
          ],
        ),
      ),
    );
  }
}
