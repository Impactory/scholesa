import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';
import '../../i18n/parent_surface_i18n.dart';
import 'parent_models.dart';
import 'parent_service.dart';

class ParentChildPage extends StatefulWidget {
  const ParentChildPage({
    super.key,
    required this.learnerId,
  });

  final String learnerId;

  @override
  State<ParentChildPage> createState() => _ParentChildPageState();
}

class _ParentChildPageState extends State<ParentChildPage> {
  String _t(String input) => ParentSurfaceI18n.text(context, input);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final ParentService service = context.read<ParentService>();
      if (service.learnerSummaries.isEmpty && !service.isLoading) {
        service.loadParentData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ParentService>(
      builder: (BuildContext context, ParentService service, _) {
        final LearnerSummary? learner = service.learnerSummaries
            .where((LearnerSummary item) => item.learnerId == widget.learnerId)
            .cast<LearnerSummary?>()
            .firstWhere(
              (LearnerSummary? item) => item != null,
              orElse: () => null,
            );

        return Scaffold(
          backgroundColor: ScholesaColors.background,
          appBar: AppBar(
            title: Text(_t('Child Detail')),
            backgroundColor: ScholesaColors.parent,
            foregroundColor: Colors.white,
            actions: <Widget>[
              TextButton.icon(
                onPressed: () {
                  TelemetryService.instance.logEvent(
                    event: 'cta.clicked',
                    metadata: <String, dynamic>{
                      'cta': 'parent_child_view_consent',
                      'learner_id': widget.learnerId,
                    },
                  );
                  context.go('/parent/consent');
                },
                icon: const Icon(Icons.verified_user_outlined),
                label: Text(_t('View Consent')),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
              ),
            ],
          ),
          body: _buildBody(service: service, learner: learner),
        );
      },
    );
  }

  Widget _buildBody({
    required ParentService service,
    required LearnerSummary? learner,
  }) {
    if (service.isLoading && learner == null) {
      return Center(
        child: Text(
          _t('Loading...'),
          style: const TextStyle(color: ScholesaColors.textSecondary),
        ),
      );
    }

    if (service.error != null && learner == null) {
      return _buildMessageState(
        title: _t('Unable to load learner details right now'),
        body: service.error!,
        actionLabel: _t('Retry'),
        onPressed: service.loadParentData,
      );
    }

    if (learner == null) {
      return _buildMessageState(
        title: _t('This learner is not linked to your account right now.'),
        body: _t(
          'Ask your site admin to confirm the guardian link before trying again.',
        ),
        actionLabel: _t('Open Family Dashboard'),
        onPressed: () => context.go('/parent/summary'),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _buildHeroCard(learner),
        const SizedBox(height: 16),
        _buildSnapshotGrid(learner),
        const SizedBox(height: 16),
        _buildPillarSection(learner),
        const SizedBox(height: 16),
        _buildActivitySection(learner),
        const SizedBox(height: 16),
        _buildUpcomingSection(learner),
      ],
    );
  }

  Widget _buildMessageState({
    required String title,
    required String body,
    required String actionLabel,
    required VoidCallback onPressed,
  }) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        Card(
          color: ScholesaColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: ScholesaColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: const TextStyle(color: ScholesaColors.textSecondary),
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: onPressed,
                  child: Text(actionLabel),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(LearnerSummary learner) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            ScholesaColors.parent,
            ScholesaColors.parent.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: ScholesaColors.parent.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _safeLearnerName(learner.learnerName),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${learner.totalXp} ${_t('XP earned')}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _buildHeroStat(
                label: _t('Level'),
                value: '${learner.currentLevel}',
              ),
              _buildHeroStat(
                label: _t('Missions'),
                value: '${learner.missionsCompleted}',
              ),
              _buildHeroStat(
                label: _t('Attendance'),
                value: '${(learner.attendanceRate * 100).round()}%',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat({
    required String label,
    required String value,
  }) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSnapshotGrid(LearnerSummary learner) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        _buildSnapshotCard(
          label: _t('Capability Band'),
          value: _titleCase(learner.capabilitySnapshot.band),
        ),
        _buildSnapshotCard(
          label: _t('Portfolio Items'),
          value: '${learner.portfolioSnapshot.artifactCount}',
        ),
        _buildSnapshotCard(
          label: _t('Reflections Submitted'),
          value: '${learner.ideationPassport.reflectionsSubmitted}',
        ),
        _buildSnapshotCard(
          label: _t('Upcoming'),
          value: '${learner.upcomingEvents.length}',
        ),
      ],
    );
  }

  Widget _buildSnapshotCard({
    required String label,
    required String value,
  }) {
    return SizedBox(
      width: 180,
      child: Card(
        color: ScholesaColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: ScholesaColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(color: ScholesaColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPillarSection(LearnerSummary learner) {
    return _buildSectionCard(
      title: _t('Learning Pillars'),
      child: Column(
        children: <Widget>[
          _buildPillarRow(
            label: _t('Future Skills'),
            value: learner.pillarProgress['futureSkills'] ?? 0,
            color: const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 12),
          _buildPillarRow(
            label: _t('Leadership & Agency'),
            value: learner.pillarProgress['leadership'] ?? 0,
            color: const Color(0xFF8B5CF6),
          ),
          const SizedBox(height: 12),
          _buildPillarRow(
            label: _t('Impact & Innovation'),
            value: learner.pillarProgress['impact'] ?? 0,
            color: const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }

  Widget _buildPillarRow({
    required String label,
    required double value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(label)),
            Text(
              '${(value * 100).round()}%',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildActivitySection(LearnerSummary learner) {
    if (learner.recentActivities.isEmpty) {
      return _buildSectionCard(
        title: _t('Recent Activity'),
        child: Text(
          _t('No recent activity yet'),
          style: const TextStyle(color: ScholesaColors.textSecondary),
        ),
      );
    }

    return _buildSectionCard(
      title: _t('Recent Activity'),
      child: Column(
        children: learner.recentActivities
            .map(
              (RecentActivity activity) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor:
                      ScholesaColors.parent.withValues(alpha: 0.12),
                  child: Text(activity.emoji),
                ),
                title: Text(activity.title),
                subtitle: Text(activity.description),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _buildUpcomingSection(LearnerSummary learner) {
    if (learner.upcomingEvents.isEmpty) {
      return _buildSectionCard(
        title: _t('Upcoming'),
        child: Text(
          _t('No upcoming events yet'),
          style: const TextStyle(color: ScholesaColors.textSecondary),
        ),
      );
    }

    return _buildSectionCard(
      title: _t('Upcoming'),
      child: Column(
        children: learner.upcomingEvents
            .map(
              (UpcomingEvent event) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.event_rounded,
                  color: ScholesaColors.parent,
                ),
                title: Text(event.title),
                subtitle: Text(
                  event.location?.trim().isNotEmpty == true
                      ? '${event.description ?? ''}\n${_t('Location')}: ${event.location}'
                      : event.description ?? '',
                ),
                isThreeLine: event.location?.trim().isNotEmpty == true,
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required Widget child,
  }) {
    return Card(
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: ScholesaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  String _safeLearnerName(String learnerName) {
    final String normalized = learnerName.trim();
    if (normalized.isEmpty || normalized == 'Unknown') {
      return _t('Learner unavailable');
    }
    return normalized;
  }

  String _titleCase(String value) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      return normalized;
    }
    return normalized
        .split(RegExp(r'[_\s]+'))
        .map((String part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
        .join(' ');
  }
}
