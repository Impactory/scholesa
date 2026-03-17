import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../i18n/workflow_surface_i18n.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';
import '../../runtime/runtime.dart';
import '../../i18n/bos_coaching_i18n.dart';
import '../../auth/app_state.dart';
import '../missions/mission_service.dart';

String _tEducatorMissionReview(BuildContext context, String input) {
  return WorkflowSurfaceI18n.text(context, input);
}

/// Educator Mission Review Page - Review and assess learner submissions
class EducatorMissionReviewPage extends StatefulWidget {
  const EducatorMissionReviewPage({super.key});

  @override
  State<EducatorMissionReviewPage> createState() =>
      _EducatorMissionReviewPageState();
}

class _EducatorMissionReviewPageState extends State<EducatorMissionReviewPage> {
  String _filterStatus = 'pending';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MissionService>().loadPendingReviews();
    });
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
              ScholesaColors.educator.withValues(alpha: 0.05),
              Colors.white,
              ScholesaColors.futureSkills.withValues(alpha: 0.03),
            ],
          ),
        ),
        child: Consumer<MissionService>(
          builder: (BuildContext context, MissionService service, _) {
            final List<MissionSubmission> filteredSubmissions =
                _getFilteredSubmissions(service);
            final MissionSubmission? loopSubmission =
                filteredSubmissions.isNotEmpty
                    ? filteredSubmissions.first
                    : (service.pendingReviews.isNotEmpty
                        ? service.pendingReviews.first
                        : null);

            return CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(child: _buildHeader(service)),
                SliverToBoxAdapter(
                  child: AiContextCoachSection(
                    title: _tEducatorMissionReview(context, 'Review AI Coach'),
                    subtitle: _tEducatorMissionReview(
                      context,
                      'Keep BOS/MIA loop active while reviewing learner submissions',
                    ),
                    module: 'educator_mission_review',
                    surface: 'mission_review_queue',
                    actorRole: UserRole.educator,
                    accentColor: ScholesaColors.educator,
                    conceptTags: const <String>[
                      'mission_review',
                      'feedback_quality',
                      'learner_growth',
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: BosLearnerLoopInsightsCard(
                  title: BosCoachingI18n.sessionLoopTitle(context),
                  subtitle: BosCoachingI18n.sessionLoopSubtitle(context),
                  emptyLabel: BosCoachingI18n.sessionLoopEmpty(context),
                    learnerId: loopSubmission?.learnerId,
                    learnerName: loopSubmission?.learnerName,
                    accentColor: ScholesaColors.educator,
                  ),
                ),
                SliverToBoxAdapter(child: _buildFilters()),
                SliverToBoxAdapter(child: _buildStats(service)),
                if (service.isLoading)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: ScholesaColors.educator,
                      ),
                    ),
                  )
                else if (filteredSubmissions.isEmpty)
                  SliverFillRemaining(
                    child: _buildEmptyState(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (BuildContext context, int index) {
                          final List<MissionSubmission> submissions =
                              filteredSubmissions;
                          if (index >= submissions.length) return null;
                          return _SubmissionCard(
                            submission: submissions[index],
                            onTap: () => _openReviewSheet(submissions[index]),
                          );
                        },
                        childCount: filteredSubmissions.length,
                      ),
                    ),
                  ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(MissionService service) {
    final int pendingCount = service.pendingReviews.length;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: ScholesaColors.educatorGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: ScholesaColors.educator.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child:
                  const Icon(Icons.rate_review, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _tEducatorMissionReview(context, 'Mission Review'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: ScholesaColors.educator,
                        ),
                  ),
                  Text(
                    '$pendingCount ${_tEducatorMissionReview(context, 'submissions pending review')}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            _FilterChip(
              label: _tEducatorMissionReview(context, 'Pending'),
              isSelected: _filterStatus == 'pending',
              count: 0,
              onTap: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: const <String, dynamic>{
                    'cta': 'educator_mission_review_filter_pending',
                  },
                );
                setState(() => _filterStatus = 'pending');
              },
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: _tEducatorMissionReview(context, 'Reviewed'),
              isSelected: _filterStatus == 'reviewed',
              onTap: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: const <String, dynamic>{
                    'cta': 'educator_mission_review_filter_reviewed',
                  },
                );
                setState(() => _filterStatus = 'reviewed');
              },
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: _tEducatorMissionReview(context, 'Needs Revision'),
              isSelected: _filterStatus == 'revision',
              color: ScholesaColors.warning,
              onTap: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: const <String, dynamic>{
                    'cta': 'educator_mission_review_filter_revision',
                  },
                );
                setState(() => _filterStatus = 'revision');
              },
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: _tEducatorMissionReview(context, 'Approved'),
              isSelected: _filterStatus == 'approved',
              color: ScholesaColors.success,
              onTap: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: const <String, dynamic>{
                    'cta': 'educator_mission_review_filter_approved',
                  },
                );
                setState(() => _filterStatus = 'approved');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(MissionService service) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _StatCard(
              icon: Icons.pending_actions,
              value: service.pendingReviews.length.toString(),
              label: _tEducatorMissionReview(context, 'Pending'),
              color: ScholesaColors.warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Icons.check_circle,
              value: service.reviewedToday.toString(),
              label: _tEducatorMissionReview(context, 'Reviewed Today'),
              color: ScholesaColors.success,
            ),
          ),
        ],
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
              color: ScholesaColors.educator.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline,
              size: 64,
              color: ScholesaColors.educator.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _tEducatorMissionReview(context, 'All caught up!'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: ScholesaColors.educator,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _tEducatorMissionReview(context, 'No submissions matching this filter'),
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  List<MissionSubmission> _getFilteredSubmissions(MissionService service) {
    return service.pendingReviews
        .where((MissionSubmission s) => s.status == _filterStatus)
        .toList();
  }

  void _openReviewSheet(MissionSubmission submission) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'educator_mission_review_open_sheet',
        'submission_id': submission.id
      },
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => _ReviewSheet(submission: submission),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({required this.submission, required this.onTap});
  final MissionSubmission submission;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            TelemetryService.instance.logEvent(
              event: 'cta.clicked',
              metadata: <String, dynamic>{
                'cta': 'educator_mission_review_open_submission_card',
                'submission_id': submission.id,
              },
            );
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 20,
                      backgroundColor:
                          ScholesaColors.learner.withValues(alpha: 0.1),
                      child: Text(
                        submission.learnerInitials,
                        style: const TextStyle(
                          color: ScholesaColors.learner,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            submission.learnerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            submission.missionTitle,
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    _StatusBadge(status: submission.status),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.attach_file,
                          size: 16, color: Colors.grey[500]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          submission.submissionPreview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(color: Colors.grey[700], fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getPillarColor().withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        submission.pillar,
                        style: TextStyle(
                          color: _getPillarColor(),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      submission.submittedAgo,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getPillarColor() {
    switch (submission.pillar.toLowerCase()) {
      case 'future skills':
        return ScholesaColors.futureSkills;
      case 'leadership':
        return ScholesaColors.leadership;
      case 'impact':
        return ScholesaColors.impact;
      default:
        return ScholesaColors.educator;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status.toLowerCase()) {
      case 'pending':
        color = ScholesaColors.warning;
        label = _tEducatorMissionReview(context, 'PENDING');
      case 'reviewed':
        color = ScholesaColors.info;
        label = _tEducatorMissionReview(context, 'REVIEWED');
      case 'approved':
        color = ScholesaColors.success;
        label = _tEducatorMissionReview(context, 'APPROVED');
      case 'revision':
        color = ScholesaColors.error;
        label = _tEducatorMissionReview(context, 'REVISION');
      default:
        color = Colors.grey;
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.count,
    this.color,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final int? count;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color chipColor = color ?? ScholesaColors.educator;
    return GestureDetector(
      onTap: () {
        TelemetryService.instance.logEvent(
          event: 'cta.clicked',
          metadata: <String, dynamic>{
            'cta': 'educator_mission_review_filter_chip',
            'label': label,
            'selected': isSelected,
          },
        );
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : chipColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : chipColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            if (count != null && count! > 0) ...<Widget>[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.2)
                      : chipColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.submission});
  final MissionSubmission submission;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  final TextEditingController _feedbackController = TextEditingController();
  String? _aiFeedbackDraft;
  int _rating = 0;
  late final Map<String, int> _rubricScores;

  @override
  void initState() {
    super.initState();
    _rating = widget.submission.rating ?? 0;
    _feedbackController.text = widget.submission.feedback ?? '';
    _aiFeedbackDraft = widget.submission.aiFeedbackDraft;
    _rubricScores = <String, int>{
      for (final Map<String, dynamic> criterion in widget.submission.rubricCriteria)
        _criterionId(criterion): _existingScoreForCriterion(criterion),
    };
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  int _existingScoreForCriterion(Map<String, dynamic> criterion) {
    final String criterionId = _criterionId(criterion);
    for (final Map<String, dynamic> score in widget.submission.rubricScores) {
      if ((score['criterionId'] as String? ?? '') == criterionId) {
        return (score['score'] as num?)?.toInt() ?? 0;
      }
    }
    return 0;
  }

  String _criterionId(Map<String, dynamic> criterion) {
    return criterion['id'] as String? ?? criterion['label'] as String? ?? 'criterion';
  }

  int _criterionMaxScore(Map<String, dynamic> criterion) {
    final List<int> levels = ((criterion['levels'] as List<dynamic>?)
            ?.map((dynamic value) => (value as num).toInt())
            .toList()) ??
        const <int>[];
    if (levels.isEmpty) {
      return 4;
    }
    return levels.reduce((int left, int right) => left > right ? left : right);
  }

  String _pillarLabel(String pillarCode) {
    switch (pillarCode) {
      case 'leadership':
        return _tEducatorMissionReview(context, 'Leadership');
      case 'impact':
        return _tEducatorMissionReview(context, 'Impact');
      default:
        return _tEducatorMissionReview(context, 'Future Skills');
    }
  }

  String _buildAiDraft() {
    final int effectiveRating = _rating == 0 ? 4 : _rating;
    final String tone = effectiveRating >= 4
        ? _tEducatorMissionReview(context, 'Strong progress')
        : effectiveRating == 3
            ? _tEducatorMissionReview(context, 'Solid progress')
            : _tEducatorMissionReview(context, 'Growth opportunity');
    final String nextStep = effectiveRating >= 4
        ? _tEducatorMissionReview(context,
            'Next, push the learner to explain their choices and extend the work independently.')
        : _tEducatorMissionReview(context,
            'Next, ask the learner to revise one concrete part and explain the change back to you.');
    return '${widget.submission.learnerName} showed ${_pillarLabel(widget.submission.pillar).toLowerCase()} growth in ${widget.submission.missionTitle}. $tone. ${_tEducatorMissionReview(context, 'Reference specific evidence from the submission and keep the next step concrete.')} $nextStep';
  }

  List<Map<String, dynamic>> _selectedRubricScores() {
    return widget.submission.rubricCriteria.map((Map<String, dynamic> criterion) {
      final String criterionId = _criterionId(criterion);
      final int maxScore = _criterionMaxScore(criterion);
      return <String, dynamic>{
        'criterionId': criterionId,
        'label': criterion['label'] as String? ?? criterionId,
        'pillarCode': criterion['pillarCode'] as String? ?? widget.submission.pillar,
        'score': (_rubricScores[criterionId] ?? 0).clamp(0, maxScore),
        'maxScore': maxScore,
      };
    }).toList();
  }

  Future<void> _submitReview(
    BuildContext context, {
    required String status,
    required int fallbackRating,
    required String outcome,
    required String successMessage,
    required Color successColor,
  }) async {
    final MissionService missionService = context.read<MissionService>();
    final String reviewerId =
        FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    final int effectiveRating = _rating == 0 ? fallbackRating : _rating;
    final List<Map<String, dynamic>> rubricScores = _selectedRubricScores();
    final bool success = await missionService.submitReview(
      submissionId: widget.submission.id,
      rating: effectiveRating,
      feedback: _feedbackController.text.trim(),
      reviewerId: reviewerId,
      status: status,
      aiFeedbackDraft: _aiFeedbackDraft,
      rubricId: widget.submission.rubricId,
      rubricTitle: widget.submission.rubricTitle,
      rubricScores: rubricScores,
    );
    if (!success || !context.mounted) {
      return;
    }
    if (_aiFeedbackDraft != null && _aiFeedbackDraft!.isNotEmpty) {
      TelemetryService.instance.logEvent(
        event: 'ai_coach_feedback',
        metadata: <String, dynamic>{
          'submission_id': widget.submission.id,
          'mission_id': widget.submission.missionId,
          'edited': _aiFeedbackDraft != _feedbackController.text.trim(),
          'draft_length': _aiFeedbackDraft!.length,
          'final_length': _feedbackController.text.trim().length,
        },
      );
    }
    TelemetryService.instance.logEvent(
      event: 'checkpoint_graded',
      metadata: <String, dynamic>{
        'submission_id': widget.submission.id,
        'mission_id': widget.submission.missionId,
        'rating': effectiveRating,
        'rubric_id': widget.submission.rubricId,
        'rubric_criteria_count': rubricScores.length,
        'outcome': outcome,
      },
    );
    TelemetryService.instance.logEvent(
      event: 'educator.review.completed',
      metadata: <String, dynamic>{
        'submission_id': widget.submission.id,
        'mission_id': widget.submission.missionId,
        'outcome': outcome,
        'rating': effectiveRating,
        'feedback_length': _feedbackController.text.trim().length,
        'turnaround_minutes': DateTime.now()
            .difference(widget.submission.submittedAt)
            .inMinutes,
      },
    );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_tEducatorMissionReview(context, successMessage)),
        backgroundColor: successColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
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
                      CircleAvatar(
                        radius: 24,
                        backgroundColor:
                            ScholesaColors.learner.withValues(alpha: 0.1),
                        child: Text(
                          widget.submission.learnerInitials,
                          style: const TextStyle(
                            color: ScholesaColors.learner,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              widget.submission.learnerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              widget.submission.missionTitle,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _tEducatorMissionReview(context, 'Submission'),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      widget.submission.submissionPreview,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _tEducatorMissionReview(context, 'Rating'),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List<Widget>.generate(
                      5,
                      (int index) => GestureDetector(
                        onTap: () {
                          TelemetryService.instance.logEvent(
                            event: 'cta.clicked',
                            metadata: <String, dynamic>{
                              'cta': 'educator_mission_review_set_rating',
                              'submission_id': widget.submission.id,
                              'rating': index + 1,
                            },
                          );
                          setState(() => _rating = index + 1);
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                            index < _rating ? Icons.star : Icons.star_border,
                            color: ScholesaColors.warning,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _tEducatorMissionReview(context, 'Feedback'),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: () {
                          final String draft = _buildAiDraft();
                          TelemetryService.instance.logEvent(
                            event: 'cta.clicked',
                            metadata: <String, dynamic>{
                              'cta': 'educator_mission_review_generate_ai_feedback',
                              'submission_id': widget.submission.id,
                            },
                          );
                          setState(() {
                            _aiFeedbackDraft = draft;
                            _feedbackController.text = draft;
                            _feedbackController.selection =
                                TextSelection.collapsed(
                              offset: _feedbackController.text.length,
                            );
                          });
                        },
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: Text(
                          _tEducatorMissionReview(context, 'Generate AI draft'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _tEducatorMissionReview(
                            context,
                            'Generate a coach draft, then edit before sending.',
                          ),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_aiFeedbackDraft != null && _aiFeedbackDraft!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ScholesaColors.educator.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: ScholesaColors.educator.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _tEducatorMissionReview(
                              context,
                              'AI draft ready to edit',
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: ScholesaColors.educator,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _aiFeedbackDraft!,
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _feedbackController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: _tEducatorMissionReview(
                          context, 'Write your feedback for the learner...'),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                  ),
                  if (widget.submission.hasRubric) ...<Widget>[
                    const SizedBox(height: 24),
                    Text(
                      _tEducatorMissionReview(context, 'Rubric'),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (widget.submission.rubricTitle != null &&
                        widget.submission.rubricTitle!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        widget.submission.rubricTitle!,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                    const SizedBox(height: 12),
                    ...widget.submission.rubricCriteria.map((Map<String, dynamic> criterion) {
                      final String criterionId = _criterionId(criterion);
                      final int maxScore = _criterionMaxScore(criterion);
                      final String label =
                          criterion['label'] as String? ?? criterionId;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              label,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: List<Widget>.generate(
                                maxScore + 1,
                                (int score) => ChoiceChip(
                                  label: Text('$score/$maxScore'),
                                  selected:
                                      (_rubricScores[criterionId] ?? 0) == score,
                                  onSelected: (_) {
                                    setState(() => _rubricScores[criterionId] = score);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            TelemetryService.instance.logEvent(
                              event: 'cta.clicked',
                              metadata: <String, dynamic>{
                                'cta':
                                    'educator_mission_review_request_revision',
                                'submission_id': widget.submission.id,
                              },
                            );
                            await _submitReview(
                              context,
                              status: 'revision',
                              fallbackRating: 3,
                              outcome: 'revision',
                              successMessage: 'Revision requested',
                              successColor: ScholesaColors.warning,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ScholesaColors.warning,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side:
                                const BorderSide(color: ScholesaColors.warning),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(_tEducatorMissionReview(
                              context, 'Request Revision')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            TelemetryService.instance.logEvent(
                              event: 'cta.clicked',
                              metadata: <String, dynamic>{
                                'cta': 'educator_mission_review_approve',
                                'submission_id': widget.submission.id,
                              },
                            );
                            await _submitReview(
                              context,
                              status: 'approved',
                              fallbackRating: 5,
                              outcome: 'approved',
                              successMessage: 'Mission approved!',
                              successColor: ScholesaColors.success,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ScholesaColors.success,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child:
                              Text(_tEducatorMissionReview(context, 'Approve')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
