import 'package:flutter/material.dart';
import '../../ui/theme/scholesa_theme.dart';

/// Parent portfolio page for viewing learner's work and achievements
/// Based on docs/01_SUPREME_SPEC_EMPIRE_PLATFORM.md - Portfolio features
class ParentPortfolioPage extends StatefulWidget {
  const ParentPortfolioPage({super.key});

  @override
  State<ParentPortfolioPage> createState() => _ParentPortfolioPageState();
}

class _ParentPortfolioPageState extends State<ParentPortfolioPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<_PortfolioItem> _portfolioItems = <_PortfolioItem>[
    _PortfolioItem(
      id: '1',
      title: 'AI Chatbot Project',
      pillar: 'Future Skills',
      type: _ItemType.project,
      completedAt: DateTime.now().subtract(const Duration(days: 5)),
      imageUrl: null,
      description: 'Built a chatbot that can answer questions about our school',
    ),
    _PortfolioItem(
      id: '2',
      title: 'Team Leadership Award',
      pillar: 'Leadership & Agency',
      type: _ItemType.badge,
      completedAt: DateTime.now().subtract(const Duration(days: 10)),
      imageUrl: null,
      description: 'Led a team of 4 to complete the robotics challenge',
    ),
    _PortfolioItem(
      id: '3',
      title: 'Community Garden Project',
      pillar: 'Impact & Innovation',
      type: _ItemType.project,
      completedAt: DateTime.now().subtract(const Duration(days: 15)),
      imageUrl: null,
      description: 'Designed and helped build a community garden at school',
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
        title: const Text('Portfolio'),
        backgroundColor: ScholesaColors.parentGradient.colors.first,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const <Widget>[
            Tab(text: 'All'),
            Tab(text: 'Projects'),
            Tab(text: 'Badges'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          _buildPortfolioGrid(null),
          _buildPortfolioGrid(_ItemType.project),
          _buildPortfolioGrid(_ItemType.badge),
        ],
      ),
    );
  }

  Widget _buildPortfolioGrid(_ItemType? typeFilter) {
    final List<_PortfolioItem> filtered = typeFilter == null
        ? _portfolioItems
        : _portfolioItems.where((_PortfolioItem i) => i.type == typeFilter).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.folder_open_rounded, size: 64, color: ScholesaColors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'No items yet',
              style: TextStyle(fontSize: 16, color: ScholesaColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: filtered.length,
      itemBuilder: (BuildContext context, int index) => _buildPortfolioCard(filtered[index]),
    );
  }

  Widget _buildPortfolioCard(_PortfolioItem item) {
    return Card(
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showItemDetails(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[_getPillarColor(item.pillar), _getPillarColor(item.pillar).withValues(alpha: 0.7)],
                ),
              ),
              child: Center(
                child: Icon(
                  item.type == _ItemType.badge ? Icons.military_tech_rounded : Icons.work_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      _buildPillarDot(item.pillar),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.pillar,
                          style: TextStyle(fontSize: 11, color: ScholesaColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
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

  Widget _buildPillarDot(String pillar) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: _getPillarColor(pillar),
        shape: BoxShape.circle,
      ),
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

  void _showItemDetails(_PortfolioItem item) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ScholesaColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (BuildContext context, ScrollController scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            Container(
              height: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[_getPillarColor(item.pillar), _getPillarColor(item.pillar).withValues(alpha: 0.7)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  item.type == _ItemType.badge ? Icons.military_tech_rounded : Icons.work_rounded,
                  color: Colors.white,
                  size: 64,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getPillarColor(item.pillar).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item.pillar,
                    style: TextStyle(fontSize: 12, color: _getPillarColor(item.pillar), fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item.type == _ItemType.badge ? 'Badge' : 'Project',
                    style: TextStyle(fontSize: 12, color: ScholesaColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(item.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Completed ${_formatDate(item.completedAt)}',
              style: TextStyle(color: ScholesaColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Text(item.description, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sharing...')),
                      );
                    },
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Share'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Download'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}

enum _ItemType { project, badge }

class _PortfolioItem {
  const _PortfolioItem({
    required this.id,
    required this.title,
    required this.pillar,
    required this.type,
    required this.completedAt,
    required this.imageUrl,
    required this.description,
  });

  final String id;
  final String title;
  final String pillar;
  final _ItemType type;
  final DateTime completedAt;
  final String? imageUrl;
  final String description;
}
