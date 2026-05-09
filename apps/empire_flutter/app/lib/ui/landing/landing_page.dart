import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/telemetry_service.dart';
import '../localization/inline_locale_text.dart';
import '../theme/scholesa_theme.dart';
import '../widgets/scholesa_logo.dart';

const Map<String, String> _landingZhCn = <String, String>{
  'Features': '功能',
  'Curriculum': '课程体系',
  'For Schools': '面向学校',
  'Evidence capture, MiloOS coaching, portfolios, analytics, and offline classroom support.':
      '证据采集、MiloOS 辅导、作品集、分析与离线课堂支持。',
  'Discoverers, Builders, Explorers, Innovators, and six capability strands.':
      '发现者、建构者、探索者、创新者，以及六大能力主线。',
  'Role-based dashboards for learners, educators, parents, site teams, and HQ.':
      '为学习者、教育者、家长、站点团队和 HQ 提供按角色划分的仪表板。',
  'Sign In': '登录',
  'Capability learning, made visible': '让能力学习清晰可见',
  'The Proof Engine for\nReal Capability Growth': '真实能力成长的\n证据引擎',
  'Scholesa turns classroom moments into trustworthy proof: observations, artifacts, explain-backs, rubric judgments, growth history, and portfolios families can understand.':
      'Scholesa 将课堂时刻转化为可信证据：观察、作品、解释回顾、量规判断、成长记录，以及家长能够理解的作品集。',
  'See the Proof Flow': '查看证据流程',
  'Scholesa Demo': 'Scholesa 演示',
  'Demo walkthrough includes:\n• Role dashboards\n• CTA action flows\n• Mission and attendance lifecycle':
      '演示包含：\n• 角色仪表板\n• CTA 操作流程\n• 任务与出勤生命周期',
  'Close': '关闭',
  'Try Live': '立即体验',
  'MiloOS': 'MiloOS',
  'Achievements': '成就',
  'Missions': '任务',
  'Community': '社区',
  'Capability Pathways': '能力路径',
  'Proof That Growth Is Real': '让成长真实可证',
  'A K-12 learning architecture that carries evidence from discovery to innovation.':
      '一个让证据贯穿从发现到创新全过程的 K-12 学习架构。',
  'Discoverers': '发现者',
  'Grades 1-3 • Story-rich invention studio with teacher-led AI demonstrations.':
      '1-3 年级 • 以故事驱动的发明工作室，由教师主导 AI 示范。',
  'Builders': '建构者',
  'Grades 4-6 • Design-and-build labs with guided assistive AI use.':
      '4-6 年级 • 以设计与建造实验室为核心，配合引导式 AI 辅助。',
  'Explorers': '探索者',
  'Grades 7-9 • Investigation labs focused on critique, bias checks, and verification.':
      '7-9 年级 • 聚焦批判、偏差检查与验证的探究实验室。',
  'Innovators': '创新者',
  'Grades 10-12 • Pathway-based capstone studios with full audit trails.':
      '10-12 年级 • 以方向路径驱动的毕业项目工作室，具备完整审计轨迹。',
  'PLATFORM FEATURES': '平台功能',
  'Everything You Need': '所需尽在其中',
  'Mission-Based Learning': '任务式学习',
  'AI Habit Coaching': 'AI 习惯教练',
  'Portfolio Showcase': '作品集展示',
  'Progress Analytics': '进度分析',
  'Parent Portal': '家长门户',
  'Offline-First': '离线优先',
  'FOR EVERYONE': '适用于所有人',
  'Designed for Your Role': '为你的角色而设计',
  'Learners': '学习者',
  'Educators': '教育者',
  'Parents': '家长',
  'Site Admins': '站点管理员',
  'Ready to Transform Learning?': '准备好改变学习方式了吗？',
  'Join hundreds of learning studios already using Scholesa.':
      '加入已经在使用 Scholesa 的数百家学习工作室。',
  '© 2026 Scholesa. Capability Evidence Platform.': '© 2026 Scholesa。能力证据平台。',
};

const Map<String, String> _landingZhTw = <String, String>{
  'Features': '功能',
  'Curriculum': '課程體系',
  'For Schools': '面向學校',
  'Evidence capture, MiloOS coaching, portfolios, analytics, and offline classroom support.':
      '證據擷取、MiloOS 輔導、作品集、分析與離線課堂支援。',
  'Discoverers, Builders, Explorers, Innovators, and six capability strands.':
      '發現者、建構者、探索者、創新者，以及六大能力主線。',
  'Role-based dashboards for learners, educators, parents, site teams, and HQ.':
      '為學習者、教育者、家長、站點團隊和 HQ 提供按角色劃分的儀表板。',
  'Sign In': '登入',
  'Capability learning, made visible': '讓能力學習清晰可見',
  'The Proof Engine for\nReal Capability Growth': '真實能力成長的\n證據引擎',
  'Scholesa turns classroom moments into trustworthy proof: observations, artifacts, explain-backs, rubric judgments, growth history, and portfolios families can understand.':
      'Scholesa 將課堂時刻轉化為可信證據：觀察、作品、解釋回顧、量規判斷、成長紀錄，以及家長能理解的作品集。',
  'See the Proof Flow': '查看證據流程',
  'Scholesa Demo': 'Scholesa 示範',
  'Demo walkthrough includes:\n• Role dashboards\n• CTA action flows\n• Mission and attendance lifecycle':
      '示範包含：\n• 角色儀表板\n• CTA 操作流程\n• 任務與出勤生命週期',
  'Close': '關閉',
  'Try Live': '立即體驗',
  'MiloOS': 'MiloOS',
  'Achievements': '成就',
  'Missions': '任務',
  'Community': '社群',
  'Capability Pathways': '能力路徑',
  'Proof That Growth Is Real': '讓成長真實可證',
  'A K-12 learning architecture that carries evidence from discovery to innovation.':
      '一個讓證據貫穿從發現到創新全過程的 K-12 學習架構。',
  'Discoverers': '發現者',
  'Grades 1-3 • Story-rich invention studio with teacher-led AI demonstrations.':
      '1-3 年級 • 以故事驅動的發明工作室，由教師主導 AI 示範。',
  'Builders': '建構者',
  'Grades 4-6 • Design-and-build labs with guided assistive AI use.':
      '4-6 年級 • 以設計與建造實驗室為核心，搭配引導式 AI 輔助。',
  'Explorers': '探索者',
  'Grades 7-9 • Investigation labs focused on critique, bias checks, and verification.':
      '7-9 年級 • 聚焦批判、偏差檢查與驗證的探究實驗室。',
  'Innovators': '創新者',
  'Grades 10-12 • Pathway-based capstone studios with full audit trails.':
      '10-12 年級 • 以方向路徑驅動的畢業專題工作室，具備完整審計軌跡。',
  'PLATFORM FEATURES': '平台功能',
  'Everything You Need': '所需盡在其中',
  'Mission-Based Learning': '任務式學習',
  'AI Habit Coaching': 'AI 習慣教練',
  'Portfolio Showcase': '作品集展示',
  'Progress Analytics': '進度分析',
  'Parent Portal': '家長入口',
  'Offline-First': '離線優先',
  'FOR EVERYONE': '適用於所有人',
  'Designed for Your Role': '為你的角色而設計',
  'Learners': '學習者',
  'Educators': '教育者',
  'Parents': '家長',
  'Site Admins': '站點管理員',
  'Ready to Transform Learning?': '準備好改變學習方式了嗎？',
  'Join hundreds of learning studios already using Scholesa.':
      '加入已經在使用 Scholesa 的數百家學習工作室。',
  '© 2026 Scholesa. Capability Evidence Platform.': '© 2026 Scholesa。能力證據平台。',
};

String _tLanding(BuildContext context, String input) {
  return InlineLocaleText.of(
    context,
    input,
    zhCn: _landingZhCn,
    zhTw: _landingZhTw,
  );
}

/// Landing Page - Public welcome page before login
/// Showcases Scholesa's K-12 curriculum architecture and platform model
class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with TickerProviderStateMixin {
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
    ).animate(
        CurvedAnimation(parent: _heroController, curve: Curves.easeOutCubic));
    _featuresFade =
        CurvedAnimation(parent: _featuresController, curve: Curves.easeOut);

    _heroController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _featuresController.forward();
    });

    TelemetryService.instance.logEvent(
      event: 'cms.page.viewed',
      metadata: const <String, dynamic>{
        'slug': 'landing',
        'surface': 'public_landing',
      },
    );
  }

  @override
  void dispose() {
    _heroController.dispose();
    _featuresController.dispose();
    super.dispose();
  }

  Future<void> _trackSignInCTA(String source) async {
    await TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'landing_sign_in',
        'source': source,
      },
    );
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

              // Curriculum Section
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
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const ScholesaLogoSmall(size: 44),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Scholesa',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isWide ? 24 : 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Nav links (wide only)
          if (isWide) ...<Widget>[
            _NavLink(
              label: _tLanding(context, 'Features'),
              onTap: () => _showSectionPreview(
                title: _tLanding(context, 'Features'),
                detail: _tLanding(context,
                    'Evidence capture, MiloOS coaching, portfolios, analytics, and offline classroom support.'),
              ),
            ),
            const SizedBox(width: 32),
            _NavLink(
              label: _tLanding(context, 'Curriculum'),
              onTap: () => _showSectionPreview(
                title: _tLanding(context, 'Curriculum'),
                detail: _tLanding(context,
                    'Discoverers, Builders, Explorers, Innovators, and six capability strands.'),
              ),
            ),
            const SizedBox(width: 32),
            _NavLink(
              label: _tLanding(context, 'For Schools'),
              onTap: () => _showSectionPreview(
                title: _tLanding(context, 'For Schools'),
                detail: _tLanding(context,
                    'Role-based dashboards for learners, educators, parents, site teams, and HQ.'),
              ),
            ),
            const SizedBox(width: 32),
          ],
          // CTA Buttons
          TextButton(
            onPressed: () {
              _trackSignInCTA('landing_nav_sign_in');
              context.go('/login');
            },
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _tLanding(context, 'Sign In'),
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.auto_awesome, size: 16, color: ScholesaColors.primary),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  _tLanding(context, 'Capability learning, made visible'),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ScholesaColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Headline
        Text(
          _tLanding(context, 'The Proof Engine for\nReal Capability Growth'),
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
          _tLanding(context,
              'Scholesa turns classroom moments into trustworthy proof: observations, artifacts, explain-backs, rubric judgments, growth history, and portfolios families can understand.'),
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
              onPressed: () {
                _trackSignInCTA('landing_hero_sign_in');
                context.go('/login');
              },
              icon: const Icon(Icons.login_rounded),
              label: Text(_tLanding(context, 'Sign In')),
              style: ElevatedButton.styleFrom(
                backgroundColor: ScholesaColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
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
              onPressed: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: const <String, dynamic>{
                    'cta': 'landing_watch_demo',
                  },
                );
                _showDemoDialog(context);
              },
              icon: const Icon(Icons.play_circle_outline_rounded),
              label: Text(_tLanding(context, 'See the Proof Flow')),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
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

  void _showDemoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(_tLanding(context, 'Scholesa Demo')),
        content: Text(_tLanding(context,
            'Demo walkthrough includes:\n• Role dashboards\n• CTA action flows\n• Mission and attendance lifecycle')),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'cta': 'landing_demo_close',
                },
              );
              Navigator.pop(dialogContext);
            },
            child: Text(_tLanding(context, 'Close')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _trackSignInCTA('landing_try_live');
              context.go('/login');
            },
            child: Text(_tLanding(context, 'Try Live')),
          ),
        ],
      ),
    );
  }

  void _showSectionPreview({required String title, required String detail}) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(detail),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'cta': 'landing_section_preview_close',
                  'section_title': title,
                },
              );
              Navigator.pop(dialogContext);
            },
            child: Text(_tLanding(context, 'Close')),
          ),
        ],
      ),
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
              label: _tLanding(context, 'MiloOS'),
              color: ScholesaColors.futureSkills,
            ),
          ),
          Positioned(
            top: 80,
            right: 40,
            child: _buildFloatingCard(
              icon: Icons.emoji_events_rounded,
              label: _tLanding(context, 'Achievements'),
              color: ScholesaColors.leadership,
            ),
          ),
          Positioned(
            bottom: 80,
            left: 60,
            child: _buildFloatingCard(
              icon: Icons.rocket_launch_rounded,
              label: _tLanding(context, 'Missions'),
              color: ScholesaColors.impact,
            ),
          ),
          Positioned(
            bottom: 40,
            right: 60,
            child: _buildFloatingCard(
              icon: Icons.groups_rounded,
              label: _tLanding(context, 'Community'),
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
          Text(
            _tLanding(context, 'Capability Pathways'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ScholesaColors.primary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _tLanding(context, 'Proof That Growth Is Real'),
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            _tLanding(context,
                'A K-12 learning architecture that carries evidence from discovery to innovation.'),
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          Wrap(
            spacing: 24,
            runSpacing: 24,
            children: <Widget>[
              SizedBox(
                width: isWide ? 320 : double.infinity,
                child: _buildPillarCard(
                  icon: Icons.auto_awesome_rounded,
                  title: _tLanding(context, 'Discoverers'),
                  description: _tLanding(context,
                      'Grades 1-3 • Story-rich invention studio with teacher-led AI demonstrations.'),
                  color: ScholesaColors.futureSkills,
                  emoji: '✨',
                ),
              ),
              SizedBox(
                width: isWide ? 320 : double.infinity,
                child: _buildPillarCard(
                  icon: Icons.handyman_rounded,
                  title: _tLanding(context, 'Builders'),
                  description: _tLanding(context,
                      'Grades 4-6 • Design-and-build labs with guided assistive AI use.'),
                  color: ScholesaColors.leadership,
                  emoji: '🛠️',
                ),
              ),
              SizedBox(
                width: isWide ? 320 : double.infinity,
                child: _buildPillarCard(
                  icon: Icons.travel_explore_rounded,
                  title: _tLanding(context, 'Explorers'),
                  description: _tLanding(context,
                      'Grades 7-9 • Investigation labs focused on critique, bias checks, and verification.'),
                  color: ScholesaColors.impact,
                  emoji: '🧭',
                ),
              ),
              SizedBox(
                width: isWide ? 320 : double.infinity,
                child: _buildPillarCard(
                  icon: Icons.rocket_launch_rounded,
                  title: _tLanding(context, 'Innovators'),
                  description: _tLanding(context,
                      'Grades 10-12 • Pathway-based capstone studios with full audit trails.'),
                  color: ScholesaColors.primary,
                  emoji: '🚀',
                ),
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
          Text(
            _tLanding(context, 'PLATFORM FEATURES'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ScholesaColors.primary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _tLanding(context, 'Everything You Need'),
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
              _buildFeatureItem(Icons.assignment_turned_in_rounded,
                  _tLanding(context, 'Mission-Based Learning')),
              _buildFeatureItem(Icons.psychology_rounded,
                  _tLanding(context, 'AI Habit Coaching')),
              _buildFeatureItem(Icons.folder_special_rounded,
                  _tLanding(context, 'Portfolio Showcase')),
              _buildFeatureItem(Icons.insights_rounded,
                  _tLanding(context, 'Progress Analytics')),
              _buildFeatureItem(
                  Icons.groups_rounded, _tLanding(context, 'Parent Portal')),
              _buildFeatureItem(
                  Icons.cloud_off_rounded, _tLanding(context, 'Offline-First')),
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
          Text(
            _tLanding(context, 'FOR EVERYONE'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ScholesaColors.primary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _tLanding(context, 'Designed for Your Role'),
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
              _buildRoleChip(_tLanding(context, 'Learners'),
                  ScholesaColors.learner, Icons.school_rounded),
              _buildRoleChip(_tLanding(context, 'Educators'),
                  ScholesaColors.educator, Icons.person_rounded),
              _buildRoleChip(_tLanding(context, 'Parents'),
                  ScholesaColors.parent, Icons.family_restroom_rounded),
              _buildRoleChip(_tLanding(context, 'Site Admins'),
                  ScholesaColors.site, Icons.business_rounded),
              _buildRoleChip(
                  'HQ', ScholesaColors.hq, Icons.admin_panel_settings_rounded),
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
          Text(
            _tLanding(context, 'Ready to Transform Learning?'),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            _tLanding(context,
                'Join hundreds of learning studios already using Scholesa.'),
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              _trackSignInCTA('landing_bottom_sign_in');
              context.go('/login');
            },
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
            child: Text(_tLanding(context, 'Sign In')),
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
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              ScholesaLogoSmall(size: 36),
              SizedBox(width: 8),
              Text(
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
            _tLanding(
                context, '© 2026 Scholesa. Capability Evidence Platform.'),
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
      onTap: () {
        TelemetryService.instance.logEvent(
          event: 'cta.clicked',
          metadata: <String, dynamic>{
            'cta': 'landing_nav_link',
            'label': label,
          },
        );
        onTap();
      },
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
