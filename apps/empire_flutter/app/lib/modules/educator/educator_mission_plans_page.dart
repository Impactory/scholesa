import 'package:flutter/material.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';

const Map<String, String> _educatorMissionPlansEs = <String, String>{
  'Future Skills': 'Habilidades del futuro',
  'Impact & Innovation': 'Impacto e innovación',
  'Leadership & Agency': 'Liderazgo y agencia',
  'Mission Plans': 'Planes de misión',
  'New Mission': 'Nueva misión',
  'Grade': 'Grado',
  'sessions': 'sesiones',
  'done': 'completadas',
  'Draft': 'Borrador',
  'Active': 'Activa',
  'Archived': 'Archivada',
  'Filter Missions': 'Filtrar misiones',
  'All Pillars': 'Todos los pilares',
  'Close': 'Cerrar',
  'Edit': 'Editar',
  'Assigning to sessions...': 'Asignando a sesiones...',
  'Assign': 'Asignar',
  'Create New Mission': 'Crear nueva misión',
  'Mission Title': 'Título de la misión',
  'Pillar': 'Pilar',
  'Cancel': 'Cancelar',
  'Mission title is required': 'El título de la misión es obligatorio',
  'Mission created and added to list':
      'Misión creada y agregada a la lista',
  'Create': 'Crear',
};

String _tEducatorMissionPlans(BuildContext context, String input) {
  final String locale = Localizations.localeOf(context).languageCode;
  if (locale != 'es') return input;
  return _educatorMissionPlansEs[input] ?? input;
}

/// Educator mission plans page for planning and managing missions
/// Based on docs/11_MISSIONS_CHALLENGES_SPEC.md

enum _PlanStatus { draft, active, archived }

class _MissionPlan {
  const _MissionPlan({
    required this.id,
    required this.title,
    required this.pillar,
    required this.duration,
    required this.targetGrade,
    required this.status,
    required this.assignedSessions,
    required this.completedBy,
  });

  final String id;
  final String title;
  final String pillar;
  final String duration;
  final String targetGrade;
  final _PlanStatus status;
  final int assignedSessions;
  final int completedBy;
}

class EducatorMissionPlansPage extends StatefulWidget {
  const EducatorMissionPlansPage({super.key});

  @override
  State<EducatorMissionPlansPage> createState() =>
      _EducatorMissionPlansPageState();
}

class _EducatorMissionPlansPageState extends State<EducatorMissionPlansPage> {
  final List<_MissionPlan> _missionPlans = <_MissionPlan>[
    const _MissionPlan(
      id: '1',
      title: 'AI Image Generator',
      pillar: 'Future Skills',
      duration: '4 weeks',
      targetGrade: '6-8',
      status: _PlanStatus.active,
      assignedSessions: 3,
      completedBy: 12,
    ),
    const _MissionPlan(
      id: '2',
      title: 'Community Clean-up Project',
      pillar: 'Impact & Innovation',
      duration: '2 weeks',
      targetGrade: '4-6',
      status: _PlanStatus.active,
      assignedSessions: 2,
      completedBy: 8,
    ),
    const _MissionPlan(
      id: '3',
      title: 'Student Council Campaign',
      pillar: 'Leadership & Agency',
      duration: '3 weeks',
      targetGrade: '7-9',
      status: _PlanStatus.draft,
      assignedSessions: 0,
      completedBy: 0,
    ),
  ];
  int _nextMissionId = 4;

  @override
  Widget build(BuildContext context) {
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
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _missionPlans.length,
        itemBuilder: (BuildContext context, int index) {
          return _buildMissionPlanCard(_missionPlans[index]);
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
                      ],
                    ),
                  ),
                  _buildStatusChip(plan.status),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  _buildInfoItem(Icons.timer_outlined, plan.duration),
                  _buildInfoItem(
                      Icons.school_outlined,
                      '${_tEducatorMissionPlans(context, 'Grade')} ${plan.targetGrade}'),
                  _buildInfoItem(Icons.calendar_today_outlined,
                      '${plan.assignedSessions} ${_tEducatorMissionPlans(context, 'sessions')}'),
                  _buildInfoItem(
                      Icons.check_circle_outline,
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

  void _showFilterDialog() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{
        'cta': 'educator_mission_plans_open_filter'
      },
    );
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: ScholesaColors.surface,
        title: Text(_tEducatorMissionPlans(context, 'Filter Missions')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _buildFilterOption(_tEducatorMissionPlans(context, 'All Pillars')),
            _buildFilterOption(_tEducatorMissionPlans(context, 'Future Skills')),
            _buildFilterOption(_tEducatorMissionPlans(context, 'Leadership & Agency')),
            _buildFilterOption(_tEducatorMissionPlans(context, 'Impact & Innovation')),
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
        ],
      ),
    );
  }

  Widget _buildFilterOption(String label) {
    return ListTile(
      title: Text(label),
      leading: RadioGroup<String>(
        groupValue: _tEducatorMissionPlans(context, 'All Pillars'),
        onChanged: (_) {},
        child: Radio<String>(
          value: label,
        ),
      ),
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
                        child: Text(_tEducatorMissionPlans(context, 'Future Skills'))),
                    DropdownMenuItem<String>(
                        value: 'Leadership & Agency',
                        child: Text(_tEducatorMissionPlans(context, 'Leadership & Agency'))),
                    DropdownMenuItem<String>(
                        value: 'Impact & Innovation',
                        child: Text(_tEducatorMissionPlans(context, 'Impact & Innovation'))),
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
              onPressed: () {
                final String title = titleController.text.trim();
                if (title.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_tEducatorMissionPlans(
                        context, 'Mission title is required'))),
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

                setState(() {
                  _missionPlans.insert(
                    0,
                    _MissionPlan(
                      id: (_nextMissionId++).toString(),
                      title: title,
                      pillar: selectedPillar,
                      duration: '4 weeks',
                      targetGrade: '6-8',
                      status: _PlanStatus.draft,
                      assignedSessions: 0,
                      completedBy: 0,
                    ),
                  );
                });

                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(_tEducatorMissionPlans(
                          context, 'Mission created and added to list'))),
                );
              },
              child: Text(_tEducatorMissionPlans(context, 'Create')),
            ),
          ],
        ),
      ),
    );
  }
}
