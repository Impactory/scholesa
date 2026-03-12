import 'package:flutter/material.dart';
import '../theme/scholesa_theme.dart';

/// Scholesa Logo widget - consistent branding across the app.
/// Uses the shared launcher asset generated from the canonical SVG brand mark.
class ScholesaLogo extends StatelessWidget {
  const ScholesaLogo({
    super.key,
    this.size = 64,
    this.showShadow = true,
    this.borderRadius,
  });

  /// Size of the logo (width and height)
  final double size;

  /// Whether to show the glow shadow effect
  final bool showShadow;

  /// Custom border radius (defaults to size * 0.22 for consistent look)
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final double radius = borderRadius ?? size * 0.22;
    final double shadowBlur = showShadow ? size * 0.25 : 0;
    final double shadowSpread = showShadow ? size * 0.04 : 0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: showShadow
            ? <BoxShadow>[
                BoxShadow(
                  color: ScholesaColors.primary.withValues(alpha: 0.4),
                  blurRadius: shadowBlur,
                  spreadRadius: shadowSpread,
                ),
                BoxShadow(
                  color: ScholesaColors.futureSkills.withValues(alpha: 0.2),
                  blurRadius: shadowBlur * 2,
                  spreadRadius: shadowSpread * 2,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          'assets/icons/scholesa_launcher.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

/// Small Scholesa logo for app bars, list items, etc.
class ScholesaLogoSmall extends StatelessWidget {
  const ScholesaLogoSmall({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ScholesaLogo(size: size, showShadow: false);
  }
}

/// Large Scholesa logo for splash screens, landing pages
class ScholesaLogoLarge extends StatelessWidget {
  const ScholesaLogoLarge({super.key, this.size = 120});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ScholesaLogo(size: size, showShadow: true);
  }
}

/// Scholesa logo with text underneath
class ScholesaLogoWithText extends StatelessWidget {
  const ScholesaLogoWithText({
    super.key,
    this.logoSize = 64,
    this.showTagline = false,
    this.textColor,
  });

  final double logoSize;
  final bool showTagline;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final Color effectiveTextColor = textColor ?? Colors.white;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ScholesaLogo(size: logoSize),
        SizedBox(height: logoSize * 0.15),
        ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              colors: <Color>[
                ScholesaColors.primary,
                ScholesaColors.futureSkills,
                ScholesaColors.leadership,
              ],
            ).createShader(bounds);
          },
          child: Text(
            'Scholesa',
            style: TextStyle(
              fontSize: logoSize * 0.35,
              fontWeight: FontWeight.bold,
              color: effectiveTextColor,
              letterSpacing: 2,
            ),
          ),
        ),
        if (showTagline) ...<Widget>[
          SizedBox(height: logoSize * 0.06),
          Text(
            'Education 2.0 Platform',
            style: TextStyle(
              fontSize: logoSize * 0.13,
              color: effectiveTextColor.withValues(alpha: 0.7),
              letterSpacing: 1,
            ),
          ),
        ],
      ],
    );
  }
}
