import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';
import '../missions/mission_service.dart';

const Map<String, String> _educatorMissionReviewEs = <String, String>{
  'Mission Review': 'Revisión de misiones',
  'submissions pending review': 'entregas pendientes de revisión',
  'Pending': 'Pendientes',
  'Reviewed': 'Revisadas',
  'Needs Revision': 'Necesita revisión',
  'Approved': 'Aprobadas',
  'Reviewed Today': 'Revisadas hoy',
  'All caught up!': '¡Todo al día!',
  'No submissions matching this filter':
      'No hay entregas que coincidan con este filtro',
  'PENDING': 'PENDIENTE',
  'REVIEWED': 'REVISADA',
  'APPROVED': 'APROBADA',
  'REVISION': 'REVISIÓN',
  'Submission': 'Entrega',
  'Rating': 'Calificación',
  'Feedback': 'Comentarios',
  'Write your feedback for the learner...':
      'Escribe tus comentarios para el estudiante...',
  'Revision requested': 'Revisión solicitada',
  'Request Revision': 'Solicitar revisión',
  'Mission approved!': '¡Misión aprobada!',
  'Approve': 'Aprobar',
};

String _tEducatorMissionReview(BuildContext context, String input) {
  final String locale = Localizations.localeOf(context).languageCode;
  if (locale != 'es') return input;
  return _educatorMissionReviewEs[input] ?? input;
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
            return CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(child: _buildHeader(service)),
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
                else if (_getFilteredSubmissions(service).isEmpty)
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
                              _getFilteredSubmissions(service);
                          if (index >= submissions.length) return null;
                          return _SubmissionCard(
                            submission: submissions[index],
                            onTap: () => _openReviewSheet(submissions[index]),
                          );
                        },
                        childCount: _getFilteredSubmissions(service).length,
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
  int _rating = 0;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
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
                            final MissionService missionService =
                                context.read<MissionService>();
                            final String reviewerId =
                                FirebaseAuth.instance.currentUser?.uid ??
                                    'unknown';
                            final bool success =
                                await missionService.submitReview(
                              submissionId: widget.submission.id,
                              rating: _rating == 0 ? 3 : _rating,
                              feedback: _feedbackController.text.trim(),
                              reviewerId: reviewerId,
                              status: 'revision',
                            );
                            if (!success || !context.mounted) {
                              return;
                            }
                            TelemetryService.instance.logEvent(
                              event: 'educator.review.completed',
                              metadata: <String, dynamic>{
                                'submission_id': widget.submission.id,
                                'mission_id': widget.submission.missionId,
                                'outcome': 'revision',
                                'rating': _rating == 0 ? 3 : _rating,
                                'feedback_length':
                                    _feedbackController.text.trim().length,
                                'turnaround_minutes': DateTime.now()
                                    .difference(widget.submission.submittedAt)
                                    .inMinutes,
                              },
                            );
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(_tEducatorMissionReview(
                                    context, 'Revision requested')),
                                backgroundColor: ScholesaColors.warning,
                              ),
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
                            final MissionService missionService =
                                context.read<MissionService>();
                            final String reviewerId =
                                FirebaseAuth.instance.currentUser?.uid ??
                                    'unknown';
                            final bool success =
                                await missionService.submitReview(
                              submissionId: widget.submission.id,
                              rating: _rating == 0 ? 5 : _rating,
                              feedback: _feedbackController.text.trim(),
                              reviewerId: reviewerId,
                              status: 'approved',
                            );
                            if (!success || !context.mounted) {
                              return;
                            }
                            TelemetryService.instance.logEvent(
                              event: 'educator.review.completed',
                              metadata: <String, dynamic>{
                                'submission_id': widget.submission.id,
                                'mission_id': widget.submission.missionId,
                                'outcome': 'approved',
                                'rating': _rating == 0 ? 5 : _rating,
                                'feedback_length':
                                    _feedbackController.text.trim().length,
                                'turnaround_minutes': DateTime.now()
                                    .difference(widget.submission.submittedAt)
                                    .inMinutes,
                              },
                            );
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(_tEducatorMissionReview(
                                    context, 'Mission approved!')),
                                backgroundColor: ScholesaColors.success,
                              ),
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
