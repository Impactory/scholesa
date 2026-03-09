import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../auth/app_state.dart';
import '../../i18n/site_surface_i18n.dart';
import '../../services/firestore_service.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';

String _tSiteSessions(BuildContext context, String input) {
  return SiteSurfaceI18n.text(context, input);
}

/// Site Sessions Page - Schedule and manage sessions
class SiteSessionsPage extends StatefulWidget {
  const SiteSessionsPage({super.key});

  @override
  State<SiteSessionsPage> createState() => _SiteSessionsPageState();
}

class _SiteSessionsPageState extends State<SiteSessionsPage> {
  DateTime _selectedDate = DateTime.now();
  String _viewMode = 'week';
  final Map<String, List<_SessionData>> _sessionsByTime =
      <String, List<_SessionData>>{};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _logScheduleViewed(trigger: 'page_open');
      _loadSessions();
    });
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

  _SessionConflict? _findSessionConflict(_NewSessionResult result) {
    final List<_SessionData> sameSlotSessions =
        _sessionsByTime[result.time] ?? const <_SessionData>[];
    for (final _SessionData existing in sameSlotSessions) {
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
    final List<MapEntry<String, List<_SessionData>>> timeSlots =
        _sessionsByTime.entries.toList(growable: false);
    timeSlots.sort((MapEntry<String, List<_SessionData>> a,
        MapEntry<String, List<_SessionData>> b) {
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
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                    if (index >= timeSlots.length) {
                      return null;
                    }

                    final MapEntry<String, List<_SessionData>> slot =
                        timeSlots[index];
                    return _SessionTimeSlot(
                      time: slot.key,
                      sessions: slot.value,
                    );
                  },
                  childCount: timeSlots.length,
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
                  setState(() => _viewMode = 'day');
                  _logScheduleViewed(trigger: 'view_mode_day');
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
                  setState(() => _viewMode = 'week');
                  _logScheduleViewed(trigger: 'view_mode_week');
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
                  setState(() => _viewMode = 'month');
                  _logScheduleViewed(trigger: 'view_mode_month');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarStrip() {
    final DateTime today = DateTime.now();
    final List<DateTime> weekDays = List<DateTime>.generate(
      7,
      (int i) => today.subtract(Duration(days: today.weekday - 1 - i)),
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'module': 'site_sessions',
                  'cta_id': 'navigate_previous_week',
                  'surface': 'calendar_strip',
                },
              );
              setState(() {
                _selectedDate = _selectedDate.subtract(const Duration(days: 7));
              });
              _logScheduleViewed(trigger: 'navigate_previous_week');
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
                  onTap: () {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: <String, dynamic>{
                        'module': 'site_sessions',
                        'cta_id': 'select_calendar_date',
                        'surface': 'calendar_strip',
                        'date': date.toIso8601String(),
                      },
                    );
                    setState(() => _selectedDate = date);
                    _logScheduleViewed(trigger: 'select_date');
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
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'module': 'site_sessions',
                  'cta_id': 'navigate_next_week',
                  'surface': 'calendar_strip',
                },
              );
              setState(() {
                _selectedDate = _selectedDate.add(const Duration(days: 7));
              });
              _logScheduleViewed(trigger: 'navigate_next_week');
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
                        onSelected: (_) {
                          TelemetryService.instance.logEvent(
                            event: 'cta.clicked',
                            metadata: <String, dynamic>{
                              'module': 'site_sessions',
                              'cta_id': 'apply_filter_view_mode',
                              'surface': 'filter_sheet',
                              'view_mode': mode,
                            },
                          );
                          setState(() => _viewMode = mode);
                          _logScheduleViewed(trigger: 'filter_view_mode');
                          Navigator.pop(sheetContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '${_tSiteSessions(context, 'Showing')} ${_modeLabel(context, mode)} ${_tSiteSessions(context, 'view')}'),
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
    if (!persisted && !mounted) {
      return;
    }

    setState(() {
      _sessionsByTime.putIfAbsent(result.time, () => <_SessionData>[]);
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
    final FirestoreService? firestoreService = _maybeFirestoreService();
    final AppState? appState = _maybeAppState();
    if (firestoreService == null || appState == null) {
      return;
    }

    final String siteId = (appState.activeSiteId ??
            (appState.siteIds.isNotEmpty ? appState.siteIds.first : ''))
        .trim();
    if (siteId.isEmpty) {
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
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
          snapshot = await query
              .orderBy('createdAt', descending: true)
              .limit(300)
              .get();
        } catch (_) {
          snapshot = await query.limit(300).get();
        }
      }

      final Map<String, List<_SessionData>> grouped =
          <String, List<_SessionData>>{};
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs) {
        final Map<String, dynamic> data = doc.data();
        final String slot = _sessionTimeSlot(data);
        final _SessionData session = _SessionData(
          title: _sessionTitle(data, doc.id),
          educator: _sessionEducator(data),
          room: _sessionRoom(data),
          learnerCount: _sessionLearnerCount(data),
          pillar: _sessionPillar(data),
        );
        grouped.putIfAbsent(slot, () => <_SessionData>[]).add(session);
      }

      if (!mounted) return;
      setState(() {
        _sessionsByTime
          ..clear()
          ..addAll(grouped);
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
      await firestoreService.firestore
          .collection('sessions')
          .add(<String, dynamic>{
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

  int _timeSortKey(String label) {
    final DateTime? parsed = _dateWithTimeLabel(DateTime.now(), label);
    if (parsed == null) return 24 * 60;
    return parsed.hour * 60 + parsed.minute;
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
}

class _NewSessionResult {
  const _NewSessionResult({required this.time, required this.session});

  final String time;
  final _SessionData session;
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

class _SessionData {
  const _SessionData({
    required this.title,
    required this.educator,
    required this.room,
    required this.learnerCount,
    required this.pillar,
  });
  final String title;
  final String educator;
  final String room;
  final int learnerCount;
  final String pillar;
}

class _SessionTimeSlot extends StatelessWidget {
  const _SessionTimeSlot({required this.time, required this.sessions});
  final String time;
  final List<_SessionData> sessions;

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
                  .map((_SessionData session) => _SessionCard(session: session))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});
  final _SessionData session;

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
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showAssignSubstituteSheet(context),
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: Text(_tSiteSessions(context, 'Assign Substitute')),
              ),
            ),
          ],
        ),
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
                    initialValue: _selectedTime,
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
                    initialValue: _selectedEducatorId,
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
                    initialValue: _selectedRoom,
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
                            session: _SessionData(
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
