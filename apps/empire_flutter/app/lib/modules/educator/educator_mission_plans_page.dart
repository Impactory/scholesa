import 'package:flutter/material.dart';
import '../../ui/theme/scholesa_theme.dart';

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
  State<EducatorMissionPlansPage> createState() => _EducatorMissionPlansPageState();
}

class _EducatorMissionPlansPageState extends State<EducatorMissionPlansPage> {
  final List<_MissionPlan> _missionPlans = <_MissionPlan>[
    _MissionPlan(
      id: '1',
      title: 'AI Image Generator',
      pillar: 'Future Skills',
      duration: '4 weeks',
      targetGrade: '6-8',
      status: _PlanStatus.active,
      assignedSessions: 3,
      completedBy: 12,
    ),
    _MissionPlan(
      id: '2',
      title: 'Community Clean-up Project',
      pillar: 'Impact & Innovation',
      duration: '2 weeks',
      targetGrade: '4-6',
      status: _PlanStatus.active,
      assignedSessions: 2,
      completedBy: 8,
    ),
    _MissionPlan(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: const Text('Mission Plans'),
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
        label: const Text('New Mission'),
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
                          plan.pillar,
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
                  _buildInfoItem(Icons.school_outlined, 'Grade ${plan.targetGrade}'),
                  _buildInfoItem(Icons.calendar_today_outlined, '${plan.assignedSessions} sessions'),
                  _buildInfoItem(Icons.check_circle_outline, '${plan.completedBy} done'),
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
        label = 'Draft';
      case _PlanStatus.active:
        color = Colors.green;
        label = 'Active';
      case _PlanStatus.archived:
        color = Colors.orange;
        label = 'Archived';
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
          style: TextStyle(
            fontSize: 12,
            color: ScholesaColors.textSecondary,
          ),
        ),
      ],
    );
  }

  void _showFilterDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: ScholesaColors.surface,
        title: const Text('Filter Missions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _buildFilterOption('All Pillars'),
            _buildFilterOption('Future Skills'),
            _buildFilterOption('Leadership & Agency'),
            _buildFilterOption('Impact & Innovation'),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterOption(String label) {
    return ListTile(
      title: Text(label),
      leading: Radio<String>(
        value: label,
        groupValue: 'All Pillars',
        onChanged: (_) {},
      ),
    );
  }

  void _showMissionDetails(_MissionPlan plan) {
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
              plan.pillar,
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
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Assigning to sessions...')),
                      );
                    },
                    child: const Text('Assign'),
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
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: ScholesaColors.surface,
        title: const Text('Create New Mission'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const TextField(
              decoration: InputDecoration(
                labelText: 'Mission Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Pillar',
                border: OutlineInputBorder(),
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(value: 'Future Skills', child: Text('Future Skills')),
                DropdownMenuItem<String>(value: 'Leadership & Agency', child: Text('Leadership & Agency')),
                DropdownMenuItem<String>(value: 'Impact & Innovation', child: Text('Impact & Innovation')),
              ],
              onChanged: (_) {},
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Mission created')),
              );
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
