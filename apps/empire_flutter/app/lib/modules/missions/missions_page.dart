import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/models.dart' show LearnerProfileModel;
import '../../domain/repositories.dart';
import '../../i18n/workflow_surface_i18n.dart';
import '../../services/firestore_service.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';
import '../../ui/auth/global_session_menu.dart';
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

  bool _isCompactLayout(BuildContext context) {
    return MediaQuery.sizeOf(context).height < 700;
  }

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
    final bool compactLayout = _isCompactLayout(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compactLayout ? 16 : 20,
        compactLayout ? 16 : 20,
        compactLayout ? 16 : 20,
        compactLayout ? 12 : 20,
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: EdgeInsets.all(compactLayout ? 10 : 12),
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
          Expanded(
            child: Column(
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
                  _tMissions(
                    context,
                    'Track your engagement while educator-reviewed evidence builds your real growth record.',
                  ),
                  style: TextStyle(
                    color: context.schTextSecondary,
                    fontSize: compactLayout ? 13 : 14,
                  ),
                  maxLines: compactLayout ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const SessionMenuHeaderAction(
            foregroundColor: Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    final bool compactLayout = _isCompactLayout(context);
    return Consumer<MissionService>(
      builder: (BuildContext context, MissionService service, _) {
        final LearnerProgress? progress = service.progress;
        if (progress == null) return const SizedBox.shrink();

        return Container(
          margin: EdgeInsets.symmetric(horizontal: compactLayout ? 12 : 16),
          padding: EdgeInsets.all(compactLayout ? 12 : 16),
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
                    width: compactLayout ? 48 : 56,
                    height: compactLayout ? 48 : 56,
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
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: compactLayout ? 12 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              '${progress.totalXp} ${_tMissions(context, 'Activity XP')}',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: compactLayout ? 16 : 18,
                              ),
                            ),
                            Flexible(
                              child: Text(
                                '${progress.xpToNextLevel} ${_tMissions(context, 'to next activity level')}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: compactLayout ? 11 : 12,
                                ),
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
                    label: _tMissions(context, 'Finished'),
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
              if (!compactLayout) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  _tMissions(
                    context,
                    'XP, levels, and streaks show activity. Capability growth comes from reviewed evidence and rubric feedback.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPillarFilters() {
    final bool compactLayout = _isCompactLayout(context);
    return Consumer<MissionService>(
      builder: (BuildContext context, MissionService service, _) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            compactLayout ? 12 : 16,
            compactLayout ? 12 : 16,
            compactLayout ? 12 : 16,
            compactLayout ? 12 : 16,
          ),
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
          Tab(text: _tMissions(context, 'Finished')),
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
        title = _tMissions(context, 'No finished missions yet');
        subtitle = _tMissions(context, 'Finish missions to see them here!');
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
  bool _isSavingProofBundle = false;
  bool _isSavingCheckpoint = false;
  LearnerProfileModel? _learnerProfile;
  final TextEditingController _explainItBackController =
      TextEditingController();
  final TextEditingController _oralCheckController = TextEditingController();
  final TextEditingController _miniRebuildController = TextEditingController();
  final TextEditingController _aiDisclosureController = TextEditingController();
  final TextEditingController _artifactUrlsController = TextEditingController();
  final TextEditingController _checkpointSummaryController =
      TextEditingController();
  final TextEditingController _checkpointArtifactController =
      TextEditingController();
  List<MissionProofCheckpoint> _versionHistory =
      const <MissionProofCheckpoint>[];
  bool? _aiAssistanceUsed;

  bool get _keyboardOnlyEnabled =>
      _learnerProfile?.keyboardOnlyEnabled ?? false;
  bool get _highContrastEnabled =>
      _learnerProfile?.highContrastEnabled ?? false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLearnerProfile();
      _loadProofBundle();
    });
  }

  @override
  void dispose() {
    _explainItBackController.dispose();
    _oralCheckController.dispose();
    _miniRebuildController.dispose();
    _aiDisclosureController.dispose();
    _artifactUrlsController.dispose();
    _checkpointSummaryController.dispose();
    _checkpointArtifactController.dispose();
    super.dispose();
  }

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

  Future<void> _loadLearnerProfile() async {
    final AppState appState = context.read<AppState>();
    final String? learnerId = appState.userId;
    final String? siteId = appState.activeSiteId;
    if (learnerId == null ||
        learnerId.isEmpty ||
        siteId == null ||
        siteId.isEmpty) {
      return;
    }

    final FirestoreService firestoreService = context.read<FirestoreService>();
    final LearnerProfileRepository repository = LearnerProfileRepository(
      firestore: firestoreService.firestore,
    );
    final LearnerProfileModel? profile = await repository.getByLearnerAndSite(
      learnerId: learnerId,
      siteId: siteId,
    );

    if (!mounted || profile == null) {
      return;
    }

    setState(() => _learnerProfile = profile);
  }

  bool get _proofBundleReady {
    return _explainItBackController.text.trim().isNotEmpty &&
        _oralCheckController.text.trim().isNotEmpty &&
        _miniRebuildController.text.trim().isNotEmpty &&
        _aiAssistanceUsed != null &&
        (_aiAssistanceUsed != true ||
            _aiDisclosureController.text.trim().isNotEmpty) &&
        _versionHistory.isNotEmpty;
  }

  Future<void> _loadProofBundle() async {
    final MissionService missionService = context.read<MissionService>();
    final MissionProofBundle? bundle =
        await missionService.loadProofBundle(widget.mission.id);
    if (!mounted || bundle == null) {
      return;
    }
    setState(() {
      _explainItBackController.text = bundle.explainItBack ?? '';
      _oralCheckController.text = bundle.oralCheckResponse ?? '';
      _miniRebuildController.text = bundle.miniRebuildPlan ?? '';
      _aiAssistanceUsed = bundle.aiAssistanceUsed;
      _aiDisclosureController.text = bundle.aiAssistanceDetails ?? '';
      _artifactUrlsController.text = bundle.artifactUrls.join('\n');
      _versionHistory = bundle.versionHistory;
    });
  }

  Future<void> _saveProofBundle() async {
    setState(() => _isSavingProofBundle = true);
    final MissionService missionService = context.read<MissionService>();
    final List<String> artifactUrls = _artifactUrlsController.text
        .split(RegExp(r'\r?\n'))
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
    final MissionProofBundle? bundle =
        await missionService.saveProofBundleDraft(
      missionId: widget.mission.id,
      explainItBack: _explainItBackController.text,
      oralCheckResponse: _oralCheckController.text,
      miniRebuildPlan: _miniRebuildController.text,
      aiAssistanceUsed: _aiAssistanceUsed,
      aiAssistanceDetails: _aiDisclosureController.text,
      artifactUrls: artifactUrls,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isSavingProofBundle = false;
      _versionHistory = bundle?.versionHistory ?? _versionHistory;
    });
    final String message = bundle == null
        ? _tMissions(context, 'Unable to save proof bundle right now')
        : _tMissions(
            context,
            missionService.isOnline
                ? 'Proof bundle saved'
                : 'Proof bundle queued to sync',
          );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            bundle == null ? ScholesaColors.error : ScholesaColors.success,
      ),
    );
  }

  Future<void> _saveCheckpoint() async {
    final String summary = _checkpointSummaryController.text.trim();
    if (summary.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              _tMissions(context, 'Add a version checkpoint summary first')),
        ),
      );
      return;
    }
    setState(() => _isSavingCheckpoint = true);
    final MissionService missionService = context.read<MissionService>();
    final MissionProofBundle? bundle =
        await missionService.addVersionCheckpoint(
      missionId: widget.mission.id,
      summary: summary,
      artifactNote: _checkpointArtifactController.text,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isSavingCheckpoint = false;
      _checkpointSummaryController.clear();
      _checkpointArtifactController.clear();
      _versionHistory = bundle?.versionHistory ?? _versionHistory;
    });
  }

  String _formatCheckpointTimestamp(DateTime? value) {
    if (value == null) {
      return _tMissions(context, 'Saved just now');
    }
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  Widget _buildProofOfLearningSection(BuildContext context, Mission mission) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _pillarColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _pillarColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.verified_outlined, color: _pillarColor),
              const SizedBox(width: 8),
              Text(
                _tMissions(context, 'Proof of Learning'),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _pillarColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _tMissions(
              context,
              'Capture an explain-it-back, version history, oral check, mini-rebuild, and AI-use disclosure before review.',
            ),
            style: TextStyle(color: context.schTextSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          Text(
            _tMissions(context, 'AI Use Disclosure'),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _tMissions(
              context,
              'Declare whether AI supported this mission so your review and portfolio stay trustworthy.',
            ),
            style: TextStyle(color: context.schTextSecondary, height: 1.4),
          ),
          const SizedBox(height: 8),
          RadioListTile<bool>(
            value: false,
            groupValue: _aiAssistanceUsed,
            onChanged: (bool? value) {
              setState(() {
                _aiAssistanceUsed = value;
                _aiDisclosureController.clear();
              });
            },
            title: Text(
                _tMissions(context, 'No AI support used for this mission')),
            contentPadding: EdgeInsets.zero,
          ),
          RadioListTile<bool>(
            value: true,
            groupValue: _aiAssistanceUsed,
            onChanged: (bool? value) {
              setState(() {
                _aiAssistanceUsed = value;
              });
            },
            title:
                Text(_tMissions(context, 'AI supported part of this mission')),
            subtitle: Text(
              _tMissions(
                context,
                'Describe what AI helped with and what remained your own reasoning.',
              ),
            ),
            contentPadding: EdgeInsets.zero,
          ),
          if (_aiAssistanceUsed == true) ...<Widget>[
            const SizedBox(height: 8),
            TextField(
              controller: _aiDisclosureController,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: _tMissions(context, 'AI support details'),
                helperText: _tMissions(
                  context,
                  'Example: AI helped me brainstorm, but I wrote the final explanation and tested the solution myself.',
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _explainItBackController,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: _tMissions(context, 'Explain-it-back summary'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _oralCheckController,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: _tMissions(context, 'Oral check reflection'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _miniRebuildController,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: _tMissions(context, 'Mini-rebuild plan'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _artifactUrlsController,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: _tMissions(context, 'Artifact links (one per line)'),
              helperText: _tMissions(
                context,
                'Paste direct links to learner artifacts that should travel with this review.',
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _tMissions(context, 'Version History'),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          if (_versionHistory.isEmpty)
            Text(
              _tMissions(context, 'No version checkpoints yet'),
              style: TextStyle(color: context.schTextSecondary),
            )
          else
            ..._versionHistory.reversed.map(
              (MissionProofCheckpoint checkpoint) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.history_rounded, color: _pillarColor),
                title: Text(checkpoint.summary),
                subtitle:
                    Text(_formatCheckpointTimestamp(checkpoint.createdAt)),
                trailing: checkpoint.artifactNote?.isNotEmpty == true
                    ? const Icon(Icons.attach_file_rounded, size: 18)
                    : null,
              ),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _checkpointSummaryController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: _tMissions(context, 'Version checkpoint summary'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _checkpointArtifactController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: _tMissions(context, 'Artifact note (optional)'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSavingCheckpoint ? null : _saveCheckpoint,
                  icon: _isSavingCheckpoint
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.history_toggle_off_rounded),
                  label: Text(_tMissions(context, 'Save Checkpoint')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSavingProofBundle ? null : _saveProofBundle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pillarColor,
                    foregroundColor: Colors.white,
                  ),
                  icon: _isSavingProofBundle
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_tMissions(context, 'Save Proof Bundle')),
                ),
              ),
            ],
          ),
          if (mission.progress == 1.0 && !_proofBundleReady) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              _tMissions(
                context,
                'Complete the proof bundle, version history, and AI-use disclosure before submitting this mission.',
              ),
              style: TextStyle(
                color: ScholesaColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MissionService>(
      builder: (BuildContext context, MissionService service, _) {
        final Mission mission =
            service.getMissionById(widget.mission.id) ?? widget.mission;

        final AppState appState = context.read<AppState>();
        final FirestoreService firestoreService =
            context.read<FirestoreService>();
        final String learnerId = (appState.userId ?? '').trim();
        final String siteId = (appState.activeSiteId ?? '').trim();

        final Widget sheetBody = AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            top: false,
            child: FractionallySizedBox(
              heightFactor: 0.85,
              alignment: Alignment.bottomCenter,
              child: Container(
                decoration: BoxDecoration(
                  color: _highContrastEnabled ? Colors.black : Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Align(
                              alignment: Alignment.center,
                              child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: _highContrastEnabled
                                      ? Colors.white54
                                      : Colors.grey[300],
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(
                              Icons.close_rounded,
                              color: _highContrastEnabled
                                  ? Colors.white
                                  : Colors.grey[700],
                            ),
                            label: Text(
                                _tMissions(context, 'Close mission details')),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (_keyboardOnlyEnabled) ...<Widget>[
                              _buildKeyboardOnlyBanner(context),
                              const SizedBox(height: 20),
                            ],
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
                                        color:
                                            _pillarColor.withValues(alpha: 0.3),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _pillarColor.withValues(
                                              alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
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
                                            color: _pillarColor.withValues(
                                                alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(12),
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
                              _buildProofOfLearningSection(context, mission),
                              const SizedBox(height: 24),
                            ],

                            // Educator feedback
                            if (mission.educatorFeedback != null) ...<Widget>[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: ScholesaColors.success
                                      .withValues(alpha: 0.1),
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
                                            color: ScholesaColors.success,
                                            size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          _tMissions(
                                              context, 'Educator Feedback'),
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

                            // AI Help Section
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
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              '${_tMissions(context, 'Started')}: ${mission.title}'),
                                          backgroundColor:
                                              ScholesaColors.success,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(_tMissions(context,
                                              'Unable to start mission right now')),
                                          backgroundColor: Colors.red,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _pillarColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
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
                                  onPressed: !_proofBundleReady
                                      ? null
                                      : () async {
                                          final MissionService missionService =
                                              context.read<MissionService>();
                                          final NavigatorState navigator =
                                              Navigator.of(context);
                                          final ScaffoldMessengerState
                                              messenger =
                                              ScaffoldMessenger.of(context);
                                          await _saveProofBundle();
                                          TelemetryService.instance.logEvent(
                                            event: 'cta.clicked',
                                            metadata: <String, dynamic>{
                                              'cta':
                                                  'missions_submit_for_review',
                                              'mission_id': mission.id,
                                            },
                                          );
                                          final String? submissionId =
                                              await missionService
                                                  .submitMission(mission.id);

                                          if (submissionId == null) {
                                            if (!context.mounted) return;
                                            messenger.showSnackBar(
                                              SnackBar(
                                                content: Text(_tMissions(
                                                    context,
                                                    'Unable to submit mission right now')),
                                                backgroundColor:
                                                    ScholesaColors.error,
                                              ),
                                            );
                                            return;
                                          }

                                          TelemetryService.instance.logEvent(
                                            event: 'mission.attempt.submitted',
                                            metadata: <String, dynamic>{
                                              'mission_id': mission.id,
                                              'submission_id': submissionId,
                                              'mission_status':
                                                  mission.status.name,
                                              'progress': mission.progress,
                                            },
                                          );
                                          if (!context.mounted) return;
                                          navigator.pop();
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  '${_tMissions(context, 'Submitted')}: ${mission.title}'),
                                              backgroundColor:
                                                  ScholesaColors.success,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          );
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: ScholesaColors.success,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
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
                                        _tMissions(
                                            context, 'Submit for Review'),
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
              ),
            ),
          ),
        );

        if (learnerId.isEmpty || siteId.isEmpty) {
          return sheetBody;
        }

        return _MissionRuntimeScope(
          learnerId: learnerId,
          siteId: siteId,
          firestoreService: firestoreService,
          child: sheetBody,
        );
      },
    );
  }

  Widget _buildStudyFlowSection(BuildContext context, Mission mission) {
    final MissionService missionService = context.read<MissionService>();
    final List<String> recommendedMissionTitles = mission
        .recommendedInterleavingMissionIds
        .map((String missionId) =>
            missionService.getMissionById(missionId)?.title)
        .whereType<String>()
        .toList();

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
              const SizedBox(height: 4),
              Text(
                '${_tMissions(context, 'Queue state')}: ${_tMissions(context, mission.fsrsQueueState.label)}',
                style: TextStyle(color: context.schTextSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              _keyboardOnlyEnabled
                  ? Column(
                      children: FsrsRating.values
                          .map(
                            (FsrsRating rating) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _isUpdatingStudyAction
                                      ? null
                                      : () => _handleStudyAction(
                                            action: () => context
                                                .read<MissionService>()
                                                .rateFsrsReview(
                                                  mission.id,
                                                  rating: rating,
                                                ),
                                            successMessage: _tMissions(
                                                context, 'Review saved'),
                                          ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _pillarColor,
                                    foregroundColor: Colors.white,
                                  ),
                                  child:
                                      Text(_tMissions(context, rating.label)),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    )
                  : Wrap(
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
                              backgroundColor:
                                  _pillarColor.withValues(alpha: 0.12),
                            ),
                          )
                          .toList(),
                    ),
              const SizedBox(height: 12),
              _keyboardOnlyEnabled
                  ? Column(
                      children: <Widget>[
                        _buildKeyboardActionButton(
                          label: _tMissions(context, 'Snooze 1 day'),
                          icon: Icons.snooze_rounded,
                          onPressed: _isUpdatingStudyAction
                              ? null
                              : () => _handleStudyAction(
                                    action: () => context
                                        .read<MissionService>()
                                        .snoozeFsrsQueue(mission.id),
                                    successMessage:
                                        _tMissions(context, 'Queue snoozed'),
                                  ),
                        ),
                        _buildKeyboardActionButton(
                          label: _tMissions(context, 'Review in 3 days'),
                          icon: Icons.event_repeat_rounded,
                          onPressed: _isUpdatingStudyAction
                              ? null
                              : () => _handleStudyAction(
                                    action: () => context
                                        .read<MissionService>()
                                        .rescheduleFsrsQueue(mission.id),
                                    successMessage: _tMissions(
                                        context, 'Review rescheduled'),
                                  ),
                        ),
                        _buildKeyboardActionButton(
                          label: _tMissions(context, 'Suspend review queue'),
                          icon: Icons.pause_circle_outline_rounded,
                          onPressed: _isUpdatingStudyAction
                              ? null
                              : () => _handleStudyAction(
                                    action: () => context
                                        .read<MissionService>()
                                        .suspendFsrsQueue(mission.id),
                                    successMessage:
                                        _tMissions(context, 'Review suspended'),
                                  ),
                        ),
                      ],
                    )
                  : Wrap(
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
                                    successMessage: _tMissions(
                                        context, 'Review rescheduled'),
                                  ),
                          icon: const Icon(Icons.event_repeat_rounded),
                          label: Text(_tMissions(context, 'Review in 3 days')),
                        ),
                        OutlinedButton.icon(
                          onPressed: _isUpdatingStudyAction
                              ? null
                              : () => _handleStudyAction(
                                    action: () => context
                                        .read<MissionService>()
                                        .suspendFsrsQueue(mission.id),
                                    successMessage:
                                        _tMissions(context, 'Review suspended'),
                                  ),
                          icon: const Icon(Icons.pause_circle_outline_rounded),
                          label:
                              Text(_tMissions(context, 'Suspend review queue')),
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
              const SizedBox(height: 4),
              Text(
                '${_tMissions(context, 'Confusability band')}: ${_tMissions(context, _confusabilityLabel(mission.confusabilityBand))}',
                style: TextStyle(color: context.schTextSecondary, fontSize: 12),
              ),
              if (recommendedMissionTitles.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  '${_tMissions(context, 'Recommended mix')}: ${recommendedMissionTitles.join(' • ')}',
                  style: TextStyle(
                    color: context.schTextSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _keyboardOnlyEnabled
                  ? Column(
                      children: InterleavingMode.values
                          .map(
                            (InterleavingMode mode) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: _isUpdatingStudyAction
                                      ? null
                                      : () => _handleStudyAction(
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
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: mission.interleavingMode ==
                                            mode
                                        ? _pillarColor.withValues(alpha: 0.12)
                                        : null,
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child:
                                        Text(_tMissions(context, mode.label)),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    )
                  : Wrap(
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
                              selectedColor:
                                  _pillarColor.withValues(alpha: 0.18),
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
                    ? '${_tMissions(context, 'Fade stage')}: ${mission.workedExampleFadeStage} • ${_tMissions(context, mission.workedExamplePromptLevel.label)}'
                    : _tMissions(
                        context,
                        'Reveal a worked example before you try the next step alone.',
                      ),
                style: TextStyle(color: context.schTextSecondary, height: 1.4),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: _keyboardOnlyEnabled ? double.infinity : null,
                child: FilledButton.icon(
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
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKeyboardOnlyBanner(BuildContext context) {
    final Color textColor =
        _highContrastEnabled ? Colors.white : Colors.black87;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _highContrastEnabled
            ? Colors.white12
            : _pillarColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _highContrastEnabled
              ? Colors.white70
              : _pillarColor.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _tMissions(context, 'Keyboard-only mission controls'),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _tMissions(
              context,
              'Large buttons are shown below so you can review, switch study mode, and close this sheet without drag gestures.',
            ),
            style: TextStyle(color: textColor, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyboardActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Align(
            alignment: Alignment.centerLeft,
            child: Text(label),
          ),
        ),
      ),
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

  String _confusabilityLabel(String band) {
    switch (band) {
      case 'high':
        return 'High';
      case 'medium':
        return 'Medium';
      case 'low':
      default:
        return 'Low';
    }
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
                    key: const Key('mission-ai-toggle'),
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
    final Color accentColor = ScholesaColors.learner;
    final LearningRuntimeProvider? runtime =
        context.read<LearningRuntimeProvider?>();
    if (runtime == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.wifi_tethering_error_rounded,
                  color: accentColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _tMissions(context, 'AI help is temporarily unavailable'),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: context.schTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _tMissions(
                context,
                'Keep working on this mission while AI reconnects.',
              ),
              style: TextStyle(color: context.schTextSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              _tMissions(
                context,
                'Try the next step below or reopen AI help in a moment.',
              ),
              style: TextStyle(color: context.schTextSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const Key('mission-ai-continue'),
              onPressed: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: <String, dynamic>{
                    'cta': 'mission_ai_continue_without_ai',
                    'mission_id': widget.mission.id,
                    'surface': 'mission_detail_sheet',
                  },
                );
                setState(() => _showAiCoach = false);
              },
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(_tMissions(context, 'Continue this mission')),
            ),
          ],
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

class _MissionRuntimeScope extends StatefulWidget {
  const _MissionRuntimeScope({
    required this.learnerId,
    required this.siteId,
    required this.firestoreService,
    required this.child,
  });

  final String learnerId;
  final String siteId;
  final FirestoreService firestoreService;
  final Widget child;

  @override
  State<_MissionRuntimeScope> createState() => _MissionRuntimeScopeState();
}

class _MissionRuntimeScopeState extends State<_MissionRuntimeScope> {
  late final LearningRuntimeProvider _runtime;

  @override
  void initState() {
    super.initState();
    _runtime = LearningRuntimeProvider(
      siteId: widget.siteId,
      learnerId: widget.learnerId,
      gradeBand: GradeBand.g4_6,
      firestore: widget.firestoreService.firestore,
    );
    _runtime.startListening();
  }

  @override
  void dispose() {
    _runtime.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LearningRuntimeProvider>.value(
      value: _runtime,
      child: AnimatedBuilder(
        animation: _runtime,
        builder: (BuildContext context, Widget? child) {
          return MvlGateWidget(
            runtime: _runtime,
            child: child ?? const SizedBox.shrink(),
          );
        },
        child: widget.child,
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
