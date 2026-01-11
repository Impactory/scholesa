import 'package:flutter/material.dart';
import '../../ui/theme/scholesa_theme.dart';

/// HQ Analytics Page - Platform-wide analytics and insights
class HqAnalyticsPage extends StatefulWidget {
  const HqAnalyticsPage({super.key});

  @override
  State<HqAnalyticsPage> createState() => _HqAnalyticsPageState();
}

class _HqAnalyticsPageState extends State<HqAnalyticsPage> {
  String _selectedPeriod = 'month';
  String _selectedSite = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              ScholesaColors.hq.withOpacity(0.05),
              Colors.white,
              ScholesaColors.futureSkills.withOpacity(0.03),
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildFilters()),
            SliverToBoxAdapter(child: _buildKeyMetrics()),
            SliverToBoxAdapter(child: _buildGrowthChart()),
            SliverToBoxAdapter(child: _buildPillarAnalytics()),
            SliverToBoxAdapter(child: _buildSiteComparison()),
            SliverToBoxAdapter(child: _buildTopPerformers()),
            const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
          ],
        ),
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
                gradient: ScholesaColors.hqGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: ScholesaColors.hq.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.insights, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Platform Analytics',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: ScholesaColors.hq,
                        ),
                  ),
                  Text(
                    'Comprehensive performance insights',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _exportReport,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ScholesaColors.hq.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.download, color: ScholesaColors.hq),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: DropdownButton<String>(
                value: _selectedSite,
                isExpanded: true,
                underline: const SizedBox(),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(value: 'all', child: Text('All Sites')),
                  DropdownMenuItem<String>(value: 'sg', child: Text('Singapore')),
                  DropdownMenuItem<String>(value: 'kl', child: Text('Kuala Lumpur')),
                  DropdownMenuItem<String>(value: 'jkt', child: Text('Jakarta')),
                ],
                onChanged: (String? value) {
                  if (value != null) setState(() => _selectedSite = value);
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: DropdownButton<String>(
                value: _selectedPeriod,
                isExpanded: true,
                underline: const SizedBox(),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(value: 'week', child: Text('This Week')),
                  DropdownMenuItem<String>(value: 'month', child: Text('This Month')),
                  DropdownMenuItem<String>(value: 'quarter', child: Text('This Quarter')),
                  DropdownMenuItem<String>(value: 'year', child: Text('This Year')),
                ],
                onChanged: (String? value) {
                  if (value != null) setState(() => _selectedPeriod = value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyMetrics() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Key Performance Indicators',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricCard(
                  icon: Icons.people,
                  value: '147',
                  label: 'Total Learners',
                  trend: '+12%',
                  trendUp: true,
                  color: ScholesaColors.learner,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  icon: Icons.rocket_launch,
                  value: '456',
                  label: 'Missions Done',
                  trend: '+23%',
                  trendUp: true,
                  color: ScholesaColors.futureSkills,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricCard(
                  icon: Icons.event_available,
                  value: '91%',
                  label: 'Avg Attendance',
                  trend: '+2%',
                  trendUp: true,
                  color: ScholesaColors.success,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  icon: Icons.trending_up,
                  value: '78%',
                  label: 'Engagement',
                  trend: '-3%',
                  trendUp: false,
                  color: ScholesaColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthChart() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Text(
                  'Learner Growth',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: ScholesaColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: <Widget>[
                      Icon(Icons.trending_up, size: 16, color: ScholesaColors.success),
                      SizedBox(width: 4),
                      Text(
                        '+18 this month',
                        style: TextStyle(
                          color: ScholesaColors.success,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const SizedBox(
              height: 150,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  _BarColumn(label: 'Jan', value: 0.45, color: ScholesaColors.hq),
                  _BarColumn(label: 'Feb', value: 0.52, color: ScholesaColors.hq),
                  _BarColumn(label: 'Mar', value: 0.61, color: ScholesaColors.hq),
                  _BarColumn(label: 'Apr', value: 0.58, color: ScholesaColors.hq),
                  _BarColumn(label: 'May', value: 0.75, color: ScholesaColors.hq),
                  _BarColumn(label: 'Jun', value: 0.89, color: ScholesaColors.hq),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillarAnalytics() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Pillar Performance',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 20),
            _PillarAnalyticsRow(
              icon: Icons.code,
              label: 'Future Skills',
              progress: 0.72,
              learners: 98,
              missions: 234,
              color: ScholesaColors.futureSkills,
            ),
            SizedBox(height: 16),
            _PillarAnalyticsRow(
              icon: Icons.emoji_events,
              label: 'Leadership',
              progress: 0.65,
              learners: 85,
              missions: 156,
              color: ScholesaColors.leadership,
            ),
            SizedBox(height: 16),
            _PillarAnalyticsRow(
              icon: Icons.eco,
              label: 'Impact',
              progress: 0.58,
              learners: 72,
              missions: 112,
              color: ScholesaColors.impact,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSiteComparison() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Site Comparison',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Column(
              children: <Widget>[
                _SiteComparisonRow(
                  name: 'Singapore',
                  learners: 47,
                  attendance: 94,
                  engagement: 82,
                ),
                Divider(),
                _SiteComparisonRow(
                  name: 'Kuala Lumpur',
                  learners: 62,
                  attendance: 88,
                  engagement: 76,
                ),
                Divider(),
                _SiteComparisonRow(
                  name: 'Jakarta',
                  learners: 38,
                  attendance: 85,
                  engagement: 71,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopPerformers() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                'Top Performers',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const _TopPerformerCard(
            rank: 1,
            name: 'Emma Johnson',
            site: 'Singapore',
            missionsCompleted: 28,
            streak: 15,
          ),
          const _TopPerformerCard(
            rank: 2,
            name: 'Liam Chen',
            site: 'Kuala Lumpur',
            missionsCompleted: 24,
            streak: 12,
          ),
          const _TopPerformerCard(
            rank: 3,
            name: 'Sofia Martinez',
            site: 'Singapore',
            missionsCompleted: 22,
            streak: 18,
          ),
        ],
      ),
    );
  }

  void _exportReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Report export feature coming soon'),
        backgroundColor: ScholesaColors.hq,
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {

  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.trend,
    required this.trendUp,
    required this.color,
  });
  final IconData icon;
  final String value;
  final String label;
  final String trend;
  final bool trendUp;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: trendUp
                      ? ScholesaColors.success.withOpacity(0.1)
                      : ScholesaColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      trendUp ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 10,
                      color: trendUp ? ScholesaColors.success : ScholesaColors.error,
                    ),
                    Text(
                      trend,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: trendUp ? ScholesaColors.success : ScholesaColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _BarColumn extends StatelessWidget {

  const _BarColumn({required this.label, required this.value, required this.color});
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        Container(
          width: 32,
          height: 100 * value,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }
}

class _PillarAnalyticsRow extends StatelessWidget {

  const _PillarAnalyticsRow({
    required this.icon,
    required this.label,
    required this.progress,
    required this.learners,
    required this.missions,
    required this.color,
  });
  final IconData icon;
  final String label;
  final double progress;
  final int learners;
  final int missions;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: color.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              '$learners',
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              'learners',
              style: TextStyle(color: Colors.grey[500], fontSize: 10),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              '$missions',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'missions',
              style: TextStyle(color: Colors.grey[500], fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }
}

class _SiteComparisonRow extends StatelessWidget {

  const _SiteComparisonRow({
    required this.name,
    required this.learners,
    required this.attendance,
    required this.engagement,
  });
  final String name;
  final int learners;
  final int attendance;
  final int engagement;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 2,
            child: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                Text(
                  '$learners',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Learners',
                  style: TextStyle(color: Colors.grey[500], fontSize: 10),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                Text(
                  '$attendance%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ScholesaColors.success,
                  ),
                ),
                Text(
                  'Attendance',
                  style: TextStyle(color: Colors.grey[500], fontSize: 10),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                Text(
                  '$engagement%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: engagement >= 80
                        ? ScholesaColors.success
                        : ScholesaColors.warning,
                  ),
                ),
                Text(
                  'Engage',
                  style: TextStyle(color: Colors.grey[500], fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopPerformerCard extends StatelessWidget {

  const _TopPerformerCard({
    required this.rank,
    required this.name,
    required this.site,
    required this.missionsCompleted,
    required this.streak,
  });
  final int rank;
  final String name;
  final String site;
  final int missionsCompleted;
  final int streak;

  Color get _rankColor {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700);
      case 2:
        return const Color(0xFFC0C0C0);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _rankColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _rankColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    site,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.rocket_launch,
                        size: 14, color: ScholesaColors.futureSkills),
                    const SizedBox(width: 4),
                    Text(
                      '$missionsCompleted',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Row(
                  children: <Widget>[
                    const Icon(Icons.local_fire_department,
                        size: 14, color: ScholesaColors.warning),
                    const SizedBox(width: 4),
                    Text(
                      '$streak days',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
