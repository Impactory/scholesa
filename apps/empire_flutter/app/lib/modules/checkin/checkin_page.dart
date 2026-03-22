import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/workflow_surface_i18n.dart';
import '../../services/telemetry_service.dart';
import '../../ui/auth/global_session_menu.dart';
import '../../ui/theme/scholesa_theme.dart';
import 'checkin_models.dart';
import 'checkin_service.dart';

String _tCheckin(BuildContext context, String input) {
  return WorkflowSurfaceI18n.text(context, input);
}

const String _canonicalLearnerUnavailableLabel = 'Learner unavailable';

String _displayLearnerName(BuildContext context, String learnerName) {
  final String normalized = learnerName.trim();
  if (normalized.isEmpty ||
      normalized == 'Unknown' ||
      normalized == _canonicalLearnerUnavailableLabel) {
    return _tCheckin(context, 'Learner unavailable');
  }
  return normalized;
}

class CheckinPage extends StatefulWidget {
  const CheckinPage({super.key});

  @override
  State<CheckinPage> createState() => _CheckinPageState();
}

class _CheckinPageState extends State<CheckinPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CheckinService>().loadTodayData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
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
              ScholesaColors.site.withValues(alpha: 0.05),
              context.schSurface,
              const Color(0xFF3B82F6).withValues(alpha: 0.03),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _buildHeader(),
              _buildStatsRow(),
              _buildSearchAndFilters(),
              _buildTabBar(),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFF3B82F6), Color(0xFF60A5FA)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.qr_code_scanner,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _tCheckin(context, 'Check-in / Check-out'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF3B82F6),
                    ),
              ),
              Text(
                _tCheckin(context, 'Manage arrivals and pickups'),
                style: TextStyle(color: context.schTextSecondary, fontSize: 14),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () async {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{'cta': 'checkin_refresh'},
              );
              await context.read<CheckinService>().loadTodayData();
            },
            icon: const Icon(Icons.refresh, color: Color(0xFF3B82F6)),
            tooltip: _tCheckin(context, 'Refresh'),
          ),
          const SizedBox(width: 4),
          const SessionMenuHeaderAction(
            foregroundColor: Color(0xFF3B82F6),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Consumer<CheckinService>(
      builder: (BuildContext context, CheckinService service, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: <Widget>[
              Expanded(
                child: _StatMiniCard(
                  icon: Icons.people,
                  value: service.totalLearners.toString(),
                  label: _tCheckin(context, 'Total'),
                  color: ScholesaColors.site,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatMiniCard(
                  icon: Icons.check_circle,
                  value: service.presentCount.toString(),
                  label: _tCheckin(context, 'Present'),
                  color: ScholesaColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatMiniCard(
                  icon: Icons.exit_to_app,
                  value: service.checkedOutCount.toString(),
                  label: _tCheckin(context, 'Left'),
                  color: ScholesaColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatMiniCard(
                  icon: Icons.schedule,
                  value: service.absentCount.toString(),
                  label: _tCheckin(context, 'Absent'),
                  color: ScholesaColors.error,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchAndFilters() {
    return Consumer<CheckinService>(
      builder: (BuildContext context, CheckinService service, _) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: <Widget>[
              // Search bar
              Container(
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
                child: TextField(
                  controller: _searchController,
                  onChanged: (String value) {
                    if (value.isNotEmpty) {
                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: <String, dynamic>{
                          'cta': 'checkin_search_input',
                          'length': value.length,
                        },
                      );
                    }
                    service.setSearchQuery(value);
                  },
                  decoration: InputDecoration(
                    hintText: _tCheckin(context, 'Search learners...'),
                    prefixIcon:
                        const Icon(Icons.search, color: Color(0xFF3B82F6)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              TelemetryService.instance.logEvent(
                                event: 'cta.clicked',
                                metadata: const <String, dynamic>{
                                  'cta': 'checkin_search_clear',
                                },
                              );
                              _searchController.clear();
                              service.setSearchQuery('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    _FilterChip(
                      label: _tCheckin(context, 'All'),
                      selected: service.statusFilter == null,
                      onTap: () {
                        TelemetryService.instance.logEvent(
                          event: 'cta.clicked',
                          metadata: const <String, dynamic>{
                            'cta': 'checkin_filter_all'
                          },
                        );
                        service.setStatusFilter(null);
                      },
                    ),
                    _FilterChip(
                      label: _tCheckin(context, 'Present'),
                      selected: service.statusFilter == CheckStatus.checkedIn,
                      onTap: () {
                        TelemetryService.instance.logEvent(
                          event: 'cta.clicked',
                          metadata: const <String, dynamic>{
                            'cta': 'checkin_filter_present'
                          },
                        );
                        service.setStatusFilter(CheckStatus.checkedIn);
                      },
                      color: ScholesaColors.success,
                    ),
                    _FilterChip(
                      label: _tCheckin(context, 'Late'),
                      selected: service.statusFilter == CheckStatus.late,
                      onTap: () {
                        TelemetryService.instance.logEvent(
                          event: 'cta.clicked',
                          metadata: const <String, dynamic>{
                            'cta': 'checkin_filter_late'
                          },
                        );
                        service.setStatusFilter(CheckStatus.late);
                      },
                      color: ScholesaColors.warning,
                    ),
                    _FilterChip(
                      label: _tCheckin(context, 'Checked Out'),
                      selected: service.statusFilter == CheckStatus.checkedOut,
                      onTap: () {
                        TelemetryService.instance.logEvent(
                          event: 'cta.clicked',
                          metadata: const <String, dynamic>{
                            'cta': 'checkin_filter_checked_out'
                          },
                        );
                        service.setStatusFilter(CheckStatus.checkedOut);
                      },
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.schSurfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (int index) {
          final List<String> tabs = <String>['learners', 'today_log'];
          TelemetryService.instance.logEvent(
            event: 'cta.clicked',
            metadata: <String, dynamic>{
              'cta': 'checkin_tab_change',
              'tab': tabs[index],
            },
          );
        },
        indicator: BoxDecoration(
          color: const Color(0xFF3B82F6),
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: context.schTextSecondary,
        tabs: <Widget>[
          Tab(text: _tCheckin(context, 'Learners')),
          Tab(text: _tCheckin(context, "Today's Log")),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Consumer<CheckinService>(
      builder: (BuildContext context, CheckinService service, _) {
        final bool hasCachedData =
            service.learnerSummaries.isNotEmpty || service.todayRecords.isNotEmpty;

        if (service.isLoading && !hasCachedData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
          );
        }

        if (service.error != null && !hasCachedData) {
          return _buildLoadErrorCard(service.error!);
        }

        return Column(
          children: <Widget>[
            if (service.error != null)
              _CheckinStatusBanner(message: service.error!),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: <Widget>[
                  _buildLearnersList(),
                  _buildTodayLog(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLearnersList() {
    return Consumer<CheckinService>(
      builder: (BuildContext context, CheckinService service, _) {
        if (service.isLoading &&
            service.learnerSummaries.isEmpty &&
            service.todayRecords.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
          );
        }

        if (service.learnerSummaries.isEmpty) {
          return _buildEmptyState(
            icon: Icons.people_outline,
            title: _tCheckin(context, 'No learners found'),
            subtitle: _tCheckin(context, 'Try adjusting your search'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: service.learnerSummaries.length,
          itemBuilder: (BuildContext context, int index) {
            final LearnerDaySummary summary = service.learnerSummaries[index];
            return _LearnerCheckinCard(
              summary: summary,
              onCheckIn: () => _showCheckInDialog(summary),
              onCheckOut: () => _showCheckOutDialog(summary),
              onFlagLatePickup: () => _flagLatePickup(summary),
            );
          },
        );
      },
    );
  }

  Widget _buildTodayLog() {
    return Consumer<CheckinService>(
      builder: (BuildContext context, CheckinService service, _) {
        if (service.isLoading &&
            service.todayRecords.isEmpty &&
            service.learnerSummaries.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
          );
        }

        if (service.todayRecords.isEmpty) {
          return _buildEmptyState(
            icon: Icons.history,
            title: _tCheckin(context, 'No records today'),
            subtitle:
                _tCheckin(context, 'Check-in/out activity will appear here'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: service.todayRecords.length,
          itemBuilder: (BuildContext context, int index) {
            final CheckRecord record = service.todayRecords[index];
            return _CheckRecordCard(record: record);
          },
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: const Color(0xFF3B82F6)),
          ),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: context.schTextSecondary)),
        ],
      ),
    );
  }

  Widget _buildLoadErrorCard(String error) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ScholesaColors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off,
                size: 40,
                color: ScholesaColors.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _tCheckin(
                context,
                'We could not load check-in data right now. Retry to check the current state.',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.schTextSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFab() {
    return Consumer<CheckinService>(
      builder: (BuildContext context, CheckinService service, _) {
        return FloatingActionButton.extended(
          onPressed: service.isLoading
              ? null
              : () {
                  TelemetryService.instance.logEvent(
                    event: 'cta.clicked',
                    metadata: const <String, dynamic>{
                      'cta': 'checkin_open_quick_pickup',
                    },
                  );
                  _showQrScanDialog();
                },
          backgroundColor: const Color(0xFF3B82F6),
          icon: const Icon(Icons.qr_code_scanner),
          label: Text(_tCheckin(context, 'Quick Pickup')),
        );
      },
    );
  }

  void _showCheckInDialog(LearnerDaySummary summary) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'checkin_open_check_in',
        'learner_id': summary.learnerId
      },
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) =>
          _CheckInSheet(summary: summary, isCheckOut: false),
    );
  }

  void _showCheckOutDialog(
    LearnerDaySummary summary, {
    AuthorizedPickup? initialPickup,
    String source = 'checkin_card',
  }) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'checkin_open_check_out',
        'learner_id': summary.learnerId,
        'source': source,
      },
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) =>
          _CheckInSheet(
            summary: summary,
            isCheckOut: true,
            initialPickup: initialPickup,
          ),
    );
  }

  Future<void> _flagLatePickup(LearnerDaySummary summary) async {
    final CheckinService service = context.read<CheckinService>();
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'checkin_flag_late_pickup',
        'learner_id': summary.learnerId,
      },
    );
    final bool success = await service.markLate(
      learnerId: summary.learnerId,
      learnerName: summary.learnerName,
      notes: 'Late pickup flagged from check-in desk',
    );
    if (!mounted) {
      return;
    }
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tCheckin(context, 'Unable to flag late pickup right now.'),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }
    TelemetryService.instance.logEvent(
      event: 'site.late_pickup.flagged',
      siteId: service.siteId,
      metadata: <String, dynamic>{
        'learnerId': summary.learnerId,
        'source': 'checkin_page',
      },
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '${_tCheckin(context, 'Late pickup flagged for')} ${_displayLearnerName(context, summary.learnerName)}'),
        backgroundColor: ScholesaColors.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _showQrScanDialog() async {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{'cta': 'checkin_quick_pickup_opened'},
    );
    final PickupLookupMatch? match = await showDialog<PickupLookupMatch>(
      context: context,
      builder: (BuildContext dialogContext) => const _QuickPickupLookupDialog(),
    );
    if (!mounted || match == null) {
      return;
    }
    _showCheckOutDialog(
      match.summary,
      initialPickup: match.pickup,
      source: 'quick_pickup_lookup',
    );
  }
}

class _CheckinStatusBanner extends StatelessWidget {
  const _CheckinStatusBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ScholesaColors.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ScholesaColors.warning.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.warning_amber_rounded,
              color: ScholesaColors.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${_tCheckin(context, 'Unable to refresh check-in data right now. Showing the last successful data. ')}$message',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.schTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== Sub Widgets ====================

class _StatMiniCard extends StatelessWidget {
  const _StatMiniCard({
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
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: context.schTextSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color chipColor = color ?? const Color(0xFF3B82F6);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? chipColor : chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            TelemetryService.instance.logEvent(
              event: 'cta.clicked',
              metadata: <String, dynamic>{
                'cta': 'checkin_filter_chip',
                'label': label,
              },
            );
            onTap();
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : chipColor,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LearnerCheckinCard extends StatelessWidget {
  const _LearnerCheckinCard({
    required this.summary,
    required this.onCheckIn,
    required this.onCheckOut,
    required this.onFlagLatePickup,
  });
  final LearnerDaySummary summary;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;
  final VoidCallback onFlagLatePickup;

  Color get _statusColor {
    switch (summary.currentStatus) {
      case CheckStatus.checkedIn:
        return ScholesaColors.success;
      case CheckStatus.checkedOut:
        return Colors.grey;
      case CheckStatus.late:
        return ScholesaColors.warning;
      case CheckStatus.absent:
      case null:
        return ScholesaColors.error;
    }
  }

  String get _statusText {
    if (summary.currentStatus == null) return 'Not arrived';
    return summary.currentStatus!.label;
  }

  @override
  Widget build(BuildContext context) {
    final String learnerName = _displayLearnerName(context, summary.learnerName);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _statusColor.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                // Avatar
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        ScholesaColors.learner.withValues(alpha: 0.8),
                        ScholesaColors.learner
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: ScholesaColors.learner.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(learnerName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              learnerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: _statusColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _tCheckin(context, _statusText),
                                  style: TextStyle(
                                    color: _statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (summary.checkedInAt != null) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          '${_tCheckin(context, 'In:')} ${_formatTime(summary.checkedInAt!)}${summary.checkedInBy != null ? ' ${_tCheckin(context, 'by')} ${summary.checkedInBy}' : ''}',
                          style: TextStyle(
                              color: context.schTextSecondary, fontSize: 12),
                        ),
                      ],
                      if (summary.checkedOutAt != null) ...<Widget>[
                        Text(
                          '${_tCheckin(context, 'Out:')} ${_formatTime(summary.checkedOutAt!)}${summary.checkedOutBy != null ? ' ${_tCheckin(context, 'by')} ${summary.checkedOutBy}' : ''}',
                          style: TextStyle(
                              color: context.schTextSecondary, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Action buttons
            Row(
              children: <Widget>[
                if (summary.currentStatus == null ||
                    summary.currentStatus == CheckStatus.checkedOut)
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.login,
                      label: _tCheckin(context, 'Check In'),
                      color: ScholesaColors.success,
                      onTap: onCheckIn,
                    ),
                  )
                else if (summary.isCurrentlyPresent) ...<Widget>[
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.logout,
                      label: _tCheckin(context, 'Check Out'),
                      color: const Color(0xFF3B82F6),
                      onTap: onCheckOut,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onFlagLatePickup,
                    icon: const Icon(
                      Icons.warning_amber_rounded,
                      color: ScholesaColors.warning,
                    ),
                    tooltip: _tCheckin(context, 'Flag late pickup'),
                  ),
                ],
                if (summary.authorizedPickups.isNotEmpty) ...<Widget>[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: <String, dynamic>{
                          'cta': 'checkin_open_authorized_pickups',
                          'learner_id': summary.learnerId,
                        },
                      );
                      _showAuthorizedPickups(context);
                    },
                    icon: const Icon(Icons.people, color: Colors.grey),
                    tooltip: _tCheckin(context, 'Authorized pickups'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final String safeName = name.trim();
    if (safeName.isEmpty) {
      return '?';
    }
    final List<String> parts = safeName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return safeName.substring(0, safeName.length >= 2 ? 2 : 1).toUpperCase();
  }

  String _formatTime(DateTime time) {
    final int hour = time.hour > 12 ? time.hour - 12 : time.hour;
    final String period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
  }

  void _showAuthorizedPickups(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _tCheckin(context, 'Authorized Pickups'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_tCheckin(context, 'For')} ${_displayLearnerName(context, summary.learnerName)}',
              style: TextStyle(color: context.schTextSecondary),
            ),
            const SizedBox(height: 16),
            ...summary.authorizedPickups
                .map((AuthorizedPickup pickup) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: pickup.isPrimaryContact
                            ? ScholesaColors.success.withValues(alpha: 0.1)
                            : context.schSurfaceMuted,
                        child: Icon(
                          Icons.person,
                          color: pickup.isPrimaryContact
                              ? ScholesaColors.success
                              : Colors.grey,
                        ),
                      ),
                      title: Row(
                        children: <Widget>[
                          Text(pickup.name),
                          if (pickup.isPrimaryContact) ...<Widget>[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: ScholesaColors.success
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _tCheckin(context, 'Primary'),
                                style: const TextStyle(
                                  color: ScholesaColors.success,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(pickup.relationship),
                      trailing: pickup.phone != null
                          ? IconButton(
                              icon: const Icon(Icons.phone),
                              onPressed: () {
                                TelemetryService.instance.logEvent(
                                  event: 'cta.clicked',
                                  metadata: <String, dynamic>{
                                    'cta': 'checkin_call_pickup_contact',
                                    'pickup_id': pickup.id,
                                    'pickup_name': pickup.name,
                                  },
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Call ${pickup.name}: ${pickup.phone}'),
                                    backgroundColor: ScholesaColors.site,
                                  ),
                                );
                              },
                            )
                          : null,
                    )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
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
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          TelemetryService.instance.logEvent(
            event: 'cta.clicked',
            metadata: <String, dynamic>{
              'cta': 'checkin_action_button',
              'label': label,
            },
          );
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckRecordCard extends StatelessWidget {
  const _CheckRecordCard({required this.record});
  final CheckRecord record;

  Color get _statusColor {
    switch (record.status) {
      case CheckStatus.checkedIn:
        return ScholesaColors.success;
      case CheckStatus.checkedOut:
        return const Color(0xFF3B82F6);
      case CheckStatus.late:
        return ScholesaColors.warning;
      case CheckStatus.absent:
        return ScholesaColors.error;
    }
  }

  IconData get _statusIcon {
    switch (record.status) {
      case CheckStatus.checkedIn:
        return Icons.login;
      case CheckStatus.checkedOut:
        return Icons.logout;
      case CheckStatus.late:
        return Icons.schedule;
      case CheckStatus.absent:
        return Icons.cancel;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_statusIcon, color: _statusColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        _displayLearnerName(context, record.learnerName),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          record.status.label,
                          style: TextStyle(
                            color: _statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'by ${record.visitorName}',
                    style: TextStyle(
                        color: context.schTextSecondary, fontSize: 12),
                  ),
                  if (record.notes != null)
                    Text(
                      record.notes!,
                      style: TextStyle(
                          color:
                              context.schTextSecondary.withValues(alpha: 0.88),
                          fontSize: 11,
                          fontStyle: FontStyle.italic),
                    ),
                ],
              ),
            ),
            Text(
              _formatTime(record.timestamp),
              style: TextStyle(
                  color: context.schTextSecondary.withValues(alpha: 0.88),
                  fontSize: 11),
            ),
          ],
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

class _CheckInSheet extends StatefulWidget {
  const _CheckInSheet({
    required this.summary,
    required this.isCheckOut,
    this.initialPickup,
  });
  final LearnerDaySummary summary;
  final bool isCheckOut;
  final AuthorizedPickup? initialPickup;

  @override
  State<_CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends State<_CheckInSheet> {
  final TextEditingController _notesController = TextEditingController();
  AuthorizedPickup? _selectedPickup;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPickup != null) {
      _selectedPickup = widget.summary.authorizedPickups.firstWhere(
        (AuthorizedPickup pickup) => pickup.id == widget.initialPickup!.id,
        orElse: () => widget.initialPickup!,
      );
    } else if (widget.summary.authorizedPickups.isNotEmpty) {
      _selectedPickup = widget.summary.authorizedPickups.first;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String action = widget.isCheckOut ? 'Check Out' : 'Check In';
    final Color color =
        widget.isCheckOut ? const Color(0xFF3B82F6) : ScholesaColors.success;

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          widget.isCheckOut ? Icons.logout : Icons.login,
                          color: color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            action,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            _displayLearnerName(
                              context,
                              widget.summary.learnerName,
                            ),
                            style: TextStyle(color: context.schTextSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.isCheckOut ? 'Picking up by:' : 'Dropping off by:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (widget.summary.authorizedPickups.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.schSurfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.warning,
                              color: ScholesaColors.warning),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(_tCheckin(
                                context, 'No authorized contacts on file')),
                          ),
                        ],
                      ),
                    )
                  else
                    ...widget.summary.authorizedPickups
                        .map((AuthorizedPickup pickup) => _PickupOption(
                              pickup: pickup,
                              selected: _selectedPickup == pickup,
                              onTap: () =>
                                  setState(() => _selectedPickup = pickup),
                            )),
                  const SizedBox(height: 24),
                  Text(
                    'Notes (optional)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: _tCheckin(context, 'Add any notes...'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading || _selectedPickup == null
                          ? null
                          : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Confirm $action',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
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

  Future<void> _submit() async {
    if (_selectedPickup == null) return;

    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': widget.isCheckOut
            ? 'checkin_confirm_check_out'
            : 'checkin_confirm_check_in',
        'learner_id': widget.summary.learnerId,
        'pickup_id': _selectedPickup!.id,
      },
    );

    setState(() => _isLoading = true);

    final CheckinService service = context.read<CheckinService>();
    bool success;

    if (widget.isCheckOut) {
      success = await service.checkOut(
        learnerId: widget.summary.learnerId,
        learnerName: widget.summary.learnerName,
        visitorId: _selectedPickup!.id,
        visitorName: _selectedPickup!.name,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );
    } else {
      success = await service.checkIn(
        learnerId: widget.summary.learnerId,
        learnerName: widget.summary.learnerName,
        visitorId: _selectedPickup!.id,
        visitorName: _selectedPickup!.name,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );
    }

    setState(() => _isLoading = false);

    if (success && mounted) {
      TelemetryService.instance.logEvent(
        event: widget.isCheckOut ? 'site.checkout' : 'site.checkin',
        siteId: service.siteId,
        metadata: <String, dynamic>{
          'learnerId': widget.summary.learnerId,
          'pickupId': _selectedPickup!.id,
          'source': 'checkin_sheet_confirm',
        },
      );
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_displayLearnerName(context, widget.summary.learnerName)} ${widget.isCheckOut ? 'checked out' : 'checked in'} successfully',
          ),
          backgroundColor: widget.isCheckOut
              ? const Color(0xFF3B82F6)
              : ScholesaColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}

class _QuickPickupLookupDialog extends StatefulWidget {
  const _QuickPickupLookupDialog();

  @override
  State<_QuickPickupLookupDialog> createState() =>
      _QuickPickupLookupDialogState();
}

class _QuickPickupLookupDialogState extends State<_QuickPickupLookupDialog> {
  final TextEditingController _queryController = TextEditingController();
  List<PickupLookupMatch> _matches = const <PickupLookupMatch>[];
  String? _error;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _resolve() {
    final CheckinService service = context.read<CheckinService>();
    final String query = _queryController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _matches = const <PickupLookupMatch>[];
        _error = _tCheckin(
          context,
          'Enter a pickup code, learner name, or pickup phone',
        );
      });
      return;
    }
    final List<PickupLookupMatch> matches = service.findPickupMatches(query);
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'checkin_quick_pickup_search',
        'query_length': query.length,
        'match_count': matches.length,
      },
    );
    if (matches.length == 1) {
      TelemetryService.instance.logEvent(
        event: 'cta.clicked',
        metadata: <String, dynamic>{
          'cta': 'checkin_quick_pickup_resolved',
          'learner_id': matches.first.summary.learnerId,
          'pickup_id': matches.first.pickup.id,
          'source': matches.first.matchSource,
        },
      );
      Navigator.of(context).pop(matches.first);
      return;
    }
    setState(() {
      _matches = matches;
      _error = matches.isEmpty
          ? _tCheckin(
              context,
              'No active pickup match found',
            )
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_tCheckin(context, 'Quick Pickup')),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _tCheckin(context, 'Scan or enter pickup code'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _tCheckin(
                  context,
                  'Connected scanners can type directly into this field. You can also search by learner name or pickup phone.',
                ),
                style: TextStyle(color: context.schTextSecondary, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _queryController,
                autofocus: true,
                onSubmitted: (_) => _resolve(),
                decoration: InputDecoration(
                  labelText:
                      _tCheckin(context, 'Pickup code, learner, or phone'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ScholesaColors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ScholesaColors.warning.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: context.schTextSecondary),
                  ),
                ),
              ],
              if (_matches.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                Text(
                  _tCheckin(context, 'Continue with check-out'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                ..._matches.map(
                  (PickupLookupMatch match) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _displayLearnerName(context, match.summary.learnerName),
                    ),
                    subtitle: Text(
                      [
                        match.pickup.name,
                        match.pickup.relationship,
                        if ((match.pickup.phone ?? '').trim().isNotEmpty)
                          match.pickup.phone!,
                      ].join(' • '),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: <String, dynamic>{
                          'cta': 'checkin_quick_pickup_select_match',
                          'learner_id': match.summary.learnerId,
                          'pickup_id': match.pickup.id,
                          'source': match.matchSource,
                        },
                      );
                      Navigator.of(context).pop(match);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            TelemetryService.instance.logEvent(
              event: 'cta.clicked',
              metadata: const <String, dynamic>{
                'cta': 'checkin_quick_pickup_close',
              },
            );
            Navigator.of(context).pop();
          },
          child: Text(_tCheckin(context, 'Close')),
        ),
        FilledButton(
          onPressed: _resolve,
          child: Text(_tCheckin(context, 'Find pickup')),
        ),
      ],
    );
  }
}

class _PickupOption extends StatelessWidget {
  const _PickupOption({
    required this.pickup,
    required this.selected,
    required this.onTap,
  });
  final AuthorizedPickup pickup;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        TelemetryService.instance.logEvent(
          event: 'cta.clicked',
          metadata: <String, dynamic>{
            'cta': 'checkin_pickup_option',
            'pickup_name': pickup.name,
          },
        );
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? ScholesaColors.success.withValues(alpha: 0.1)
              : context.schSurfaceMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? ScholesaColors.success
                : Colors.grey.withValues(alpha: 0.2),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              backgroundColor: pickup.isPrimaryContact
                  ? ScholesaColors.success.withValues(alpha: 0.2)
                  : Colors.grey[200],
              child: Icon(
                Icons.person,
                color: pickup.isPrimaryContact
                    ? ScholesaColors.success
                    : Colors.grey,
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
                        pickup.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (pickup.isPrimaryContact) ...<Widget>[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                ScholesaColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Primary',
                            style: TextStyle(
                              color: ScholesaColors.success,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    pickup.relationship,
                    style: TextStyle(
                        color: context.schTextSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: ScholesaColors.success),
          ],
        ),
      ),
    );
  }
}
