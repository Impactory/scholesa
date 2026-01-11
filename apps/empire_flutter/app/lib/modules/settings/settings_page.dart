import 'package:flutter/material.dart';
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
  bool _darkMode = false;
  bool _biometricEnabled = false;
  String _language = 'en';
  String _timeZone = 'auto';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Colors.grey.shade100,
              Colors.white,
              Colors.grey.shade50,
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
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(16),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.settings, color: Colors.white, size: 28),
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
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
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
    return _SettingsSection(
      title: 'Appearance',
      children: <Widget>[
        _SettingsToggle(
          icon: Icons.dark_mode,
          title: 'Dark Mode',
          subtitle: 'Use dark theme',
          value: _darkMode,
          onChanged: (bool value) {
            setState(() => _darkMode = value);
            _showComingSoon('Dark mode');
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
          onTap: () {},
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Danger Zone',
            style: TextStyle(
              color: ScholesaColors.error,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ScholesaColors.error.withOpacity(0.3)),
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
                const Divider(height: 1),
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
    // Navigation handled by parent
  }

  void _showChangePasswordSheet() {
    _showComingSoon('Change Password');
  }

  void _showChangeEmailSheet() {
    _showComingSoon('Change Email');
  }

  void _showChangePhoneSheet() {
    _showComingSoon('Change Phone');
  }

  void _showNotificationPreferences() {
    _showComingSoon('Notification Preferences');
  }

  void _showLanguageSelector() {
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
    _showComingSoon('Time Zone Selection');
  }

  void _openPrivacyPolicy() {
    _showComingSoon('Privacy Policy');
  }

  void _openTermsOfService() {
    _showComingSoon('Terms of Service');
  }

  void _requestDataDownload() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Data download request submitted'),
        backgroundColor: ScholesaColors.success,
      ),
    );
  }

  void _openHelpCenter() {
    _showComingSoon('Help Center');
  }

  void _showFeedbackSheet() {
    _showComingSoon('Feedback');
  }

  void _rateApp() {
    _showComingSoon('App Rating');
  }

  void _confirmSignOut() {
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
              onPressed: () {
                Navigator.pop(context);
                // Sign out logic
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon'),
        backgroundColor: Colors.grey.shade800,
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: List<Widget>.generate(
                children.length * 2 - 1,
                (int index) {
                  if (index.isOdd) {
                    return const Divider(height: 1);
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
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? Colors.grey).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor ?? Colors.grey[700], size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
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
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.grey[700], size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: ScholesaColors.success,
      ),
    );
  }
}
