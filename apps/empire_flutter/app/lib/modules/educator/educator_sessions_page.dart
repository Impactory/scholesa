import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../i18n/workflow_surface_i18n.dart';
import '../../services/telemetry_service.dart';
import '../../services/firestore_service.dart';
import '../../ui/auth/global_session_menu.dart';
import '../../ui/theme/scholesa_theme.dart';
import '../../runtime/runtime.dart';
import '../../auth/app_state.dart';
import '../../i18n/bos_coaching_i18n.dart';
import 'educator_models.dart';
import 'educator_service.dart';

String _tEducatorSessions(
  BuildContext context,
  String input, {
  Map<String, String> placeholders = const <String, String>{},
}) {
  return WorkflowSurfaceI18n.textWithPlaceholders(
    context,
    input,
    placeholders: placeholders,
  );
}

class _StudioFlowStep {
  const _StudioFlowStep({
    required this.key,
    required this.label,
    required this.teacherPrompt,
    required this.icon,
  });

  final String key;
  final String label;
  final String teacherPrompt;
  final IconData icon;
}

const List<_StudioFlowStep> _studioFlowSteps = <_StudioFlowStep>[
  _StudioFlowStep(
    key: 'retrieval_warm_up',
    label: 'Retrieval Warm-up',
    teacherPrompt: 'Spot who can recall the core idea without scaffolds.',
    icon: Icons.psychology_alt_rounded,
  ),
  _StudioFlowStep(
    key: 'mini_lesson',
    label: 'Mini-lesson / Micro-skill',
    teacherPrompt: 'Capture who can use the micro-skill after teaching.',
    icon: Icons.auto_stories_rounded,
  ),
  _StudioFlowStep(
    key: 'build_sprint',
    label: 'Build Sprint',
    teacherPrompt: 'Log live observations while learners build.',
    icon: Icons.construction_rounded,
  ),
  _StudioFlowStep(
    key: 'checkpoint',
    label: 'Checkpoint',
    teacherPrompt: 'Record the checkpoint that proves current understanding.',
    icon: Icons.flag_rounded,
  ),
  _StudioFlowStep(
    key: 'share_out',
    label: 'Share-out',
    teacherPrompt: 'Mark the moment learners explain work to others.',
    icon: Icons.campaign_rounded,
  ),
  _StudioFlowStep(
    key: 'reflection',
    label: 'Reflection',
    teacherPrompt: 'Capture what the learner says they improved or still need.',
    icon: Icons.edit_note_rounded,
  ),
  _StudioFlowStep(
    key: 'portfolio_artifact',
    label: 'Portfolio Artifact',
    teacherPrompt: 'Flag the strongest artifact for portfolio follow-up.',
    icon: Icons.collections_bookmark_rounded,
  ),
];

/// Educator Sessions Page - Manage and view all sessions
class EducatorSessionsPage extends StatefulWidget {
  const EducatorSessionsPage({super.key, this.sharedPreferences});

  final SharedPreferences? sharedPreferences;

  @override
  State<EducatorSessionsPage> createState() => _EducatorSessionsPageState();
}

class _EducatorSessionsPageState extends State<EducatorSessionsPage>
    with SingleTickerProviderStateMixin {
  static const List<String> _tabs = <String>['upcoming', 'ongoing', 'past'];
  static const List<String> _supportedFilterStatuses = <String>[
    'all',
    'future_skills',
    'leadership',
    'impact',
  ];

  late TabController _tabController;
  SharedPreferences? _prefsCache;
  String _filterStatus = 'all';

  String _tabNameForIndex(int index) {
    if (index < 0 || index >= _tabs.length) {
      return 'unknown';
    }
    return _tabs[index];
  }

  void _logScheduleViewed({required String trigger}) {
    final EducatorService service = context.read<EducatorService>();
    TelemetryService.instance.logEvent(
      event: 'schedule.viewed',
      metadata: <String, dynamic>{
        'module': 'educator_sessions',
        'trigger': trigger,
        'tab': _tabNameForIndex(_tabController.index),
        'filter_status': _filterStatus,
        'session_count': service.sessions.length,
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!mounted) {
        return;
      }
      setState(() {});
      if (_tabController.indexIsChanging) {
        TelemetryService.instance.logEvent(
          event: 'cta.clicked',
          metadata: <String, dynamic>{
            'cta': 'educator_sessions_tab_change',
            'tab': _tabs[_tabController.index],
          },
        );
        _logScheduleViewed(trigger: 'tab_change');
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _restoreSavedSelections();
      if (!mounted) {
        return;
      }
      context.read<EducatorService>().loadSessions();
      context.read<EducatorService>().loadLearners();
      _logScheduleViewed(trigger: 'page_open');
    });
  }

  Future<SharedPreferences> _prefs() async {
    final SharedPreferences? injected = widget.sharedPreferences;
    if (injected != null) {
      return injected;
    }
    return _prefsCache ??= await SharedPreferences.getInstance();
  }

  String _selectionPrefsScope() {
    final AppState appState = context.read<AppState>();
    final String userKey =
        appState.userId?.trim().isNotEmpty == true ? appState.userId!.trim() : 'anonymous';
    final String siteKey = appState.activeSiteId?.trim().isNotEmpty == true
        ? appState.activeSiteId!.trim()
        : 'no-site';
    return '$userKey.$siteKey';
  }

  String _filterStatusPrefsKey() {
    return 'educator_sessions.filter_status.${_selectionPrefsScope()}';
  }

  String _selectedTabPrefsKey() {
    return 'educator_sessions.selected_tab.${_selectionPrefsScope()}';
  }

  String _normalizeFilterStatus(String? value) {
    if (value == null) {
      return 'all';
    }
    final String normalized =
        value.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
    if (_supportedFilterStatuses.contains(normalized)) {
      return normalized;
    }
    return 'all';
  }

  String _normalizeTabName(String? value) {
    if (value == null) {
      return _tabs.first;
    }
    final String normalized =
        value.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
    if (_tabs.contains(normalized)) {
      return normalized;
    }
    return _tabs.first;
  }

  int _tabIndexForName(String value) {
    final int index = _tabs.indexOf(_normalizeTabName(value));
    return index >= 0 ? index : 0;
  }

  Future<void> _restoreSavedSelections() async {
    final SharedPreferences prefs = await _prefs();
    final String restoredFilterStatus =
        _normalizeFilterStatus(prefs.getString(_filterStatusPrefsKey()));
    final int restoredTabIndex =
        _tabIndexForName(prefs.getString(_selectedTabPrefsKey()) ?? _tabs.first);
    if (!mounted) {
      return;
    }
    setState(() {
      _filterStatus = restoredFilterStatus;
      _tabController.index = restoredTabIndex;
    });
  }

  Future<void> _setFilterStatus(String value) async {
    final String normalized = _normalizeFilterStatus(value);
    final SharedPreferences prefs = await _prefs();
    await prefs.setString(_filterStatusPrefsKey(), normalized);
    if (!mounted) {
      return;
    }
    setState(() => _filterStatus = normalized);
  }

  Future<void> _setSelectedTab(String value) async {
    final String normalized = _normalizeTabName(value);
    final SharedPreferences prefs = await _prefs();
    await prefs.setString(_selectedTabPrefsKey(), normalized);
  }

  String _normalizeSessionStatus(String value) {
    final String normalized =
        value.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
    switch (normalized) {
      case 'active':
      case 'in_progress':
      case 'ongoing':
        return 'ongoing';
      case 'completed':
      case 'past':
      case 'cancelled':
      case 'canceled':
        return 'past';
      default:
        return 'upcoming';
    }
  }

  bool _matchesSelectedTab(EducatorSession session) {
    return _normalizeSessionStatus(session.status) ==
        _tabNameForIndex(_tabController.index);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
              ScholesaColors.futureSkills.withValues(alpha: 0.03),
            ],
          ),
        ),
        child: Consumer<EducatorService>(
          builder: (BuildContext context, EducatorService service, _) {
            final List<EducatorSession> sessions =
                _getFilteredSessions(service);
            return CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildTabBar()),
                SliverToBoxAdapter(child: _buildFilters()),
                SliverToBoxAdapter(
                  child: AiContextCoachSection(
                    title: _tEducatorSessions(context, 'Session AI Help'),
                    subtitle: _tEducatorSessions(
                      context,
                      'See support ideas for each session and learner',
                    ),
                    module: 'educator_sessions',
                    surface: 'sessions_schedule',
                    actorRole: UserRole.educator,
                    accentColor: ScholesaColors.educator,
                    conceptTags: const <String>[
                      'session_planning',
                      'classroom_orchestration',
                      'attendance_support',
                    ],
                  ),
                ),
                if (service.learners.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: BosLearnerLoopInsightsCard(
                        title: BosCoachingI18n.sessionLoopTitle(context),
                        subtitle: BosCoachingI18n.sessionLoopSubtitle(context),
                        emptyLabel: BosCoachingI18n.sessionLoopEmpty(context),
                        learnerId: service.learners.first.id,
                        learnerName: service.learners.first.name,
                        accentColor: ScholesaColors.educator,
                      ),
                    ),
                  ),
                if (!service.isLoading &&
                    service.error != null &&
                    service.sessions.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _buildStaleDataBanner(service.error!),
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
                else if (service.error != null && service.sessions.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildLoadErrorState(service.error!),
                    ),
                  )
                else if (sessions.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _tEducatorSessions(context, 'No sessions yet'),
                          style: const TextStyle(
                            color: ScholesaColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (BuildContext context, int index) {
                          if (index >= sessions.length) return null;
                          return _SessionCard(
                            session: sessions[index],
                            onTap: () => _openSessionDetail(sessions[index]),
                          );
                        },
                        childCount: _getFilteredSessions(service).length,
                      ),
                    ),
                  ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewSession,
        backgroundColor: ScholesaColors.educator,
        icon: const Icon(Icons.add),
        label: Text(_tEducatorSessions(context, 'New Session')),
      ),
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
              child:
                  const Icon(Icons.event_note, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _tEducatorSessions(context, 'My Sessions'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: ScholesaColors.educator,
                        ),
                  ),
                  Text(
                    _tEducatorSessions(
                        context, 'Manage your teaching schedule'),
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: () async {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: const <String, dynamic>{
                    'cta': 'educator_sessions_refresh',
                  },
                );
                await context.read<EducatorService>().loadSessions();
              },
              icon: const Icon(
                Icons.refresh_rounded,
                color: ScholesaColors.educator,
              ),
              tooltip: _tEducatorSessions(context, 'Refresh'),
            ),
            SessionMenuHeaderAction(
              foregroundColor: ScholesaColors.educator,
              backgroundColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: _tabController,
          onTap: (int index) {
            final String selectedTab = _tabs[index];
            TelemetryService.instance.logEvent(
              event: 'cta.clicked',
              metadata: <String, dynamic>{
                'cta': 'educator_sessions_tab_bar_tap',
                'tab': selectedTab,
              },
            );
            setState(() {});
            _setSelectedTab(selectedTab);
            _logScheduleViewed(trigger: 'tab_tap');
          },
          indicator: BoxDecoration(
            color: ScholesaColors.educator,
            borderRadius: BorderRadius.circular(10),
          ),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[600],
          tabs: <Widget>[
            Tab(text: _tEducatorSessions(context, 'Upcoming')),
            Tab(text: _tEducatorSessions(context, 'Ongoing')),
            Tab(text: _tEducatorSessions(context, 'Past')),
          ],
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
              label: _tEducatorSessions(context, 'All'),
              isSelected: _filterStatus == 'all',
              onTap: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: const <String, dynamic>{
                    'cta': 'educator_sessions_filter_all'
                  },
                );
                _setFilterStatus('all');
                _logScheduleViewed(trigger: 'filter_all');
              },
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: _tEducatorSessions(context, 'Future Skills'),
              isSelected: _filterStatus == 'future_skills',
              color: ScholesaColors.futureSkills,
              onTap: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: const <String, dynamic>{
                    'cta': 'educator_sessions_filter_future_skills'
                  },
                );
                _setFilterStatus('future_skills');
                _logScheduleViewed(trigger: 'filter_future_skills');
              },
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: _tEducatorSessions(context, 'Leadership'),
              isSelected: _filterStatus == 'leadership',
              color: ScholesaColors.leadership,
              onTap: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: const <String, dynamic>{
                    'cta': 'educator_sessions_filter_leadership'
                  },
                );
                _setFilterStatus('leadership');
                _logScheduleViewed(trigger: 'filter_leadership');
              },
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: _tEducatorSessions(context, 'Impact'),
              isSelected: _filterStatus == 'impact',
              color: ScholesaColors.impact,
              onTap: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: const <String, dynamic>{
                    'cta': 'educator_sessions_filter_impact'
                  },
                );
                _setFilterStatus('impact');
                _logScheduleViewed(trigger: 'filter_impact');
              },
            ),
          ],
        ),
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
                  _tEducatorSessions(
                    context,
                    'We could not load sessions right now. Retry to check the current state.',
                  ),
                  style: TextStyle(
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
            onPressed: () => context.read<EducatorService>().loadSessions(),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(_tEducatorSessions(context, 'Retry')),
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
              _tEducatorSessions(
                    context,
                    'Unable to refresh sessions right now. Showing the last successful data. ',
                  ) +
                  message,
              style: const TextStyle(color: Color(0xFF92400E)),
            ),
          ),
        ],
      ),
    );
  }

  List<EducatorSession> _getFilteredSessions(EducatorService service) {
    return service.sessions.where((EducatorSession session) {
      final bool matchesTab = _matchesSelectedTab(session);
      if (!matchesTab) {
        return false;
      }
      if (_filterStatus == 'all') {
        return true;
      }
      return session.pillar.toLowerCase().replaceAll(' ', '_') ==
          _filterStatus;
    }).toList();
  }

  void _openSessionDetail(EducatorSession session) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'educator_sessions_open_detail',
        'session_id': session.id
      },
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => _SessionDetailSheet(session: session),
    );
  }

  void _createNewSession() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{
        'cta': 'educator_sessions_open_create_dialog'
      },
    );
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => const _CreateSessionDialog(),
    );
  }
}

class _CreateSessionDialog extends StatefulWidget {
  const _CreateSessionDialog();

  @override
  State<_CreateSessionDialog> createState() => _CreateSessionDialogState();
}

class _CreateSessionDialogState extends State<_CreateSessionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _coTeacherIdsController = TextEditingController();
  final TextEditingController _aideIdsController = TextEditingController();
  String _pillar = 'Future Skills';
  bool _generateJoinCode = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _coTeacherIdsController.dispose();
    _aideIdsController.dispose();
    super.dispose();
  }

  List<String> _splitIds(String input) {
    return input
        .split(',')
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'educator_sessions_create_submit',
        'pillar': _pillar,
      },
    );

    setState(() => _isSubmitting = true);

    final DateTime now = DateTime.now();
    final DateTime start = now.add(const Duration(hours: 1));
    final DateTime end = start.add(const Duration(hours: 1));

    final EducatorService service = context.read<EducatorService>();
    final List<String> coTeacherIds = _splitIds(_coTeacherIdsController.text);
    final List<String> aideIds = _splitIds(_aideIdsController.text);
    final EducatorSession? created = await service.createSession(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      location: _locationController.text.trim(),
      pillar: _pillar,
      startTime: start,
      endTime: end,
      coTeacherIds: coTeacherIds,
      aideIds: aideIds,
      generateJoinCode: _generateJoinCode,
    );

    if (!mounted) {
      return;
    }

    setState(() => _isSubmitting = false);

    if (created == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(service.error ??
                _tEducatorSessions(context, 'Failed to create session'))),
      );
      return;
    }

    final AppState appState = context.read<AppState>();
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState scaffoldMessenger =
        ScaffoldMessenger.of(context);
    final String successMessage =
        created.joinCode == null || created.joinCode!.isEmpty
            ? _tEducatorSessions(
                context,
                'Session created and added to your list',
              )
            : _tEducatorSessions(
                context,
                'Session created with join code {joinCode}',
                placeholders: <String, String>{
                  'joinCode': created.joinCode!,
                },
              );
    final String? activeSiteId = service.siteId?.trim().isNotEmpty == true
        ? service.siteId!.trim()
        : appState.activeSiteId?.trim();
    await TelemetryService.instance.logEvent(
      event: 'class.created',
      role: appState.role?.name,
      siteId: activeSiteId,
      metadata: <String, dynamic>{
        'classId': created.id,
        'pillar': created.pillar,
        'coTeacherCount': created.coTeacherIds.length,
        'aideCount': created.aideIds.length,
      },
    );
    if (created.joinCode != null && created.joinCode!.isNotEmpty) {
      await TelemetryService.instance.logEvent(
        event: 'class.join_code.created',
        role: appState.role?.name,
        siteId: activeSiteId,
        metadata: <String, dynamic>{
          'classId': created.id,
          'joinCodeLength': created.joinCode!.length,
        },
      );
    }

    if (!mounted) return;

    navigator.pop();
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(successMessage),
        backgroundColor: ScholesaColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_tEducatorSessions(context, 'Create Session')),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                  labelText: _tEducatorSessions(context, 'Session title')),
              validator: (String? value) =>
                  value == null || value.trim().isEmpty
                      ? _tEducatorSessions(context, 'Title is required')
                      : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText:
                    _tEducatorSessions(context, 'Description (optional)'),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: _tEducatorSessions(context, 'Location (optional)'),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _coTeacherIdsController,
              decoration: InputDecoration(
                labelText: _tEducatorSessions(
                  context,
                  'Co-teacher IDs (comma separated)',
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _aideIdsController,
              decoration: InputDecoration(
                labelText: _tEducatorSessions(
                  context,
                  'Aide IDs (comma separated)',
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _pillar,
              decoration: InputDecoration(
                  labelText: _tEducatorSessions(context, 'Pillar')),
              items: <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: 'Future Skills',
                  child: Text(_tEducatorSessions(context, 'Future Skills')),
                ),
                DropdownMenuItem<String>(
                  value: 'Leadership',
                  child: Text(_tEducatorSessions(context, 'Leadership')),
                ),
                DropdownMenuItem<String>(
                  value: 'Impact',
                  child: Text(_tEducatorSessions(context, 'Impact')),
                ),
              ],
              onChanged: (String? value) {
                if (value != null) {
                  TelemetryService.instance.logEvent(
                    event: 'cta.clicked',
                    metadata: <String, dynamic>{
                      'cta': 'educator_sessions_create_select_pillar',
                      'pillar': value,
                    },
                  );
                  setState(() => _pillar = value);
                }
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              value: _generateJoinCode,
              contentPadding: EdgeInsets.zero,
              title: Text(_tEducatorSessions(context, 'Generate join code')),
              onChanged: (bool value) {
                setState(() => _generateJoinCode = value);
              },
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () {
                  TelemetryService.instance.logEvent(
                    event: 'cta.clicked',
                    metadata: const <String, dynamic>{
                      'cta': 'educator_sessions_create_cancel',
                    },
                  );
                  Navigator.pop(context);
                },
          child: Text(_tEducatorSessions(context, 'Cancel')),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_tEducatorSessions(context, 'Create')),
        ),
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.onTap});
  final EducatorSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            TelemetryService.instance.logEvent(
              event: 'cta.clicked',
              metadata: <String, dynamic>{
                'cta': 'educator_sessions_open_session',
                'session_title': session.title,
                'pillar': session.pillar,
                'status': session.status,
              },
            );
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _getPillarColor().withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getPillarIcon(),
                        color: _getPillarColor(),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            session.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${session.learnerCount} ${_tEducatorSessions(context, 'learners enrolled')}',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor().withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        session.status.toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(),
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Icon(Icons.calendar_today,
                        size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _formatSchedule(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getPillarColor().withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _tEducatorSessions(context, session.pillar),
                        style: TextStyle(
                          color: _getPillarColor(),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

  Color _getPillarColor() {
    switch (session.pillar.toLowerCase()) {
      case 'future skills':
        return ScholesaColors.futureSkills;
      case 'leadership':
        return ScholesaColors.leadership;
      case 'impact':
        return ScholesaColors.impact;
      default:
        return ScholesaColors.educator;
    }
  }

  IconData _getPillarIcon() {
    switch (session.pillar.toLowerCase()) {
      case 'future skills':
        return Icons.code;
      case 'leadership':
        return Icons.emoji_events;
      case 'impact':
        return Icons.eco;
      default:
        return Icons.school;
    }
  }

  Color _getStatusColor() {
    switch (session.status.toLowerCase()) {
      case 'active':
        return ScholesaColors.success;
      case 'upcoming':
        return ScholesaColors.info;
      case 'completed':
        return Colors.grey;
      default:
        return ScholesaColors.educator;
    }
  }

  String _formatSchedule() {
    return '${session.dayOfWeek} • ${_formatTimeOfDay(session.startTime)} - ${_formatTimeOfDay(session.endTime)}';
  }

  String _formatTimeOfDay(DateTime value) {
    final int hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final String minute = value.minute.toString().padLeft(2, '0');
    final String meridiem = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $meridiem';
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
    final Color chipColor = color ?? ScholesaColors.educator;
    return GestureDetector(
      onTap: () {
        TelemetryService.instance.logEvent(
          event: 'cta.clicked',
          metadata: <String, dynamic>{
            'cta': 'educator_sessions_filter_chip',
            'label': label,
            'selected': isSelected,
          },
        );
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : chipColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : chipColor,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _SessionDetailSheet extends StatelessWidget {
  const _SessionDetailSheet({required this.session});
  final EducatorSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
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
                    session.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (session.description != null)
                    Text(
                      session.description!,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  const SizedBox(height: 24),
                  _DetailRow(
                    icon: Icons.people,
                    label: _tEducatorSessions(context, 'Enrolled'),
                    value:
                        '${session.learnerCount} ${_tEducatorSessions(context, 'learners enrolled')}',
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.schedule,
                    label: _tEducatorSessions(context, 'Schedule'),
                    value:
                        '${session.dayOfWeek} ${session.startTime} - ${session.endTime}',
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.category,
                    label: _tEducatorSessions(context, 'Pillar'),
                    value: _tEducatorSessions(context, session.pillar),
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.qr_code_rounded,
                    label: _tEducatorSessions(context, 'Join Code'),
                    value: session.joinCode?.isNotEmpty == true
                        ? session.joinCode!
                        : _tEducatorSessions(context, 'No join code yet'),
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.badge_rounded,
                    label: _tEducatorSessions(context, 'Primary Teachers'),
                    value: session.teacherIds.isEmpty
                        ? _tEducatorSessions(context, 'Unassigned')
                        : session.teacherIds.join(', '),
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.groups_rounded,
                    label: _tEducatorSessions(context, 'Co-teachers'),
                    value: session.coTeacherIds.isEmpty
                        ? _tEducatorSessions(context, 'Unassigned')
                        : session.coTeacherIds.join(', '),
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.support_agent_rounded,
                    label: _tEducatorSessions(context, 'Aides'),
                    value: session.aideIds.isEmpty
                        ? _tEducatorSessions(context, 'Unassigned')
                        : session.aideIds.join(', '),
                  ),
                  const SizedBox(height: 24),
                  _StudioLaunchCard(session: session),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        TelemetryService.instance.logEvent(
                          event: 'cta.clicked',
                          metadata: <String, dynamic>{
                            'cta': 'educator_sessions_import_roster_csv',
                            'session_id': session.id,
                          },
                        );
                        showDialog<void>(
                          context: context,
                          builder: (BuildContext context) =>
                              _ImportRosterDialog(session: session),
                        );
                      },
                      icon: const Icon(Icons.upload_file_rounded),
                      label: Text(
                        _tEducatorSessions(context, 'Import Roster CSV'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        TelemetryService.instance.logEvent(
                          event: 'substitute.requested',
                          metadata: <String, dynamic>{
                            'module': 'educator_sessions',
                            'session_id': session.id,
                            'pillar': session.pillar,
                            'day_of_week': session.dayOfWeek,
                          },
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_tEducatorSessions(context,
                                'Substitute request submitted for approval')),
                            backgroundColor: ScholesaColors.info,
                          ),
                        );
                      },
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: Text(
                          _tEducatorSessions(context, 'Request Substitute')),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        TelemetryService.instance.logEvent(
                          event: 'cta.clicked',
                          metadata: <String, dynamic>{
                            'cta': 'educator_sessions_view_full_details',
                            'session_id': session.id,
                          },
                        );
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ScholesaColors.educator,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                          _tEducatorSessions(context, 'View Full Details')),
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

class _ImportRosterDialog extends StatefulWidget {
  const _ImportRosterDialog({required this.session});

  final EducatorSession session;

  @override
  State<_ImportRosterDialog> createState() => _ImportRosterDialogState();
}

class _ImportRosterDialogState extends State<_ImportRosterDialog> {
  final TextEditingController _csvController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _csvController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_csvController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tEducatorSessions(context, 'Paste CSV content to import a roster'),
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final EducatorService service = context.read<EducatorService>();
    final RosterImportOutcome? outcome = await service.importRosterCsv(
      sessionId: widget.session.id,
      csvContent: _csvController.text,
    );
    if (!mounted) {
      return;
    }
    setState(() => _isSubmitting = false);

    if (outcome == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            service.error ??
                _tEducatorSessions(
                    context, 'Unable to import roster right now'),
          ),
          backgroundColor: ScholesaColors.error,
        ),
      );
      return;
    }

    Navigator.of(context).pop();
    final String message = outcome.queuedCount == 0
        ? _tEducatorSessions(
            context,
            'Roster import complete: {importedCount} enrolled, {duplicateCount} already present',
            placeholders: <String, String>{
              'importedCount': '${outcome.importedCount}',
              'duplicateCount': '${outcome.duplicateCount}',
            },
          )
        : _tEducatorSessions(
            context,
            'Roster import complete: {importedCount} enrolled, {queuedCount} queued for provisioning',
            placeholders: <String, String>{
              'importedCount': '${outcome.importedCount}',
              'queuedCount': '${outcome.queuedCount}',
            },
          );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ScholesaColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_tEducatorSessions(context, 'Import Roster CSV')),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _tEducatorSessions(
                context,
                'Use headers like name, email, or learner_id. Unmatched learners will be queued for site provisioning.',
              ),
              style: TextStyle(color: Colors.grey[700], height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _csvController,
              maxLines: 10,
              decoration: InputDecoration(
                hintText: _tEducatorSessions(
                  context,
                  'name,email\nAva Maker,ava@example.com\nKai Build,kai@example.com',
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(_tEducatorSessions(context, 'Cancel')),
        ),
        ElevatedButton.icon(
          onPressed: _isSubmitting ? null : _submit,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_file_rounded),
          label: Text(_tEducatorSessions(context, 'Import')),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ScholesaColors.educator.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: ScholesaColors.educator),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }
}

class _StudioLaunchCard extends StatelessWidget {
  const _StudioLaunchCard({required this.session});

  final EducatorSession session;

  @override
  Widget build(BuildContext context) {
    final EducatorService educatorService = context.read<EducatorService>();
    final List<EducatorLearner> scopedLearners = educatorService.learners
        .where((EducatorLearner learner) =>
            learner.enrolledSessionIds.contains(session.id))
        .toList();
    final int learnerCount = scopedLearners.isNotEmpty
        ? scopedLearners.length
        : session.learnerCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD7E3F4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ScholesaColors.educator.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: ScholesaColors.educator,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _tEducatorSessions(context, 'Live Studio Flow'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _tEducatorSessions(
                        context,
                        'Run the session in Scholesa order and log evidence with as few taps as possible.',
                      ),
                      style: TextStyle(color: Colors.grey[700], height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _studioFlowSteps
                .map(
                  (_StudioFlowStep step) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(step.icon,
                            size: 16, color: ScholesaColors.educator),
                        const SizedBox(width: 8),
                        Text(
                          _tEducatorSessions(context, step.label),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _tEducatorSessions(context, 'Live capture right now'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  _tEducatorSessions(
                    context,
                    'Attendance is available in one tap. Studio evidence capture keeps learner, session, phase, capability focus, and portfolio follow-up together.',
                  ),
                  style: TextStyle(color: Colors.grey[700], height: 1.35),
                ),
                const SizedBox(height: 10),
                Text(
                  _tEducatorSessions(
                    context,
                    'Learners ready for capture: {count}',
                    placeholders: <String, String>{'count': '$learnerCount'},
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: <String, dynamic>{
                        'cta': 'educator_sessions_open_attendance_from_studio',
                        'session_id': session.id,
                      },
                    );
                    Navigator.of(context).pop();
                    context.go('/educator/attendance');
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: ScholesaColors.educator,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.how_to_reg_rounded),
                  label: Text(_tEducatorSessions(context, 'Take Attendance')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: <String, dynamic>{
                        'cta': 'educator_sessions_open_live_evidence',
                        'session_id': session.id,
                      },
                    );
                    showDialog<void>(
                      context: context,
                      builder: (BuildContext dialogContext) =>
                          _QuickEvidenceDialog(session: session),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.note_add_rounded),
                  label: Text(_tEducatorSessions(context, 'Log Evidence')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickEvidenceDialog extends StatefulWidget {
  const _QuickEvidenceDialog({required this.session});

  final EducatorSession session;

  @override
  State<_QuickEvidenceDialog> createState() => _QuickEvidenceDialogState();
}

class _QuickEvidenceDialogState extends State<_QuickEvidenceDialog> {
  final TextEditingController _capabilityController = TextEditingController();
  final TextEditingController _observationController = TextEditingController();
  final TextEditingController _nextExplainController = TextEditingController();
  String _selectedLearnerId = '';
  String _selectedCapabilityId = '';
  String _selectedPhaseKey = _studioFlowSteps[2].key;
  bool _markForPortfolio = true;
  bool _isSubmitting = false;
  bool _isLoadingCapabilities = false;
  bool _didLoadCapabilities = false;
  List<_CapabilityOption> _availableCapabilities = const <_CapabilityOption>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadCapabilities) {
      return;
    }
    _didLoadCapabilities = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _loadCapabilities();
    });
  }

  @override
  void dispose() {
    _capabilityController.dispose();
    _observationController.dispose();
    _nextExplainController.dispose();
    super.dispose();
  }

  List<EducatorLearner> _availableLearners(EducatorService service) {
    final List<EducatorLearner> scoped = service.learners
        .where((EducatorLearner learner) =>
            learner.enrolledSessionIds.contains(widget.session.id))
        .toList();
    return scoped.isNotEmpty ? scoped : service.learners;
  }

  String _phaseLabel(String key) {
    return _studioFlowSteps
            .where(((_StudioFlowStep step) => step.key == key))
            .map(((_StudioFlowStep step) => step.label))
            .cast<String?>()
            .firstOrNull ??
        'Build Sprint';
  }

  String _evidenceTypeForPhase(String key) {
    switch (key) {
      case 'retrieval_warm_up':
        return 'retrieval_response';
      case 'mini_lesson':
        return 'micro_skill_observation';
      case 'checkpoint':
        return 'checkpoint_signal';
      case 'share_out':
        return 'share_out_signal';
      case 'reflection':
        return 'reflection_signal';
      case 'portfolio_artifact':
        return 'artifact_candidate';
      case 'build_sprint':
      default:
        return 'build_observation';
    }
  }

  String _pillarCodeForSession(String pillarLabel) {
    final String normalized = pillarLabel.trim().toLowerCase();
    if (normalized.contains('leadership')) {
      return 'LEAD';
    }
    if (normalized.contains('impact')) {
      return 'IMP';
    }
    return 'FS';
  }

  Future<void> _loadCapabilities() async {
    final FirestoreService firestoreService = context.read<FirestoreService>();
    final AppState appState = context.read<AppState>();
    final String activeSiteId = (appState.activeSiteId?.trim().isNotEmpty ??
            false)
        ? appState.activeSiteId!.trim()
        : (appState.siteIds.isNotEmpty ? appState.siteIds.first.trim() : '');

    setState(() => _isLoadingCapabilities = true);
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await firestoreService.firestore
              .collection('capabilities')
              .where(
                'pillarCode',
                isEqualTo: _pillarCodeForSession(widget.session.pillar),
              )
              .limit(100)
              .get();

      final List<_CapabilityOption> options = snapshot.docs
          .map((doc) => _CapabilityOption.fromDoc(doc))
          .where((_CapabilityOption option) {
        final String optionSiteId = option.siteId?.trim() ?? '';
        return optionSiteId.isEmpty ||
            activeSiteId.isEmpty ||
            optionSiteId == activeSiteId;
      }).toList()
        ..sort((_CapabilityOption a, _CapabilityOption b) {
          final int siteBias = (b.siteId?.trim().isNotEmpty == true ? 1 : 0) -
              (a.siteId?.trim().isNotEmpty == true ? 1 : 0);
          if (siteBias != 0) {
            return siteBias;
          }
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });

      if (!mounted) {
        return;
      }
      setState(() {
        _availableCapabilities = options;
        if (_selectedCapabilityId.isEmpty && options.isNotEmpty) {
          _selectedCapabilityId = options.first.id;
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _availableCapabilities = const <_CapabilityOption>[];
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingCapabilities = false);
      }
    }
  }

  _CapabilityOption? _selectedCapability() {
    if (_selectedCapabilityId.isEmpty) {
      return null;
    }
    for (final _CapabilityOption option in _availableCapabilities) {
      if (option.id == _selectedCapabilityId) {
        return option;
      }
    }
    return null;
  }

  Future<void> _submit() async {
    final EducatorService educatorService = context.read<EducatorService>();
    final AppState appState = context.read<AppState>();
    final FirestoreService firestoreService = context.read<FirestoreService>();
    final List<EducatorLearner> learners = _availableLearners(educatorService);

    final String learnerId = _selectedLearnerId.trim();
    final _CapabilityOption? selectedCapability = _selectedCapability();
    final String capabilityFocus =
        selectedCapability?.title ?? _capabilityController.text.trim();
    final String observation = _observationController.text.trim();
    final String siteId = (educatorService.siteId?.trim().isNotEmpty ?? false)
        ? educatorService.siteId!.trim()
        : (appState.activeSiteId?.trim() ?? '');

    if (learnerId.isEmpty || capabilityFocus.isEmpty || observation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tEducatorSessions(
              context,
              'Choose a learner, add a capability focus, and capture what you observed.',
            ),
          ),
        ),
      );
      return;
    }

    if (siteId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tEducatorSessions(
              context,
              'Active site is required before evidence can be captured.',
            ),
          ),
          backgroundColor: ScholesaColors.error,
        ),
      );
      return;
    }

    final EducatorLearner learner = learners.firstWhere(
      (EducatorLearner value) => value.id == learnerId,
      orElse: () => EducatorLearner(
        id: learnerId,
        name: _tEducatorSessions(context, 'Learner unavailable'),
        email: '',
        attendanceRate: 0,
        missionsCompleted: 0,
        pillarProgress: const <String, double>{},
        enrolledSessionIds: const <String>[],
      ),
    );

    setState(() => _isSubmitting = true);
    try {
      final String? rawRoleName = appState.role?.name;
      final String educatorRole =
          (rawRoleName != null && rawRoleName.isNotEmpty)
              ? rawRoleName
              : 'educator';
      await firestoreService.createDocument(
        'evidenceRecords',
        <String, dynamic>{
          'siteId': siteId,
          'learnerId': learner.id,
          'learnerName': learner.name,
          'sessionId': widget.session.id,
          'sessionTitle': widget.session.title,
          'sessionOccurrenceId': null,
          'educatorId': appState.userId ?? educatorService.educatorId,
          'educatorRole': educatorRole,
          'phaseKey': _selectedPhaseKey,
          'phaseLabel': _phaseLabel(_selectedPhaseKey),
          'evidenceType': _evidenceTypeForPhase(_selectedPhaseKey),
          'capabilityId': selectedCapability?.id,
          'capabilityLabel': capabilityFocus,
          'capabilityMapped': selectedCapability != null,
          'capabilityPillarCode': selectedCapability?.pillarCode ??
              _pillarCodeForSession(widget.session.pillar),
          'observationNote': observation,
          'nextVerificationPrompt': _nextExplainController.text.trim().isEmpty
              ? null
              : _nextExplainController.text.trim(),
          'portfolioCandidate': _markForPortfolio,
          'rubricStatus': 'pending',
          'growthStatus': 'pending',
          'source': 'educator_live_capture',
          'status': 'captured',
          'observedAt': FieldValue.serverTimestamp(),
        },
      );
      await TelemetryService.instance.logEvent(
        event: 'teacher.evidence.captured',
        role: educatorRole,
        siteId: siteId,
        metadata: <String, dynamic>{
          'sessionId': widget.session.id,
          'learnerId': learner.id,
          'phaseKey': _selectedPhaseKey,
          'capabilityId': selectedCapability?.id,
          'capabilityMapped': selectedCapability != null,
          'portfolioCandidate': _markForPortfolio,
        },
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tEducatorSessions(
              context,
              'Live evidence captured for {learnerName}',
              placeholders: <String, String>{'learnerName': learner.name},
            ),
          ),
          backgroundColor: ScholesaColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tEducatorSessions(
              context,
              'Unable to capture evidence right now: {error}',
              placeholders: <String, String>{'error': '$error'},
            ),
          ),
          backgroundColor: ScholesaColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final EducatorService educatorService = context.read<EducatorService>();
    final List<EducatorLearner> learners = _availableLearners(educatorService);
    if (_selectedLearnerId.isEmpty && learners.isNotEmpty) {
      _selectedLearnerId = learners.first.id;
    }

    return AlertDialog(
      title: Text(_tEducatorSessions(context, 'Log Live Evidence')),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _tEducatorSessions(
                  context,
                  'Capture the strongest piece of evidence from studio time in one place so rubricing, growth, and portfolio follow-up can happen later.',
                ),
                style: TextStyle(color: Colors.grey[700], height: 1.35),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue:
                    _selectedLearnerId.isEmpty ? null : _selectedLearnerId,
                decoration: InputDecoration(
                  labelText: _tEducatorSessions(context, 'Learner'),
                ),
                items: learners
                    .map(
                      (EducatorLearner learner) => DropdownMenuItem<String>(
                        value: learner.id,
                        child: Text(learner.name),
                      ),
                    )
                    .toList(),
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() => _selectedLearnerId = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedPhaseKey,
                decoration: InputDecoration(
                  labelText: _tEducatorSessions(context, 'Learning phase'),
                ),
                items: _studioFlowSteps
                    .map(
                      (_StudioFlowStep step) => DropdownMenuItem<String>(
                        value: step.key,
                        child: Text(_tEducatorSessions(context, step.label)),
                      ),
                    )
                    .toList(),
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() => _selectedPhaseKey = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              if (_isLoadingCapabilities)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(minHeight: 3),
                ),
              if (_availableCapabilities.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: _selectedCapabilityId.isEmpty
                      ? null
                      : _selectedCapabilityId,
                  decoration: InputDecoration(
                    labelText: _tEducatorSessions(context, 'Capability focus'),
                    helperText: _tEducatorSessions(
                      context,
                      'Use a mapped capability so growth and rubric workflows can connect later.',
                    ),
                  ),
                  items: _availableCapabilities
                      .map(
                        (_CapabilityOption capability) =>
                            DropdownMenuItem<String>(
                          value: capability.id,
                          child: Text(capability.title),
                        ),
                      )
                      .toList(),
                  onChanged: (String? value) {
                    if (value != null) {
                      setState(() => _selectedCapabilityId = value);
                    }
                  },
                )
              else
                TextFormField(
                  controller: _capabilityController,
                  decoration: InputDecoration(
                    labelText: _tEducatorSessions(context, 'Capability focus'),
                    helperText: _tEducatorSessions(
                      context,
                      'No mapped capabilities found for this pillar yet. This evidence will be marked as unmapped.',
                    ),
                    hintText: _tEducatorSessions(
                      context,
                      'Example: clear explanation, debugging, collaboration, persuasive speaking',
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _observationController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText:
                      _tEducatorSessions(context, 'What evidence did you see?'),
                  hintText: _tEducatorSessions(
                    context,
                    'Short, specific observation from live studio work.',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nextExplainController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: _tEducatorSessions(
                      context, 'Next explain or verify prompt'),
                  hintText: _tEducatorSessions(
                    context,
                    'Optional: what should this learner explain, rebuild, or verify next?',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                value: _markForPortfolio,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _tEducatorSessions(context, 'Flag for portfolio follow-up'),
                ),
                subtitle: Text(
                  _tEducatorSessions(
                    context,
                    'Use this when the artifact or moment should be curated later.',
                  ),
                ),
                onChanged: (bool value) {
                  setState(() => _markForPortfolio = value);
                },
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(_tEducatorSessions(context, 'Cancel')),
        ),
        ElevatedButton.icon(
          onPressed: _isSubmitting ? null : _submit,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_rounded),
          label: Text(_tEducatorSessions(context, 'Capture Evidence')),
        ),
      ],
    );
  }
}

class _CapabilityOption {
  const _CapabilityOption({
    required this.id,
    required this.title,
    required this.pillarCode,
    this.siteId,
  });

  final String id;
  final String title;
  final String pillarCode;
  final String? siteId;

  factory _CapabilityOption.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();
    return _CapabilityOption(
      id: doc.id,
      title: (data['title'] as String? ?? '').trim(),
      pillarCode: (data['pillarCode'] as String? ?? '').trim(),
      siteId: data['siteId'] as String?,
    );
  }
}
