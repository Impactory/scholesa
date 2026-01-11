import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  final AuthService _auth = AuthService();
  bool loading = false;
  String? error;
  bool showPassword = false;
  bool showConfirm = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (passwordController.text != confirmController.text) {
      setState(() => error = 'Passwords do not match');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final user = await _auth.register(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      if (!mounted) return;
      if (user != null) {
        final ok = await _showBotHoldDialog();
        if (!ok) {
          setState(() => error = 'Bot check cancelled.');
          return;
        }
      }
      if (!mounted) return;
      context.read<AppState>().clearRole();
      Navigator.pushReplacementNamed(context, '/roles');
    } catch (e) {
      if (!mounted) return;
      setState(() => error = 'Registration failed. Try again.');
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
                          'Create your account',
                          style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        const Text('Use your school email to join.', style: TextStyle(color: Colors.white70)),
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
                                isConfirm: false,
                              ),
                              const SizedBox(height: 14),
                              _label('Password'),
                              const SizedBox(height: 8),
                              _field(controller: passwordController, obscure: true, hint: '••••••••', isConfirm: false),
                              const SizedBox(height: 14),
                              _label('Confirm password'),
                              const SizedBox(height: 8),
                              _field(controller: confirmController, obscure: true, hint: '••••••••', isConfirm: true),
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
                                  backgroundColor: const Color(0xFFF59E0B),
                                  foregroundColor: const Color(0xFF0B1224),
                                ),
                                child: loading
                                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Text('Create account', style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                              TextButton(
                                onPressed: loading ? null : () => Navigator.pop(context),
                                child: const Text('Back to login', style: TextStyle(color: Colors.white70)),
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
    required bool isConfirm,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure && !(isConfirm ? showConfirm : showPassword),
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
          borderSide: const BorderSide(color: Color(0xFFF59E0B)),
        ),
        suffixIcon: obscure
            ? IconButton(
                onPressed: () => setState(() {
                  if (isConfirm) {
                    showConfirm = !showConfirm;
                  } else {
                    showPassword = !showPassword;
                  }
                }),
                icon: Icon(
                  (isConfirm ? showConfirm : showPassword) ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white70,
                ),
              )
            : null,
      ),
      style: const TextStyle(color: Colors.white),
    );
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
                      color: const Color(0xFFF59E0B),
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
