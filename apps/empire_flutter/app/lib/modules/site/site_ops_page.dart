import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../auth/app_state.dart';
import '../../i18n/site_surface_i18n.dart';
import '../../services/firestore_service.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';

String _tSiteOps(BuildContext context, String input) {
  return SiteSurfaceI18n.text(context, input);
}

/// Site operations page for daily operations overview
/// Based on docs/42_PHYSICAL_SITE_CHECKIN_CHECKOUT_SPEC.md
class SiteOpsPage extends StatefulWidget {
  const SiteOpsPage({super.key});

  @override
  State<SiteOpsPage> createState() => _SiteOpsPageState();
}

class _SiteOpsPageState extends State<SiteOpsPage> {
  bool _isDayOpen = false;
  int _presentCount = 0;
  int _pendingPickups = 0;
  int _openIncidents = 0;
  bool _isLoading = false;
  String? _siteId;
  List<_ActivityEntry> _recentActivity = <_ActivityEntry>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOpsData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: Text(_tSiteOps(context, 'Today Operations')),
        backgroundColor: ScholesaColors.siteGradient.colors.first,
        foregroundColor: Colors.white,
        actions: <Widget>[
          Switch(
            value: _isDayOpen,
            onChanged: (bool value) {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'module': 'site_ops',
                  'cta_id': 'toggle_day_open',
                  'surface': 'appbar_switch',
                  'is_day_open': value,
                },
              );
              setState(() => _isDayOpen = value);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(value
                      ? _tSiteOps(context, 'Day opened')
                      : _tSiteOps(context, 'Day closed')),
                  backgroundColor: value ? Colors.green : Colors.orange,
                ),
              );
            },
            activeThumbColor: Colors.white,
            activeTrackColor: Colors.green.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildStatusBanner(),
            const SizedBox(height: 24),
            _buildQuickStats(),
            const SizedBox(height: 24),
            _buildQuickActions(),
            const SizedBox(height: 24),
            _buildRecentActivity(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: _isDayOpen
            ? const LinearGradient(
                colors: <Color>[Color(0xFF22C55E), Color(0xFF4ADE80)])
            : const LinearGradient(
                colors: <Color>[Color(0xFFF59E0B), Color(0xFFFBBF24)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: (_isDayOpen ? Colors.green : Colors.orange)
                .withValues(alpha: 0.3),
            blurRadius: 12,
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
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isDayOpen
                  ? Icons.door_front_door_rounded
                  : Icons.door_sliding_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _isDayOpen
                      ? _tSiteOps(context, 'Site is OPEN')
                      : _tSiteOps(context, 'Site is CLOSED'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isDayOpen
                      ? _tSiteOps(context, 'Check-ins and operations active')
                      : _tSiteOps(context, 'Toggle switch to open the day'),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: <Widget>[
        Expanded(
          child: _buildStatCard(_tSiteOps(context, 'Present'), _presentCount.toString(),
                Icons.people_rounded, Colors.green)),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(_tSiteOps(context, 'Pickups'), _pendingPickups.toString(),
                Icons.directions_walk_rounded, Colors.blue)),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(_tSiteOps(context, 'Incidents'), _openIncidents.toString(),
                Icons.warning_rounded, Colors.orange)),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ScholesaColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: ScholesaColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _tSiteOps(context, 'Quick Actions'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: ScholesaColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.5,
          children: <Widget>[
            _buildActionButton(
              'Check-in', Icons.login_rounded, '/site/checkin'),
            _buildActionButton(
              'Check-out', Icons.logout_rounded, '/site/checkin'),
            _buildActionButton(
              'New Incident', Icons.add_alert_rounded, '/site/incidents'),
            _buildActionButton(
              'View Roster', Icons.list_alt_rounded, '/site/sessions'),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, String route) {
    return Material(
      color: ScholesaColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          TelemetryService.instance.logEvent(
            event: 'cta.clicked',
            metadata: <String, dynamic>{
              'module': 'site_ops',
              'cta_id': 'quick_action',
              'surface': 'quick_actions',
              'label': label,
              'route': route,
            },
          );
          _handleQuickAction(label);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: <Widget>[
              Icon(icon, color: ScholesaColors.primary, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _tSiteOps(context, label),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _tSiteOps(context, 'Recent Activity'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: ScholesaColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: ScholesaColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: _isLoading
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      _tSiteOps(context, 'Loading...'),
                      style:
                          const TextStyle(color: ScholesaColors.textSecondary),
                    ),
                  ),
                )
              : _recentActivity.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Text(
                          _tSiteOps(context, 'No recent activity yet'),
                          style: const TextStyle(
                              color: ScholesaColors.textSecondary),
                        ),
                      ),
                    )
                  : Column(
                      children: <Widget>[
                        ..._buildRecentActivityRows(),
                      ],
                    ),
        ),
      ],
    );
  }

  List<Widget> _buildRecentActivityRows() {
    final List<Widget> rows = <Widget>[];
    for (var index = 0; index < _recentActivity.length; index++) {
      final _ActivityEntry entry = _recentActivity[index];
      rows.add(
          _buildActivityItem(entry.title, entry.time, entry.icon, entry.color));
      if (index < _recentActivity.length - 1) {
        rows.add(const Divider(height: 1));
      }
    }
    return rows;
  }

  Future<void> _handleQuickAction(String label) async {
    if (label == 'New Incident') {
      if (!mounted) return;
      Navigator.of(context).pushNamed('/site/incidents');
      return;
    }

    try {
      final FirestoreService firestoreService = context.read<FirestoreService>();
      final String siteId = _siteId ?? '';
      if (siteId.isNotEmpty) {
        await firestoreService.firestore.collection('siteOpsEvents').add(
          <String, dynamic>{
            'siteId': siteId,
            'action': label,
            'createdBy': FirebaseAuth.instance.currentUser?.uid,
            'createdAt': FieldValue.serverTimestamp(),
          },
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label ${_tSiteOps(context, 'completed')}')),
      );
      await _loadOpsData();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tSiteOps(context, 'Action failed'))),
      );
    }
  }

  Future<void> _loadOpsData() async {
    final AppState appState = context.read<AppState>();
    final FirestoreService firestoreService = context.read<FirestoreService>();
    final String resolvedSiteId = (appState.activeSiteId ??
            (appState.siteIds.isNotEmpty ? appState.siteIds.first : ''))
        .trim();
    _siteId = resolvedSiteId;

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      if (resolvedSiteId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _presentCount = 0;
          _pendingPickups = 0;
          _openIncidents = 0;
          _isDayOpen = false;
          _recentActivity = <_ActivityEntry>[];
        });
        return;
      }

      final DateTime now = DateTime.now();
      final DateTime dayStart = DateTime(now.year, now.month, now.day);
      final List<_TimedActivity> activities = <_TimedActivity>[];

      final QuerySnapshot<Map<String, dynamic>> presenceSnap =
          await firestoreService.firestore
              .collection('checkins')
              .where('siteId', isEqualTo: resolvedSiteId)
              .limit(250)
              .get();

      final Set<String> presentLearners = <String>{};
      int pickupSignals = 0;
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in presenceSnap.docs) {
        final Map<String, dynamic> data = doc.data();
        final DateTime? eventAt = _toDateTime(data['timestamp']);
        if (eventAt == null || eventAt.isBefore(dayStart)) continue;

        final String learnerId = (data['learnerId'] as String?) ?? '';
        final String type =
            ((data['type'] as String?) ?? '').trim().toLowerCase();
        if (type == 'checkin' && learnerId.isNotEmpty) {
          presentLearners.add(learnerId);
          activities.add(
            _TimedActivity(
              title: _tSiteOps(context, 'Manual check-in recorded'),
              at: eventAt,
              icon: Icons.login_rounded,
              color: Colors.green,
            ),
          );
        } else if (type == 'checkout' && learnerId.isNotEmpty) {
          presentLearners.remove(learnerId);
          pickupSignals += 1;
          activities.add(
            _TimedActivity(
              title: _tSiteOps(context, 'Manual check-out recorded'),
              at: eventAt,
              icon: Icons.logout_rounded,
              color: Colors.blue,
            ),
          );
        }
      }

      QuerySnapshot<Map<String, dynamic>> incidentsSnap;
      try {
        incidentsSnap = await firestoreService.firestore
            .collection('incidents')
            .where('siteId', isEqualTo: resolvedSiteId)
            .orderBy('reportedAt', descending: true)
            .limit(100)
            .get();
      } catch (_) {
        incidentsSnap = await firestoreService.firestore
            .collection('incidents')
            .where('siteId', isEqualTo: resolvedSiteId)
            .limit(100)
            .get();
      }

      int openIncidents = 0;
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in incidentsSnap.docs) {
        final Map<String, dynamic> data = doc.data();
        final String status =
            ((data['status'] as String?) ?? '').trim().toLowerCase();
        if (status != 'closed') {
          openIncidents += 1;
        }
        final DateTime? incidentAt =
            _toDateTime(data['reportedAt']) ?? _toDateTime(data['createdAt']);
        if (incidentAt == null || incidentAt.isBefore(dayStart)) continue;

        activities.add(
          _TimedActivity(
            title: _tSiteOps(context, 'New incident created'),
            at: incidentAt,
            icon: Icons.warning_rounded,
            color: Colors.orange,
          ),
        );
      }

      QuerySnapshot<Map<String, dynamic>> opsEventSnap;
      try {
        opsEventSnap = await firestoreService.firestore
            .collection('siteOpsEvents')
            .where('siteId', isEqualTo: resolvedSiteId)
            .orderBy('createdAt', descending: true)
            .limit(100)
            .get();
      } catch (_) {
        opsEventSnap = await firestoreService.firestore
            .collection('siteOpsEvents')
            .where('siteId', isEqualTo: resolvedSiteId)
            .limit(100)
            .get();
      }

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in opsEventSnap.docs) {
        final Map<String, dynamic> data = doc.data();
        final DateTime? at = _toDateTime(data['createdAt']);
        if (at == null || at.isBefore(dayStart)) continue;
        final String action = (data['action'] as String?) ?? '';
        final ({String title, IconData icon, Color color}) mapped =
          _mapActionToDisplay(action, context);
        activities.add(
          _TimedActivity(
            title: mapped.title,
            at: at,
            icon: mapped.icon,
            color: mapped.color,
          ),
        );
      }

      activities.sort((_TimedActivity a, _TimedActivity b) => b.at.compareTo(a.at));
      final List<_ActivityEntry> recent = activities
          .take(8)
          .map(
            (_TimedActivity item) => _ActivityEntry(
              item.title,
              _formatTime(item.at),
              item.icon,
              item.color,
            ),
          )
          .toList();

      if (!mounted) return;
      setState(() {
        _presentCount = presentLearners.length;
        _pendingPickups = pickupSignals;
        _openIncidents = openIncidents;
        _isDayOpen = _presentCount > 0;
        _recentActivity = recent;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatTime(DateTime dateTime) {
    final int hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final String minute = dateTime.minute.toString().padLeft(2, '0');
    final String period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  ({String title, IconData icon, Color color}) _mapActionToDisplay(
      String action, BuildContext context) {
    switch (action) {
      case 'Check-in':
        return (
          title: _tSiteOps(context, 'Manual check-in recorded'),
          icon: Icons.login_rounded,
          color: Colors.green,
        );
      case 'Check-out':
        return (
          title: _tSiteOps(context, 'Manual check-out recorded'),
          icon: Icons.logout_rounded,
          color: Colors.blue,
        );
      case 'View Roster':
        return (
          title: _tSiteOps(context, 'Roster viewed'),
          icon: Icons.list_alt_rounded,
          color: ScholesaColors.primary,
        );
      default:
        return (
          title: action,
          icon: Icons.info_outline,
          color: ScholesaColors.textSecondary,
        );
    }
  }

  Widget _buildActivityItem(
      String title, String time, IconData icon, Color color) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(_tSiteOps(context, title)),
      trailing: Text(
        time,
        style: const TextStyle(
          fontSize: 12,
          color: ScholesaColors.textSecondary,
        ),
      ),
    );
  }
}

class _ActivityEntry {
  const _ActivityEntry(this.title, this.time, this.icon, this.color);

  final String title;
  final String time;
  final IconData icon;
  final Color color;
}

class _TimedActivity {
  const _TimedActivity({
    required this.title,
    required this.at,
    required this.icon,
    required this.color,
  });

  final String title;
  final DateTime at;
  final IconData icon;
  final Color color;
}
