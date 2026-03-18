import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../auth/auth_service.dart';
import '../../auth/app_state.dart';
import '../../auth/recent_login_store.dart';
import '../../services/telemetry_service.dart';
import '../localization/app_strings.dart';
import '../localization/inline_locale_text.dart';
import '../theme/scholesa_theme.dart';
import '../widgets/scholesa_logo.dart';

const Map<String, String> _loginZhCn = <String, String>{
  'Education 2.0\nPlatform': '教育 2.0\n平台',
  'Empowering K-9 learning studios with Future Skills,\nLeadership & Agency, and Impact & Innovation.':
      '以未来技能、\n领导力与自主性、影响力与创新\n赋能 K-9 学习工作室。',
  'Mission-based learning': '任务式学习',
  'Habit coaching': '习惯教练',
  'Portfolio showcase': '作品集展示',
  'Future Skills': '未来技能',
  'Leadership': '领导力',
  'Impact': '影响力',
};

const Map<String, String> _loginZhTw = <String, String>{
  'Education 2.0\nPlatform': '教育 2.0\n平台',
  'Empowering K-9 learning studios with Future Skills,\nLeadership & Agency, and Impact & Innovation.':
      '以未來技能、\n領導力與自主性、影響力與創新\n賦能 K-9 學習工作室。',
  'Mission-based learning': '任務式學習',
  'Habit coaching': '習慣教練',
  'Portfolio showcase': '作品集展示',
  'Future Skills': '未來技能',
  'Leadership': '領導力',
  'Impact': '影響力',
};

String _tLogin(BuildContext context, String input) {
  return InlineLocaleText.of(context, input, zhCn: _loginZhCn, zhTw: _loginZhTw);
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _navigatePostAuth() {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  void _prefillRememberedAccount(RecentLoginAccount account) {
    _emailController.text = account.email;
    _passwordController.clear();
    setState(() {
      _errorMessage = null;
    });
  }

  Future<void> _continueWithRememberedAccount(
    RecentLoginAccount account,
  ) async {
    _prefillRememberedAccount(account);
    await TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'login',
        'cta_id': 'continue_recent_account',
        'surface': 'recent_accounts',
        'provider': account.provider.name,
      },
    );

    switch (account.provider) {
      case RecentLoginProvider.google:
        await _handleGoogleSignIn();
        return;
      case RecentLoginProvider.microsoft:
        await _handleMicrosoftSignIn();
        return;
      case RecentLoginProvider.email:
      case RecentLoginProvider.unknown:
        return;
    }
  }

  Future<void> _forgetRememberedAccount(
    BuildContext context,
    RecentLoginStore store,
    RecentLoginAccount account,
  ) async {
    try {
      await TelemetryService.instance.logEvent(
        event: 'cta.clicked',
        metadata: <String, dynamic>{
          'module': 'login',
          'cta_id': 'forget_recent_account',
          'surface': 'recent_accounts',
          'provider': account.provider.name,
        },
      );
    } catch (_) {
      // Best effort telemetry only.
    }

    await store.forgetAccount(account.userId);
    if (!mounted) return;

    if (_emailController.text.trim().toLowerCase() ==
        account.email.trim().toLowerCase()) {
      _emailController.clear();
      _passwordController.clear();
      setState(() {
        _errorMessage = null;
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.of(context, 'auth.rememberedAccountRemoved')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _providerLabel(BuildContext context, RecentLoginProvider provider) {
    switch (provider) {
      case RecentLoginProvider.google:
        return AppStrings.of(context, 'auth.google');
      case RecentLoginProvider.microsoft:
        return AppStrings.of(context, 'auth.microsoft');
      case RecentLoginProvider.email:
        return AppStrings.of(context, 'auth.useEmail');
      case RecentLoginProvider.unknown:
        return AppStrings.of(context, 'auth.savedAccount');
    }
  }

  Widget _buildRecentAccounts(BuildContext context) {
    return Consumer<RecentLoginStore>(
      builder: (BuildContext context, RecentLoginStore store, _) {
        if (store.recentAccounts.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              AppStrings.of(context, 'auth.recentAccountsTitle'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: ScholesaColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.of(context, 'auth.recentAccountsSubtitle'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ScholesaColors.textSecondary,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 16),
            ...store.recentAccounts.map((RecentLoginAccount account) {
              final bool isActive = store.activeUserId == account.userId;
              final String initial =
                  account.displayName.trim().isEmpty ? account.email[0] : account.displayName.trim()[0];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isActive
                        ? ScholesaColors.primary.withValues(alpha: 0.35)
                        : ScholesaColors.border,
                  ),
                ),
                child: ListTile(
                  onTap: () {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: <String, dynamic>{
                        'module': 'login',
                        'cta_id': 'prefill_recent_account',
                        'surface': 'recent_accounts',
                        'provider': account.provider.name,
                      },
                    );
                    _prefillRememberedAccount(account);
                  },
                  leading: CircleAvatar(
                    backgroundColor:
                        ScholesaColors.primary.withValues(alpha: 0.12),
                    foregroundColor: ScholesaColors.primaryDark,
                    child: Text(initial.toUpperCase()),
                  ),
                  title: Text(
                    account.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(account.email),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextButton(
                        onPressed: () => _continueWithRememberedAccount(account),
                        child: Text(_providerLabel(context, account.provider)),
                      ),
                      IconButton(
                        tooltip: AppStrings.of(
                          context,
                          'auth.removeRememberedAccount',
                        ),
                        onPressed: () => _forgetRememberedAccount(
                          context,
                          store,
                          account,
                        ),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final AuthService authService = context.read<AuthService>();
      await authService.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      await TelemetryService.instance.logEvent(
        event: 'auth.login',
        metadata: <String, dynamic>{'method': 'email'},
      );

      _navigatePostAuth();
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _authErrorMessageFromException(context, e);
        });
      }
    } catch (e) {
      if (mounted) {
        final String fallbackMessage = context.read<AppState>().error ??
            AppStrings.of(context, 'auth.error.unexpected');
        setState(() {
          _errorMessage =
              _normalizeAuthExceptionMessage(context, e, fallbackMessage);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final AuthService authService = context.read<AuthService>();
      await authService.signInWithGoogle();
      await TelemetryService.instance.logEvent(
        event: 'auth.login',
        metadata: <String, dynamic>{'method': 'google'},
      );

      _navigatePostAuth();
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _authErrorMessageFromException(context, e);
        });
      }
    } catch (e) {
      if (mounted) {
        final String fallbackMessage = context.read<AppState>().error ??
            AppStrings.of(context, 'auth.error.googleFailed');
        setState(() {
          _errorMessage =
              _normalizeAuthExceptionMessage(context, e, fallbackMessage);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleMicrosoftSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final AuthService authService = context.read<AuthService>();
      await authService.signInWithMicrosoft();
      await TelemetryService.instance.logEvent(
        event: 'auth.login',
        metadata: <String, dynamic>{'method': 'microsoft'},
      );

      _navigatePostAuth();
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _authErrorMessageFromException(context, e);
        });
      }
    } catch (e) {
      if (mounted) {
        final String fallbackMessage = context.read<AppState>().error ??
            AppStrings.of(context, 'auth.error.microsoftFailed');
        setState(() {
          _errorMessage =
              _normalizeAuthExceptionMessage(context, e, fallbackMessage);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final TextEditingController resetEmailController = TextEditingController(
      text: _emailController.text.trim(),
    );

    final bool? sent = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        String? dialogError;
        bool sending = false;

        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setDialogState) {
            return AlertDialog(
              title: Text(AppStrings.of(ctx, 'auth.resetPassword')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    AppStrings.of(ctx, 'auth.resetPasswordHelp'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: resetEmailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: AppStrings.of(ctx, 'auth.email'),
                      errorText: dialogError,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: sending
                      ? null
                      : () {
                          TelemetryService.instance.logEvent(
                            event: 'cta.clicked',
                            metadata: const <String, dynamic>{
                              'module': 'login',
                              'cta_id': 'cancel_password_reset',
                              'surface': 'forgot_password_dialog',
                            },
                          );
                          Navigator.pop(ctx, false);
                        },
                  child: Text(AppStrings.of(ctx, 'auth.cancel')),
                ),
                ElevatedButton(
                  onPressed: sending
                      ? null
                      : () async {
                          final String email = resetEmailController.text.trim();
                          if (email.isEmpty || !email.contains('@')) {
                            setDialogState(() {
                              dialogError = AppStrings.of(
                                  ctx, 'auth.validation.validEmail');
                            });
                            return;
                          }
                          setDialogState(() {
                            sending = true;
                            dialogError = null;
                          });
                          try {
                            TelemetryService.instance.logEvent(
                              event: 'cta.clicked',
                              metadata: <String, dynamic>{
                                'module': 'login',
                                'cta_id': 'submit_password_reset',
                                'surface': 'forgot_password_dialog',
                                'email_length': email.length,
                              },
                            );
                            await FirebaseAuth.instance
                                .sendPasswordResetEmail(email: email);
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } on FirebaseAuthException catch (e) {
                            setDialogState(() {
                              sending = false;
                              dialogError = _authErrorMessage(ctx, e.code,
                                  fallback: AppStrings.of(
                                      ctx, 'auth.error.resetFailed'));
                            });
                          }
                        },
                  child: sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(AppStrings.of(ctx, 'auth.sendResetLink')),
                ),
              ],
            );
          },
        );
      },
    );

    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.of(context, 'auth.resetEmailSent')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool isWide = size.width > 800;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    const Color headingColor = ScholesaColors.textPrimary;
    const Color secondaryTextColor = ScholesaColors.textSecondary;
    const Color fieldFillColor = Colors.white;
    const Color fieldTextColor = ScholesaColors.textPrimary;
    const Color fieldHintColor = ScholesaColors.textMuted;
    const Color fieldBorderColor = ScholesaColors.border;
    const Color linkColor = ScholesaColors.primaryDark;

    return Scaffold(
      backgroundColor: ScholesaColors.background,
      body: Row(
        children: <Widget>[
          // Left side - decorative gradient panel (only on wide screens)
          if (isWide)
            Expanded(
              flex: 5,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: ScholesaColors.primaryGradient,
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // Logo
                        const Row(
                          children: <Widget>[
                            ScholesaLogo(size: 56, showShadow: false),
                            SizedBox(width: 12),
                            Text(
                              'Scholesa',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Hero text
                        Text(
                          _tLogin(context, 'Education 2.0\nPlatform'),
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _tLogin(context,
                              'Empowering K-9 learning studios with Future Skills,\nLeadership & Agency, and Impact & Innovation.'),
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 48),
                        // Feature highlights
                        _buildFeatureRow(Icons.rocket_launch_rounded,
                          _tLogin(context, 'Mission-based learning')),
                        const SizedBox(height: 16),
                        _buildFeatureRow(
                          Icons.psychology_rounded,
                          _tLogin(context, 'Habit coaching')),
                        const SizedBox(height: 16),
                        _buildFeatureRow(
                          Icons.folder_special_rounded,
                          _tLogin(context, 'Portfolio showcase')),
                        const Spacer(),
                        // Bottom pillars
                        Row(
                          children: <Widget>[
                            _buildPillarChip(
                                _tLogin(context, 'Future Skills'),
                                ScholesaColors.futureSkills),
                            const SizedBox(width: 8),
                            _buildPillarChip(
                                _tLogin(context, 'Leadership'),
                                ScholesaColors.leadership),
                            const SizedBox(width: 8),
                            _buildPillarChip(
                                _tLogin(context, 'Impact'),
                                ScholesaColors.impact),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Right side - login form
          Expanded(
            flex: 4,
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          // Mobile logo (only show on narrow screens)
                          if (!isWide) ...<Widget>[
                            const Center(
                              child: ScholesaLogo(size: 80, showShadow: true),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Welcome text
                          Text(
                            isWide
                                ? AppStrings.of(context, 'auth.welcomeBack')
                                : AppStrings.of(
                                    context, 'auth.welcomeToScholesa'),
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: headingColor,
                            ),
                            textAlign:
                                isWide ? TextAlign.left : TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppStrings.of(context, 'auth.signInSubtitle'),
                            style: textTheme.bodyMedium?.copyWith(
                              color: secondaryTextColor,
                            ),
                            textAlign:
                                isWide ? TextAlign.left : TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          _buildRecentAccounts(context),
                          const SizedBox(height: 40),

                          // Error message
                          if (_errorMessage != null) ...<Widget>[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color:
                                    ScholesaColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: ScholesaColors.error
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: <Widget>[
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: ScholesaColors.error,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        color: ScholesaColors.error,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Login form
                          Form(
                            key: _formKey,
                            child: Column(
                              children: <Widget>[
                                // Email field
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  style: const TextStyle(
                                    color: fieldTextColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    labelText:
                                        AppStrings.of(context, 'auth.email'),
                                    hintText: AppStrings.of(
                                        context, 'auth.emailHint'),
                                    labelStyle: const TextStyle(
                                        color: secondaryTextColor),
                                    floatingLabelStyle:
                                        const TextStyle(color: headingColor),
                                    hintStyle:
                                        const TextStyle(color: fieldHintColor),
                                    prefixIcon: const Icon(Icons.email_outlined,
                                        color: secondaryTextColor),
                                    filled: true,
                                    fillColor: fieldFillColor,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: fieldBorderColor),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: fieldBorderColor),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: colorScheme.primary,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  validator: (String? value) {
                                    if (value == null || value.isEmpty) {
                                      return AppStrings.of(context,
                                          'auth.validation.enterEmail');
                                    }
                                    if (!value.contains('@')) {
                                      return AppStrings.of(context,
                                          'auth.validation.validEmail');
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),

                                // Password field
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _handleLogin(),
                                  style: const TextStyle(
                                    color: fieldTextColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    labelText:
                                        AppStrings.of(context, 'auth.password'),
                                    hintText: AppStrings.of(
                                        context, 'auth.passwordHint'),
                                    labelStyle: const TextStyle(
                                        color: secondaryTextColor),
                                    floatingLabelStyle:
                                        const TextStyle(color: headingColor),
                                    hintStyle:
                                        const TextStyle(color: fieldHintColor),
                                    prefixIcon: const Icon(Icons.lock_outlined,
                                        color: secondaryTextColor),
                                    filled: true,
                                    fillColor: fieldFillColor,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: fieldBorderColor),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: fieldBorderColor),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: colorScheme.primary,
                                        width: 2,
                                      ),
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: secondaryTextColor,
                                      ),
                                      onPressed: () {
                                        TelemetryService.instance.logEvent(
                                          event: 'cta.clicked',
                                          metadata: <String, dynamic>{
                                            'module': 'login',
                                            'cta_id': _obscurePassword
                                                ? 'show_password'
                                                : 'hide_password',
                                            'surface': 'password_field',
                                          },
                                        );
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                  ),
                                  validator: (String? value) {
                                    if (value == null || value.isEmpty) {
                                      return AppStrings.of(context,
                                          'auth.validation.enterPassword');
                                    }
                                    if (value.length < 6) {
                                      return AppStrings.of(context,
                                          'auth.validation.passwordLength');
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),

                                // Forgot password
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      TelemetryService.instance.logEvent(
                                        event: 'cta.clicked',
                                        metadata: const <String, dynamic>{
                                          'module': 'login',
                                          'cta_id':
                                              'open_forgot_password_dialog',
                                          'surface': 'login_form',
                                        },
                                      );
                                      _showForgotPasswordDialog();
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: linkColor,
                                    ),
                                    child: Text(AppStrings.of(
                                        context, 'auth.forgotPassword')),
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Sign in button
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () {
                                            TelemetryService.instance.logEvent(
                                              event: 'cta.clicked',
                                              metadata: const <String, dynamic>{
                                                'module': 'login',
                                                'cta_id': 'submit_email_login',
                                                'surface': 'login_form',
                                              },
                                            );
                                            _handleLogin();
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colorScheme.primary,
                                      foregroundColor: colorScheme.onPrimary,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                            ),
                                          )
                                        : Text(
                                            AppStrings.of(
                                                context, 'auth.signIn'),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Divider
                          Row(
                            children: <Widget>[
                              const Expanded(
                                  child: Divider(color: ScholesaColors.border)),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  AppStrings.of(context, 'auth.orContinueWith'),
                                  style: textTheme.bodySmall?.copyWith(
                                    color: secondaryTextColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const Expanded(
                                  child: Divider(color: ScholesaColors.border)),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Social sign in buttons
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isLoading
                                      ? null
                                      : () {
                                          TelemetryService.instance.logEvent(
                                            event: 'cta.clicked',
                                            metadata: const <String, dynamic>{
                                              'module': 'login',
                                              'cta_id': 'submit_google_login',
                                              'surface': 'social_login',
                                            },
                                          );
                                          _handleGoogleSignIn();
                                        },
                                  icon: const Icon(
                                    Icons.g_mobiledata,
                                    color: Colors.red,
                                    size: 24,
                                  ),
                                  label: Text(
                                      AppStrings.of(context, 'auth.google')),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    side: BorderSide(
                                        color: colorScheme.outlineVariant),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isLoading
                                      ? null
                                      : () {
                                          TelemetryService.instance.logEvent(
                                            event: 'cta.clicked',
                                            metadata: const <String, dynamic>{
                                              'module': 'login',
                                              'cta_id':
                                                  'submit_microsoft_login',
                                              'surface': 'social_login',
                                            },
                                          );
                                          _handleMicrosoftSignIn();
                                        },
                                  icon: const Icon(
                                    Icons.window,
                                    size: 20,
                                    color: Color(0xFF00A4EF),
                                  ),
                                  label: Text(
                                      AppStrings.of(context, 'auth.microsoft')),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    side: BorderSide(
                                        color: colorScheme.outlineVariant),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 32),

                          Text(
                            AppStrings.of(context, 'auth.provisioningNote'),
                            style: textTheme.bodyMedium
                                ?.copyWith(color: secondaryTextColor),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPillarChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  String _authErrorMessage(BuildContext context, String code,
      {String? fallback}) {
    switch (code) {
      case 'user-not-found':
        return AppStrings.of(context, 'auth.error.userNotFound');
      case 'wrong-password':
        return AppStrings.of(context, 'auth.error.wrongPassword');
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return AppStrings.of(context, 'auth.error.invalidCredential');
      case 'invalid-password':
        return AppStrings.of(context, 'auth.error.wrongPassword');
      case 'email-already-in-use':
        return AppStrings.of(context, 'auth.error.emailInUse');
      case 'weak-password':
        return AppStrings.of(context, 'auth.error.weakPassword');
      case 'invalid-email':
        return AppStrings.of(context, 'auth.error.invalidEmail');
      case 'user-disabled':
        return AppStrings.of(context, 'auth.error.userDisabled');
      case 'too-many-requests':
        return AppStrings.of(context, 'auth.error.tooManyRequests');
      case 'network-request-failed':
        return AppStrings.of(context, 'auth.error.networkFailed');
      case 'operation-not-allowed':
        return AppStrings.of(context, 'auth.error.operationNotAllowed');
      case 'invalid-api-key':
        return AppStrings.of(context, 'auth.error.invalidApiKey');
      case 'app-not-authorized':
        return AppStrings.of(context, 'auth.error.appNotAuthorized');
      case 'unknown':
      case 'internal-error':
      case 'channel-error':
        return fallback ?? AppStrings.of(context, 'auth.error.generic');
      case 'popup-closed-by-user':
        return AppStrings.of(context, 'auth.error.popupClosed');
      case 'popup-blocked':
        return AppStrings.of(context, 'auth.error.popupBlocked');
      default:
        return fallback ?? AppStrings.of(context, 'auth.error.generic');
    }
  }

  String _authErrorMessageFromException(
      BuildContext context, FirebaseAuthException e) {
    final String message = (e.message ?? '').toLowerCase();

    if (message.contains('invalid-login-credentials') ||
        message.contains('invalid_credential') ||
        message.contains('wrong-password')) {
      return AppStrings.of(context, 'auth.error.invalidCredential');
    }

    if (message.contains('network') ||
        message.contains('network-request-failed')) {
      return AppStrings.of(context, 'auth.error.networkFailed');
    }

    if (message.contains('too-many-requests')) {
      return AppStrings.of(context, 'auth.error.tooManyRequests');
    }

    final String? appStateError = context.read<AppState>().error;
    final String? fallback = appStateError?.isNotEmpty == true
        ? appStateError
        : (e.message?.isNotEmpty == true ? e.message : null);

    return _authErrorMessage(context, e.code, fallback: fallback);
  }

  String _normalizeAuthExceptionMessage(
      BuildContext context, Object error, String fallback) {
    final RegExp codePattern = RegExp(r'firebase_auth\/([a-z\-]+)');
    final Match? match = codePattern.firstMatch(error.toString().toLowerCase());
    if (match != null && match.groupCount >= 1) {
      final String normalizedCode = match.group(1)!;
      return _authErrorMessage(context, normalizedCode, fallback: fallback);
    }

    return fallback;
  }
}
