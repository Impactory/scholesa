import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/telemetry_service.dart';
import '../../services/firestore_service.dart';
import '../../ui/auth/global_session_menu.dart';
import '../../ui/theme/scholesa_theme.dart';
import '../../runtime/runtime.dart';
import '../../i18n/bos_coaching_i18n.dart';
import '../../i18n/workflow_surface_i18n.dart';
import '../../auth/app_state.dart';
import 'educator_models.dart';
import 'educator_service.dart';

String _tEducatorLearnerSupports(BuildContext context, String input) {
  return WorkflowSurfaceI18n.text(context, input);
}

typedef LearnerSupportPlansLoader = Future<List<Map<String, dynamic>>> Function(
  BuildContext context,
  String siteId,
);

/// Educator learner supports page for tracking learner wellbeing & accommodations
/// Based on docs/09_LEARNER_SUPPORT_ACCOMMODATIONS_SPEC.md
class EducatorLearnerSupportsPage extends StatefulWidget {
  const EducatorLearnerSupportsPage({
    this.supportPlansLoader,
    super.key,
  });

  final LearnerSupportPlansLoader? supportPlansLoader;

  @override
  State<EducatorLearnerSupportsPage> createState() =>
      _EducatorLearnerSupportsPageState();
}

class _EducatorLearnerSupportsPageState
    extends State<EducatorLearnerSupportsPage> {
  static const String _supportPlansCollection = 'learnerSupportPlans';
  static const String _supportOutcomesCollection = 'learnerSupportOutcomes';

  Map<String, _PersistedSupportPlan> _supportPlanOverrides =
      <String, _PersistedSupportPlan>{};
  String _searchQuery = '';
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSupportPlansAndLearners();
    });
    TelemetryService.instance.logEvent(
      event: 'insight.viewed',
      metadata: const <String, dynamic>{
        'surface': 'educator_learner_supports',
        'insight_type': 'support_overview',
      },
    );
  }

  Future<void> _loadSupportPlansAndLearners() async {
    await context.read<EducatorService>().loadLearners();
    await _loadPersistedSupportPlans();
  }

  String _activeSiteId() {
    final String siteId = (context.read<AppState>().activeSiteId ?? '').trim();
    return siteId;
  }

  Future<bool> _loadPersistedSupportPlans() async {
    final String siteId = _activeSiteId();
    if (siteId.isEmpty || !mounted) {
      return false;
    }

    setState(() {
      _loadError = null;
    });

    try {
      // ignore: use_build_context_synchronously
      final BuildContext ctx = context;
      final List<Map<String, dynamic>> rows = widget.supportPlansLoader != null
          ? await widget.supportPlansLoader!(ctx, siteId) // ignore: use_build_context_synchronously
          : await _loadPersistedSupportPlanRows(siteId);
      final Map<String, _PersistedSupportPlan> nextOverrides =
          <String, _PersistedSupportPlan>{};
      for (final Map<String, dynamic> row in rows) {
        final _PersistedSupportPlan? plan = _PersistedSupportPlan.fromMap(row);
        if (plan == null) {
          continue;
        }
        nextOverrides[plan.learnerId] = plan;
      }

      if (!mounted) {
        return false;
      }
      setState(() {
        _supportPlanOverrides = nextOverrides;
        _loadError = null;
      });
      return true;
    } catch (error) {
      debugPrint('Failed to load learner support plans: $error');
      if (!mounted) {
        return false;
      }
      setState(() {
        _loadError = 'Failed to load learner supports: $error';
      });
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> _loadPersistedSupportPlanRows(
    String siteId,
  ) async {
    final FirestoreService firestoreService = context.read<FirestoreService>();
    final QuerySnapshot<Map<String, dynamic>> snapshot = await firestoreService
        .firestore
        .collection(_supportPlansCollection)
        .where('siteId', isEqualTo: siteId)
        .get();

    return snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
          final Map<String, dynamic> row = Map<String, dynamic>.from(doc.data());
          row['documentId'] = doc.id;
          return row;
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return MiloRuntimeScope(child: Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: Text(_tEducatorLearnerSupports(context, 'Learner Supports')),
        backgroundColor: ScholesaColors.educatorGradient.colors.first,
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            tooltip: _tEducatorLearnerSupports(context, 'Refresh'),
            onPressed: _loadSupportPlansAndLearners,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: _showSearchDialog,
          ),
          const SessionMenuButton(
            foregroundColor: Colors.white,
          ),
        ],
      ),
      body: Consumer<EducatorService>(
        builder: (BuildContext context, EducatorService service, _) {
          final List<_LearnerSupport> supports = _supportsFromService(service);
          final List<_LearnerSupport> visibleSupports =
              _applySearchFilter(supports);
          final String? effectiveError = service.error ?? _loadError;
          final bool shouldBlockForLoadFailure =
              (service.error != null && supports.isEmpty) ||
                  (_loadError != null && _supportPlanOverrides.isEmpty);

          if (service.isLoading && supports.isEmpty && effectiveError == null) {
            return Center(
              child: Text(
                _tEducatorLearnerSupports(context, 'Loading...'),
                style: const TextStyle(color: ScholesaColors.textSecondary),
              ),
            );
          }

          if (effectiveError != null && shouldBlockForLoadFailure) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildLoadErrorState(effectiveError),
              ),
            );
          }

          if (supports.isEmpty) {
            return Center(
              child: Text(
                _tEducatorLearnerSupports(context, 'No support plans yet'),
                style: const TextStyle(color: ScholesaColors.textSecondary),
              ),
            );
          }

          if (visibleSupports.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                if (_searchQuery.isNotEmpty) _buildSearchBanner(),
                const SizedBox(height: 24),
                Center(
                  child: Column(
                    children: <Widget>[
                      const Icon(
                        Icons.search_off_rounded,
                        size: 48,
                        color: ScholesaColors.textSecondary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _tEducatorLearnerSupports(
                          context,
                          'No matching support plans',
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          color: ScholesaColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              if (effectiveError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildStaleDataBanner(effectiveError),
                ),
              AiContextCoachSection(
                title: _tEducatorLearnerSupports(context, 'Support MiloOS'),
                subtitle: _tEducatorLearnerSupports(
                  context,
                  'See support ideas for each learner support plan',
                ),
                module: 'educator_learner_supports',
                surface: 'support_plans',
                actorRole: UserRole.educator,
                accentColor: ScholesaColors.educator,
                conceptTags: const <String>[
                  'learner_supports',
                  'accommodations',
                  'wellbeing',
                ],
              ),
              if (service.learners.isNotEmpty)
                BosLearnerLoopInsightsCard(
                  title: BosCoachingI18n.sessionLoopTitle(context),
                  subtitle: BosCoachingI18n.sessionLoopSubtitle(context),
                  emptyLabel: BosCoachingI18n.sessionLoopEmpty(context),
                  learnerId: service.learners.first.id,
                  learnerName: service.learners.first.name,
                  accentColor: ScholesaColors.educator,
                ),
              _buildSummaryCards(visibleSupports),
              if (_searchQuery.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                _buildSearchBanner(),
              ],
              const SizedBox(height: 24),
              Text(
                _tEducatorLearnerSupports(context, 'Active Support Plans'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ScholesaColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ...visibleSupports.map((support) => _buildSupportCard(support)),
            ],
          );
        },
      ),
    ));
  }

  Widget _buildSearchBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ScholesaColors.educator.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ScholesaColors.educator.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.search_rounded, color: ScholesaColors.educator),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${_tEducatorLearnerSupports(context, 'Showing results for')}: "$_searchQuery"',
              style: const TextStyle(color: ScholesaColors.textPrimary),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _searchQuery = '';
              });
            },
            child: Text(_tEducatorLearnerSupports(context, 'Clear Search')),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadErrorState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.error_outline_rounded, color: ScholesaColors.error),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _tEducatorLearnerSupports(
                    context,
                    'We could not load learner supports right now. Retry to check the current state.',
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ScholesaColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: ScholesaColors.textSecondary),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _loadSupportPlansAndLearners,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(_tEducatorLearnerSupports(context, 'Retry')),
          ),
        ],
      ),
    );
  }

  Widget _buildStaleDataBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _tEducatorLearnerSupports(
                    context,
                    'Unable to refresh learner supports right now. Showing the last successful data. ',
                  ) +
                  message,
              style: const TextStyle(color: Color(0xFF92400E)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(List<_LearnerSupport> supports) {
    final int highPriorityCount = supports
        .where((_LearnerSupport s) => s.priority == _Priority.high)
        .length;
    final DateTime now = DateTime.now();
    final int reviewsDue = supports
        .where((_LearnerSupport support) =>
            now.difference(support.lastUpdated).inDays >= 7)
        .length;

    return Row(
      children: <Widget>[
        Expanded(
          child: _buildSummaryCard(
            _tEducatorLearnerSupports(context, 'High Priority'),
            highPriorityCount.toString(),
            Colors.red,
            Icons.priority_high_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            _tEducatorLearnerSupports(context, 'Active Plans'),
            supports.length.toString(),
            Colors.blue,
            Icons.people_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            _tEducatorLearnerSupports(context, 'Reviews Due'),
            reviewsDue.toString(),
            Colors.orange,
            Icons.schedule_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
      String label, String value, Color color, IconData icon) {
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
            style: const TextStyle(
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
                    backgroundColor: ScholesaColors
                        .educatorGradient.colors.first
                        .withValues(alpha: 0.2),
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
                          _tEducatorLearnerSupports(
                              context, support.supportType),
                          style: const TextStyle(
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
                children: support.accommodations
                    .map((String a) => _buildAccommodationChip(
                        _tEducatorLearnerSupports(context, a)))
                    .toList(),
              ),
              if (support.notes.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  '${_tEducatorLearnerSupports(context, 'Note')}: ${_tEducatorLearnerSupports(context, support.notes)}',
                  style: const TextStyle(
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
        label = _tEducatorLearnerSupports(context, 'High');
      case _Priority.medium:
        color = Colors.orange;
        label = _tEducatorLearnerSupports(context, 'Medium');
      case _Priority.low:
        color = Colors.green;
        label = _tEducatorLearnerSupports(context, 'Low');
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

  Future<void> _showSupportDetails(_LearnerSupport support) async {
    bool popupCompleted = false;
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'educator_learner_supports',
        'cta_id': 'open_support_details',
        'surface': 'support_card',
        'learner_id': support.learnerId,
        'priority': support.priority.name,
      },
    );
    TelemetryService.instance.logEvent(
      event: 'insight.viewed',
      metadata: <String, dynamic>{
        'surface': 'educator_learner_supports',
        'insight_type': 'learner_support_plan',
        'learner_id': support.learnerId,
        'support_type': support.supportType,
      },
    );
    TelemetryService.instance.logEvent(
      event: 'popup.shown',
      metadata: <String, dynamic>{
        'popup_id': 'support_details_sheet',
        'surface': 'educator_learner_supports',
        'learner_id': support.learnerId,
      },
    );
    await showModalBottomSheet<void>(
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
        builder: (BuildContext context, ScrollController scrollController) =>
            ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 30,
                  backgroundColor: ScholesaColors.educatorGradient.colors.first
                      .withValues(alpha: 0.2),
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
                        '${_tEducatorLearnerSupports(context, 'Support Plan')} • ${_tEducatorLearnerSupports(context, support.supportType)}',
                        style: const TextStyle(
                            color: ScholesaColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              _tEducatorLearnerSupports(context, 'Accommodations'),
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
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Text(_tEducatorLearnerSupports(context, a)),
                    ],
                  ),
                )),
            const SizedBox(height: 16),
            Text(
              _tEducatorLearnerSupports(context, 'Notes'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              support.notes.isNotEmpty
                  ? _tEducatorLearnerSupports(context, support.notes)
                  : _tEducatorLearnerSupports(context, 'No notes'),
              style: const TextStyle(color: ScholesaColors.textSecondary),
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
                          'module': 'educator_learner_supports',
                          'cta_id': 'close_support_details',
                          'surface': 'support_details_sheet',
                          'learner_id': support.learnerId,
                        },
                      );
                      TelemetryService.instance.logEvent(
                        event: 'popup.dismissed',
                        metadata: <String, dynamic>{
                          'popup_id': 'support_details_sheet',
                          'surface': 'educator_learner_supports',
                          'learner_id': support.learnerId,
                        },
                      );
                      popupCompleted = true;
                      Navigator.pop(context);
                    },
                    child: Text(_tEducatorLearnerSupports(context, 'Close')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: <String, dynamic>{
                          'module': 'educator_learner_supports',
                          'cta_id': 'edit_support_plan',
                          'surface': 'support_details_sheet',
                          'learner_id': support.learnerId,
                        },
                      );
                      popupCompleted = true;
                      Navigator.pop(context);
                      await _showEditSupportPlanDialog(support);
                    },
                    child:
                        Text(_tEducatorLearnerSupports(context, 'Edit Plan')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (!popupCompleted) {
      TelemetryService.instance.logEvent(
        event: 'popup.dismissed',
        metadata: <String, dynamic>{
          'popup_id': 'support_details_sheet',
          'surface': 'educator_learner_supports',
          'learner_id': support.learnerId,
          'reason': 'closed_without_action',
        },
      );
    }
  }

  Future<void> _showSearchDialog() async {
    final List<_LearnerSupport> supports =
        _supportsFromService(context.read<EducatorService>());
    bool popupCompleted = false;
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'educator_learner_supports',
        'cta_id': 'open_search_dialog',
        'surface': 'appbar',
      },
    );
    TelemetryService.instance.logEvent(
      event: 'popup.shown',
      metadata: const <String, dynamic>{
        'popup_id': 'support_search_dialog',
        'surface': 'educator_learner_supports',
      },
    );
    final TextEditingController controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title:
            Text(_tEducatorLearnerSupports(context, 'Search Learner Supports')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: _tEducatorLearnerSupports(
                context, 'Enter learner name or support tag'),
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'module': 'educator_learner_supports',
                  'cta_id': 'cancel_search',
                  'surface': 'search_dialog',
                },
              );
              TelemetryService.instance.logEvent(
                event: 'popup.dismissed',
                metadata: const <String, dynamic>{
                  'popup_id': 'support_search_dialog',
                  'surface': 'educator_learner_supports',
                },
              );
              popupCompleted = true;
              Navigator.pop(dialogContext);
            },
            child: Text(_tEducatorLearnerSupports(context, 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              final String query = controller.text.trim().toLowerCase();
              final int matches = supports
                  .where((support) => _matchesSearchQuery(support, query))
                  .length;
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'module': 'educator_learner_supports',
                  'cta_id': 'submit_search',
                  'surface': 'search_dialog',
                  'query_length': query.length,
                  'matches': matches,
                },
              );
              TelemetryService.instance.logEvent(
                event: 'popup.completed',
                metadata: <String, dynamic>{
                  'popup_id': 'support_search_dialog',
                  'surface': 'educator_learner_supports',
                  'completion_action': 'search',
                  'matches': matches,
                },
              );
              popupCompleted = true;
              setState(() {
                _searchQuery = query;
              });
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        '${_tEducatorLearnerSupports(context, 'Found')} $matches ${_tEducatorLearnerSupports(context, 'matching support plans')}')),
              );
            },
            child: Text(_tEducatorLearnerSupports(context, 'Search')),
          ),
        ],
      ),
    );
    if (!popupCompleted) {
      TelemetryService.instance.logEvent(
        event: 'popup.dismissed',
        metadata: const <String, dynamic>{
          'popup_id': 'support_search_dialog',
          'surface': 'educator_learner_supports',
          'reason': 'closed_without_action',
        },
      );
    }
  }

  Future<void> _showOutcomeDialog(_LearnerSupport support) async {
    TelemetryService.instance.logEvent(
      event: 'popup.shown',
      metadata: <String, dynamic>{
        'popup_id': 'support_outcome_dialog',
        'surface': 'educator_learner_supports',
        'learner_id': support.learnerId,
      },
    );

    final String? outcome = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(_tEducatorLearnerSupports(context, 'Log Support Outcome')),
        content: Text(
          _tEducatorLearnerSupports(
              context, 'Select the outcome from this support action.'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'popup.dismissed',
                metadata: const <String, dynamic>{
                  'popup_id': 'support_outcome_dialog',
                  'surface': 'educator_learner_supports',
                },
              );
              Navigator.pop(dialogContext, null);
            },
            child: Text(_tEducatorLearnerSupports(context, 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'partial'),
            child: Text(_tEducatorLearnerSupports(context, 'Partial')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'no_change'),
            child: Text(_tEducatorLearnerSupports(context, 'No Change')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, 'helped'),
            child: Text(_tEducatorLearnerSupports(context, 'Helped')),
          ),
        ],
      ),
    );

    if (outcome == null) {
      return;
    }

    final bool saved = await _saveSupportOutcome(support, outcome);
    if (!saved) {
      return;
    }

    TelemetryService.instance.logEvent(
      event: 'support.outcome.logged',
      metadata: <String, dynamic>{
        'learner_id': support.learnerId,
        'support_type': support.supportType,
        'priority': support.priority.name,
        'outcome': outcome,
      },
    );
    TelemetryService.instance.logEvent(
      event: 'popup.completed',
      metadata: <String, dynamic>{
        'popup_id': 'support_outcome_dialog',
        'surface': 'educator_learner_supports',
        'completion_action': 'log_outcome',
        'outcome': outcome,
      },
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              '${_tEducatorLearnerSupports(context, 'Support outcome logged')}: $outcome')),
    );
  }

  Future<bool> _saveSupportOutcome(
    _LearnerSupport support,
    String outcome,
  ) async {
    final String siteId = _activeSiteId();
    if (siteId.isEmpty) {
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tEducatorLearnerSupports(
              context,
              'Unable to log support outcome right now.',
            ),
          ),
        ),
      );
      return false;
    }

    try {
      final FirestoreService firestoreService = context.read<FirestoreService>();
      final AppState appState = context.read<AppState>();
      await firestoreService.createDocument(
        _supportOutcomesCollection,
        <String, dynamic>{
          'siteId': siteId,
          'learnerId': support.learnerId,
          'learnerName': support.learnerName,
          'supportType': support.supportType,
          'priority': support.priority.name,
          'outcome': outcome,
          'loggedAt': Timestamp.fromDate(DateTime.now()),
          'supportPlanId': _supportPlanOverrides[support.learnerId]?.documentId,
          'loggedBy': (appState.userId ?? '').trim(),
          'loggedByName': (appState.displayName ?? '').trim(),
        },
      );
      return true;
    } catch (error) {
      debugPrint('Failed to log support outcome: $error');
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tEducatorLearnerSupports(
              context,
              'Unable to log support outcome right now.',
            ),
          ),
        ),
      );
      return false;
    }
  }

  Future<void> _showEditSupportPlanDialog(_LearnerSupport support) async {
    final TextEditingController accommodationsController =
        TextEditingController(text: support.accommodations.join(', '));
    final TextEditingController notesController =
        TextEditingController(text: support.notes);
    String selectedSupportType = support.supportType;
    _Priority selectedPriority = support.priority;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (
          BuildContext innerContext,
          void Function(void Function()) setLocalState,
        ) {
          return AlertDialog(
            title:
                Text(_tEducatorLearnerSupports(context, 'Edit Support Plan')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    initialValue: selectedSupportType,
                    decoration: InputDecoration(
                      labelText:
                          _tEducatorLearnerSupports(context, 'Support Type'),
                    ),
                    items: const <String>[
                      'Academic',
                      'Social-Emotional',
                      'Behavioral',
                    ].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(_tEducatorLearnerSupports(context, value)),
                      );
                    }).toList(growable: false),
                    onChanged: (String? value) {
                      if (value == null) {
                        return;
                      }
                      setLocalState(() {
                        selectedSupportType = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<_Priority>(
                    initialValue: selectedPriority,
                    decoration: InputDecoration(
                      labelText: _tEducatorLearnerSupports(context, 'Priority'),
                    ),
                    items: _Priority.values.map((_Priority value) {
                      return DropdownMenuItem<_Priority>(
                        value: value,
                        child: Text(
                          _tEducatorLearnerSupports(
                            context,
                            value.name[0].toUpperCase() + value.name.substring(1),
                          ),
                        ),
                      );
                    }).toList(growable: false),
                    onChanged: (_Priority? value) {
                      if (value == null) {
                        return;
                      }
                      setLocalState(() {
                        selectedPriority = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: accommodationsController,
                    minLines: 2,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: _tEducatorLearnerSupports(
                        context,
                        'Accommodations (comma separated)',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: _tEducatorLearnerSupports(context, 'Notes'),
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(_tEducatorLearnerSupports(context, 'Cancel')),
              ),
              ElevatedButton(
                onPressed: () async {
                  final List<String> accommodations = accommodationsController
                      .text
                      .split(',')
                      .map((String value) => value.trim())
                      .where((String value) => value.isNotEmpty)
                      .toList(growable: false);
                  final String notes = notesController.text.trim();

                  final _LearnerSupport updatedSupport = support.copyWith(
                    supportType: selectedSupportType,
                    accommodations: accommodations,
                    notes: notes,
                    priority: selectedPriority,
                    lastUpdated: DateTime.now(),
                  );

                  final bool saved = await _saveSupportPlan(updatedSupport);
                  if (!saved) {
                    return;
                  }

                  if (!dialogContext.mounted) {
                    return;
                  }
                  Navigator.pop(dialogContext);
                  if (!mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _tEducatorLearnerSupports(
                          context,
                          'Support plan updated.',
                        ),
                      ),
                    ),
                  );
                  await _showOutcomeDialog(updatedSupport);
                },
                child: Text(_tEducatorLearnerSupports(context, 'Save')),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<bool> _saveSupportPlan(_LearnerSupport support) async {
    final String siteId = _activeSiteId();
    if (siteId.isEmpty) {
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tEducatorLearnerSupports(
              context,
              'Unable to update support plan right now.',
            ),
          ),
        ),
      );
      return false;
    }

    try {
      final FirestoreService firestoreService = context.read<FirestoreService>();
      final AppState appState = context.read<AppState>();
      final _PersistedSupportPlan? existing =
          _supportPlanOverrides[support.learnerId];
      final Map<String, dynamic> payload = <String, dynamic>{
        'siteId': siteId,
        'learnerId': support.learnerId,
        'learnerName': support.learnerName,
        'supportType': support.supportType,
        'priority': support.priority.name,
        'accommodations': support.accommodations,
        'notes': support.notes,
        'lastUpdated': Timestamp.fromDate(support.lastUpdated),
        'updatedBy': (appState.userId ?? '').trim(),
        'updatedByName': (appState.displayName ?? '').trim(),
      };

      String documentId = existing?.documentId ?? '';
      if (documentId.isEmpty) {
        documentId = await firestoreService.createDocument(
          _supportPlansCollection,
          payload,
        );
      } else {
        await firestoreService.updateDocument(
          _supportPlansCollection,
          documentId,
          payload,
        );
      }

      final bool reloaded = await _loadPersistedSupportPlans();
      if (!mounted) {
        return false;
      }
      final _PersistedSupportPlan? persistedPlan =
          _supportPlanOverrides[support.learnerId];
      if (!reloaded) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _tEducatorLearnerSupports(
                context,
                'Support plan was submitted, but persisted support data could not be reloaded. Retry to verify the current state.',
              ),
            ),
          ),
        );
        return false;
      }
      if (persistedPlan == null ||
          persistedPlan.supportType != support.supportType ||
          persistedPlan.priority != support.priority ||
          persistedPlan.notes != support.notes ||
          !_listEquals(
            persistedPlan.accommodations,
            support.accommodations,
          )) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _tEducatorLearnerSupports(
                context,
                'The saved support plan did not match the latest persisted record. Retry to verify the current state.',
              ),
            ),
          ),
        );
        return false;
      }

      TelemetryService.instance.logEvent(
        event: 'support.plan_updated',
        metadata: <String, dynamic>{
          'learner_id': support.learnerId,
          'support_type': support.supportType,
          'priority': support.priority.name,
          'accommodation_count': support.accommodations.length,
        },
      );
      return true;
    } catch (error) {
      debugPrint('Failed to update support plan: $error');
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tEducatorLearnerSupports(
              context,
              'Unable to update support plan right now.',
            ),
          ),
        ),
      );
      return false;
    }
  }

  bool _listEquals(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (int index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  List<_LearnerSupport> _supportsFromService(EducatorService service) {
    final List<EducatorLearner> learners = service.learners;
    final List<_LearnerSupport> supports = <_LearnerSupport>[];

    for (int index = 0; index < learners.length; index++) {
      final EducatorLearner learner = learners[index];
      final _Priority priority = _priorityForLearner(learner);
      final String supportType = _supportTypeForIndex(index);
      supports.add(
        _mergeSupportPlan(
          _LearnerSupport(
          learnerId: learner.id,
          learnerName: learner.name,
          avatarUrl: learner.photoUrl,
          supportType: supportType,
          accommodations: _accommodationsForPriority(priority),
          notes: _supportNoteForPriority(priority),
          lastUpdated:
              DateTime.now().subtract(Duration(days: (index % 10) + 1)),
          priority: priority,
          ),
        ),
      );
    }

    return supports;
  }

  _LearnerSupport _mergeSupportPlan(_LearnerSupport baseSupport) {
    final _PersistedSupportPlan? override =
        _supportPlanOverrides[baseSupport.learnerId];
    if (override == null) {
      return baseSupport;
    }
    return baseSupport.copyWith(
      supportType: override.supportType,
      accommodations: override.accommodations,
      notes: override.notes,
      priority: override.priority,
      lastUpdated: override.lastUpdated,
    );
  }

  List<_LearnerSupport> _applySearchFilter(List<_LearnerSupport> supports) {
    final String query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return supports;
    }
    return supports
        .where((_LearnerSupport support) => _matchesSearchQuery(support, query))
        .toList(growable: false);
  }

  bool _matchesSearchQuery(_LearnerSupport support, String query) {
    if (query.isEmpty) {
      return true;
    }
    final List<String> haystacks = <String>[
      support.learnerName,
      support.supportType,
      support.notes,
      support.priority.name,
      ...support.accommodations,
    ];
    return haystacks.any(
      (String value) => value.toLowerCase().contains(query),
    );
  }

  _Priority _priorityForLearner(EducatorLearner learner) {
    if (learner.attendanceRate < 60) {
      return _Priority.high;
    }
    if (learner.attendanceRate < 80) {
      return _Priority.medium;
    }
    return _Priority.low;
  }

  String _supportTypeForIndex(int index) {
    switch (index % 3) {
      case 0:
        return 'Academic';
      case 1:
        return 'Social-Emotional';
      default:
        return 'Behavioral';
    }
  }

  List<String> _accommodationsForPriority(_Priority priority) {
    switch (priority) {
      case _Priority.high:
        return <String>['Check-in support', 'Peer buddy'];
      case _Priority.medium:
        return <String>['Extended time', 'Quiet space'];
      case _Priority.low:
        return <String>['Movement breaks', 'Clear transitions'];
    }
  }

  String _supportNoteForPriority(_Priority priority) {
    switch (priority) {
      case _Priority.high:
        return 'Building confidence in group settings';
      case _Priority.medium:
        return 'Responds well to visual aids';
      case _Priority.low:
        return 'Use positive reinforcement';
    }
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

  _LearnerSupport copyWith({
    String? supportType,
    List<String>? accommodations,
    String? notes,
    DateTime? lastUpdated,
    _Priority? priority,
  }) {
    return _LearnerSupport(
      learnerId: learnerId,
      learnerName: learnerName,
      avatarUrl: avatarUrl,
      supportType: supportType ?? this.supportType,
      accommodations: accommodations ?? this.accommodations,
      notes: notes ?? this.notes,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      priority: priority ?? this.priority,
    );
  }
}

class _PersistedSupportPlan {
  const _PersistedSupportPlan({
    required this.documentId,
    required this.learnerId,
    required this.supportType,
    required this.accommodations,
    required this.notes,
    required this.priority,
    required this.lastUpdated,
  });

  final String documentId;
  final String learnerId;
  final String supportType;
  final List<String> accommodations;
  final String notes;
  final _Priority priority;
  final DateTime lastUpdated;

  static _PersistedSupportPlan? fromMap(Map<String, dynamic> data) {
    final String documentId = (data['documentId'] as String? ?? '').trim();
    final String learnerId = (data['learnerId'] as String? ?? '').trim();
    if (documentId.isEmpty || learnerId.isEmpty) {
      return null;
    }
    final String supportType =
        (data['supportType'] as String? ?? 'Academic').trim();
    final List<String> accommodations =
        (data['accommodations'] as List<dynamic>? ?? <dynamic>[])
            .whereType<String>()
            .map((String value) => value.trim())
            .where((String value) => value.isNotEmpty)
            .toList(growable: false);
    final String notes = (data['notes'] as String? ?? '').trim();
    final String priorityName = (data['priority'] as String? ?? 'medium').trim();
    final dynamic lastUpdatedRaw = data['lastUpdated'];
    final DateTime lastUpdated = lastUpdatedRaw is Timestamp
        ? lastUpdatedRaw.toDate()
        : lastUpdatedRaw is DateTime
            ? lastUpdatedRaw
            : DateTime.now();
    return _PersistedSupportPlan(
      documentId: documentId,
      learnerId: learnerId,
      supportType: supportType.isEmpty ? 'Academic' : supportType,
      accommodations: accommodations,
      notes: notes,
      priority: _priorityFromName(priorityName),
      lastUpdated: lastUpdated,
    );
  }

  static _Priority _priorityFromName(String value) {
    switch (value) {
      case 'high':
        return _Priority.high;
      case 'low':
        return _Priority.low;
      default:
        return _Priority.medium;
    }
  }
}
