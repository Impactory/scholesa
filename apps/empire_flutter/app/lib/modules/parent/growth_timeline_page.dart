import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/app_state.dart';
import '../../i18n/evidence_chain_i18n.dart';
import '../../services/firestore_service.dart';

/// Rich growth timeline for parents showing capability progression over time.
/// Loads capability growth events for linked learners and displays them
/// as a vertical timeline with pillar color-coding and summary stats.
class GrowthTimelinePage extends StatefulWidget {
  const GrowthTimelinePage({super.key});

  @override
  State<GrowthTimelinePage> createState() => _GrowthTimelinePageState();
}

class _GrowthTimelinePageState extends State<GrowthTimelinePage> {
  static const String _growthTimelineLoadErrorMessage =
      'We could not load this growth timeline right now. Refresh, or check again after the app reconnects.';

  List<Map<String, dynamic>> _growthEvents = <Map<String, dynamic>>[];
  Map<String, String> _capabilityNames = <String, String>{};
  bool _isLoading = true;
  String? _error;

  FirestoreService get _firestoreService => context.read<FirestoreService>();

  String _t(String input) => EvidenceChainI18n.text(context, input);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGrowthTimeline();
    });
  }

  Future<void> _loadGrowthTimeline() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final AppState appState = context.read<AppState>();
      final String? parentId = appState.userId;

      if (parentId == null || parentId.isEmpty) {
        setState(() {
          _error = 'User not authenticated.';
          _isLoading = false;
        });
        return;
      }

      // Find linked learners via guardian links
      final List<Map<String, dynamic>> guardianLinks =
          await _firestoreService.queryCollection(
        'guardianLinks',
        where: <List<dynamic>>[
          <dynamic>['guardianId', parentId],
        ],
      );

      if (guardianLinks.isEmpty) {
        setState(() {
          _growthEvents = <Map<String, dynamic>>[];
          _isLoading = false;
        });
        return;
      }

      // Collect all growth events for linked learners
      final List<Map<String, dynamic>> allEvents = <Map<String, dynamic>>[];
      final Set<String> capabilityIds = <String>{};

      for (final Map<String, dynamic> link in guardianLinks) {
        final String learnerId = link['learnerId'] as String? ?? '';
        if (learnerId.isEmpty) continue;

        final List<Map<String, dynamic>> events =
            await _firestoreService.getGrowthEventsByLearner(learnerId);

        // Attach learner name for display
        final String learnerName = link['learnerName'] as String? ??
            link['learnerId'] as String? ??
            'Learner';
        for (final Map<String, dynamic> event in events) {
          event['_learnerName'] = learnerName;
          final String capId = event['capabilityId'] as String? ?? '';
          if (capId.isNotEmpty) capabilityIds.add(capId);
        }
        allEvents.addAll(events);
      }

      // Sort by date descending
      allEvents.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
        final Timestamp? aTs = a['createdAt'] as Timestamp?;
        final Timestamp? bTs = b['createdAt'] as Timestamp?;
        if (aTs == null && bTs == null) return 0;
        if (aTs == null) return 1;
        if (bTs == null) return -1;
        return bTs.compareTo(aTs);
      });

      // Load capability names for display
      final Map<String, String> capNames = <String, String>{};
      for (final String capId in capabilityIds) {
        final Map<String, dynamic>? capDoc =
            await _firestoreService.getDocument('capabilities', capId);
        if (capDoc != null) {
          capNames[capId] = capDoc['name'] as String? ?? capId;
        }
      }

      setState(() {
        _growthEvents = allEvents;
        _capabilityNames = capNames;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load parent growth timeline: $e');
      setState(() {
        _error = _growthTimelineLoadErrorMessage;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('Growth Timeline')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.error_outline,
                          size: 48, color: theme.colorScheme.error),
                      const SizedBox(height: 12),
                      Text(_t(_error!), style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _loadGrowthTimeline,
                        icon: const Icon(Icons.refresh),
                        label: Text(_t('Retry')),
                      ),
                    ],
                  ),
                )
              : _growthEvents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.timeline_outlined,
                              size: 48, color: theme.colorScheme.primary),
                          const SizedBox(height: 12),
                          Text(_t('No growth events recorded yet.'),
                              style: theme.textTheme.bodyLarge),
                          const SizedBox(height: 4),
                          Text(
                            _t('Growth events appear as educators assess capabilities.'),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadGrowthTimeline,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: <Widget>[
                          _buildSummaryCard(),
                          const SizedBox(height: 16),
                          Text(_t('Timeline'),
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          ..._growthEvents.asMap().entries.map(
                              (MapEntry<int, Map<String, dynamic>> entry) =>
                                  _buildTimelineEvent(entry.value, entry.key)),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildSummaryCard() {
    final ThemeData theme = Theme.of(context);
    final int totalEvents = _growthEvents.length;
    final Set<String> advancingCaps = <String>{};
    String? latestMilestone;

    for (final Map<String, dynamic> event in _growthEvents) {
      final String capId = event['capabilityId'] as String? ?? '';
      if (capId.isNotEmpty) advancingCaps.add(capId);
    }

    if (_growthEvents.isNotEmpty) {
      final Map<String, dynamic> latest = _growthEvents.first;
      final String capName =
          _capabilityNames[latest['capabilityId'] as String? ?? ''] ??
              'Unknown';
      final String toLevel = latest['toLevel'] as String? ?? '';
      latestMilestone = '$capName reached $toLevel';
    }

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(_t('Growth Summary'), style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                _SummaryItem(
                  icon: Icons.trending_up,
                  value: totalEvents.toString(),
                  label: _t('Growth Events'),
                ),
                const SizedBox(width: 24),
                _SummaryItem(
                  icon: Icons.category_outlined,
                  value: advancingCaps.length.toString(),
                  label: _t('Capabilities'),
                ),
              ],
            ),
            if (latestMilestone != null) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Icon(Icons.star,
                      size: 18, color: theme.colorScheme.onPrimaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_t('Latest:')} $latestMilestone',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineEvent(Map<String, dynamic> event, int index) {
    final ThemeData theme = Theme.of(context);
    final String capId = event['capabilityId'] as String? ?? '';
    final String capName = _capabilityNames[capId] ?? capId;
    final String? fromLevel = event['fromLevel'] as String?;
    final String toLevel = event['toLevel'] as String? ?? '';
    final String educatorId = event['educatorId'] as String? ?? '';
    final String learnerName = event['_learnerName'] as String? ?? '';
    final Timestamp? createdAt = event['createdAt'] as Timestamp?;
    final List<dynamic> evidenceIds =
        event['evidenceIds'] as List<dynamic>? ?? <dynamic>[];

    // Determine pillar color by looking up capability or using a default
    final Color pillarColor = _guessPillarColor(event);
    final bool isLast = index == _growthEvents.length - 1;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Timeline line and dot
          SizedBox(
            width: 32,
            child: Column(
              children: <Widget>[
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: pillarColor,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: pillarColor.withValues(alpha: 0.3),
                    ),
                  ),
              ],
            ),
          ),
          // Event card
          Expanded(
            child: Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child:
                              Text(capName, style: theme.textTheme.titleSmall),
                        ),
                        if (createdAt != null)
                          Text(
                            _formatDate(createdAt),
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Level transition
                    Row(
                      children: <Widget>[
                        if (fromLevel != null &&
                            fromLevel.isNotEmpty) ...<Widget>[
                          _LevelChip(level: fromLevel, muted: true),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(Icons.arrow_forward, size: 16),
                          ),
                        ],
                        _LevelChip(level: toLevel, muted: false),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (learnerName.isNotEmpty)
                      Text('${_t('Learner:')} $learnerName',
                          style: theme.textTheme.bodySmall),
                    if (educatorId.isNotEmpty)
                      Text('${_t('Assessed by:')} $educatorId',
                          style: theme.textTheme.bodySmall),
                    if (evidenceIds.isNotEmpty)
                      Text(
                        '${evidenceIds.length} ${evidenceIds.length == 1 ? _t('evidence item linked') : _t('evidence items linked')}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _guessPillarColor(Map<String, dynamic> event) {
    // Try to determine pillar from event or capability metadata
    final String pillar = event['pillarCode'] as String? ?? '';
    switch (pillar) {
      case 'futureSkills':
        return Colors.blue;
      case 'leadership':
        return Colors.purple;
      case 'impact':
        return Colors.green;
      default:
        // Fall back to a hash-based color from capability ID
        final String capId = event['capabilityId'] as String? ?? '';
        final int hash = capId.hashCode;
        final List<Color> fallbacks = <Color>[
          Colors.blue,
          Colors.purple,
          Colors.green
        ];
        return fallbacks[hash.abs() % fallbacks.length];
    }
  }

  String _formatDate(Timestamp ts) {
    final DateTime dt = ts.toDate();
    final List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 20, color: theme.colorScheme.onPrimaryContainer),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.level, required this.muted});

  final String level;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: muted ? Colors.grey.shade200 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        level,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: muted ? Colors.grey.shade600 : Colors.green.shade700,
        ),
      ),
    );
  }
}
