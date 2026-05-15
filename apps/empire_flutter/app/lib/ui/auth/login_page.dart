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
  'Capability Evidence\nPlatform': '能力证据\n平台',
  'Empowering K-12 schools with mission-based learning,\nevidence-rich portfolios, and stage-based AI governance.':
      '通过任务式学习、证据型作品集和分阶段 AI 治理，赋能 K-12 学校。',
  'Sign in to capture Evidence, run Sessions, review Capability growth, and keep Portfolio proof connected.':
      '登录以采集证据、运行课程、审阅能力成长，并保持作品集证据连贯。',
  'Mission-based learning': '任务式学习',
  'Mission Evidence capture': '任务证据采集',
  'Habit coaching': '习惯教练',
  'Capability Review': '能力审阅',
  'Portfolio showcase': '作品集展示',
  'Portfolio proof': '作品集证据',
  'Discoverers': '发现者',
  'Builders': '建构者',
  'Explorers': '探索者',
  'Innovators': '创新者',
};

const Map<String, String> _loginZhTw = <String, String>{
  'Education 2.0\nPlatform': '教育 2.0\n平台',
  'Capability Evidence\nPlatform': '能力證據\n平台',
  'Empowering K-12 schools with mission-based learning,\nevidence-rich portfolios, and stage-based AI governance.':
      '透過任務式學習、證據型作品集和分階段 AI 治理，賦能 K-12 學校。',
  'Sign in to capture Evidence, run Sessions, review Capability growth, and keep Portfolio proof connected.':
      '登入以擷取證據、運行課程、審閱能力成長，並保持作品集證據連貫。',
  'Mission-based learning': '任務式學習',
  'Mission Evidence capture': '任務證據擷取',
  'Habit coaching': '習慣教練',
  'Capability Review': '能力審閱',
  'Portfolio showcase': '作品集展示',
  'Portfolio proof': '作品集證據',
  'Discoverers': '發現者',
  'Builders': '建構者',
  'Explorers': '探索者',
  'Innovators': '創新者',
};

String _tLogin(BuildContext context, String input) {
  return InlineLocaleText.of(context, input,
      zhCn: _loginZhCn, zhTw: _loginZhTw);
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
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String removedMessage =
        AppStrings.of(context, 'auth.rememberedAccountRemoved');
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

    messenger.showSnackBar(
      SnackBar(
        content: Text(removedMessage),
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
              final String initial = account.displayName.trim().isEmpty
                  ? account.email[0]
                  : account.displayName.trim()[0];
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
                        onPressed: () =>
                            _continueWithRememberedAccount(account),
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
    final Color headingColor = colorScheme.onSurface;
    final Color secondaryTextColor = colorScheme.onSurfaceVariant;
    final Color fieldFillColor = colorScheme.surfaceContainerHighest;
    final Color fieldTextColor = colorScheme.onSurface;
    final Color fieldHintColor = colorScheme.onSurfaceVariant;
    final Color fieldBorderColor = colorScheme.outlineVariant;
    final Color linkColor = colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Row(
        children: <Widget>[
          // Left side - decorative gradient panel (only on wide screens)
          if (isWide)
            Expanded(
              flex: 5,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      Color(0xFF0F172A),
                      Color(0xFF155E75),
                      Color(0xFF172033),
                    ],
                  ),
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
                          _tLogin(context, 'Capability Evidence\nPlatform'),
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.2,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _tLogin(context,
                              'Sign in to capture Evidence, run Sessions, review Capability growth, and keep Portfolio proof connected.'),
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 48),
                        // Feature highlights
                        _buildFeatureRow(Icons.rocket_launch_rounded,
                            _tLogin(context, 'Mission Evidence capture')),
                        const SizedBox(height: 16),
                        _buildFeatureRow(Icons.psychology_rounded,
                            _tLogin(context, 'Capability Review')),
                        const SizedBox(height: 16),
                        _buildFeatureRow(Icons.folder_special_rounded,
                            _tLogin(context, 'Portfolio proof')),
                        const Spacer(),
                        // Bottom pillars
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            _buildPillarChip(_tLogin(context, 'Discoverers'),
                                ScholesaColors.futureSkills),
                            _buildPillarChip(_tLogin(context, 'Builders'),
                                ScholesaColors.leadership),
                            _buildPillarChip(_tLogin(context, 'Explorers'),
                                ScholesaColors.info),
                            _buildPillarChip(_tLogin(context, 'Innovators'),
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
                                color: colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colorScheme.error,
                                ),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.error_outline_rounded,
                                    color: colorScheme.onErrorContainer,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        color: colorScheme.onErrorContainer,
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
                                  style: TextStyle(
                                    color: fieldTextColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    labelText:
                                        AppStrings.of(context, 'auth.email'),
                                    hintText: AppStrings.of(
                                        context, 'auth.emailHint'),
                                    labelStyle:
                                        TextStyle(color: secondaryTextColor),
                                    floatingLabelStyle:
                                        TextStyle(color: headingColor),
                                    hintStyle: TextStyle(color: fieldHintColor),
                                    prefixIcon: Icon(Icons.email_outlined,
                                        color: secondaryTextColor),
                                    filled: true,
                                    fillColor: fieldFillColor,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide:
                                          BorderSide(color: fieldBorderColor),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide:
                                          BorderSide(color: fieldBorderColor),
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
                                  style: TextStyle(
                                    color: fieldTextColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    labelText:
                                        AppStrings.of(context, 'auth.password'),
                                    hintText: AppStrings.of(
                                        context, 'auth.passwordHint'),
                                    labelStyle:
                                        TextStyle(color: secondaryTextColor),
                                    floatingLabelStyle:
                                        TextStyle(color: headingColor),
                                    hintStyle: TextStyle(color: fieldHintColor),
                                    prefixIcon: Icon(Icons.lock_outlined,
                                        color: secondaryTextColor),
                                    filled: true,
                                    fillColor: fieldFillColor,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide:
                                          BorderSide(color: fieldBorderColor),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide:
                                          BorderSide(color: fieldBorderColor),
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
                              Expanded(
                                child: Divider(
                                  color: colorScheme.outlineVariant,
                                ),
                              ),
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
                              Expanded(
                                child: Divider(
                                  color: colorScheme.outlineVariant,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Social sign in buttons
                          LayoutBuilder(
                            builder: (BuildContext context,
                                BoxConstraints constraints) {
                              final bool stackButtons =
                                  constraints.maxWidth < 380;
                              final List<Widget> buttons = <Widget>[
                                _buildSocialLoginButton(
                                  context: context,
                                  label: AppStrings.of(context, 'auth.google'),
                                  icon: const Icon(
                                    Icons.g_mobiledata,
                                    color: Colors.red,
                                    size: 24,
                                  ),
                                  ctaId: 'submit_google_login',
                                  onPressed: _handleGoogleSignIn,
                                ),
                                _buildSocialLoginButton(
                                  context: context,
                                  label:
                                      AppStrings.of(context, 'auth.microsoft'),
                                  icon: const Icon(
                                    Icons.window,
                                    size: 20,
                                    color: Color(0xFF00A4EF),
                                  ),
                                  ctaId: 'submit_microsoft_login',
                                  onPressed: _handleMicrosoftSignIn,
                                ),
                              ];

                              if (stackButtons) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    buttons.first,
                                    const SizedBox(height: 12),
                                    buttons.last,
                                  ],
                                );
                              }

                              return Row(
                                children: <Widget>[
                                  Expanded(child: buttons.first),
                                  const SizedBox(width: 16),
                                  Expanded(child: buttons.last),
                                ],
                              );
                            },
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

  Widget _buildSocialLoginButton({
    required BuildContext context,
    required String label,
    required Widget icon,
    required String ctaId,
    required VoidCallback onPressed,
  }) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: _isLoading
          ? null
          : () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'module': 'login',
                  'cta_id': ctaId,
                  'surface': 'social_login',
                },
              );
              onPressed();
            },
      icon: icon,
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
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
