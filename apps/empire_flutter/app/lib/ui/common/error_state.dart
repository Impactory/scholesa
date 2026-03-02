import 'package:flutter/material.dart';
import '../../services/telemetry_service.dart';

const Map<String, String> _errorStateEs = <String, String>{
  'Error': 'Error',
  'Retry': 'Reintentar',
};

String _tErrorState(BuildContext context, String input) {
  final String locale = Localizations.localeOf(context).languageCode;
  if (locale != 'es') return input;
  return _errorStateEs[input] ?? input;
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.warning_amber_rounded,
              size: 64,
              color: Colors.orange[400],
            ),
            const SizedBox(height: 16),
            Text(
              _tErrorState(context, 'Error'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[700],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
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
