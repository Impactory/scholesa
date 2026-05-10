import 'package:flutter/material.dart';
import '../../services/telemetry_service.dart';
import '../localization/inline_locale_text.dart';
import '../theme/scholesa_theme.dart';

const Map<String, String> _fatalErrorZhCn = <String, String>{
  'Something went wrong': '出现了一些问题',
  'Try Again': '再试一次',
};

const Map<String, String> _fatalErrorZhTw = <String, String>{
  'Something went wrong': '出現了一些問題',
  'Try Again': '再試一次',
};

String _tFatalError(BuildContext context, String input) {
  return InlineLocaleText.of(
    context,
    input,
    zhCn: _fatalErrorZhCn,
    zhTw: _fatalErrorZhTw,
  );
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
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
                  color: scheme.error,
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
                        color: context.schTextSecondary,
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
