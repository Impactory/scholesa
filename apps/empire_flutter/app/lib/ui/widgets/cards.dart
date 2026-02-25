import 'package:flutter/material.dart';
import '../../services/telemetry_service.dart';
import '../theme/scholesa_theme.dart';

/// A beautiful gradient card widget for dashboards
class GradientCard extends StatelessWidget {
  const GradientCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.gradient,
    this.onTap,
    this.isEnabled = true,
    this.badge,
    this.badgeText,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final LinearGradient gradient;
  final VoidCallback? onTap;
  final bool isEnabled;
  final Widget? badge;
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color disabledSurface = scheme.surfaceContainerHigh;
    final Color disabledText = scheme.onSurfaceVariant;
    final bool darkForeground = isEnabled && _useDarkForeground(gradient);
    final Color foregroundColor = darkForeground
        ? const Color(0xFF0F172A)
        : Colors.white;
    final Color subtitleColor = darkForeground
        ? const Color(0xFF1E293B).withValues(alpha: 0.88)
        : Colors.white.withValues(alpha: 0.92);
    final Color iconChipColor = darkForeground
        ? Colors.white.withValues(alpha: 0.52)
        : Colors.white.withValues(alpha: 0.28);
    final Color decorativeIconColor = darkForeground
        ? Colors.black.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.2);
    final Color badgeBackgroundColor = darkForeground
        ? Colors.white.withValues(alpha: 0.56)
        : Colors.white.withValues(alpha: 0.25);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  TelemetryService.instance.logEvent(
                    event: 'cta.clicked',
                    metadata: <String, dynamic>{
                      'module': 'ui_cards',
                      'cta_id': 'tap_gradient_card',
                      'title': title,
                    },
                  );
                  onTap?.call();
                },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              gradient: isEnabled ? gradient : null,
              color: isEnabled ? null : disabledSurface,
              borderRadius: BorderRadius.circular(20),
              border: isEnabled
                  ? Border.all(
                      color: Colors.white.withValues(
                        alpha: darkForeground ? 0.12 : 0.2,
                      ),
                    )
                  : null,
              boxShadow: isEnabled
                  ? <BoxShadow>[
                      BoxShadow(
                        color: gradient.colors.first.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.all(20),
            child: Stack(
              children: <Widget>[
                // Background icon decoration
                Positioned(
                  right: -10,
                  bottom: -10,
                  child: Icon(
                    icon,
                    size: 80,
                    color: isEnabled
                        ? decorativeIconColor
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                if (isEnabled)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: darkForeground
                              ? <Color>[
                                  Colors.black.withValues(alpha: 0.04),
                                  Colors.black.withValues(alpha: 0.1),
                                ]
                              : <Color>[
                                  Colors.black.withValues(alpha: 0.08),
                                  Colors.black.withValues(alpha: 0.16),
                                ],
                        ),
                      ),
                    ),
                  ),
                // Content
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isEnabled
                                ? iconChipColor
                                : Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            icon,
                            size: 28,
                            color: isEnabled ? foregroundColor : disabledText,
                          ),
                        ),
                        const Spacer(),
                        if (badgeText != null)
                          Flexible(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: badgeBackgroundColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  badgeText!,
                                  style: TextStyle(
                                    color: isEnabled
                                        ? foregroundColor
                                        : disabledText,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        if (badge != null) badge!,
                      ],
                    ),
                    const Spacer(),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color:
                            isEnabled ? foregroundColor : scheme.onSurface,
                      ),
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 13,
                          color: isEnabled ? subtitleColor : disabledText,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (!isEnabled) ...<Widget>[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: disabledText.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Unavailable',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: disabledText,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _useDarkForeground(LinearGradient value) {
    final double totalLuminance = value.colors
        .map((Color color) => color.computeLuminance())
        .fold<double>(0, (double a, double b) => a + b);
    final double averageLuminance = totalLuminance / value.colors.length;
    // Lower threshold to keep contrast high on mint/yellow dashboard cards.
    return averageLuminance >= 0.42;
  }
}

/// A colorful stat card for quick metrics
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.trend,
    this.isPositive = true,
    this.onTap,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? trend;
  final bool isPositive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: <String, dynamic>{
                    'module': 'ui_cards',
                    'cta_id': 'tap_stat_card',
                    'label': label,
                  },
                );
                onTap?.call();
              },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool compact =
                  constraints.maxHeight < 90 || constraints.maxWidth < 130;
              final bool ultraCompact = constraints.maxHeight < 75;

              if (ultraCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(icon, color: color, size: 14),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.all(compact ? 6 : 8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child:
                            Icon(icon, color: color, size: compact ? 16 : 20),
                      ),
                      if (trend != null)
                        Flexible(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: compact ? 4 : 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isPositive
                                      ? ScholesaColors.success
                                      : ScholesaColors.error)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  isPositive
                                      ? Icons.trending_up
                                      : Icons.trending_down,
                                  size: compact ? 10 : 12,
                                  color: isPositive
                                      ? ScholesaColors.success
                                      : ScholesaColors.error,
                                ),
                                const SizedBox(width: 2),
                                Flexible(
                                  child: Text(
                                    trend!,
                                    style: TextStyle(
                                      fontSize: compact ? 10 : 11,
                                      fontWeight: FontWeight.bold,
                                      color: isPositive
                                          ? ScholesaColors.success
                                          : ScholesaColors.error,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: compact ? 6 : 10),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 20 : 28,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 11 : 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A quick action button with icon and label
class QuickActionButton extends StatelessWidget {
  const QuickActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: <String, dynamic>{
                    'module': 'ui_cards',
                    'cta_id': 'tap_quick_action',
                    'label': label,
                  },
                );
                onTap?.call();
              },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[color, color.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A pill-shaped status badge
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.filled = false,
    this.icon,
  });
  final String label;
  final Color color;
  final bool filled;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: filled ? null : Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 14, color: filled ? Colors.white : color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: filled ? Colors.white : color,
            ),
          ),
        ],
      ),
    );
  }
}

/// A progress indicator with label
class ProgressCard extends StatelessWidget {
  const ProgressCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.color,
    this.icon,
  });
  final String title;
  final String subtitle;
  final double progress;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}

/// An avatar with online status indicator
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = 40,
    this.showOnline = false,
    this.isOnline = false,
    this.backgroundColor,
  });
  final String? imageUrl;
  final String name;
  final double size;
  final bool showOnline;
  final bool isOnline;
  final Color? backgroundColor;

  String get initials {
    final List<String> parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].substring(0, parts[0].length.clamp(0, 2)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Stack(
      children: <Widget>[
        CircleAvatar(
          radius: size / 2,
          backgroundColor: backgroundColor ?? scheme.primaryContainer,
          backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
          child: imageUrl == null
              ? Text(
                  initials,
                  style: TextStyle(
                    fontSize: size * 0.4,
                    fontWeight: FontWeight.bold,
                    color: backgroundColor != null
                        ? Colors.white
                        : scheme.onPrimaryContainer,
                  ),
                )
              : null,
        ),
        if (showOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.3,
              height: size * 0.3,
              decoration: BoxDecoration(
                color:
                    isOnline ? ScholesaColors.success : scheme.onSurfaceVariant,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surface, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

/// A list tile with colorful icon
class ColorfulListTile extends StatelessWidget {
  const ColorfulListTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
    this.trailing,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap == null
          ? null
          : () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'module': 'ui_cards',
                  'cta_id': 'tap_colorful_list_tile',
                  'title': title,
                },
              );
              onTap?.call();
            },
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 13,
              ),
            )
          : null,
      trailing:
          trailing ?? Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
