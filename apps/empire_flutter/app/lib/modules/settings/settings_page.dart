import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../auth/app_state.dart';
import '../../auth/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/theme_service.dart';
import '../../services/telemetry_service.dart';
import '../../ui/localization/inline_locale_text.dart';
import '../../ui/theme/scholesa_theme.dart';

const String _androidStorePackageId = 'com.scholesa.app';
const String _iosStoreLookupBundleId = 'com.scholesa.app';

const Map<String, String> _settingsZhCn = <String, String>{
  'Settings': '设置',
  'Customize your experience': '自定义你的使用体验',
  'Account': '账户',
  'Profile': '个人资料',
  'Edit your profile information': '编辑个人资料信息',
  'Change Password': '修改密码',
  'Update your password': '更新你的密码',
  'Email': '电子邮箱',
  'Phone Number': '电话号码',
  'Notifications': '通知',
  'Enable Notifications': '启用通知',
  'Receive app notifications': '接收应用通知',
  'Email Notifications': '邮件通知',
  'Receive updates via email': '通过邮件接收更新',
  'Push Notifications': '推送通知',
  'Receive push notifications': '接收推送通知',
  'Notification Preferences': '通知偏好',
  'Choose what to be notified about': '选择希望接收的通知内容',
  'Appearance': '外观',
  'Theme Preference': '主题偏好',
  'Dark Mode': '深色模式',
  'Use dark theme': '使用深色主题',
  'Follow System Theme': '跟随系统主题',
  'Match your device appearance': '与设备外观保持一致',
  'Language': '语言',
  'Time Zone': '时区',
  'Automatic': '自动',
  'Privacy & Security': '隐私与安全',
  'Biometric Login': '生物识别登录',
  'Use fingerprint or face to login': '使用指纹或面容登录',
  'Privacy Policy': '隐私政策',
  'Read our privacy policy': '阅读我们的隐私政策',
  'Terms of Service': '服务条款',
  'Read our terms of service': '阅读我们的服务条款',
  'Download My Data': '下载我的数据',
  'Get a copy of your data': '获取你的数据副本',
  'About': '关于',
  'App Version': '应用版本',
  'Help & Support': '帮助与支持',
  'Get help or contact us': '获取帮助或联系我们',
  'Send Feedback': '发送反馈',
  'Help us improve the app': '帮助我们改进应用',
  'Rate the App': '评价应用',
  'Love Scholesa? Rate us!': '喜欢 Scholesa？欢迎评价！',
  'Danger Zone': '高风险操作区',
  'Sign Out': '退出登录',
  'Sign out of your account': '退出你的账户',
  'Delete Account': '删除账户',
  'Permanently delete your account': '永久删除你的账户',
  'English': '英语',
  'Change Email': '修改邮箱',
  'Change Phone': '修改电话',
  'System': '系统',
  'Light': '浅色',
  'Dark': '深色',
  'Select Language': '选择语言',
  'Data export requests are not available in the app yet. Contact support with your site ID to request your data.':
      '应用内暂不支持数据导出请求。请附上你的站点 ID 联系支持团队以申请数据副本。',
    'We could not open your email app right now. Contact support@scholesa.com with your site ID to request your data.':
      '目前无法打开你的邮件应用。请附上你的站点 ID 联系 support@scholesa.com 申请数据副本。',
  'Help Center': '帮助中心',
  'Feedback': '反馈',
  'App Rating': '应用评分',
  'Scholesa version 1.0.0 (Build 1).': 'Scholesa 版本 1.0.0（Build 1）。',
  'Close': '关闭',
  'Are you sure you want to sign out?': '确定要退出登录吗？',
  'Cancel': '取消',
  'This action cannot be undone. All your data will be permanently deleted.':
      '此操作无法撤销。你的所有数据都将被永久删除。',
  'Submit': '提交',
  'is available by request. Submit this request now?': '可按请求提供。现在提交此请求吗？',
  'request submitted': '请求已提交',
  'Current Password': '当前密码',
  'New Password': '新密码',
  'Confirm Password': '确认密码',
  'Save': '保存',
  'Update Email': '更新邮箱',
  'Enter current password': '输入当前密码',
  'Enter a new password (min 8 characters)': '输入新密码（至少 8 个字符）',
  'Re-enter new password': '再次输入新密码',
  'Enter new email': '输入新邮箱',
  'Phone Number Updated': '电话号码已更新',
  'Password Updated': '密码已更新',
  'Email Update Requested': '邮箱更新请求已提交',
  'Check your inbox to verify your new email.': '请检查收件箱以验证新邮箱。',
  'Update Phone': '更新电话',
  'Enter phone number': '输入电话号码',
  'Choose Time Zone': '选择时区',
  'UTC+8 (Singapore)': 'UTC+8（新加坡）',
  'UTC+1 (Madrid)': 'UTC+1（马德里）',
  'UTC-5 (New York)': 'UTC-5（纽约）',
  'Privacy Policy Notice': '隐私政策说明',
  'Your data is processed according to Scholesa privacy standards and your site policies.':
      '你的数据将根据 Scholesa 隐私标准和站点政策进行处理。',
  'Terms of Service Notice': '服务条款说明',
  'Use of Scholesa requires compliance with site and platform safety standards.':
      '使用 Scholesa 需要遵守站点与平台的安全标准。',
  'Help Center Contact': '帮助中心联系方式',
  'Contact support at support@scholesa.com with your site ID and issue details.':
      '请发送邮件至 support@scholesa.com，并附上站点 ID 和问题详情。',
  'Send': '发送',
  'Feedback submission is not available in the app yet. Contact support if you need follow-up.':
      '应用内暂不支持反馈提交。如需跟进，请联系支持团队。',
  'Thanks for helping improve Scholesa.': '感谢你帮助改进 Scholesa。',
  'Please enter feedback before sending.': '发送前请输入反馈内容。',
  'In-app rating is not available yet. Please rate Scholesa in your app store when the listing is live.':
      '应用内暂不支持评分。待应用商店上架后，请在商店中评价 Scholesa。',
  'We could not open the store rating page right now. Please try again later.':
      '目前无法打开商店评分页面。请稍后再试。',
  'Delete Account Confirmation': '删除账户确认',
  'Enter current password to confirm account deletion.': '输入当前密码以确认删除账户。',
  'Delete': '删除',
  'Not set': '未设置',
  'Managed in profile': '在个人资料中管理',
  'Chinese (Simplified)': '简体中文',
  'Chinese (Traditional)': '繁体中文',
};

const Map<String, String> _settingsZhTw = <String, String>{
  'Settings': '設定',
  'Customize your experience': '自訂你的使用體驗',
  'Account': '帳戶',
  'Profile': '個人資料',
  'Edit your profile information': '編輯個人資料資訊',
  'Change Password': '變更密碼',
  'Update your password': '更新你的密碼',
  'Email': '電子郵件',
  'Phone Number': '電話號碼',
  'Notifications': '通知',
  'Enable Notifications': '啟用通知',
  'Receive app notifications': '接收應用通知',
  'Email Notifications': '電子郵件通知',
  'Receive updates via email': '透過電子郵件接收更新',
  'Push Notifications': '推播通知',
  'Receive push notifications': '接收推播通知',
  'Notification Preferences': '通知偏好',
  'Choose what to be notified about': '選擇希望接收的通知內容',
  'Appearance': '外觀',
  'Theme Preference': '主題偏好',
  'Dark Mode': '深色模式',
  'Use dark theme': '使用深色主題',
  'Follow System Theme': '跟隨系統主題',
  'Match your device appearance': '與裝置外觀保持一致',
  'Language': '語言',
  'Time Zone': '時區',
  'Automatic': '自動',
  'Privacy & Security': '隱私與安全',
  'Biometric Login': '生物辨識登入',
  'Use fingerprint or face to login': '使用指紋或臉部辨識登入',
  'Privacy Policy': '隱私政策',
  'Read our privacy policy': '閱讀我們的隱私政策',
  'Terms of Service': '服務條款',
  'Read our terms of service': '閱讀我們的服務條款',
  'Download My Data': '下載我的資料',
  'Get a copy of your data': '取得你的資料副本',
  'About': '關於',
  'App Version': '應用版本',
  'Help & Support': '說明與支援',
  'Get help or contact us': '取得協助或聯絡我們',
  'Send Feedback': '傳送回饋',
  'Help us improve the app': '幫助我們改善應用',
  'Rate the App': '評價應用',
  'Love Scholesa? Rate us!': '喜歡 Scholesa？歡迎評價！',
  'Danger Zone': '高風險操作區',
  'Sign Out': '登出',
  'Sign out of your account': '登出你的帳戶',
  'Delete Account': '刪除帳戶',
  'Permanently delete your account': '永久刪除你的帳戶',
  'English': '英文',
  'Change Email': '變更電子郵件',
  'Change Phone': '變更電話',
  'System': '系統',
  'Light': '淺色',
  'Dark': '深色',
  'Select Language': '選擇語言',
  'Data export requests are not available in the app yet. Contact support with your site ID to request your data.':
      'App 內暫不支援資料匯出請求。請附上你的站點 ID 聯絡支援團隊以申請資料副本。',
    'We could not open your email app right now. Contact support@scholesa.com with your site ID to request your data.':
      '目前無法開啟你的郵件 App。請附上你的站點 ID 聯絡 support@scholesa.com 申請資料副本。',
  'Help Center': '說明中心',
  'Feedback': '回饋',
  'App Rating': '應用評分',
  'Scholesa version 1.0.0 (Build 1).': 'Scholesa 版本 1.0.0（Build 1）。',
  'Close': '關閉',
  'Are you sure you want to sign out?': '確定要登出嗎？',
  'Cancel': '取消',
  'This action cannot be undone. All your data will be permanently deleted.':
      '此操作無法復原。你的所有資料都將被永久刪除。',
  'Submit': '提交',
  'is available by request. Submit this request now?': '可依申請提供。現在送出此請求嗎？',
  'request submitted': '請求已提交',
  'Current Password': '目前密碼',
  'New Password': '新密碼',
  'Confirm Password': '確認密碼',
  'Save': '儲存',
  'Update Email': '更新電子郵件',
  'Enter current password': '輸入目前密碼',
  'Enter a new password (min 8 characters)': '輸入新密碼（至少 8 個字元）',
  'Re-enter new password': '再次輸入新密碼',
  'Enter new email': '輸入新電子郵件',
  'Phone Number Updated': '電話號碼已更新',
  'Password Updated': '密碼已更新',
  'Email Update Requested': '電子郵件更新請求已提交',
  'Check your inbox to verify your new email.': '請檢查收件匣以驗證新電子郵件。',
  'Update Phone': '更新電話',
  'Enter phone number': '輸入電話號碼',
  'Choose Time Zone': '選擇時區',
  'UTC+8 (Singapore)': 'UTC+8（新加坡）',
  'UTC+1 (Madrid)': 'UTC+1（馬德里）',
  'UTC-5 (New York)': 'UTC-5（紐約）',
  'Privacy Policy Notice': '隱私政策說明',
  'Your data is processed according to Scholesa privacy standards and your site policies.':
      '你的資料會依據 Scholesa 隱私標準與站點政策進行處理。',
  'Terms of Service Notice': '服務條款說明',
  'Use of Scholesa requires compliance with site and platform safety standards.':
      '使用 Scholesa 需要遵守站點與平台的安全標準。',
  'Help Center Contact': '說明中心聯絡方式',
  'Contact support at support@scholesa.com with your site ID and issue details.':
      '請寄信至 support@scholesa.com，並附上站點 ID 與問題詳情。',
  'Send': '傳送',
  'Feedback submission is not available in the app yet. Contact support if you need follow-up.':
      'App 內暫不支援回饋提交。如需後續協助，請聯絡支援團隊。',
  'Thanks for helping improve Scholesa.': '感謝你協助改善 Scholesa。',
  'Please enter feedback before sending.': '傳送前請先輸入回饋內容。',
  'In-app rating is not available yet. Please rate Scholesa in your app store when the listing is live.':
      'App 內暫不支援評分。待應用商店上架後，請在商店中評價 Scholesa。',
  'We could not open the store rating page right now. Please try again later.':
      '目前無法打開商店評分頁面。請稍後再試。',
  'Delete Account Confirmation': '刪除帳戶確認',
  'Enter current password to confirm account deletion.': '輸入目前密碼以確認刪除帳戶。',
  'Delete': '刪除',
  'Not set': '未設定',
  'Managed in profile': '在個人資料中管理',
  'Chinese (Simplified)': '簡體中文',
  'Chinese (Traditional)': '繁體中文',
};

String _tSettings(BuildContext context, String input) {
  return InlineLocaleText.of(
    context,
    input,
    zhCn: _settingsZhCn,
    zhTw: _settingsZhTw,
  );
}

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
  String _timeZone = 'auto';
  bool _didLoadPreferences = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadPreferences) return;
    final AppState appState = context.read<AppState>();
    _notificationsEnabled = appState.notificationsEnabled;
    _emailNotifications = appState.emailNotifications;
    _pushNotifications = appState.pushNotifications;
    _biometricEnabled = appState.biometricEnabled;
    _language = appState.preferredLocaleCode;
    _timeZone = appState.timeZone;
    _didLoadPreferences = true;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final AppState appState = context.watch<AppState>();
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
            SliverToBoxAdapter(child: _buildAccountSection(appState)),
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
                    _tSettings(context, 'Settings'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    _tSettings(context, 'Customize your experience'),
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

  Widget _buildAccountSection(AppState appState) {
    return _SettingsSection(
      title: _tSettings(context, 'Account'),
      children: <Widget>[
        _SettingsTile(
          icon: Icons.person,
          title: _tSettings(context, 'Profile'),
          subtitle: _tSettings(context, 'Edit your profile information'),
          onTap: () => _navigateTo('profile'),
        ),
        _SettingsTile(
          icon: Icons.lock,
          title: _tSettings(context, 'Change Password'),
          subtitle: _tSettings(context, 'Update your password'),
          onTap: () => _showChangePasswordSheet(),
        ),
        _SettingsTile(
          icon: Icons.email,
          title: _tSettings(context, 'Email'),
          subtitle: (appState.email?.trim().isNotEmpty ?? false)
              ? appState.email!.trim()
              : _tSettings(context, 'Not set'),
          onTap: () => _showChangeEmailSheet(),
        ),
        _SettingsTile(
          icon: Icons.phone,
          title: _tSettings(context, 'Phone Number'),
          subtitle: _tSettings(context, 'Managed in profile'),
          onTap: () => _showChangePhoneSheet(),
        ),
      ],
    );
  }

  Widget _buildNotificationsSection() {
    return _SettingsSection(
      title: _tSettings(context, 'Notifications'),
      children: <Widget>[
        _SettingsToggle(
          icon: Icons.notifications,
          title: _tSettings(context, 'Enable Notifications'),
          subtitle: _tSettings(context, 'Receive app notifications'),
          value: _notificationsEnabled,
          onChanged: (bool value) {
            setState(() => _notificationsEnabled = value);
            _persistPreferences(<String, dynamic>{
              'notificationsEnabled': value,
            });
          },
        ),
        if (_notificationsEnabled) ...<Widget>[
          _SettingsToggle(
            icon: Icons.email_outlined,
            title: _tSettings(context, 'Email Notifications'),
            subtitle: _tSettings(context, 'Receive updates via email'),
            value: _emailNotifications,
            onChanged: (bool value) {
              setState(() => _emailNotifications = value);
              _persistPreferences(<String, dynamic>{
                'emailNotifications': value,
              });
            },
          ),
          _SettingsToggle(
            icon: Icons.phone_android,
            title: _tSettings(context, 'Push Notifications'),
            subtitle: _tSettings(context, 'Receive push notifications'),
            value: _pushNotifications,
            onChanged: (bool value) {
              setState(() => _pushNotifications = value);
              _persistPreferences(<String, dynamic>{
                'pushNotifications': value,
              });
            },
          ),
        ],
        _SettingsTile(
          icon: Icons.tune,
          title: _tSettings(context, 'Notification Preferences'),
          subtitle: _tSettings(context, 'Choose what to be notified about'),
          onTap: () => _showNotificationPreferences(),
        ),
      ],
    );
  }

  Widget _buildAppearanceSection() {
    final ThemeService themeService = context.watch<ThemeService>();
    return _SettingsSection(
      title: _tSettings(context, 'Appearance'),
      children: <Widget>[
        _SettingsTile(
          icon: Icons.palette_outlined,
          title: _tSettings(context, 'Theme Preference'),
          subtitle: themeService.modeLabel(),
          onTap: () => _showThemeSelector(themeService),
        ),
        _SettingsToggle(
          icon: Icons.dark_mode,
          title: _tSettings(context, 'Dark Mode'),
          subtitle: _tSettings(context, 'Use dark theme'),
          value: themeService.themeMode == ThemeMode.dark,
          onChanged: (bool value) => _applyDarkMode(themeService, value),
        ),
        _SettingsToggle(
          icon: Icons.brightness_auto,
          title: _tSettings(context, 'Follow System Theme'),
          subtitle: _tSettings(context, 'Match your device appearance'),
          value: themeService.followSystem,
          onChanged: (bool value) {
            themeService
                .setThemeMode(value ? ThemeMode.system : ThemeMode.light);
          },
        ),
        _SettingsTile(
          icon: Icons.language,
          title: _tSettings(context, 'Language'),
          subtitle: _getLanguageName(_language),
          onTap: () => _showLanguageSelector(),
        ),
        _SettingsTile(
          icon: Icons.schedule,
          title: _tSettings(context, 'Time Zone'),
          subtitle: _timeZone == 'auto'
              ? _tSettings(context, 'Automatic')
              : _timeZone,
          onTap: () => _showTimeZoneSelector(),
        ),
      ],
    );
  }

  Widget _buildPrivacySection() {
    return _SettingsSection(
      title: _tSettings(context, 'Privacy & Security'),
      children: <Widget>[
        _SettingsToggle(
          icon: Icons.fingerprint,
          title: _tSettings(context, 'Biometric Login'),
          subtitle: _tSettings(context, 'Use fingerprint or face to login'),
          value: _biometricEnabled,
          onChanged: (bool value) {
            setState(() => _biometricEnabled = value);
            _persistPreferences(<String, dynamic>{
              'biometricEnabled': value,
            });
          },
        ),
        _SettingsTile(
          icon: Icons.shield,
          title: _tSettings(context, 'Privacy Policy'),
          subtitle: _tSettings(context, 'Read our privacy policy'),
          onTap: () => _openPrivacyPolicy(),
        ),
        _SettingsTile(
          icon: Icons.description,
          title: _tSettings(context, 'Terms of Service'),
          subtitle: _tSettings(context, 'Read our terms of service'),
          onTap: () => _openTermsOfService(),
        ),
        _SettingsTile(
          icon: Icons.download,
          title: _tSettings(context, 'Download My Data'),
          subtitle: _tSettings(context, 'Get a copy of your data'),
          onTap: () => _requestDataDownload(),
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return _SettingsSection(
      title: _tSettings(context, 'About'),
      children: <Widget>[
        _SettingsTile(
          icon: Icons.info,
          title: _tSettings(context, 'App Version'),
          subtitle: '1.0.0 (Build 1)',
          onTap: () => _showAppVersionDetails(),
        ),
        _SettingsTile(
          icon: Icons.help,
          title: _tSettings(context, 'Help & Support'),
          subtitle: _tSettings(context, 'Get help or contact us'),
          onTap: () => _openHelpCenter(),
        ),
        _SettingsTile(
          icon: Icons.feedback,
          title: _tSettings(context, 'Send Feedback'),
          subtitle: _tSettings(context, 'Help us improve the app'),
          onTap: () => _showFeedbackSheet(),
        ),
        _SettingsTile(
          icon: Icons.star,
          title: _tSettings(context, 'Rate the App'),
          subtitle: _tSettings(context, 'Love Scholesa? Rate us!'),
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
            _tSettings(context, 'Danger Zone'),
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
                  title: _tSettings(context, 'Sign Out'),
                  subtitle: _tSettings(context, 'Sign out of your account'),
                  iconColor: ScholesaColors.error,
                  onTap: () => _confirmSignOut(),
                ),
                Divider(height: 1, color: colorScheme.outlineVariant),
                _SettingsTile(
                  icon: Icons.delete_forever,
                  title: _tSettings(context, 'Delete Account'),
                  subtitle:
                      _tSettings(context, 'Permanently delete your account'),
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
    switch (code) {
      case 'zh-CN':
        return _tSettings(context, 'Chinese (Simplified)');
      case 'zh-TW':
        return _tSettings(context, 'Chinese (Traditional)');
      case 'en':
      default:
        return _tSettings(context, 'English');
    }
  }

  void _navigateTo(String route) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{'cta': 'settings_navigate', 'route': route},
    );
    if (route == 'profile') {
      context.go('/profile');
      return;
    }
  }

  void _showChangePasswordSheet() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{'cta': 'settings_change_password'},
    );
    final TextEditingController currentPasswordController =
        TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext bottomSheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: _tSettings(context, 'Current Password'),
                  hintText: _tSettings(context, 'Enter current password'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: _tSettings(context, 'New Password'),
                  hintText: _tSettings(
                      context, 'Enter a new password (min 8 characters)'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: _tSettings(context, 'Confirm Password'),
                  hintText: _tSettings(context, 'Re-enter new password'),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(bottomSheetContext),
                      child: Text(_tSettings(context, 'Cancel')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final AuthService authService =
                            context.read<AuthService>();
                        final String validationMessage = _tSettings(
                            context, 'Enter a new password (min 8 characters)');
                        final String successMessage =
                            _tSettings(context, 'Password Updated');
                        final String currentPassword =
                            currentPasswordController.text.trim();
                        final String newPassword =
                            newPasswordController.text.trim();
                        final String confirmPassword =
                            confirmPasswordController.text.trim();

                        if (newPassword.length < 8 ||
                            newPassword != confirmPassword) {
                          _showErrorSnackBar(validationMessage);
                          return;
                        }

                        try {
                          await authService.updatePassword(
                            currentPassword: currentPassword,
                            newPassword: newPassword,
                          );
                          if (!context.mounted) return;
                          Navigator.pop(bottomSheetContext);
                          _showSuccessSnackBar(successMessage);
                        } catch (error) {
                          if (!context.mounted) return;
                          _showErrorSnackBar(_mapActionError(error));
                        }
                      },
                      child: Text(_tSettings(context, 'Save')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showChangeEmailSheet() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{'cta': 'settings_change_email'},
    );
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext bottomSheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: _tSettings(context, 'Update Email'),
                  hintText: _tSettings(context, 'Enter new email'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: _tSettings(context, 'Current Password'),
                  hintText: _tSettings(context, 'Enter current password'),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(bottomSheetContext),
                      child: Text(_tSettings(context, 'Cancel')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final AuthService authService =
                            context.read<AuthService>();
                        final String invalidEmailMessage =
                            _tSettings(context, 'Enter new email');
                        final String emailRequestedMessage =
                            _tSettings(context, 'Email Update Requested');
                        final String verifyInboxMessage = _tSettings(context,
                            'Check your inbox to verify your new email.');
                        final String newEmail = emailController.text.trim();
                        final String currentPassword =
                            passwordController.text.trim();
                        if (newEmail.isEmpty || !newEmail.contains('@')) {
                          _showErrorSnackBar(invalidEmailMessage);
                          return;
                        }

                        try {
                          await authService.updateEmail(
                            currentPassword: currentPassword,
                            newEmail: newEmail,
                          );
                          await _refreshAppStateFromFirestore();
                          if (!context.mounted) return;
                          Navigator.pop(bottomSheetContext);
                          _showSuccessSnackBar(emailRequestedMessage);
                          _showSuccessSnackBar(verifyInboxMessage);
                        } catch (error) {
                          if (!context.mounted) return;
                          _showErrorSnackBar(_mapActionError(error));
                        }
                      },
                      child: Text(_tSettings(context, 'Save')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showChangePhoneSheet() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{'cta': 'settings_change_phone'},
    );
    final TextEditingController phoneController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext bottomSheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: _tSettings(context, 'Update Phone'),
                  hintText: _tSettings(context, 'Enter phone number'),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(bottomSheetContext),
                      child: Text(_tSettings(context, 'Cancel')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final AuthService authService =
                            context.read<AuthService>();
                        final String phoneRequiredMessage =
                            _tSettings(context, 'Enter phone number');
                        final String phoneUpdatedMessage =
                            _tSettings(context, 'Phone Number Updated');
                        final String phoneNumber = phoneController.text.trim();
                        if (phoneNumber.isEmpty) {
                          _showErrorSnackBar(phoneRequiredMessage);
                          return;
                        }
                        try {
                          await authService
                              .updatePhoneNumberInProfile(phoneNumber);
                          await _refreshAppStateFromFirestore();
                          if (!context.mounted) return;
                          Navigator.pop(bottomSheetContext);
                          _showSuccessSnackBar(phoneUpdatedMessage);
                        } catch (error) {
                          if (!context.mounted) return;
                          _showErrorSnackBar(_mapActionError(error));
                        }
                      },
                      child: Text(_tSettings(context, 'Save')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showNotificationPreferences() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{
        'cta': 'settings_notification_preferences'
      },
    );
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext bottomSheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SwitchListTile(
                    title: Text(_tSettings(context, 'Email Notifications')),
                    value: _emailNotifications,
                    onChanged: (bool value) {
                      setState(() => _emailNotifications = value);
                      _persistPreferences(<String, dynamic>{
                        'emailNotifications': value,
                      });
                      setModalState(() {});
                    },
                  ),
                  SwitchListTile(
                    title: Text(_tSettings(context, 'Push Notifications')),
                    value: _pushNotifications,
                    onChanged: (bool value) {
                      setState(() => _pushNotifications = value);
                      _persistPreferences(<String, dynamic>{
                        'pushNotifications': value,
                      });
                      setModalState(() {});
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
          (ThemeMode.system, _tSettings(context, 'System')),
          (ThemeMode.light, _tSettings(context, 'Light')),
          (ThemeMode.dark, _tSettings(context, 'Dark')),
        ];
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _tSettings(context, 'Theme Preference'),
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
              Text(
                _tSettings(context, 'Select Language'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...<String>['en', 'zh-CN', 'zh-TW'].map((String code) {
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
                    _persistPreferences(<String, dynamic>{'locale': code});
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
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext bottomSheetContext) {
        final List<String> zones = <String>[
          'auto',
          _tSettings(context, 'UTC'),
          _tSettings(context, 'UTC+8 (Singapore)'),
          _tSettings(context, 'UTC+1 (Madrid)'),
          _tSettings(context, 'UTC-5 (New York)'),
        ];
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _tSettings(context, 'Choose Time Zone'),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...zones.map((String zone) {
                final bool isSelected = _timeZone == zone ||
                    (_timeZone == 'auto' && zone == 'auto');
                return ListTile(
                  title: Text(
                      zone == 'auto' ? _tSettings(context, 'Automatic') : zone),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: ScholesaColors.success)
                      : null,
                  onTap: () {
                    setState(() => _timeZone = zone);
                    _persistPreferences(<String, dynamic>{
                      'timeZone': zone,
                    });
                    Navigator.pop(bottomSheetContext);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _openPrivacyPolicy() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{'cta': 'settings_open_privacy_policy'},
    );
    _showInfoDialog(
      title: _tSettings(context, 'Privacy Policy Notice'),
      body: _tSettings(context,
          'Your data is processed according to Scholesa privacy standards and your site policies.'),
    );
  }

  void _openTermsOfService() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{
        'cta': 'settings_open_terms_of_service'
      },
    );
    _showInfoDialog(
      title: _tSettings(context, 'Terms of Service Notice'),
      body: _tSettings(context,
          'Use of Scholesa requires compliance with site and platform safety standards.'),
    );
  }

  Future<void> _requestDataDownload() async {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{'cta': 'settings_download_my_data'},
    );

    final AppState appState = context.read<AppState>();
    final User? currentUser = FirebaseAuth.instance.currentUser;
    final String siteId = appState.activeSiteId?.trim().isNotEmpty == true
        ? appState.activeSiteId!.trim()
        : 'Not set';
    final String userId = appState.userId?.trim().isNotEmpty == true
        ? appState.userId!.trim()
        : (currentUser?.uid ?? 'Not set');
    final String email = appState.email?.trim().isNotEmpty == true
        ? appState.email!.trim()
        : (currentUser?.email ?? 'Not set');
    final String displayName = appState.displayName?.trim().isNotEmpty == true
        ? appState.displayName!.trim()
        : (currentUser?.displayName ?? 'Not set');

    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@scholesa.com',
      queryParameters: <String, String>{
        'subject': 'Data export request - $siteId',
        'body': 'Hello Scholesa support.\n\nI would like to request a copy of my data.\n\nSite ID: $siteId\nUser ID: $userId\nName: $displayName\nEmail: $email\n\nPlease let me know if you need anything else.\n',
      },
    );

    final bool launched = await _tryLaunchExternalUri(emailUri);
    if (!mounted) {
      return;
    }
    if (!launched) {
      _showInfoDialog(
        title: _tSettings(context, 'Download My Data'),
        body: _tSettings(
          context,
          'We could not open your email app right now. Contact support@scholesa.com with your site ID to request your data.',
        ),
      );
    }
  }

  void _openHelpCenter() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{'cta': 'settings_open_help_center'},
    );
    _showInfoDialog(
      title: _tSettings(context, 'Help Center Contact'),
      body: _tSettings(context,
          'Contact support at support@scholesa.com with your site ID and issue details.'),
    );
  }

  void _showFeedbackSheet() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{'cta': 'settings_open_feedback'},
    );
    final TextEditingController feedbackController = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext bottomSheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: feedbackController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: _tSettings(context, 'Feedback'),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(bottomSheetContext),
                      child: Text(_tSettings(context, 'Cancel')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final String feedbackRequiredMessage = _tSettings(
                            context, 'Please enter feedback before sending.');
                        final String feedbackUnavailableMessage = _tSettings(
                            context,
                            'Feedback submission is not available in the app yet. Contact support if you need follow-up.');
                        final String feedback = feedbackController.text.trim();
                        if (feedback.isEmpty) {
                          _showErrorSnackBar(feedbackRequiredMessage);
                          return;
                        }
                        await TelemetryService.instance.logEvent(
                          event: 'settings.feedback.submitted',
                          metadata: <String, dynamic>{
                            'length': feedback.length
                          },
                        );
                        if (!context.mounted) return;
                        Navigator.pop(bottomSheetContext);
                        _showInfoDialog(
                          title: _tSettings(context, 'Send Feedback'),
                          body: feedbackUnavailableMessage,
                        );
                      },
                      child: Text(_tSettings(context, 'Send')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _rateApp() async {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{'cta': 'settings_rate_app'},
    );

    final Uri? ratingUri = await _resolveStoreRatingUri();
    if (!mounted) {
      return;
    }

    if (ratingUri == null) {
      _showInfoDialog(
        title: _tSettings(context, 'Rate the App'),
        body: _tSettings(
          context,
          'We could not open the store rating page right now. Please try again later.',
        ),
      );
      return;
    }

    final bool launched = await _launchStoreRatingUri(ratingUri);
    if (!mounted) {
      return;
    }
    if (!launched) {
      _showInfoDialog(
        title: _tSettings(context, 'Rate the App'),
        body: _tSettings(
          context,
          'We could not open the store rating page right now. Please try again later.',
        ),
      );
    }
  }

  Future<Uri?> _resolveStoreRatingUri() async {
    if (kIsWeb) {
      return _fallbackAndroidStoreUri;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return Uri.parse('market://details?id=$_androidStorePackageId');
      case TargetPlatform.iOS:
        return _lookupIosStoreRatingUri();
      default:
        return _fallbackAndroidStoreUri;
    }
  }

  Uri get _fallbackAndroidStoreUri => Uri.parse(
        'https://play.google.com/store/apps/details?id=$_androidStorePackageId',
      );

  Future<Uri?> _lookupIosStoreRatingUri() async {
    try {
      final http.Response response = await http.get(
        Uri.https('itunes.apple.com', '/lookup', <String, String>{
          'bundleId': _iosStoreLookupBundleId,
        }),
      );
      if (response.statusCode != 200) {
        return null;
      }
      final Map<String, dynamic>? payload =
          _asStringDynamicMap(jsonDecode(response.body));
      final List<dynamic> results =
          payload?['results'] as List<dynamic>? ?? <dynamic>[];
      for (final dynamic result in results) {
        final Map<String, dynamic>? data = _asStringDynamicMap(result);
        final String trackViewUrl =
            (data?['trackViewUrl'] as String? ?? '').trim();
        if (trackViewUrl.isNotEmpty) {
          return Uri.tryParse(trackViewUrl);
        }
      }
    } catch (error) {
      debugPrint('Unable to resolve iOS store rating URI: $error');
    }

    return null;
  }

  Future<bool> _launchStoreRatingUri(Uri ratingUri) async {
    final bool launchedPrimary = await _tryLaunchExternalUri(ratingUri);
    if (launchedPrimary) {
      return true;
    }

    if (ratingUri.scheme == 'market') {
      return _tryLaunchExternalUri(_fallbackAndroidStoreUri);
    }

    return false;
  }

  Future<bool> _tryLaunchExternalUri(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error) {
      debugPrint('Unable to launch external URI $uri: $error');
      return false;
    }
  }

  Map<String, dynamic>? _asStringDynamicMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (dynamic key, dynamic nestedValue) =>
            MapEntry<String, dynamic>(key.toString(), nestedValue),
      );
    }
    return null;
  }

  void _showAppVersionDetails() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{'cta': 'settings_open_app_version'},
    );
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(_tSettings(context, 'App Version')),
        content: Text(_tSettings(context, 'Scholesa version 1.0.0 (Build 1).')),
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
            child: Text(_tSettings(context, 'Close')),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut() {
    final AuthService authService = context.read<AuthService>();
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{'cta': 'settings_open_sign_out_dialog'},
    );
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(_tSettings(dialogContext, 'Sign Out')),
          content: Text(
              _tSettings(dialogContext, 'Are you sure you want to sign out?')),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_tSettings(dialogContext, 'Cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: const <String, dynamic>{
                    'cta': 'settings_confirm_sign_out'
                  },
                );
                Navigator.pop(dialogContext);
                await authService.signOut(source: 'settings_page');
                if (!mounted) return;
                context.go('/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ScholesaColors.error,
              ),
              child: Text(
                _tSettings(dialogContext, 'Sign Out'),
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
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(_tSettings(dialogContext, 'Delete Account')),
          content: Text(
            _tSettings(dialogContext,
                'This action cannot be undone. All your data will be permanently deleted.'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_tSettings(dialogContext, 'Cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: const <String, dynamic>{
                    'cta': 'settings_confirm_delete_account'
                  },
                );
                Navigator.pop(dialogContext);
                await _confirmDeleteAccountWithPassword();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ScholesaColors.error,
              ),
              child: Text(
                _tSettings(dialogContext, 'Delete Account'),
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteAccountWithPassword() async {
    final TextEditingController passwordController = TextEditingController();
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(_tSettings(context, 'Delete Account Confirmation')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(_tSettings(context,
                  'Enter current password to confirm account deletion.')),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: _tSettings(context, 'Current Password'),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_tSettings(context, 'Cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ScholesaColors.error,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                _tSettings(context, 'Delete'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;
    if (!mounted) return;

    try {
      final AuthService authService = context.read<AuthService>();
      await authService.deleteAccount(
        currentPassword: passwordController.text.trim(),
      );
      if (!mounted) return;
      context.go('/login');
    } catch (error) {
      if (!mounted) return;
      _showErrorSnackBar(_mapActionError(error));
    }
  }

  void _showInfoDialog({required String title, required String body}) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: Text(_tSettings(context, 'Close')),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  String _mapActionError(Object error) {
    if (error is FirebaseAuthException && error.message != null) {
      return error.message!;
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _persistPreferences(Map<String, dynamic> updates) async {
    try {
      final FirestoreService firestoreService =
          context.read<FirestoreService>();
      final Map<String, dynamic> payload = <String, dynamic>{};
      updates.forEach((String key, dynamic value) {
        payload['preferences.$key'] = value;
      });
      await firestoreService.updateUserProfile(payload);
      final Map<String, dynamic>? profile =
          await firestoreService.getUserProfile();
      if (!mounted || profile == null) return;
      context.read<AppState>().updateFromMeResponse(profile);
    } catch (error) {
      if (!mounted) return;
      _showErrorSnackBar(_mapActionError(error));
    }
  }

  Future<void> _refreshAppStateFromFirestore() async {
    final FirestoreService firestoreService = context.read<FirestoreService>();
    final Map<String, dynamic>? profile =
        await firestoreService.getUserProfile();
    if (!mounted || profile == null) return;
    context.read<AppState>().updateFromMeResponse(profile);
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
