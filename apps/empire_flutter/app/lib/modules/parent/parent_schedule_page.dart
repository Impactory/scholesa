import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'parent_models.dart';
import 'parent_service.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';

const Map<String, String> _parentScheduleEs = <String, String>{
  'No learner links found yet. Ask your site admin to link parent and learner accounts.':
      'Aún no se encontraron vínculos de estudiantes. Pide al administrador del sitio que vincule las cuentas de padres y estudiantes.',
  'Schedule': 'Horario',
  'View upcoming sessions': 'Ver próximas sesiones',
  'Refresh': 'Actualizar',
  'All Learners': 'Todos los estudiantes',
  'No upcoming sessions': 'No hay próximas sesiones',
  'Next session': 'Próxima sesión',
  'Check back later for learner schedules':
      'Vuelve más tarde para ver los horarios de los estudiantes',
  'Details': 'Detalles',
  'Today\'s Schedule': 'Horario de hoy',
  'session': 'sesión',
  'sessions': 'sesiones',
  'No sessions on this date.': 'No hay sesiones en esta fecha.',
  'Next Session Details': 'Detalles de la próxima sesión',
  'Location': 'Ubicación',
  'Starts': 'Empieza',
  'Learner': 'Estudiante',
  'Close': 'Cerrar',
  'Session reminder set': 'Recordatorio de sesión establecido',
  'Set Reminder': 'Establecer recordatorio',
  'This Week': 'Esta semana',
  'Monday': 'Lunes',
  'Tuesday': 'Martes',
  'Wednesday': 'Miércoles',
  'Thursday': 'Jueves',
  'Friday': 'Viernes',
  'Total Sessions': 'Sesiones totales',
  'Future Skills': 'Habilidades del futuro',
  'Leadership': 'Liderazgo',
  'Impact': 'Impacto',
  'TBD': 'Por definir',
  'Mon': 'Lun',
  'Tue': 'Mar',
  'Wed': 'Mié',
  'Thu': 'Jue',
  'Fri': 'Vie',
  'Sat': 'Sáb',
  'Sun': 'Dom',
  'now': 'ahora',
  'in': 'en',
  'min': 'min',
  'hr': 'h',
  'on': 'el',
};

/// Parent Schedule Page - View learner schedules and upcoming sessions
class ParentSchedulePage extends StatefulWidget {
  const ParentSchedulePage({super.key});

  @override
  State<ParentSchedulePage> createState() => _ParentSchedulePageState();
}

class _ParentSchedulePageState extends State<ParentSchedulePage> {
  String _selectedLearner = 'all';
  DateTime _selectedDate = DateTime.now();
  String _viewMode = 'week'; // day, week, month

  String _t(String input) {
    final String locale = Localizations.localeOf(context).languageCode;
    if (locale != 'es') return input;
    return _parentScheduleEs[input] ?? input;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ParentService>().loadParentData();
    });
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
              scheme.surfaceContainerLowest,
              scheme.surface,
              scheme.surfaceContainerLow,
            ],
          ),
        ),
        child: Consumer<ParentService>(
          builder:
              (BuildContext context, ParentService service, Widget? child) {
            if (service.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: ScholesaColors.parent),
              );
            }
            if (service.learnerSummaries.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _t('No learner links found yet. Ask your site admin to link parent and learner accounts.'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ),
              );
            }
            return CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(child: _buildHeader(service)),
                SliverToBoxAdapter(child: _buildLearnerFilter(service)),
                SliverToBoxAdapter(child: _buildCalendarStrip(service)),
                SliverToBoxAdapter(child: _buildUpcomingSection(service)),
                SliverToBoxAdapter(child: _buildTodaySchedule(service)),
                SliverToBoxAdapter(child: _buildWeekOverview(service)),
                const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(ParentService service) {
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
                gradient: ScholesaColors.parentGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: ScholesaColors.parent.withValues(alpha: 0.3),
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
                    _t('Schedule'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: ScholesaColors.parent,
                        ),
                  ),
                  Text(
                    _t('View upcoming sessions'),
                    style:
                        TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: _t('Refresh'),
              onPressed: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: const <String, dynamic>{
                    'cta': 'parent_schedule_refresh',
                  },
                );
                service.loadParentData();
              },
              icon: const Icon(Icons.refresh, color: ScholesaColors.parent),
            ),
            Container(
              decoration: BoxDecoration(
                color: ScholesaColors.parent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  _ViewModeButton(
                    label: 'D',
                    isSelected: _viewMode == 'day',
                    onTap: () {
                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: const <String, dynamic>{
                          'cta': 'parent_schedule_view_mode_day',
                        },
                      );
                      setState(() => _viewMode = 'day');
                    },
                  ),
                  _ViewModeButton(
                    label: 'W',
                    isSelected: _viewMode == 'week',
                    onTap: () {
                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: const <String, dynamic>{
                          'cta': 'parent_schedule_view_mode_week',
                        },
                      );
                      setState(() => _viewMode = 'week');
                    },
                  ),
                  _ViewModeButton(
                    label: 'M',
                    isSelected: _viewMode == 'month',
                    onTap: () {
                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: const <String, dynamic>{
                          'cta': 'parent_schedule_view_mode_month',
                        },
                      );
                      setState(() => _viewMode = 'month');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLearnerFilter(ParentService service) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Set<String> linkedLearnerIds = service.learnerSummaries
        .map((LearnerSummary learner) => learner.learnerId)
        .toSet();
    if (_selectedLearner != 'all' &&
        !linkedLearnerIds.contains(_selectedLearner)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedLearner = 'all');
      });
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: DropdownButton<String>(
          value: _selectedLearner,
          isExpanded: true,
          underline: const SizedBox(),
          icon: const Icon(Icons.keyboard_arrow_down),
          items: <DropdownMenuItem<String>>[
            const DropdownMenuItem<String>(
              value: 'all',
              child: Text('All Learners'),
            ),
            ...service.learnerSummaries.map(
              (LearnerSummary learner) => DropdownMenuItem<String>(
                value: learner.learnerId,
                child: Text(learner.learnerName),
              ),
            ),
          ],
          onChanged: (String? value) {
            if (value != null) {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'cta': 'parent_schedule_select_learner',
                  'learner': value
                },
              );
              setState(() => _selectedLearner = value);
            }
          },
        ),
      ),
    );
  }

  Widget _buildCalendarStrip(ParentService service) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DateTime today = DateTime.now();
    final List<DateTime> days = List<DateTime>.generate(
      7,
      (int i) => today.add(Duration(days: i - today.weekday + 1)),
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: days.map((DateTime date) {
            final bool isSelected = date.day == _selectedDate.day &&
                date.month == _selectedDate.month;
            final bool isToday =
                date.day == today.day && date.month == today.month;

            return GestureDetector(
              onTap: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: <String, dynamic>{
                    'cta': 'parent_schedule_select_date',
                    'date': date.toIso8601String(),
                  },
                );
                setState(() => _selectedDate = date);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? ScholesaColors.parent
                      : isToday
                          ? ScholesaColors.parent.withValues(alpha: 0.1)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: <Widget>[
                    Text(
                      _getDayName(date.weekday),
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white70
                            : scheme.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        color: isSelected ? Colors.white : scheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (_hasEvents(date, service))
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color:
                              isSelected ? Colors.white : ScholesaColors.parent,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildUpcomingSection(ParentService service) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = scheme.brightness == Brightness.dark;
    final _ParentScheduleEntry? nextSession = _nextSession(service);
    final List<Color> highlightColors = isDark
        ? const <Color>[Color(0xFF7A123A), Color(0xFF4D0E2F)]
        : const <Color>[Color(0xFFB51250), Color(0xFF8F1547)];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: highlightColors,
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          borderRadius: BorderRadius.circular(16),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: highlightColors.last.withValues(alpha: 0.34),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.event_available, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    nextSession == null
                        ? _t('No upcoming sessions')
                        : '${_t('Next session')} ${_formatRelative(nextSession.dateTime)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                  ),
                  Text(
                    nextSession == null
                        ? _t('Check back later for learner schedules')
                        : '${nextSession.title} @ ${nextSession.location}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: nextSession == null
                  ? null
                  : () => _showNextSessionDetails(nextSession),
              style: TextButton.styleFrom(
                foregroundColor: highlightColors.first,
                backgroundColor: Colors.white.withValues(alpha: 0.96),
                disabledForegroundColor: Colors.white.withValues(alpha: 0.65),
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.18),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              child: Text(_t('Details')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodaySchedule(ParentService service) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<_ParentScheduleEntry> entries = _entriesForSelectedDate(service);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                _t('Today\'s Schedule'),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Text(
                '${entries.length} ${entries.length == 1 ? _t('session') : _t('sessions')}',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Text(
                _t('No sessions on this date.'),
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ...entries.map(
            (_ParentScheduleEntry entry) => _ScheduleItem(
              time: _formatTime(entry.dateTime),
              title: entry.title,
              learner: entry.learnerName,
              location: entry.location,
              pillar: entry.pillarLabel,
              pillarColor: entry.pillarColor,
              status: entry.status,
            ),
          ),
        ],
      ),
    );
  }

  void _showNextSessionDetails(_ParentScheduleEntry nextSession) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'parent_schedule_open_next_session_details',
        'view_mode': _viewMode,
        'selected_learner': _selectedLearner,
        'session_title': nextSession.title,
      },
    );
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(_t('Next Session Details')),
        content: Text(
          '${nextSession.title}\n'
          '${_t('Location')}: ${nextSession.location}\n'
          '${_t('Starts')}: ${_formatDateTime(nextSession.dateTime)}\n'
          '${_t('Learner')}: ${nextSession.learnerName}',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'cta': 'parent_schedule_close_next_session_details',
                },
              );
              Navigator.pop(dialogContext);
            },
            child: Text(_t('Close')),
          ),
          ElevatedButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'cta': 'parent_schedule_set_session_reminder',
                },
              );
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Session reminder set'),
                  backgroundColor: ScholesaColors.parent,
                ),
              );
            },
            child: Text(_t('Set Reminder')),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekOverview(ParentService service) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<_ParentScheduleEntry> weekEntries = _entriesForWeek(service);
    final Map<int, List<_ParentScheduleEntry>> byWeekday =
        <int, List<_ParentScheduleEntry>>{};
    for (final _ParentScheduleEntry entry in weekEntries) {
      byWeekday
          .putIfAbsent(entry.dateTime.weekday, () => <_ParentScheduleEntry>[])
          .add(entry);
    }
    final int futureSkillsCount =
        weekEntries.where((entry) => entry.pillarKey == 'futureSkills').length;
    final int leadershipCount =
        weekEntries.where((entry) => entry.pillarKey == 'leadership').length;
    final int impactCount =
        weekEntries.where((entry) => entry.pillarKey == 'impact').length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _t('This Week'),
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              children: <Widget>[
                _WeekDayRow(
                  day: _t('Monday'),
                  sessions: byWeekday[DateTime.monday]?.length ?? 0,
                  sessionsLabel: _t('sessions'),
                  hours: _hoursLabel(
                      byWeekday[DateTime.monday] ?? <_ParentScheduleEntry>[]),
                  isToday: DateTime.now().weekday == DateTime.monday,
                ),
                const Divider(),
                _WeekDayRow(
                  day: _t('Tuesday'),
                  sessions: byWeekday[DateTime.tuesday]?.length ?? 0,
                  sessionsLabel: _t('sessions'),
                  hours: _hoursLabel(
                      byWeekday[DateTime.tuesday] ?? <_ParentScheduleEntry>[]),
                  isToday: DateTime.now().weekday == DateTime.tuesday,
                ),
                const Divider(),
                _WeekDayRow(
                  day: _t('Wednesday'),
                  sessions: byWeekday[DateTime.wednesday]?.length ?? 0,
                  sessionsLabel: _t('sessions'),
                  hours: _hoursLabel(byWeekday[DateTime.wednesday] ??
                      <_ParentScheduleEntry>[]),
                  isToday: DateTime.now().weekday == DateTime.wednesday,
                ),
                const Divider(),
                _WeekDayRow(
                  day: _t('Thursday'),
                  sessions: byWeekday[DateTime.thursday]?.length ?? 0,
                  sessionsLabel: _t('sessions'),
                  hours: _hoursLabel(
                      byWeekday[DateTime.thursday] ?? <_ParentScheduleEntry>[]),
                  isToday: DateTime.now().weekday == DateTime.thursday,
                ),
                const Divider(),
                _WeekDayRow(
                  day: _t('Friday'),
                  sessions: byWeekday[DateTime.friday]?.length ?? 0,
                  sessionsLabel: _t('sessions'),
                  hours: _hoursLabel(
                      byWeekday[DateTime.friday] ?? <_ParentScheduleEntry>[]),
                  isToday: DateTime.now().weekday == DateTime.friday,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _WeekStat(
                    label: _t('Total Sessions'),
                    value: '${weekEntries.length}',
                    icon: Icons.event,
                    color: ScholesaColors.parent,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: scheme.outlineVariant,
                ),
                Expanded(
                  child: _WeekStat(
                    label: _t('Future Skills'),
                    value: '$futureSkillsCount',
                    icon: Icons.code,
                    color: ScholesaColors.futureSkills,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: scheme.outlineVariant,
                ),
                Expanded(
                  child: _WeekStat(
                    label: _t('Leadership'),
                    value: '$leadershipCount',
                    icon: Icons.emoji_events,
                    color: ScholesaColors.leadership,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: scheme.outlineVariant,
                ),
                Expanded(
                  child: _WeekStat(
                    label: _t('Impact'),
                    value: '$impactCount',
                    icon: Icons.eco,
                    color: ScholesaColors.impact,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getDayName(int weekday) {
    const List<String> days = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return days[weekday - 1];
  }

  List<_ParentScheduleEntry> _visibleEntries(ParentService service) {
    final DateTime now = DateTime.now();
    final List<_ParentScheduleEntry> entries = <_ParentScheduleEntry>[];
    for (final LearnerSummary learner in service.learnerSummaries) {
      if (_selectedLearner != 'all' && learner.learnerId != _selectedLearner) {
        continue;
      }
      for (final UpcomingEvent event in learner.upcomingEvents) {
        final String normalizedType = event.type.trim().toLowerCase();
        final String pillarKey = _pillarKeyForType(normalizedType);
        entries.add(
          _ParentScheduleEntry(
            learnerId: learner.learnerId,
            learnerName: learner.learnerName,
            title: event.title,
            location: event.location?.trim().isNotEmpty == true
                ? event.location!.trim()
              : _t('TBD'),
            dateTime: event.dateTime,
            pillarKey: pillarKey,
            pillarLabel: _pillarLabel(pillarKey),
            pillarColor: _pillarColor(pillarKey),
            status: _statusForDate(event.dateTime, now),
          ),
        );
      }
    }
    entries.sort(
      (_ParentScheduleEntry a, _ParentScheduleEntry b) =>
          a.dateTime.compareTo(b.dateTime),
    );
    return entries;
  }

  List<_ParentScheduleEntry> _entriesForSelectedDate(ParentService service) {
    return _visibleEntries(service)
        .where((entry) => _isSameDay(entry.dateTime, _selectedDate))
        .toList();
  }

  List<_ParentScheduleEntry> _entriesForWeek(ParentService service) {
    final DateTime weekStart = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    ).subtract(Duration(days: _selectedDate.weekday - 1));
    final DateTime weekEnd = weekStart.add(const Duration(days: 7));
    return _visibleEntries(service)
        .where(
          (_ParentScheduleEntry entry) =>
              !entry.dateTime.isBefore(weekStart) &&
              entry.dateTime.isBefore(weekEnd),
        )
        .toList();
  }

  _ParentScheduleEntry? _nextSession(ParentService service) {
    final DateTime now = DateTime.now();
    for (final _ParentScheduleEntry entry in _visibleEntries(service)) {
      if (entry.dateTime.isAfter(now)) {
        return entry;
      }
    }
    return null;
  }

  bool _hasEvents(DateTime date, ParentService service) {
    return _visibleEntries(service)
        .any((_ParentScheduleEntry entry) => _isSameDay(entry.dateTime, date));
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _statusForDate(DateTime dateTime, DateTime now) {
    if (dateTime.isBefore(now.subtract(const Duration(minutes: 30)))) {
      return 'completed';
    }
    if (dateTime.isBefore(now.add(const Duration(hours: 1)))) {
      return 'in_progress';
    }
    return 'upcoming';
  }

  String _pillarKeyForType(String type) {
    if (type.contains('leader')) return 'leadership';
    if (type.contains('impact') || type.contains('community')) return 'impact';
    return 'futureSkills';
  }

  String _pillarLabel(String key) {
    switch (key) {
      case 'leadership':
        return _t('Leadership');
      case 'impact':
        return _t('Impact');
      default:
        return _t('Future Skills');
    }
  }

  Color _pillarColor(String key) {
    switch (key) {
      case 'leadership':
        return ScholesaColors.leadership;
      case 'impact':
        return ScholesaColors.impact;
      default:
        return ScholesaColors.futureSkills;
    }
  }

  String _formatTime(DateTime dateTime) {
    final int hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final String minute = dateTime.minute.toString().padLeft(2, '0');
    final String suffix = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  String _formatDateTime(DateTime dateTime) {
    const List<String> weekdays = <String>[
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun'
    ];
    final List<String> localized = weekdays.map(_t).toList();
    return '${localized[dateTime.weekday - 1]} ${dateTime.month}/${dateTime.day} ${_formatTime(dateTime)}';
  }

  String _formatRelative(DateTime dateTime) {
    final Duration delta = dateTime.difference(DateTime.now());
    if (delta.inMinutes <= 0) return _t('now');
    if (delta.inMinutes < 60) {
      return '${_t('in')} ${delta.inMinutes} ${_t('min')}';
    }
    if (delta.inHours < 24) return '${_t('in')} ${delta.inHours} ${_t('hr')}';
    return '${_t('on')} ${dateTime.month}/${dateTime.day}';
  }

  String _hoursLabel(List<_ParentScheduleEntry> entries) {
    if (entries.isEmpty) return '-';
    entries.sort((_ParentScheduleEntry a, _ParentScheduleEntry b) =>
        a.dateTime.compareTo(b.dateTime));
    return '${_formatTime(entries.first.dateTime)} - ${_formatTime(entries.last.dateTime)}';
  }
}

class _ParentScheduleEntry {
  const _ParentScheduleEntry({
    required this.learnerId,
    required this.learnerName,
    required this.title,
    required this.location,
    required this.dateTime,
    required this.pillarKey,
    required this.pillarLabel,
    required this.pillarColor,
    required this.status,
  });

  final String learnerId;
  final String learnerName;
  final String title;
  final String location;
  final DateTime dateTime;
  final String pillarKey;
  final String pillarLabel;
  final Color pillarColor;
  final String status;
}

class _ViewModeButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ViewModeButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? ScholesaColors.parent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : scheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _ScheduleItem extends StatelessWidget {
  final String time;
  final String title;
  final String learner;
  final String location;
  final String pillar;
  final Color pillarColor;
  final String status;

  const _ScheduleItem({
    required this.time,
    required this.title,
    required this.learner,
    required this.location,
    required this.pillar,
    required this.pillarColor,
    required this.status,
  });

  IconData get _statusIcon {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'in_progress':
        return Icons.play_circle;
      default:
        return Icons.schedule;
    }
  }

  Color _statusColor(ColorScheme scheme) {
    switch (status) {
      case 'completed':
        return ScholesaColors.success;
      case 'in_progress':
        return ScholesaColors.warning;
      default:
        return scheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: <Widget>[
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: pillarColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: <Widget>[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            time,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Icon(_statusIcon,
                              color: _statusColor(scheme), size: 20),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: <Widget>[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: pillarColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    pillar,
                                    style: TextStyle(
                                      color: pillarColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.person,
                                    size: 12, color: scheme.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Text(
                                  learner,
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Icon(Icons.location_on,
                                  size: 12, color: scheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(
                                location,
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekDayRow extends StatelessWidget {
  final String day;
  final int sessions;
  final String sessionsLabel;
  final String hours;
  final bool isToday;

  const _WeekDayRow({
    required this.day,
    required this.sessions,
    required this.sessionsLabel,
    required this.hours,
    this.isToday = false,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          if (isToday)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: const BoxDecoration(
                color: ScholesaColors.parent,
                shape: BoxShape.circle,
              ),
            ),
          Expanded(
            flex: 2,
            child: Text(
              day,
              style: TextStyle(
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: isToday ? ScholesaColors.parent : scheme.onSurface,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '$sessions $sessionsLabel',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          ),
          Text(
            hours,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _WeekStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _WeekStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      children: <Widget>[
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 9),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
