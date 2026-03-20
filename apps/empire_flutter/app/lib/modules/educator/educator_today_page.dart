import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/firestore_service.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';
import '../../runtime/runtime.dart';
import '../../i18n/bos_coaching_i18n.dart';
import '../../i18n/workflow_surface_i18n.dart';
import '../../auth/app_state.dart';
import '../../ui/auth/global_session_menu.dart';
import 'educator_models.dart';
import 'educator_service.dart';

String _tEducatorToday(BuildContext context, String input) {
  return WorkflowSurfaceI18n.text(context, input);
}

/// Educator Today Page - Daily schedule and quick actions
class EducatorTodayPage extends StatefulWidget {
  const EducatorTodayPage({this.classInsightsLoader, super.key});

  final BosClassInsightsLoader? classInsightsLoader;

  @override
  State<EducatorTodayPage> createState() => _EducatorTodayPageState();
}

class _EducatorTodayPageState extends State<EducatorTodayPage> {
  bool _showAiCoach = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final EducatorService service = context.read<EducatorService>();
      await service.loadTodaySchedule();
      await service.loadLearners();
    });
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
              context.schSurface,
              const Color(0xFF10B981).withValues(alpha: 0.03),
            ],
          ),
        ),
        child: Consumer<EducatorService>(
          builder: (BuildContext context, EducatorService service, _) {
            if (service.isLoading) {
              return const Center(
                child:
                    CircularProgressIndicator(color: ScholesaColors.educator),
              );
            }

            return CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildAiCoachingSection(context)),
                SliverToBoxAdapter(
                  child: BosClassInsightsCard(
                    title: BosCoachingI18n.classInsightsTitle(context),
                    subtitle: BosCoachingI18n.classInsightsSubtitle(context),
                    emptyLabel: BosCoachingI18n.classInsightsEmpty(context),
                    sessionOccurrenceId:
                        _sessionOccurrenceIdForInsights(service),
                    siteId: _siteIdForInsights(service),
                    learnerNamesById: <String, String>{
                      for (final EducatorLearner learner in service.learners)
                        learner.id: learner.name,
                    },
                    accentColor: ScholesaColors.educator,
                    insightsLoader: widget.classInsightsLoader,
                  ),
                ),
                SliverToBoxAdapter(child: _buildQuickStats(service)),
                SliverToBoxAdapter(child: _buildQuickActions()),
                SliverToBoxAdapter(child: _buildCurrentClass(service)),
                SliverToBoxAdapter(child: _buildScheduleHeader()),
                if (service.todayClasses.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              _tEducatorToday(
                                  context, 'No classes scheduled yet'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _tEducatorToday(context,
                                  'Add or sync classes to populate today’s schedule.'),
                              style: TextStyle(
                                  color: Colors.grey[700], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) => _ClassCard(
                      todayClass: service.todayClasses[index],
                      onTap: () =>
                          _openClassDetail(service.todayClasses[index]),
                    ),
                    childCount: service.todayClasses.length,
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

  String? _sessionOccurrenceIdForInsights(EducatorService service) {
    final TodayClass? classForInsights =
        service.currentClass ?? service.todayClasses.firstOrNull;
    final String? sessionOccurrenceId = classForInsights?.id.trim();
    if (sessionOccurrenceId == null || sessionOccurrenceId.isEmpty) {
      return null;
    }
    return sessionOccurrenceId;
  }

  String? _siteIdForInsights(EducatorService service) {
    final String educatorSiteId = service.siteId?.trim() ?? '';
    if (educatorSiteId.isNotEmpty) {
      return educatorSiteId;
    }
    final AppState appState = context.read<AppState>();
    final String activeSiteId = appState.activeSiteId?.trim() ?? '';
    if (activeSiteId.isNotEmpty) {
      return activeSiteId;
    }
    if (appState.siteIds.isNotEmpty) {
      final String siteId = appState.siteIds.first.trim();
      if (siteId.isNotEmpty) {
        return siteId;
      }
    }
    return null;
  }

  Widget _buildHeader() {
    final DateTime now = DateTime.now();
    final String greeting = now.hour < 12
        ? 'Good morning'
        : (now.hour < 17 ? 'Good afternoon' : 'Good evening');
    final Widget datePill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: ScholesaColors.educator.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _formatDate(now),
        style: const TextStyle(
          color: ScholesaColors.educator,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
    final Widget sessionAction = SessionMenuHeaderAction(
      foregroundColor: ScholesaColors.educator,
      backgroundColor: Colors.white,
    );

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compactHeader = constraints.maxWidth < 420;

            return Row(
              crossAxisAlignment:
                  compactHeader ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: <Color>[ScholesaColors.educator, Color(0xFF10B981)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: ScholesaColors.educator.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.today, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: compactHeader
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              _tEducatorToday(context, greeting),
                              style: TextStyle(
                                  color: context.schTextSecondary, fontSize: 14),
                            ),
                            Text(
                              _tEducatorToday(context, "Today's Schedule"),
                              style:
                                  Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: ScholesaColors.educator,
                                      ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: <Widget>[
                                datePill,
                                sessionAction,
                              ],
                            ),
                          ],
                        )
                      : Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    _tEducatorToday(context, greeting),
                                    style: TextStyle(
                                        color: context.schTextSecondary, fontSize: 14),
                                  ),
                                  Text(
                                    _tEducatorToday(context, "Today's Schedule"),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: ScholesaColors.educator,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            datePill,
                            const SizedBox(width: 12),
                            sessionAction,
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildQuickStats(EducatorService service) {
    final EducatorDayStats? stats = service.dayStats;
    if (stats == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: <Widget>[
            Expanded(
              child: _StatCard(
                icon: Icons.school,
                value: '--',
                label: _tEducatorToday(context, 'Classes'),
                color: ScholesaColors.educator,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.people,
                value: '--',
                label: _tEducatorToday(context, 'Attendance'),
                color: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.assignment,
                value: '--',
                label: _tEducatorToday(context, 'To Review'),
                color: ScholesaColors.warning,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _StatCard(
              icon: Icons.school,
              value: '${stats.completedClasses}/${stats.totalClasses}',
              label: _tEducatorToday(context, 'Classes'),
              color: ScholesaColors.educator,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Icons.people,
              value: '${(stats.attendanceRate * 100).toInt()}%',
              label: _tEducatorToday(context, 'Attendance'),
              color: const Color(0xFF10B981),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Icons.assignment,
              value: '${stats.missionsToReview}',
              label: _tEducatorToday(context, 'To Review'),
              color: ScholesaColors.warning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _QuickActionButton(
              icon: Icons.how_to_reg,
              label: _tEducatorToday(context, 'Take Attendance'),
              color: ScholesaColors.educator,
              onTap: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: const <String, dynamic>{
                    'cta': 'educator_today_take_attendance'
                  },
                );
                context.push('/educator/attendance');
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActionButton(
              icon: Icons.rate_review,
              label: _tEducatorToday(context, 'Review Missions'),
              color: const Color(0xFF8B5CF6),
              onTap: _showReviewMissionsDialog,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActionButton(
              icon: Icons.message,
              label: _tEducatorToday(context, 'Messages'),
              color: const Color(0xFF3B82F6),
              onTap: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: const <String, dynamic>{
                    'cta': 'educator_today_open_messages'
                  },
                );
                context.push('/messages');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentClass(EducatorService service) {
    final TodayClass? currentClass = service.currentClass;
    if (currentClass == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _tEducatorToday(context, 'No class in progress'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              _tEducatorToday(context,
                  'Your next class will appear here when schedule data syncs.'),
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[ScholesaColors.educator, Color(0xFF10B981)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: ScholesaColors.educator.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _tEducatorToday(context, 'NOW'),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '${_formatTime(currentClass.startTime)} - ${_formatTime(currentClass.endTime)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            currentClass.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.location_on,
                      size: 16, color: Colors.white.withValues(alpha: 0.8)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      currentClass.location ??
                          _tEducatorToday(context, 'No location'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.people,
                      size: 16, color: Colors.white.withValues(alpha: 0.8)),
                  const SizedBox(width: 4),
                  Text(
                    '${currentClass.presentCount}/${currentClass.enrolledCount} ${_tEducatorToday(context, 'present')}',
                    style:
                        TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: <String, dynamic>{
                        'cta': 'educator_today_manage_attendance_current_class',
                        'class_id': currentClass.id,
                      },
                    );
                    context.push('/educator/attendance');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.schSurface,
                    foregroundColor: ScholesaColors.educator,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Icon(Icons.how_to_reg, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _tEducatorToday(context, 'Manage Attendance'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _openLiveSessionMode(currentClass, service),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side:
                        BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Icon(Icons.podcasts_outlined, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _tEducatorToday(context, 'Live Session Mode'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 420;
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _tEducatorToday(context, 'Full Schedule'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: _showWeekViewSummary,
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: Text(_tEducatorToday(context, 'Week View')),
                  style: TextButton.styleFrom(
                    foregroundColor: ScholesaColors.educator,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                _tEducatorToday(context, 'Full Schedule'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: _showWeekViewSummary,
                icon: const Icon(Icons.calendar_month, size: 18),
                label: Text(_tEducatorToday(context, 'Week View')),
                style: TextButton.styleFrom(
                  foregroundColor: ScholesaColors.educator,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openClassDetail(TodayClass todayClass) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'educator_today_open_class_detail',
        'class_id': todayClass.id
      },
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) =>
          _ClassDetailSheet(todayClass: todayClass),
    );
  }

  void _openLiveSessionMode(TodayClass todayClass, EducatorService service) {
    final Map<String, String> learnerNamesById = <String, String>{
      for (final EducatorLearner learner in service.learners)
        learner.id: learner.name,
    };
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'educator_today_open_live_session_mode',
        'class_id': todayClass.id,
      },
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext bottomSheetContext) => _LiveSessionModeSheet(
        todayClass: todayClass,
        siteId: _siteIdForInsights(service),
        learnerNamesById: learnerNamesById,
        classInsightsLoader: widget.classInsightsLoader,
      ),
    );
  }

  void _showWeekViewSummary() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{'cta': 'educator_today_week_view'},
    );
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(_tEducatorToday(context, 'Week View Summary')),
        content: Text(
          '${_tEducatorToday(context, 'This week:')} ${context.read<EducatorService>().todayClasses.length} ${_tEducatorToday(context, 'classes loaded from your current schedule.')}',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'cta': 'educator_today_close_week_view_summary',
                },
              );
              Navigator.pop(dialogContext);
            },
            child: Text(_tEducatorToday(context, 'Close')),
          ),
        ],
      ),
    );
  }

  void _showReviewMissionsDialog() {
    final int count =
        context.read<EducatorService>().dayStats?.missionsToReview ?? 0;
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'educator_today_open_review_queue_dialog',
        'count': count
      },
    );
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(_tEducatorToday(context, 'Mission Review Queue')),
        content: Text(
            '${_tEducatorToday(context, 'You have')} $count ${_tEducatorToday(context, 'missions pending review today.')}'),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'cta': 'educator_today_close_review_queue_dialog',
                },
              );
              Navigator.pop(dialogContext);
            },
            child: Text(_tEducatorToday(context, 'Close')),
          ),
          ElevatedButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'cta': 'educator_today_open_review_queue'
                },
              );
              Navigator.pop(dialogContext);
              context.push('/educator/missions/review');
            },
            child: Text(_tEducatorToday(context, 'Open Queue')),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const List<String> days = <String>[
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun'
    ];
    const List<String> months = <String>[
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
      'Dec'
    ];
    final String day = _tEducatorToday(context, days[date.weekday - 1]);
    final String month = _tEducatorToday(context, months[date.month - 1]);
    return '$day, $month ${date.day}';
  }

  String _formatTime(DateTime time) {
    final int hour =
        time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final String period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
  }

  Widget _buildAiCoachingSection(BuildContext context) {
    final AppState appState = context.read<AppState>();
    final UserRole? role = appState.role;

    if (role != UserRole.educator) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              color: ScholesaColors.educator.withValues(alpha: 0.1),
              border: Border.all(
                color: ScholesaColors.educator.withValues(alpha: 0.2),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Icon(
                Icons.smart_toy_rounded,
                color: ScholesaColors.educator,
              ),
              title: Text(_tEducatorToday(context, 'AI Classroom Coach')),
              subtitle: Text(_tEducatorToday(context,
                  'Get personalized coaching for classroom management')),
              trailing: IconButton(
                icon: Icon(
                  _showAiCoach ? Icons.expand_less : Icons.expand_more,
                ),
                onPressed: () {
                  setState(() => _showAiCoach = !_showAiCoach);
                  TelemetryService.instance.logEvent(
                    event: 'cta.clicked',
                    metadata: <String, dynamic>{
                      'module': 'educator_today',
                      'cta': 'educator_ai_${_showAiCoach ? 'show' : 'hide'}',
                      'surface': 'today_dashboard',
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

  Widget _buildAiCoachPanel(BuildContext context, UserRole? role) {
    final LearningRuntimeProvider? runtime =
        context.read<LearningRuntimeProvider?>();
    if (role == null || runtime == null) {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _tEducatorToday(context, 'MiloOS is loading'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              _tEducatorToday(context,
                  'Runtime context is syncing. Try again in a moment.'),
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: ScholesaColors.educator.withValues(alpha: 0.05),
        border: Border.all(
          color: ScholesaColors.educator.withValues(alpha: 0.1),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      constraints: const BoxConstraints(minHeight: 350),
      child: AiCoachWidget(
        runtime: runtime,
        actorRole: role,
        conceptTags: <String>[
          'classroom_management',
          'educator_support',
          'learner_engagement',
        ],
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
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
            style: TextStyle(
              fontSize: 11,
              color: context.schTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          TelemetryService.instance.logEvent(
            event: 'cta.clicked',
            metadata: <String, dynamic>{
              'cta': 'educator_today_quick_action',
              'label': label,
            },
          );
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: <Widget>[
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.todayClass,
    required this.onTap,
  });
  final TodayClass todayClass;
  final VoidCallback onTap;

  Color get _statusColor {
    switch (todayClass.status) {
      case 'completed':
        return Colors.grey;
      case 'in_progress':
        return ScholesaColors.educator;
      default:
        return const Color(0xFF3B82F6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = todayClass.status == 'completed';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _statusColor.withValues(alpha: isCompleted ? 0.2 : 0.3),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              // Time column
              SizedBox(
                width: 56,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _formatTime(todayClass.startTime),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isCompleted ? Colors.grey : Colors.grey[800],
                      ),
                    ),
                    Text(
                      _formatTime(todayClass.endTime),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.schTextSecondary.withValues(alpha: 0.88),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 3,
                height: 50,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: _statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      todayClass.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isCompleted ? Colors.grey : Colors.grey[800],
                        decoration:
                            isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(Icons.location_on,
                                size: 14,
                                color: context.schTextSecondary
                                    .withValues(alpha: 0.74)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                todayClass.location ??
                                    _tEducatorToday(context, 'No location'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: context.schTextSecondary
                                        .withValues(alpha: 0.88),
                                    fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.people,
                                size: 14,
                                color: context.schTextSecondary
                                    .withValues(alpha: 0.74)),
                            const SizedBox(width: 4),
                            Text(
                              '${todayClass.enrolledCount}',
                              style: TextStyle(
                                  color: context.schTextSecondary
                                      .withValues(alpha: 0.88),
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  todayClass.status.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _statusColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final int hour =
        time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final String period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
  }
}

class _ClassDetailSheet extends StatelessWidget {
  const _ClassDetailSheet({required this.todayClass});
  final TodayClass todayClass;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  todayClass.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (todayClass.description != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    todayClass.description!,
                    style: TextStyle(color: context.schTextSecondary),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: <Widget>[
                    _DetailChip(
                      icon: Icons.access_time,
                      label:
                          '${_formatTime(todayClass.startTime)} - ${_formatTime(todayClass.endTime)}',
                    ),
                    const SizedBox(width: 12),
                    _DetailChip(
                      icon: Icons.location_on,
                      label: todayClass.location ??
                          _tEducatorToday(context, 'No location'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  _tEducatorToday(context, 'Enrolled Learners'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    itemCount: todayClass.learners.length,
                    itemBuilder: (BuildContext context, int index) {
                      final EnrolledLearner learner =
                          todayClass.learners[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor:
                              ScholesaColors.learner.withValues(alpha: 0.1),
                          child: Text(
                            _getInitials(learner.name),
                            style: const TextStyle(
                              color: ScholesaColors.learner,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(learner.name),
                        trailing: _buildAttendanceBadge(
                            context, learner.attendanceStatus),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: <String, dynamic>{
                          'cta':
                              'educator_today_take_attendance_from_class_detail',
                          'class_id': todayClass.id,
                        },
                      );
                      Navigator.pop(context);
                      context.push('/educator/attendance');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ScholesaColors.educator,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(_tEducatorToday(context, 'Take Attendance')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceBadge(BuildContext context, String? status) {
    if (status == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          _tEducatorToday(context, 'Not recorded'),
          style: TextStyle(fontSize: 11, color: context.schTextSecondary),
        ),
      );
    }

    Color color;
    switch (status) {
      case 'present':
        color = ScholesaColors.success;
      case 'late':
        color = ScholesaColors.warning;
      case 'absent':
        color = ScholesaColors.error;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final int hour =
        time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final String period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
  }

  String _getInitials(String name) {
    final List<String> parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 2).toUpperCase();
  }
}

class _LiveSessionModeSheet extends StatefulWidget {
  const _LiveSessionModeSheet({
    required this.todayClass,
    required this.siteId,
    required this.learnerNamesById,
    this.classInsightsLoader,
  });

  final TodayClass todayClass;
  final String? siteId;
  final Map<String, String> learnerNamesById;
  final BosClassInsightsLoader? classInsightsLoader;

  @override
  State<_LiveSessionModeSheet> createState() => _LiveSessionModeSheetState();
}

class _LiveSessionModeSheetState extends State<_LiveSessionModeSheet> {
  final TextEditingController _pollController = TextEditingController(
    text: 'How confident are you with this step?',
  );
  final TextEditingController _exitTicketController = TextEditingController(
    text: 'What is one thing you can now explain without help?',
  );
  String _pacingMode = 'steady';
  String? _selectedColdCallLearnerId;
  bool _isSaving = false;
  List<String> _misconceptionAlerts = const <String>[];

  @override
  void initState() {
    super.initState();
    _selectedColdCallLearnerId = widget.learnerNamesById.keys.firstOrNull;
    _loadMisconceptionAlerts();
  }

  @override
  void dispose() {
    _pollController.dispose();
    _exitTicketController.dispose();
    super.dispose();
  }

  Future<void> _loadMisconceptionAlerts() async {
    final String? occurrenceId = widget.todayClass.id.trim().isEmpty
        ? null
        : widget.todayClass.id.trim();
    final String? siteId = widget.siteId?.trim();
    if (widget.classInsightsLoader == null ||
        occurrenceId == null ||
        siteId == null ||
        siteId.isEmpty) {
      return;
    }

    try {
      final Map<String, dynamic> insights = await widget.classInsightsLoader!(
        sessionOccurrenceId: occurrenceId,
        siteId: siteId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _misconceptionAlerts = _extractMisconceptionAlerts(insights);
      });
    } catch (_) {}
  }

  List<String> _extractMisconceptionAlerts(Map<String, dynamic> insights) {
    final Set<String> alerts = <String>{};
    final List<dynamic> learners =
        insights['learners'] as List<dynamic>? ?? const <dynamic>[];
    for (final dynamic entry in learners) {
      if (entry is! Map) {
        continue;
      }
      final Map<String, dynamic> learner = Map<String, dynamic>.from(entry);
      final String learnerName =
          widget.learnerNamesById[learner['learnerId'] as String? ?? ''] ??
              learner['learnerId'] as String? ??
              _tEducatorToday(context, 'Learner');
      final List<String> tags = (learner['misconceptionTags'] as List?)
              ?.whereType<String>()
              .map((String value) => value.trim())
              .where((String value) => value.isNotEmpty)
              .toList() ??
          const <String>[];
      for (final String tag in tags) {
        alerts.add('$learnerName: $tag');
      }
      final Map<String, dynamic> state =
          (learner['x_hat'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final double cognition = (state['cognition'] as num?)?.toDouble() ?? 1;
      if (cognition < 0.4) {
        alerts.add(
          '$learnerName: ${_tEducatorToday(context, 'Needs reteach on current concept')}',
        );
      }
    }
    return alerts.take(4).toList(growable: false);
  }

  FirestoreService? _maybeFirestoreService() {
    try {
      return context.read<FirestoreService>();
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistLiveSessionState({
    String? eventType,
    Map<String, dynamic>? eventData,
    String? successMessage,
  }) async {
    final FirestoreService? firestoreService = _maybeFirestoreService();
    final AppState? appState = context.read<AppState?>();
    final String? siteId = widget.siteId?.trim().isNotEmpty == true
        ? widget.siteId?.trim()
        : appState?.activeSiteId?.trim();
    final String? educatorId = appState?.userId?.trim();
    if (firestoreService == null ||
        siteId == null ||
        siteId.isEmpty ||
        educatorId == null ||
        educatorId.isEmpty) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      final String docId = '${widget.todayClass.id}_$siteId';
      final Map<String, dynamic> modePayload = <String, dynamic>{
        'siteId': siteId,
        'sessionOccurrenceId': widget.todayClass.id,
        'sessionId': widget.todayClass.sessionId,
        'sessionTitle': widget.todayClass.title,
        'pacingMode': _pacingMode,
        'coldCallLearnerId': _selectedColdCallLearnerId,
        'coldCallLearnerName':
            widget.learnerNamesById[_selectedColdCallLearnerId],
        'pollPrompt': _pollController.text.trim(),
        'exitTicketPrompt': _exitTicketController.text.trim(),
        'misconceptionAlerts': _misconceptionAlerts,
        'updatedBy': educatorId,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await firestoreService.firestore
          .collection('liveSessionModes')
          .doc(docId)
          .set(modePayload, SetOptions(merge: true));
      if (eventType != null) {
        await firestoreService.firestore.collection('liveSessionEvents').add(
          <String, dynamic>{
            'siteId': siteId,
            'sessionOccurrenceId': widget.todayClass.id,
            'sessionId': widget.todayClass.sessionId,
            'eventType': eventType,
            'eventData': eventData ?? <String, dynamic>{},
            'createdBy': educatorId,
            'createdAt': FieldValue.serverTimestamp(),
          },
        );
      }
      if (!mounted || successMessage == null) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tEducatorToday(context, successMessage))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _queueColdCall() async {
    final String? learnerId = _selectedColdCallLearnerId;
    if (learnerId == null || learnerId.isEmpty) {
      return;
    }
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'educator_live_session_queue_cold_call',
        'class_id': widget.todayClass.id,
        'learner_id': learnerId,
      },
    );
    await _persistLiveSessionState(
      eventType: 'cold_call',
      eventData: <String, dynamic>{
        'learnerId': learnerId,
        'learnerName': widget.learnerNamesById[learnerId],
      },
      successMessage: 'Cold-call queued',
    );
  }

  Future<void> _launchQuickPoll() async {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'educator_live_session_save_poll_prompt',
        'class_id': widget.todayClass.id,
      },
    );
    await _persistLiveSessionState(
      eventType: 'poll',
      eventData: <String, dynamic>{
        'prompt': _pollController.text.trim(),
        'options': const <String>['Need help', 'Ready', 'Can teach it'],
      },
      successMessage: 'Quick poll saved to live mode',
    );
  }

  Future<void> _sendExitTicket() async {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'educator_live_session_save_exit_ticket_prompt',
        'class_id': widget.todayClass.id,
      },
    );
    await _persistLiveSessionState(
      eventType: 'exit_ticket',
      eventData: <String, dynamic>{
        'prompt': _exitTicketController.text.trim(),
      },
      successMessage: 'Exit ticket saved to live mode',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _tEducatorToday(context, 'Live Session Mode'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              widget.todayClass.title,
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
            const SizedBox(height: 20),
            Text(
              _tEducatorToday(context, 'Pacing'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <String>['reteach', 'steady', 'accelerate']
                  .map(
                    (String mode) => ChoiceChip(
                      label: Text(
                        _tEducatorToday(
                          context,
                          mode == 'reteach'
                              ? 'Reteach'
                              : mode == 'accelerate'
                                  ? 'Accelerate'
                                  : 'Steady',
                        ),
                      ),
                      selected: _pacingMode == mode,
                      onSelected: (_) {
                        setState(() => _pacingMode = mode);
                      },
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 20),
            Text(
              _tEducatorToday(context, 'Cold-Calls'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (widget.learnerNamesById.isEmpty)
              Text(_tEducatorToday(context, 'No learners available'))
            else
              DropdownButtonFormField<String>(
                initialValue: _selectedColdCallLearnerId,
                items: widget.learnerNamesById.entries
                    .map(
                      (MapEntry<String, String> entry) =>
                          DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (String? value) {
                  setState(() => _selectedColdCallLearnerId = value);
                },
                decoration: InputDecoration(
                  labelText: _tEducatorToday(context, 'Target learner'),
                  border: const OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isSaving ? null : _queueColdCall,
                icon: const Icon(Icons.record_voice_over_outlined),
                label: Text(_tEducatorToday(context, 'Queue Cold-Call')),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _tEducatorToday(context, 'Quick Poll'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pollController,
              decoration: InputDecoration(
                labelText: _tEducatorToday(context, 'Poll prompt'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isSaving ? null : _launchQuickPoll,
                icon: const Icon(Icons.poll_outlined),
                label: Text(
                  _tEducatorToday(context, 'Save Quick Poll Prompt'),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _tEducatorToday(context, 'Exit Ticket'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _exitTicketController,
              decoration: InputDecoration(
                labelText: _tEducatorToday(context, 'Exit ticket prompt'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isSaving ? null : _sendExitTicket,
                icon: const Icon(Icons.assignment_turned_in_outlined),
                label: Text(
                  _tEducatorToday(context, 'Save Exit Ticket Prompt'),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _tEducatorToday(context, 'Misconception Alerts'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_misconceptionAlerts.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ScholesaColors.educator.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _tEducatorToday(
                    context,
                    'No misconception alerts yet for this session.',
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _misconceptionAlerts
                    .map(
                      (String alert) => Chip(
                        label: Text(alert),
                        avatar:
                            const Icon(Icons.warning_amber_rounded, size: 16),
                      ),
                    )
                    .toList(growable: false),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving
                    ? null
                    : () => _persistLiveSessionState(
                          successMessage: 'Live session mode saved',
                        ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_tEducatorToday(context, 'Save Live Mode')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ScholesaColors.educator,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.schSurfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: context.schTextSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
