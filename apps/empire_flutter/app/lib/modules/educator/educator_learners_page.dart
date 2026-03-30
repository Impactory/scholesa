import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/firestore_service.dart';
import '../../services/export_service.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';
import '../../runtime/runtime.dart';
import '../../auth/app_state.dart';
import '../../i18n/bos_coaching_i18n.dart';
import '../../i18n/workflow_surface_i18n.dart';
import '../../ui/auth/global_session_menu.dart';
import 'educator_models.dart';
import 'educator_service.dart';

String _tEducatorLearnersPageSpecific(BuildContext context, String input) {
  return WorkflowSurfaceI18n.text(context, input);
}

// Alias for backward compatibility
String _tEducatorLearners(BuildContext context, String input) {
  return _tEducatorLearnersPageSpecific(context, input);
}

const String _canonicalLearnerUnavailableLabel = 'Learner unavailable';

String _displayLearnerName(BuildContext context, String learnerName) {
  final String normalized = learnerName.trim();
  if (normalized.isEmpty ||
      normalized == 'Unknown' ||
      normalized == _canonicalLearnerUnavailableLabel) {
    return _tEducatorLearners(context, 'Learner unavailable');
  }
  return normalized;
}

/// Educator Learners Page - View and manage learner roster
class EducatorLearnersPage extends StatefulWidget {
  const EducatorLearnersPage({
    this.learnerLoopInsightsLoader,
    this.sharedPreferences,
    super.key,
  });

  final BosLearnerLoopInsightsLoader? learnerLoopInsightsLoader;
  final SharedPreferences? sharedPreferences;

  @override
  State<EducatorLearnersPage> createState() => _EducatorLearnersPageState();
}

class _EducatorLearnersPageState extends State<EducatorLearnersPage> {
  String _searchQuery = '';
  String _selectedSession = 'all';
  final TextEditingController _searchController = TextEditingController();
  String? _selectedLoopLearnerId;
  String? _loopLearnerName;
  SharedPreferences? _prefsCache;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _restoreFilters();
      await _refreshLearners();
      final EducatorService service = context.read<EducatorService>();
      if (!mounted || service.learners.isEmpty) {
        return;
      }
      _selectLoopLearner(service.learners.first);
    });
  }

  Future<void> _refreshLearners() async {
    await context.read<EducatorService>().loadLearners();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<SharedPreferences> _prefs() async {
    return _prefsCache ??=
        widget.sharedPreferences ?? await SharedPreferences.getInstance();
  }

  String _searchQueryPrefsKey() => 'educator_learners.search_query';

  String _selectedSessionPrefsKey() => 'educator_learners.selected_session';

  Future<void> _restoreFilters() async {
    final SharedPreferences prefs = await _prefs();
    final String restoredQuery = prefs.getString(_searchQueryPrefsKey()) ?? '';
    final String restoredSession =
        prefs.getString(_selectedSessionPrefsKey()) ?? 'all';
    if (!mounted) {
      return;
    }
    setState(() {
      _searchQuery = restoredQuery;
      _selectedSession = restoredSession;
      _searchController.text = restoredQuery;
    });
  }

  Future<void> _persistSearchQuery(String value) async {
    final SharedPreferences prefs = await _prefs();
    await prefs.setString(_searchQueryPrefsKey(), value);
  }

  Future<void> _persistSelectedSession(String sessionId) async {
    final SharedPreferences prefs = await _prefs();
    await prefs.setString(_selectedSessionPrefsKey(), sessionId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              ScholesaColors.educator.withValues(alpha: 0.05),
              Colors.white,
              ScholesaColors.learner.withValues(alpha: 0.03),
            ],
          ),
        ),
        child: Consumer<EducatorService>(
          builder: (BuildContext context, EducatorService service, _) {
            final List<EducatorLearner> filteredLearners =
                _getFilteredLearners(service);
            return CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildSearchBar()),
                SliverToBoxAdapter(child: _buildSessionFilter(service)),
                if (service.error != null && service.learners.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _EducatorLearnerStatusBanner(
                        message: _tEducatorLearners(context,
                                'Unable to refresh learners right now. Showing the last successful data. ') +
                            service.error!,
                      ),
                    ),
                  ),
                SliverToBoxAdapter(child: _buildStats(service)),
                SliverToBoxAdapter(child: _buildLearnerLoopCard()),
                SliverToBoxAdapter(
                  child: AiContextCoachSection(
                    title: _tEducatorLearnersPageSpecific(
                        context, 'Learner AI Help'),
                    subtitle: _tEducatorLearnersPageSpecific(
                        context, 'See support ideas for each learner'),
                    module: 'educator_learners',
                    surface: 'learners_roster',
                    actorRole: UserRole.educator,
                    accentColor: ScholesaColors.educator,
                    conceptTags: const <String>[
                      'educator_roster',
                      'learner_progress',
                      'individual_support',
                    ],
                  ),
                ),
                if (service.isLoading)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: ScholesaColors.educator,
                      ),
                    ),
                  )
                else if (service.error != null && service.learners.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildRosterLoadErrorCard(service.error!),
                    ),
                  )
                else if (filteredLearners.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildEmptyRosterCard(),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (BuildContext context, int index) {
                          if (index >= filteredLearners.length) return null;
                          return _LearnerCard(
                            learner: filteredLearners[index],
                            onTap: () =>
                                _openLearnerDetail(filteredLearners[index]),
                          );
                        },
                        childCount: filteredLearners.length,
                      ),
                    ),
                  ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
              ],
            );
          },
        ),
      ),
    );
  }

  void _selectLoopLearner(EducatorLearner learner) {
    setState(() {
      _selectedLoopLearnerId = learner.id;
      _loopLearnerName = _displayLearnerName(context, learner.name);
    });
  }

  Widget _buildLearnerLoopCard() {
    return BosLearnerLoopInsightsCard(
      title: BosCoachingI18n.sessionLoopTitle(context),
      subtitle: BosCoachingI18n.latestSignal(context),
      emptyLabel: BosCoachingI18n.sessionLoopEmpty(context),
      learnerId: _selectedLoopLearnerId,
      learnerName: _loopLearnerName,
      accentColor: ScholesaColors.educator,
      insightsLoader: widget.learnerLoopInsightsLoader,
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: ScholesaColors.educatorGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: ScholesaColors.educator.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.groups, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _tEducatorLearners(context, 'My Learners'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: ScholesaColors.educator,
                        ),
                  ),
                  Text(
                    _tEducatorLearners(
                        context, 'Track progress and engagement'),
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _refreshLearners,
              icon: const Icon(
                Icons.refresh_rounded,
                color: ScholesaColors.educator,
              ),
            ),
            const SizedBox(width: 12),
            SessionMenuHeaderAction(
              foregroundColor: ScholesaColors.educator,
              backgroundColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRosterLoadErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ScholesaColors.error.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            _tEducatorLearners(context, 'Unable to load learners'),
            style: TextStyle(
              color: context.schTextPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _tEducatorLearners(context,
                'We could not load learners right now. Retry to check the current state.'),
            style: TextStyle(
              color: context.schTextSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(
              color: context.schTextSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRosterCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            _tEducatorLearners(context, 'No learners enrolled'),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _tEducatorLearners(context,
                'Learners will appear here when enrollments sync to your roster.'),
            style: TextStyle(color: Colors.grey[700], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        onChanged: (String value) {
          if (value.isNotEmpty) {
            TelemetryService.instance.logEvent(
              event: 'cta.clicked',
              metadata: <String, dynamic>{
                'module': 'educator_learners',
                'cta_id': 'search_input',
                'surface': 'search_bar',
                'length': value.length,
              },
            );
          }
          setState(() => _searchQuery = value);
          _persistSearchQuery(value);
        },
        decoration: InputDecoration(
          hintText: _tEducatorLearners(context, 'Search learners...'),
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: <String, dynamic>{
                        'module': 'educator_learners',
                        'cta_id': 'clear_search_query',
                        'surface': 'search_bar',
                      },
                    );
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    _persistSearchQuery('');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionFilter(EducatorService service) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            _FilterChip(
              label: _tEducatorLearners(context, 'All Sessions'),
              isSelected: _selectedSession == 'all',
              onTap: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: <String, dynamic>{
                    'module': 'educator_learners',
                    'cta_id': 'set_session_filter',
                    'surface': 'session_filter',
                    'session_id': 'all',
                  },
                );
                setState(() => _selectedSession = 'all');
                _persistSelectedSession('all');
              },
            ),
            const SizedBox(width: 8),
            ...service.sessions.map(
              (EducatorSession session) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _FilterChip(
                  label: session.title,
                  isSelected: _selectedSession == session.id,
                  onTap: () {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: <String, dynamic>{
                        'module': 'educator_learners',
                        'cta_id': 'set_session_filter',
                        'surface': 'session_filter',
                        'session_id': session.id,
                      },
                    );
                    setState(() => _selectedSession = session.id);
                    _persistSelectedSession(session.id);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(EducatorService service) {
    final List<EducatorLearner> learners = _getFilteredLearners(service);
    final int totalLearners = learners.length;
    final int activeToday =
        learners.where((EducatorLearner l) => l.isActiveToday).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _StatCard(
              icon: Icons.people,
              value: totalLearners.toString(),
              label: _tEducatorLearners(context, 'Total Learners'),
              color: ScholesaColors.educator,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Icons.check_circle,
              value: activeToday.toString(),
              label: _tEducatorLearners(context, 'Active Today'),
              color: ScholesaColors.success,
            ),
          ),
        ],
      ),
    );
  }

  List<EducatorLearner> _getFilteredLearners(EducatorService service) {
    List<EducatorLearner> learners = service.learners;

    // Filter by session
    if (_selectedSession != 'all') {
      learners = learners
          .where((EducatorLearner l) => l.sessionIds.contains(_selectedSession))
          .toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      learners = learners.where((EducatorLearner l) {
        return l.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            l.email.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    return learners;
  }

  void _openLearnerDetail(EducatorLearner learner) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'educator_learners',
        'cta_id': 'open_learner_detail',
        'surface': 'learner_card',
        'learner_id': learner.id,
      },
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => _LearnerDetailSheet(learner: learner),
    );
    _selectLoopLearner(learner);
  }
}

class _LearnerCard extends StatelessWidget {
  const _LearnerCard({required this.learner, required this.onTap});
  final EducatorLearner learner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 24,
                  backgroundColor:
                      ScholesaColors.learner.withValues(alpha: 0.1),
                  child: Text(
                    learner.initials,
                    style: const TextStyle(
                      color: ScholesaColors.learner,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            _displayLearnerName(context, learner.name),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          if (learner.isActiveToday)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: ScholesaColors.success
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _tEducatorLearners(context, 'ACTIVE'),
                                style: const TextStyle(
                                  color: ScholesaColors.success,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        learner.email,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    _PillarProgress(
                      label: 'FS',
                      progress: learner.futureSkillsProgress,
                      color: ScholesaColors.futureSkills,
                    ),
                    const SizedBox(height: 4),
                    _PillarProgress(
                      label: 'LD',
                      progress: learner.leadershipProgress,
                      color: ScholesaColors.leadership,
                    ),
                    const SizedBox(height: 4),
                    _PillarProgress(
                      label: 'IM',
                      progress: learner.impactProgress,
                      color: ScholesaColors.impact,
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

class _PillarProgress extends StatelessWidget {
  const _PillarProgress({
    required this.label,
    required this.progress,
    required this.color,
  });
  final String label;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[500]),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 40,
          height: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }
}

class _EducatorLearnerStatusBanner extends StatelessWidget {
  const _EducatorLearnerStatusBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ScholesaColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ScholesaColors.warning.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.info_outline,
            size: 18,
            color: ScholesaColors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: context.schTextPrimary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? ScholesaColors.educator
              : ScholesaColors.educator.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : ScholesaColors.educator,
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
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
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
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LearnerDetailSheet extends StatefulWidget {
  const _LearnerDetailSheet({required this.learner});
  final EducatorLearner learner;

  @override
  State<_LearnerDetailSheet> createState() => _LearnerDetailSheetState();
}

class _LearnerDetailSheetState extends State<_LearnerDetailSheet> {
  static const String _differentiationPlansCollection =
      'learnerDifferentiationPlans';
  final TextEditingController _overrideReasonController =
      TextEditingController();
  final TextEditingController _followUpRequestController =
      TextEditingController();
  late final String _recommendedLane;
  late String _selectedLane;
  String? _savedLane;
  String _savedOverrideReason = '';
  bool _isSavingOverride = false;
  bool _isExporting = false;
  bool _isSubmittingFollowUp = false;
  String? _followUpStatusMessage;
  bool _followUpStatusIsError = false;
  List<Map<String, dynamic>> _growthEvents = <Map<String, dynamic>>[];
  bool _isLoadingGrowth = true;

  EducatorLearner get learner => widget.learner;

  @override
  void initState() {
    super.initState();
    _recommendedLane = _resolveRecommendedLane();
    _selectedLane = _recommendedLane;
    _savedLane = _recommendedLane;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedLaneOverride();
      _loadGrowthEvents();
    });
  }

  @override
  void dispose() {
    _overrideReasonController.dispose();
    _followUpRequestController.dispose();
    super.dispose();
  }

  String _resolveRecommendedLane() {
    final double averageProgress = (learner.futureSkillsProgress +
            learner.leadershipProgress +
            learner.impactProgress) /
        3;
    if (learner.attendanceRate < 75 || averageProgress < 0.45) {
      return 'scaffolded';
    }
    if (averageProgress >= 0.75) {
      return 'stretch';
    }
    return 'core';
  }

  String _laneLabel(String lane) {
    switch (lane) {
      case 'scaffolded':
        return _tEducatorLearners(context, 'Scaffolded lane');
      case 'stretch':
        return _tEducatorLearners(context, 'Stretch lane');
      default:
        return _tEducatorLearners(context, 'Core lane');
    }
  }

  String _laneSummary(String lane) {
    switch (lane) {
      case 'scaffolded':
        return _tEducatorLearners(
          context,
          'Use worked examples, shorter sets, and frequent explain-it-back checks.',
        );
      case 'stretch':
        return _tEducatorLearners(
          context,
          'Use open-ended extensions, transfer prompts, and learner-led reflection.',
        );
      default:
        return _tEducatorLearners(
          context,
          'Use on-level practice, targeted feedback, and one concrete next step.',
        );
    }
  }

  List<String> _practiceTasksForLane(String lane) {
    switch (lane) {
      case 'scaffolded':
        return <String>[
          _tEducatorLearners(context, 'Review one model example together.'),
          _tEducatorLearners(context, 'Complete two short guided reps.'),
          _tEducatorLearners(context, 'End with a verbal explain-it-back.'),
        ];
      case 'stretch':
        return <String>[
          _tEducatorLearners(
              context, 'Solve one transfer challenge without hints.'),
          _tEducatorLearners(context, 'Document an alternative strategy.'),
          _tEducatorLearners(
              context, 'Reflect on tradeoffs and next iteration.'),
        ];
      default:
        return <String>[
          _tEducatorLearners(context, 'Complete one on-level practice set.'),
          _tEducatorLearners(
              context, 'Check one misconception and correct it.'),
          _tEducatorLearners(context, 'Write one concrete next-step note.'),
        ];
    }
  }

  String _buildPrintablePracticePlan() {
    final List<String> tasks = _practiceTasksForLane(_selectedLane);
    return <String>[
      '${_tEducatorLearners(context, 'Learner')}: ${_displayLearnerName(context, learner.name)}',
      '${_tEducatorLearners(context, 'Differentiation lane')}: ${_laneLabel(_selectedLane)}',
      '${_tEducatorLearners(context, 'Attendance')}: ${learner.attendanceRate}%',
      '${_tEducatorLearners(context, 'Missions')}: ${learner.missionsCompleted}',
      '',
      _tEducatorLearners(context, 'Practice focus'),
      _laneSummary(_selectedLane),
      '',
      ...tasks.asMap().entries.map(
            (MapEntry<int, String> entry) => '${entry.key + 1}. ${entry.value}',
          ),
    ].join('\n');
  }

  Future<void> _loadSavedLaneOverride() async {
    final AppState? appState = context.read<AppState?>();
    final String siteId = appState?.activeSiteId?.trim() ?? '';
    if (siteId.isEmpty) {
      return;
    }

    try {
      final FirestoreService firestoreService =
          context.read<FirestoreService>();
      final DocumentSnapshot<Map<String, dynamic>> doc = await firestoreService
          .firestore
          .collection(_differentiationPlansCollection)
          .doc('${learner.id}_$siteId')
          .get();
      if (!doc.exists || !mounted) {
        return;
      }
      final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
      final String savedLane =
          (data['selectedLane'] as String? ?? _recommendedLane).trim();
      final String savedReason =
          (data['overrideReason'] as String? ?? '').trim();
      setState(() {
        _selectedLane = savedLane.isEmpty ? _recommendedLane : savedLane;
        _savedLane = _selectedLane;
        _savedOverrideReason = savedReason;
        _overrideReasonController.text = savedReason;
      });
    } catch (error) {
      debugPrint('Failed to load learner differentiation override: $error');
    }
  }

  Future<void> _loadGrowthEvents() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snap = await FirebaseFirestore
          .instance
          .collection('capabilityGrowthEvents')
          .where('learnerId', isEqualTo: learner.id)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();
      if (!mounted) return;
      setState(() {
        _growthEvents = snap.docs
            .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                <String, dynamic>{'id': doc.id, ...doc.data()})
            .toList();
        _isLoadingGrowth = false;
      });
    } catch (error) {
      debugPrint('Failed to load growth events: $error');
      if (mounted) {
        setState(() => _isLoadingGrowth = false);
      }
    }
  }

  String _levelLabel(int level) {
    switch (level) {
      case 1:
        return _tEducatorLearners(context, 'Beginning');
      case 2:
        return _tEducatorLearners(context, 'Developing');
      case 3:
        return _tEducatorLearners(context, 'Proficient');
      case 4:
        return _tEducatorLearners(context, 'Advanced');
      default:
        return _tEducatorLearners(context, 'Not assessed');
    }
  }

  Color _getPillarColorForCode(String code) {
    switch (code.toLowerCase()) {
      case 'future_skills':
      case 'futureskills':
        return ScholesaColors.futureSkills;
      case 'leadership':
      case 'leadership_agency':
        return ScholesaColors.leadership;
      case 'impact':
      case 'impact_innovation':
        return ScholesaColors.impact;
      default:
        return Colors.grey;
    }
  }

  bool get _hasPendingOverrideChanges {
    final String baselineLane = _savedLane ?? _recommendedLane;
    return _selectedLane != baselineLane ||
        _overrideReasonController.text.trim() != _savedOverrideReason;
  }

  Future<bool> _saveLaneOverride({bool showSuccessMessage = true}) async {
    final AppState? appState = context.read<AppState?>();
    final String? siteId = appState?.activeSiteId;
    final String? educatorId = appState?.userId;
    if (siteId == null ||
        siteId.isEmpty ||
        educatorId == null ||
        educatorId.isEmpty) {
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tEducatorLearners(
              context,
              'Unable to save lane override right now.',
            ),
          ),
        ),
      );
      return false;
    }
    setState(() => _isSavingOverride = true);
    try {
      final FirestoreService firestoreService =
          context.read<FirestoreService>();
      await firestoreService.setDocument(
        _differentiationPlansCollection,
        '${learner.id}_$siteId',
        <String, dynamic>{
          'siteId': siteId,
          'learnerId': learner.id,
          'educatorId': educatorId,
          'recommendedLane': _recommendedLane,
          'selectedLane': _selectedLane,
          'overrideReason': _overrideReasonController.text.trim(),
          'teacherOverride': _selectedLane != _recommendedLane,
          'printablePracticePlan': _buildPrintablePracticePlan(),
          'updatedAt': DateTime.now().toIso8601String(),
        },
        merge: true,
      );

      _savedLane = _selectedLane;
      _savedOverrideReason = _overrideReasonController.text.trim();

      TelemetryService.instance.logEvent(
        event: _selectedLane == _recommendedLane
            ? 'teacher_override_mvl'
            : 'teacher_override_intervention',
        metadata: <String, dynamic>{
          'learner_id': learner.id,
          'recommended_lane': _recommendedLane,
          'selected_lane': _selectedLane,
          'override': _selectedLane != _recommendedLane,
        },
      );

      if (!mounted) return true;
      if (showSuccessMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _tEducatorLearners(context, 'Differentiation lane saved'),
            ),
            backgroundColor: ScholesaColors.success,
          ),
        );
      }
      return true;
    } catch (error) {
      debugPrint('Failed to save differentiation lane override: $error');
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tEducatorLearners(
              context,
              'Unable to save lane override right now.',
            ),
          ),
        ),
      );
      return false;
    } finally {
      if (mounted) {
        setState(() => _isSavingOverride = false);
      }
    }
  }

  Future<void> _handleLaneSelected(String lane) async {
    if (_isSavingOverride || lane == _selectedLane) {
      return;
    }
    final String previousLane = _selectedLane;
    setState(() {
      _selectedLane = lane;
    });
    final bool saved = await _saveLaneOverride();
    if (!saved && mounted) {
      setState(() {
        _selectedLane = previousLane;
      });
    }
  }

  Future<void> _exportPracticePlan() async {
    final AppState? appState = context.read<AppState?>();
    final String? siteId = appState?.activeSiteId;
    final String? educatorId = appState?.userId;
    final String printablePlan = _buildPrintablePracticePlan();
    if (siteId == null ||
        siteId.isEmpty ||
        educatorId == null ||
        educatorId.isEmpty) {
      return;
    }
    setState(() => _isExporting = true);
    try {
      final FirestoreService firestoreService =
          context.read<FirestoreService>();
      await firestoreService.firestore.collection('practiceExports').add(
        <String, dynamic>{
          'siteId': siteId,
          'learnerId': learner.id,
          'educatorId': educatorId,
          'lane': _selectedLane,
          'content': printablePlan,
          'format': 'text/plain',
          'createdAt': DateTime.now().toIso8601String(),
        },
      );
      final String fileName = 'practice-plan-${learner.id}-$_selectedLane.txt';
      final String? savedLocation = await ExportService.instance.saveTextFile(
        fileName: fileName,
        content: printablePlan,
      );
      if (savedLocation == null || !mounted) {
        return;
      }
      TelemetryService.instance.logEvent(
        event: 'export.downloaded',
        metadata: <String, dynamic>{
          'learner_id': learner.id,
          'lane': _selectedLane,
          'export_type': 'printable_practice',
          'file_name': fileName,
        },
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tEducatorLearners(context, 'Practice plan downloaded.'),
          ),
          backgroundColor: ScholesaColors.educator,
        ),
      );
    } on UnsupportedError catch (error) {
      debugPrint(
          'Export unsupported for educator practice plan download, copying plan instead: $error');
      await Clipboard.setData(ClipboardData(text: printablePlan));
      TelemetryService.instance.logEvent(
        event: 'educator.practice_plan_export.copied',
        metadata: <String, dynamic>{
          'learner_id': learner.id,
          'lane': _selectedLane,
          'fallback': 'clipboard',
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tEducatorLearners(context, 'Practice plan copied for sharing.'),
          ),
          backgroundColor: ScholesaColors.educator,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tEducatorLearners(
              context,
              'Unable to download practice plan right now.',
            ),
          ),
          backgroundColor: ScholesaColors.educator,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _submitLearnerFollowUpRequest() async {
    final String details = _followUpRequestController.text.trim();
    if (details.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tEducatorLearners(
              context,
              'Please describe the learner follow-up before sending.',
            ),
          ),
        ),
      );
      return;
    }

    final AppState? appState = context.read<AppState?>();
    final String siteId = appState?.activeSiteId?.trim() ?? '';
    final String userId = appState?.userId?.trim() ?? '';
    final String userEmail = appState?.email?.trim() ?? '';
    final String userName = appState?.displayName?.trim() ?? '';
    final UserRole? role = appState?.role;
    if (siteId.isEmpty ||
        userId.isEmpty ||
        userEmail.isEmpty ||
        userName.isEmpty ||
        role == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tEducatorLearners(
              context,
              'Unable to submit follow-up right now. Refresh your session and try again.',
            ),
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmittingFollowUp = true);
    try {
      final FirestoreService firestoreService =
          context.read<FirestoreService>();
      final String requestId = await firestoreService.submitSupportRequest(
        requestType: 'learner_follow_up',
        source: 'educator_learner_detail_request_follow_up',
        siteId: siteId,
        userId: userId,
        userEmail: userEmail,
        userName: userName,
        role: role.name,
        subject:
            'Learner follow-up request: ${_displayLearnerName(context, learner.name)}',
        message: details,
        metadata: <String, dynamic>{
          'learnerId': learner.id,
          'learnerName': _displayLearnerName(context, learner.name),
          'learnerEmail': learner.email,
          'recommendedLane': _recommendedLane,
          'selectedLane': _selectedLane,
          'teacherOverride': _selectedLane != _recommendedLane,
        },
      );

      await TelemetryService.instance.logEvent(
        event: 'educator.learner_follow_up.submitted',
        metadata: <String, dynamic>{
          'request_id': requestId,
          'learner_id': learner.id,
          'selected_lane': _selectedLane,
        },
      );

      _followUpRequestController.clear();
      if (!mounted) {
        return;
      }
      setState(() {
        _followUpStatusMessage =
            _tEducatorLearners(context, 'Learner follow-up request submitted.');
        _followUpStatusIsError = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tEducatorLearners(context, 'Learner follow-up request submitted.'),
          ),
          backgroundColor: ScholesaColors.success,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _followUpStatusMessage = _tEducatorLearners(
          context,
          'Unable to submit learner follow-up right now.',
        );
        _followUpStatusIsError = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tEducatorLearners(
              context,
              'Unable to submit learner follow-up right now.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingFollowUp = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
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
                  Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 32,
                        backgroundColor:
                            ScholesaColors.learner.withValues(alpha: 0.1),
                        child: Text(
                          learner.initials,
                          style: const TextStyle(
                            color: ScholesaColors.learner,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              _displayLearnerName(context, learner.name),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              learner.email,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _tEducatorLearners(context, 'Pillar Progress'),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  _ProgressBar(
                    label: _tEducatorLearners(context, 'Future Skills'),
                    progress: learner.futureSkillsProgress,
                    color: ScholesaColors.futureSkills,
                  ),
                  const SizedBox(height: 8),
                  _ProgressBar(
                    label: _tEducatorLearners(context, 'Leadership'),
                    progress: learner.leadershipProgress,
                    color: ScholesaColors.leadership,
                  ),
                  const SizedBox(height: 8),
                  _ProgressBar(
                    label: _tEducatorLearners(context, 'Impact'),
                    progress: learner.impactProgress,
                    color: ScholesaColors.impact,
                  ),
                  const SizedBox(height: 24),
                  // Capability Growth History
                  Text(
                    _tEducatorLearners(context, 'Capability Growth'),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  if (_isLoadingGrowth)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: ScholesaColors.educator,
                          ),
                        ),
                      ),
                    )
                  else if (_growthEvents.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _tEducatorLearners(
                          context,
                          'No capability growth events recorded yet. Growth updates appear after rubric scoring.',
                        ),
                        style: TextStyle(color: Colors.grey[500], height: 1.4),
                      ),
                    )
                  else
                    ...(_growthEvents.take(8).map(
                      (Map<String, dynamic> event) {
                        final String title =
                            (event['capabilityTitle'] as String?) ??
                                (event['capabilityId'] as String?) ??
                                '';
                        final int level =
                            (event['level'] as int?) ?? 0;
                        final int rawScore =
                            (event['rawScore'] as int?) ?? 0;
                        final int maxScore =
                            (event['maxScore'] as int?) ?? 0;
                        final String pillar =
                            (event['pillarCode'] as String?) ?? '';
                        final Timestamp? createdAt =
                            event['createdAt'] as Timestamp?;
                        final String educatorId =
                            (event['educatorId'] as String?) ?? '';
                        final Color pillarColor = _getPillarColorForCode(pillar);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border(
                              left: BorderSide(color: pillarColor, width: 3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: pillarColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _levelLabel(level),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: pillarColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: <Widget>[
                                  if (maxScore > 0)
                                    Text(
                                      '${_tEducatorLearners(context, 'Rubric')}: $rawScore/$maxScore',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  if (maxScore > 0 && createdAt != null)
                                    Text(
                                      ' · ',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                  if (createdAt != null)
                                    Text(
                                      '${createdAt.toDate().month}/${createdAt.toDate().day}/${createdAt.toDate().year}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  if (educatorId.isNotEmpty) ...<Widget>[
                                    Text(
                                      ' · ',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                    Icon(Icons.person_outline,
                                        size: 12, color: Colors.grey[500]),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    )),
                  const SizedBox(height: 24),
                  Text(
                    _tEducatorLearners(context, 'Differentiation lane'),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ScholesaColors.educator.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: ScholesaColors.educator.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${_tEducatorLearners(context, 'Recommended lane')}: ${_laneLabel(_recommendedLane)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: ScholesaColors.educator,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _laneSummary(_selectedLane),
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <String>['scaffolded', 'core', 'stretch']
                              .map(
                                (String lane) => ChoiceChip(
                                  label: Text(_laneLabel(lane)),
                                  selected: _selectedLane == lane,
                                  onSelected: (_) async {
                                    await _handleLaneSelected(lane);
                                  },
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _overrideReasonController,
                          onChanged: (_) => setState(() {}),
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: _tEducatorLearners(
                              context,
                              'Teacher override note (optional)',
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                _isSavingOverride || !_hasPendingOverrideChanges
                                    ? null
                                    : _saveLaneOverride,
                            icon: _isSavingOverride
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.tune),
                            label: Text(
                              _tEducatorLearners(context, 'Save lane override'),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ScholesaColors.educator,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _tEducatorLearners(context, 'Printable practice export'),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      _buildPrintablePracticePlan(),
                      style: TextStyle(color: Colors.grey[700], height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isExporting ? null : _exportPracticePlan,
                      icon: _isExporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.print_outlined),
                      label: Text(
                        _tEducatorLearners(context, 'Export practice plan'),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ScholesaColors.educator,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: ScholesaColors.educator),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _tEducatorLearners(context, 'Learner follow-up'),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _tEducatorLearners(
                            context,
                            'Request family or support-team follow-up for this learner.',
                          ),
                          style:
                              TextStyle(color: Colors.grey[700], height: 1.4),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _followUpRequestController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: _tEducatorLearners(
                              context,
                              'Describe the concern, learner context, and next action needed.',
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSubmittingFollowUp
                                ? null
                                : _submitLearnerFollowUpRequest,
                            icon: _isSubmittingFollowUp
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.support_agent),
                            label: Text(
                              _tEducatorLearners(
                                context,
                                'Request follow-up',
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ScholesaColors.educator,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        if (_followUpStatusMessage != null) ...<Widget>[
                          const SizedBox(height: 12),
                          Text(
                            _followUpStatusMessage!,
                            style: TextStyle(
                              color: _followUpStatusIsError
                                  ? Theme.of(context).colorScheme.error
                                  : ScholesaColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
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
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.label,
    required this.progress,
    required this.color,
  });
  final String label;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(label, style: TextStyle(color: Colors.grey[700])),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
