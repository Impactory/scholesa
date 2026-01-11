import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/app_state.dart';
import '../../services/telemetry_service.dart';
import 'lead_capture_card.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  bool _loggedView = false;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    if (appState.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/roles');
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_loggedView) return;
      _loggedView = true;
      TelemetryService.instance.logEvent(event: 'cms.page.viewed', metadata: {'slug': 'home'});
    });

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B1224), Color(0xFF0F172A), Color(0xFF0B1224)],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              left: -120,
              top: -80,
              child: _Glow(radius: 200, colors: [Color(0xFF38BDF8), Color(0xFF6366F1)]),
            ),
            const Positioned(
              right: -140,
              bottom: -100,
              child: _Glow(radius: 240, colors: [Color(0xFFF59E0B), Color(0xFFF472B6)]),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      height: 44,
                                      width: 44,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF06B6D4)]),
                                      ),
                                      alignment: Alignment.center,
                                      child: const Text('S', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                                    ),
                                    const SizedBox(width: 12),
                                    Text('Scholesa', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pushNamed(context, '/login'),
                                  style: TextButton.styleFrom(foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                                  child: const Text('Login'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            Text(
                              'Education 2.0 for Future Skills, Leadership, and Impact.',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: -0.4),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Missions, dashboards, and portfolios in one place for learners, educators, parents, sites, partners, and HQ.',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70, height: 1.5),
                            ),
                            const SizedBox(height: 22),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: const [
                                _PillarChip(label: 'Future Skills', gradient: [Color(0xFF38BDF8), Color(0xFF6366F1)]),
                                _PillarChip(label: 'Leadership & Agency', gradient: [Color(0xFFF472B6), Color(0xFFF97316)]),
                                _PillarChip(label: 'Impact & Innovation', gradient: [Color(0xFF22C55E), Color(0xFF06B6D4)]),
                              ],
                            ),
                            const SizedBox(height: 28),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: const LeadCaptureCard(source: 'landing', slug: 'home'),
                            ),
                            const SizedBox(height: 20),
                            const SizedBox(height: 28),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => Navigator.pushNamed(context, '/register'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ).copyWith(
                                        backgroundColor: WidgetStateProperty.all(const Color(0xFFF59E0B)),
                                        foregroundColor: WidgetStateProperty.all(const Color(0xFF0B1224)),
                                    ),
                                    child: const Text('Get started', style: TextStyle(fontWeight: FontWeight.w700)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.pushNamed(context, '/login'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(color: Colors.white38),
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    child: const Text('I already have an account'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillarChip extends StatelessWidget {
  const _PillarChip({required this.label, required this.gradient});

  final String label;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 8))],
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.radius, required this.colors});

  final double radius;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: radius,
      width: radius,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: colors),
        boxShadow: [BoxShadow(color: colors.last.withValues(alpha: 0.35), blurRadius: 120, spreadRadius: 36)],
      ),
    );
  }
}
