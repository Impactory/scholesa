import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../auth/app_state.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  static const List<int> _windows = <int>[7, 30, 90];
  int _selectedDays = 30;
  late Future<_AnalyticsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AnalyticsData> _load() async {
    final appState = context.read<AppState>();
    final siteId = appState.primarySiteId;
    if (siteId == null || siteId.isEmpty) return const _AnalyticsData();

    final start = Timestamp.fromDate(DateTime.now().subtract(Duration(days: _selectedDays)));
    final firestore = FirebaseFirestore.instance;

    Future<QuerySnapshot<Map<String, dynamic>>> fetch(String col) => firestore
        .collection(col)
        .where('siteId', isEqualTo: siteId)
        .where('createdAt', isGreaterThanOrEqualTo: start)
        .limit(500)
        .get();

    final results = await Future.wait< QuerySnapshot<Map<String, dynamic>>>(<Future<QuerySnapshot<Map<String, dynamic>>>>[
      fetch('attendanceRecords'),
      fetch('missionAttempts'),
      fetch('incidentReports'),
      fetch('aiDrafts'),
      fetch('telemetryEvents'),
    ]);

    final attendance = results[0].docs.map(AttendanceRecordModel.fromDoc).toList();
    final attempts = results[1].docs.map(MissionAttemptModel.fromDoc).toList();
    final incidents = results[2].docs.map(IncidentReportModel.fromDoc).toList();
    final drafts = results[3].docs.map(AiDraftModel.fromDoc).toList();
    final telemetryEvents = results[4].docs.map((doc) => doc.data()).toList();
    final kpis = await AccountabilityKPIRepository().listRecent(limit: 6);

    final attendanceTotal = attendance.length;
    final attendancePresent = attendance.where((a) => a.status.toLowerCase() == 'present').length;

    final attemptsTotal = attempts.length;
    final attemptsSubmitted = attempts.where((a) => a.status.toLowerCase() != 'draft').length;
    final attemptsReviewed = attempts.where((a) => a.status.toLowerCase().contains('review') || a.status.toLowerCase().contains('approved')).length;

    final criticalIncidents = incidents.where((i) => i.severity == 'critical' || i.severity == 'major').length;
    final openIncidents = incidents.where((i) => i.status != 'closed').length;

    final draftsTotal = drafts.length;
    final draftsReviewed = drafts.where((d) => d.status.toLowerCase() == 'reviewed' || d.status.toLowerCase() == 'approved').length;

    final Map<String, int> eventCounts = <String, int>{};
    for (final event in telemetryEvents) {
      final name = (event['event'] as String? ?? '').trim();
      if (name.isEmpty) continue;
      eventCounts[name] = (eventCounts[name] ?? 0) + 1;
    }

    return _AnalyticsData(
      attendanceTotal: attendanceTotal,
      attendancePresent: attendancePresent,
      attemptsTotal: attemptsTotal,
      attemptsSubmitted: attemptsSubmitted,
      attemptsReviewed: attemptsReviewed,
      criticalIncidents: criticalIncidents,
      openIncidents: openIncidents,
      draftsTotal: draftsTotal,
      draftsReviewed: draftsReviewed,
      kpis: kpis,
      eventCounts: eventCounts,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final siteId = appState.primarySiteId;
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics & KPIs')),
      body: siteId == null || siteId.isEmpty
          ? const Center(child: Text('Select a primary site to view analytics.'))
          : RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<_AnalyticsData>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final data = snapshot.data ?? const _AnalyticsData();
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          const Text('Window:'),
                          const SizedBox(width: 12),
                          DropdownButton<int>(
                            value: _selectedDays,
                            items: _windows
                                .map((d) => DropdownMenuItem<int>(value: d, child: Text('Last $d days')))
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _selectedDays = value;
                                _future = _load();
                              });
                            },
                          ),
                          const Spacer(),
                          Text('Site: $siteId'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _metricCard(
                            title: 'Attendance compliance',
                            value: data.attendanceTotal == 0
                                ? 'N/A'
                                : '${((data.attendancePresent / data.attendanceTotal) * 100).toStringAsFixed(1)}%',
                            subtitle: '${data.attendancePresent}/${data.attendanceTotal} present',
                            icon: Icons.check_circle_outline,
                            color: Colors.teal,
                          ),
                          _metricCard(
                            title: 'Missions submitted',
                            value: data.attemptsTotal == 0
                                ? '0'
                                : '${data.attemptsSubmitted}/${data.attemptsTotal}',
                            subtitle: '${data.attemptsReviewed} reviewed',
                            icon: Icons.flag_outlined,
                            color: Colors.indigo,
                          ),
                          _metricCard(
                            title: 'Incidents (major/critical)',
                            value: data.criticalIncidents.toString(),
                            subtitle: '${data.openIncidents} open',
                            icon: Icons.health_and_safety,
                            color: Colors.orange,
                          ),
                          _metricCard(
                            title: 'AI drafts reviewed',
                            value: data.draftsTotal == 0 ? '0' : '${data.draftsReviewed}/${data.draftsTotal}',
                            subtitle: 'Requested: ${data.draftsTotal}',
                            icon: Icons.bolt,
                            color: Colors.purple,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('Telemetry rollups', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _metricCard(
                            title: 'Logins',
                            value: _eventCount(data, 'auth.login').toString(),
                            subtitle: 'auth.logout: ${_eventCount(data, 'auth.logout')}',
                            icon: Icons.login,
                            color: Colors.blue,
                          ),
                          _metricCard(
                            title: 'Attendance events',
                            value: _eventCount(data, 'attendance.recorded').toString(),
                            subtitle: 'Mission submits: ${_eventCount(data, 'mission.attempt.submitted')}',
                            icon: Icons.checklist,
                            color: Colors.teal,
                          ),
                          _metricCard(
                            title: 'Messaging sent',
                            value: _eventCount(data, 'message.sent').toString(),
                            subtitle: 'Notifications: ${_eventCount(data, 'notification.requested')}',
                            icon: Icons.chat_bubble_outline,
                            color: Colors.indigo,
                          ),
                          _metricCard(
                            title: 'Orders',
                            value: _eventCount(data, 'order.intent').toString(),
                            subtitle: 'Paid: ${_eventCount(data, 'order.paid')}',
                            icon: Icons.shopping_cart_checkout,
                            color: Colors.green,
                          ),
                          _metricCard(
                            title: 'AI drafts',
                            value: _eventCount(data, 'aiDraft.requested').toString(),
                            subtitle: 'Reviewed: ${_eventCount(data, 'aiDraft.reviewed')}',
                            icon: Icons.bolt_outlined,
                            color: Colors.purple,
                          ),
                          _metricCard(
                            title: 'Leads',
                            value: _eventCount(data, 'lead.submitted').toString(),
                            subtitle: 'CMS views: ${_eventCount(data, 'cms.page.viewed')}',
                            icon: Icons.campaign,
                            color: Colors.orange,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('Accountability KPIs', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (data.kpis.isEmpty)
                        const Text('No KPIs recorded yet.')
                      else
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: data.kpis
                              .map((kpi) => _metricCard(
                                    title: kpi.name,
                                    value: kpi.currentValue.toString(),
                                    subtitle: kpi.unit != null && kpi.unit!.isNotEmpty
                                        ? 'Target: ${kpi.target} ${kpi.unit}'
                                        : 'Target: ${kpi.target}',
                                    icon: Icons.insights,
                                    color: Colors.blueGrey,
                                  ))
                              .toList(),
                        ),
                    ],
                  );
                },
              ),
            ),
    );
  }

  Widget _metricCard({required String title, required String value, required String subtitle, required IconData icon, required Color color}) {
    return SizedBox(
      width: 230,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 8),
                  Flexible(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  int _eventCount(_AnalyticsData data, String eventName) => data.eventCounts[eventName] ?? 0;
}

class _AnalyticsData {
  const _AnalyticsData({
    this.attendanceTotal = 0,
    this.attendancePresent = 0,
    this.attemptsTotal = 0,
    this.attemptsSubmitted = 0,
    this.attemptsReviewed = 0,
    this.criticalIncidents = 0,
    this.openIncidents = 0,
    this.draftsTotal = 0,
    this.draftsReviewed = 0,
    this.kpis = const <AccountabilityKPIModel>[],
    this.eventCounts = const <String, int>{},
  });

  final int attendanceTotal;
  final int attendancePresent;
  final int attemptsTotal;
  final int attemptsSubmitted;
  final int attemptsReviewed;
  final int criticalIncidents;
  final int openIncidents;
  final int draftsTotal;
  final int draftsReviewed;
  final List<AccountabilityKPIModel> kpis;
  final Map<String, int> eventCounts;
}
