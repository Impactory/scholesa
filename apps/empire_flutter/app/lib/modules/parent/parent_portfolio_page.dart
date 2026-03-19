import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../i18n/parent_surface_i18n.dart';
import '../../services/export_service.dart';
import '../../services/firestore_service.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';
import '../../runtime/runtime.dart';
import '../../auth/app_state.dart';
import '../../ui/auth/global_session_menu.dart';
import 'parent_models.dart';
import 'parent_service.dart';

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
  static const String _canonicalLearnerUnavailableLabel = 'Learner unavailable';

  String _t(String input) {
    return ParentSurfaceI18n.text(context, input);
  }

  String _displayLearnerName(String learnerName) {
    final String normalized = learnerName.trim();
    if (normalized.isEmpty ||
        normalized == 'Unknown' ||
        normalized == _canonicalLearnerUnavailableLabel) {
      return _t('Learner unavailable');
    }
    return normalized;
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
        actions: const <Widget>[
          SessionMenuButton(
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
        ],
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
          if (service.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: ScholesaColors.parent),
            );
          }
          if (service.error != null) {
            return _buildLoadErrorState(
              message: _t('Unable to load portfolio right now'),
              onRetry: service.loadParentData,
            );
          }
          final List<_PortfolioItem> portfolioItems =
              _portfolioItemsFromService(service);
          return Column(
            children: <Widget>[
              _buildAiCoachingSection(context),
              if (service.learnerSummaries.isNotEmpty)
                _buildLearnerSnapshotStrip(service),
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

  Widget _buildLoadErrorState({
    required String message,
    required Future<void> Function() onRetry,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.error_outline_rounded,
                  color: scheme.error,
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () => onRetry(),
                  child: Text(_t('Retry')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLearnerSnapshotStrip(ParentService service) {
    return SizedBox(
      height: 272,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        scrollDirection: Axis.horizontal,
        itemCount: service.learnerSummaries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (BuildContext context, int index) =>
            _buildLearnerSnapshotCard(service.learnerSummaries[index]),
      ),
    );
  }

  Widget _buildLearnerSnapshotCard(LearnerSummary learner) {
    final Color accent = _getBandColor(learner.capabilitySnapshot.band);
    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ScholesaColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _displayLearnerName(learner.learnerName),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              _buildSnapshotChip(_t('Capability Snapshot'),
                  _t(_titleCaseBand(learner.capabilitySnapshot.band)), accent),
              const SizedBox(width: 8),
              _buildSnapshotChip(
                _t('Verified Portfolio'),
                '${learner.portfolioSnapshot.verifiedArtifactCount}',
                ScholesaColors.parentGradient.colors.first,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSnapshotMetric(
            _t('Artifacts'),
            '${learner.portfolioSnapshot.artifactCount}',
          ),
          _buildSnapshotMetric(
            _t('Evidence Linked'),
            '${learner.portfolioSnapshot.evidenceLinkedArtifactCount}',
          ),
          _buildSnapshotMetric(
            _t('Verified'),
            '${learner.portfolioSnapshot.verifiedArtifactCount}',
          ),
          _buildSnapshotMetric(
            _t('Reflections'),
            '${learner.ideationPassport.reflectionsSubmitted}',
          ),
        ],
      ),
    );
  }

  Widget _buildSnapshotChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: ScholesaColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSnapshotMetric(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: ScholesaColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioGrid(
      List<_PortfolioItem> portfolioItems, _ItemType? typeFilter) {
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
                  if (item.evidenceLinked ||
                      (item.verificationStatus?.trim().isNotEmpty ?? false) ||
                      (item.proofOfLearningStatus?.trim().isNotEmpty ?? false) ||
                      (item.aiDisclosureStatus?.trim().isNotEmpty ?? false))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: <Widget>[
                          if (item.evidenceLinked)
                            _buildMetaChip(
                              _t('Evidence linked'),
                              _getPillarColor(item.pillar),
                            ),
                          if (item.verificationStatus?.trim().isNotEmpty ?? false)
                            _buildMetaChip(
                              _titleCaseBand(item.verificationStatus!),
                              Colors.teal,
                            ),
                          if (item.proofOfLearningStatus?.trim().isNotEmpty ?? false)
                            _buildMetaChip(
                              _formatProofStatus(item.proofOfLearningStatus),
                              Colors.indigo,
                            ),
                          if (item.aiDisclosureStatus?.trim().isNotEmpty ?? false)
                            _buildMetaChip(
                              _formatAiDisclosure(item.aiDisclosureStatus),
                              Colors.deepOrange,
                            ),
                        ],
                      ),
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

  Widget _buildMetaChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
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
    final BuildContext rootContext = context;
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
                    item.type == _ItemType.badge ? _t('Badge') : _t('Project'),
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
            if (item.evidenceLinked ||
                (item.verificationStatus?.trim().isNotEmpty ?? false) ||
                (item.proofOfLearningStatus?.trim().isNotEmpty ?? false) ||
                (item.aiDisclosureStatus?.trim().isNotEmpty ?? false)) ...<Widget>[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  if (item.evidenceLinked)
                    _buildMetaChip(
                      _t('Evidence linked'),
                      _getPillarColor(item.pillar),
                    ),
                  if (item.verificationStatus?.trim().isNotEmpty ?? false)
                    _buildMetaChip(
                      _titleCaseBand(item.verificationStatus!),
                      Colors.teal,
                    ),
                  if (item.proofOfLearningStatus?.trim().isNotEmpty ?? false)
                    _buildMetaChip(
                      _formatProofStatus(item.proofOfLearningStatus),
                      Colors.indigo,
                    ),
                  if (item.aiDisclosureStatus?.trim().isNotEmpty ?? false)
                    _buildMetaChip(
                      _formatAiDisclosure(item.aiDisclosureStatus),
                      Colors.deepOrange,
                    ),
                ],
              ),
            ],
            if (item.capabilityTitles.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Text(
                _t('Capability Evidence'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: item.capabilityTitles
                    .where((String value) => value.trim().isNotEmpty)
                    .map((String title) =>
                        _buildMetaChip(title, _getPillarColor(item.pillar)))
                    .toList(growable: false),
              ),
            ],
            if (item.verificationPrompt?.trim().isNotEmpty ?? false) ...<Widget>[
              const SizedBox(height: 16),
              Text(
                _t('Verification Prompt'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(item.verificationPrompt!, style: const TextStyle(fontSize: 14)),
            ],
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final Widget shareButton = OutlinedButton.icon(
                  onPressed: () async {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: <String, dynamic>{
                        'cta': 'parent_portfolio_share_item',
                        'item_id': item.id,
                      },
                    );
                    Navigator.pop(context);
                    await _requestPortfolioSupport(
                      rootContext,
                      item: item,
                      requestType: 'share',
                    );
                  },
                  icon: const Icon(Icons.share_rounded),
                  label: Text(_t('Request Share')),
                );
                final Widget downloadButton = ElevatedButton.icon(
                  onPressed: () async {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: <String, dynamic>{
                        'cta': 'parent_portfolio_download_item',
                        'item_id': item.id,
                      },
                    );
                    Navigator.pop(context);
                    await _requestPortfolioSupport(
                      rootContext,
                      item: item,
                      requestType: 'download',
                    );
                  },
                  icon: const Icon(Icons.download_rounded),
                  label: Text(_t('Download Summary')),
                );

                if (constraints.maxWidth < 560) {
                  return Column(
                    children: <Widget>[
                      SizedBox(width: double.infinity, child: shareButton),
                      const SizedBox(height: 12),
                      SizedBox(width: double.infinity, child: downloadButton),
                    ],
                  );
                }

                return Row(
                  children: <Widget>[
                    Expanded(child: shareButton),
                    const SizedBox(width: 12),
                    Expanded(child: downloadButton),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestPortfolioSupport(
    BuildContext context, {
    required _PortfolioItem item,
    required String requestType,
  }) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      if (requestType == 'share') {
        final String requestId = await _submitPortfolioShareRequest(
          context,
          item: item,
        );
        TelemetryService.instance.logEvent(
          event: 'parent.portfolio_share_request.submitted',
          metadata: <String, dynamic>{
            'request_id': requestId,
            'item_id': item.id,
          },
        );
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(_t('Portfolio share request submitted.')),
          ),
        );
        return;
      }

      final String? savedLocation = await ExportService.instance.saveTextFile(
        fileName: _portfolioSummaryFileName(item),
        content: _buildPortfolioSummary(context, item),
      );
      if (savedLocation == null || !mounted) {
        return;
      }
      TelemetryService.instance.logEvent(
        event: 'export.downloaded',
        metadata: <String, dynamic>{
          'module': 'parent_portfolio',
          'surface': 'portfolio_detail_sheet',
          'item_id': item.id,
          'file_name': _portfolioSummaryFileName(item),
        },
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(_t('Portfolio summary downloaded.')),
        ),
      );
    } catch (error) {
      debugPrint(
          'Failed to process parent portfolio $requestType request: $error');
      final String failureEvent = requestType == 'share'
          ? 'parent.portfolio_share_request.failed'
          : 'parent.portfolio_download.failed';
      TelemetryService.instance.logEvent(
        event: failureEvent,
        metadata: <String, dynamic>{
          'item_id': item.id,
          'error': error.toString(),
        },
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _t(
              requestType == 'share'
                  ? 'Unable to submit portfolio share request right now.'
                  : 'Unable to download portfolio summary right now.',
            ),
          ),
        ),
      );
    }
  }

  FirestoreService? _maybeFirestoreService(BuildContext context) {
    try {
      return context.read<FirestoreService>();
    } catch (_) {
      return null;
    }
  }

  Future<String> _submitPortfolioShareRequest(
    BuildContext context, {
    required _PortfolioItem item,
  }) async {
    final FirestoreService? firestoreService = _maybeFirestoreService(context);
    if (firestoreService == null) {
      throw StateError(_t('Support requests are unavailable right now.'));
    }
    final AppState appState = context.read<AppState>();
    return firestoreService.submitSupportRequest(
      requestType: 'portfolio_share',
      source: 'parent_portfolio_request_share',
      siteId: appState.activeSiteId?.trim().isNotEmpty == true
          ? appState.activeSiteId!.trim()
          : 'Not set',
      userId: appState.userId?.trim().isNotEmpty == true
          ? appState.userId!.trim()
          : 'Not set',
      userEmail: appState.email?.trim().isNotEmpty == true
          ? appState.email!.trim()
          : 'Not set',
      userName: appState.displayName?.trim().isNotEmpty == true
          ? appState.displayName!.trim()
          : 'Not set',
      role: appState.role?.name ?? 'unknown',
      subject: 'Parent portfolio share request',
      message: <String>[
        'Please review and share this portfolio item through the approved parent-safe process.',
        '',
        'Portfolio Item ID: ${item.id}',
        'Title: ${item.title}',
        'Pillar: ${item.pillar}',
        'Completed At: ${item.completedAt.toIso8601String()}',
      ].join('\n'),
      metadata: <String, dynamic>{
        'itemId': item.id,
        'itemTitle': item.title,
        'pillar': item.pillar,
        'itemType': item.type.name,
        'completedAt': item.completedAt.toIso8601String(),
      },
    );
  }

  String _portfolioSummaryFileName(_PortfolioItem item) {
    return 'portfolio-summary-${item.id}.txt';
  }

  String _buildPortfolioSummary(BuildContext context, _PortfolioItem item) {
    return <String>[
      _t('Portfolio'),
      '${_t('Portfolio Item ID')}: ${item.id}',
      '${_t('Completed')}: ${item.completedAt.toIso8601String()}',
      '${_t('Type')}: ${item.type == _ItemType.project ? _t('Project') : _t('Badge')}',
      '${_t('Pillar')}: ${item.pillar}',
      '${_t('Title')}: ${item.title}',
      '${_t('Description')}: ${item.description}',
      '${_t('Evidence Linked')}: ${item.evidenceLinked ? _t('Yes') : _t('No')}',
      '${_t('Verification Status')}: ${item.verificationStatus?.trim().isNotEmpty == true ? _titleCaseBand(item.verificationStatus!) : _t('Pending')}',
      '${_t('Proof of Learning')}: ${_formatProofStatus(item.proofOfLearningStatus)}',
      '${_t('AI Disclosure')}: ${_formatAiDisclosure(item.aiDisclosureStatus)}',
      if (item.capabilityTitles.isNotEmpty)
        '${_t('Capability Evidence')}: ${item.capabilityTitles.join(', ')}',
      if (item.verificationPrompt?.trim().isNotEmpty == true)
        '${_t('Verification Prompt')}: ${item.verificationPrompt}',
      if (item.evidenceRecordIds.isNotEmpty)
        '${_t('Evidence Record IDs')}: ${item.evidenceRecordIds.join(', ')}',
      if (item.missionAttemptId?.trim().isNotEmpty == true)
        '${_t('Mission Attempt ID')}: ${item.missionAttemptId}',
    ].join('\n');
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  List<_PortfolioItem> _portfolioItemsFromService(ParentService service) {
    final List<_PortfolioItem> items = <_PortfolioItem>[];

    for (final LearnerSummary learner in service.learnerSummaries) {
      for (final PortfolioPreviewItem item in learner.portfolioItemsPreview) {
        items.add(
          _PortfolioItem(
            id: item.id,
            title: item.title,
            pillar: item.pillar,
            type: item.type == 'badge' ? _ItemType.badge : _ItemType.project,
            completedAt: item.completedAt,
            imageUrl: null,
            description: item.description,
            verificationStatus: item.verificationStatus,
            evidenceLinked: item.evidenceLinked,
            capabilityTitles: item.capabilityTitles,
            evidenceRecordIds: item.evidenceRecordIds,
            missionAttemptId: item.missionAttemptId,
            verificationPrompt: item.verificationPrompt,
            proofOfLearningStatus: item.proofOfLearningStatus,
            aiDisclosureStatus: item.aiDisclosureStatus,
          ),
        );
      }
    }

    items.sort((_PortfolioItem a, _PortfolioItem b) =>
        b.completedAt.compareTo(a.completedAt));
    return items;
  }

  String _titleCaseBand(String value) {
    switch (value.trim().toLowerCase()) {
      case 'strong':
        return 'Strong';
      case 'developing':
        return 'Developing';
      case 'reviewed':
        return 'Reviewed';
      case 'verified':
        return 'Verified';
      default:
        return 'Emerging';
    }
  }

  String _formatProofStatus(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'verified':
        return _t('Proof verified');
      case 'partial':
        return _t('Proof partial');
      case 'missing':
        return _t('Proof missing');
      case 'not-available':
        return _t('No linked proof bundle');
      default:
        return _t('Proof status unknown');
    }
  }

  String _formatAiDisclosure(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'learner-ai-verified':
        return _t('Learner AI use disclosed with explain-back evidence');
      case 'learner-ai-verification-gap':
        return _t('Learner AI use detected without explain-back evidence');
      case 'learner-ai-not-used':
        return _t('Learner declared no AI support used');
      case 'educator-feedback-ai':
        return _t('AI-assisted educator feedback visible');
      case 'no-learner-ai-signal':
        return _t('No learner AI-use signal linked to this artifact');
      case 'not-available':
        return _t('No linked mission attempt');
      default:
        return _t('AI status unknown');
    }
  }

  Color _getBandColor(String value) {
    switch (value.trim().toLowerCase()) {
      case 'strong':
        return Colors.green;
      case 'developing':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  Widget _buildAiCoachingSection(BuildContext context) {
    final AppState appState = context.read<AppState>();
    final UserRole? role = appState.role;

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
              subtitle: Text(
                  _t('Get personalized coaching on supporting your child')),
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
    this.verificationStatus,
    this.evidenceLinked = false,
    this.capabilityTitles = const <String>[],
    this.evidenceRecordIds = const <String>[],
    this.missionAttemptId,
    this.verificationPrompt,
    this.proofOfLearningStatus,
    this.aiDisclosureStatus,
  });

  final String id;
  final String title;
  final String pillar;
  final _ItemType type;
  final DateTime completedAt;
  final String? imageUrl;
  final String description;
  final String? verificationStatus;
  final bool evidenceLinked;
  final List<String> capabilityTitles;
  final List<String> evidenceRecordIds;
  final String? missionAttemptId;
  final String? verificationPrompt;
  final String? proofOfLearningStatus;
  final String? aiDisclosureStatus;
}
