import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../auth/auth_service.dart';
import '../../services/theme_service.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';

const Map<String, String> _settingsEs = <String, String>{
  'Settings': 'Configuración',
  'Customize your experience': 'Personaliza tu experiencia',
  'Account': 'Cuenta',
  'Profile': 'Perfil',
  'Edit your profile information': 'Edita la información de tu perfil',
  'Change Password': 'Cambiar contraseña',
  'Update your password': 'Actualiza tu contraseña',
  'Email': 'Correo electrónico',
  'Phone Number': 'Número de teléfono',
  'Notifications': 'Notificaciones',
  'Enable Notifications': 'Activar notificaciones',
  'Receive app notifications': 'Recibir notificaciones de la app',
  'Email Notifications': 'Notificaciones por correo',
  'Receive updates via email': 'Recibir actualizaciones por correo',
  'Push Notifications': 'Notificaciones push',
  'Receive push notifications': 'Recibir notificaciones push',
  'Notification Preferences': 'Preferencias de notificación',
  'Choose what to be notified about':
      'Elige sobre qué quieres recibir notificaciones',
  'Appearance': 'Apariencia',
  'Theme Preference': 'Preferencia de tema',
  'Dark Mode': 'Modo oscuro',
  'Use dark theme': 'Usar tema oscuro',
  'Follow System Theme': 'Seguir tema del sistema',
  'Match your device appearance': 'Coincidir con la apariencia del dispositivo',
  'Language': 'Idioma',
  'Time Zone': 'Zona horaria',
  'Automatic': 'Automática',
  'Privacy & Security': 'Privacidad y seguridad',
  'Biometric Login': 'Inicio biométrico',
  'Use fingerprint or face to login':
      'Usa huella o rostro para iniciar sesión',
  'Privacy Policy': 'Política de privacidad',
  'Read our privacy policy': 'Lee nuestra política de privacidad',
  'Terms of Service': 'Términos del servicio',
  'Read our terms of service': 'Lee nuestros términos del servicio',
  'Download My Data': 'Descargar mis datos',
  'Get a copy of your data': 'Obtén una copia de tus datos',
  'About': 'Acerca de',
  'App Version': 'Versión de la app',
  'Help & Support': 'Ayuda y soporte',
  'Get help or contact us': 'Obtén ayuda o contáctanos',
  'Send Feedback': 'Enviar comentarios',
  'Help us improve the app': 'Ayúdanos a mejorar la app',
  'Rate the App': 'Calificar la app',
  'Love Scholesa? Rate us!': '¿Te encanta Scholesa? ¡Califícanos!',
  'Danger Zone': 'Zona de peligro',
  'Sign Out': 'Cerrar sesión',
  'Sign out of your account': 'Cerrar sesión de tu cuenta',
  'Delete Account': 'Eliminar cuenta',
  'Permanently delete your account': 'Eliminar tu cuenta de forma permanente',
    'English': 'Inglés',
    'Change Email': 'Cambiar correo',
    'Change Phone': 'Cambiar teléfono',
    'System': 'Sistema',
    'Light': 'Claro',
    'Dark': 'Oscuro',
    'Select Language': 'Seleccionar idioma',
    'Time Zone Selection': 'Selección de zona horaria',
    'Data download request submitted':
      'Solicitud de descarga de datos enviada',
    'Help Center': 'Centro de ayuda',
    'Feedback': 'Comentarios',
    'App Rating': 'Calificación de la app',
    'Scholesa version 1.0.0 (Build 1).': 'Scholesa versión 1.0.0 (Build 1).',
    'Close': 'Cerrar',
    'Are you sure you want to sign out?':
      '¿Seguro que quieres cerrar sesión?',
    'Cancel': 'Cancelar',
    'This action cannot be undone. All your data will be permanently deleted.':
      'Esta acción no se puede deshacer. Todos tus datos se eliminarán permanentemente.',
    'Submit': 'Enviar',
    'is available by request. Submit this request now?':
        'está disponible bajo solicitud. ¿Enviar esta solicitud ahora?',
    'request submitted': 'solicitud enviada',
    'Current Password': 'Contraseña actual',
    'New Password': 'Nueva contraseña',
    'Confirm Password': 'Confirmar contraseña',
    'Save': 'Guardar',
    'Update Email': 'Actualizar correo',
    'Enter current password': 'Introduce la contraseña actual',
    'Enter a new password (min 8 characters)':
      'Introduce una nueva contraseña (mínimo 8 caracteres)',
    'Re-enter new password': 'Vuelve a introducir la nueva contraseña',
    'Enter new email': 'Introduce el nuevo correo',
    'Phone Number Updated': 'Número de teléfono actualizado',
    'Password Updated': 'Contraseña actualizada',
    'Email Update Requested': 'Actualización de correo solicitada',
    'Check your inbox to verify your new email.':
      'Revisa tu correo para verificar tu nuevo email.',
    'Update Phone': 'Actualizar teléfono',
    'Enter phone number': 'Introduce el número de teléfono',
    'Choose Time Zone': 'Elige zona horaria',
    'UTC': 'UTC',
    'UTC+8 (Singapore)': 'UTC+8 (Singapur)',
    'UTC+1 (Madrid)': 'UTC+1 (Madrid)',
    'UTC-5 (New York)': 'UTC-5 (Nueva York)',
    'Privacy Policy Notice': 'Aviso de política de privacidad',
    'Your data is processed according to Scholesa privacy standards and your site policies.':
      'Tus datos se procesan según los estándares de privacidad de Scholesa y las políticas de tu sitio.',
    'Terms of Service Notice': 'Aviso de términos del servicio',
    'Use of Scholesa requires compliance with site and platform safety standards.':
      'El uso de Scholesa requiere cumplir con los estándares de seguridad del sitio y de la plataforma.',
    'Help Center Contact': 'Contacto del centro de ayuda',
    'Contact support at support@scholesa.com with your site ID and issue details.':
      'Contacta a soporte en support@scholesa.com con tu ID de sitio y los detalles del problema.',
    'Send': 'Enviar',
    'Feedback sent': 'Comentarios enviados',
    'Thanks for helping improve Scholesa.':
      'Gracias por ayudar a mejorar Scholesa.',
    'Please enter feedback before sending.':
      'Introduce comentarios antes de enviar.',
    'Thanks for rating Scholesa!': '¡Gracias por calificar Scholesa!',
    'Delete Account Confirmation': 'Confirmación para eliminar cuenta',
    'Enter current password to confirm account deletion.':
      'Introduce la contraseña actual para confirmar la eliminación de la cuenta.',
    'Delete': 'Eliminar',
};

String _tSettings(BuildContext context, String input) {
  final String locale = Localizations.localeOf(context).languageCode;
  if (locale != 'es') return input;
  return _settingsEs[input] ?? input;
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

  Widget _buildAccountSection() {
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
          subtitle: 'emma@example.com',
          onTap: () => _showChangeEmailSheet(),
        ),
        _SettingsTile(
          icon: Icons.phone,
          title: _tSettings(context, 'Phone Number'),
          subtitle: '+1 234 567 8900',
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
            },
          ),
          _SettingsToggle(
            icon: Icons.phone_android,
            title: _tSettings(context, 'Push Notifications'),
            subtitle: _tSettings(context, 'Receive push notifications'),
            value: _pushNotifications,
            onChanged: (bool value) {
              setState(() => _pushNotifications = value);
            },
          ),
        ],
        _SettingsTile(
          icon: Icons.tune,
          title: _tSettings(context, 'Notification Preferences'),
          subtitle:
              _tSettings(context, 'Choose what to be notified about'),
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
    const Map<String, String> languages = <String, String>{
      'en': 'English',
      'es': 'Español',
      'zh': '中文',
      'ms': 'Bahasa Melayu',
    };
    return languages[code] ?? _tSettings(context, 'English');
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
                        final String currentPassword =
                            currentPasswordController.text.trim();
                        final String newPassword =
                            newPasswordController.text.trim();
                        final String confirmPassword =
                            confirmPasswordController.text.trim();

                        if (newPassword.length < 8 ||
                            newPassword != confirmPassword) {
                          _showErrorSnackBar(_tSettings(
                              context, 'Enter a new password (min 8 characters)'));
                          return;
                        }

                        try {
                          final AuthService authService =
                              this.context.read<AuthService>();
                          await authService.updatePassword(
                            currentPassword: currentPassword,
                            newPassword: newPassword,
                          );
                          if (!mounted) return;
                          Navigator.pop(bottomSheetContext);
                          _showSuccessSnackBar(
                              _tSettings(context, 'Password Updated'));
                        } catch (error) {
                          if (!mounted) return;
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
                        final String newEmail = emailController.text.trim();
                        final String currentPassword =
                            passwordController.text.trim();
                        if (newEmail.isEmpty || !newEmail.contains('@')) {
                          _showErrorSnackBar(_tSettings(context, 'Enter new email'));
                          return;
                        }

                        try {
                          final AuthService authService =
                              this.context.read<AuthService>();
                          await authService.updateEmail(
                            currentPassword: currentPassword,
                            newEmail: newEmail,
                          );
                          if (!mounted) return;
                          Navigator.pop(bottomSheetContext);
                          _showSuccessSnackBar(
                              _tSettings(context, 'Email Update Requested'));
                          _showSuccessSnackBar(_tSettings(
                              context, 'Check your inbox to verify your new email.'));
                        } catch (error) {
                          if (!mounted) return;
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
                        final String phoneNumber = phoneController.text.trim();
                        if (phoneNumber.isEmpty) {
                          _showErrorSnackBar(
                              _tSettings(context, 'Enter phone number'));
                          return;
                        }
                        try {
                          final AuthService authService =
                              this.context.read<AuthService>();
                          await authService.updatePhoneNumberInProfile(
                              phoneNumber);
                          if (!mounted) return;
                          Navigator.pop(bottomSheetContext);
                          _showSuccessSnackBar(
                              _tSettings(context, 'Phone Number Updated'));
                        } catch (error) {
                          if (!mounted) return;
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
                      setModalState(() {});
                    },
                  ),
                  SwitchListTile(
                    title: Text(_tSettings(context, 'Push Notifications')),
                    value: _pushNotifications,
                    onChanged: (bool value) {
                      setState(() => _pushNotifications = value);
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
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...zones.map((String zone) {
                final bool isSelected = _timeZone == zone ||
                    (_timeZone == 'auto' && zone == 'auto');
                return ListTile(
                  title: Text(zone == 'auto'
                      ? _tSettings(context, 'Automatic')
                      : zone),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: ScholesaColors.success)
                      : null,
                  onTap: () {
                    setState(() => _timeZone = zone);
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

  void _requestDataDownload() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{'cta': 'settings_download_my_data'},
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_tSettings(context, 'Data download request submitted')),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
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
                        final String feedback = feedbackController.text.trim();
                        if (feedback.isEmpty) {
                          _showErrorSnackBar(_tSettings(
                              context, 'Please enter feedback before sending.'));
                          return;
                        }
                        await TelemetryService.instance.logEvent(
                          event: 'settings.feedback.submitted',
                          metadata: <String, dynamic>{'length': feedback.length},
                        );
                        if (!mounted) return;
                        Navigator.pop(bottomSheetContext);
                        _showSuccessSnackBar(_tSettings(context, 'Feedback sent'));
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

  void _rateApp() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{'cta': 'settings_rate_app'},
    );
    _showSuccessSnackBar(_tSettings(context, 'Thanks for rating Scholesa!'));
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
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{'cta': 'settings_open_sign_out_dialog'},
    );
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(_tSettings(context, 'Sign Out')),
          content:
              Text(_tSettings(context, 'Are you sure you want to sign out?')),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_tSettings(context, 'Cancel')),
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
              child: Text(
                _tSettings(context, 'Sign Out'),
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
          title: Text(_tSettings(context, 'Delete Account')),
          content: Text(
            _tSettings(context,
                'This action cannot be undone. All your data will be permanently deleted.'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_tSettings(context, 'Cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: const <String, dynamic>{
                    'cta': 'settings_confirm_delete_account'
                  },
                );
                Navigator.pop(context);
                await _confirmDeleteAccountWithPassword();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ScholesaColors.error,
              ),
              child: Text(
                _tSettings(context, 'Delete Account'),
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
              Text(_tSettings(
                  context, 'Enter current password to confirm account deletion.')),
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
