import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../i18n/workflow_surface_i18n.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';
import '../../runtime/runtime.dart';
import '../../auth/app_state.dart';
import 'mission_models.dart';
import 'mission_service.dart';

String _tMissions(BuildContext context, String input) {
  return WorkflowSurfaceI18n.text(context, input);
}

/// Learner Missions Page
/// Beautiful colorful UI for learners to discover and complete missions
class MissionsPage extends StatefulWidget {
  const MissionsPage({super.key});

  @override
  State<MissionsPage> createState() => _MissionsPageState();
}

class _MissionsPageState extends State<MissionsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        return;
      }
      final String tab = switch (_tabController.index) {
        0 => 'available',
        1 => 'in_progress',
        2 => 'completed',
        _ => 'unknown',
      };
      TelemetryService.instance.logEvent(
        event: 'cta.clicked',
        metadata: <String, dynamic>{
          'cta': 'missions_change_tab',
          'surface': 'missions_tab_bar',
          'tab': tab,
        },
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MissionService>().loadMissions();
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
              const Color(0xFFF59E0B).withValues(alpha: 0.03),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _buildHeader(),
              _buildProgressCard(),
              _buildPillarFilters(),
              _buildTabBar(),
              Expanded(child: _buildTabContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: ScholesaColors.missionGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child:
                const Icon(Icons.rocket_launch, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _tMissions(context, 'My Missions'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFF59E0B),
                    ),
              ),
              Text(
                _tMissions(context, 'Learn, grow, and level up!'),
                style: TextStyle(color: context.schTextSecondary, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    return Consumer<MissionService>(
      builder: (BuildContext context, MissionService service, _) {
        final LearnerProgress? progress = service.progress;
        if (progress == null) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                ScholesaColors.learner,
                ScholesaColors.learner.withValues(alpha: 0.8)
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: ScholesaColors.learner.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        'Lv ${progress.currentLevel}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              '${progress.totalXp} XP',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              '${progress.xpToNextLevel} ${_tMissions(context, 'to next level')}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress.levelProgress,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.3),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  _ProgressStat(
                    icon: Icons.check_circle,
                    value: '${progress.missionsCompleted}',
                    label: _tMissions(context, 'Completed'),
                  ),
                  _ProgressStat(
                    icon: Icons.local_fire_department,
                    value: '${progress.currentStreak}',
                    label: _tMissions(context, 'Day Streak'),
                  ),
                  _ProgressStat(
                    icon: Icons.play_circle,
                    value: '${service.activeMissions.length}',
                    label: _tMissions(context, 'Active'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPillarFilters() {
    return Consumer<MissionService>(
      builder: (BuildContext context, MissionService service, _) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                _PillarChip(
                  label: _tMissions(context, 'All'),
                  emoji: '🎯',
                  selected: service.pillarFilter == null,
                  onTap: () {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: const <String, dynamic>{
                        'cta': 'missions_filter_all',
                        'surface': 'missions_pillar_filters',
                      },
                    );
                    service.setPillarFilter(null);
                  },
                ),
                ...Pillar.values.map((Pillar pillar) => _PillarChip(
                      label: pillar.label,
                      emoji: pillar.emoji,
                      selected: service.pillarFilter == pillar,
                      onTap: () {
                        TelemetryService.instance.logEvent(
                          event: 'cta.clicked',
                          metadata: <String, dynamic>{
                            'cta': 'missions_filter_pillar',
                            'surface': 'missions_pillar_filters',
                            'pillar': pillar.name,
                          },
                        );
                        service.setPillarFilter(pillar);
                      },
                      color: _getPillarColor(pillar),
                    )),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.schSurfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: ScholesaColors.learner,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: context.schTextSecondary,
        tabs: <Widget>[
          Tab(text: _tMissions(context, 'Available')),
          Tab(text: _tMissions(context, 'In Progress')),
          Tab(text: _tMissions(context, 'Completed')),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: <Widget>[
        _buildMissionsList(MissionStatus.notStarted),
        _buildMissionsList(MissionStatus.inProgress),
        _buildMissionsList(MissionStatus.completed),
      ],
    );
  }

  Widget _buildMissionsList(MissionStatus statusFilter) {
    return Consumer<MissionService>(
      builder: (BuildContext context, MissionService service, _) {
        if (service.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: ScholesaColors.learner),
          );
        }

        final List<Mission> missions = service.missions.where((Mission m) {
          if (statusFilter == MissionStatus.inProgress) {
            return m.status == MissionStatus.inProgress ||
                m.status == MissionStatus.submitted ||
                m.status == MissionStatus.needsRevision;
          }
          return m.status == statusFilter;
        }).toList();

        if (missions.isEmpty) {
          return _buildEmptyState(statusFilter);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: missions.length,
          itemBuilder: (BuildContext context, int index) {
            final Mission mission = missions[index];
            return _MissionCard(
              mission: mission,
              onTap: () => _showMissionDetails(mission),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(MissionStatus status) {
    String title;
    String subtitle;
    IconData icon;

    switch (status) {
      case MissionStatus.notStarted:
        title = _tMissions(context, 'No missions available');
        subtitle = _tMissions(context, 'Check back soon for new challenges!');
        icon = Icons.search;
      case MissionStatus.inProgress:
        title = _tMissions(context, 'No active missions');
        subtitle =
            _tMissions(context, 'Start a mission to begin your journey!');
        icon = Icons.play_circle_outline;
      case MissionStatus.completed:
        title = _tMissions(context, 'No completed missions yet');
        subtitle = _tMissions(context, 'Complete missions to see them here!');
        icon = Icons.emoji_events_outlined;
      default:
        title = _tMissions(context, 'No missions');
        subtitle = '';
        icon = Icons.rocket_launch;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ScholesaColors.learner.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: ScholesaColors.learner),
          ),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: context.schTextSecondary)),
        ],
      ),
    );
  }

  void _showMissionDetails(Mission mission) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'missions_open_details',
        'mission_id': mission.id,
        'status': mission.status.name,
      },
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => _MissionDetailsSheet(mission: mission),
    );
  }

  Color _getPillarColor(Pillar pillar) {
    switch (pillar) {
      case Pillar.futureSkills:
        return const Color(0xFF3B82F6);
      case Pillar.leadership:
        return const Color(0xFF8B5CF6);
      case Pillar.impact:
        return const Color(0xFF10B981);
    }
  }
}

// ==================== Sub Widgets ====================

class _ProgressStat extends StatelessWidget {
  const _ProgressStat({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _PillarChip extends StatelessWidget {
  const _PillarChip({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
    this.color,
  });
  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color chipColor = color ?? ScholesaColors.learner;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? chipColor : chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : chipColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({
    required this.mission,
    required this.onTap,
  });
  final Mission mission;
  final VoidCallback onTap;

  Color get _pillarColor {
    switch (mission.pillar) {
      case Pillar.futureSkills:
        return const Color(0xFF3B82F6);
      case Pillar.leadership:
        return const Color(0xFF8B5CF6);
      case Pillar.impact:
        return const Color(0xFF10B981);
    }
  }

  Color get _statusColor {
    switch (mission.status) {
      case MissionStatus.notStarted:
        return Colors.grey;
      case MissionStatus.inProgress:
        return ScholesaColors.learner;
      case MissionStatus.submitted:
        return ScholesaColors.warning;
      case MissionStatus.completed:
        return ScholesaColors.success;
      case MissionStatus.needsRevision:
        return ScholesaColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: _pillarColor.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  // Pillar badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _pillarColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(mission.pillar.emoji,
                            style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(
                          mission.pillar.label,
                          style: TextStyle(
                            color: _pillarColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // XP badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.star,
                            color: Color(0xFFF59E0B), size: 14),
                        const SizedBox(width: 2),
                        Text(
                          '${mission.xpReward} XP',
                          style: const TextStyle(
                            color: Color(0xFFF59E0B),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                mission.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                mission.description,
                style: TextStyle(color: context.schTextSecondary, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              // Progress or Status
              if (mission.status == MissionStatus.inProgress ||
                  mission.status == MissionStatus.submitted) ...<Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: mission.progress,
                          backgroundColor: _pillarColor.withValues(alpha: 0.1),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(_pillarColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${(mission.progress * 100).toInt()}%',
                      style: TextStyle(
                        color: _pillarColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              // Bottom row
              Row(
                children: <Widget>[
                  // Difficulty
                  Icon(
                    Icons.signal_cellular_alt,
                    size: 14,
                    color: context.schTextSecondary.withValues(alpha: 0.74),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    mission.difficulty.label,
                    style: TextStyle(
                        color: context.schTextSecondary.withValues(alpha: 0.88),
                        fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  // Steps
                  Icon(
                    Icons.checklist,
                    size: 14,
                    color: context.schTextSecondary.withValues(alpha: 0.74),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${mission.completedStepsCount}/${mission.totalStepsCount} ${_tMissions(context, 'steps')}',
                    style: TextStyle(
                        color: context.schTextSecondary.withValues(alpha: 0.88),
                        fontSize: 12),
                  ),
                  const Spacer(),
                  // Status badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      mission.status.label,
                      style: TextStyle(
                        color: _statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissionDetailsSheet extends StatefulWidget {
  const _MissionDetailsSheet({required this.mission});
  final Mission mission;

  @override
  State<_MissionDetailsSheet> createState() => _MissionDetailsSheetState();
}

class _MissionDetailsSheetState extends State<_MissionDetailsSheet> {
  bool _showAiCoach = false;
  bool _isUpdatingStudyAction = false;

  Color get _pillarColor {
    switch (widget.mission.pillar) {
      case Pillar.futureSkills:
        return const Color(0xFF3B82F6);
      case Pillar.leadership:
        return const Color(0xFF8B5CF6);
      case Pillar.impact:
        return const Color(0xFF10B981);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MissionService>(
      builder: (BuildContext context, MissionService service, _) {
        final Mission mission =
            service.getMissionById(widget.mission.id) ?? widget.mission;

        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: <Widget>[
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Header
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: <Color>[
                                  _pillarColor.withValues(alpha: 0.8),
                                  _pillarColor
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: _pillarColor.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              mission.pillar.emoji,
                              style: const TextStyle(fontSize: 32),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _pillarColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    mission.pillar.label,
                                    style: TextStyle(
                                      color: _pillarColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  mission.title,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Stats row
                      Row(
                        children: <Widget>[
                          _StatChip(
                            icon: Icons.star,
                            value: '${mission.xpReward} XP',
                            color: const Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 8),
                          _StatChip(
                            icon: Icons.signal_cellular_alt,
                            value: mission.difficulty.label,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          _StatChip(
                            icon: Icons.checklist,
                            value:
                                '${mission.steps.length} ${_tMissions(context, 'Steps')}',
                            color: _pillarColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Description
                      Text(
                        _tMissions(context, 'Description'),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        mission.description,
                        style: TextStyle(
                            color: context.schTextSecondary, height: 1.5),
                      ),
                      const SizedBox(height: 24),

                      // Skills
                      if (mission.skills.isNotEmpty) ...<Widget>[
                        Text(
                          _tMissions(context, "Skills You'll Learn"),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: mission.skills
                              .map((Skill skill) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color:
                                          _pillarColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      skill.name,
                                      style: TextStyle(
                                        color: _pillarColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Steps
                      Text(
                        _tMissions(context, 'Mission Steps'),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...mission.steps.map((MissionStep step) =>
                          _StepItem(step: step, color: _pillarColor)),
                      const SizedBox(height: 24),

                      if (mission.status !=
                          MissionStatus.notStarted) ...<Widget>[
                        _buildStudyFlowSection(context, mission),
                        const SizedBox(height: 24),
                      ],

                      // Educator feedback
                      if (mission.educatorFeedback != null) ...<Widget>[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:
                                ScholesaColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: ScholesaColors.success
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Icon(Icons.comment,
                                      color: ScholesaColors.success, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    _tMissions(context, 'Educator Feedback'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: ScholesaColors.success,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                mission.educatorFeedback!,
                                style: TextStyle(
                                    color: Colors.grey[700], height: 1.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // AI Coaching Section
                      _buildAiCoachingSection(context, _pillarColor),
                      const SizedBox(height: 24),

                      // Action button
                      if (mission.status == MissionStatus.notStarted)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              TelemetryService.instance.logEvent(
                                event: 'cta.clicked',
                                metadata: <String, dynamic>{
                                  'cta': 'missions_start_mission',
                                  'mission_id': mission.id,
                                },
                              );
                              final bool started = await context
                                  .read<MissionService>()
                                  .startMission(mission.id);

                              if (!context.mounted) return;

                              if (started) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        '${_tMissions(context, 'Started')}: ${mission.title}'),
                                    backgroundColor: ScholesaColors.success,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(_tMissions(context,
                                        'Unable to start mission right now')),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _pillarColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Icon(Icons.rocket_launch),
                                SizedBox(width: 8),
                                Text(
                                  _tMissions(context, 'Start Mission'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (mission.status == MissionStatus.inProgress &&
                          mission.progress == 1.0)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              TelemetryService.instance.logEvent(
                                event: 'cta.clicked',
                                metadata: <String, dynamic>{
                                  'cta': 'missions_submit_for_review',
                                  'mission_id': mission.id,
                                },
                              );
                              final MissionService missionService =
                                  context.read<MissionService>();
                              final String? submissionId = await missionService
                                  .submitMission(mission.id);

                              if (submissionId == null) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(_tMissions(context,
                                        'Unable to submit mission right now')),
                                    backgroundColor: ScholesaColors.error,
                                  ),
                                );
                                return;
                              }

                              TelemetryService.instance.logEvent(
                                event: 'mission.attempt.submitted',
                                metadata: <String, dynamic>{
                                  'mission_id': mission.id,
                                  'submission_id': submissionId,
                                  'mission_status': mission.status.name,
                                  'progress': mission.progress,
                                },
                              );
                              if (!context.mounted) return;
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      '${_tMissions(context, 'Submitted')}: ${mission.title}'),
                                  backgroundColor: ScholesaColors.success,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ScholesaColors.success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Icon(Icons.send),
                                SizedBox(width: 8),
                                Text(
                                  _tMissions(context, 'Submit for Review'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStudyFlowSection(BuildContext context, Mission mission) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _tMissions(context, 'Study flow'),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _pillarColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _pillarColor.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.memory_rounded, color: _pillarColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _tMissions(context, 'Review memory'),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _pillarColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                mission.fsrsLastRating == null
                    ? _tMissions(
                        context,
                        'Choose how this mission felt to plan the next review.',
                      )
                    : '${_tMissions(context, 'Last rating')}: ${_tMissions(context, mission.fsrsLastRating!.label)}',
                style: TextStyle(color: context.schTextSecondary, height: 1.4),
              ),
              const SizedBox(height: 4),
              Text(
                '${_tMissions(context, 'Next review')}: ${_formatNextReview(mission.nextReviewAt)}',
                style: TextStyle(color: context.schTextSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: FsrsRating.values
                    .map(
                      (FsrsRating rating) => ActionChip(
                        label: Text(_tMissions(context, rating.label)),
                        onPressed: _isUpdatingStudyAction
                            ? null
                            : () => _handleStudyAction(
                                  action: () => context
                                      .read<MissionService>()
                                      .rateFsrsReview(
                                        mission.id,
                                        rating: rating,
                                      ),
                                  successMessage:
                                      _tMissions(context, 'Review saved'),
                                ),
                        backgroundColor: _pillarColor.withValues(alpha: 0.12),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: _isUpdatingStudyAction
                        ? null
                        : () => _handleStudyAction(
                              action: () => context
                                  .read<MissionService>()
                                  .snoozeFsrsQueue(mission.id),
                              successMessage:
                                  _tMissions(context, 'Queue snoozed'),
                            ),
                    icon: const Icon(Icons.snooze_rounded),
                    label: Text(_tMissions(context, 'Snooze 1 day')),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isUpdatingStudyAction
                        ? null
                        : () => _handleStudyAction(
                              action: () => context
                                  .read<MissionService>()
                                  .rescheduleFsrsQueue(mission.id),
                              successMessage:
                                  _tMissions(context, 'Review rescheduled'),
                            ),
                    icon: const Icon(Icons.event_repeat_rounded),
                    label: Text(_tMissions(context, 'Review in 3 days')),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Icon(Icons.shuffle_rounded, color: _pillarColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _tMissions(context, 'Study mode'),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _pillarColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _tMissions(
                  context,
                  'Switch between a single-focus path and mixed practice.',
                ),
                style: TextStyle(color: context.schTextSecondary, height: 1.4),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: InterleavingMode.values
                    .map(
                      (InterleavingMode mode) => ChoiceChip(
                        label: Text(_tMissions(context, mode.label)),
                        selected: mission.interleavingMode == mode,
                        onSelected: _isUpdatingStudyAction
                            ? null
                            : (_) => _handleStudyAction(
                                  action: () => context
                                      .read<MissionService>()
                                      .setInterleavingMode(
                                        mission.id,
                                        mode: mode,
                                      ),
                                  successMessage: _tMissions(
                                    context,
                                    'Study mode updated',
                                  ),
                                ),
                        selectedColor: _pillarColor.withValues(alpha: 0.18),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Icon(Icons.menu_book_rounded, color: _pillarColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _tMissions(context, 'Worked example'),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _pillarColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                mission.workedExampleShown
                    ? '${_tMissions(context, 'Fade stage')}: ${mission.workedExampleFadeStage}'
                    : _tMissions(
                        context,
                        'Reveal a worked example before you try the next step alone.',
                      ),
                style: TextStyle(color: context.schTextSecondary, height: 1.4),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _isUpdatingStudyAction
                    ? null
                    : () => _handleStudyAction(
                          action: () => context
                              .read<MissionService>()
                              .showWorkedExample(mission.id),
                          successMessage:
                              _tMissions(context, 'Worked example ready'),
                        ),
                icon: const Icon(Icons.visibility_rounded),
                label: Text(
                  mission.workedExampleShown
                      ? _tMissions(context, 'Show next example stage')
                      : _tMissions(context, 'Show worked example'),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _pillarColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatNextReview(DateTime? nextReviewAt) {
    if (nextReviewAt == null) {
      return _tMissions(context, 'Not scheduled');
    }

    final Duration difference = nextReviewAt.difference(DateTime.now());
    if (difference.inMinutes <= 0) {
      return _tMissions(context, 'Now');
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    }
    if (difference.inDays < 1) {
      return '${difference.inHours}h';
    }
    return '${difference.inDays}d';
  }

  Future<void> _handleStudyAction({
    required Future<bool> Function() action,
    required String successMessage,
  }) async {
    if (_isUpdatingStudyAction) {
      return;
    }

    setState(() => _isUpdatingStudyAction = true);
    final bool succeeded = await action();
    if (!mounted) {
      return;
    }
    setState(() => _isUpdatingStudyAction = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          succeeded
              ? successMessage
              : _tMissions(context, 'Unable to update study flow right now'),
        ),
        backgroundColor:
            succeeded ? ScholesaColors.success : ScholesaColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildAiCoachingSection(BuildContext context, Color pillarColor) {
    final AppState appState = context.read<AppState>();
    final String learnerId = appState.userId ?? '';
    final UserRole? role = appState.role;

    if (learnerId.isEmpty || role == null || role != UserRole.learner) {
      return const SizedBox.shrink();
    }

    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: pillarColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: pillarColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(Icons.smart_toy_rounded,
                          color: pillarColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _tMissions(context, 'Get AI Help'),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: pillarColor,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () {
                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: <String, dynamic>{
                          'cta': _showAiCoach
                              ? 'mission_ai_hide'
                              : 'mission_ai_show',
                          'mission_id': widget.mission.id,
                          'surface': 'mission_detail_sheet',
                        },
                      );
                      setState(() => _showAiCoach = !_showAiCoach);
                    },
                    icon: Icon(
                      _showAiCoach ? Icons.expand_less : Icons.expand_more,
                      color: pillarColor,
                    ),
                  ),
                ],
              ),
              if (!_showAiCoach) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  _tMissions(context,
                      'Ask for hints, explanations, or debugging help'),
                  style: TextStyle(
                    color: context.schTextSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
              if (_showAiCoach) ...<Widget>[
                const SizedBox(height: 16),
                _buildAiCoachPanel(context, role),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAiCoachPanel(BuildContext context, UserRole role) {
    final LearningRuntimeProvider? runtime =
        context.read<LearningRuntimeProvider?>();
    if (runtime == null) {
      return Center(
        child: Text(
          'AI Coach not available',
          style: TextStyle(color: context.schTextSecondary),
        ),
      );
    }

    return SizedBox(
      height: 400,
      child: AiCoachWidget(
        runtime: runtime,
        actorRole: role,
        missionId: widget.mission.id,
        conceptTags: widget.mission.skills.map((Skill s) => s.name).toList(),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  const _StepItem({required this.step, required this.color});
  final MissionStep step;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: step.isCompleted ? color : Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: step.isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : Text(
                      '${step.order}',
                      style: TextStyle(
                        color: context.schTextSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              step.title,
              style: TextStyle(
                color: step.isCompleted
                    ? context.schTextSecondary.withValues(alpha: 0.88)
                    : Colors.grey[800],
                decoration:
                    step.isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
