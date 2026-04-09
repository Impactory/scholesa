import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';
import '../../runtime/runtime.dart';
import '../../i18n/bos_coaching_i18n.dart';
import '../../i18n/parent_surface_i18n.dart';
import '../../auth/app_state.dart';
import '../../ui/auth/global_session_menu.dart';
import 'parent_models.dart';
import 'parent_service.dart';

/// Parent Summary Page - Safe view for parents to see their children's progress
class ParentSummaryPage extends StatefulWidget {
  const ParentSummaryPage({super.key});

  @override
  State<ParentSummaryPage> createState() => _ParentSummaryPageState();
}

class _ParentSummaryPageState extends State<ParentSummaryPage> {
  int _selectedLearnerIndex = 0;
  static const String _canonicalLearnerUnavailableLabel = 'Learner unavailable';

  String _t(String input) {
    return ParentSurfaceI18n.text(context, input);
  }

  String _displayLearnerName(String learnerName) {
    final String normalized = learnerName.trim();
    if (normalized.isEmpty ||
        normalized == 'Unknown' ||
        normalized == _canonicalLearnerUnavailableLabel) {
      return _t('Learner unavailable');
    }
    return normalized;
  }

  Future<void> _submitLinkedLearnerReviewRequest() async {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{
        'cta': 'parent_summary_request_linked_learner_review',
      },
    );

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final AppState appState = context.read<AppState>();
      final ParentService parentService = context.read<ParentService>();
      final String requestId =
          await parentService.firestoreService.submitSupportRequest(
        requestType: 'parent_linked_learner_review',
        source: 'parent_summary_request_linked_learner_review',
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
        subject: 'Parent linked learner review request',
        message: 'Please review the learner links for this parent account.',
        metadata: <String, dynamic>{
          'activeSiteId': appState.activeSiteId,
          'linkedLearnerCount': parentService.learnerSummaries.length,
        },
      );
      TelemetryService.instance.logEvent(
        event: 'parent.linked_learner_review.submitted',
        metadata: <String, dynamic>{'request_id': requestId},
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ParentService>().loadParentData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MiloRuntimeScope(child: Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              ScholesaColors.parent.withValues(alpha: 0.05),
              Colors.white,
              const Color(0xFFEC4899).withValues(alpha: 0.03),
            ],
          ),
        ),
        child: Consumer<ParentService>(
          builder: (BuildContext context, ParentService service, _) {
            if (service.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: ScholesaColors.parent),
              );
            }

            if (service.error != null && service.learnerSummaries.isEmpty) {
              return _buildLoadErrorState(service);
            }

            if (service.learnerSummaries.isEmpty) {
              return _buildEmptyState();
            }

            final int selectedIndex = _selectedLearnerIndex >= 0 &&
                    _selectedLearnerIndex < service.learnerSummaries.length
                ? _selectedLearnerIndex
                : 0;
            final LearnerSummary selectedLearner =
                service.learnerSummaries[selectedIndex];

            return CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(child: _buildHeader(service)),
                if (service.error != null)
                  SliverToBoxAdapter(child: _buildStaleDataBanner()),
                if (service.learnerSummaries.length > 1)
                  SliverToBoxAdapter(child: _buildLearnerSelector(service)),
                SliverToBoxAdapter(child: _buildProgressCard(selectedLearner)),
                SliverToBoxAdapter(
                  child: _buildFamilyEvidenceAnswers(selectedLearner),
                ),
                SliverToBoxAdapter(
                  child: AiContextCoachSection(
                    title: _t('Family MiloOS'),
                    subtitle: _t('See support ideas for each child’s progress'),
                    module: 'parent_summary',
                    surface: 'family_dashboard',
                    actorRole: UserRole.parent,
                    accentColor: ScholesaColors.parent,
                    conceptTags: <String>[
                      'parent_view',
                      'home_support',
                      'learner_${selectedLearner.learnerId}',
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: BosLearnerLoopInsightsCard(
                      title: BosCoachingI18n.familyLearningTitle(context),
                      subtitle: BosCoachingI18n.familyLearningSubtitle(context),
                      emptyLabel: BosCoachingI18n.familyLearningEmpty(context),
                      learnerId: selectedLearner.learnerId,
                      learnerName:
                          _displayLearnerName(selectedLearner.learnerName),
                      accentColor: ScholesaColors.parent,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                    child: _buildPillarProgress(selectedLearner)),
                if (selectedLearner.growthTimeline.length > 1)
                  SliverToBoxAdapter(
                      child: _buildGrowthTrendSection(selectedLearner)),
                SliverToBoxAdapter(
                    child: _buildRecentActivity(selectedLearner)),
                SliverToBoxAdapter(
                    child: _buildUpcomingEvents(selectedLearner)),
                const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
              ],
            );
          },
        ),
      ),
    ));
  }

  Widget _buildHeader(ParentService service) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[ScholesaColors.parent, Color(0xFFEC4899)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: ScholesaColors.parent.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.family_restroom,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _t('Family Dashboard'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: ScholesaColors.parent,
                      ),
                ),
                Text(
                  '${service.learnerSummaries.length} ${service.learnerSummaries.length > 1 ? _t('learners') : _t('learner')}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
            const Spacer(),
            IconButton(
              onPressed: () async {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: const <String, dynamic>{
                    'cta': 'parent_summary_refresh'
                  },
                );
                await service.loadParentData();
              },
              icon: const Icon(Icons.refresh, color: ScholesaColors.parent),
            ),
            const SessionMenuButton(
              foregroundColor: ScholesaColors.parent,
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLearnerSelector(ParentService service) {
    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: service.learnerSummaries.length,
        itemBuilder: (BuildContext context, int index) {
          final LearnerSummary learner = service.learnerSummaries[index];
          final bool isSelected = index == _selectedLearnerIndex;

          return GestureDetector(
            onTap: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'cta': 'parent_summary_select_learner',
                  'learner_index': index,
                },
              );
              setState(() => _selectedLearnerIndex = index);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? ScholesaColors.parent : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? ScholesaColors.parent
                      : Colors.grey.withValues(alpha: 0.2),
                  width: 2,
                ),
                boxShadow: isSelected
                    ? <BoxShadow>[
                        BoxShadow(
                          color: ScholesaColors.parent.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isSelected
                            ? <Color>[
                                Colors.white.withValues(alpha: 0.3),
                                Colors.white.withValues(alpha: 0.2)
                              ]
                            : <Color>[
                                ScholesaColors.learner.withValues(alpha: 0.8),
                                ScholesaColors.learner
                              ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _getInitials(_displayLearnerName(learner.learnerName)),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _displayLearnerName(learner.learnerName),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : Colors.grey[800],
                        ),
                      ),
                      Text(
                        '${learner.evidenceSummary.reviewedCount} ${_t('reviewed evidence records')}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? Colors.white70 : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressCard(LearnerSummary learner) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            ScholesaColors.learner,
            ScholesaColors.learner.withValues(alpha: 0.8)
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: ScholesaColors.learner.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        _t('Caps'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${learner.growthSummary.updatedCapabilityCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _displayLearnerName(learner.learnerName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${learner.portfolioSnapshot.verifiedArtifactCount} ${_t('reviewed or verified artifacts')} • ${_formatAverageCapabilityLevel(learner.growthSummary.averageLevel)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              _ProgressStat(
                icon: Icons.fact_check_rounded,
                value: '${learner.evidenceSummary.reviewedCount}',
                label: _t('Reviewed Evidence'),
              ),
              _ProgressStat(
                icon: Icons.workspace_premium_rounded,
                value: '${learner.portfolioSnapshot.verifiedArtifactCount}',
                label: _t('Reviewed/Verified Artifacts'),
              ),
              _ProgressStat(
                icon: Icons.check_circle,
                value: '${(learner.attendanceRate * 100).toInt()}%',
                label: _t('Attendance'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              FilledButton.tonalIcon(
                onPressed: () {
                  TelemetryService.instance.logEvent(
                    event: 'cta.clicked',
                    metadata: <String, dynamic>{
                      'cta': 'parent_summary_view_child_detail',
                      'learner_id': learner.learnerId,
                    },
                  );
                  context.go(
                      '/parent/child/${Uri.encodeComponent(learner.learnerId)}');
                },
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(_t('View Child Detail')),
              ),
              FilledButton.tonalIcon(
                onPressed: () {
                  TelemetryService.instance.logEvent(
                    event: 'cta.clicked',
                    metadata: <String, dynamic>{
                      'cta': 'parent_summary_view_consent',
                      'learner_id': learner.learnerId,
                    },
                  );
                  context.go('/parent/consent');
                },
                icon: const Icon(Icons.verified_user_outlined),
                label: Text(_t('View Consent')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyEvidenceAnswers(LearnerSummary learner) {
    final PassportClaim? featuredClaim = _selectFeaturedClaim(learner);
    final PortfolioPreviewItem? featuredPortfolioItem =
        _selectFeaturedPortfolioItem(learner);
    final List<String> featuredProgressionDescriptors =
        _featuredProgressionDescriptors(featuredClaim, featuredPortfolioItem);
    final List<VerificationCheckpointMapping> featuredCheckpointMappings =
        _featuredCheckpointMappings(featuredClaim, featuredPortfolioItem);
    final String verificationCriteria =
        _buildVerificationCriteriaDetail(featuredCheckpointMappings);
    final String progressionDescriptors =
        _buildProgressionDescriptorsDetail(featuredProgressionDescriptors);
    final String proofDetail =
        _buildProofSummary(featuredClaim, featuredPortfolioItem);
    final int capabilityPercent =
        (learner.capabilitySnapshot.overall * 100).round();
    final String nextFocus = _buildNextFocusAnswer(
      learner,
      featuredClaim,
      featuredPortfolioItem,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _t('Family Evidence View'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              _t('This view answers what the learner can do now, what evidence is on record, how growth is trending, and what should come next.'),
              style: TextStyle(color: Colors.grey[700], height: 1.35),
            ),
            const SizedBox(height: 16),
            _FamilyAnswerRow(
              icon: Icons.workspace_premium_rounded,
              label: _t('What can this learner do now?'),
              value: _buildCapabilityAnswer(
                learner,
                featuredClaim,
                capabilityPercent,
                progressionDescriptors,
              ),
            ),
            const SizedBox(height: 12),
            _FamilyAnswerRow(
              icon: Icons.fact_check_rounded,
              label: _t('What evidence proves it?'),
              value: _buildEvidenceAnswer(
                learner,
                featuredClaim,
                featuredPortfolioItem,
                verificationCriteria,
              ),
            ),
            const SizedBox(height: 12),
            _FamilyAnswerRow(
              icon: Icons.timeline_rounded,
              label: _t('How are they growing?'),
              value: _buildGrowthAnswer(
                learner,
                featuredClaim,
                proofDetail,
              ),
            ),
            if (featuredClaim != null ||
                featuredPortfolioItem != null) ...<Widget>[
              const SizedBox(height: 16),
              Text(
                _t('Capability Snapshot'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              _FamilyEvidenceDetail(
                label: _t('Evidence-backed capability focus'),
                value: _buildFeaturedCapabilityFocus(
                  featuredClaim,
                  featuredPortfolioItem,
                ),
              ),
              if (progressionDescriptors.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                _FamilyEvidenceDetail(
                  label: _t('Progression Descriptors'),
                  value: progressionDescriptors,
                ),
              ],
              if (verificationCriteria.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                _FamilyEvidenceDetail(
                  label: _t('Verification Criteria'),
                  value: verificationCriteria,
                ),
              ],
              if (proofDetail.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                _FamilyEvidenceDetail(
                  label: _t('Proof of Learning'),
                  value: proofDetail,
                ),
              ],
            ],
            if (learner.growthTimeline.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _t('Recent growth timeline'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              ...learner.growthTimeline.take(4).map(
                    (GrowthTimelineEntry entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 6),
                            decoration: const BoxDecoration(
                              color: ScholesaColors.parent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _formatGrowthTimelineEntry(entry),
                              style: TextStyle(
                                color: Colors.grey[700],
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
            const SizedBox(height: 12),
            _FamilyAnswerRow(
              icon: Icons.forward_to_inbox_rounded,
              label: _t('What should they work on next?'),
              value: nextFocus,
            ),
            const SizedBox(height: 12),
            Text(
              _t('This family view prioritizes reviewed observations, reviewed or verified artifacts, and capability growth over gamified progress counters. Attendance is shown elsewhere as participation, not capability growth.'),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatAverageCapabilityLevel(double value) {
    if (value <= 0) {
      return _t('No capability level yet');
    }
    return '${value.toStringAsFixed(1)}/4 ${_t('average capability level')}';
  }

  String _levelLabel(int level) {
    switch (level) {
      case 1:
        return _t('Beginning');
      case 2:
        return _t('Developing');
      case 3:
        return _t('Proficient');
      case 4:
        return _t('Advanced');
      default:
        return _t('Not assessed');
    }
  }

  PassportClaim? _selectFeaturedClaim(LearnerSummary learner) {
    if (learner.ideationPassport.claims.isEmpty) {
      return null;
    }
    final List<PassportClaim> claims = List<PassportClaim>.from(
        learner.ideationPassport.claims)
      ..sort((PassportClaim left, PassportClaim right) {
        final int evidenceAtCompare =
            (right.latestEvidenceAt?.millisecondsSinceEpoch ?? 0)
                .compareTo(left.latestEvidenceAt?.millisecondsSinceEpoch ?? 0);
        if (evidenceAtCompare != 0) {
          return evidenceAtCompare;
        }
        final int reviewedAtCompare =
            (right.reviewedAt?.millisecondsSinceEpoch ?? 0)
                .compareTo(left.reviewedAt?.millisecondsSinceEpoch ?? 0);
        if (reviewedAtCompare != 0) {
          return reviewedAtCompare;
        }
        final int verifiedCompare =
            right.verifiedArtifactCount.compareTo(left.verifiedArtifactCount);
        if (verifiedCompare != 0) {
          return verifiedCompare;
        }
        return right.evidenceCount.compareTo(left.evidenceCount);
      });
    return claims.first;
  }

  PortfolioPreviewItem? _selectFeaturedPortfolioItem(LearnerSummary learner) {
    if (learner.portfolioItemsPreview.isEmpty) {
      return null;
    }
    final List<PortfolioPreviewItem> items =
        List<PortfolioPreviewItem>.from(learner.portfolioItemsPreview)
          ..sort((PortfolioPreviewItem left, PortfolioPreviewItem right) {
            final int verificationCompare = _verificationPriority(right)
                .compareTo(_verificationPriority(left));
            if (verificationCompare != 0) {
              return verificationCompare;
            }
            final int evidenceCompare = (right.evidenceLinked ? 1 : 0)
                .compareTo(left.evidenceLinked ? 1 : 0);
            if (evidenceCompare != 0) {
              return evidenceCompare;
            }
            return right.completedAt.compareTo(left.completedAt);
          });
    return items.first;
  }

  int _verificationPriority(PortfolioPreviewItem item) {
    switch ((item.verificationStatus ?? '').trim().toLowerCase()) {
      case 'verified':
        return 4;
      case 'reviewed':
        return 3;
      case 'pending':
        return 2;
      case 'draft':
        return 1;
      default:
        return 0;
    }
  }

  List<String> _featuredProgressionDescriptors(
    PassportClaim? claim,
    PortfolioPreviewItem? item,
  ) {
    if (item != null && item.progressionDescriptors.isNotEmpty) {
      return item.progressionDescriptors;
    }
    if (claim != null && claim.progressionDescriptors.isNotEmpty) {
      return claim.progressionDescriptors;
    }
    return const <String>[];
  }

  List<VerificationCheckpointMapping> _featuredCheckpointMappings(
    PassportClaim? claim,
    PortfolioPreviewItem? item,
  ) {
    if (item != null && item.checkpointMappings.isNotEmpty) {
      return item.checkpointMappings;
    }
    if (claim != null && claim.checkpointMappings.isNotEmpty) {
      return claim.checkpointMappings;
    }
    return const <VerificationCheckpointMapping>[];
  }

  String _buildCapabilityAnswer(
    LearnerSummary learner,
    PassportClaim? featuredClaim,
    int capabilityPercent,
    String progressionDescriptors,
  ) {
    if (featuredClaim == null) {
      return '${learner.capabilitySnapshot.band} • ${learner.growthSummary.capabilityCount} ${_t('capabilities with current evidence')} • $capabilityPercent% ${_t('coverage confidence')}';
    }
    final List<String> parts = <String>[
      '${featuredClaim.title} • ${_levelLabel(featuredClaim.latestLevel)}',
    ];
    if (progressionDescriptors.isNotEmpty) {
      parts.add(progressionDescriptors);
    }
    parts.add(
      '${learner.growthSummary.capabilityCount} ${_t('capabilities with current evidence')} • $capabilityPercent% ${_t('coverage confidence')}',
    );
    return parts.join(' • ');
  }

  String _buildEvidenceAnswer(
    LearnerSummary learner,
    PassportClaim? featuredClaim,
    PortfolioPreviewItem? featuredPortfolioItem,
    String verificationCriteria,
  ) {
    final List<String> parts = <String>[
      '${learner.evidenceSummary.reviewedCount} ${_t('reviewed observations')}',
      '${learner.portfolioSnapshot.verifiedArtifactCount} ${_t('reviewed or verified artifacts')}',
      '${learner.ideationPassport.reflectionsSubmitted} ${_t('reflections')}',
    ];
    if (featuredPortfolioItem != null) {
      parts.add('${_t('Artifact')}: ${featuredPortfolioItem.title}');
    }
    if (featuredClaim != null) {
      parts.add('${_t('Capability')}: ${featuredClaim.title}');
    }
    if (verificationCriteria.isNotEmpty) {
      parts.add('${_t('Verification Criteria')}: $verificationCriteria');
    }
    if (learner.evidenceSummary.verificationPromptCount > 0) {
      parts.add(
        '${learner.evidenceSummary.verificationPromptCount} ${_t('verification prompts pending')}',
      );
    }
    return parts.join(' • ');
  }

  String _buildGrowthAnswer(
    LearnerSummary learner,
    PassportClaim? featuredClaim,
    String proofDetail,
  ) {
    final List<String> parts = <String>[
      '${learner.growthSummary.updatedCapabilityCount} ${_t('capabilities updated')}',
      _formatAverageCapabilityLevel(learner.growthSummary.averageLevel),
      _formatLatestGrowthNote(learner.growthSummary.latestGrowthAt),
    ];
    if (featuredClaim != null) {
      parts.insert(0,
          '${featuredClaim.title} • ${_levelLabel(featuredClaim.latestLevel)}');
    }
    if (proofDetail.isNotEmpty) {
      parts.add(proofDetail);
    }
    return parts.join(' • ');
  }

  String _buildNextFocusAnswer(
    LearnerSummary learner,
    PassportClaim? featuredClaim,
    PortfolioPreviewItem? featuredPortfolioItem,
  ) {
    if (featuredPortfolioItem?.verificationPrompt?.trim().isNotEmpty == true) {
      return featuredPortfolioItem!.verificationPrompt!.trim();
    }
    final List<VerificationCheckpointMapping> checkpointMappings =
        _featuredCheckpointMappings(featuredClaim, featuredPortfolioItem);
    if (checkpointMappings.isNotEmpty) {
      return _checkpointMappingToSentence(checkpointMappings.first);
    }
    if (learner.evidenceSummary.verificationPromptCount > 0) {
      return _t(
          'Follow up on the latest educator verification prompts during the next studio check-in.');
    }
    if (learner.portfolioSnapshot.artifactCount == 0) {
      return _t('Capture a first portfolio artifact from current studio work.');
    }
    if (learner.portfolioSnapshot.verifiedArtifactCount <
        learner.portfolioSnapshot.artifactCount) {
      return _t('Publish the strongest recent artifact with reflection.');
    }
    return _t(
        'Keep adding checkpoints, reflections, and educator evidence next week.');
  }

  String _checkpointMappingToSentence(VerificationCheckpointMapping mapping) {
    final String phase = _titleCase(mapping.phase);
    final String guidance = mapping.guidance.trim();
    if (phase.isEmpty) {
      return guidance;
    }
    if (guidance.isEmpty) {
      return phase;
    }
    return '$phase: $guidance';
  }

  String _buildFeaturedCapabilityFocus(
    PassportClaim? claim,
    PortfolioPreviewItem? item,
  ) {
    final List<String> parts = <String>[];
    if (claim != null) {
      parts.add('${claim.title} • ${_levelLabel(claim.latestLevel)}');
      if ((claim.verificationStatus ?? '').trim().isNotEmpty) {
        parts.add(
          '${_t('Artifact Review Status')}: ${_titleCase(claim.verificationStatus!)}',
        );
      }
    }
    if (item != null) {
      parts.add('${_t('Artifact')}: ${item.title}');
      if (item.reviewingEducatorName?.trim().isNotEmpty == true) {
        parts.add('${_t('Reviewed by')}: ${item.reviewingEducatorName}');
      }
    }
    return parts.join(' • ');
  }

  String _buildVerificationCriteriaDetail(
    List<VerificationCheckpointMapping> checkpointMappings,
  ) {
    if (checkpointMappings.isEmpty) {
      return '';
    }
    return checkpointMappings
        .map(_checkpointMappingToSentence)
        .where((String value) => value.trim().isNotEmpty)
        .join(' • ');
  }

  String _buildProgressionDescriptorsDetail(List<String> descriptors) {
    if (descriptors.isEmpty) {
      return '';
    }
    return descriptors.join(' • ');
  }

  String _buildProofSummary(
    PassportClaim? claim,
    PortfolioPreviewItem? item,
  ) {
    final List<String> parts = <String>[];
    final String? proofStatus =
        (item?.proofOfLearningStatus?.trim().isNotEmpty == true)
            ? item!.proofOfLearningStatus
            : claim?.proofOfLearningStatus;
    if (proofStatus?.trim().isNotEmpty == true) {
      parts.add(
        '${_t('Proof of Learning')}: ${_formatTimelineProofStatus(proofStatus!)}',
      );
    }
    if (claim?.reviewingEducatorName?.trim().isNotEmpty == true) {
      parts.add('${_t('Reviewed by')}: ${claim!.reviewingEducatorName}');
    } else if (item?.reviewingEducatorName?.trim().isNotEmpty == true) {
      parts.add('${_t('Reviewed by')}: ${item!.reviewingEducatorName}');
    }
    if ((item?.rubricLevel ?? 0) > 0) {
      parts.add('${_t('Rubric level')}: ${_levelLabel(item!.rubricLevel ?? 0)}');
    } else if ((claim?.rubricRawScore ?? 0) > 0 &&
        (claim?.rubricMaxScore ?? 0) > 0) {
      parts.add(
        '${_t('Rubric score')}: ${claim!.rubricRawScore}/${claim.rubricMaxScore}',
      );
    }
    return parts.join(' • ');
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

  String _formatLatestGrowthNote(DateTime? value) {
    if (value == null) {
      return _t('latest growth update pending');
    }
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    return '${_t('latest update')}: $month/$day/${value.year}';
  }

  String _formatGrowthTimelineEntry(GrowthTimelineEntry entry) {
    final List<String> parts = <String>[
      entry.title,
      _levelLabel(entry.level),
    ];
    if ((entry.rubricRawScore ?? 0) > 0 && (entry.rubricMaxScore ?? 0) > 0) {
      parts.add(
          '${_t('rubric')} ${entry.rubricRawScore}/${entry.rubricMaxScore}');
    }
    if (entry.reviewingEducatorName?.trim().isNotEmpty == true) {
      parts.add('${_t('reviewed by')} ${entry.reviewingEducatorName}');
    }
    if (entry.linkedEvidenceRecordIds.isNotEmpty) {
      parts.add(
          '${entry.linkedEvidenceRecordIds.length} ${_t('evidence records linked')}');
    }
    if (entry.linkedPortfolioItemIds.isNotEmpty) {
      parts.add(
          '${entry.linkedPortfolioItemIds.length} ${_t('portfolio artifacts linked')}');
    }
    if (entry.proofOfLearningStatus?.trim().isNotEmpty == true) {
      parts.add(
          '${_t('proof')} ${_formatTimelineProofStatus(entry.proofOfLearningStatus!)}');
    }
    if (entry.occurredAt != null) {
      final DateTime value = entry.occurredAt!;
      parts.add(
          '${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}/${value.year}');
    }
    return parts.join(' • ');
  }

  String _formatTimelineProofStatus(String value) {
    switch (value.trim().toLowerCase()) {
      case 'verified':
        return _t('verified');
      case 'partial':
        return _t('partial');
      case 'missing':
        return _t('missing');
      case 'not-available':
        return _t('not available');
      default:
        return value.trim();
    }
  }

  Widget _buildPillarProgress(LearnerSummary learner) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _t('Learning Pillars'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _PillarProgressBar(
            emoji: '🚀',
            label: _t('Future Skills'),
            progress: learner.pillarProgress['futureSkills'] ?? 0,
            color: const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 12),
          _PillarProgressBar(
            emoji: '👑',
            label: _t('Leadership & Agency'),
            progress: learner.pillarProgress['leadership'] ?? 0,
            color: const Color(0xFF8B5CF6),
          ),
          const SizedBox(height: 12),
          _PillarProgressBar(
            emoji: '💡',
            label: _t('Impact & Innovation'),
            progress: learner.pillarProgress['impact'] ?? 0,
            color: const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthTrendSection(LearnerSummary learner) {
    // Group timeline entries by capability to show per-capability growth
    final Map<String, List<GrowthTimelineEntry>> byCapability =
        <String, List<GrowthTimelineEntry>>{};
    for (final GrowthTimelineEntry entry in learner.growthTimeline) {
      byCapability.putIfAbsent(entry.capabilityId, () => <GrowthTimelineEntry>[]).add(entry);
    }
    // Sort entries within each capability by date
    for (final List<GrowthTimelineEntry> entries in byCapability.values) {
      entries.sort((GrowthTimelineEntry a, GrowthTimelineEntry b) {
        final DateTime da = a.occurredAt ?? DateTime(2000);
        final DateTime db = b.occurredAt ?? DateTime(2000);
        return da.compareTo(db);
      });
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _t('Capability Growth Trend'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _t('How capabilities have progressed over time'),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 14),
          for (final MapEntry<String, List<GrowthTimelineEntry>> cap
              in byCapability.entries)
            _buildCapabilityTrendRow(cap.value),
        ],
      ),
    );
  }

  Widget _buildCapabilityTrendRow(List<GrowthTimelineEntry> entries) {
    final GrowthTimelineEntry latest = entries.last;
    final Color pillarColor = _getPillarColor(latest.pillar);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: pillarColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  latest.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _levelLabel(latest.level),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: pillarColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Level progression bar
          Row(
            children: <Widget>[
              for (int i = 0; i < entries.length; i++) ...<Widget>[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 12,
                      color: Colors.grey[400],
                    ),
                  ),
                _buildLevelBadge(entries[i].level, pillarColor),
              ],
            ],
          ),
          if (latest.reviewingEducatorName?.trim().isNotEmpty == true ||
              latest.proofOfLearningStatus?.trim().isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: <Widget>[
                  if (latest.reviewingEducatorName?.trim().isNotEmpty == true)
                    Text(
                      '${_t('Reviewed by')} ${latest.reviewingEducatorName}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  if (latest.reviewingEducatorName?.trim().isNotEmpty == true &&
                      latest.proofOfLearningStatus?.trim().isNotEmpty == true)
                    Text(
                      ' · ',
                      style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                    ),
                  if (latest.proofOfLearningStatus?.trim().isNotEmpty == true)
                    Text(
                      _formatTimelineProofStatus(
                          latest.proofOfLearningStatus!),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLevelBadge(int level, Color baseColor) {
    final double opacity = level / 4.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.1 + (opacity * 0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$level',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: baseColor,
        ),
      ),
    );
  }

  Color _getPillarColor(String pillar) {
    switch (pillar) {
      case 'Future Skills':
        return const Color(0xFF3B82F6);
      case 'Leadership & Agency':
        return const Color(0xFF8B5CF6);
      case 'Impact & Innovation':
        return const Color(0xFF10B981);
      default:
        return Colors.grey;
    }
  }

  Widget _buildRecentActivity(LearnerSummary learner) {
    if (learner.recentActivities.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
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
                _t('Recent Activity'),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _t('No recent activity yet'),
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 4),
              Text(
                _t('Recent learner updates will appear here once missions or habits are completed.'),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                _t('Recent Activity'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () => _showAllActivities(learner),
                child: Text(
                  _t('See all'),
                  style: TextStyle(color: ScholesaColors.parent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...learner.recentActivities.take(4).map(
              (RecentActivity activity) => _ActivityItem(activity: activity)),
        ],
      ),
    );
  }

  Widget _buildUpcomingEvents(LearnerSummary learner) {
    if (learner.upcomingEvents.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
                _t('Upcoming'),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _t('No upcoming events yet'),
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 4),
              Text(
                _t('Upcoming sessions and school events will appear here.'),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _t('Upcoming'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...learner.upcomingEvents
              .map((UpcomingEvent event) => _EventCard(event: event)),
        ],
      ),
    );
  }

  void _showAllActivities(LearnerSummary learner) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'parent_summary_view_all_activities',
        'learner': _displayLearnerName(learner.learnerName)
      },
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                _t('All Recent Activity'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                shrinkWrap: true,
                children: learner.recentActivities
                    .map((RecentActivity activity) =>
                        _ActivityItem(activity: activity))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ScholesaColors.parent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.family_restroom,
                size: 48, color: ScholesaColors.parent),
          ),
          const SizedBox(height: 16),
          Text(
            _t('No learners linked'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _t('Contact your school to link your children'),
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: _submitLinkedLearnerReviewRequest,
            child: Text(_t('Request Linking Review')),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadErrorState(ParentService service) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.red.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              _t('Family dashboard is temporarily unavailable'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _t('We could not load your linked learners right now. Retry to check the current state.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: service.loadParentData,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(_t('Retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaleDataBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              _t('Unable to refresh family dashboard right now. Showing the last successful data.'),
              style: const TextStyle(color: ScholesaColors.textPrimary),
            ),
          ),
        ],
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
}

class _ProgressStat extends StatelessWidget {
  const _ProgressStat({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _PillarProgressBar extends StatelessWidget {
  const _PillarProgressBar({
    required this.emoji,
    required this.label,
    required this.progress,
    required this.color,
  });
  final String emoji;
  final String label;
  final double progress;
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
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: color.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FamilyAnswerRow extends StatelessWidget {
  const _FamilyAnswerRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ScholesaColors.parent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: ScholesaColors.parent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FamilyEvidenceDetail extends StatelessWidget {
  const _FamilyEvidenceDetail({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ScholesaColors.parent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ScholesaColors.parent.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  const _ActivityItem({required this.activity});
  final RecentActivity activity;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(activity.emoji, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  activity.title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  activity.description,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            _formatTime(context, activity.timestamp),
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
        ],
      ),
    );
  }

  String _formatTime(BuildContext context, DateTime time) {
    final DateTime now = DateTime.now();
    final Duration diff = now.difference(time);
    if (diff.inHours < 24) {
      return '${diff.inHours}${ParentSurfaceI18n.text(context, 'h ago')}';
    }
    return '${diff.inDays}${ParentSurfaceI18n.text(context, 'd ago')}';
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});
  final UpcomingEvent event;

  Color get _typeColor {
    switch (event.type) {
      case 'class':
        return const Color(0xFF3B82F6);
      case 'mission_due':
        return ScholesaColors.warning;
      case 'conference':
        return ScholesaColors.parent;
      default:
        return Colors.grey;
    }
  }

  IconData get _typeIcon {
    switch (event.type) {
      case 'class':
        return Icons.school;
      case 'mission_due':
        return Icons.assignment;
      case 'conference':
        return Icons.people;
      default:
        return Icons.event;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _typeColor.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Container(
              width: 52,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: _typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: <Widget>[
                  Text(
                    _getMonth(context, event.dateTime),
                    style: TextStyle(
                      color: _typeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${event.dateTime.day}',
                    style: TextStyle(
                      color: _typeColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(_typeIcon, size: 16, color: _typeColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          event.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(context, event.dateTime),
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  if (event.location != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Row(
                      children: <Widget>[
                        Icon(Icons.location_on,
                            size: 12, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(
                          event.location!,
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getMonth(BuildContext context, DateTime date) {
    const List<String> months = <String>[
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC'
    ];
    return ParentSurfaceI18n.text(context, months[date.month - 1]);
  }

  String _formatTime(BuildContext context, DateTime time) {
    final int hour =
        time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final String period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
  }
}
