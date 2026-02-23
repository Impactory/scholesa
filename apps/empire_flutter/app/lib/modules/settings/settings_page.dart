import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../auth/auth_service.dart';
import '../../services/theme_service.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';

/// Settings Page - App settings and preferences
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Settings state
  bool _notificationsEnabled = true;
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _biometricEnabled = false;
  String _language = 'en';
  final String _timeZone = 'auto';

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              colorScheme.surfaceContainerLowest,
              colorScheme.surface,
              colorScheme.surfaceContainerLow,
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildAccountSection()),
            SliverToBoxAdapter(child: _buildNotificationsSection()),
            SliverToBoxAdapter(child: _buildAppearanceSection()),
            SliverToBoxAdapter(child: _buildPrivacySection()),
            SliverToBoxAdapter(child: _buildAboutSection()),
            SliverToBoxAdapter(child: _buildDangerZone()),
            const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(Icons.settings,
                  color: colorScheme.onPrimaryContainer, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Settings',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    'Customize your experience',
                    style: TextStyle(
                        color: colorScheme.onSurfaceVariant, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSection() {
    return _SettingsSection(
      title: 'Account',
      children: <Widget>[
        _SettingsTile(
          icon: Icons.person,
          title: 'Profile',
          subtitle: 'Edit your profile information',
          onTap: () => _navigateTo('profile'),
        ),
        _SettingsTile(
          icon: Icons.lock,
          title: 'Change Password',
          subtitle: 'Update your password',
          onTap: () => _showChangePasswordSheet(),
        ),
        _SettingsTile(
          icon: Icons.email,
          title: 'Email',
          subtitle: 'emma@example.com',
          onTap: () => _showChangeEmailSheet(),
        ),
        _SettingsTile(
          icon: Icons.phone,
          title: 'Phone Number',
          subtitle: '+1 234 567 8900',
          onTap: () => _showChangePhoneSheet(),
        ),
      ],
    );
  }

  Widget _buildNotificationsSection() {
    return _SettingsSection(
      title: 'Notifications',
      children: <Widget>[
        _SettingsToggle(
          icon: Icons.notifications,
          title: 'Enable Notifications',
          subtitle: 'Receive app notifications',
          value: _notificationsEnabled,
          onChanged: (bool value) {
            setState(() => _notificationsEnabled = value);
          },
        ),
        if (_notificationsEnabled) ...<Widget>[
          _SettingsToggle(
            icon: Icons.email_outlined,
            title: 'Email Notifications',
            subtitle: 'Receive updates via email',
            value: _emailNotifications,
            onChanged: (bool value) {
              setState(() => _emailNotifications = value);
            },
          ),
          _SettingsToggle(
            icon: Icons.phone_android,
            title: 'Push Notifications',
            subtitle: 'Receive push notifications',
            value: _pushNotifications,
            onChanged: (bool value) {
              setState(() => _pushNotifications = value);
            },
          ),
        ],
        _SettingsTile(
          icon: Icons.tune,
          title: 'Notification Preferences',
          subtitle: 'Choose what to be notified about',
          onTap: () => _showNotificationPreferences(),
        ),
      ],
    );
  }

  Widget _buildAppearanceSection() {
    final ThemeService themeService = context.watch<ThemeService>();
    return _SettingsSection(
      title: 'Appearance',
      children: <Widget>[
        _SettingsTile(
          icon: Icons.palette_outlined,
          title: 'Theme Preference',
          subtitle: themeService.modeLabel(),
          onTap: () => _showThemeSelector(themeService),
        ),
        _SettingsToggle(
          icon: Icons.dark_mode,
          title: 'Dark Mode',
          subtitle: 'Use dark theme',
          value: themeService.themeMode == ThemeMode.dark,
          onChanged: (bool value) => _applyDarkMode(themeService, value),
        ),
        _SettingsToggle(
          icon: Icons.brightness_auto,
          title: 'Follow System Theme',
          subtitle: 'Match your device appearance',
          value: themeService.followSystem,
          onChanged: (bool value) {
            themeService
                .setThemeMode(value ? ThemeMode.system : ThemeMode.light);
          },
        ),
        _SettingsTile(
          icon: Icons.language,
          title: 'Language',
          subtitle: _getLanguageName(_language),
          onTap: () => _showLanguageSelector(),
        ),
        _SettingsTile(
          icon: Icons.schedule,
          title: 'Time Zone',
          subtitle: _timeZone == 'auto' ? 'Automatic' : _timeZone,
          onTap: () => _showTimeZoneSelector(),
        ),
      ],
    );
  }

  Widget _buildPrivacySection() {
    return _SettingsSection(
      title: 'Privacy & Security',
      children: <Widget>[
        _SettingsToggle(
          icon: Icons.fingerprint,
          title: 'Biometric Login',
          subtitle: 'Use fingerprint or face to login',
          value: _biometricEnabled,
          onChanged: (bool value) {
            setState(() => _biometricEnabled = value);
          },
        ),
        _SettingsTile(
          icon: Icons.shield,
          title: 'Privacy Policy',
          subtitle: 'Read our privacy policy',
          onTap: () => _openPrivacyPolicy(),
        ),
        _SettingsTile(
          icon: Icons.description,
          title: 'Terms of Service',
          subtitle: 'Read our terms of service',
          onTap: () => _openTermsOfService(),
        ),
        _SettingsTile(
          icon: Icons.download,
          title: 'Download My Data',
          subtitle: 'Get a copy of your data',
          onTap: () => _requestDataDownload(),
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return _SettingsSection(
      title: 'About',
      children: <Widget>[
        _SettingsTile(
          icon: Icons.info,
          title: 'App Version',
          subtitle: '1.0.0 (Build 1)',
          onTap: () => _showAppVersionDetails(),
        ),
        _SettingsTile(
          icon: Icons.help,
          title: 'Help & Support',
          subtitle: 'Get help or contact us',
          onTap: () => _openHelpCenter(),
        ),
        _SettingsTile(
          icon: Icons.feedback,
          title: 'Send Feedback',
          subtitle: 'Help us improve the app',
          onTap: () => _showFeedbackSheet(),
        ),
        _SettingsTile(
          icon: Icons.star,
          title: 'Rate the App',
          subtitle: 'Love Scholesa? Rate us!',
          onTap: () => _rateApp(),
        ),
      ],
    );
  }

  Widget _buildDangerZone() {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Danger Zone',
            style: TextStyle(
              color: colorScheme.error,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: colorScheme.error.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: <Widget>[
                _SettingsTile(
                  icon: Icons.logout,
                  title: 'Sign Out',
                  subtitle: 'Sign out of your account',
                  iconColor: ScholesaColors.error,
                  onTap: () => _confirmSignOut(),
                ),
                Divider(height: 1, color: colorScheme.outlineVariant),
                _SettingsTile(
                  icon: Icons.delete_forever,
                  title: 'Delete Account',
                  subtitle: 'Permanently delete your account',
                  iconColor: ScholesaColors.error,
                  onTap: () => _confirmDeleteAccount(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getLanguageName(String code) {
    const Map<String, String> languages = <String, String>{
      'en': 'English',
      'es': 'Español',
      'zh': '中文',
      'ms': 'Bahasa Melayu',
    };
    return languages[code] ?? 'English';
  }

  void _navigateTo(String route) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{'cta': 'settings_navigate', 'route': route},
    );
    // Navigation handled by parent
  }

  void _showChangePasswordSheet() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{'cta': 'settings_change_password'},
    );
    _showComingSoon('Change Password');
  }

  void _showChangeEmailSheet() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{'cta': 'settings_change_email'},
    );
    _showComingSoon('Change Email');
  }

  void _showChangePhoneSheet() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{'cta': 'settings_change_phone'},
    );
    _showComingSoon('Change Phone');
  }

  void _showNotificationPreferences() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{
        'cta': 'settings_notification_preferences'
      },
    );
    _showComingSoon('Notification Preferences');
  }

  void _applyDarkMode(ThemeService themeService, bool enabled) {
    themeService.setThemeMode(enabled ? ThemeMode.dark : ThemeMode.light);
  }

  void _showThemeSelector(ThemeService themeService) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{'cta': 'settings_open_theme_selector'},
    );
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        final List<(ThemeMode, String)> options = <(ThemeMode, String)>[
          (ThemeMode.system, 'System'),
          (ThemeMode.light, 'Light'),
          (ThemeMode.dark, 'Dark'),
        ];
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Theme Preference',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...options.map(((ThemeMode, String) option) {
                final ThemeMode mode = option.$1;
                final String label = option.$2;
                return ListTile(
                  title: Text(label),
                  trailing: themeService.themeMode == mode
                      ? const Icon(Icons.check, color: ScholesaColors.success)
                      : null,
                  onTap: () {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: <String, dynamic>{
                        'cta': 'settings_select_theme_mode',
                        'mode': mode.name,
                      },
                    );
                    themeService.setThemeMode(mode);
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showLanguageSelector() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{
        'cta': 'settings_open_language_selector'
      },
    );
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Select Language',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...<String>['en', 'es', 'zh', 'ms'].map((String code) {
                return ListTile(
                  title: Text(_getLanguageName(code)),
                  trailing: _language == code
                      ? const Icon(Icons.check, color: ScholesaColors.success)
                      : null,
                  onTap: () {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: <String, dynamic>{
                        'cta': 'settings_select_language',
                        'language': code,
                      },
                    );
                    setState(() => _language = code);
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showTimeZoneSelector() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{
        'cta': 'settings_open_timezone_selector'
      },
    );
    _showComingSoon('Time Zone Selection');
  }

  void _openPrivacyPolicy() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{'cta': 'settings_open_privacy_policy'},
    );
    _showComingSoon('Privacy Policy');
  }

  void _openTermsOfService() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{
        'cta': 'settings_open_terms_of_service'
      },
    );
    _showComingSoon('Terms of Service');
  }

  void _requestDataDownload() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{'cta': 'settings_download_my_data'},
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Data download request submitted'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  void _openHelpCenter() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{'cta': 'settings_open_help_center'},
    );
    _showComingSoon('Help Center');
  }

  void _showFeedbackSheet() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{'cta': 'settings_open_feedback'},
    );
    _showComingSoon('Feedback');
  }

  void _rateApp() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{'cta': 'settings_rate_app'},
    );
    _showComingSoon('App Rating');
  }

  void _showAppVersionDetails() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{'cta': 'settings_open_app_version'},
    );
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('App Version'),
        content: const Text('Scholesa version 1.0.0 (Build 1).'),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'cta': 'settings_close_app_version'
                },
              );
              Navigator.pop(dialogContext);
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{'cta': 'settings_open_sign_out_dialog'},
    );
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: const <String, dynamic>{
                    'cta': 'settings_confirm_sign_out'
                  },
                );
                Navigator.pop(context);
                final AuthService authService =
                    this.context.read<AuthService>();
                await authService.signOut();
                if (!mounted) return;
                this.context.go('/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ScholesaColors.error,
              ),
              child: const Text(
                'Sign Out',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteAccount() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{
        'cta': 'settings_open_delete_account_dialog'
      },
    );
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: const Text(
            'This action cannot be undone. All your data will be permanently deleted.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: const <String, dynamic>{
                    'cta': 'settings_confirm_delete_account'
                  },
                );
                Navigator.pop(context);
                // Delete account logic
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ScholesaColors.error,
              ),
              child: const Text(
                'Delete Account',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showComingSoon(String feature) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(feature),
        content: Text(
          '$feature is available by request. Submit this request now?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'cta': 'settings_cancel_coming_soon_request',
                  'feature': feature,
                },
              );
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'cta': 'settings_submit_coming_soon_request',
                  'feature': feature,
                },
              );
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$feature request submitted'),
                  backgroundColor: Theme.of(context).colorScheme.inverseSurface,
                ),
              );
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              children: List<Widget>.generate(
                children.length * 2 - 1,
                (int index) {
                  if (index.isOdd) {
                    return Divider(
                        height: 1, color: colorScheme.outlineVariant);
                  }
                  return children[index ~/ 2];
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconColor;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Color baseIconColor = iconColor ?? colorScheme.onSurfaceVariant;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: baseIconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: baseIconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
      ),
      trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
      onTap: () {
        TelemetryService.instance.logEvent(
          event: 'cta.clicked',
          metadata: <String, dynamic>{
            'cta': 'settings_tile',
            'title': title,
          },
        );
        onTap();
      },
    );
  }
}

class _SettingsToggle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: colorScheme.onSurfaceVariant, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
      ),
      trailing: Switch(
        value: value,
        onChanged: (bool nextValue) {
          TelemetryService.instance.logEvent(
            event: 'cta.clicked',
            metadata: <String, dynamic>{
              'cta': 'settings_toggle',
              'title': title,
              'value': nextValue,
            },
          );
          onChanged(nextValue);
        },
        activeThumbColor: ScholesaColors.success,
      ),
    );
  }
}
