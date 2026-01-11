import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'auth_service.dart';
import 'role_routes.dart';
import '../../services/telemetry_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final AuthService _auth = AuthService();
  bool loading = false;
  String? error;
  bool showPassword = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final user = await _auth.signIn(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      if (!mounted) return;
      if (user == null) {
        setState(() => error = 'Check your email or password and try again.');
        return;
      }
      final appState = context.read<AppState>();
      await appState.refreshEntitlements();
      if (!mounted) return;
      final requiresBotCheck = await _needsDormantBotCheck(user);
      if (requiresBotCheck) {
        final ok = await _showBotHoldDialog();
        if (!ok) {
          setState(() => error = 'Bot check cancelled.');
          return;
        }
      }
      await _updateLastLogin(user);
      if (!mounted) return;
      final ent = appState.entitlements;
      final normalizedEnt = ent.map(normalizeRole).toSet();
      final hasSuperuser = normalizedEnt.contains('superuser');
      final selectableRoles = normalizedEnt.where((role) => role != 'superuser').toSet();

      if (selectableRoles.length == 1 || (selectableRoles.isEmpty && hasSuperuser)) {
        final role = selectableRoles.isNotEmpty ? selectableRoles.first : 'hq';
        final normalized = normalizeRole(role);
        appState.setRole(normalized);
        TelemetryService.instance.logEvent(
          event: 'auth.login',
          role: normalized,
          siteId: appState.primarySiteId,
        );
        Navigator.pushNamedAndRemoveUntil(context, dashboardRouteFor(normalized), (route) => false);
      } else {
        appState.clearRole();
        TelemetryService.instance.logEvent(
          event: 'auth.login',
          role: null,
          siteId: appState.primarySiteId,
        );
        Navigator.pushReplacementNamed(context, '/roles');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => error = 'Check your email or password and try again.');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradient = const LinearGradient(
      colors: [Color(0xFF0B1224), Color(0xFF0F172A), Color(0xFF0B1224)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + bottomInset),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 520, minHeight: constraints.maxHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const Text(
                          'Welcome back',
                          style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Sign in to access your role dashboards.',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 24),
                        _glassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _label('Email address'),
                              const SizedBox(height: 8),
                              _field(
                                controller: emailController,
                                keyboardType: TextInputType.emailAddress,
                                hint: 'you@example.com',
                              ),
                              const SizedBox(height: 14),
                              _label('Password'),
                              const SizedBox(height: 8),
                              _field(
                                controller: passwordController,
                                obscure: true,
                                hint: '••••••••',
                              ),
                              const SizedBox(height: 14),
                              if (error != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(error!, style: const TextStyle(color: Colors.redAccent)),
                                ),
                              ElevatedButton(
                                onPressed: loading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  backgroundColor: const Color(0xFF38BDF8),
                                  foregroundColor: const Color(0xFF0B1224),
                                ),
                                child: loading
                                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Text('Continue', style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                              TextButton(
                                onPressed: loading ? null : () => Navigator.pushNamed(context, '/register'),
                                child: const Text('Need an account? Register', style: TextStyle(color: Colors.white70)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700));

  Widget _field({
    required TextEditingController controller,
    bool obscure = false,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure && !showPassword,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF38BDF8)),
        ),
        suffixIcon: obscure
            ? IconButton(
                onPressed: () => setState(() => showPassword = !showPassword),
                icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility, color: Colors.white70),
              )
            : null,
      ),
      style: const TextStyle(color: Colors.white),
    );
  }

  Future<bool> _needsDormantBotCheck(User user) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();
      final lastLoginAt = data?['lastLoginAt'];
      if (lastLoginAt is Timestamp) {
        final last = lastLoginAt.toDate();
        if (DateTime.now().difference(last) > const Duration(days: 30)) return true;
        return false;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  Future<void> _updateLastLogin(User user) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        <String, dynamic>{'lastLoginAt': Timestamp.now()},
        SetOptions(merge: true),
      );
    } catch (_) {
      // best effort
    }
  }

  Future<bool> _showBotHoldDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              title: const Text('Human check', style: TextStyle(color: Colors.white)),
              content: const Text('Press and hold to continue.', style: TextStyle(color: Colors.white70)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                GestureDetector(
                  onLongPress: () => Navigator.of(context).pop(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('Press and hold', style: TextStyle(color: Color(0xFF0B1224), fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }
}

Widget _glassCard({required Widget child}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white10),
      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 18, offset: Offset(0, 12))],
    ),
    padding: const EdgeInsets.all(16),
    child: child,
  );
}
