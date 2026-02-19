import 'package:flutter/material.dart';
import '../../ui/theme/scholesa_theme.dart';

/// Site operations page for daily operations overview
/// Based on docs/42_PHYSICAL_SITE_CHECKIN_CHECKOUT_SPEC.md
class SiteOpsPage extends StatefulWidget {
  const SiteOpsPage({super.key});

  @override
  State<SiteOpsPage> createState() => _SiteOpsPageState();
}

class _SiteOpsPageState extends State<SiteOpsPage> {
  bool _isDayOpen = true;
  final int _presentCount = 24;
  final int _pendingPickups = 5;
  final int _openIncidents = 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: const Text('Today Operations'),
        backgroundColor: ScholesaColors.siteGradient.colors.first,
        foregroundColor: Colors.white,
        actions: <Widget>[
          Switch(
            value: _isDayOpen,
            onChanged: (bool value) {
              setState(() => _isDayOpen = value);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(value ? 'Day opened' : 'Day closed'),
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
            ? const LinearGradient(colors: <Color>[Color(0xFF22C55E), Color(0xFF4ADE80)])
            : const LinearGradient(colors: <Color>[Color(0xFFF59E0B), Color(0xFFFBBF24)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: (_isDayOpen ? Colors.green : Colors.orange).withValues(alpha: 0.3),
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
              _isDayOpen ? Icons.door_front_door_rounded : Icons.door_sliding_rounded,
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
                  _isDayOpen ? 'Site is OPEN' : 'Site is CLOSED',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isDayOpen
                      ? 'Check-ins and operations active'
                      : 'Toggle switch to open the day',
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
        Expanded(child: _buildStatCard('Present', _presentCount.toString(), Icons.people_rounded, Colors.green)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Pickups', _pendingPickups.toString(), Icons.directions_walk_rounded, Colors.blue)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Incidents', _openIncidents.toString(), Icons.warning_rounded, Colors.orange)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
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
        const Text(
          'Quick Actions',
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
            _buildActionButton('Check-in', Icons.login_rounded, '/site/checkin'),
            _buildActionButton('Check-out', Icons.logout_rounded, '/site/checkin'),
            _buildActionButton('New Incident', Icons.add_alert_rounded, '/site/incidents'),
            _buildActionButton('View Roster', Icons.list_alt_rounded, '/site/sessions'),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Navigating to $label...')),
          );
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
                  label,
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
        const Text(
          'Recent Activity',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: ScholesaColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: ScholesaColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: <Widget>[
              _buildActivityItem('Emma S. checked in', '9:02 AM', Icons.login_rounded, Colors.green),
              const Divider(height: 1),
              _buildActivityItem('Oliver T. checked in', '9:05 AM', Icons.login_rounded, Colors.green),
              const Divider(height: 1),
              _buildActivityItem('Minor incident reported', '9:15 AM', Icons.warning_rounded, Colors.orange),
              const Divider(height: 1),
              _buildActivityItem('Sophia M. picked up', '3:30 PM', Icons.logout_rounded, Colors.blue),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(String title, String time, IconData icon, Color color) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title),
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
