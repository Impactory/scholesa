import 'package:flutter/material.dart';

import '../theme/scholesa_theme.dart';

/// Scholesa Logo widget - consistent branding across the app.
/// Drawn in code so legacy badge assets do not ship in the UI bundle.
class ScholesaLogo extends StatelessWidget {
  const ScholesaLogo({
    super.key,
    this.size = 64,
    this.showShadow = true,
    this.borderRadius,
  });

  final double size;
  final bool showShadow;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final double radius = borderRadius ?? size * 0.26;
    final double shadowBlur = showShadow ? size * 0.25 : 0;
    final double shadowSpread = showShadow ? size * 0.04 : 0;
    final double nodeSize = size * 0.15;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF0F172A),
            Color(0xFF153B6D),
            Color(0xFF0B6E63),
          ],
        ),
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
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.15, -0.1),
                    radius: 0.9,
                    colors: <Color>[
                      Colors.white.withValues(alpha: 0.14),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: size * 0.16,
              left: size * 0.16,
              child: _LogoNode(
                size: nodeSize,
                color: ScholesaColors.futureSkills,
              ),
            ),
            Positioned(
              top: size * 0.16,
              right: size * 0.16,
              child: _LogoNode(
                size: nodeSize,
                color: ScholesaColors.leadership,
              ),
            ),
            Positioned(
              bottom: size * 0.16,
              left: size * 0.16,
              child: _LogoNode(
                size: nodeSize,
                color: ScholesaColors.impact,
              ),
            ),
            Center(
              child: Transform.rotate(
                angle: -0.42,
                child: Container(
                  width: size * 0.17,
                  height: size * 0.58,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(size * 0.12),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Color(0xFFF8FAFC),
                        Color(0xFFBAE6FD),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: Container(
                width: size * 0.24,
                height: size * 0.24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: size * 0.018,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoNode extends StatelessWidget {
  const _LogoNode({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: size * 0.8,
            spreadRadius: size * 0.06,
          ),
        ],
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
              fontWeight: FontWeight.w800,
              color: effectiveTextColor,
              letterSpacing: 1.2,
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
