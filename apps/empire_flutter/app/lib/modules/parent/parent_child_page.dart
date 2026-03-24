import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../auth/app_state.dart';
import '../../services/export_service.dart';
import '../../services/firestore_service.dart';
import '../../services/telemetry_service.dart';
import '../../ui/auth/global_session_menu.dart';
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
  bool _pendingInitialLoad = false;

  String _t(String input) => ParentSurfaceI18n.text(context, input);

  FirestoreService? _maybeFirestoreService() {
    try {
      return context.read<ParentService>().firestoreService;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    final ParentService service = context.read<ParentService>();
    _pendingInitialLoad =
        service.learnerSummaries.isEmpty && !service.isLoading;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_pendingInitialLoad) {
        setState(() {
          _pendingInitialLoad = false;
        });
      }
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

        final List<Widget> appBarActions = <Widget>[
          IconButton(
            onPressed: service.loadParentData,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: _t('Refresh'),
          ),
          TextButton.icon(
            onPressed: learner == null ? null : () => _exportPassport(learner),
            icon: const Icon(Icons.download_rounded),
            label: Text(_t('Export Passport')),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
          ),
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
          const SessionMenuButton(
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
        ];

        return Scaffold(
          backgroundColor: ScholesaColors.background,
          appBar: AppBar(
            toolbarHeight: 64,
            title: Text(_t('Child Detail')),
            backgroundColor: ScholesaColors.parent,
            foregroundColor: Colors.white,
            actions: appBarActions,
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
    if ((service.isLoading || _pendingInitialLoad) && learner == null) {
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
        body: _t(
          'We could not load this learner right now. Retry to check the current state.',
        ),
        actionLabel: _t('Retry'),
        onPressed: service.loadParentData,
      );
    }

    if (learner == null) {
      return _buildMessageState(
        title: _t('This learner is not linked to your account right now.'),
        body: _t(
          'Request a linking review and we will check this learner connection for your family account.',
        ),
        actionLabel: _t('Request Linking Review'),
        onPressed: _submitLinkedLearnerReviewRequest,
        secondaryActionLabel: _t('Open Family Dashboard'),
        onSecondaryPressed: () => context.go('/parent/summary'),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        if (service.error != null) ...<Widget>[
          _buildStaleDataBanner(),
          const SizedBox(height: 16),
        ],
        _buildHeroCard(learner),
        const SizedBox(height: 16),
        _buildSnapshotGrid(learner),
        const SizedBox(height: 16),
        _buildPassportSection(learner),
        const SizedBox(height: 16),
        _buildPillarSection(learner),
        const SizedBox(height: 16),
        _buildActivitySection(learner),
        const SizedBox(height: 16),
        _buildUpcomingSection(learner),
      ],
    );
  }

  Widget _buildStaleDataBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _t(
                'Unable to refresh learner details right now. Showing the last successful data.',
              ),
              style: const TextStyle(color: ScholesaColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageState({
    required String title,
    required String body,
    required String actionLabel,
    required VoidCallback onPressed,
    String? secondaryActionLabel,
    VoidCallback? onSecondaryPressed,
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
                if (secondaryActionLabel != null && onSecondaryPressed != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: OutlinedButton(
                      onPressed: onSecondaryPressed,
                      child: Text(secondaryActionLabel),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submitLinkedLearnerReviewRequest() async {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{
        'cta': 'parent_child_request_linked_learner_review',
      },
    );

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final FirestoreService? firestoreService = _maybeFirestoreService();
    if (firestoreService == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(_t('Support requests are unavailable right now.')),
        ),
      );
      return;
    }

    final AppState appState = context.read<AppState>();
    try {
      final String requestId = await firestoreService.submitSupportRequest(
        requestType: 'parent_linked_learner_review',
        source: 'parent_child_request_linked_learner_review',
        siteId: appState.activeSiteId?.trim().isNotEmpty == true
            ? appState.activeSiteId!.trim()
            : 'Not set',
        userId: appState.userId?.trim().isNotEmpty == true
            ? appState.userId!.trim()
            : 'Not set',
        userEmail: appState.email?.trim().isNotEmpty == true
            ? appState.email!.trim()
            : 'Not set',
        userName: appState.displayName?.trim().isNotEmpty == true
            ? appState.displayName!.trim()
            : 'Not set',
        role: appState.role?.name ?? 'unknown',
        subject: 'Parent guardian link review request',
        message:
            'Please review the guardian link for the requested learner detail route.',
        metadata: <String, dynamic>{
          'requestedLearnerId': widget.learnerId,
          'activeSiteId': appState.activeSiteId,
        },
      );
      TelemetryService.instance.logEvent(
        event: 'parent.linked_learner_review.submitted',
        metadata: <String, dynamic>{
          'request_id': requestId,
          'requested_learner_id': widget.learnerId,
        },
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(_t('Linked learner review request submitted.')),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content:
              Text(_t('Unable to submit linked learner review right now.')),
        ),
      );
    }
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
            '${learner.evidenceSummary.reviewedCount} ${_t('reviewed evidence records')} • ${learner.portfolioSnapshot.verifiedArtifactCount} ${_t('reviewed or verified artifacts')}',
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
                label: _t('Capabilities Updated'),
                value: '${learner.growthSummary.updatedCapabilityCount}',
              ),
              _buildHeroStat(
                label: _t('Reviewed/Verified Artifacts'),
                value: '${learner.portfolioSnapshot.verifiedArtifactCount}',
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
          label: _t('Reviewed Evidence'),
          value: '${learner.evidenceSummary.reviewedCount}',
        ),
        _buildSnapshotCard(
          label: _t('Reviewed/Verified Artifacts'),
          value: '${learner.portfolioSnapshot.verifiedArtifactCount}',
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

  Widget _buildPassportSection(LearnerSummary learner) {
    final IdeationPassport passport = learner.ideationPassport;
    if (passport.claims.isEmpty) {
      return _buildSectionCard(
        title: _t('Ideation Passport'),
        child: Text(
          _t('No capability claims are ready for Passport view yet.'),
          style: const TextStyle(color: ScholesaColors.textSecondary),
        ),
      );
    }

    return _buildSectionCard(
      title: _t('Ideation Passport'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            passport.summary ??
                _t('Capability claims built from currently linked evidence and reviewed artifacts.'),
            style: const TextStyle(color: ScholesaColors.textSecondary),
          ),
          const SizedBox(height: 12),
          ...passport.claims.take(3).map(
                (PassportClaim claim) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ScholesaColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ScholesaColors.parent.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        claim.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: ScholesaColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_t(claim.pillar)} • ${_t('Level')} ${claim.latestLevel}/4',
                        style: const TextStyle(
                            color: ScholesaColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${claim.evidenceCount} ${_t('evidence records')} • ${claim.verifiedArtifactCount} ${_t('reviewed or verified artifacts')}',
                        style: const TextStyle(
                            color: ScholesaColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_t('Proof of Learning')}: ${_titleCase(claim.proofOfLearningStatus ?? 'missing')} • ${_t('AI Disclosure')}: ${_formatAiDisclosure(claim.aiDisclosureStatus)}',
                        style: const TextStyle(
                          color: ScholesaColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      if (_buildProofDetail(claim).isNotEmpty) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          _buildProofDetail(claim),
                          style: const TextStyle(
                            color: ScholesaColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (_buildAiDetail(claim).isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          _buildAiDetail(claim),
                          style: const TextStyle(
                            color: ScholesaColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (_buildReviewDetail(claim).isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          _buildReviewDetail(claim),
                          style: const TextStyle(
                            color: ScholesaColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (_buildVerificationCriteriaDetail(claim)
                          .isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          '${_t('Verification Criteria')}: ${_buildVerificationCriteriaDetail(claim)}',
                          style: const TextStyle(
                            color: ScholesaColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (_buildProgressionDescriptorsDetail(claim)
                          .isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          '${_t('Progression Descriptors')}: ${_buildProgressionDescriptorsDetail(claim)}',
                          style: const TextStyle(
                            color: ScholesaColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (claim.evidenceRecordIds.isNotEmpty ||
                          claim.portfolioItemIds.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          '${_t('Evidence IDs')}: ${claim.evidenceRecordIds.take(2).join(', ')}${claim.evidenceRecordIds.length > 2 ? '…' : ''}',
                          style: const TextStyle(
                            color: ScholesaColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _exportPassport(LearnerSummary learner) async {
    final String content = _buildPassportExport(learner);
    final String fileName = 'ideation-passport-${learner.learnerId}.txt';
    try {
      final String? savedLocation = await ExportService.instance.saveTextFile(
        fileName: fileName,
        content: content,
      );
      if (!mounted || savedLocation == null) {
        return;
      }
      TelemetryService.instance.logEvent(
        event: 'export.downloaded',
        metadata: <String, dynamic>{
          'module': 'parent_child',
          'surface': 'passport_export',
          'learner_id': learner.learnerId,
          'file_name': fileName,
        },
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('Ideation Passport downloaded.')),
        ),
      );
    } on UnsupportedError catch (error) {
      debugPrint(
          'Export unsupported for parent passport download, copying summary instead: $error');
      await Clipboard.setData(ClipboardData(text: content));
      TelemetryService.instance.logEvent(
        event: 'parent.passport_export.copied',
        metadata: <String, dynamic>{
          'learner_id': learner.learnerId,
          'fallback': 'clipboard',
        },
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('Ideation Passport copied for sharing.')),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('Unable to download Ideation Passport right now.')),
          backgroundColor: ScholesaColors.error,
        ),
      );
    }
  }

  String _buildPassportExport(LearnerSummary learner) {
    final IdeationPassport passport = learner.ideationPassport;
    final List<String> lines = <String>[
      _t('Ideation Passport'),
      '${_t('Learner')}: ${_safeLearnerName(learner.learnerName)}',
      '${_t('Generated')}: ${(passport.generatedAt ?? DateTime.now()).toIso8601String()}',
      '${_t('Summary')}: ${passport.summary ?? _t('No passport summary yet.')}',
      '${_t('Reviewed Evidence')}: ${learner.evidenceSummary.reviewedCount}',
      '${_t('Reviewed/Verified Artifacts')}: ${learner.portfolioSnapshot.verifiedArtifactCount}',
      '${_t('Reflections')}: ${passport.reflectionsSubmitted}',
      '',
      _t('Claims'),
    ];

    if (passport.claims.isEmpty) {
      lines.add(_t('No capability claims are ready for export yet.'));
      return lines.join('\n');
    }

    for (final PassportClaim claim in passport.claims) {
      lines.add('- ${claim.title}');
      lines.add('  ${_t('Pillar')}: ${_t(claim.pillar)}');
      lines.add('  ${_t('Level')}: ${claim.latestLevel}/4');
      lines.add('  ${_t('Evidence Count')}: ${claim.evidenceCount}');
      lines.add(
        '  ${_t('Reviewed/Verified Artifacts')}: ${claim.verifiedArtifactCount}',
      );
      lines.add(
        '  ${_t('Artifact Review Status')}: ${claim.verificationStatus?.trim().isNotEmpty == true ? _titleCase(claim.verificationStatus!) : _t('Pending')}',
      );
      lines.add(
        '  ${_t('Proof of Learning')}: ${_titleCase(claim.proofOfLearningStatus ?? 'missing')}',
      );
      if (_buildProofDetail(claim).isNotEmpty) {
        lines.add('  ${_t('Proof Detail')}: ${_buildProofDetail(claim)}');
      }
      lines.add(
        '  ${_t('AI Disclosure')}: ${_formatAiDisclosure(claim.aiDisclosureStatus)}',
      );
      if (_buildAiDetail(claim).isNotEmpty) {
        lines.add('  ${_t('AI Detail')}: ${_buildAiDetail(claim)}');
      }
      if (_buildReviewDetail(claim).isNotEmpty) {
        lines.add('  ${_t('Review Detail')}: ${_buildReviewDetail(claim)}');
      }
      if (_buildVerificationCriteriaDetail(claim).isNotEmpty) {
        lines.add(
            '  ${_t('Verification Criteria')}: ${_buildVerificationCriteriaDetail(claim)}');
      }
      if (_buildProgressionDescriptorsDetail(claim).isNotEmpty) {
        lines.add(
            '  ${_t('Progression Descriptors')}: ${_buildProgressionDescriptorsDetail(claim)}');
      }
      if (claim.latestEvidenceAt != null) {
        lines.add(
          '  ${_t('Latest Evidence At')}: ${claim.latestEvidenceAt!.toIso8601String()}',
        );
      }
      if (claim.evidenceRecordIds.isNotEmpty) {
        lines.add(
          '  ${_t('Evidence IDs')}: ${claim.evidenceRecordIds.join(', ')}',
        );
      }
      if (claim.portfolioItemIds.isNotEmpty) {
        lines.add(
          '  ${_t('Portfolio Item IDs')}: ${claim.portfolioItemIds.join(', ')}',
        );
      }
      if (claim.missionAttemptIds.isNotEmpty) {
        lines.add(
          '  ${_t('Mission Attempt IDs')}: ${claim.missionAttemptIds.join(', ')}',
        );
      }
      lines.add('');
    }

    return lines.join('\n');
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
                title: Text(
                  activity.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  activity.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                isThreeLine: true,
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
                title: Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  event.location?.trim().isNotEmpty == true
                      ? '${event.description ?? ''}\n${_t('Location')}: ${event.location}'
                      : event.description ?? '',
                  maxLines: event.location?.trim().isNotEmpty == true ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
                isThreeLine: true,
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

  String _buildProofDetail(PassportClaim claim) {
    if (!claim.proofHasExplainItBack &&
        !claim.proofHasOralCheck &&
        !claim.proofHasMiniRebuild &&
        claim.proofCheckpoints.isEmpty) {
      return '';
    }
    return <String>[
      '${_t('Explain-it-back')}: ${claim.proofHasExplainItBack ? _t('Yes') : _t('No')}',
      '${_t('Oral check')}: ${claim.proofHasOralCheck ? _t('Yes') : _t('No')}',
      '${_t('Mini-rebuild')}: ${claim.proofHasMiniRebuild ? _t('Yes') : _t('No')}',
      if (claim.proofCheckpointCount > 0)
        '${_t('Version checkpoints')}: ${claim.proofCheckpointCount}',
      if (claim.proofExplainItBackExcerpt?.trim().isNotEmpty == true)
        '${_t('Explain-it-back note')}: ${claim.proofExplainItBackExcerpt}',
      if (claim.proofOralCheckExcerpt?.trim().isNotEmpty == true)
        '${_t('Oral check note')}: ${claim.proofOralCheckExcerpt}',
      if (claim.proofMiniRebuildExcerpt?.trim().isNotEmpty == true)
        '${_t('Mini-rebuild note')}: ${claim.proofMiniRebuildExcerpt}',
      ...claim.proofCheckpoints.map(_formatCheckpointLine),
    ].join(' • ');
  }

  String _formatCheckpointLine(ProofCheckpointPreview checkpoint) {
    final List<String> parts = <String>[];
    if (checkpoint.createdAt != null) {
      final DateTime value = checkpoint.createdAt!;
      parts.add(
          '${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}/${value.year}');
    }
    if (checkpoint.actorRole?.trim().isNotEmpty == true) {
      parts.add('${_t('actor')}: ${_titleCase(checkpoint.actorRole!)}');
    }
    if (checkpoint.summary.trim().isNotEmpty) {
      parts.add(checkpoint.summary.trim());
    }
    if (checkpoint.artifactNote?.trim().isNotEmpty == true) {
      parts.add('${_t('artifact note')}: ${checkpoint.artifactNote}');
    }
    return '${_t('Checkpoint')}: ${parts.join(' - ')}';
  }

  String _buildAiDetail(PassportClaim claim) {
    final bool hasAnyAiDetail = claim.aiHasLearnerDisclosure ||
        claim.aiHelpEventCount > 0 ||
        claim.aiHasEducatorAiFeedback ||
        claim.aiHasExplainItBackEvidence;
    if (!hasAnyAiDetail) {
      return '';
    }
    return <String>[
      '${_t('Learner disclosure')}: ${claim.aiHasLearnerDisclosure ? _t('Present') : _t('Not recorded')}',
      '${_t('Learner said AI used')}: ${claim.aiLearnerDeclaredUsed ? _t('Yes') : _t('No')}',
      '${_t('Explain-it-back evidence')}: ${claim.aiHasExplainItBackEvidence ? _t('Yes') : _t('No')}',
      '${_t('AI help events')}: ${claim.aiHelpEventCount}',
      if (claim.aiHasEducatorAiFeedback)
        '${_t('Educator AI feedback')}: ${_t('Present')}',
      if (claim.aiFeedbackEducatorName?.trim().isNotEmpty == true)
        '${_t('AI feedback by')}: ${claim.aiFeedbackEducatorName}',
      if (claim.aiFeedbackAt != null)
        '${_t('AI feedback date')}: ${claim.aiFeedbackAt!.month.toString().padLeft(2, '0')}/${claim.aiFeedbackAt!.day.toString().padLeft(2, '0')}/${claim.aiFeedbackAt!.year}',
      if (claim.aiAssistanceDetails?.trim().isNotEmpty == true)
        '${_t('Learner AI details')}: ${claim.aiAssistanceDetails}',
    ].join(' • ');
  }

  String _buildVerificationCriteriaDetail(PassportClaim claim) {
    if (claim.checkpointMappings.isEmpty) {
      return '';
    }
    return claim.checkpointMappings
        .map((VerificationCheckpointMapping mapping) {
          final String phase = _titleCase(mapping.phase);
          if (phase.isEmpty) {
            return mapping.guidance;
          }
          if (mapping.guidance.trim().isEmpty) {
            return phase;
          }
          return '$phase: ${mapping.guidance}';
        })
        .where((String value) => value.trim().isNotEmpty)
        .join(' • ');
  }

  String _buildProgressionDescriptorsDetail(PassportClaim claim) {
    if (claim.progressionDescriptors.isEmpty) {
      return '';
    }
    return claim.progressionDescriptors.join(' • ');
  }

  String _buildReviewDetail(PassportClaim claim) {
    final List<String> parts = <String>[];
    if (claim.reviewingEducatorName?.trim().isNotEmpty == true) {
      parts.add('${_t('Reviewed by')}: ${claim.reviewingEducatorName}');
    }
    if (claim.reviewedAt != null) {
      parts.add(
          '${_t('Review date')}: ${claim.reviewedAt!.month.toString().padLeft(2, '0')}/${claim.reviewedAt!.day.toString().padLeft(2, '0')}/${claim.reviewedAt!.year}');
    }
    if ((claim.rubricRawScore ?? 0) > 0 && (claim.rubricMaxScore ?? 0) > 0) {
      parts.add(
          '${_t('Rubric score')}: ${claim.rubricRawScore}/${claim.rubricMaxScore}');
    }
    return parts.join(' • ');
  }

  String _formatAiDisclosure(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'learner-ai-verified':
        return _t('Learner AI use disclosed with explain-back evidence');
      case 'learner-ai-verification-gap':
        return _t('Learner AI use detected without explain-back evidence');
      case 'learner-ai-not-used':
        return _t('Learner declared no AI support used');
      case 'educator-feedback-ai':
        return _t('AI-assisted educator feedback visible');
      case 'no-learner-ai-signal':
        return _t('No learner AI-use signal linked to this claim');
      case 'not-available':
        return _t('No linked mission attempt');
      default:
        return _t('Unknown');
    }
  }
}
