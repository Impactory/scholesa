import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../i18n/workflow_surface_i18n.dart';
import '../../services/telemetry_service.dart';
import '../../services/firestore_service.dart';
import '../../ui/theme/scholesa_theme.dart';
import '../../runtime/runtime.dart';
import '../../i18n/bos_coaching_i18n.dart';
import '../../auth/app_state.dart';
import 'educator_service.dart';

String _tEducatorMissionPlans(BuildContext context, String input) {
  return WorkflowSurfaceI18n.text(context, input);
}

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
  const EducatorMissionPlansPage({super.key});

  @override
  State<EducatorMissionPlansPage> createState() =>
      _EducatorMissionPlansPageState();
}

class _EducatorMissionPlansPageState extends State<EducatorMissionPlansPage> {
  List<_MissionPlan> _missionPlans = <_MissionPlan>[];
  bool _isLoading = false;
  String _pillarFilter = 'All Pillars';

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
                    context, 'Mission Planning AI Coach'),
                subtitle: _tEducatorMissionPlans(
                  context,
                  'Keep BOS/MIA loop active while designing missions for each learner',
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
      backgroundColor: ScholesaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
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
                    },
                    child: Text(_tEducatorMissionPlans(context, 'Edit')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: <String, dynamic>{
                          'cta': 'educator_mission_plans_assign_plan',
                          'plan_id': plan.id,
                        },
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(_tEducatorMissionPlans(
                                context, 'Assigning to sessions...'))),
                      );
                    },
                    child: Text(_tEducatorMissionPlans(context, 'Assign')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateMissionDialog() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{
        'cta': 'educator_mission_plans_open_create_dialog'
      },
    );
    final TextEditingController titleController = TextEditingController();
    String selectedPillar = 'Future Skills';

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context,
                void Function(void Function()) setLocalState) =>
            AlertDialog(
          backgroundColor: ScholesaColors.surface,
          title: Text(_tEducatorMissionPlans(context, 'Create New Mission')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: _tEducatorMissionPlans(context, 'Mission Title'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedPillar,
                  decoration: InputDecoration(
                    labelText: _tEducatorMissionPlans(context, 'Pillar'),
                    border: OutlineInputBorder(),
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
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: const <String, dynamic>{
                    'cta': 'educator_mission_plans_create_cancel'
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
                final String createdText = _tEducatorMissionPlans(
                    context, 'Mission created and added to list');
                final String createFailedText =
                    _tEducatorMissionPlans(context, 'Failed to create mission');
                final String title = titleController.text.trim();
                if (title.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(titleRequiredText)),
                  );
                  return;
                }

                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: <String, dynamic>{
                    'cta': 'educator_mission_plans_create_submit',
                    'pillar': selectedPillar,
                  },
                );

                final bool created = await _createMission(
                  title: title,
                  pillar: selectedPillar,
                );
                if (!mounted || !dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(created ? createdText : createFailedText),
                  ),
                );
              },
              child: Text(_tEducatorMissionPlans(context, 'Create')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadMissionPlans() async {
    setState(() => _isLoading = true);
    try {
      final FirebaseFirestore firestore = _resolveFirestore();
      Query<Map<String, dynamic>> query =
          firestore.collection('missions').limit(100);
      try {
        query = query.orderBy('createdAt', descending: true);
      } catch (_) {}

      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
      final String? currentUserId = _resolveActorId();

      final List<_MissionPlan> loaded =
          snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        final String pillar = _canonicalPillar(
          data['pillar'] as String? ?? data['pillarCode'] as String?,
        );
        return _MissionPlan(
          id: doc.id,
          title: (data['title'] as String? ?? '').trim().isEmpty
              ? 'Mission'
              : (data['title'] as String).trim(),
          pillar: pillar,
          duration: (data['duration'] as String? ?? '4 weeks'),
          targetGrade: (data['targetGrade'] as String? ??
              data['gradeBand'] as String? ??
              '6-8'),
          status: _parsePlanStatus(data['status'] as String?),
          assignedSessions: _asInt(data['assignedSessions']) ??
              ((data['sessionIds'] as List<dynamic>?)?.length ?? 0),
          completedBy: _asInt(data['completedBy']) ??
              _asInt(data['completedCount']) ??
              0,
        );
      }).where((_MissionPlan plan) {
        if (currentUserId == null || currentUserId.isEmpty) return true;
        final QueryDocumentSnapshot<Map<String, dynamic>>? sourceDoc =
            snapshot.docs.where((d) => d.id == plan.id).firstOrNull;
        final Map<String, dynamic>? data = sourceDoc?.data();
        if (data == null) return true;
        final String? ownerId =
            (data['educatorId'] as String?) ?? (data['createdBy'] as String?);
        if (ownerId == null || ownerId.trim().isEmpty) return true;
        return ownerId.trim() == currentUserId;
      }).toList();

      setState(() {
        _missionPlans = loaded;
      });
    } catch (_) {
      // Best-effort load for environments without Firebase (e.g. widget tests).
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _createMission({
    required String title,
    required String pillar,
  }) async {
    try {
      final FirebaseFirestore firestore = _resolveFirestore();
      final String? userId = _resolveActorId();
      final DocumentReference<Map<String, dynamic>> createdRef =
          await firestore.collection('missions').add(<String, dynamic>{
        'title': title,
        'pillar': pillar,
        'pillarCode': _pillarCodeFromLabel(pillar),
        'duration': '4 weeks',
        'targetGrade': '6-8',
        'status': 'draft',
        'assignedSessions': 0,
        'completedBy': 0,
        if (userId != null && userId.isNotEmpty) 'educatorId': userId,
        if (userId != null && userId.isNotEmpty) 'createdBy': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final _MissionPlan created = _MissionPlan(
        id: createdRef.id,
        title: title,
        pillar: pillar,
        duration: '4 weeks',
        targetGrade: '6-8',
        status: _PlanStatus.draft,
        assignedSessions: 0,
        completedBy: 0,
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Create mission failed: $error')),
        );
      }
      return false;
    }
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

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}
