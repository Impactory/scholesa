import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_service.dart';
import '../../services/telemetry_service.dart';
import '../localization/app_strings.dart';
import '../theme/scholesa_theme.dart';

Future<void> runSharedSignOutFlow({
  required BuildContext context,
  required String source,
  required String title,
  required String message,
  required String cancelLabel,
  required String confirmLabel,
  required String openTelemetryCta,
  required String cancelTelemetryCta,
  required String confirmTelemetryCta,
  String? executeTelemetryCta,
}) async {
  final AuthService authService = context.read<AuthService>();
  final GoRouter router = GoRouter.of(context);
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final String signOutFailedMessage =
      AppStrings.of(context, 'auth.error.signOutFailed');

  TelemetryService.instance.logEvent(
    event: 'cta.clicked',
    metadata: <String, dynamic>{'cta': openTelemetryCta},
  );

  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            TelemetryService.instance.logEvent(
              event: 'cta.clicked',
              metadata: <String, dynamic>{'cta': cancelTelemetryCta},
            );
            Navigator.pop(dialogContext, false);
          },
          child: Text(cancelLabel),
        ),
        ElevatedButton(
          onPressed: () {
            TelemetryService.instance.logEvent(
              event: 'cta.clicked',
              metadata: <String, dynamic>{'cta': confirmTelemetryCta},
            );
            Navigator.pop(dialogContext, true);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: ScholesaColors.error,
          ),
          child: Text(
            confirmLabel,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );

  if (confirmed != true) {
    return;
  }

  if (executeTelemetryCta != null && executeTelemetryCta.trim().isNotEmpty) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{'cta': executeTelemetryCta.trim()},
    );
  }

  try {
    await authService.signOut(source: source);
    if (!context.mounted) {
      return;
    }
    router.go(kIsWeb ? '/welcome' : '/login');
  } catch (_) {
    if (!context.mounted) {
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(signOutFailedMessage),
      ),
    );
  }
}