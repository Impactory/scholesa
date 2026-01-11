import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../ui/theme/scholesa_theme.dart';
import 'checkin_models.dart';
import 'checkin_service.dart';

/// Site Check-in / Check-out Page
/// Beautiful colorful UI for managing learner arrivals and departures
class CheckinPage extends StatefulWidget {
  const CheckinPage({super.key});

  @override
  State<CheckinPage> createState() => _CheckinPageState();
}

class _CheckinPageState extends State<CheckinPage> with SingleTickerProviderStateMixin {
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
              ScholesaColors.site.withOpacity(0.05),
              Colors.white,
              const Color(0xFF3B82F6).withOpacity(0.03),
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
              Expanded(child: _buildTabContent()),
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
                  color: const Color(0xFF3B82F6).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Check-in / Check-out',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF3B82F6),
                ),
              ),
              Text(
                'Manage arrivals and pickups',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () => context.read<CheckinService>().loadTodayData(),
            icon: const Icon(Icons.refresh, color: Color(0xFF3B82F6)),
            tooltip: 'Refresh',
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
                  label: 'Total',
                  color: ScholesaColors.site,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatMiniCard(
                  icon: Icons.check_circle,
                  value: service.presentCount.toString(),
                  label: 'Present',
                  color: ScholesaColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatMiniCard(
                  icon: Icons.exit_to_app,
                  value: service.checkedOutCount.toString(),
                  label: 'Left',
                  color: ScholesaColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatMiniCard(
                  icon: Icons.schedule,
                  value: service.absentCount.toString(),
                  label: 'Absent',
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
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (String value) => service.setSearchQuery(value),
                  decoration: InputDecoration(
                    hintText: 'Search learners...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF3B82F6)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              service.setSearchQuery('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                      label: 'All',
                      selected: service.statusFilter == null,
                      onTap: () => service.setStatusFilter(null),
                    ),
                    _FilterChip(
                      label: 'Present',
                      selected: service.statusFilter == CheckStatus.checkedIn,
                      onTap: () => service.setStatusFilter(CheckStatus.checkedIn),
                      color: ScholesaColors.success,
                    ),
                    _FilterChip(
                      label: 'Late',
                      selected: service.statusFilter == CheckStatus.late,
                      onTap: () => service.setStatusFilter(CheckStatus.late),
                      color: ScholesaColors.warning,
                    ),
                    _FilterChip(
                      label: 'Checked Out',
                      selected: service.statusFilter == CheckStatus.checkedOut,
                      onTap: () => service.setStatusFilter(CheckStatus.checkedOut),
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
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFF3B82F6),
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[600],
        tabs: const <Widget>[
          Tab(text: 'Learners'),
          Tab(text: "Today's Log"),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: <Widget>[
        _buildLearnersList(),
        _buildTodayLog(),
      ],
    );
  }

  Widget _buildLearnersList() {
    return Consumer<CheckinService>(
      builder: (BuildContext context, CheckinService service, _) {
        if (service.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
          );
        }

        if (service.learnerSummaries.isEmpty) {
          return _buildEmptyState(
            icon: Icons.people_outline,
            title: 'No learners found',
            subtitle: 'Try adjusting your search',
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
            );
          },
        );
      },
    );
  }

  Widget _buildTodayLog() {
    return Consumer<CheckinService>(
      builder: (BuildContext context, CheckinService service, _) {
        if (service.todayRecords.isEmpty) {
          return _buildEmptyState(
            icon: Icons.history,
            title: 'No records today',
            subtitle: 'Check-in/out activity will appear here',
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
              color: const Color(0xFF3B82F6).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: const Color(0xFF3B82F6)),
          ),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      onPressed: () => _showQrScanDialog(),
      backgroundColor: const Color(0xFF3B82F6),
      icon: const Icon(Icons.qr_code_scanner),
      label: const Text('Scan QR'),
    );
  }

  void _showCheckInDialog(LearnerDaySummary summary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => _CheckInSheet(summary: summary, isCheckOut: false),
    );
  }

  void _showCheckOutDialog(LearnerDaySummary summary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => _CheckInSheet(summary: summary, isCheckOut: true),
    );
  }

  void _showQrScanDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: <Widget>[
            Icon(Icons.qr_code, color: Colors.white),
            SizedBox(width: 12),
            Text('QR Scanner coming soon'),
          ],
        ),
        backgroundColor: const Color(0xFF3B82F6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
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
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
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
        color: selected ? chipColor : chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
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
  });
  final LearnerDaySummary summary;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;

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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _statusColor.withOpacity(0.2)),
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
                      colors: <Color>[ScholesaColors.learner.withOpacity(0.8), ScholesaColors.learner],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: ScholesaColors.learner.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(summary.learnerName),
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
                              summary.learnerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _statusColor.withOpacity(0.1),
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
                                  _statusText,
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
                          'In: ${_formatTime(summary.checkedInAt!)}${summary.checkedInBy != null ? ' by ${summary.checkedInBy}' : ''}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                      if (summary.checkedOutAt != null) ...<Widget>[
                        Text(
                          'Out: ${_formatTime(summary.checkedOutAt!)}${summary.checkedOutBy != null ? ' by ${summary.checkedOutBy}' : ''}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
                if (summary.currentStatus == null || summary.currentStatus == CheckStatus.checkedOut)
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.login,
                      label: 'Check In',
                      color: ScholesaColors.success,
                      onTap: onCheckIn,
                    ),
                  )
                else if (summary.isCurrentlyPresent) ...<Widget>[
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.logout,
                      label: 'Check Out',
                      color: const Color(0xFF3B82F6),
                      onTap: onCheckOut,
                    ),
                  ),
                ],
                if (summary.authorizedPickups.isNotEmpty) ...<Widget>[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _showAuthorizedPickups(context),
                    icon: const Icon(Icons.people, color: Colors.grey),
                    tooltip: 'Authorized pickups',
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
    final List<String> parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 2).toUpperCase();
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
              'Authorized Pickups',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'For ${summary.learnerName}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ...summary.authorizedPickups.map((AuthorizedPickup pickup) => ListTile(
              leading: CircleAvatar(
                backgroundColor: pickup.isPrimaryContact
                    ? ScholesaColors.success.withOpacity(0.1)
                    : Colors.grey[100],
                child: Icon(
                  Icons.person,
                  color: pickup.isPrimaryContact ? ScholesaColors.success : Colors.grey,
                ),
              ),
              title: Row(
                children: <Widget>[
                  Text(pickup.name),
                  if (pickup.isPrimaryContact) ...<Widget>[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: ScholesaColors.success.withOpacity(0.1),
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
              subtitle: Text(pickup.relationship),
              trailing: pickup.phone != null
                  ? IconButton(
                      icon: const Icon(Icons.phone),
                      onPressed: () {},
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
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
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
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.1),
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
                        record.learnerName,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _statusColor.withOpacity(0.1),
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
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  if (record.notes != null)
                    Text(
                      record.notes!,
                      style: TextStyle(color: Colors.grey[500], fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                ],
              ),
            ),
            Text(
              _formatTime(record.timestamp),
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final int hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final String period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
  }
}

class _CheckInSheet extends StatefulWidget {

  const _CheckInSheet({required this.summary, required this.isCheckOut});
  final LearnerDaySummary summary;
  final bool isCheckOut;

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
    if (widget.summary.authorizedPickups.isNotEmpty) {
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
    final Color color = widget.isCheckOut ? const Color(0xFF3B82F6) : ScholesaColors.success;

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
                          color: color.withOpacity(0.1),
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
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.summary.learnerName,
                            style: TextStyle(color: Colors.grey[600]),
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
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: <Widget>[
                          Icon(Icons.warning, color: ScholesaColors.warning),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text('No authorized contacts on file'),
                          ),
                        ],
                      ),
                    )
                  else
                    ...widget.summary.authorizedPickups.map((AuthorizedPickup pickup) => _PickupOption(
                      pickup: pickup,
                      selected: _selectedPickup == pickup,
                      onTap: () => setState(() => _selectedPickup = pickup),
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
                      hintText: 'Add any notes...',
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
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.summary.learnerName} ${widget.isCheckOut ? 'checked out' : 'checked in'} successfully',
          ),
          backgroundColor: widget.isCheckOut ? const Color(0xFF3B82F6) : ScholesaColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
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
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? ScholesaColors.success.withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? ScholesaColors.success : Colors.grey.withOpacity(0.2),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              backgroundColor: pickup.isPrimaryContact
                  ? ScholesaColors.success.withOpacity(0.2)
                  : Colors.grey[200],
              child: Icon(
                Icons.person,
                color: pickup.isPrimaryContact ? ScholesaColors.success : Colors.grey,
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
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: ScholesaColors.success.withOpacity(0.1),
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
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
