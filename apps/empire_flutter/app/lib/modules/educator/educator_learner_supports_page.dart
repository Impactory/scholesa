import 'package:flutter/material.dart';
import '../../ui/theme/scholesa_theme.dart';

/// Educator learner supports page for tracking learner wellbeing & accommodations
/// Based on docs/09_LEARNER_SUPPORT_ACCOMMODATIONS_SPEC.md
class EducatorLearnerSupportsPage extends StatefulWidget {
  const EducatorLearnerSupportsPage({super.key});

  @override
  State<EducatorLearnerSupportsPage> createState() => _EducatorLearnerSupportsPageState();
}

class _EducatorLearnerSupportsPageState extends State<EducatorLearnerSupportsPage> {
  final List<_LearnerSupport> _learnerSupports = <_LearnerSupport>[
    _LearnerSupport(
      learnerId: '1',
      learnerName: 'Oliver Thompson',
      avatarUrl: null,
      supportType: 'Academic',
      accommodations: <String>['Extended time', 'Quiet space'],
      notes: 'Responds well to visual aids',
      lastUpdated: DateTime.now().subtract(const Duration(days: 5)),
      priority: _Priority.medium,
    ),
    _LearnerSupport(
      learnerId: '2',
      learnerName: 'Emma Smith',
      avatarUrl: null,
      supportType: 'Social-Emotional',
      accommodations: <String>['Check-in support', 'Peer buddy'],
      notes: 'Building confidence in group settings',
      lastUpdated: DateTime.now().subtract(const Duration(days: 2)),
      priority: _Priority.high,
    ),
    _LearnerSupport(
      learnerId: '3',
      learnerName: 'Liam Martinez',
      avatarUrl: null,
      supportType: 'Behavioral',
      accommodations: <String>['Movement breaks', 'Clear transitions'],
      notes: 'Use positive reinforcement',
      lastUpdated: DateTime.now().subtract(const Duration(days: 10)),
      priority: _Priority.low,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: const Text('Learner Supports'),
        backgroundColor: ScholesaColors.educatorGradient.colors.first,
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Search coming soon')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _buildSummaryCards(),
          const SizedBox(height: 24),
          const Text(
            'Active Support Plans',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ScholesaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ..._learnerSupports.map((support) => _buildSupportCard(support)),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: <Widget>[
        Expanded(
          child: _buildSummaryCard(
            'High Priority',
            _learnerSupports.where((_LearnerSupport s) => s.priority == _Priority.high).length.toString(),
            Colors.red,
            Icons.priority_high_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Active Plans',
            _learnerSupports.length.toString(),
            Colors.blue,
            Icons.people_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Reviews Due',
            '2',
            Colors.orange,
            Icons.schedule_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ScholesaColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: ScholesaColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSupportCard(_LearnerSupport support) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showSupportDetails(support),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: ScholesaColors.educatorGradient.colors.first.withValues(alpha: 0.2),
                    child: Text(
                      support.learnerName.substring(0, 1),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: ScholesaColors.educatorGradient.colors.first,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          support.learnerName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: ScholesaColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          support.supportType,
                          style: TextStyle(
                            fontSize: 13,
                            color: ScholesaColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildPriorityBadge(support.priority),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: support.accommodations.map((String a) => _buildAccommodationChip(a)).toList(),
              ),
              if (support.notes.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  'Note: ${support.notes}',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
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

  Widget _buildPriorityBadge(_Priority priority) {
    Color color;
    String label;
    switch (priority) {
      case _Priority.high:
        color = Colors.red;
        label = 'High';
      case _Priority.medium:
        color = Colors.orange;
        label = 'Medium';
      case _Priority.low:
        color = Colors.green;
        label = 'Low';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildAccommodationChip(String accommodation) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Text(
        accommodation,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.blue,
        ),
      ),
    );
  }

  void _showSupportDetails(_LearnerSupport support) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ScholesaColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (BuildContext context, ScrollController scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 30,
                  backgroundColor: ScholesaColors.educatorGradient.colors.first.withValues(alpha: 0.2),
                  child: Text(
                    support.learnerName.substring(0, 1),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: ScholesaColors.educatorGradient.colors.first,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        support.learnerName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Support Plan • ${support.supportType}',
                        style: TextStyle(color: ScholesaColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Accommodations',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...support.accommodations.map((String a) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Text(a),
                ],
              ),
            )),
            const SizedBox(height: 16),
            const Text(
              'Notes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              support.notes.isNotEmpty ? support.notes : 'No notes',
              style: TextStyle(color: ScholesaColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Edit support plan')),
                      );
                    },
                    child: const Text('Edit Plan'),
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

enum _Priority { high, medium, low }

class _LearnerSupport {
  const _LearnerSupport({
    required this.learnerId,
    required this.learnerName,
    required this.avatarUrl,
    required this.supportType,
    required this.accommodations,
    required this.notes,
    required this.lastUpdated,
    required this.priority,
  });

  final String learnerId;
  final String learnerName;
  final String? avatarUrl;
  final String supportType;
  final List<String> accommodations;
  final String notes;
  final DateTime lastUpdated;
  final _Priority priority;
}
