import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/scholesa_theme.dart';

/// Beautiful animated splash screen for Scholesa
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.message = 'Loading Scholesa...'});
  
  final String message;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _pulseController;
  late AnimationController _orbController;
  late Animation<double> _logoScale;
  late Animation<double> _logoRotation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Logo bounce animation
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.elasticOut,
      ),
    );
    _logoRotation = Tween<double>(begin: -0.1, end: 0.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeOutBack,
      ),
    );

    // Pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Orb rotation
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _logoController.forward();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _pulseController.dispose();
    _orbController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF0F172A),
              Color(0xFF1E293B),
              Color(0xFF0F172A),
            ],
          ),
        ),
        child: Stack(
          children: <Widget>[
            // Animated background orbs
            ..._buildFloatingOrbs(),
            
            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // Animated logo
                  AnimatedBuilder(
                    animation: Listenable.merge(<Listenable>[
                      _logoController,
                      _pulseController,
                    ]),
                    builder: (BuildContext context, Widget? child) {
                      return Transform.scale(
                        scale: _logoScale.value * _pulseAnimation.value,
                        child: Transform.rotate(
                          angle: _logoRotation.value,
                          child: child,
                        ),
                      );
                    },
                    child: _buildLogo(),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // App name with gradient
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
                    child: const Text(
                      'Scholesa',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Tagline
                  Text(
                    'Education 2.0 Platform',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.7),
                      letterSpacing: 1,
                    ),
                  ),
                  
                  const SizedBox(height: 60),
                  
                  // Loading indicator with pillar colors
                  _buildPillarLoadingIndicator(),
                  
                  const SizedBox(height: 24),
                  
                  // Loading message
                  Text(
                    widget.message,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            
            // Three pillars at bottom
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: _buildPillarChips(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        gradient: ScholesaColors.primaryGradient,
        borderRadius: BorderRadius.circular(30),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: ScholesaColors.primary.withValues(alpha: 0.4),
            blurRadius: 30,
            spreadRadius: 5,
          ),
          BoxShadow(
            color: ScholesaColors.futureSkills.withValues(alpha: 0.2),
            blurRadius: 60,
            spreadRadius: 10,
          ),
        ],
      ),
      child: const Icon(
        Icons.school_rounded,
        size: 64,
        color: Colors.white,
      ),
    );
  }

  List<Widget> _buildFloatingOrbs() {
    return <Widget>[
      // Future Skills orb (blue)
      _buildOrb(
        color: ScholesaColors.futureSkills,
        size: 200,
        top: -50,
        right: -50,
        delay: 0,
      ),
      // Leadership orb (purple)
      _buildOrb(
        color: ScholesaColors.leadership,
        size: 150,
        bottom: 100,
        left: -30,
        delay: 2,
      ),
      // Impact orb (green)
      _buildOrb(
        color: ScholesaColors.impact,
        size: 180,
        bottom: -60,
        right: 50,
        delay: 4,
      ),
      // Primary orb
      _buildOrb(
        color: ScholesaColors.primary,
        size: 100,
        top: 150,
        left: 20,
        delay: 1,
      ),
      // Purple accent
      _buildOrb(
        color: ScholesaColors.purple,
        size: 120,
        top: 80,
        right: 100,
        delay: 3,
      ),
    ];
  }

  Widget _buildOrb({
    required Color color,
    required double size,
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double delay,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: AnimatedBuilder(
        animation: _orbController,
        builder: (BuildContext context, Widget? child) {
          final double progress = (_orbController.value + delay / 10) % 1.0;
          final double offset = math.sin(progress * 2 * math.pi) * 20;
          return Transform.translate(
            offset: Offset(offset, offset * 0.5),
            child: child,
          );
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: <Color>[
                color.withValues(alpha: 0.3),
                color.withValues(alpha: 0.1),
                color.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPillarLoadingIndicator() {
    return SizedBox(
      width: 200,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          _buildPulsingDot(ScholesaColors.futureSkills, 0),
          const SizedBox(width: 16),
          _buildPulsingDot(ScholesaColors.leadership, 200),
          const SizedBox(width: 16),
          _buildPulsingDot(ScholesaColors.impact, 400),
        ],
      ),
    );
  }

  Widget _buildPulsingDot(Color color, int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + delayMs),
      builder: (BuildContext context, double value, Widget? child) {
        return AnimatedBuilder(
          animation: _pulseController,
          builder: (BuildContext context, Widget? child) {
            final double scale = 0.8 + (_pulseController.value * 0.4);
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPillarChips() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _buildPillarChip('Future Skills', ScholesaColors.futureSkills, Icons.rocket_launch_rounded),
        const SizedBox(width: 12),
        _buildPillarChip('Leadership', ScholesaColors.leadership, Icons.psychology_rounded),
        const SizedBox(width: 12),
        _buildPillarChip('Impact', ScholesaColors.impact, Icons.public_rounded),
      ],
    );
  }

  Widget _buildPillarChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Minimal loading indicator for inline use
class ScholesaLoadingIndicator extends StatefulWidget {
  const ScholesaLoadingIndicator({super.key, this.size = 40});
  
  final double size;

  @override
  State<ScholesaLoadingIndicator> createState() => _ScholesaLoadingIndicatorState();
}

class _ScholesaLoadingIndicatorState extends State<ScholesaLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          return CustomPaint(
            painter: _PillarSpinnerPainter(
              progress: _controller.value,
            ),
          );
        },
      ),
    );
  }
}

class _PillarSpinnerPainter extends CustomPainter {
  _PillarSpinnerPainter({required this.progress});
  
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double radius = size.width / 2 - 4;

    final List<Color> colors = <Color>[
      ScholesaColors.futureSkills,
      ScholesaColors.leadership,
      ScholesaColors.impact,
    ];

    for (int i = 0; i < 3; i++) {
      final double angle = (progress * 2 * math.pi) + (i * 2 * math.pi / 3);
      final double x = centerX + radius * math.cos(angle);
      final double y = centerY + radius * math.sin(angle);
      
      final double dotSize = 6 + (math.sin(progress * 2 * math.pi + i) * 2);
      
      final Paint paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(Offset(x, y), dotSize, paint);
      
      // Glow effect
      final Paint glowPaint = Paint()
        ..color = colors[i].withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(x, y), dotSize + 2, glowPaint);
    }
  }

  @override
  bool shouldRepaint(_PillarSpinnerPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
