import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../auth/app_state.dart';
import '../../i18n/workflow_surface_i18n.dart';
import '../../services/firestore_service.dart';
import '../../services/telemetry_service.dart';
import '../../ui/auth/global_session_menu.dart';
import '../../ui/theme/scholesa_theme.dart';

String _tHqSites(BuildContext context, String input) {
  return WorkflowSurfaceI18n.text(context, input);
}

/// HQ Sites Page - Manage all sites across the platform
class HqSitesPage extends StatefulWidget {
  const HqSitesPage({super.key, this.loadSitesOverride});

  final Future<List<Map<String, dynamic>>> Function()? loadSitesOverride;

  @override
  State<HqSitesPage> createState() => _HqSitesPageState();
}

class _HqSitesPageState extends State<HqSitesPage> {
  String _filterStatus = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<_SiteItem> _sites = <_SiteItem>[];
  bool _isLoading = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSites();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              scheme.surfaceContainerLow,
              scheme.surface,
              scheme.surfaceContainerHighest,
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildSearchBar()),
            SliverToBoxAdapter(child: _buildFilters()),
            SliverToBoxAdapter(child: _buildStats()),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: _buildSitesSliver(),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewSite,
        backgroundColor: ScholesaColors.hq,
        icon: const Icon(Icons.add),
        label: Text(_tHqSites(context, 'Add Site')),
      ),
    );
  }

  Widget _buildHeader() {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: ScholesaColors.hqGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: ScholesaColors.hq.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.business, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _tHqSites(context, 'Sites Management'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: ScholesaColors.hq,
                        ),
                  ),
                  Text(
                    _tHqSites(context, 'Manage all platform sites'),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _loadSites,
              icon: const Icon(Icons.refresh, color: ScholesaColors.hq),
              tooltip: _tHqSites(context, 'Refresh'),
            ),
            const SizedBox(width: 4),
            const SessionMenuHeaderAction(
              foregroundColor: ScholesaColors.hq,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        onChanged: (String value) {
          if (value.isNotEmpty) {
            TelemetryService.instance.logEvent(
              event: 'cta.clicked',
              metadata: <String, dynamic>{
                'cta': 'hq_sites_search_input',
                'length': value.length,
              },
            );
          }
          setState(() => _searchQuery = value);
        },
        decoration: InputDecoration(
          hintText: _tHqSites(context, 'Search sites...'),
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: const <String, dynamic>{
                        'cta': 'hq_sites_clear_search',
                        'surface': 'sites_search_bar',
                      },
                    );
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: scheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.primary),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            _FilterChip(
              label: _tHqSites(context, 'All Sites'),
              isSelected: _filterStatus == 'all',
              onTap: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: const <String, dynamic>{
                    'cta': 'hq_sites_filter_all',
                    'surface': 'sites_filter_chips',
                  },
                );
                setState(() => _filterStatus = 'all');
              },
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: _tHqSites(context, 'Active'),
              isSelected: _filterStatus == 'active',
              color: ScholesaColors.success,
              onTap: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: const <String, dynamic>{
                    'cta': 'hq_sites_filter_active',
                    'surface': 'sites_filter_chips',
                  },
                );
                setState(() => _filterStatus = 'active');
              },
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: _tHqSites(context, 'Onboarding'),
              isSelected: _filterStatus == 'onboarding',
              color: ScholesaColors.warning,
              onTap: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: const <String, dynamic>{
                    'cta': 'hq_sites_filter_onboarding',
                    'surface': 'sites_filter_chips',
                  },
                );
                setState(() => _filterStatus = 'onboarding');
              },
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: _tHqSites(context, 'Pending'),
              isSelected: _filterStatus == 'pending',
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              onTap: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: const <String, dynamic>{
                    'cta': 'hq_sites_filter_pending',
                    'surface': 'sites_filter_chips',
                  },
                );
                setState(() => _filterStatus = 'pending');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    final int totalSites = _sites.length;
    final int totalLearners = _sites.fold<int>(
        0, (int total, _SiteItem site) => total + site.learnerCount);
    final int totalEducators = _sites.fold<int>(
        0, (int total, _SiteItem site) => total + site.educatorCount);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _StatCard(
              icon: Icons.business,
              value: '$totalSites',
              label: _tHqSites(context, 'Total Sites'),
              color: ScholesaColors.hq,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Icons.people,
              value: '$totalLearners',
              label: _tHqSites(context, 'Total Learners'),
              color: ScholesaColors.learner,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Icons.school,
              value: '$totalEducators',
              label: _tHqSites(context, 'Educators'),
              color: ScholesaColors.educator,
            ),
          ),
        ],
      ),
    );
  }

  void _openSiteDetail(String siteId) {
    final String selectedSiteId = siteId.trim();
    if (selectedSiteId.isEmpty) return;
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'hq_sites_open_detail',
        'site_id': selectedSiteId,
      },
    );

    final AppState? appState = _maybeAppState();
    appState?.switchSite(selectedSiteId);

    final GoRouter? router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go('/site/dashboard');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_tHqSites(context, 'Opening site')}: $selectedSiteId'),
      ),
    );
  }

  void _createNewSite() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{'cta': 'hq_sites_open_create_site'},
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => _CreateSiteSheet(
        onCreated: () {
          _loadSites();
        },
      ),
    );
  }

  SliverList _buildSitesSliver() {
    if (_isLoading) {
      return SliverList(
        delegate: SliverChildListDelegate(
          <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  _tHqSites(context, 'Loading...'),
                  style: const TextStyle(color: ScholesaColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final List<_SiteItem> filtered = _filteredSites();
    if (_loadError != null && _sites.isEmpty) {
      return SliverList(
        delegate: SliverChildListDelegate(
          <Widget>[
            _buildLoadErrorCard(),
          ],
        ),
      );
    }
    if (filtered.isEmpty) {
      return SliverList(
        delegate: SliverChildListDelegate(
          <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  _tHqSites(context, 'No sites found'),
                  style: const TextStyle(color: ScholesaColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          if (_loadError != null && index == 0) {
            return _buildStaleDataBanner();
          }
          final int siteIndex = index - (_loadError != null ? 1 : 0);
          final _SiteItem item = filtered[siteIndex];
          return _SiteCard(
            name: item.name,
            location: item.location,
            learnerCount: item.learnerCount,
            educatorCount: item.educatorCount,
            status: item.status,
            healthScore: item.healthScore,
            onTap: () => _openSiteDetail(item.id),
          );
        },
        childCount: filtered.length + (_loadError != null ? 1 : 0),
      ),
    );
  }

  Widget _buildLoadErrorCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.red.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              _tHqSites(context, 'Sites are temporarily unavailable'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ScholesaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _tHqSites(
                context,
                'We could not load sites right now. Retry to check the current state.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(color: ScholesaColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadSites,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(_tHqSites(context, 'Retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaleDataBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _tHqSites(
                context,
                'Unable to refresh sites right now. Showing the last successful data.',
              ),
              style: const TextStyle(color: ScholesaColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  List<_SiteItem> _filteredSites() {
    return _sites.where((_SiteItem site) {
      final bool statusOk =
          _filterStatus == 'all' || site.status == _filterStatus;
      if (!statusOk) return false;
      if (_searchQuery.trim().isEmpty) return true;
      final String query = _searchQuery.trim().toLowerCase();
      return site.name.toLowerCase().contains(query) ||
          site.location.toLowerCase().contains(query) ||
          site.id.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _loadSites() async {
    final FirestoreService? firestoreService = _maybeFirestoreService();
    if (firestoreService == null) {
      if (!mounted) return;
      setState(() {
        _sites = <_SiteItem>[];
        _isLoading = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final List<_SiteItem> loaded = await _loadSiteItems(firestoreService);

      if (!mounted) return;
      setState(() => _sites = loaded);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = _tHqSites(
          context,
          'We could not load sites right now. Retry to check the current state.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<List<_SiteItem>> _loadSiteItems(
      FirestoreService firestoreService) async {
    if (widget.loadSitesOverride != null) {
      final List<Map<String, dynamic>> rows = await widget.loadSitesOverride!();
      return rows.map(_siteItemFromMap).toList()
        ..sort((_SiteItem a, _SiteItem b) => a.name.compareTo(b.name));
    }

    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await firestoreService.firestore
          .collection('sites')
          .orderBy('name')
          .limit(300)
          .get();
    } catch (_) {
      snapshot =
          await firestoreService.firestore.collection('sites').limit(300).get();
    }

    return snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
            _siteItemFromMap(<String, dynamic>{'id': doc.id, ...doc.data()}))
        .toList()
      ..sort((_SiteItem a, _SiteItem b) => a.name.compareTo(b.name));
  }

  _SiteItem _siteItemFromMap(Map<String, dynamic> data) {
    final List<dynamic> learnerIds =
        (data['learnerIds'] as List?) ?? <dynamic>[];
    final List<dynamic> educatorIds =
        (data['educatorIds'] as List?) ?? <dynamic>[];
    final String status =
        ((data['status'] as String?) ?? 'active').trim().toLowerCase();
    final int healthScore =
        _asInt(data['healthScore']) ?? _defaultHealth(status);

    return _SiteItem(
      id: (data['id'] as String?)?.trim().isNotEmpty == true
          ? (data['id'] as String).trim()
          : ((data['name'] as String?)?.trim().isNotEmpty == true
              ? (data['name'] as String).trim()
              : 'site'),
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? (data['name'] as String).trim()
          : ((data['id'] as String?)?.trim().isNotEmpty == true
              ? (data['id'] as String).trim()
              : 'Site'),
      location: (data['location'] as String?)?.trim().isNotEmpty == true
          ? (data['location'] as String).trim()
          : '—',
      learnerCount: _asInt(data['learnerCount']) ?? learnerIds.length,
      educatorCount: _asInt(data['educatorCount']) ?? educatorIds.length,
      status: _normalizeStatus(status),
      healthScore: healthScore,
    );
  }

  String _normalizeStatus(String status) {
    if (status == 'pending') return 'pending';
    if (status == 'onboarding' || status == 'provisioning') return 'onboarding';
    return 'active';
  }

  int _defaultHealth(String status) {
    switch (_normalizeStatus(status)) {
      case 'pending':
        return 0;
      case 'onboarding':
        return 70;
      default:
        return 90;
    }
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  FirestoreService? _maybeFirestoreService() {
    try {
      return context.read<FirestoreService>();
    } catch (_) {
      return null;
    }
  }

  AppState? _maybeAppState() {
    try {
      return context.read<AppState>();
    } catch (_) {
      return null;
    }
  }
}

class _SiteItem {
  const _SiteItem({
    required this.id,
    required this.name,
    required this.location,
    required this.learnerCount,
    required this.educatorCount,
    required this.status,
    required this.healthScore,
  });

  final String id;
  final String name;
  final String location;
  final int learnerCount;
  final int educatorCount;
  final String status;
  final int healthScore;
}

class _SiteCard extends StatelessWidget {
  const _SiteCard({
    required this.name,
    required this.location,
    required this.learnerCount,
    required this.educatorCount,
    required this.status,
    required this.healthScore,
    required this.onTap,
  });
  final String name;
  final String location;
  final int learnerCount;
  final int educatorCount;
  final String status;
  final int healthScore;
  final VoidCallback onTap;

  Color get _statusColor {
    switch (status) {
      case 'active':
        return ScholesaColors.success;
      case 'onboarding':
        return ScholesaColors.warning;
      case 'pending':
        return Colors.grey;
      default:
        return ScholesaColors.hq;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        surfaceTintColor: scheme.surfaceTint,
        child: InkWell(
          onTap: () {
            TelemetryService.instance.logEvent(
              event: 'cta.clicked',
              metadata: <String, dynamic>{
                'cta': 'hq_sites_site_card_tap',
                'site_name': name,
                'status': status,
              },
            );
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ScholesaColors.site.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.location_city,
                        color: ScholesaColors.site,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: scheme.onSurface,
                            ),
                          ),
                          Row(
                            children: <Widget>[
                              Icon(Icons.location_on,
                                  size: 14, color: scheme.onSurfaceVariant),
                              const SizedBox(width: 2),
                              Text(
                                location,
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _statusColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: _statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _SiteMetric(
                        icon: Icons.people,
                        value: learnerCount.toString(),
                        label: _tHqSites(context, 'Learners'),
                      ),
                    ),
                    Expanded(
                      child: _SiteMetric(
                        icon: Icons.school,
                        value: educatorCount.toString(),
                        label: _tHqSites(context, 'Educators'),
                      ),
                    ),
                    Expanded(
                      child: _HealthScore(score: healthScore),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SiteMetric extends StatelessWidget {
  const _SiteMetric({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              value,
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              label,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }
}

class _HealthScore extends StatelessWidget {
  const _HealthScore({required this.score});
  final int score;

  Color get _color {
    if (score >= 90) return ScholesaColors.success;
    if (score >= 70) return ScholesaColors.warning;
    if (score > 0) return ScholesaColors.error;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        SizedBox(
          width: 32,
          height: 32,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              CircularProgressIndicator(
                value: score / 100,
                backgroundColor: _color.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(_color),
                strokeWidth: 3,
              ),
              Text(
                score > 0 ? '$score' : '-',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Text(
          _tHqSites(context, 'Health'),
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 10),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.color,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color chipColor = color ?? ScholesaColors.hq;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color selectedLabelColor = chipColor == ScholesaColors.warning
        ? ScholesaColors.navy
        : Colors.white;
    return GestureDetector(
      onTap: () {
        TelemetryService.instance.logEvent(
          event: 'cta.clicked',
          metadata: <String, dynamic>{
            'cta': 'hq_sites_filter_chip',
            'label': label,
          },
        );
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? chipColor : chipColor.withValues(alpha: 0.45),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? selectedLabelColor : chipColor,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
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
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _CreateSiteSheet extends StatefulWidget {
  const _CreateSiteSheet({required this.onCreated});

  final VoidCallback onCreated;

  @override
  State<_CreateSiteSheet> createState() => _CreateSiteSheetState();
}

class _CreateSiteSheetState extends State<_CreateSiteSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
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
                  Text(
                    _tHqSites(context, 'Add New Site'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: _tHqSites(context, 'Site Name'),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _locationController,
                    decoration: InputDecoration(
                      labelText: _tHqSites(context, 'Location'),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        TelemetryService.instance.logEvent(
                          event: 'cta.clicked',
                          metadata: <String, dynamic>{
                            'cta': 'hq_sites_create_site_submit',
                            'has_name': _nameController.text.trim().isNotEmpty,
                            'has_location':
                                _locationController.text.trim().isNotEmpty,
                          },
                        );
                        await _submitCreateSite();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ScholesaColors.hq,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(_tHqSites(context, 'Create Site')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitCreateSite() async {
    final String name = _nameController.text.trim();
    final String location = _locationController.text.trim();
    if (name.isEmpty) {
      Navigator.pop(context);
      return;
    }

    final FirestoreService? firestoreService = _maybeFirestoreService();
    if (firestoreService == null) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tHqSites(context, 'Create site failed')),
          backgroundColor: ScholesaColors.error,
        ),
      );
      return;
    }

    try {
      await firestoreService.firestore
          .collection('sites')
          .add(<String, dynamic>{
        'name': name,
        'location': location,
        'status': 'pending',
        'learnerIds': <String>[],
        'educatorIds': <String>[],
        'healthScore': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      widget.onCreated();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tHqSites(context, 'Site created successfully')),
          backgroundColor: ScholesaColors.success,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tHqSites(context, 'Create site failed')),
          backgroundColor: ScholesaColors.error,
        ),
      );
    }
  }

  FirestoreService? _maybeFirestoreService() {
    try {
      return context.read<FirestoreService>();
    } catch (_) {
      return null;
    }
  }
}
