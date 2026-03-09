import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';
import '../../runtime/runtime.dart';
import '../../auth/app_state.dart';
import '../../i18n/learner_surface_i18n.dart';

String _tLearnerPortfolio(BuildContext context, String input) {
  return LearnerSurfaceI18n.text(context, input);
}

/// Learner Portfolio Page - Achievements, badges, and skill showcase
class LearnerPortfolioPage extends StatefulWidget {
  const LearnerPortfolioPage({super.key});

  @override
  State<LearnerPortfolioPage> createState() => _LearnerPortfolioPageState();
}

class _LearnerPortfolioPageState extends State<LearnerPortfolioPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showAiCoach = false;

  String _t(String input) => _tLearnerPortfolio(context, input);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        return;
      }
      final String tab = switch (_tabController.index) {
        0 => 'badges',
        1 => 'skills',
        2 => 'projects',
        _ => 'unknown',
      };
      TelemetryService.instance.logEvent(
        event: 'cta.clicked',
        metadata: <String, dynamic>{
          'module': 'learner_portfolio',
          'cta_id': 'change_tab',
          'surface': 'tab_bar',
          'tab': tab,
        },
      );
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              ScholesaColors.learner.withValues(alpha: 0.05),
              context.schSurface,
              ScholesaColors.futureSkills.withValues(alpha: 0.03),
            ],
          ),
        ),
        child: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildProfileCard()),
              SliverToBoxAdapter(child: _buildLevelProgress()),
              SliverToBoxAdapter(child: _buildPillarStats()),
              SliverToBoxAdapter(child: _buildAiCoachingSection(context)),
              SliverToBoxAdapter(child: _buildTabBar()),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: <Widget>[
              _buildBadgesList(),
              _buildSkillsList(),
              _buildProjectsList(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          TelemetryService.instance.logEvent(
            event: 'cta.clicked',
            metadata: <String, dynamic>{
              'module': 'learner_portfolio',
              'cta_id': 'open_share_portfolio_dialog',
              'surface': 'floating_action_button',
            },
          );
          _sharePortfolio();
        },
        backgroundColor: ScholesaColors.learner,
        icon: const Icon(Icons.share),
        label: Text(_t('Share')),
      ),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: ScholesaColors.learnerGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: ScholesaColors.learner.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.workspace_premium,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _t('My Portfolio'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: ScholesaColors.learner,
                        ),
                  ),
                  Text(
                    _t('Showcase your achievements'),
                    style: TextStyle(
                        color: context.schTextSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: <String, dynamic>{
                    'module': 'learner_portfolio',
                    'cta_id': 'open_edit_profile_dialog',
                    'surface': 'header',
                  },
                );
                _editProfile();
              },
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ScholesaColors.learner.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.edit, color: ScholesaColors.learner),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              ScholesaColors.learner,
              ScholesaColors.learner.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: ScholesaColors.learner.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3), width: 2),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 48),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Emma Johnson',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _t('Future Innovator • Singapore'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Icon(Icons.local_fire_department,
                          color: Colors.orange, size: 18),
                      SizedBox(width: 4),
                      Text(
                        '15 ${_t('day streak')}',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      SizedBox(width: 16),
                      Icon(Icons.star, color: Colors.amber, size: 18),
                      SizedBox(width: 4),
                      Text(
                        '1,250 XP',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelProgress() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.schBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            ScholesaColors.futureSkills.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.rocket_launch,
                          color: ScholesaColors.futureSkills, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _t('Level 12'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          _t('Rising Explorer'),
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: ScholesaColors.futureSkills.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '750 / 1000 XP',
                    style: TextStyle(
                      color: ScholesaColors.futureSkills,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: 0.75,
                backgroundColor:
                    ScholesaColors.futureSkills.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  ScholesaColors.futureSkills,
                ),
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _t('250 XP to Level 13 - Aspiring Trailblazer'),
              style: TextStyle(color: context.schTextSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillarStats() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _PillarStatCard(
              icon: Icons.code,
              label: _t('Future Skills'),
              missions: 28,
              skills: 12,
              color: ScholesaColors.futureSkills,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _PillarStatCard(
              icon: Icons.emoji_events,
              label: _t('Leadership'),
              missions: 18,
              skills: 8,
              color: ScholesaColors.leadership,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _PillarStatCard(
              icon: Icons.eco,
              label: _t('Impact'),
              missions: 14,
              skills: 6,
              color: ScholesaColors.impact,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.schSurfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: context.schTextSecondary,
        indicator: BoxDecoration(
          color: ScholesaColors.learner,
          borderRadius: BorderRadius.circular(12),
        ),
        tabs: <Widget>[
          Tab(text: _t('Badges')),
          Tab(text: _t('Skills')),
          Tab(text: _t('Projects')),
        ],
      ),
    );
  }

  Widget _buildBadgesList() {
    final List<Map<String, dynamic>> badges = <Map<String, dynamic>>[
      <String, dynamic>{
        'name': _t('First Mission'),
        'description': _t('Completed your first mission'),
        'icon': Icons.rocket_launch,
        'color': ScholesaColors.futureSkills,
        'earned': true,
        'date': 'Oct 15, 2024',
      },
      <String, dynamic>{
        'name': _t('Week Warrior'),
        'description': _t('7-day streak achievement'),
        'icon': Icons.local_fire_department,
        'color': Colors.orange,
        'earned': true,
        'date': 'Nov 22, 2024',
      },
      <String, dynamic>{
        'name': _t('Code Master'),
        'description': _t('Complete 10 coding missions'),
        'icon': Icons.code,
        'color': ScholesaColors.futureSkills,
        'earned': true,
        'date': 'Dec 5, 2024',
      },
      <String, dynamic>{
        'name': _t('Team Leader'),
        'description': _t('Lead a group project'),
        'icon': Icons.groups,
        'color': ScholesaColors.leadership,
        'earned': true,
        'date': 'Dec 12, 2024',
      },
      <String, dynamic>{
        'name': _t('Eco Champion'),
        'description': _t('Complete 5 sustainability missions'),
        'icon': Icons.eco,
        'color': ScholesaColors.impact,
        'earned': false,
        'progress': 3,
        'total': 5,
      },
      <String, dynamic>{
        'name': _t('Perfect Month'),
        'description': _t('30-day streak achievement'),
        'icon': Icons.calendar_month,
        'color': Colors.amber,
        'earned': false,
        'progress': 15,
        'total': 30,
      },
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: badges.length,
      itemBuilder: (BuildContext context, int index) {
        final Map<String, dynamic> badge = badges[index];
        return _BadgeCard(badge: badge);
      },
    );
  }

  Widget _buildSkillsList() {
    final List<Map<String, dynamic>> skills = <Map<String, dynamic>>[
      <String, dynamic>{
        'name': _t('Python Programming'),
        'pillar': _t('Future Skills'),
        'level': 3,
        'maxLevel': 5,
        'progress': 0.65,
        'color': ScholesaColors.futureSkills,
      },
      <String, dynamic>{
        'name': _t('Creative Thinking'),
        'pillar': _t('Leadership'),
        'level': 4,
        'maxLevel': 5,
        'progress': 0.82,
        'color': ScholesaColors.leadership,
      },
      <String, dynamic>{
        'name': _t('Public Speaking'),
        'pillar': _t('Leadership'),
        'level': 2,
        'maxLevel': 5,
        'progress': 0.45,
        'color': ScholesaColors.leadership,
      },
      <String, dynamic>{
        'name': _t('Environmental Awareness'),
        'pillar': _t('Impact'),
        'level': 3,
        'maxLevel': 5,
        'progress': 0.58,
        'color': ScholesaColors.impact,
      },
      <String, dynamic>{
        'name': _t('Robotics'),
        'pillar': _t('Future Skills'),
        'level': 2,
        'maxLevel': 5,
        'progress': 0.35,
        'color': ScholesaColors.futureSkills,
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: skills.length,
      itemBuilder: (BuildContext context, int index) {
        final Map<String, dynamic> skill = skills[index];
        return _SkillCard(skill: skill);
      },
    );
  }

  Widget _buildProjectsList() {
    final List<Map<String, dynamic>> projects = <Map<String, dynamic>>[
      <String, dynamic>{
        'title': _t('Weather Station App'),
        'description': _t('Built a Python app to display local weather data'),
        'pillar': _t('Future Skills'),
        'date': 'Dec 10, 2024',
        'image': null,
        'color': ScholesaColors.futureSkills,
      },
      <String, dynamic>{
        'title': _t('School Recycling Campaign'),
        'description': _t('Led initiative to increase recycling by 40%'),
        'pillar': _t('Impact'),
        'date': 'Nov 28, 2024',
        'image': null,
        'color': ScholesaColors.impact,
      },
      <String, dynamic>{
        'title': _t('Team Presentation'),
        'description': _t('Presented AI research to parents and community'),
        'pillar': _t('Leadership'),
        'date': 'Nov 15, 2024',
        'image': null,
        'color': ScholesaColors.leadership,
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: projects.length,
      itemBuilder: (BuildContext context, int index) {
        final Map<String, dynamic> project = projects[index];
        return _ProjectCard(project: project);
      },
    );
  }

  void _editProfile() {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(_t('Edit Portfolio Profile')),
        content: Text(
          _t('Update your portfolio bio, goals, and featured highlights.')),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'module': 'learner_portfolio',
                  'cta_id': 'cancel_edit_profile',
                  'surface': 'edit_profile_dialog',
                },
              );
              Navigator.pop(dialogContext);
            },
            child: Text(_t('Cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'module': 'learner_portfolio',
                  'cta_id': 'save_profile_changes',
                  'surface': 'edit_profile_dialog',
                },
              );
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_t('Portfolio profile update queued')),
                  backgroundColor: ScholesaColors.learner,
                ),
              );
            },
            child: Text(_t('Save')),
          ),
        ],
      ),
    );
  }

  void _sharePortfolio() {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(_t('Share Portfolio')),
        content: Text(_t('Create a secure share link for parents or mentors.')),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'module': 'learner_portfolio',
                  'cta_id': 'cancel_share_portfolio',
                  'surface': 'share_portfolio_dialog',
                },
              );
              Navigator.pop(dialogContext);
            },
            child: Text(_t('Cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'module': 'learner_portfolio',
                  'cta_id': 'generate_share_link',
                  'surface': 'share_portfolio_dialog',
                },
              );
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_t('Share link generated')),
                  backgroundColor: ScholesaColors.learner,
                ),
              );
            },
            child: Text(_t('Generate Link')),
          ),
        ],
      ),
    );
  }

  Widget _buildAiCoachingSection(BuildContext context) {
    final AppState appState = context.read<AppState>();
    final UserRole? role = appState.role;

    if (role == null || role != UserRole.learner) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              color: context.schSurface,
              border: Border.all(
                color: ScholesaColors.learner.withValues(alpha: 0.2),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Icon(
                Icons.smart_toy_rounded,
                color: ScholesaColors.learner,
              ),
              title: Text(_t('Reflect on Progress')),
              subtitle: Text(_t('Get AI insights on your achievements')),
              trailing: IconButton(
                icon: Icon(
                  _showAiCoach ? Icons.expand_less : Icons.expand_more,
                ),
                onPressed: () {
                  setState(() => _showAiCoach = !_showAiCoach);
                  TelemetryService.instance.logEvent(
                    event: 'cta.clicked',
                    metadata: <String, dynamic>{
                      'module': 'learner_portfolio',
                      'cta': 'portfolio_ai_${_showAiCoach ? 'show' : 'hide'}',
                      'surface': 'portfolio_header',
                    },
                  );
                },
              ),
            ),
          ),
          if (_showAiCoach) _buildAiCoachPanel(context, role),
        ],
      ),
    );
  }

  Widget _buildAiCoachPanel(BuildContext context, UserRole role) {
    final LearningRuntimeProvider? runtime =
        context.read<LearningRuntimeProvider?>();
    if (runtime == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: context.schSurface,
        border: Border.all(
          color: ScholesaColors.learner.withValues(alpha: 0.1),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      constraints: const BoxConstraints(minHeight: 350),
      child: AiCoachWidget(
        runtime: runtime,
        actorRole: role,
        conceptTags: <String>[
          'portfolio',
          'reflection',
          'achievements',
        ],
      ),
    );
  }
}

class _PillarStatCard extends StatelessWidget {
  const _PillarStatCard({
    required this.icon,
    required this.label,
    required this.missions,
    required this.skills,
    required this.color,
  });
  final IconData icon;
  final String label;
  final int missions;
  final int skills;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.schBorder),
      ),
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            '$missions',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: color,
            ),
          ),
          Text(
            _tLearnerPortfolio(context, 'missions'),
            style: TextStyle(
                color: context.schTextSecondary.withValues(alpha: 0.88),
                fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.badge});
  final Map<String, dynamic> badge;

  @override
  Widget build(BuildContext context) {
    final bool earned = badge['earned'] as bool;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: earned
              ? (badge['color'] as Color).withValues(alpha: 0.3)
              : context.schBorder,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: earned
                  ? (badge['color'] as Color).withValues(alpha: 0.15)
                  : context.schSurfaceMuted,
              shape: BoxShape.circle,
            ),
            child: Icon(
              badge['icon'] as IconData,
              color: earned ? badge['color'] as Color : Colors.grey,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            badge['name'] as String,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: earned ? Colors.black : Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          if (earned)
            Text(
              badge['date'] as String,
              style: TextStyle(color: context.schTextSecondary, fontSize: 10),
            )
          else
            Column(
              children: <Widget>[
                Text(
                  '${badge['progress']}/${badge['total']}',
                  style:
                      TextStyle(color: context.schTextSecondary, fontSize: 10),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (badge['progress'] as int) / (badge['total'] as int),
                    backgroundColor: context.schBorder,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      badge['color'] as Color,
                    ),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SkillCard extends StatelessWidget {
  const _SkillCard({required this.skill});
  final Map<String, dynamic> skill;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.schBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        skill['name'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        skill['pillar'] as String,
                        style: TextStyle(
                          color: skill['color'] as Color,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: (skill['color'] as Color).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_tLearnerPortfolio(context, 'Level')} ${skill['level']}/${skill['maxLevel']}',
                    style: TextStyle(
                      color: skill['color'] as Color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: skill['progress'] as double,
                backgroundColor:
                    (skill['color'] as Color).withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  skill['color'] as Color,
                ),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  '${((skill['progress'] as double) * 100).toInt()}% ${_tLearnerPortfolio(context, 'to next level')}',
                  style:
                      TextStyle(color: context.schTextSecondary, fontSize: 12),
                ),
                Row(
                  children: List<Widget>.generate(
                    skill['maxLevel'] as int,
                    (int index) => Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.star,
                        size: 16,
                        color: index < (skill['level'] as int)
                            ? skill['color'] as Color
                            : Colors.grey.shade300,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});
  final Map<String, dynamic> project;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.schBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: (project['color'] as Color).withValues(alpha: 0.15),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.folder_special,
                  size: 48,
                  color: project['color'] as Color,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (project['color'] as Color)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          project['pillar'] as String,
                          style: TextStyle(
                            color: project['color'] as Color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        project['date'] as String,
                        style: TextStyle(
                            color: context.schTextSecondary
                                .withValues(alpha: 0.88),
                            fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    project['title'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    project['description'] as String,
                    style: TextStyle(
                        color: context.schTextSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
