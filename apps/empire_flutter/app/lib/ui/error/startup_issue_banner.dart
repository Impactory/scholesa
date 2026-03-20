import 'package:flutter/material.dart';

import '../../services/app_resilience.dart';
import '../localization/app_strings.dart';

class StartupIssueBanner extends StatelessWidget {
  const StartupIssueBanner({
    super.key,
    required this.issues,
    required this.onDismiss,
    this.includeSafeArea = true,
    this.padding = const EdgeInsets.fromLTRB(12, 12, 12, 0),
  });

  final List<AppStartupIssue> issues;
  final VoidCallback onDismiss;
  final bool includeSafeArea;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final List<String> serviceLabels = issues
        .map((AppStartupIssue issue) {
          return AppStrings.of(
            context,
            'app.startupService.${issue.serviceKey}',
          );
        })
        .toSet()
        .toList()
      ..sort();

    final Widget banner = Semantics(
      container: true,
      liveRegion: true,
      label: AppStrings.of(context, 'app.recoveryModeTitle'),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: padding,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: colorScheme.errorContainer.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.error),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  blurRadius: 18,
                  offset: Offset(0, 8),
                  color: Color(0x26000000),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.warning_amber_rounded,
                        color: colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              AppStrings.of(context, 'app.recoveryModeTitle'),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              AppStrings.of(context, 'app.recoveryModeBody'),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${AppStrings.of(context, 'app.affectedServices')}: ${serviceLabels.join(', ')}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onDismiss,
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.onErrorContainer,
                      ),
                      icon: const Icon(Icons.close),
                      label: Text(AppStrings.of(context, 'app.dismiss')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (!includeSafeArea) {
      return banner;
    }

    return SafeArea(
      bottom: false,
      child: banner,
    );
  }
}
