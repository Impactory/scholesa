import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../i18n/workflow_surface_i18n.dart';
import '../../services/telemetry_service.dart';
import '../../services/firestore_service.dart';
import '../../ui/auth/global_session_menu.dart';
import '../../ui/theme/scholesa_theme.dart';
import '../../runtime/runtime.dart';
import '../../i18n/bos_coaching_i18n.dart';
import '../../auth/app_state.dart';
import 'educator_service.dart';

String _tEducatorMissionPlans(BuildContext context, String input) {
  return WorkflowSurfaceI18n.text(context, input);
}

typedef EducatorMissionPlansLoader = Future<List<Map<String, dynamic>>> Function(
  BuildContext context,
);

typedef EducatorMissionPlanCreator = Future<bool> Function(
  BuildContext context, {
  required String title,
  required String description,
  required String pillar,
  required String difficulty,
  required List<String> evidenceDefaults,
  required List<String> orderedSteps,
});

typedef EducatorMissionPlanUpdater = Future<bool> Function(
  BuildContext context, {
  required String missionId,
  required _PlanStatus currentStatus,
  required String title,
  required String description,
  required String pillar,
  required String difficulty,
  required List<String> evidenceDefaults,
  required List<String> orderedSteps,
});

typedef EducatorMissionPlanArchiver = Future<bool> Function(
  BuildContext context, {
  required String missionId,
});

/// Educator mission plans page for planning and managing missions
/// Based on docs/11_MISSIONS_CHALLENGES_SPEC.md

enum _PlanStatus { draft, active, archived }

class _MissionPlan {
  const _MissionPlan({
    required this.id,
    required this.title,
    required this.description,
    required this.pillar,
    required this.duration,
    required this.targetGrade,
    required this.difficulty,
    required this.status,
    required this.assignedSessions,
    required this.completedBy,
    required this.evidenceDefaults,
    required this.lessonSteps,
  });

  final String id;
  final String title;
  final String description;
  final String pillar;
  final String duration;
  final String targetGrade;
  final String difficulty;
  final _PlanStatus status;
  final int assignedSessions;
  final int completedBy;
  final List<String> evidenceDefaults;
  final List<String> lessonSteps;
}

class _LessonStepDraft {
  _LessonStepDraft({required this.id, required String title})
      : controller = TextEditingController(text: title);

  final String id;
  final TextEditingController controller;
}

class EducatorMissionPlansPage extends StatefulWidget {
  const EducatorMissionPlansPage({
    this.missionPlansLoader,
    this.missionPlanCreator,
    this.missionPlanUpdater,
    this.missionPlanArchiver,
    super.key,
  });

  final EducatorMissionPlansLoader? missionPlansLoader;
  final EducatorMissionPlanCreator? missionPlanCreator;
  final EducatorMissionPlanUpdater? missionPlanUpdater;
  final EducatorMissionPlanArchiver? missionPlanArchiver;

  @override
  State<EducatorMissionPlansPage> createState() =>
      _EducatorMissionPlansPageState();
}

class _EducatorMissionPlansPageState extends State<EducatorMissionPlansPage> {
  List<_MissionPlan> _missionPlans = <_MissionPlan>[];
  bool _isLoading = false;
  String _pillarFilter = 'All Pillars';
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadMissionPlans();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EducatorService>().loadLearners();
    });
  }

  List<_MissionPlan> get _filteredMissionPlans {
    if (_pillarFilter == 'All Pillars') {
      return _missionPlans;
    }
    return _missionPlans
        .where((_MissionPlan mission) => mission.pillar == _pillarFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = _isLoading
        ? Center(
            child: Text(
              _tEducatorMissionPlans(context, 'Loading...'),
              style: const TextStyle(color: ScholesaColors.textSecondary),
            ),
          )
        : _loadError != null && _filteredMissionPlans.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: _buildLoadErrorState(_loadError!),
              )
        : _filteredMissionPlans.isEmpty
            ? Center(
                child: Text(
                  _tEducatorMissionPlans(context, 'No missions yet'),
                  style: const TextStyle(color: ScholesaColors.textSecondary),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _filteredMissionPlans.length,
                itemBuilder: (BuildContext context, int index) {
                  return _buildMissionPlanCard(_filteredMissionPlans[index]);
                },
              );

    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: Text(_tEducatorMissionPlans(context, 'Mission Plans')),
        backgroundColor: ScholesaColors.educatorGradient.colors.first,
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () => _showFilterDialog(),
          ),
          const SessionMenuButton(
            foregroundColor: Colors.white,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateMissionDialog(),
        backgroundColor: ScholesaColors.educatorGradient.colors.first,
        icon: const Icon(Icons.add_rounded),
        label: Text(_tEducatorMissionPlans(context, 'New Mission')),
      ),
      body: Consumer<EducatorService>(
        builder: (BuildContext context, EducatorService service, _) {
          return Column(
            children: <Widget>[
              AiContextCoachSection(
                title: _tEducatorMissionPlans(
                    context, 'MiloOS Mission Planning Help'),
                subtitle: _tEducatorMissionPlans(
                  context,
                  'See support ideas while designing missions for each learner',
                ),
                module: 'educator_mission_plans',
                surface: 'mission_planning',
                actorRole: UserRole.educator,
                accentColor: ScholesaColors.educator,
                conceptTags: const <String>[
                  'mission_design',
                  'curriculum_planning',
                  'individual_learning_path',
                ],
              ),
              if (service.learners.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: BosLearnerLoopInsightsCard(
                    title: BosCoachingI18n.sessionLoopTitle(context),
                    subtitle: BosCoachingI18n.sessionLoopSubtitle(context),
                    emptyLabel: BosCoachingI18n.sessionLoopEmpty(context),
                    learnerId: service.learners.first.id,
                    learnerName: service.learners.first.name,
                    accentColor: ScholesaColors.educator,
                  ),
                ),
              if (_loadError != null && _missionPlans.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _buildStaleDataBanner(_loadError!),
                ),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMissionPlanCard(_MissionPlan plan) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showMissionDetails(plan),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _buildPillarIcon(plan.pillar),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          plan.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: ScholesaColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _tEducatorMissionPlans(context, plan.pillar),
                          style: TextStyle(
                            fontSize: 12,
                            color: _getPillarColor(plan.pillar),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (plan.description.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 6),
                          Text(
                            plan.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: ScholesaColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _buildStatusChip(plan.status),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _buildMetaChip(
                    Icons.stacked_bar_chart_rounded,
                    _difficultyLabel(plan.difficulty),
                  ),
                  _buildMetaChip(
                    Icons.checklist_rtl_rounded,
                    '${plan.lessonSteps.length} ${_tEducatorMissionPlans(context, 'Steps')}',
                  ),
                  _buildMetaChip(
                    Icons.verified_outlined,
                    '${plan.evidenceDefaults.length} ${_tEducatorMissionPlans(context, 'Evidence defaults')}',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  _buildInfoItem(Icons.timer_outlined, plan.duration),
                  _buildInfoItem(Icons.school_outlined,
                      '${_tEducatorMissionPlans(context, 'Grade')} ${plan.targetGrade}'),
                  _buildInfoItem(Icons.calendar_today_outlined,
                      '${plan.assignedSessions} ${_tEducatorMissionPlans(context, 'sessions')}'),
                  _buildInfoItem(Icons.check_circle_outline,
                      '${plan.completedBy} ${_tEducatorMissionPlans(context, 'done')}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPillarIcon(String pillar) {
    IconData icon;
    Color color = _getPillarColor(pillar);

    switch (pillar) {
      case 'Future Skills':
        icon = Icons.psychology_rounded;
      case 'Leadership & Agency':
        icon = Icons.groups_rounded;
      case 'Impact & Innovation':
        icon = Icons.lightbulb_rounded;
      default:
        icon = Icons.star_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Color _getPillarColor(String pillar) {
    switch (pillar) {
      case 'Future Skills':
        return Colors.blue;
      case 'Leadership & Agency':
        return Colors.purple;
      case 'Impact & Innovation':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatusChip(_PlanStatus status) {
    Color color;
    String label;
    switch (status) {
      case _PlanStatus.draft:
        color = Colors.grey;
        label = _tEducatorMissionPlans(context, 'Draft');
      case _PlanStatus.active:
        color = Colors.green;
        label = _tEducatorMissionPlans(context, 'Active');
      case _PlanStatus.archived:
        color = Colors.orange;
        label = _tEducatorMissionPlans(context, 'Archived');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: ScholesaColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: ScholesaColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildMetaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ScholesaColors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ScholesaColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: ScholesaColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: ScholesaColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{
        'cta': 'educator_mission_plans_open_filter'
      },
    );
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        String selected = _pillarFilter;
        return StatefulBuilder(
          builder: (BuildContext context,
              void Function(void Function()) setLocalState) {
            return AlertDialog(
              backgroundColor: ScholesaColors.surface,
              title: Text(_tEducatorMissionPlans(context, 'Filter Missions')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _buildFilterOption(
                    label: _tEducatorMissionPlans(context, 'All Pillars'),
                    selected: selected,
                    onChanged: (String value) {
                      setLocalState(() => selected = value);
                    },
                  ),
                  _buildFilterOption(
                    label: _tEducatorMissionPlans(context, 'Future Skills'),
                    selected: selected,
                    onChanged: (String value) {
                      setLocalState(() => selected = value);
                    },
                  ),
                  _buildFilterOption(
                    label:
                        _tEducatorMissionPlans(context, 'Leadership & Agency'),
                    selected: selected,
                    onChanged: (String value) {
                      setLocalState(() => selected = value);
                    },
                  ),
                  _buildFilterOption(
                    label:
                        _tEducatorMissionPlans(context, 'Impact & Innovation'),
                    selected: selected,
                    onChanged: (String value) {
                      setLocalState(() => selected = value);
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: const <String, dynamic>{
                        'cta': 'educator_mission_plans_close_filter'
                      },
                    );
                    Navigator.pop(context);
                  },
                  child: Text(_tEducatorMissionPlans(context, 'Close')),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _pillarFilter = selected);
                    Navigator.pop(context);
                  },
                  child: Text(_tEducatorMissionPlans(context, 'Apply')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFilterOption({
    required String label,
    required String selected,
    required ValueChanged<String> onChanged,
  }) {
    return ListTile(
      onTap: () => onChanged(label),
      leading: Icon(
        selected == label
            ? Icons.radio_button_checked
            : Icons.radio_button_unchecked,
      ),
      title: Text(label),
    );
  }

  void _showMissionDetails(_MissionPlan plan) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'educator_mission_plans_open_details',
        'plan_id': plan.id
      },
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ScholesaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
            Text(
              plan.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _tEducatorMissionPlans(context, plan.pillar),
              style: TextStyle(
                fontSize: 14,
                color: _getPillarColor(plan.pillar),
                fontWeight: FontWeight.w500,
              ),
            ),
            if (plan.description.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Text(
                plan.description,
                style: const TextStyle(
                  fontSize: 14,
                  color: ScholesaColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _buildMetaChip(
                  Icons.stacked_bar_chart_rounded,
                  _difficultyLabel(plan.difficulty),
                ),
                _buildMetaChip(
                  Icons.checklist_rtl_rounded,
                  '${plan.lessonSteps.length} ${_tEducatorMissionPlans(context, 'Steps')}',
                ),
                _buildMetaChip(
                  Icons.verified_outlined,
                  '${plan.evidenceDefaults.length} ${_tEducatorMissionPlans(context, 'Evidence defaults')}',
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              _tEducatorMissionPlans(context, 'Evidence defaults'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: plan.evidenceDefaults.isEmpty
                  ? <Widget>[
                      Text(
                        _tEducatorMissionPlans(
                          context,
                          'No evidence defaults selected',
                        ),
                        style: const TextStyle(
                          color: ScholesaColors.textSecondary,
                        ),
                      ),
                    ]
                  : plan.evidenceDefaults
                      .map((String defaultKey) => _buildMetaChip(
                            Icons.task_alt_rounded,
                            _evidenceDefaultLabel(defaultKey),
                          ))
                      .toList(),
            ),
            const SizedBox(height: 20),
            Text(
              _tEducatorMissionPlans(context, 'Lesson flow'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Column(
              children: plan.lessonSteps.asMap().entries.map(
                (MapEntry<int, String> entry) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor:
                          ScholesaColors.educator.withValues(alpha: 0.15),
                      foregroundColor: ScholesaColors.educator,
                      child: Text('${entry.key + 1}'),
                    ),
                    title: Text(entry.value),
                  );
                },
              ).toList(),
            ),
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: <String, dynamic>{
                          'cta': 'educator_mission_plans_edit_plan',
                          'plan_id': plan.id,
                        },
                      );
                      Navigator.pop(context);
                      _showCreateMissionDialog(plan: plan);
                    },
                    child: Text(_tEducatorMissionPlans(context, 'Edit')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmArchiveMission(plan);
                    },
                    icon: const Icon(Icons.archive_outlined),
                    label: Text(
                      _tEducatorMissionPlans(
                        context,
                        plan.status == _PlanStatus.archived
                            ? 'Archived'
                            : 'Archive',
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: plan.status == _PlanStatus.archived
                          ? Colors.grey.shade300
                          : Colors.orange,
                      foregroundColor: plan.status == _PlanStatus.archived
                          ? Colors.black54
                          : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            if (plan.status == _PlanStatus.archived) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _tEducatorMissionPlans(
                  context,
                  'Archived mission plans stay visible for reference but can no longer be assigned.',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: ScholesaColors.textSecondary,
                ),
              ),
            ],
            if (plan.status != _PlanStatus.archived) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _tEducatorMissionPlans(
                  context,
                  'Archive completed or outdated mission plans to remove them from active planning.',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: ScholesaColors.textSecondary,
                ),
              ),
            ],
            ],
          ),
        ),
      ),
    );
  }

  void _confirmArchiveMission(_MissionPlan plan) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: ScholesaColors.surface,
          title: Text(_tEducatorMissionPlans(context, 'Archive mission plan?')),
          content: Text(
            _tEducatorMissionPlans(
              context,
              'Archived mission plans stay visible for reference but are removed from active planning.',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_tEducatorMissionPlans(context, 'Cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                final bool archived = await _archiveMission(plan.id);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      archived
                          ? _tEducatorMissionPlans(
                              context,
                              'Mission archived',
                            )
                          : _tEducatorMissionPlans(
                              context,
                              'Failed to archive mission',
                            ),
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: Text(_tEducatorMissionPlans(context, 'Archive')),
            ),
          ],
        );
      },
    );
  }

  void _showCreateMissionDialog({_MissionPlan? plan}) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': plan == null
            ? 'educator_mission_plans_open_create_dialog'
            : 'educator_mission_plans_open_edit_dialog',
        if (plan != null) 'plan_id': plan.id,
      },
    );
    final bool isEditing = plan != null;
    final TextEditingController titleController = TextEditingController(
      text: plan?.title ?? '',
    );
    final TextEditingController descriptionController = TextEditingController(
      text: plan?.description ?? '',
    );
    String selectedPillar = plan?.pillar ?? 'Future Skills';
    String selectedDifficulty = plan?.difficulty ?? 'beginner';
    final Set<String> evidenceDefaults = <String>{
      ...(plan?.evidenceDefaults ?? const <String>[
        'explain_it_back',
        'reflection_note',
      ]),
    };
    final List<String> initialSteps =
        plan?.lessonSteps.isNotEmpty == true
            ? plan!.lessonSteps
            : const <String>[
                'Launch challenge',
                'Guided practice',
                'Evidence capture',
              ];
    final List<_LessonStepDraft> lessonSteps = initialSteps
        .asMap()
        .entries
        .map(
          (MapEntry<int, String> entry) => _LessonStepDraft(
            id: 'step-${entry.key}',
            title: entry.value,
          ),
        )
        .toList();

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context,
                void Function(void Function()) setLocalState) =>
            AlertDialog(
          backgroundColor: ScholesaColors.surface,
          title: Text(
            _tEducatorMissionPlans(
              context,
              isEditing ? 'Edit Mission Plan' : 'Create New Mission',
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: _tEducatorMissionPlans(context, 'Mission Title'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText:
                        _tEducatorMissionPlans(context, 'Mission Description'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedPillar,
                  decoration: InputDecoration(
                    labelText: _tEducatorMissionPlans(context, 'Pillar'),
                    border: const OutlineInputBorder(),
                  ),
                  items: <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                        value: 'Future Skills',
                        child: Text(
                            _tEducatorMissionPlans(context, 'Future Skills'))),
                    DropdownMenuItem<String>(
                        value: 'Leadership & Agency',
                        child: Text(_tEducatorMissionPlans(
                            context, 'Leadership & Agency'))),
                    DropdownMenuItem<String>(
                        value: 'Impact & Innovation',
                        child: Text(_tEducatorMissionPlans(
                            context, 'Impact & Innovation'))),
                  ],
                  onChanged: (String? value) {
                    if (value != null) {
                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: <String, dynamic>{
                          'cta': 'educator_mission_plans_create_select_pillar',
                          'pillar': value,
                        },
                      );
                      setLocalState(() => selectedPillar = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedDifficulty,
                  decoration: InputDecoration(
                    labelText:
                        _tEducatorMissionPlans(context, 'Lesson difficulty'),
                    border: const OutlineInputBorder(),
                  ),
                  items: <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                      value: 'beginner',
                      child: Text(
                        _tEducatorMissionPlans(context, 'Beginner'),
                      ),
                    ),
                    DropdownMenuItem<String>(
                      value: 'intermediate',
                      child: Text(
                        _tEducatorMissionPlans(context, 'Intermediate'),
                      ),
                    ),
                    DropdownMenuItem<String>(
                      value: 'advanced',
                      child: Text(
                        _tEducatorMissionPlans(context, 'Advanced'),
                      ),
                    ),
                  ],
                  onChanged: (String? value) {
                    if (value != null) {
                      setLocalState(() => selectedDifficulty = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _tEducatorMissionPlans(context, 'Evidence defaults'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildEvidenceToggle(
                  context: context,
                  value: evidenceDefaults.contains('explain_it_back'),
                  label: 'Explain-it-back check',
                  onChanged: (bool enabled) {
                    setLocalState(() {
                      if (enabled) {
                        evidenceDefaults.add('explain_it_back');
                      } else {
                        evidenceDefaults.remove('explain_it_back');
                      }
                    });
                  },
                ),
                _buildEvidenceToggle(
                  context: context,
                  value: evidenceDefaults.contains('artifact_capture'),
                  label: 'Artifact capture',
                  onChanged: (bool enabled) {
                    setLocalState(() {
                      if (enabled) {
                        evidenceDefaults.add('artifact_capture');
                      } else {
                        evidenceDefaults.remove('artifact_capture');
                      }
                    });
                  },
                ),
                _buildEvidenceToggle(
                  context: context,
                  value: evidenceDefaults.contains('reflection_note'),
                  label: 'Reflection note',
                  onChanged: (bool enabled) {
                    setLocalState(() {
                      if (enabled) {
                        evidenceDefaults.add('reflection_note');
                      } else {
                        evidenceDefaults.remove('reflection_note');
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _tEducatorMissionPlans(context, 'Lesson flow'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      key: const ValueKey<String>('mission_step_add'),
                      onPressed: () {
                        setLocalState(() {
                          lessonSteps.add(
                            _LessonStepDraft(
                              id: 'step-${lessonSteps.length}',
                              title: '',
                            ),
                          );
                        });
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: Text(_tEducatorMissionPlans(context, 'Add step')),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Column(
                  children:
                      List<Widget>.generate(lessonSteps.length, (int index) {
                    final _LessonStepDraft draft = lessonSteps[index];
                    return Card(
                      key: ValueKey<String>(draft.id),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            CircleAvatar(
                              radius: 14,
                              child: Text('${index + 1}'),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                key: ValueKey<String>(
                                  'mission_step_field_$index',
                                ),
                                controller: draft.controller,
                                decoration: InputDecoration(
                                  labelText: _tEducatorMissionPlans(
                                    context,
                                    'Lesson step',
                                  ),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              children: <Widget>[
                                IconButton(
                                  key: ValueKey<String>(
                                    'mission_step_up_$index',
                                  ),
                                  tooltip: _tEducatorMissionPlans(
                                    context,
                                    'Move up',
                                  ),
                                  onPressed: index == 0
                                      ? null
                                      : () {
                                          setLocalState(() {
                                            final _LessonStepDraft moved =
                                                lessonSteps.removeAt(index);
                                            lessonSteps.insert(
                                              index - 1,
                                              moved,
                                            );
                                          });
                                        },
                                  icon: const Icon(Icons.arrow_upward_rounded),
                                ),
                                IconButton(
                                  key: ValueKey<String>(
                                    'mission_step_down_$index',
                                  ),
                                  tooltip: _tEducatorMissionPlans(
                                    context,
                                    'Move down',
                                  ),
                                  onPressed: index == lessonSteps.length - 1
                                      ? null
                                      : () {
                                          setLocalState(() {
                                            final _LessonStepDraft moved =
                                                lessonSteps.removeAt(index);
                                            lessonSteps.insert(
                                              index + 1,
                                              moved,
                                            );
                                          });
                                        },
                                  icon: const Icon(
                                    Icons.arrow_downward_rounded,
                                  ),
                                ),
                                IconButton(
                                  key: ValueKey<String>(
                                    'mission_step_delete_$index',
                                  ),
                                  tooltip: _tEducatorMissionPlans(
                                    context,
                                    'Delete step',
                                  ),
                                  onPressed: lessonSteps.length <= 1
                                      ? null
                                      : () {
                                          setLocalState(() {
                                            lessonSteps.removeAt(index);
                                          });
                                        },
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: <String, dynamic>{
                    'cta': isEditing
                        ? 'educator_mission_plans_edit_cancel'
                        : 'educator_mission_plans_create_cancel'
                  },
                );
                Navigator.pop(dialogContext);
              },
              child: Text(_tEducatorMissionPlans(context, 'Cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                final String titleRequiredText = _tEducatorMissionPlans(
                    context, 'Mission title is required');
                final String successText = _tEducatorMissionPlans(
                  context,
                  isEditing
                    ? 'Mission updated'
                    : 'Mission created and added to list',
                );
                final String failedText = _tEducatorMissionPlans(
                  context,
                  isEditing
                    ? 'Failed to update mission'
                    : 'Failed to create mission',
                );
                final String stepRequiredText = _tEducatorMissionPlans(
                    context, 'Add at least one lesson step');
                final String title = titleController.text.trim();
                final List<String> orderedSteps = lessonSteps
                    .map(
                      (_LessonStepDraft draft) => draft.controller.text.trim(),
                    )
                    .where((String stepTitle) => stepTitle.isNotEmpty)
                    .toList();
                if (title.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(titleRequiredText)),
                  );
                  return;
                }
                if (orderedSteps.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(stepRequiredText)),
                  );
                  return;
                }

                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: <String, dynamic>{
                    'cta': isEditing
                        ? 'educator_mission_plans_edit_submit'
                        : 'educator_mission_plans_create_submit',
                    'pillar': selectedPillar,
                    if (plan != null) 'plan_id': plan.id,
                  },
                );

                final bool saved = isEditing
                    ? await _updateMission(
                    missionId: plan.id,
                        currentStatus: plan.status,
                        title: title,
                        description: descriptionController.text.trim(),
                        pillar: selectedPillar,
                        difficulty: selectedDifficulty,
                        evidenceDefaults: evidenceDefaults.toList(),
                        orderedSteps: orderedSteps,
                      )
                    : await _createMission(
                        title: title,
                        description: descriptionController.text.trim(),
                        pillar: selectedPillar,
                        difficulty: selectedDifficulty,
                        evidenceDefaults: evidenceDefaults.toList(),
                        orderedSteps: orderedSteps,
                      );
                if (!mounted || !dialogContext.mounted) return;
                if (saved) {
                  Navigator.pop(dialogContext);
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(saved ? successText : failedText),
                  ),
                );
              },
              child: Text(
                _tEducatorMissionPlans(
                  context,
                  isEditing ? 'Save changes' : 'Create',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadMissionPlans() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final List<_MissionPlan> loaded =
          widget.missionPlansLoader != null
              ? await _loadMissionPlansFromOverride(widget.missionPlansLoader!)
              : await _loadMissionPlansFromFirestore();

      setState(() {
        _missionPlans = loaded;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Failed to load mission plans: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _createMission({
    required String title,
    required String description,
    required String pillar,
    required String difficulty,
    required List<String> evidenceDefaults,
    required List<String> orderedSteps,
  }) async {
    if (widget.missionPlanCreator != null) {
      return widget.missionPlanCreator!(
        context,
        title: title,
        description: description,
        pillar: pillar,
        difficulty: difficulty,
        evidenceDefaults: evidenceDefaults,
        orderedSteps: orderedSteps,
      );
    }

    try {
      final FirebaseFirestore firestore = _resolveFirestore();
      final String? userId = _resolveActorId();
      final DocumentReference<Map<String, dynamic>> createdRef =
          firestore.collection('missions').doc();
      final WriteBatch batch = firestore.batch();
      final List<Map<String, dynamic>> lessonStepMaps = orderedSteps
          .asMap()
          .entries
          .map((MapEntry<int, String> entry) => <String, dynamic>{
                'title': entry.value,
                'order': entry.key,
              })
          .toList();
      batch.set(createdRef, <String, dynamic>{
        'title': title,
        'description': description,
        'pillar': pillar,
        'pillarCode': _pillarCodeFromLabel(pillar),
        'pillarCodes': <String>[_pillarCodeFromLabel(pillar)],
        'duration': '4 weeks',
        'targetGrade': '6-8',
        'difficulty': difficulty,
        'status': 'draft',
        'approvalStatus': 'draft',
        'assignedSessions': 0,
        'completedBy': 0,
        'evidenceDefaults': evidenceDefaults,
        'lessonSteps': orderedSteps,
        'stepCount': orderedSteps.length,
        'bodyJson': <String, dynamic>{
          'lessonBuilder': <String, dynamic>{
            'evidenceDefaults': evidenceDefaults,
            'steps': lessonStepMaps,
          },
          'misconceptionTags': const <String>[],
        },
        if (userId != null && userId.isNotEmpty) 'educatorId': userId,
        if (userId != null && userId.isNotEmpty) 'createdBy': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      for (final MapEntry<int, String> entry in orderedSteps.asMap().entries) {
        batch.set(createdRef.collection('steps').doc(), <String, dynamic>{
          'title': entry.value,
          'order': entry.key,
          'isCompleted': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      final _MissionPlan created = _MissionPlan(
        id: createdRef.id,
        title: title,
        description: description,
        pillar: pillar,
        duration: '4 weeks',
        targetGrade: '6-8',
        difficulty: difficulty,
        status: _PlanStatus.draft,
        assignedSessions: 0,
        completedBy: 0,
        evidenceDefaults: evidenceDefaults,
        lessonSteps: orderedSteps,
      );
      if (mounted) {
        setState(() {
          _missionPlans = <_MissionPlan>[
            created,
            ..._missionPlans
                .where((_MissionPlan plan) => plan.id != created.id),
          ];
        });
      }
      await _loadMissionPlans();
      return true;
    } catch (error) {
      debugPrint('Failed to create mission: $error');
      return false;
    }
  }

  Future<bool> _updateMission({
    required String missionId,
    required _PlanStatus currentStatus,
    required String title,
    required String description,
    required String pillar,
    required String difficulty,
    required List<String> evidenceDefaults,
    required List<String> orderedSteps,
  }) async {
    if (widget.missionPlanUpdater != null) {
      return widget.missionPlanUpdater!(
        context,
        missionId: missionId,
        currentStatus: currentStatus,
        title: title,
        description: description,
        pillar: pillar,
        difficulty: difficulty,
        evidenceDefaults: evidenceDefaults,
        orderedSteps: orderedSteps,
      );
    }

    try {
      final FirebaseFirestore firestore = _resolveFirestore();
      final DocumentReference<Map<String, dynamic>> missionRef =
          firestore.collection('missions').doc(missionId);
      final QuerySnapshot<Map<String, dynamic>> existingSteps =
          await missionRef.collection('steps').get();
      final WriteBatch batch = firestore.batch();
      final List<Map<String, dynamic>> lessonStepMaps = orderedSteps
          .asMap()
          .entries
          .map((MapEntry<int, String> entry) => <String, dynamic>{
                'title': entry.value,
                'order': entry.key,
              })
          .toList();
      batch.update(missionRef, <String, dynamic>{
        'title': title,
        'description': description,
        'pillar': pillar,
        'pillarCode': _pillarCodeFromLabel(pillar),
        'pillarCodes': <String>[_pillarCodeFromLabel(pillar)],
        'difficulty': difficulty,
        'status': _statusKey(currentStatus),
        'evidenceDefaults': evidenceDefaults,
        'lessonSteps': orderedSteps,
        'stepCount': orderedSteps.length,
        'bodyJson': <String, dynamic>{
          'lessonBuilder': <String, dynamic>{
            'evidenceDefaults': evidenceDefaults,
            'steps': lessonStepMaps,
          },
          'misconceptionTags': const <String>[],
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
      for (final QueryDocumentSnapshot<Map<String, dynamic>> stepDoc
          in existingSteps.docs) {
        batch.delete(stepDoc.reference);
      }
      for (final MapEntry<int, String> entry in orderedSteps.asMap().entries) {
        batch.set(missionRef.collection('steps').doc(), <String, dynamic>{
          'title': entry.value,
          'order': entry.key,
          'isCompleted': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      await _loadMissionPlans();
      return true;
    } catch (error) {
      debugPrint('Failed to update mission: $error');
      return false;
    }
  }

  Future<bool> _archiveMission(String missionId) async {
    if (widget.missionPlanArchiver != null) {
      return widget.missionPlanArchiver!(context, missionId: missionId);
    }

    try {
      final FirebaseFirestore firestore = _resolveFirestore();
      await firestore.collection('missions').doc(missionId).update(
        <String, dynamic>{
          'status': 'archived',
          'archivedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
      await _loadMissionPlans();
      return true;
    } catch (error) {
      debugPrint('Failed to archive mission: $error');
      return false;
    }
  }

  Future<List<_MissionPlan>> _loadMissionPlansFromOverride(
    EducatorMissionPlansLoader loader,
  ) async {
    final List<Map<String, dynamic>> items = await loader(context);
    final String? currentUserId = _resolveActorId();
    return items
        .map(_missionPlanFromMap)
        .where((_MissionPlan plan) {
          if (currentUserId == null || currentUserId.isEmpty) return true;
          final Map<String, dynamic>? source = items
              .where((Map<String, dynamic> item) =>
                  (item['id'] as String? ?? '').trim() == plan.id)
              .firstOrNull;
          if (source == null) return true;
          final String? ownerId =
              (source['educatorId'] as String?) ?? (source['createdBy'] as String?);
          if (ownerId == null || ownerId.trim().isEmpty) return true;
          return ownerId.trim() == currentUserId;
        })
        .toList();
  }

  Future<List<_MissionPlan>> _loadMissionPlansFromFirestore() async {
    final FirebaseFirestore firestore = _resolveFirestore();
    Query<Map<String, dynamic>> query = firestore.collection('missions').limit(100);
    try {
      query = query.orderBy('createdAt', descending: true);
    } catch (_) {}

    final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
    final String? currentUserId = _resolveActorId();
    return snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
          final Map<String, dynamic> data = doc.data();
          return _missionPlanFromMap(<String, dynamic>{
            'id': doc.id,
            ...data,
          });
        })
        .where((_MissionPlan plan) {
          if (currentUserId == null || currentUserId.isEmpty) return true;
          final QueryDocumentSnapshot<Map<String, dynamic>>? sourceDoc =
              snapshot.docs.where((d) => d.id == plan.id).firstOrNull;
          final Map<String, dynamic>? data = sourceDoc?.data();
          if (data == null) return true;
          final String? ownerId =
              (data['educatorId'] as String?) ?? (data['createdBy'] as String?);
          if (ownerId == null || ownerId.trim().isEmpty) return true;
          return ownerId.trim() == currentUserId;
        })
        .toList();
  }

  _MissionPlan _missionPlanFromMap(Map<String, dynamic> data) {
    final String pillar = _canonicalPillar(
      data['pillar'] as String? ?? data['pillarCode'] as String?,
    );
    return _MissionPlan(
      id: (data['id'] as String? ?? '').trim(),
      title: (data['title'] as String? ?? '').trim().isEmpty
          ? 'Mission'
          : (data['title'] as String).trim(),
      description: (data['description'] as String? ?? '').trim(),
      pillar: pillar,
      duration: (data['duration'] as String? ?? '4 weeks'),
      targetGrade:
          (data['targetGrade'] as String? ?? data['gradeBand'] as String? ?? '6-8'),
      difficulty: (data['difficulty'] as String? ?? 'beginner').trim(),
      status: _parsePlanStatus(data['status'] as String?),
      assignedSessions: _asInt(data['assignedSessions']) ??
          ((data['sessionIds'] as List<dynamic>?)?.length ?? 0),
      completedBy:
          _asInt(data['completedBy']) ?? _asInt(data['completedCount']) ?? 0,
      evidenceDefaults: List<String>.from(
        data['evidenceDefaults'] as List<dynamic>? ?? const <String>[],
      ),
      lessonSteps: _parseLessonSteps(data),
    );
  }

  Widget _buildLoadErrorState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.error_outline_rounded, color: Colors.redAccent),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Unable to load mission plans',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _loadMissionPlans,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(_tEducatorMissionPlans(context, 'Retry')),
          ),
        ],
      ),
    );
  }

  Widget _buildStaleDataBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _tEducatorMissionPlans(context, 'Showing last loaded mission plans. ') +
                  message,
              style: const TextStyle(color: Color(0xFF92400E)),
            ),
          ),
        ],
      ),
    );
  }

  FirebaseFirestore _resolveFirestore() {
    try {
      return context.read<FirestoreService>().firestore;
    } catch (_) {
      return FirebaseFirestore.instance;
    }
  }

  String? _resolveActorId() {
    try {
      final String educatorId =
          context.read<EducatorService>().educatorId.trim();
      if (educatorId.isNotEmpty) {
        return educatorId;
      }
    } catch (_) {
      // no-op
    }
    try {
      final String? appStateUserId = context.read<AppState>().userId;
      if (appStateUserId != null && appStateUserId.trim().isNotEmpty) {
        return appStateUserId.trim();
      }
    } catch (_) {
      // no-op
    }
    return null;
  }

  Widget _buildEvidenceToggle({
    required BuildContext context,
    required bool value,
    required String label,
    required ValueChanged<bool> onChanged,
  }) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      value: value,
      onChanged: (bool? nextValue) => onChanged(nextValue ?? false),
      title: Text(_tEducatorMissionPlans(context, label)),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  _PlanStatus _parsePlanStatus(String? status) {
    switch ((status ?? '').trim().toLowerCase()) {
      case 'active':
      case 'in_progress':
        return _PlanStatus.active;
      case 'archived':
      case 'completed':
        return _PlanStatus.archived;
      default:
        return _PlanStatus.draft;
    }
  }

  String _canonicalPillar(String? pillar) {
    switch ((pillar ?? '').trim().toLowerCase()) {
      case 'future skills':
      case 'future_skills':
        return 'Future Skills';
      case 'leadership & agency':
      case 'leadership':
        return 'Leadership & Agency';
      case 'impact & innovation':
      case 'impact':
        return 'Impact & Innovation';
      default:
        return 'Future Skills';
    }
  }

  String _pillarCodeFromLabel(String pillar) {
    switch (pillar) {
      case 'Leadership & Agency':
        return 'leadership';
      case 'Impact & Innovation':
        return 'impact';
      default:
        return 'future_skills';
    }
  }

  String _statusKey(_PlanStatus status) {
    switch (status) {
      case _PlanStatus.active:
        return 'active';
      case _PlanStatus.archived:
        return 'archived';
      case _PlanStatus.draft:
        return 'draft';
    }
  }

  List<String> _parseLessonSteps(Map<String, dynamic> data) {
    final List<String> topLevel = List<String>.from(
      data['lessonSteps'] as List<dynamic>? ?? const <String>[],
    ).where((String value) => value.trim().isNotEmpty).toList();
    if (topLevel.isNotEmpty) {
      return topLevel;
    }
    final dynamic bodyJson = data['bodyJson'];
    if (bodyJson is Map<String, dynamic>) {
      final dynamic lessonBuilder = bodyJson['lessonBuilder'];
      if (lessonBuilder is Map<String, dynamic>) {
        final dynamic steps = lessonBuilder['steps'];
        if (steps is List<dynamic>) {
          return steps
              .map((dynamic step) {
                if (step is Map<String, dynamic>) {
                  return (step['title'] as String? ?? '').trim();
                }
                return '';
              })
              .where((String value) => value.isNotEmpty)
              .toList();
        }
      }
    }
    return const <String>[];
  }

  String _difficultyLabel(String difficulty) {
    switch (difficulty.trim().toLowerCase()) {
      case 'advanced':
        return _tEducatorMissionPlans(context, 'Advanced');
      case 'intermediate':
        return _tEducatorMissionPlans(context, 'Intermediate');
      default:
        return _tEducatorMissionPlans(context, 'Beginner');
    }
  }

  String _evidenceDefaultLabel(String evidenceDefault) {
    switch (evidenceDefault) {
      case 'artifact_capture':
        return _tEducatorMissionPlans(context, 'Artifact capture');
      case 'reflection_note':
        return _tEducatorMissionPlans(context, 'Reflection note');
      default:
        return _tEducatorMissionPlans(context, 'Explain-it-back check');
    }
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}
