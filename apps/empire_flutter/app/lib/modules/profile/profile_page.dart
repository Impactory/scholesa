import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../i18n/workflow_surface_i18n.dart';
import '../../auth/auth_service.dart';
import '../../auth/app_state.dart';
import '../../services/firestore_service.dart';
import '../../services/telemetry_service.dart';
import '../../ui/localization/app_strings.dart';
import '../../ui/theme/scholesa_theme.dart';

String _tProfile(BuildContext context, String input) {
  return WorkflowSurfaceI18n.text(context, input);
}

/// Profile Page - User profile and settings
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<AppState>(
        builder: (BuildContext context, AppState appState, _) {
          final String roleName = appState.role?.name ?? 'learner';
          final Color roleColor = ScholesaColors.forRole(roleName);

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  roleColor.withValues(alpha: 0.05),
                  Colors.white,
                  Colors.grey.withValues(alpha: 0.02),
                ],
              ),
            ),
            child: CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(
                    child: _buildHeader(context, appState, roleColor)),
                SliverToBoxAdapter(
                    child: _buildProfileCard(appState, roleColor)),
                SliverToBoxAdapter(child: _buildSettingsSection(context)),
                SliverToBoxAdapter(child: _buildAboutSection(context)),
                SliverToBoxAdapter(
                    child: _buildLogoutButton(context, appState)),
                const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, AppState appState, Color roleColor) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: <Widget>[
            IconButton(
              onPressed: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: const <String, dynamic>{'cta': 'profile_back'},
                );
                context.pop();
              },
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 8),
            Text(
              _tProfile(context, 'Profile'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: roleColor,
                  ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: const <String, dynamic>{'cta': 'profile_edit_icon'},
                );
                _showEditProfileDialog(context, appState);
              },
              icon: Icon(Icons.edit, color: roleColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(AppState appState, Color roleColor) {
    final String displayName = appState.displayName ?? 'User';
    final String email = appState.email ?? 'email@example.com';
    final String roleName = appState.role?.name ?? 'learner';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[roleColor, roleColor.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: roleColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                _getInitials(displayName),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    roleName.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              _tProfile(context, 'Settings'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: _tProfile(context, 'Notifications'),
            subtitle: _tProfile(context, 'Manage notification preferences'),
            onTap: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'cta': 'profile_open_notifications_settings'
                },
              );
              context.push('/settings');
            },
          ),
          _SettingsTile(
            icon: Icons.lock_outline,
            title: _tProfile(context, 'Privacy & Security'),
            subtitle: _tProfile(context, 'Password, two-factor auth'),
            onTap: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'cta': 'profile_open_privacy_security_settings'
                },
              );
              context.push('/settings');
            },
          ),
          _SettingsTile(
            icon: Icons.language,
            title: _tProfile(context, 'Language'),
            subtitle: _tProfile(context, 'English'),
            onTap: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'cta': 'profile_open_language_settings'
                },
              );
              context.push('/settings');
            },
          ),
          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            title: _tProfile(context, 'Appearance'),
            subtitle: _tProfile(context, 'Light mode'),
            onTap: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'cta': 'profile_open_appearance_settings'
                },
              );
              context.push('/settings');
            },
          ),
          _SettingsTile(
            icon: Icons.cloud_sync_outlined,
            title: _tProfile(context, 'Sync & Data'),
            subtitle: _tProfile(context, 'Last synced: Just now'),
            onTap: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'cta': 'profile_open_sync_data_settings'
                },
              );
              context.push('/settings');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              _tProfile(context, 'About'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _SettingsTile(
            icon: Icons.help_outline,
            title: _tProfile(context, 'Help & Support'),
            onTap: () => _openHelpSupport(context),
          ),
          _SettingsTile(
            icon: Icons.description_outlined,
            title: _tProfile(context, 'Terms of Service'),
            onTap: () => _openTermsOfService(context),
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: _tProfile(context, 'Privacy Policy'),
            onTap: () => _openPrivacyPolicy(context),
          ),
          _SettingsTile(
            icon: Icons.info_outline,
            title: _tProfile(context, 'Version'),
            subtitle: '1.0.0 (Build 1)',
            onTap: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'cta': 'profile_open_version_info'
                },
              );
              _showInfoDialog(
                context,
                title: _tProfile(context, 'Version'),
                message: _tProfile(context, 'App version 1.0.0 (Build 1).'),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, AppState appState) {
    final AuthService authService = context.read<AuthService>();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () async {
            final bool? confirmed = await showDialog<bool>(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                title: Text(_tProfile(context, 'Sign Out')),
                content: Text(
                  _tProfile(
                    context,
                    'Sign out so another family member can switch accounts on this device?',
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () {
                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: const <String, dynamic>{
                          'cta': 'profile_sign_out_cancel'
                        },
                      );
                      Navigator.pop(context, false);
                    },
                    child: Text(_tProfile(context, 'Cancel')),
                  ),
                  TextButton(
                    onPressed: () {
                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: const <String, dynamic>{
                          'cta': 'profile_sign_out_confirm'
                        },
                      );
                      Navigator.pop(context, true);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: ScholesaColors.error,
                    ),
                    child: Text(_tProfile(context, 'Sign Out')),
                  ),
                ],
              ),
            );

            if (confirmed ?? false) {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'cta': 'profile_sign_out_execute'
                },
              );
              try {
                await authService.signOut(source: 'profile_page');
                if (context.mounted) {
                  context.go('/login');
                }
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppStrings.of(context, 'auth.error.signOutFailed'),
                    ),
                  ),
                );
              }
            }
          },
          icon: const Icon(Icons.logout),
          label: Text(_tProfile(context, 'Sign Out')),
          style: OutlinedButton.styleFrom(
            foregroundColor: ScholesaColors.error,
            side:
                BorderSide(color: ScholesaColors.error.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final List<String> parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 2).toUpperCase();
  }

  void _showEditProfileDialog(BuildContext context, AppState appState) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{'cta': 'profile_open_edit_dialog'},
    );
    final TextEditingController nameController =
        TextEditingController(text: appState.displayName ?? '');

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(_tProfile(context, 'Edit Profile')),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: _tProfile(context, 'Display Name'),
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{'cta': 'profile_cancel_edit'},
              );
              Navigator.pop(dialogContext);
            },
            child: Text(_tProfile(context, 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'cta': 'profile_save_edit',
                  'has_name': nameController.text.trim().isNotEmpty,
                },
              );
              final String nextName = nameController.text.trim();
              Navigator.pop(dialogContext);
              if (nextName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text(_tProfile(context, 'No profile changes applied')),
                  ),
                );
                return;
              }

              try {
                final FirestoreService firestoreService =
                    context.read<FirestoreService>();
                await firestoreService.updateUserProfile(<String, dynamic>{
                  'displayName': nextName,
                  'profileUpdatedAt': DateTime.now().millisecondsSinceEpoch,
                });
                final Map<String, dynamic>? profile =
                    await firestoreService.getUserProfile();
                if (profile != null) {
                  appState.updateFromMeResponse(profile);
                }
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${_tProfile(context, 'Profile updated for')} $nextName',
                    ),
                  ),
                );
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error.toString())),
                );
              }
            },
            child: Text(_tProfile(context, 'Save')),
          ),
        ],
      ),
    );
  }

  Future<void> _openHelpSupport(BuildContext context) async {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{'cta': 'profile_open_help_support'},
    );

    final TextEditingController controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext bottomSheetContext) {
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _tProfile(context, 'Help Center Contact'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: _tProfile(context, 'Issue details'),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(bottomSheetContext),
                        child: Text(_tProfile(context, 'Cancel')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final String details = controller.text.trim();
                          if (details.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _tProfile(
                                    context,
                                    'Please enter issue details before sending.',
                                  ),
                                ),
                              ),
                            );
                            return;
                          }

                          final NavigatorState navigator =
                              Navigator.of(bottomSheetContext);
                          try {
                            final String requestId =
                                await _submitSupportRequest(
                              context,
                              source: 'profile_open_help_support',
                              subject: 'Profile help request',
                              message: details,
                            );
                            await TelemetryService.instance.logEvent(
                              event: 'profile.help_request.submitted',
                              metadata: <String, dynamic>{
                                'request_id': requestId,
                              },
                            );
                            if (!context.mounted) {
                              return;
                            }
                            navigator.pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _tProfile(
                                    context,
                                    'Support request submitted.',
                                  ),
                                ),
                              ),
                            );
                          } catch (error) {
                            debugPrint(
                              'Failed to submit profile support request: $error',
                            );
                            await TelemetryService.instance.logEvent(
                              event: 'profile.help_request.failed',
                              metadata: <String, dynamic>{
                                'error': error.toString(),
                              },
                            );
                            if (!context.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _tProfile(
                                    context,
                                    'Unable to submit support request right now.',
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                        child: Text(_tProfile(context, 'Send')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openTermsOfService(BuildContext context) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{'cta': 'profile_open_terms'},
    );
    _showInfoDialog(
      context,
      title: _tProfile(context, 'Terms of Service Notice'),
      message: _tProfile(context,
          'Use of Scholesa requires compliance with site and platform safety standards.'),
    );
  }

  void _openPrivacyPolicy(BuildContext context) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{'cta': 'profile_open_privacy_policy'},
    );
    _showInfoDialog(
      context,
      title: _tProfile(context, 'Privacy Policy Notice'),
      message: _tProfile(context,
          'Your data is processed according to Scholesa privacy standards and your site policies.'),
    );
  }

  FirestoreService? _maybeFirestoreService(BuildContext context) {
    try {
      return context.read<FirestoreService>();
    } catch (_) {
      return null;
    }
  }

  Future<String> _submitSupportRequest(
    BuildContext context, {
    required String source,
    required String subject,
    required String message,
  }) async {
    final FirestoreService? firestoreService = _maybeFirestoreService(context);
    if (firestoreService == null) {
      throw StateError(
        _tProfile(context, 'Support requests are unavailable right now.'),
      );
    }
    final AppState appState = context.read<AppState>();
    return firestoreService.submitSupportRequest(
      requestType: 'help',
      source: source,
      siteId: appState.activeSiteId?.trim().isNotEmpty == true
          ? appState.activeSiteId!.trim()
          : 'Not set',
      userId: appState.userId?.trim().isNotEmpty == true
          ? appState.userId!.trim()
          : 'Not set',
      userEmail: appState.email?.trim().isNotEmpty == true
          ? appState.email!.trim()
          : 'Not set',
      userName: appState.displayName?.trim().isNotEmpty == true
          ? appState.displayName!.trim()
          : 'Not set',
      role: appState.role?.name ?? 'unknown',
      subject: subject,
      message: message,
      metadata: const <String, dynamic>{'entryPoint': 'profile'},
    );
  }

  void _showInfoDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_tProfile(context, 'Close')),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        onTap: () {
          TelemetryService.instance.logEvent(
            event: 'cta.clicked',
            metadata: <String, dynamic>{
              'cta': 'profile_settings_tile',
              'title': title,
            },
          );
          onTap();
        },
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: Colors.grey[700]),
        ),
        title: Text(title),
        subtitle: subtitle != null
            ? Text(subtitle!, style: TextStyle(color: Colors.grey[600]))
            : null,
        trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      ),
    );
  }
}
