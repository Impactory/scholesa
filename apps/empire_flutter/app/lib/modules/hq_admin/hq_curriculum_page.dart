import 'package:flutter/material.dart';
import '../../ui/theme/scholesa_theme.dart';

/// HQ Curriculum page for managing curriculum versions and rubrics
/// Based on docs/45_CURRICULUM_VERSIONING_RUBRICS_SPEC.md
class HqCurriculumPage extends StatefulWidget {
  const HqCurriculumPage({super.key});

  @override
  State<HqCurriculumPage> createState() => _HqCurriculumPageState();
}

enum _CurriculumStatus { draft, review, published, archived }

class _Curriculum {
  const _Curriculum({
    required this.id,
    required this.title,
    required this.pillar,
    required this.version,
    required this.status,
    required this.lastUpdated,
  });

  final String id;
  final String title;
  final String pillar;
  final String version;
  final _CurriculumStatus status;
  final DateTime lastUpdated;
}

class _HqCurriculumPageState extends State<HqCurriculumPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<_Curriculum> _curricula = <_Curriculum>[
    _Curriculum(
      id: '1',
      title: 'AI Fundamentals',
      pillar: 'Future Skills',
      version: '2.0',
      status: _CurriculumStatus.published,
      lastUpdated: DateTime.now().subtract(const Duration(days: 7)),
    ),
    _Curriculum(
      id: '2',
      title: 'Leadership Essentials',
      pillar: 'Leadership & Agency',
      version: '1.5',
      status: _CurriculumStatus.published,
      lastUpdated: DateTime.now().subtract(const Duration(days: 30)),
    ),
    _Curriculum(
      id: '3',
      title: 'Community Impact Projects',
      pillar: 'Impact & Innovation',
      version: '3.0',
      status: _CurriculumStatus.review,
      lastUpdated: DateTime.now().subtract(const Duration(days: 2)),
    ),
    _Curriculum(
      id: '4',
      title: 'Robotics Intro',
      pillar: 'Future Skills',
      version: '1.0-beta',
      status: _CurriculumStatus.draft,
      lastUpdated: DateTime.now().subtract(const Duration(hours: 6)),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: const Text('Curriculum Manager'),
        backgroundColor: ScholesaColors.hqGradient.colors.first,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const <Widget>[
            Tab(text: 'Published'),
            Tab(text: 'In Review'),
            Tab(text: 'Drafts'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(),
        backgroundColor: ScholesaColors.hqGradient.colors.first,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Curriculum'),
      ),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          _buildCurriculumList(_CurriculumStatus.published),
          _buildCurriculumList(_CurriculumStatus.review),
          _buildCurriculumList(_CurriculumStatus.draft),
        ],
      ),
    );
  }

  Widget _buildCurriculumList(_CurriculumStatus status) {
    final List<_Curriculum> filtered = _curricula.where((_Curriculum c) => c.status == status).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.menu_book_rounded, size: 64, color: ScholesaColors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('No ${status.name} curricula', style: TextStyle(color: ScholesaColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (BuildContext context, int index) => _buildCurriculumCard(filtered[index]),
    );
  }

  Widget _buildCurriculumCard(_Curriculum curriculum) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showCurriculumDetails(curriculum),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _buildPillarIcon(curriculum.pillar),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(curriculum.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(curriculum.pillar, style: TextStyle(fontSize: 12, color: _getPillarColor(curriculum.pillar))),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ScholesaColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('v${curriculum.version}', style: TextStyle(fontSize: 12, color: ScholesaColors.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Updated ${_formatTime(curriculum.lastUpdated)}',
                style: TextStyle(fontSize: 12, color: ScholesaColors.textSecondary),
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
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
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

  void _showCurriculumDetails(_Curriculum curriculum) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ScholesaColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(curriculum.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(curriculum.pillar, style: TextStyle(color: _getPillarColor(curriculum.pillar))),
            const SizedBox(height: 16),
            _buildDetailRow('Version', curriculum.version),
            _buildDetailRow('Status', curriculum.status.name.toUpperCase()),
            _buildDetailRow('Updated', _formatTime(curriculum.lastUpdated)),
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Opening curriculum editor...')),
                      );
                    },
                    child: const Text('Edit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: TextStyle(color: ScholesaColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _showCreateDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: ScholesaColors.surface,
        title: const Text('New Curriculum'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const TextField(decoration: InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Pillar', border: OutlineInputBorder()),
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Curriculum created')));
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final Duration diff = DateTime.now().difference(time);
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
