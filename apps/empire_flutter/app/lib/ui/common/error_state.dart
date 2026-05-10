import 'package:flutter/material.dart';
import '../../services/telemetry_service.dart';
import '../localization/inline_locale_text.dart';
import '../theme/scholesa_theme.dart';

const Map<String, String> _errorStateZhCn = <String, String>{
  'Error': '错误',
  'Retry': '重试',
};

const Map<String, String> _errorStateZhTw = <String, String>{
  'Error': '錯誤',
  'Retry': '重試',
};

String _tErrorState(BuildContext context, String input) {
  return InlineLocaleText.of(
    context,
    input,
    zhCn: _errorStateZhCn,
    zhTw: _errorStateZhTw,
  );
}

/// Error state widget with retry
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
  });
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.warning_amber_rounded,
              size: 64,
              color: scheme.tertiary,
            ),
            const SizedBox(height: 16),
            Text(
              _tErrorState(context, 'Error'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: context.schTextPrimary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.schTextSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  TelemetryService.instance.logEvent(
                    event: 'cta.clicked',
                    metadata: const <String, dynamic>{
                      'cta': 'shared_error_retry',
                      'surface': 'error_state',
                    },
                  );
                  onRetry!();
                },
                icon: const Icon(Icons.refresh),
                label: Text(_tErrorState(context, 'Retry')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
