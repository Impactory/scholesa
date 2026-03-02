import 'package:flutter/material.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';

const Map<String, String> _siteOpsEs = <String, String>{
  'Today Operations': 'Operaciones de hoy',
  'Day opened': 'Día abierto',
  'Day closed': 'Día cerrado',
  'Site is OPEN': 'El sitio está ABIERTO',
  'Site is CLOSED': 'El sitio está CERRADO',
  'Check-ins and operations active': 'Registros y operaciones activas',
  'Toggle switch to open the day': 'Activa el interruptor para abrir el día',
  'Present': 'Presentes',
  'Pickups': 'Recogidas',
  'Incidents': 'Incidentes',
  'Quick Actions': 'Acciones rápidas',
  'Check-in': 'Registro entrada',
  'Check-out': 'Registro salida',
  'New Incident': 'Nuevo incidente',
  'View Roster': 'Ver lista',
  'Recent Activity': 'Actividad reciente',
  'Manual check-in recorded': 'Registro manual de entrada realizado',
  'Manual check-out recorded': 'Registro manual de salida realizado',
  'New incident created': 'Nuevo incidente creado',
  'Roster viewed': 'Lista visualizada',
  'completed': 'completado',
  'Emma S. checked in': 'Emma S. registró entrada',
  'Oliver T. checked in': 'Oliver T. registró entrada',
  'Minor incident reported': 'Incidente menor reportado',
  'Sophia M. picked up': 'Sophia M. fue recogida',
};

String _tSiteOps(BuildContext context, String input) {
  final String locale = Localizations.localeOf(context).languageCode;
  if (locale != 'es') return input;
  return _siteOpsEs[input] ?? input;
}

/// Site operations page for daily operations overview
/// Based on docs/42_PHYSICAL_SITE_CHECKIN_CHECKOUT_SPEC.md
class SiteOpsPage extends StatefulWidget {
  const SiteOpsPage({super.key});

  @override
  State<SiteOpsPage> createState() => _SiteOpsPageState();
}

class _SiteOpsPageState extends State<SiteOpsPage> {
  bool _isDayOpen = true;
  int _presentCount = 24;
  int _pendingPickups = 5;
  int _openIncidents = 2;
  final List<_ActivityEntry> _recentActivity = <_ActivityEntry>[
    const _ActivityEntry(
        'Emma S. checked in', '9:02 AM', Icons.login_rounded, Colors.green),
    const _ActivityEntry(
        'Oliver T. checked in', '9:05 AM', Icons.login_rounded, Colors.green),
    const _ActivityEntry('Minor incident reported', '9:15 AM',
        Icons.warning_rounded, Colors.orange),
    const _ActivityEntry(
        'Sophia M. picked up', '3:30 PM', Icons.logout_rounded, Colors.blue),
  ];

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
          child: Column(
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

  void _handleQuickAction(String label) {
    setState(() {
      switch (label) {
        case 'Check-in':
          _presentCount += 1;
          _addRecentActivity(
              _tSiteOps(context, 'Manual check-in recorded'), Icons.login_rounded, Colors.green);
          break;
        case 'Check-out':
          if (_presentCount > 0) _presentCount -= 1;
          if (_pendingPickups > 0) _pendingPickups -= 1;
          _addRecentActivity(
              _tSiteOps(context, 'Manual check-out recorded'), Icons.logout_rounded, Colors.blue);
          break;
        case 'New Incident':
          _openIncidents += 1;
          _addRecentActivity(
              _tSiteOps(context, 'New incident created'), Icons.warning_rounded, Colors.orange);
          break;
        case 'View Roster':
          _addRecentActivity(
              _tSiteOps(context, 'Roster viewed'), Icons.list_alt_rounded, ScholesaColors.primary);
          break;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label ${_tSiteOps(context, 'completed')}')),
    );
  }

  void _addRecentActivity(String title, IconData icon, Color color) {
    _recentActivity.insert(0, _ActivityEntry(title, _nowLabel(), icon, color));
    if (_recentActivity.length > 8) {
      _recentActivity.removeLast();
    }
  }

  String _nowLabel() {
    final DateTime now = DateTime.now();
    final int hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final String minute = now.minute.toString().padLeft(2, '0');
    final String period = now.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
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
