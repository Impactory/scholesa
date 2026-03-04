import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';
import '../../runtime/runtime.dart';
import '../../auth/app_state.dart';
import 'parent_models.dart';
import 'parent_service.dart';

const Map<String, String> _parentPortfolioEs = <String, String>{
  'Portfolio': 'Portafolio',
  'All': 'Todo',
  'Projects': 'Proyectos',
  'Badges': 'Insignias',
  'No items yet': 'Aún no hay elementos',
  'Future Skills': 'Habilidades del futuro',
  'Leadership & Agency': 'Liderazgo y agencia',
  'Impact & Innovation': 'Impacto e innovación',
  'Badge': 'Insignia',
  'Project': 'Proyecto',
  'Completed': 'Completado',
  'Sharing...': 'Compartiendo...',
  'Share': 'Compartir',
  'Download': 'Descargar',
  'activity': 'actividad',
  'Completed by': 'Completado por',
  'Getting AI Guidance': 'Obteniendo orientación de IA',
  'Get personalized coaching on supporting your child': 'Obtén asesoramiento personalizado sobre cómo apoyar a tu hijo',
  'Hide AI Guidance': 'Ocultar orientación de IA',
};

/// Parent portfolio page for viewing learner's work and achievements
/// Based on docs/01_SUPREME_SPEC_EMPIRE_PLATFORM.md - Portfolio features
class ParentPortfolioPage extends StatefulWidget {
  const ParentPortfolioPage({super.key});

  @override
  State<ParentPortfolioPage> createState() => _ParentPortfolioPageState();
}

class _ParentPortfolioPageState extends State<ParentPortfolioPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showAiCoach = false;

  String _t(String input) {
    final String locale = Localizations.localeOf(context).languageCode;
    if (locale != 'es') return input;
    return _parentPortfolioEs[input] ?? input;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ParentService>().loadParentData();
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
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: Text(_t('Portfolio')),
        backgroundColor: ScholesaColors.parentGradient.colors.first,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: <Widget>[
            Tab(text: _t('All')),
            Tab(text: _t('Projects')),
            Tab(text: _t('Badges')),
          ],
        ),
      ),
      body: Consumer<ParentService>(
        builder: (BuildContext context, ParentService service, _) {
          final List<_PortfolioItem> portfolioItems =
              _portfolioItemsFromService(service);
          return Column(
            children: <Widget>[
              _buildAiCoachingSection(context),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: <Widget>[
                    _buildPortfolioGrid(portfolioItems, null),
                    _buildPortfolioGrid(portfolioItems, _ItemType.project),
                    _buildPortfolioGrid(portfolioItems, _ItemType.badge),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPortfolioGrid(List<_PortfolioItem> portfolioItems, _ItemType? typeFilter) {
    final List<_PortfolioItem> filtered = typeFilter == null
        ? portfolioItems
        : portfolioItems
            .where((_PortfolioItem i) => i.type == typeFilter)
            .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.folder_open_rounded,
                size: 64,
                color: ScholesaColors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              _t('No items yet'),
              style:
                  TextStyle(fontSize: 16, color: ScholesaColors.textSecondary),
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
      itemBuilder: (BuildContext context, int index) =>
          _buildPortfolioCard(filtered[index]),
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
                  colors: <Color>[
                    _getPillarColor(item.pillar),
                    _getPillarColor(item.pillar).withValues(alpha: 0.7)
                  ],
                ),
              ),
              child: Center(
                child: Icon(
                  item.type == _ItemType.badge
                      ? Icons.military_tech_rounded
                      : Icons.work_rounded,
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
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
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
                            _t(item.pillar),
                          style: const TextStyle(
                              fontSize: 11,
                              color: ScholesaColors.textSecondary),
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
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'parent_portfolio_open_item',
        'item_id': item.id
      },
    );
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ScholesaColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (BuildContext context, ScrollController scrollController) =>
            ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            Container(
              height: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    _getPillarColor(item.pillar),
                    _getPillarColor(item.pillar).withValues(alpha: 0.7)
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  item.type == _ItemType.badge
                      ? Icons.military_tech_rounded
                      : Icons.work_rounded,
                  color: Colors.white,
                  size: 64,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getPillarColor(item.pillar).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _t(item.pillar),
                    style: TextStyle(
                        fontSize: 12,
                        color: _getPillarColor(item.pillar),
                        fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item.type == _ItemType.badge
                        ? _t('Badge')
                        : _t('Project'),
                    style: const TextStyle(
                        fontSize: 12, color: ScholesaColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(item.title,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              '${_t('Completed')} ${_formatDate(item.completedAt)}',
              style: const TextStyle(color: ScholesaColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Text(item.description, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: <String, dynamic>{
                          'cta': 'parent_portfolio_share_item',
                          'item_id': item.id
                        },
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(_t('Sharing...'))),
                      );
                    },
                    icon: const Icon(Icons.share_rounded),
                    label: Text(_t('Share')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: <String, dynamic>{
                          'cta': 'parent_portfolio_download_item',
                          'item_id': item.id
                        },
                      );
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.download_rounded),
                    label: Text(_t('Download')),
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

  List<_PortfolioItem> _portfolioItemsFromService(ParentService service) {
    final List<_PortfolioItem> items = <_PortfolioItem>[];

    for (final LearnerSummary learner in service.learnerSummaries) {
      for (final RecentActivity activity in learner.recentActivities) {
        final _ItemType itemType = _mapActivityType(activity.type);
        final String pillar = _pillarFromActivity(activity.type);
        items.add(
          _PortfolioItem(
            id: '${learner.learnerId}-${activity.id}',
            title: activity.title.isEmpty
                ? '${learner.learnerName} ${_t('activity')}'
                : activity.title,
            pillar: pillar,
            type: itemType,
            completedAt: activity.timestamp,
            imageUrl: null,
            description: activity.description.isEmpty
                ? '${_t('Completed by')} ${learner.learnerName}'
                : activity.description,
          ),
        );
      }
    }

    items.sort((_PortfolioItem a, _PortfolioItem b) =>
        b.completedAt.compareTo(a.completedAt));
    return items;
  }

  _ItemType _mapActivityType(String rawType) {
    final String type = rawType.trim().toLowerCase();
    if (type == 'achievement' || type == 'badge') {
      return _ItemType.badge;
    }
    return _ItemType.project;
  }

  String _pillarFromActivity(String rawType) {
    final String type = rawType.trim().toLowerCase();
    if (type == 'habit') {
      return 'Leadership & Agency';
    }
    if (type == 'attendance') {
      return 'Impact & Innovation';
    }
    return 'Future Skills';
  }

  Widget _buildAiCoachingSection(BuildContext context) {
    final AppState? appState = context.read<AppState>();
    final UserRole? role = appState?.role;

    if (role == null || role != UserRole.parent) {
      return const SizedBox.shrink();
    }

    final Color parentColor = ScholesaColors.parentGradient.colors.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              color: parentColor.withValues(alpha: 0.1),
              border: Border.all(
                color: parentColor.withValues(alpha: 0.2),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Icon(
                Icons.smart_toy_rounded,
                color: parentColor,
              ),
              title: Text(_t('Getting AI Guidance')),
              subtitle: Text(_t('Get personalized coaching on supporting your child')),
              trailing: IconButton(
                icon: Icon(
                  _showAiCoach ? Icons.expand_less : Icons.expand_more,
                ),
                onPressed: () {
                  setState(() => _showAiCoach = !_showAiCoach);
                  TelemetryService.instance.logEvent(
                    event: 'cta.clicked',
                    metadata: <String, dynamic>{
                      'module': 'parent_portfolio',
                      'cta': 'parent_ai_${_showAiCoach ? 'show' : 'hide'}',
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

    final Color parentColor = ScholesaColors.parentGradient.colors.first;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: parentColor.withValues(alpha: 0.05),
        border: Border.all(
          color: parentColor.withValues(alpha: 0.1),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      constraints: const BoxConstraints(minHeight: 350),
      child: AiCoachWidget(
        runtime: runtime,
        actorRole: role,
        conceptTags: <String>[
          'parent_support',
          'learning_guidance',
          'child_achievement',
        ],
      ),
    );
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
