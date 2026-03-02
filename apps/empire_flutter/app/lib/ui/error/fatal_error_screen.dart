import 'package:flutter/material.dart';
import '../../services/telemetry_service.dart';

const Map<String, String> _fatalErrorEs = <String, String>{
  'Something went wrong': 'Algo salió mal',
  'Try Again': 'Intentar de nuevo',
};

String _tFatalError(BuildContext context, String input) {
  final String locale = Localizations.localeOf(context).languageCode;
  if (locale != 'es') return input;
  return _fatalErrorEs[input] ?? input;
}

/// Fatal error screen with retry option
class FatalErrorScreen extends StatelessWidget {
  const FatalErrorScreen({
    super.key,
    required this.error,
    this.onRetry,
  });
  final String error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.error_outline,
                  size: 80,
                  color: Colors.red[400],
                ),
                const SizedBox(height: 24),
                Text(
                  _tFatalError(context, 'Something went wrong'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  error,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (onRetry != null)
                  ElevatedButton.icon(
                    onPressed: () {
                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: const <String, dynamic>{
                          'cta': 'fatal_error_retry',
                          'surface': 'fatal_error_screen',
                        },
                      );
                      onRetry!();
                    },
                    icon: const Icon(Icons.refresh),
                    label: Text(_tFatalError(context, 'Try Again')),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
