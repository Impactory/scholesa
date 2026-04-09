import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/app_state.dart';
import '../../i18n/site_surface_i18n.dart';
import '../../services/firestore_service.dart';
import '../../services/telemetry_service.dart';
import '../../ui/auth/global_session_menu.dart';
import '../../ui/theme/scholesa_theme.dart';

String _tSiteSessions(BuildContext context, String input) {
  return SiteSurfaceI18n.text(context, input);
}

typedef SiteSessionsLoader = Future<Map<String, List<SiteSessionData>>>
    Function(
  BuildContext context,
  DateTime selectedDate,
);

/// Site Sessions Page - Schedule and manage sessions
class SiteSessionsPage extends StatefulWidget {
  const SiteSessionsPage({
    this.sessionsLoader,
    this.sharedPreferences,
    super.key,
  });

  final SiteSessionsLoader? sessionsLoader;
  final SharedPreferences? sharedPreferences;

  @override
  State<SiteSessionsPage> createState() => _SiteSessionsPageState();
}

class _SiteSessionsPageState extends State<SiteSessionsPage> {
  static const List<String> _supportedViewModes = <String>[
    'day',
    'week',
    'month',
  ];

  DateTime _selectedDate = DateTime.now();
  String _viewMode = 'week';
  SharedPreferences? _prefsCache;
  final Map<String, List<SiteSessionData>> _sessionsByTime =
      <String, List<SiteSessionData>>{};
  final Set<String> _submittingCapabilityRequestIds = <String>{};
  bool _isLoading = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _restoreSavedViewMode();
      if (!mounted) {
        return;
      }
      _logScheduleViewed(trigger: 'page_open');
      _loadSessions();
    });
  }

  Future<SharedPreferences> _prefs() async {
    final SharedPreferences? injected = widget.sharedPreferences;
    if (injected != null) {
      return injected;
    }
    return _prefsCache ??= await SharedPreferences.getInstance();
  }

  String _viewModePrefsKey() {
    final AppState? appState = _maybeAppState();
    final String siteKey = appState?.activeSiteId?.trim().isNotEmpty == true
        ? appState!.activeSiteId!.trim()
        : (appState?.siteIds.isNotEmpty == true
            ? appState!.siteIds.first.trim()
            : 'no-site');
    return 'site_sessions.view_mode.$siteKey';
  }

  String _normalizeViewMode(String? value) {
    if (value == null) {
      return 'week';
    }
    final String normalized =
        value.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
    if (_supportedViewModes.contains(normalized)) {
      return normalized;
    }
    return 'week';
  }

  Future<void> _restoreSavedViewMode() async {
    final SharedPreferences prefs = await _prefs();
    final String restoredMode =
        _normalizeViewMode(prefs.getString(_viewModePrefsKey()));
    if (!mounted) {
      return;
    }
    setState(() => _viewMode = restoredMode);
  }

  Future<void> _setViewMode(String value, {required String trigger}) async {
    final String normalized = _normalizeViewMode(value);
    final SharedPreferences prefs = await _prefs();
    await prefs.setString(_viewModePrefsKey(), normalized);
    if (!mounted) {
      return;
    }
    setState(() => _viewMode = normalized);
    _logScheduleViewed(trigger: trigger);
    await _loadSessions();
  }

  void _logScheduleViewed({required String trigger}) {
    TelemetryService.instance.logEvent(
      event: 'schedule.viewed',
      metadata: <String, dynamic>{
        'module': 'site_sessions',
        'trigger': trigger,
        'view_mode': _viewMode,
        'selected_date': DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
        ).toIso8601String(),
      },
    );
  }

  Future<void> _updateSelectedDate(
    DateTime nextDate, {
    required String trigger,
  }) async {
    setState(() {
      _selectedDate = DateUtils.dateOnly(nextDate);
    });
    _logScheduleViewed(trigger: trigger);
    await _loadSessions();
  }

  List<DateTime> _datesForActiveRange() {
    final DateTime base = DateUtils.dateOnly(_selectedDate);
    switch (_viewMode) {
      case 'day':
        return <DateTime>[base];
      case 'month':
        final DateTime monthStart = DateTime(base.year, base.month, 1);
        final DateTime nextMonth = DateTime(base.year, base.month + 1, 1);
        final int dayCount = nextMonth.difference(monthStart).inDays;
        return List<DateTime>.generate(
          dayCount,
          (int index) => monthStart.add(Duration(days: index)),
        );
      case 'week':
      default:
        final DateTime weekStart =
            base.subtract(Duration(days: base.weekday - 1));
        return List<DateTime>.generate(
          7,
          (int index) => weekStart.add(Duration(days: index)),
        );
    }
  }

  DateTime _previousRangeDate() {
    switch (_viewMode) {
      case 'day':
        return _selectedDate.subtract(const Duration(days: 1));
      case 'month':
        return DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
      case 'week':
      default:
        return _selectedDate.subtract(const Duration(days: 7));
    }
  }

  DateTime _nextRangeDate() {
    switch (_viewMode) {
      case 'day':
        return _selectedDate.add(const Duration(days: 1));
      case 'month':
        return DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
      case 'week':
      default:
        return _selectedDate.add(const Duration(days: 7));
    }
  }

  String _slotLabelForDate(DateTime date, String timeLabel) {
    return '${_getDayAbbrev(date.weekday)} ${date.month}/${date.day} • $timeLabel';
  }

  _SessionConflict? _findSessionConflict(_NewSessionResult result) {
    final List<SiteSessionData> sameSlotSessions =
        _sessionsByTime[result.time] ?? const <SiteSessionData>[];
    for (final SiteSessionData existing in sameSlotSessions) {
      if (existing.room == result.session.room) {
        return const _SessionConflict(type: 'room_double_booked');
      }
      final String existingEducator = existing.educator.trim().toLowerCase();
      final String incomingEducator =
          result.session.educator.trim().toLowerCase();
      if (existingEducator.isNotEmpty &&
          incomingEducator.isNotEmpty &&
          existingEducator == incomingEducator) {
        return const _SessionConflict(type: 'educator_overlap');
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<String, List<SiteSessionData>>> timeSlots =
        _sessionsByTime.entries.toList(growable: false);
    timeSlots.sort((MapEntry<String, List<SiteSessionData>> a,
        MapEntry<String, List<SiteSessionData>> b) {
      return _timeSortKey(a.key).compareTo(_timeSortKey(b.key));
    });

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              ScholesaColors.site.withValues(alpha: 0.05),
              context.schSurface,
              ScholesaColors.scheduleGradient.colors.first
                  .withValues(alpha: 0.03),
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildViewToggle()),
            SliverToBoxAdapter(child: _buildCalendarStrip()),
            SliverToBoxAdapter(child: _buildSessionsHeader()),
            SliverToBoxAdapter(child: _buildCapabilityCoverageBanner()),
            if (!_isLoading && _loadError != null && _sessionsByTime.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: _buildStaleDataBanner(_loadError!),
                ),
              ),
            if (_isLoading)
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    _tSiteSessions(context, 'Loading...'),
                    style: const TextStyle(color: ScholesaColors.textSecondary),
                  ),
                ),
              ),
            if (!_isLoading && _loadError != null && timeSlots.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildLoadErrorState(_loadError!),
                ),
              ),
            if (!_isLoading && timeSlots.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    _tSiteSessions(context, 'No sessions scheduled'),
                    style: const TextStyle(color: ScholesaColors.textSecondary),
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final MapEntry<String, List<SiteSessionData>> slot
                        in timeSlots)
                      _SessionTimeSlot(
                        time: slot.key,
                        sessions: slot.value,
                        onRequestCapabilityMapping: _requestCapabilityMapping,
                        submittingCapabilityRequestIds:
                            _submittingCapabilityRequestIds,
                      ),
                  ],
                ),
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewSession,
        backgroundColor: ScholesaColors.site,
        icon: const Icon(Icons.add),
        label: Text(_tSiteSessions(context, 'New Session')),
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
                gradient: ScholesaColors.scheduleGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: ScholesaColors.site.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.calendar_month,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _tSiteSessions(context, 'Session Schedule'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: ScholesaColors.site,
                        ),
                  ),
                  Text(
                    _tSiteSessions(context, 'Manage site sessions and rooms'),
                    style: TextStyle(
                        color: context.schTextSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const SessionMenuHeaderAction(
              foregroundColor: ScholesaColors.site,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: context.schSurfaceMuted,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: _ViewToggleButton(
                label: _tSiteSessions(context, 'Day'),
                isSelected: _viewMode == 'day',
                onTap: () {
                  TelemetryService.instance.logEvent(
                    event: 'cta.clicked',
                    metadata: <String, dynamic>{
                      'module': 'site_sessions',
                      'cta_id': 'set_view_mode',
                      'surface': 'view_toggle',
                      'view_mode': 'day',
                    },
                  );
                  _setViewMode('day', trigger: 'view_mode_day');
                },
              ),
            ),
            Expanded(
              child: _ViewToggleButton(
                label: _tSiteSessions(context, 'Week'),
                isSelected: _viewMode == 'week',
                onTap: () {
                  TelemetryService.instance.logEvent(
                    event: 'cta.clicked',
                    metadata: <String, dynamic>{
                      'module': 'site_sessions',
                      'cta_id': 'set_view_mode',
                      'surface': 'view_toggle',
                      'view_mode': 'week',
                    },
                  );
                  _setViewMode('week', trigger: 'view_mode_week');
                },
              ),
            ),
            Expanded(
              child: _ViewToggleButton(
                label: _tSiteSessions(context, 'Month'),
                isSelected: _viewMode == 'month',
                onTap: () {
                  TelemetryService.instance.logEvent(
                    event: 'cta.clicked',
                    metadata: <String, dynamic>{
                      'module': 'site_sessions',
                      'cta_id': 'set_view_mode',
                      'surface': 'view_toggle',
                      'view_mode': 'month',
                    },
                  );
                  _setViewMode('month', trigger: 'view_mode_month');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarStrip() {
    if (_viewMode == 'month') {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: context.schSurfaceMuted,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: <Widget>[
              IconButton(
                onPressed: () async {
                  await _updateSelectedDate(
                    _previousRangeDate(),
                    trigger: 'navigate_previous_month',
                  );
                },
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  _formatSelectedDate(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                onPressed: () async {
                  await _updateSelectedDate(
                    _nextRangeDate(),
                    trigger: 'navigate_next_month',
                  );
                },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      );
    }

    final DateTime today = DateUtils.dateOnly(DateTime.now());
    final DateTime weekAnchor = DateUtils.dateOnly(_selectedDate);
    final List<DateTime> weekDays = List<DateTime>.generate(
      7,
      (int i) =>
          weekAnchor.subtract(Duration(days: weekAnchor.weekday - 1 - i)),
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () async {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'module': 'site_sessions',
                  'cta_id': 'navigate_previous_week',
                  'surface': 'calendar_strip',
                },
              );
              await _updateSelectedDate(
                _previousRangeDate(),
                trigger: _viewMode == 'day'
                    ? 'navigate_previous_day'
                    : 'navigate_previous_week',
              );
            },
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: weekDays.map((DateTime date) {
                final bool isSelected = date.day == _selectedDate.day &&
                    date.month == _selectedDate.month;
                final bool isToday =
                    date.day == today.day && date.month == today.month;
                return GestureDetector(
                  onTap: () async {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: <String, dynamic>{
                        'module': 'site_sessions',
                        'cta_id': 'select_calendar_date',
                        'surface': 'calendar_strip',
                        'date': date.toIso8601String(),
                      },
                    );
                    await _updateSelectedDate(
                      date,
                      trigger: 'select_date',
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? ScholesaColors.site
                          : isToday
                              ? ScholesaColors.site.withValues(alpha: 0.1)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: <Widget>[
                        Text(
                          _getDayAbbrev(date.weekday),
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : isToday
                                    ? ScholesaColors.site
                                    : context.schTextSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          date.day.toString(),
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : isToday
                                    ? ScholesaColors.site
                                    : Colors.grey[800],
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          IconButton(
            onPressed: () async {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'module': 'site_sessions',
                  'cta_id': 'navigate_next_week',
                  'surface': 'calendar_strip',
                },
              );
              await _updateSelectedDate(
                _nextRangeDate(),
                trigger: _viewMode == 'day'
                    ? 'navigate_next_day'
                    : 'navigate_next_week',
              );
            },
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            _formatSelectedDate(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          Row(
            children: <Widget>[
              IconButton(
                tooltip: _tSiteSessions(context, 'Refresh'),
                onPressed: _isLoading ? null : _loadSessions,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
              TextButton.icon(
                onPressed: () {
                  TelemetryService.instance.logEvent(
                    event: 'cta.clicked',
                    metadata: <String, dynamic>{
                      'module': 'site_sessions',
                      'cta_id': 'open_filter_sheet',
                      'surface': 'sessions_header',
                    },
                  );
                  _showFilterSheet();
                },
                icon: const Icon(Icons.filter_list, size: 18),
                label: Text(_tSiteSessions(context, 'Filter')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCapabilityCoverageBanner() {
    final List<SiteSessionData> blockedSessions = _blockedSessions();
    if (blockedSessions.isEmpty) {
      return const SizedBox.shrink();
    }

    final int openRequestCount = blockedSessions
        .where((SiteSessionData session) => session.hasOpenCapabilityRequest)
        .length;
    final int pendingRequestCount = blockedSessions.length - openRequestCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFB45309),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _tSiteSessions(
                      context,
                      'Upcoming sessions blocked by capability mapping',
                    ),
                    style: const TextStyle(
                      color: ScholesaColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${blockedSessions.length} ${_tSiteSessions(context, 'sessions are currently waiting on HQ capability mappings before educators can log live evidence.')}',
              style: const TextStyle(color: ScholesaColors.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              '$openRequestCount ${_tSiteSessions(context, 'request open')} • $pendingRequestCount ${_tSiteSessions(context, 'not yet requested')}',
              style: const TextStyle(
                color: ScholesaColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.schSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _tSiteSessions(context, 'Session Filters'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: <String>['day', 'week', 'month']
                    .map(
                      (String mode) => ChoiceChip(
                        label: Text(mode.toUpperCase()),
                        selected: _viewMode == mode,
                        onSelected: (_) async {
                          final messenger =
                              ScaffoldMessenger.of(context);
                          final snackText =
                              '${_tSiteSessions(context, 'Showing')} ${_modeLabel(context, mode)} ${_tSiteSessions(context, 'view')}';
                          TelemetryService.instance.logEvent(
                            event: 'cta.clicked',
                            metadata: <String, dynamic>{
                              'module': 'site_sessions',
                              'cta_id': 'apply_filter_view_mode',
                              'surface': 'filter_sheet',
                              'view_mode': mode,
                            },
                          );
                          await _setViewMode(
                            mode,
                            trigger: 'filter_view_mode',
                          );
                          if (!mounted) return;
                          Navigator.pop(sheetContext); // ignore: use_build_context_synchronously
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(snackText),
                              backgroundColor: ScholesaColors.site,
                            ),
                          );
                        },
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDayAbbrev(int weekday) {
    const List<String> days = <String>[
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun'
    ];
    return _tSiteSessions(context, days[weekday - 1]);
  }

  String _modeLabel(BuildContext context, String mode) {
    switch (mode) {
      case 'day':
        return _tSiteSessions(context, 'Day').toUpperCase();
      case 'week':
        return _tSiteSessions(context, 'Week').toUpperCase();
      case 'month':
        return _tSiteSessions(context, 'Month').toUpperCase();
      default:
        return mode.toUpperCase();
    }
  }

  String _formatSelectedDate() {
    const List<String> months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    final String month =
        _tSiteSessions(context, months[_selectedDate.month - 1]);
    if (_viewMode == 'month') {
      return '$month ${_selectedDate.year}';
    }
    if (_viewMode == 'week') {
      final DateTime weekStart =
          _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
      final DateTime weekEnd = weekStart.add(const Duration(days: 6));
      final String startMonth =
          _tSiteSessions(context, months[weekStart.month - 1]);
      final String endMonth =
          _tSiteSessions(context, months[weekEnd.month - 1]);
      if (weekStart.month == weekEnd.month) {
        return '$startMonth ${weekStart.day}-${weekEnd.day}, ${weekEnd.year}';
      }
      return '$startMonth ${weekStart.day} - $endMonth ${weekEnd.day}, ${weekEnd.year}';
    }
    return '$month ${_selectedDate.day}, ${_selectedDate.year}';
  }

  Future<void> _createNewSession() async {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'site_sessions',
        'cta_id': 'open_create_session_sheet',
        'surface': 'floating_action_button',
      },
    );
    final _NewSessionResult? result =
        await showModalBottomSheet<_NewSessionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => const _CreateSessionSheet(),
    );

    if (result == null || !mounted) {
      return;
    }

    final _SessionConflict? conflict = _findSessionConflict(result);
    if (conflict != null) {
      TelemetryService.instance.logEvent(
        event: 'room.conflict.detected',
        metadata: <String, dynamic>{
          'module': 'site_sessions',
          'conflict_type': conflict.type,
          'time_slot': result.time,
          'room': result.session.room,
        },
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tSiteSessions(context,
              'Conflict detected: room or educator already assigned in this time slot')),
          backgroundColor: ScholesaColors.warning,
        ),
      );
      return;
    }

    final bool persisted = await _persistSession(result);
    if (!mounted) {
      return;
    }
    if (!persisted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tSiteSessions(context, 'Unable to create session right now'),
          ),
          backgroundColor: ScholesaColors.error,
        ),
      );
      return;
    }

    setState(() {
      _sessionsByTime.putIfAbsent(result.time, () => <SiteSessionData>[]);
      _sessionsByTime[result.time]!.add(result.session);
    });

    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'site_sessions',
        'cta_id': 'submit_create_session',
        'surface': 'create_session_sheet',
        'time_slot': result.time,
        'pillar': result.session.pillar,
      },
    );
    _logScheduleViewed(trigger: 'session_created');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_tSiteSessions(context, 'Session created successfully')),
        backgroundColor: ScholesaColors.success,
      ),
    );

    await _loadSessions();
  }

  Future<void> _loadSessions() async {
    final bool hadSessions = _sessionsByTime.isNotEmpty;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final SiteSessionsLoader loader =
          widget.sessionsLoader ?? _loadSessionsFromFirestore;
      final Map<String, List<SiteSessionData>> grouped =
          <String, List<SiteSessionData>>{};
      for (final DateTime date in _datesForActiveRange()) {
        final Map<String, List<SiteSessionData>> daily =
            await loader(context, date);
        daily.forEach((String timeLabel, List<SiteSessionData> sessions) {
          final String slotLabel = _viewMode == 'day'
              ? timeLabel
              : _slotLabelForDate(date, timeLabel);
          grouped
              .putIfAbsent(slotLabel, () => <SiteSessionData>[])
              .addAll(sessions);
        });
      }

      if (!mounted) return;
      setState(() {
        _sessionsByTime
          ..clear()
          ..addAll(grouped);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = hadSessions
            ? _tSiteSessions(
                context,
                'Unable to refresh sessions right now. Showing the last successful data.',
              )
            : _tSiteSessions(
                context,
                'We could not load sessions right now. Retry to check the current state.',
              );
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<Map<String, List<SiteSessionData>>> _loadSessionsFromFirestore(
    BuildContext context,
    DateTime selectedDate,
  ) async {
    final FirestoreService? firestoreService = _maybeFirestoreService();
    final AppState? appState = _maybeAppState();
    if (firestoreService == null || appState == null) {
      return <String, List<SiteSessionData>>{};
    }

    final String siteId = (appState.activeSiteId ??
            (appState.siteIds.isNotEmpty ? appState.siteIds.first : ''))
        .trim();
    if (siteId.isEmpty) {
      return <String, List<SiteSessionData>>{};
    }

    Query<Map<String, dynamic>> query =
        firestoreService.firestore.collection('sessions');
    try {
      query = query.where('siteId', isEqualTo: siteId);
    } catch (_) {}

    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await query.orderBy('startTime').limit(300).get();
    } catch (_) {
      try {
        snapshot =
            await query.orderBy('createdAt', descending: true).limit(300).get();
      } catch (_) {
        snapshot = await query.limit(300).get();
      }
    }

    final QuerySnapshot<Map<String, dynamic>> capabilitySnapshot =
        await firestoreService.firestore
            .collection('capabilities')
            .limit(500)
            .get();
    final Map<String, int> scopedCapabilityCounts = <String, int>{};
    final Map<String, int> globalCapabilityCounts = <String, int>{};
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in capabilitySnapshot.docs) {
      final Map<String, dynamic> capability = doc.data();
      final String pillarCode = _capabilityMappingPillarCode(
          capability['pillarCode'] as String? ?? '');
      if (pillarCode.isEmpty) {
        continue;
      }
      final String capabilitySiteId =
          (capability['siteId'] as String? ?? '').trim();
      if (capabilitySiteId.isEmpty) {
        globalCapabilityCounts[pillarCode] =
            (globalCapabilityCounts[pillarCode] ?? 0) + 1;
      } else {
        final String key = '$capabilitySiteId|$pillarCode';
        scopedCapabilityCounts[key] = (scopedCapabilityCounts[key] ?? 0) + 1;
      }
    }

    final QuerySnapshot<Map<String, dynamic>> supportRequestSnapshot =
        await firestoreService.firestore
            .collection('supportRequests')
            .where('siteId', isEqualTo: siteId)
            .limit(200)
            .get();
    final Map<String, _CapabilityRequestSnapshot>
        capabilityRequestsBySessionId = <String, _CapabilityRequestSnapshot>{};
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in supportRequestSnapshot.docs) {
      final Map<String, dynamic> request = doc.data();
      if ((request['requestType'] as String? ?? '').trim() !=
          'session_capability_mapping') {
        continue;
      }
      final String status =
          (request['status'] as String? ?? 'open').trim().toLowerCase();
      if (status == 'closed') {
        continue;
      }
      final Map<String, dynamic> metadata = Map<String, dynamic>.from(
          request['metadata'] as Map? ?? <String, dynamic>{});
      final String sessionId = (metadata['sessionId'] as String? ?? '').trim();
      if (sessionId.isEmpty) {
        continue;
      }

      final List<String> supportingCapabilityTitles =
          ((request['resolutionSupportingCapabilityTitles'] as List?) ??
                  const <dynamic>[])
              .map((dynamic value) => value.toString().trim())
              .where((String value) => value.isNotEmpty)
              .toList(growable: false);
      final List<String> supportingCurriculumTitles =
          ((request['resolutionSupportingCurriculumTitles'] as List?) ??
                  const <dynamic>[])
              .map((dynamic value) => value.toString().trim())
              .where((String value) => value.isNotEmpty)
              .toList(growable: false);
      final DateTime sortAt = _toDateTime(request['updatedAt']) ??
          _toDateTime(request['resolvedAt']) ??
          _toDateTime(request['submittedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final int? supportingCapabilityCount =
          switch (request['resolutionSupportingCapabilityCount']) {
        int value => value,
        num value => value.toInt(),
        _ => null,
      };
      final _CapabilityRequestSnapshot candidate = _CapabilityRequestSnapshot(
        status: status,
        sortAt: sortAt,
        resolvedAt: _toDateTime(request['resolvedAt']),
        resolutionSummary: (request['resolutionSummary'] as String?)?.trim(),
        resolutionOperatorNote:
            (request['resolutionOperatorNote'] as String?)?.trim(),
        resolutionSupportingCapabilityCount: supportingCapabilityCount,
        resolutionSupportingCapabilityTitles: supportingCapabilityTitles,
        resolutionSupportingCurriculumTitles: supportingCurriculumTitles,
      );
      final _CapabilityRequestSnapshot? existing =
          capabilityRequestsBySessionId[sessionId];
      if (existing == null || candidate.sortAt.isAfter(existing.sortAt)) {
        capabilityRequestsBySessionId[sessionId] = candidate;
      }
    }

    final Map<String, List<SiteSessionData>> grouped =
        <String, List<SiteSessionData>>{};
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      final DateTime? sessionDate = _toDateTime(data['startTime']) ??
          _toDateTime(data['startDate']) ??
          _toDateTime(data['date']);
      if (sessionDate == null ||
          !_isSameCalendarDate(sessionDate, selectedDate)) {
        continue;
      }
      final String slot = _sessionTimeSlot(data);
      final String capabilityPillarCode =
          _capabilityMappingPillarCode(_sessionPillar(data));
      final int mappedCapabilityCount =
          (scopedCapabilityCounts['$siteId|$capabilityPillarCode'] ?? 0) +
              (globalCapabilityCounts[capabilityPillarCode] ?? 0);
      final SiteSessionData session = SiteSessionData(
        id: doc.id,
        title: _sessionTitle(data, doc.id),
        educator: _sessionEducator(data),
        room: _sessionRoom(data),
        learnerCount: _sessionLearnerCount(data),
        pillar: _sessionPillar(data),
        mappedCapabilityCount: mappedCapabilityCount,
        hasOpenCapabilityRequest:
            capabilityRequestsBySessionId[doc.id]?.status == 'open',
        capabilityRequestStatus:
            capabilityRequestsBySessionId[doc.id]?.status ?? '',
        capabilityRequestResolutionSummary:
            capabilityRequestsBySessionId[doc.id]?.resolutionSummary,
        capabilityRequestResolutionOperatorNote:
            capabilityRequestsBySessionId[doc.id]?.resolutionOperatorNote,
        capabilityRequestResolvedAt:
            capabilityRequestsBySessionId[doc.id]?.resolvedAt,
        capabilityRequestResolvedSupportingCapabilityCount:
            capabilityRequestsBySessionId[doc.id]
                ?.resolutionSupportingCapabilityCount,
        capabilityRequestResolvedSupportingCapabilityTitles:
            capabilityRequestsBySessionId[doc.id]
                    ?.resolutionSupportingCapabilityTitles ??
                const <String>[],
        capabilityRequestResolvedSupportingCurriculumTitles:
            capabilityRequestsBySessionId[doc.id]
                    ?.resolutionSupportingCurriculumTitles ??
                const <String>[],
      );
      grouped.putIfAbsent(slot, () => <SiteSessionData>[]).add(session);
    }
    return grouped;
  }

  List<SiteSessionData> _blockedSessions() {
    return _sessionsByTime.values
        .expand((List<SiteSessionData> sessions) => sessions)
        .where((SiteSessionData session) => session.mappedCapabilityCount <= 0)
        .toList(growable: false);
  }

  Future<void> _requestCapabilityMapping(SiteSessionData session) async {
    if (session.id.isEmpty ||
        _submittingCapabilityRequestIds.contains(session.id) ||
        session.hasOpenCapabilityRequest) {
      return;
    }
    final FirestoreService? firestoreService = _maybeFirestoreService();
    final AppState? appState = _maybeAppState();
    final String siteId = (appState?.activeSiteId ??
            (appState?.siteIds.isNotEmpty == true
                ? appState!.siteIds.first
                : ''))
        .trim();
    final String userId = (appState?.userId ?? '').trim();
    final String userEmail = (appState?.email ?? '').trim();
    final String userName = (appState?.displayName ?? '').trim();
    final String role = appState?.role?.name ?? '';
    if (firestoreService == null ||
        siteId.isEmpty ||
        userId.isEmpty ||
        userEmail.isEmpty ||
        userName.isEmpty ||
        role.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tSiteSessions(
              context,
              'Unable to submit HQ mapping request right now. Refresh your session and try again.',
            ),
          ),
          backgroundColor: ScholesaColors.error,
        ),
      );
      return;
    }

    setState(() {
      _submittingCapabilityRequestIds.add(session.id);
    });
    try {
      final String requestId = await firestoreService.submitSupportRequest(
        requestType: 'session_capability_mapping',
        source: 'site_sessions_request_capability_mapping',
        siteId: siteId,
        userId: userId,
        userEmail: userEmail,
        userName: userName,
        role: role,
        subject: 'Session capability mapping request: ${session.title}',
        message:
            'Educators are blocked from live evidence capture until HQ maps at least one capability for the ${session.pillar} pillar.',
        metadata: <String, dynamic>{
          'sessionId': session.id,
          'sessionTitle': session.title,
          'pillar': session.pillar,
          'educator': session.educator,
          'room': session.room,
          'learnerCount': session.learnerCount,
          'mappedCapabilityCount': session.mappedCapabilityCount,
        },
      );
      TelemetryService.instance.logEvent(
        event: 'site.session_capability_mapping_request.submitted',
        metadata: <String, dynamic>{
          'request_id': requestId,
          'session_id': session.id,
          'pillar': session.pillar,
        },
      );
      if (!mounted) return;
      setState(() {
        _markCapabilityRequestOpen(session.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tSiteSessions(context, 'HQ mapping request submitted.'),
          ),
          backgroundColor: ScholesaColors.success,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      TelemetryService.instance.logEvent(
        event: 'site.session_capability_mapping_request.failed',
        metadata: <String, dynamic>{
          'session_id': session.id,
          'pillar': session.pillar,
        },
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tSiteSessions(
              context,
              'Unable to submit HQ mapping request right now.',
            ),
          ),
          backgroundColor: ScholesaColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submittingCapabilityRequestIds.remove(session.id);
        });
      }
    }
  }

  void _markCapabilityRequestOpen(String sessionId) {
    _sessionsByTime.updateAll(
      (String key, List<SiteSessionData> value) => value
          .map(
            (SiteSessionData session) => session.id == sessionId
                ? session.copyWith(
                    hasOpenCapabilityRequest: true,
                    capabilityRequestStatus: 'open',
                    capabilityRequestResolutionSummary: '',
                    capabilityRequestResolutionOperatorNote: '',
                    capabilityRequestResolvedAt: null,
                    capabilityRequestResolvedSupportingCapabilityCount: null,
                    capabilityRequestResolvedSupportingCapabilityTitles: const <String>[],
                    capabilityRequestResolvedSupportingCurriculumTitles: const <String>[],
                  )
                : session,
          )
          .toList(growable: false),
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
              Icon(Icons.error_outline_rounded, color: ScholesaColors.error),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  _tSiteSessions(context, 'Unable to load sessions'),
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
            onPressed: _loadSessions,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(_tSiteSessions(context, 'Retry')),
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
              message,
              style: const TextStyle(color: Color(0xFF92400E)),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _persistSession(_NewSessionResult result) async {
    final FirestoreService? firestoreService = _maybeFirestoreService();
    final AppState? appState = _maybeAppState();
    if (firestoreService == null || appState == null) {
      return false;
    }

    final String siteId = (appState.activeSiteId ??
            (appState.siteIds.isNotEmpty ? appState.siteIds.first : ''))
        .trim();
    if (siteId.isEmpty) {
      return false;
    }

    try {
      final DateTime? startTime =
          _dateWithTimeLabel(_selectedDate, result.time);
      final WriteBatch batch = firestoreService.firestore.batch();
      final CollectionReference<Map<String, dynamic>> sessions =
          firestoreService.firestore.collection('sessions');
      final DocumentReference<Map<String, dynamic>> sessionRef = sessions.doc();
      batch.set(sessionRef, <String, dynamic>{
        'siteId': siteId,
        'title': result.session.title,
        'educatorName': result.session.educator,
        'room': result.session.room,
        'learnerCount': result.session.learnerCount,
        'pillar': result.session.pillar,
        'pillarCode': _pillarCode(result.session.pillar),
        'timeSlot': result.time,
        if (startTime != null) 'startTime': Timestamp.fromDate(startTime),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': appState.userId,
      });

      if (startTime != null) {
        final DocumentReference<Map<String, dynamic>> occurrenceRef =
            firestoreService.firestore.collection('sessionOccurrences').doc();
        batch.set(occurrenceRef, <String, dynamic>{
          'sessionId': sessionRef.id,
          'siteId': siteId,
          'title': result.session.title,
          'startTime': Timestamp.fromDate(startTime),
          'endTime': Timestamp.fromDate(
            startTime.add(const Duration(hours: 1)),
          ),
          'roomName': result.session.room,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': appState.userId,
        });
      }

      await batch.commit();
      return true;
    } catch (_) {
      return false;
    }
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

  String _sessionTimeSlot(Map<String, dynamic> data) {
    final String? label = (data['timeSlot'] as String?)?.trim();
    if (label != null && label.isNotEmpty) return label;
    final DateTime? startTime = _toDateTime(data['startTime']) ??
        _toDateTime(data['startDate']) ??
        _toDateTime(data['date']);
    if (startTime != null) {
      return _timeLabel(startTime);
    }
    return _tSiteSessions(context, 'Unassigned');
  }

  String _sessionTitle(Map<String, dynamic> data, String fallback) {
    final String title =
        ((data['title'] as String?) ?? (data['name'] as String?) ?? '').trim();
    return title.isNotEmpty ? title : fallback;
  }

  String _sessionEducator(Map<String, dynamic> data) {
    final String educator = ((data['educatorName'] as String?) ??
            (data['educatorDisplayName'] as String?) ??
            (data['educatorId'] as String?) ??
            '')
        .trim();
    return educator.isNotEmpty
        ? educator
        : _tSiteSessions(context, 'Unassigned');
  }

  String _sessionRoom(Map<String, dynamic> data) {
    final String room = ((data['room'] as String?) ??
            (data['roomName'] as String?) ??
            (data['location'] as String?) ??
            '')
        .trim();
    return room.isNotEmpty ? room : _tSiteSessions(context, 'Unassigned');
  }

  int _sessionLearnerCount(Map<String, dynamic> data) {
    final dynamic raw = data['learnerCount'] ?? data['enrollmentCount'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }

  String _sessionPillar(Map<String, dynamic> data) {
    final String direct = ((data['pillar'] as String?) ?? '').trim();
    if (direct.isNotEmpty) return direct;
    final String code =
        ((data['pillarCode'] as String?) ?? '').trim().toLowerCase();
    switch (code) {
      case 'future_skills':
      case 'future-skills':
      case 'future skills':
        return 'Future Skills';
      case 'leadership_agency':
      case 'leadership-agency':
      case 'leadership':
      case 'leadership & agency':
        return 'Leadership';
      case 'impact_innovation':
      case 'impact-innovation':
      case 'impact':
      case 'impact & innovation':
        return 'Impact';
      default:
        return 'Future Skills';
    }
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }

  bool _isSameCalendarDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  int _timeSortKey(String label) {
    final RegExp datedRegex = RegExp(
      r'^(?:[^\d]*?)?(\d{1,2})\/(\d{1,2})\s+•\s+(\d{1,2}:\d{2}\s*[AP]M)$',
      caseSensitive: false,
    );
    final Match? datedMatch = datedRegex.firstMatch(label.trim());
    if (datedMatch != null) {
      final int month = int.tryParse(datedMatch.group(1) ?? '') ?? 1;
      final int day = int.tryParse(datedMatch.group(2) ?? '') ?? 1;
      final DateTime baseDate = DateTime(_selectedDate.year, month, day);
      final DateTime? parsed =
          _dateWithTimeLabel(baseDate, datedMatch.group(3) ?? '');
      if (parsed != null) {
        return parsed.millisecondsSinceEpoch ~/ 60000;
      }
    }
    final DateTime? parsed = _dateWithTimeLabel(_selectedDate, label);
    if (parsed == null) return 24 * 60;
    return parsed.millisecondsSinceEpoch ~/ 60000;
  }

  DateTime? _dateWithTimeLabel(DateTime baseDate, String label) {
    final RegExp regex =
        RegExp(r'^(\d{1,2}):(\d{2})\s*([AP]M)$', caseSensitive: false);
    final Match? match = regex.firstMatch(label.trim());
    if (match == null) return null;
    int hour = int.tryParse(match.group(1) ?? '') ?? 0;
    final int minute = int.tryParse(match.group(2) ?? '') ?? 0;
    final String meridiem = (match.group(3) ?? '').toUpperCase();
    if (hour < 1 || hour > 12 || minute > 59) return null;
    if (meridiem == 'PM' && hour != 12) hour += 12;
    if (meridiem == 'AM' && hour == 12) hour = 0;
    return DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
  }

  String _timeLabel(DateTime value) {
    int hour = value.hour;
    final String meridiem = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    final String minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute $meridiem';
  }

  String _pillarCode(String pillar) {
    switch (pillar.toLowerCase()) {
      case 'leadership':
      case 'leadership & agency':
        return 'leadership_agency';
      case 'impact':
      case 'impact & innovation':
        return 'impact_innovation';
      case 'future skills':
      default:
        return 'future_skills';
    }
  }

  String _capabilityMappingPillarCode(String pillar) {
    switch (pillar.trim().toLowerCase()) {
      case 'leadership':
      case 'leadership & agency':
        return 'LEAD';
      case 'impact':
      case 'impact & innovation':
        return 'IMP';
      case 'future skills':
      default:
        return 'FS';
    }
  }
}

class _NewSessionResult {
  const _NewSessionResult({required this.time, required this.session});

  final String time;
  final SiteSessionData session;
}

class _SessionConflict {
  const _SessionConflict({required this.type});

  final String type;
}

class _ViewToggleButton extends StatelessWidget {
  const _ViewToggleButton({
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? ScholesaColors.site : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : context.schTextSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class SiteSessionData {
  const SiteSessionData({
    this.id = '',
    required this.title,
    required this.educator,
    required this.room,
    required this.learnerCount,
    required this.pillar,
    this.mappedCapabilityCount = 0,
    this.hasOpenCapabilityRequest = false,
    this.capabilityRequestStatus = '',
    this.capabilityRequestResolutionSummary,
    this.capabilityRequestResolutionOperatorNote,
    this.capabilityRequestResolvedAt,
    this.capabilityRequestResolvedSupportingCapabilityCount,
    this.capabilityRequestResolvedSupportingCapabilityTitles = const <String>[],
    this.capabilityRequestResolvedSupportingCurriculumTitles = const <String>[],
  });
  final String id;
  final String title;
  final String educator;
  final String room;
  final int learnerCount;
  final String pillar;
  final int mappedCapabilityCount;
  final bool hasOpenCapabilityRequest;
  final String capabilityRequestStatus;
  final String? capabilityRequestResolutionSummary;
  final String? capabilityRequestResolutionOperatorNote;
  final DateTime? capabilityRequestResolvedAt;
  final int? capabilityRequestResolvedSupportingCapabilityCount;
  final List<String> capabilityRequestResolvedSupportingCapabilityTitles;
  final List<String> capabilityRequestResolvedSupportingCurriculumTitles;

  bool get hasResolvedCapabilityRequest =>
      capabilityRequestStatus == 'resolved';

  SiteSessionData copyWith({
    String? id,
    String? title,
    String? educator,
    String? room,
    int? learnerCount,
    String? pillar,
    int? mappedCapabilityCount,
    bool? hasOpenCapabilityRequest,
    String? capabilityRequestStatus,
    String? capabilityRequestResolutionSummary,
    String? capabilityRequestResolutionOperatorNote,
    DateTime? capabilityRequestResolvedAt,
    int? capabilityRequestResolvedSupportingCapabilityCount,
    List<String>? capabilityRequestResolvedSupportingCapabilityTitles,
    List<String>? capabilityRequestResolvedSupportingCurriculumTitles,
  }) {
    return SiteSessionData(
      id: id ?? this.id,
      title: title ?? this.title,
      educator: educator ?? this.educator,
      room: room ?? this.room,
      learnerCount: learnerCount ?? this.learnerCount,
      pillar: pillar ?? this.pillar,
      mappedCapabilityCount:
          mappedCapabilityCount ?? this.mappedCapabilityCount,
      hasOpenCapabilityRequest:
          hasOpenCapabilityRequest ?? this.hasOpenCapabilityRequest,
      capabilityRequestStatus:
          capabilityRequestStatus ?? this.capabilityRequestStatus,
      capabilityRequestResolutionSummary: capabilityRequestResolutionSummary ??
          this.capabilityRequestResolutionSummary,
      capabilityRequestResolutionOperatorNote:
          capabilityRequestResolutionOperatorNote ??
              this.capabilityRequestResolutionOperatorNote,
      capabilityRequestResolvedAt:
          capabilityRequestResolvedAt ?? this.capabilityRequestResolvedAt,
      capabilityRequestResolvedSupportingCapabilityCount:
          capabilityRequestResolvedSupportingCapabilityCount ??
              this.capabilityRequestResolvedSupportingCapabilityCount,
      capabilityRequestResolvedSupportingCapabilityTitles:
          capabilityRequestResolvedSupportingCapabilityTitles ??
              this.capabilityRequestResolvedSupportingCapabilityTitles,
      capabilityRequestResolvedSupportingCurriculumTitles:
          capabilityRequestResolvedSupportingCurriculumTitles ??
              this.capabilityRequestResolvedSupportingCurriculumTitles,
    );
  }
}

class _CapabilityRequestSnapshot {
  const _CapabilityRequestSnapshot({
    required this.status,
    required this.sortAt,
    this.resolvedAt,
    this.resolutionSummary,
    this.resolutionOperatorNote,
    this.resolutionSupportingCapabilityCount,
    this.resolutionSupportingCapabilityTitles = const <String>[],
    this.resolutionSupportingCurriculumTitles = const <String>[],
  });

  final String status;
  final DateTime sortAt;
  final DateTime? resolvedAt;
  final String? resolutionSummary;
  final String? resolutionOperatorNote;
  final int? resolutionSupportingCapabilityCount;
  final List<String> resolutionSupportingCapabilityTitles;
  final List<String> resolutionSupportingCurriculumTitles;
}

class _SessionTimeSlot extends StatelessWidget {
  const _SessionTimeSlot({
    required this.time,
    required this.sessions,
    required this.onRequestCapabilityMapping,
    required this.submittingCapabilityRequestIds,
  });
  final String time;
  final List<SiteSessionData> sessions;
  final ValueChanged<SiteSessionData> onRequestCapabilityMapping;
  final Set<String> submittingCapabilityRequestIds;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 70,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                time,
                style: TextStyle(
                  color: context.schTextSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: sessions
                  .map(
                    (SiteSessionData session) => _SessionCard(
                      session: session,
                      onRequestCapabilityMapping: onRequestCapabilityMapping,
                      isSubmittingCapabilityRequest:
                          submittingCapabilityRequestIds.contains(session.id),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.onRequestCapabilityMapping,
    required this.isSubmittingCapabilityRequest,
  });
  final SiteSessionData session;
  final ValueChanged<SiteSessionData> onRequestCapabilityMapping;
  final bool isSubmittingCapabilityRequest;

  Color get _pillarColor {
    switch (session.pillar.toLowerCase()) {
      case 'future skills':
        return ScholesaColors.futureSkills;
      case 'leadership':
        return ScholesaColors.leadership;
      case 'impact':
        return ScholesaColors.impact;
      default:
        return ScholesaColors.site;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool blocked = session.mappedCapabilityCount <= 0;
    final bool resolvedWhileBlocked =
        blocked && session.hasResolvedCapabilityRequest;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: _pillarColor, width: 4)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    session.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _pillarColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _tSiteSessions(context, session.pillar),
                    style: TextStyle(
                      color: _pillarColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Icon(Icons.person,
                    size: 14,
                    color: context.schTextSecondary.withValues(alpha: 0.88)),
                const SizedBox(width: 4),
                Text(
                  session.educator,
                  style:
                      TextStyle(color: context.schTextSecondary, fontSize: 12),
                ),
                const SizedBox(width: 16),
                Icon(Icons.meeting_room,
                    size: 14,
                    color: context.schTextSecondary.withValues(alpha: 0.88)),
                const SizedBox(width: 4),
                Text(
                  session.room,
                  style:
                      TextStyle(color: context.schTextSecondary, fontSize: 12),
                ),
                const Spacer(),
                Icon(Icons.people,
                    size: 14,
                    color: context.schTextSecondary.withValues(alpha: 0.88)),
                const SizedBox(width: 4),
                Text(
                  '${session.learnerCount}',
                  style:
                      TextStyle(color: context.schTextSecondary, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildCapabilityStatus(context),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  if (blocked)
                    OutlinedButton.icon(
                      onPressed: session.hasOpenCapabilityRequest ||
                              resolvedWhileBlocked ||
                              isSubmittingCapabilityRequest
                          ? null
                          : () => onRequestCapabilityMapping(session),
                      icon: isSubmittingCapabilityRequest
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              resolvedWhileBlocked
                                  ? Icons.task_alt_rounded
                                  : session.hasOpenCapabilityRequest
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.mail_outline_rounded,
                              size: 16,
                            ),
                      label: Text(
                        resolvedWhileBlocked
                            ? _tSiteSessions(context, 'HQ resolved request')
                            : session.hasOpenCapabilityRequest
                                ? _tSiteSessions(
                                    context, 'HQ mapping request open')
                                : _tSiteSessions(context, 'Request HQ mapping'),
                      ),
                    ),
                  TextButton.icon(
                    onPressed: () => _showAssignSubstituteSheet(context),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                    label: Text(_tSiteSessions(context, 'Assign Substitute')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapabilityStatus(BuildContext context) {
    final bool blocked = session.mappedCapabilityCount <= 0;
    final Color badgeColor =
        blocked ? const Color(0xFF9A3412) : const Color(0xFF166534);
    final Color badgeBackground =
        blocked ? const Color(0xFFFFEDD5) : const Color(0xFFDCFCE7);
    final bool resolved = session.hasResolvedCapabilityRequest;
    final List<String> supportingCapabilities =
        session.capabilityRequestResolvedSupportingCapabilityTitles;
    final List<String> supportingCurricula =
        session.capabilityRequestResolvedSupportingCurriculumTitles;
    final String? operatorNote =
        session.capabilityRequestResolutionOperatorNote?.trim().isNotEmpty ==
                true
            ? session.capabilityRequestResolutionOperatorNote!.trim()
            : null;
    final String resolvedMessage = supportingCapabilities.isNotEmpty
        ? '${_tSiteSessions(context, 'HQ resolved this request. Confirmed capabilities:')} ${supportingCapabilities.join(', ')}'
        : _tSiteSessions(
            context,
            'HQ resolved this request and confirmed mapped capability coverage for educators.',
          );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: badgeBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  blocked
                      ? _tSiteSessions(context, 'Blocked')
                      : _tSiteSessions(context, 'Ready'),
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  session.mappedCapabilityCount == 1
                      ? _tSiteSessions(context, '1 mapped capability')
                      : '${session.mappedCapabilityCount} ${_tSiteSessions(context, 'mapped capabilities')}',
                  style: TextStyle(
                    color: badgeColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (session.hasOpenCapabilityRequest || resolved) ...<Widget>[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    session.hasOpenCapabilityRequest
                        ? _tSiteSessions(context, 'HQ reviewing')
                        : _tSiteSessions(context, 'HQ resolved'),
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            blocked
                ? _tSiteSessions(
                    context,
                    session.hasOpenCapabilityRequest
                        ? 'HQ already has an open mapping request for this session. Educators stay blocked until the mapping is added and schedule data refreshes.'
                        : resolved
                            ? 'HQ marked this request resolved, but this schedule still shows no mapped capability coverage. Refresh the schedule and review the session mapping.'
                            : 'Educators are blocked from live evidence capture until HQ maps at least one capability for this session pillar.',
                  )
                : resolved
                    ? resolvedMessage
                    : _tSiteSessions(
                        context,
                        'Educators can log live evidence for this session because mapped capability coverage is available.',
                      ),
            style: const TextStyle(
              color: ScholesaColors.textSecondary,
              fontSize: 12,
            ),
          ),
          if (!blocked &&
              resolved &&
              supportingCurricula.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              '${_tSiteSessions(context, 'Mapped curriculum records:')} ${supportingCurricula.join(', ')}',
              style: const TextStyle(
                color: ScholesaColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          if (!blocked && resolved && operatorNote != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              '${_tSiteSessions(context, 'HQ resolution note:')} $operatorNote',
              style: const TextStyle(
                color: ScholesaColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAssignSubstituteSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        const List<String> substitutePools = <String>[
          'Substitute Pool A',
          'Substitute Pool B',
          'Substitute Pool C',
        ];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 12),
              Text(
                _tSiteSessions(context, 'Assign Substitute'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...substitutePools.map((String pool) {
                return ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: Text(_tSiteSessions(context, pool)),
                  onTap: () {
                    TelemetryService.instance.logEvent(
                      event: 'substitute.assigned',
                      metadata: <String, dynamic>{
                        'module': 'site_sessions',
                        'room': session.room,
                        'pillar': session.pillar,
                        'substitute_pool':
                            pool.toLowerCase().replaceAll(' ', '_'),
                      },
                    );
                    Navigator.pop(sheetContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '${_tSiteSessions(context, pool)} ${_tSiteSessions(context, 'assigned as substitute')}'),
                        backgroundColor: ScholesaColors.success,
                      ),
                    );
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class _CreateSessionSheet extends StatefulWidget {
  const _CreateSessionSheet();

  @override
  State<_CreateSessionSheet> createState() => _CreateSessionSheetState();
}

class _CreateSessionSheetState extends State<_CreateSessionSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _learnerCountController = TextEditingController();
  String _selectedPillar = 'Future Skills';
  String? _selectedEducatorId;
  String? _selectedRoom;
  String _selectedTime = '4:00 PM';
  bool _isLoadingOptions = false;
  List<_SheetOption> _educatorOptions = <_SheetOption>[];
  List<_SheetOption> _roomOptions = <_SheetOption>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOptions();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _learnerCountController.dispose();
    super.dispose();
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
                  Text(
                    _tSiteSessions(context, 'Create New Session'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: _tSiteSessions(context, 'Session Title'),
                      filled: true,
                      fillColor: context.schSurfaceMuted,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _tSiteSessions(context, 'Pillar'),
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      _PillarOption(
                        label: _tSiteSessions(context, 'Future Skills'),
                        color: ScholesaColors.futureSkills,
                        isSelected: _selectedPillar == 'Future Skills',
                        onTap: () {
                          TelemetryService.instance.logEvent(
                            event: 'cta.clicked',
                            metadata: const <String, dynamic>{
                              'cta':
                                  'site_sessions_create_select_pillar_future_skills',
                            },
                          );
                          setState(() => _selectedPillar = 'Future Skills');
                        },
                      ),
                      const SizedBox(width: 8),
                      _PillarOption(
                        label: _tSiteSessions(context, 'Leadership'),
                        color: ScholesaColors.leadership,
                        isSelected: _selectedPillar == 'Leadership',
                        onTap: () {
                          TelemetryService.instance.logEvent(
                            event: 'cta.clicked',
                            metadata: const <String, dynamic>{
                              'cta':
                                  'site_sessions_create_select_pillar_leadership',
                            },
                          );
                          setState(() => _selectedPillar = 'Leadership');
                        },
                      ),
                      const SizedBox(width: 8),
                      _PillarOption(
                        label: _tSiteSessions(context, 'Impact'),
                        color: ScholesaColors.impact,
                        isSelected: _selectedPillar == 'Impact',
                        onTap: () {
                          TelemetryService.instance.logEvent(
                            event: 'cta.clicked',
                            metadata: const <String, dynamic>{
                              'cta':
                                  'site_sessions_create_select_pillar_impact',
                            },
                          );
                          setState(() => _selectedPillar = 'Impact');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedTime,
                    decoration: InputDecoration(
                      labelText: _tSiteSessions(context, 'Time Slot'),
                      filled: true,
                      fillColor: context.schSurfaceMuted,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: <String>[
                      '9:00 AM',
                      '10:30 AM',
                      '1:00 PM',
                      '2:30 PM',
                      '4:00 PM'
                    ]
                        .map((String time) => DropdownMenuItem<String>(
                              value: time,
                              child: Text(time),
                            ))
                        .toList(),
                    onChanged: (String? value) {
                      if (value != null) {
                        TelemetryService.instance.logEvent(
                          event: 'cta.clicked',
                          metadata: <String, dynamic>{
                            'cta': 'site_sessions_create_select_time',
                            'time_slot': value,
                          },
                        );
                        setState(() => _selectedTime = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedEducatorId,
                    decoration: InputDecoration(
                      labelText: _tSiteSessions(context, 'Educator'),
                      filled: true,
                      fillColor: context.schSurfaceMuted,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: _educatorOptions
                        .map(
                          (_SheetOption option) => DropdownMenuItem<String>(
                            value: option.id,
                            child: Text(option.label),
                          ),
                        )
                        .toList(),
                    onChanged: (String? value) {
                      setState(() => _selectedEducatorId = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _learnerCountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: _tSiteSessions(context, 'Learner Count'),
                      filled: true,
                      fillColor: context.schSurfaceMuted,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedRoom,
                    decoration: InputDecoration(
                      labelText: _tSiteSessions(context, 'Room'),
                      filled: true,
                      fillColor: context.schSurfaceMuted,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: _roomOptions
                        .map(
                          (_SheetOption option) => DropdownMenuItem<String>(
                            value: option.id,
                            child: Text(option.label),
                          ),
                        )
                        .toList(),
                    onChanged: (String? value) {
                      if (value != null) {
                        TelemetryService.instance.logEvent(
                          event: 'cta.clicked',
                          metadata: <String, dynamic>{
                            'cta': 'site_sessions_create_select_room',
                            'room': value,
                          },
                        );
                        setState(() => _selectedRoom = value);
                      }
                    },
                  ),
                  if (_isLoadingOptions)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _tSiteSessions(context, 'Loading...'),
                        style: TextStyle(
                            fontSize: 12, color: context.schTextSecondary),
                      ),
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final String title = _titleController.text.trim();
                        if (title.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_tSiteSessions(
                                  context, 'Session title is required')),
                            ),
                          );
                          return;
                        }

                        final int learnerCount =
                            int.tryParse(_learnerCountController.text.trim()) ??
                                0;
                        final String educatorName = _educatorOptions
                            .firstWhere(
                              (_SheetOption option) =>
                                  option.id == _selectedEducatorId,
                              orElse: () => const _SheetOption(
                                id: '',
                                label: '',
                              ),
                            )
                            .label
                            .trim();
                        final String roomName = _roomOptions
                            .firstWhere(
                              (_SheetOption option) =>
                                  option.id == _selectedRoom,
                              orElse: () => const _SheetOption(
                                id: '',
                                label: '',
                              ),
                            )
                            .label
                            .trim();

                        TelemetryService.instance.logEvent(
                          event: 'cta.clicked',
                          metadata: <String, dynamic>{
                            'cta': 'site_sessions_create_submit',
                            'pillar': _selectedPillar,
                            'time_slot': _selectedTime,
                            'room': _selectedRoom,
                          },
                        );

                        Navigator.pop(
                          context,
                          _NewSessionResult(
                            time: _selectedTime,
                            session: SiteSessionData(
                              title: title,
                              educator: educatorName.isEmpty
                                  ? _tSiteSessions(context, 'Unassigned')
                                  : educatorName,
                              room: roomName.isEmpty
                                  ? _tSiteSessions(context, 'Unassigned')
                                  : roomName,
                              learnerCount: learnerCount,
                              pillar: _selectedPillar,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ScholesaColors.site,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(_tSiteSessions(context, 'Create Session')),
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

  Future<void> _loadOptions() async {
    final FirestoreService? firestoreService = _maybeFirestoreService();
    final AppState? appState = _maybeAppState();
    if (firestoreService == null || appState == null) {
      return;
    }

    final String siteId = (appState.activeSiteId ??
            (appState.siteIds.isNotEmpty ? appState.siteIds.first : ''))
        .trim();
    if (siteId.isEmpty) return;

    if (!mounted) return;
    setState(() => _isLoadingOptions = true);
    try {
      QuerySnapshot<Map<String, dynamic>> usersSnapshot;
      try {
        usersSnapshot = await firestoreService.firestore
            .collection('users')
            .where('role', isEqualTo: 'educator')
            .limit(300)
            .get();
      } catch (_) {
        usersSnapshot = await firestoreService.firestore
            .collection('users')
            .limit(300)
            .get();
      }

      final List<_SheetOption> educators = <_SheetOption>[];
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in usersSnapshot.docs) {
        final Map<String, dynamic> data = doc.data();
        final String role = ((data['role'] as String?) ?? '').toLowerCase();
        if (role != 'educator') continue;
        final List<String> siteIds = (data['siteIds'] as List?)
                ?.map((dynamic e) => e.toString())
                .toList() ??
            <String>[];
        final String activeSiteId = (data['activeSiteId'] as String?) ?? '';
        if (siteIds.isNotEmpty &&
            !siteIds.contains(siteId) &&
            activeSiteId != siteId) {
          continue;
        }
        final String label = ((data['displayName'] as String?) ??
                (data['email'] as String?) ??
                doc.id)
            .trim();
        if (label.isEmpty) continue;
        educators.add(_SheetOption(id: doc.id, label: label));
      }

      QuerySnapshot<Map<String, dynamic>> roomsSnapshot;
      try {
        roomsSnapshot = await firestoreService.firestore
            .collection('rooms')
            .where('siteId', isEqualTo: siteId)
            .limit(200)
            .get();
      } catch (_) {
        roomsSnapshot = await firestoreService.firestore
            .collection('rooms')
            .limit(200)
            .get();
      }

      final List<_SheetOption> rooms = roomsSnapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        final String label = ((data['name'] as String?) ??
                (data['roomName'] as String?) ??
                doc.id)
            .trim();
        return _SheetOption(id: doc.id, label: label.isEmpty ? doc.id : label);
      }).toList();

      if (!mounted) return;
      setState(() {
        _educatorOptions = educators;
        _roomOptions = rooms;
        _selectedEducatorId =
            _educatorOptions.isNotEmpty ? _educatorOptions.first.id : null;
        _selectedRoom = _roomOptions.isNotEmpty ? _roomOptions.first.id : null;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingOptions = false);
      }
    }
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

class _SheetOption {
  const _SheetOption({required this.id, required this.label});

  final String id;
  final String label;
}

class _PillarOption extends StatelessWidget {
  const _PillarOption({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
