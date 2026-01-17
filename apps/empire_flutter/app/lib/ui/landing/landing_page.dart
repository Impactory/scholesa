import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/scholesa_theme.dart';
import '../widgets/scholesa_logo.dart';

/// Landing Page - Public welcome page before login
/// Showcases Scholesa's Education 2.0 platform with the 3 pillars
class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> with TickerProviderStateMixin {
  late AnimationController _heroController;
  late AnimationController _featuresController;
  late Animation<double> _heroFade;
  late Animation<Offset> _heroSlide;
  late Animation<double> _featuresFade;

  @override
  void initState() {
    super.initState();
    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _featuresController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _heroFade = CurvedAnimation(parent: _heroController, curve: Curves.easeOut);
    _heroSlide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _heroController, curve: Curves.easeOutCubic));
    _featuresFade = CurvedAnimation(parent: _featuresController, curve: Curves.easeOut);

    _heroController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _featuresController.forward();
    });
  }

  @override
  void dispose() {
    _heroController.dispose();
    _featuresController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool isWide = size.width > 900;
    final bool isMedium = size.width > 600;

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
        child: SafeArea(
          child: CustomScrollView(
            slivers: <Widget>[
              // App Bar
              SliverToBoxAdapter(
                child: _buildNavBar(context, isWide),
              ),

              // Hero Section
              SliverToBoxAdapter(
                child: SlideTransition(
                  position: _heroSlide,
                  child: FadeTransition(
                    opacity: _heroFade,
                    child: _buildHeroSection(context, isWide, isMedium),
                  ),
                ),
              ),

              // Pillars Section
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _featuresFade,
                  child: _buildPillarsSection(context, isWide),
                ),
              ),

              // Features Section
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _featuresFade,
                  child: _buildFeaturesSection(context, isWide),
                ),
              ),

              // Roles Section
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _featuresFade,
                  child: _buildRolesSection(context, isWide),
                ),
              ),

              // CTA Section
              SliverToBoxAdapter(
                child: _buildCTASection(context),
              ),

              // Footer
              SliverToBoxAdapter(
                child: _buildFooter(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavBar(BuildContext context, bool isWide) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 64 : 24,
        vertical: 16,
      ),
      child: Row(
        children: <Widget>[
          // Logo
          const ScholesaLogoSmall(size: 44),
          const SizedBox(width: 12),
          const Text(
            'Scholesa',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          // Nav links (wide only)
          if (isWide) ...<Widget>[
            _NavLink(label: 'Features', onTap: () {}),
            const SizedBox(width: 32),
            _NavLink(label: 'Pillars', onTap: () {}),
            const SizedBox(width: 32),
            _NavLink(label: 'For Schools', onTap: () {}),
            const SizedBox(width: 32),
          ],
          // CTA Buttons
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text(
              'Sign In',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () => context.go('/register'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ScholesaColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Get Started'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, bool isWide, bool isMedium) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 64 : 24,
        vertical: isWide ? 80 : 48,
      ),
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: _buildHeroContent(context),
                ),
                const SizedBox(width: 64),
                Expanded(
                  child: _buildHeroVisual(),
                ),
              ],
            )
          : Column(
              children: <Widget>[
                _buildHeroContent(context),
                const SizedBox(height: 48),
                _buildHeroVisual(),
              ],
            ),
    );
  }

  Widget _buildHeroContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: ScholesaColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: ScholesaColors.primary.withValues(alpha: 0.3),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.auto_awesome, size: 16, color: ScholesaColors.primary),
              SizedBox(width: 8),
              Text(
                'Education 2.0 Platform',
                style: TextStyle(
                  color: ScholesaColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Headline
        const Text(
          'Unlock Every\nLearner\'s Potential',
          style: TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.1,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Scholesa empowers K-9 learning studios with mission-based education, '
          'habit coaching, and portfolio showcases—built on three pillars that '
          'prepare students for the future.',
          style: TextStyle(
            fontSize: 18,
            color: Colors.white.withValues(alpha: 0.7),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 40),
        // CTA buttons
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: <Widget>[
            ElevatedButton.icon(
              onPressed: () => context.go('/register'),
              icon: const Icon(Icons.rocket_launch_rounded),
              label: const Text('Start Free Trial'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ScholesaColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.play_circle_outline_rounded),
              label: const Text('Watch Demo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroVisual() {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            ScholesaColors.primary.withValues(alpha: 0.2),
            ScholesaColors.leadership.withValues(alpha: 0.2),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Stack(
        children: <Widget>[
          // Decorative elements
          Positioned(
            top: 40,
            left: 40,
            child: _buildFloatingCard(
              icon: Icons.psychology_rounded,
              label: 'AI Coaching',
              color: ScholesaColors.futureSkills,
            ),
          ),
          Positioned(
            top: 80,
            right: 40,
            child: _buildFloatingCard(
              icon: Icons.emoji_events_rounded,
              label: 'Achievements',
              color: ScholesaColors.leadership,
            ),
          ),
          Positioned(
            bottom: 80,
            left: 60,
            child: _buildFloatingCard(
              icon: Icons.rocket_launch_rounded,
              label: 'Missions',
              color: ScholesaColors.impact,
            ),
          ),
          Positioned(
            bottom: 40,
            right: 60,
            child: _buildFloatingCard(
              icon: Icons.groups_rounded,
              label: 'Community',
              color: ScholesaColors.parent,
            ),
          ),
          // Center logo
          const Center(
            child: ScholesaLogo(size: 128, showShadow: true),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingCard({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 20,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillarsSection(BuildContext context, bool isWide) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 64 : 24,
        vertical: 80,
      ),
      child: Column(
        children: <Widget>[
          // Section header
          const Text(
            'The Three Pillars',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ScholesaColors.primary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Building Future-Ready Learners',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Our curriculum is built on three foundational pillars that prepare students for success.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          // Pillar cards
          isWide
              ? Row(
                  children: <Widget>[
                    Expanded(child: _buildPillarCard(
                      icon: Icons.computer_rounded,
                      title: 'Future Skills',
                      description: 'AI, coding, robotics, research, and digital literacy for tomorrow\'s world.',
                      color: ScholesaColors.futureSkills,
                      emoji: '🚀',
                    )),
                    const SizedBox(width: 24),
                    Expanded(child: _buildPillarCard(
                      icon: Icons.psychology_rounded,
                      title: 'Leadership & Agency',
                      description: 'Self-direction, communication, collaboration, and decision-making skills.',
                      color: ScholesaColors.leadership,
                      emoji: '👑',
                    )),
                    const SizedBox(width: 24),
                    Expanded(child: _buildPillarCard(
                      icon: Icons.public_rounded,
                      title: 'Impact & Innovation',
                      description: 'Social responsibility, creative problem-solving, and community contribution.',
                      color: ScholesaColors.impact,
                      emoji: '🌍',
                    )),
                  ],
                )
              : Column(
                  children: <Widget>[
                    _buildPillarCard(
                      icon: Icons.computer_rounded,
                      title: 'Future Skills',
                      description: 'AI, coding, robotics, research, and digital literacy for tomorrow\'s world.',
                      color: ScholesaColors.futureSkills,
                      emoji: '🚀',
                    ),
                    const SizedBox(height: 24),
                    _buildPillarCard(
                      icon: Icons.psychology_rounded,
                      title: 'Leadership & Agency',
                      description: 'Self-direction, communication, collaboration, and decision-making skills.',
                      color: ScholesaColors.leadership,
                      emoji: '👑',
                    ),
                    const SizedBox(height: 24),
                    _buildPillarCard(
                      icon: Icons.public_rounded,
                      title: 'Impact & Innovation',
                      description: 'Social responsibility, creative problem-solving, and community contribution.',
                      color: ScholesaColors.impact,
                      emoji: '🌍',
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildPillarCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required String emoji,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
              Text(emoji, style: const TextStyle(fontSize: 32)),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.6),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection(BuildContext context, bool isWide) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 64 : 24,
        vertical: 80,
      ),
      child: Column(
        children: <Widget>[
          const Text(
            'PLATFORM FEATURES',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ScholesaColors.primary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Everything You Need',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          Wrap(
            spacing: 24,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: <Widget>[
              _buildFeatureItem(Icons.assignment_turned_in_rounded, 'Mission-Based Learning'),
              _buildFeatureItem(Icons.psychology_rounded, 'AI Habit Coaching'),
              _buildFeatureItem(Icons.folder_special_rounded, 'Portfolio Showcase'),
              _buildFeatureItem(Icons.insights_rounded, 'Progress Analytics'),
              _buildFeatureItem(Icons.groups_rounded, 'Parent Portal'),
              _buildFeatureItem(Icons.cloud_off_rounded, 'Offline-First'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String label) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, color: ScholesaColors.primary, size: 32),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRolesSection(BuildContext context, bool isWide) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 64 : 24,
        vertical: 80,
      ),
      child: Column(
        children: <Widget>[
          const Text(
            'FOR EVERYONE',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ScholesaColors.primary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Designed for Your Role',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: <Widget>[
              _buildRoleChip('Learners', ScholesaColors.learner, Icons.school_rounded),
              _buildRoleChip('Educators', ScholesaColors.educator, Icons.person_rounded),
              _buildRoleChip('Parents', ScholesaColors.parent, Icons.family_restroom_rounded),
              _buildRoleChip('Site Admins', ScholesaColors.site, Icons.business_rounded),
              _buildRoleChip('HQ', ScholesaColors.hq, Icons.admin_panel_settings_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCTASection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        gradient: ScholesaColors.primaryGradient,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: <Widget>[
          const Text(
            'Ready to Transform Learning?',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Join hundreds of learning studios already using Scholesa.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => context.go('/register'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: ScholesaColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Get Started Free'),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const ScholesaLogoSmall(size: 36),
              const SizedBox(width: 8),
              const Text(
                'Scholesa',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '© 2026 Scholesa. Education 2.0 Platform.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
