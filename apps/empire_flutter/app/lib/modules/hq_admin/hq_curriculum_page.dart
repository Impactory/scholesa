import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../auth/app_state.dart';
import '../../i18n/shared_role_surface_i18n.dart';
import '../../services/firestore_service.dart';
import '../../services/telemetry_service.dart';
import '../../services/workflow_bridge_service.dart';
import '../../ui/auth/global_session_menu.dart';
import '../../ui/theme/scholesa_theme.dart';

String _tHqCurriculum(BuildContext context, String input) {
  return SharedRoleSurfaceI18n.text(context, input);
}

/// HQ Curriculum page for managing curriculum versions and rubrics
/// Based on docs/45_CURRICULUM_VERSIONING_RUBRICS_SPEC.md
class HqCurriculumPage extends StatefulWidget {
  const HqCurriculumPage({
    super.key,
    this.curriculaLoader,
    this.trainingCyclesLoader,
    this.sessionReadinessLoader,
    this.mappingRequestLoader,
  });

  final Future<List<Map<String, dynamic>>> Function()? curriculaLoader;
  final Future<List<Map<String, dynamic>>> Function()? trainingCyclesLoader;
  final Future<List<Map<String, dynamic>>> Function()? sessionReadinessLoader;
  final Future<List<Map<String, dynamic>>> Function()? mappingRequestLoader;

  @override
  State<HqCurriculumPage> createState() => _HqCurriculumPageState();
}

enum _CurriculumStatus {
  draft,
  review,
  published,
}

class _Curriculum {
  const _Curriculum({
    required this.id,
    required this.title,
    required this.description,
    required this.pillar,
    required this.template,
    required this.difficulty,
    required this.misconceptionTags,
    required this.mediaFormat,
    required this.capabilityIds,
    required this.capabilityTitles,
    required this.version,
    required this.approvalStatus,
    required this.status,
    required this.lastUpdated,
  });

  final String id;
  final String title;
  final String description;
  final String pillar;
  final String template;
  final String difficulty;
  final List<String> misconceptionTags;
  final String mediaFormat;
  final List<String> capabilityIds;
  final List<String> capabilityTitles;
  final String version;
  final String approvalStatus;
  final _CurriculumStatus status;
  final DateTime lastUpdated;
}

class _CapabilityRef {
  const _CapabilityRef({
    required this.id,
    required this.title,
    required this.normalizedTitle,
    required this.pillarCode,
    this.siteId,
    this.descriptor,
  });

  final String id;
  final String title;
  final String normalizedTitle;
  final String pillarCode;
  final String? siteId;
  final String? descriptor;
}

class _TrainingCycle {
  const _TrainingCycle({
    required this.id,
    required this.title,
    required this.trainingType,
    required this.audience,
    required this.termLabel,
    required this.status,
    required this.updatedAt,
    this.siteId,
    this.startsAt,
    this.notes,
  });

  final String id;
  final String title;
  final String trainingType;
  final String audience;
  final String termLabel;
  final String status;
  final DateTime updatedAt;
  final String? siteId;
  final DateTime? startsAt;
  final String? notes;
}

class _SessionCapabilityReadiness {
  const _SessionCapabilityReadiness({
    required this.id,
    required this.title,
    required this.pillar,
    required this.pillarCode,
    required this.startTime,
    required this.mappedCapabilityCount,
    this.siteId,
    this.educator,
  });

  final String id;
  final String title;
  final String pillar;
  final String pillarCode;
  final DateTime startTime;
  final int mappedCapabilityCount;
  final String? siteId;
  final String? educator;

  bool get isBlocked => mappedCapabilityCount <= 0;
}

class _SessionCapabilityMappingRequest {
  const _SessionCapabilityMappingRequest({
    required this.id,
    required this.sessionId,
    required this.sessionTitle,
    required this.pillar,
    required this.siteId,
    required this.requesterName,
    required this.requesterRole,
    required this.submittedAt,
    this.message,
  });

  final String id;
  final String sessionId;
  final String sessionTitle;
  final String pillar;
  final String siteId;
  final String requesterName;
  final String requesterRole;
  final DateTime submittedAt;
  final String? message;
}

class _MappingResolutionDetails {
  const _MappingResolutionDetails({
    required this.summary,
    required this.operatorNote,
    required this.supportingCapabilityCount,
    required this.supportingCapabilityIds,
    required this.supportingCapabilityTitles,
    required this.supportingCurriculumIds,
    required this.supportingCurriculumTitles,
    required this.pillarCode,
  });

  final String summary;
  final String operatorNote;
  final int supportingCapabilityCount;
  final List<String> supportingCapabilityIds;
  final List<String> supportingCapabilityTitles;
  final List<String> supportingCurriculumIds;
  final List<String> supportingCurriculumTitles;
  final String pillarCode;
}

class _CurriculumEvidenceRef {
  const _CurriculumEvidenceRef({
    required this.id,
    required this.title,
  });

  final String id;
  final String title;
}

class _HqCurriculumPageState extends State<HqCurriculumPage>
    with SingleTickerProviderStateMixin {
  static const List<String> _templateOptions = <String>[
    'Project sprint',
    'Guided lab',
    'Seminar',
  ];
  static const List<String> _difficultyOptions = <String>[
    'Beginner',
    'Intermediate',
    'Advanced',
  ];
  static const List<String> _mediaFormatOptions = <String>[
    'Mixed media',
    'Video',
    'Slide deck',
    'Worksheet',
  ];
  final WorkflowBridgeService _workflowBridgeService =
      WorkflowBridgeService.instance;
  late TabController _tabController;
  bool _isLoading = false;
  String? _curriculaError;
  String? _trainingCyclesError;
  bool _isLoadingSessionReadiness = false;
  String? _sessionReadinessError;
  bool _isLoadingMappingRequests = false;
  String? _mappingRequestError;
  final Set<String> _resolvingMappingRequestIds = <String>{};

  List<_Curriculum> _curricula = <_Curriculum>[];
  List<_TrainingCycle> _trainingCycles = <_TrainingCycle>[];
  List<_SessionCapabilityReadiness> _sessionReadiness =
      <_SessionCapabilityReadiness>[];
  List<_SessionCapabilityMappingRequest> _mappingRequests =
      <_SessionCapabilityMappingRequest>[];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurricula();
      _loadTrainingCycles();
      _loadSessionReadiness();
      _loadMappingRequests();
    });
  }

  Future<void> _refreshCurriculumSurface() async {
    await Future.wait<void>(<Future<void>>[
      _loadCurricula(),
      _loadTrainingCycles(),
      _loadSessionReadiness(),
      _loadMappingRequests(),
    ]);
  }

  Widget _buildLoadErrorState({
    required String title,
    required String message,
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ScholesaColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: ScholesaColors.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: ScholesaColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(_tHqCurriculum(context, 'Retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaleDataBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
              message,
              style: const TextStyle(color: ScholesaColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: Text(_tHqCurriculum(context, 'Curriculum Manager')),
        backgroundColor: ScholesaColors.hqGradient.colors.first,
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            onPressed: _refreshCurriculumSurface,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: _tHqCurriculum(context, 'Refresh'),
          ),
          IconButton(
            onPressed: _showTrainingCyclesSheet,
            icon: const Icon(Icons.school_rounded),
          ),
          const SessionMenuButton(
            foregroundColor: Colors.white,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          onTap: (int index) {
            final String tab = switch (index) {
              0 => 'published',
              1 => 'in_review',
              2 => 'drafts',
              _ => 'unknown',
            };
            TelemetryService.instance.logEvent(
              event: 'cta.clicked',
              metadata: <String, dynamic>{
                'module': 'hq_curriculum',
                'cta_id': 'change_tab',
                'surface': 'appbar_tab_bar',
                'tab': tab,
              },
            );
          },
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: <Widget>[
            Tab(text: _tHqCurriculum(context, 'Published')),
            Tab(text: _tHqCurriculum(context, 'In Review')),
            Tab(text: _tHqCurriculum(context, 'Drafts')),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          TelemetryService.instance.logEvent(
            event: 'cta.clicked',
            metadata: <String, dynamic>{
              'module': 'hq_curriculum',
              'cta_id': 'open_create_curriculum_dialog',
              'surface': 'floating_action_button',
            },
          );
          _showCreateDialog();
        },
        backgroundColor: ScholesaColors.hqGradient.colors.first,
        icon: const Icon(Icons.add_rounded),
        label: Text(_tHqCurriculum(context, 'New Curriculum')),
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double maxPanelHeight = constraints.maxHeight * 0.45;
          return Column(
            children: <Widget>[
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxPanelHeight),
                child: SingleChildScrollView(
                  child: Column(
                    children: <Widget>[
                      _buildSessionCapabilityReadinessPanel(),
                      _buildCapabilityMappingRequestsPanel(),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: <Widget>[
                    _buildCurriculumList(_CurriculumStatus.published),
                    _buildCurriculumList(_CurriculumStatus.review),
                    _buildCurriculumList(_CurriculumStatus.draft),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSessionCapabilityReadinessPanel() {
    if (_isLoadingSessionReadiness && _sessionReadiness.isEmpty) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ScholesaColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ScholesaColors.border),
        ),
        child: Row(
          children: <Widget>[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _tHqCurriculum(
                  context,
                  'Checking upcoming session capability coverage...',
                ),
                style: const TextStyle(color: ScholesaColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    if (_sessionReadinessError != null && _sessionReadiness.isEmpty) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4F4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.error_outline_rounded,
                  color: ScholesaColors.error,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _tHqCurriculum(
                      context,
                      'Session capability coverage is temporarily unavailable',
                    ),
                    style: const TextStyle(
                      color: ScholesaColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _sessionReadinessError!,
              style: const TextStyle(color: ScholesaColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_sessionReadiness.isEmpty) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ScholesaColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ScholesaColors.border),
        ),
        child: Text(
          _tHqCurriculum(
            context,
            'No upcoming sessions need capability coverage review right now.',
          ),
          style: const TextStyle(color: ScholesaColors.textSecondary),
        ),
      );
    }

    final List<_SessionCapabilityReadiness> visibleSessions =
        _sessionReadiness.take(6).toList(growable: false);
    final int blockedCount = _sessionReadiness
        .where((_SessionCapabilityReadiness entry) => entry.isBlocked)
        .length;
    final int readyCount = _sessionReadiness.length - blockedCount;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ScholesaColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: blockedCount > 0
              ? Colors.orange.withValues(alpha: 0.4)
              : ScholesaColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                blockedCount > 0
                    ? Icons.warning_amber_rounded
                    : Icons.verified_rounded,
                color: blockedCount > 0 ? Colors.orange : Colors.green,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _tHqCurriculum(
                        context,
                        'Upcoming session capability coverage',
                      ),
                      style: const TextStyle(
                        color: ScholesaColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      blockedCount > 0
                          ? '$blockedCount ${_tHqCurriculum(context, 'blocked')} • $readyCount ${_tHqCurriculum(context, 'ready')}'
                          : _tHqCurriculum(
                              context,
                              'All upcoming sessions currently have mapped capability coverage.',
                            ),
                      style: const TextStyle(
                        color: ScholesaColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_sessionReadinessError != null) ...<Widget>[
            const SizedBox(height: 12),
            _buildStaleDataBanner(
              _tHqCurriculum(
                context,
                'Unable to refresh session capability coverage right now. Showing the last successful data.',
              ),
            ),
          ],
          const SizedBox(height: 12),
          ...visibleSessions.map(_buildSessionReadinessRow),
          if (_sessionReadiness.length > visibleSessions.length) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              '${_tHqCurriculum(context, 'Showing next')} ${visibleSessions.length} ${_tHqCurriculum(context, 'of')} ${_sessionReadiness.length} ${_tHqCurriculum(context, 'upcoming sessions')}',
              style: const TextStyle(
                color: ScholesaColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSessionReadinessRow(_SessionCapabilityReadiness readiness) {
    final _Curriculum? recommendedCurriculum =
        _recommendedCurriculumForPillar(readiness.pillar);
    final String coverageLabel = readiness.mappedCapabilityCount == 1
        ? _tHqCurriculum(context, '1 mapped capability')
        : '${readiness.mappedCapabilityCount} ${_tHqCurriculum(context, 'mapped capabilities')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: readiness.isBlocked
            ? Colors.orange.withValues(alpha: 0.08)
            : Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: readiness.isBlocked
              ? Colors.orange.withValues(alpha: 0.25)
              : Colors.green.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      readiness.title,
                      style: const TextStyle(
                        color: ScholesaColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_tHqCurriculum(context, readiness.pillar)} • ${_formatSessionStart(readiness.startTime)}',
                      style: const TextStyle(
                        color: ScholesaColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if ((readiness.educator ?? '')
                        .trim()
                        .isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        '${_tHqCurriculum(context, 'Educator')}: ${readiness.educator!.trim()}',
                        style: const TextStyle(
                          color: ScholesaColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if ((readiness.siteId ?? '').trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        '${_tHqCurriculum(context, 'Site')}: ${readiness.siteId!.trim()}',
                        style: const TextStyle(
                          color: ScholesaColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildCoverageStatusBadge(readiness),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            coverageLabel,
            style: TextStyle(
              color: readiness.isBlocked
                  ? const Color(0xFF9A3412)
                  : const Color(0xFF166534),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (readiness.isBlocked) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _tHqCurriculum(
                context,
                'Educators will be blocked from live evidence capture until this pillar has at least one mapped capability.',
              ),
              style: const TextStyle(
                color: ScholesaColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _openCapabilityMappingWorkflow(
                  readiness,
                  recommendedCurriculum: recommendedCurriculum,
                ),
                icon: Icon(
                  recommendedCurriculum == null
                      ? Icons.add_task_rounded
                      : Icons.edit_rounded,
                ),
                label: Text(
                  recommendedCurriculum == null
                      ? _tHqCurriculum(context, 'Create mapped curriculum')
                      : _tHqCurriculum(context, 'Open mapping workflow'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCoverageStatusBadge(_SessionCapabilityReadiness readiness) {
    final Color foreground =
        readiness.isBlocked ? const Color(0xFF9A3412) : const Color(0xFF166534);
    final Color background =
        readiness.isBlocked ? const Color(0xFFFFEDD5) : const Color(0xFFDCFCE7);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        readiness.isBlocked
            ? _tHqCurriculum(context, 'Blocked')
            : _tHqCurriculum(context, 'Ready'),
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildCapabilityMappingRequestsPanel() {
    if (_isLoadingMappingRequests && _mappingRequests.isEmpty) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ScholesaColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ScholesaColors.border),
        ),
        child: Row(
          children: <Widget>[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _tHqCurriculum(context, 'Loading HQ mapping requests...'),
                style: const TextStyle(color: ScholesaColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    if (_mappingRequestError != null && _mappingRequests.isEmpty) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4F4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _tHqCurriculum(
                context,
                'HQ mapping request queue is temporarily unavailable',
              ),
              style: const TextStyle(
                color: ScholesaColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _mappingRequestError!,
              style: const TextStyle(color: ScholesaColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_mappingRequests.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ScholesaColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ScholesaColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _tHqCurriculum(context, 'HQ mapping requests'),
            style: const TextStyle(
              color: ScholesaColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_mappingRequests.length} ${_tHqCurriculum(context, 'open school escalations are waiting for curriculum mapping follow-through.')}',
            style: const TextStyle(color: ScholesaColors.textSecondary),
          ),
          if (_mappingRequestError != null) ...<Widget>[
            const SizedBox(height: 12),
            _buildStaleDataBanner(
              _tHqCurriculum(
                context,
                'Unable to refresh HQ mapping requests right now. Showing the last successful data.',
              ),
            ),
          ],
          const SizedBox(height: 12),
          ..._mappingRequests.map(_buildMappingRequestRow),
        ],
      ),
    );
  }

  Widget _buildMappingRequestRow(_SessionCapabilityMappingRequest request) {
    final _SessionCapabilityReadiness? readiness =
        _readinessForSessionId(request.sessionId);
    final bool isResolving = _resolvingMappingRequestIds.contains(request.id);
    final bool canResolve = readiness == null || !readiness.isBlocked;
    final String statusLabel = readiness == null
        ? _tHqCurriculum(context, 'Needs manual review')
        : readiness.isBlocked
            ? _tHqCurriculum(context, 'Awaiting mapping')
            : _tHqCurriculum(context, 'Ready to resolve');
    final Color statusColor = readiness == null
        ? ScholesaColors.primary
        : readiness.isBlocked
            ? Colors.orange
            : Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ScholesaColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ScholesaColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  request.sessionTitle,
                  style: const TextStyle(
                    color: ScholesaColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_tHqCurriculum(context, request.pillar)} • ${_tHqCurriculum(context, 'Site')}: ${request.siteId}',
            style: const TextStyle(
              color: ScholesaColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_tHqCurriculum(context, 'Requested by')} ${request.requesterName} (${request.requesterRole}) • ${_formatTime(request.submittedAt)}',
            style: const TextStyle(
              color: ScholesaColors.textSecondary,
              fontSize: 12,
            ),
          ),
          if ((request.message ?? '').trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              request.message!.trim(),
              style: const TextStyle(
                color: ScholesaColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () =>
                    _openCapabilityMappingWorkflowForRequest(request),
                icon: const Icon(Icons.edit_rounded),
                label: Text(_tHqCurriculum(context, 'Open mapping workflow')),
              ),
              FilledButton.icon(
                onPressed: isResolving || !canResolve
                    ? null
                    : () => _showResolveMappingRequestDialog(request),
                icon: isResolving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(_tHqCurriculum(context, 'Resolve request')),
              ),
            ],
          ),
          if (!canResolve) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _tHqCurriculum(
                context,
                'This request cannot be resolved until mapped capability coverage is available for the session pillar.',
              ),
              style: const TextStyle(
                color: ScholesaColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCurriculumList(_CurriculumStatus status) {
    if (_isLoading) {
      return Center(
        child: Text(
          _tHqCurriculum(context, 'Loading...'),
          style: const TextStyle(color: ScholesaColors.textSecondary),
        ),
      );
    }

    final List<_Curriculum> filtered =
        _curricula.where((_Curriculum c) => c.status == status).toList();

    if (_curriculaError != null && _curricula.isEmpty) {
      return _buildLoadErrorState(
        title: _tHqCurriculum(context, 'Curricula are temporarily unavailable'),
        message: _curriculaError!,
        onRetry: _refreshCurriculumSurface,
      );
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (_curriculaError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildStaleDataBanner(
                  _tHqCurriculum(
                    context,
                    'Unable to refresh curricula right now. Showing the last successful data.',
                  ),
                ),
              ),
            Icon(Icons.menu_book_rounded,
                size: 64,
                color: ScholesaColors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
                '${_tHqCurriculum(context, 'No')} ${_tHqCurriculum(context, status.name)} ${_tHqCurriculum(context, 'curricula')}',
                style: const TextStyle(color: ScholesaColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length + (_curriculaError != null ? 1 : 0),
      itemBuilder: (BuildContext context, int index) {
        if (_curriculaError != null && index == 0) {
          return _buildStaleDataBanner(
            _tHqCurriculum(
              context,
              'Unable to refresh curricula right now. Showing the last successful data.',
            ),
          );
        }
        final int curriculumIndex = index - (_curriculaError != null ? 1 : 0);
        return _buildCurriculumCard(filtered[curriculumIndex]);
      },
    );
  }

  Widget _buildCurriculumCard(_Curriculum curriculum) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showCurriculumDetails(curriculum),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _buildPillarIcon(curriculum.pillar),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(curriculum.title,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(_tHqCurriculum(context, curriculum.pillar),
                            style: TextStyle(
                                fontSize: 12,
                                color: _getPillarColor(curriculum.pillar))),
                        if (curriculum.description.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 6),
                          Text(
                            curriculum.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: ScholesaColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ScholesaColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                        '${_tHqCurriculum(context, 'v')}${curriculum.version}',
                        style: const TextStyle(
                            fontSize: 12, color: ScholesaColors.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _buildInfoBadge(_tHqCurriculum(context, curriculum.template)),
                  _buildInfoBadge(
                    _tHqCurriculum(context, curriculum.difficulty),
                  ),
                  _buildInfoBadge(
                    _tHqCurriculum(context, curriculum.mediaFormat),
                  ),
                  _buildInfoBadge(
                    _tHqCurriculum(context, curriculum.approvalStatus),
                  ),
                  ...curriculum.capabilityTitles.map((String capabilityTitle) =>
                      _buildInfoBadge(capabilityTitle)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${_tHqCurriculum(context, 'Updated')} ${_formatTime(curriculum.lastUpdated)}',
                style: const TextStyle(
                    fontSize: 12, color: ScholesaColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ScholesaColors.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ScholesaColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: ScholesaColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPillarIcon(String pillar) {
    IconData icon;
    Color color = _getPillarColor(pillar);
    switch (pillar) {
      case 'Future Skills':
        icon = Icons.psychology_rounded;
      case 'Leadership & Agency':
        icon = Icons.groups_rounded;
      case 'Impact & Innovation':
        icon = Icons.lightbulb_rounded;
      default:
        icon = Icons.star_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Color _getPillarColor(String pillar) {
    switch (pillar) {
      case 'Future Skills':
        return Colors.blue;
      case 'Leadership & Agency':
        return Colors.purple;
      case 'Impact & Innovation':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _showCurriculumDetails(_Curriculum curriculum) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'hq_curriculum',
        'cta_id': 'open_curriculum_details',
        'surface': 'curriculum_card',
        'curriculum_id': curriculum.id,
        'status': curriculum.status.name,
      },
    );
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ScholesaColors.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(curriculum.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: ScholesaColors.textPrimary,
                  )),
              const SizedBox(height: 8),
              Text(_tHqCurriculum(context, curriculum.pillar),
                  style: TextStyle(
                    color: _getPillarColor(curriculum.pillar),
                    fontWeight: FontWeight.w600,
                  )),
              const SizedBox(height: 16),
              _buildDetailRow(
                  _tHqCurriculum(context, 'Version'), curriculum.version),
              _buildDetailRow(
                  _tHqCurriculum(context, 'Status'),
                  _tHqCurriculum(context, curriculum.status.name)
                      .toUpperCase()),
              _buildDetailRow(_tHqCurriculum(context, 'Template'),
                  _tHqCurriculum(context, curriculum.template)),
              _buildDetailRow(_tHqCurriculum(context, 'Difficulty'),
                  _tHqCurriculum(context, curriculum.difficulty)),
              _buildDetailRow(_tHqCurriculum(context, 'Media format'),
                  _tHqCurriculum(context, curriculum.mediaFormat)),
              _buildDetailRow(_tHqCurriculum(context, 'Approval status'),
                  _tHqCurriculum(context, curriculum.approvalStatus)),
              _buildDetailRow(_tHqCurriculum(context, 'Updated'),
                  _formatTime(curriculum.lastUpdated)),
              if (curriculum.description.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  _tHqCurriculum(context, 'Description'),
                  style: const TextStyle(
                    color: ScholesaColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  curriculum.description,
                  style: const TextStyle(color: ScholesaColors.textPrimary),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                _tHqCurriculum(context, 'Misconception tags'),
                style: const TextStyle(
                  color: ScholesaColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: curriculum.misconceptionTags.isEmpty
                    ? <Widget>[
                        Text(
                          _tHqCurriculum(context, 'No misconception tags'),
                          style: const TextStyle(
                            color: ScholesaColors.textSecondary,
                          ),
                        ),
                      ]
                    : curriculum.misconceptionTags
                        .map((String tag) => _buildInfoBadge(tag))
                        .toList(),
              ),
              const SizedBox(height: 12),
              Text(
                _tHqCurriculum(context, 'Capability mappings'),
                style: const TextStyle(
                  color: ScholesaColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: curriculum.capabilityTitles.isEmpty
                    ? <Widget>[
                        Text(
                          _tHqCurriculum(context, 'No capability mappings'),
                          style: const TextStyle(
                            color: ScholesaColors.textSecondary,
                          ),
                        ),
                      ]
                    : curriculum.capabilityTitles
                        .map((String title) => _buildInfoBadge(title))
                        .toList(),
              ),
              const SizedBox(height: 24),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ScholesaColors.textPrimary,
                        side: const BorderSide(color: ScholesaColors.border),
                      ),
                      onPressed: () {
                        TelemetryService.instance.logEvent(
                          event: 'cta.clicked',
                          metadata: <String, dynamic>{
                            'module': 'hq_curriculum',
                            'cta_id': 'close_curriculum_details',
                            'surface': 'curriculum_details_sheet',
                            'curriculum_id': curriculum.id,
                          },
                        );
                        Navigator.pop(context);
                      },
                      child: Text(_tHqCurriculum(context, 'Close')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ScholesaColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        TelemetryService.instance.logEvent(
                          event: 'cta.clicked',
                          metadata: <String, dynamic>{
                            'module': 'hq_curriculum',
                            'cta_id': 'open_curriculum_editor',
                            'surface': 'curriculum_details_sheet',
                            'curriculum_id': curriculum.id,
                          },
                        );
                        Navigator.pop(context);
                        _showEditDialog(curriculum);
                      },
                      child: Text(_tHqCurriculum(context, 'Edit')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ScholesaColors.hq,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: <String, dynamic>{
                        'module': 'hq_curriculum',
                        'cta_id': 'create_mission_snapshot',
                        'surface': 'curriculum_details_sheet',
                        'curriculum_id': curriculum.id,
                      },
                    );
                    Navigator.pop(context);
                    await _createMissionSnapshot(curriculum);
                  },
                  icon: const Icon(Icons.copy_all_rounded),
                  label: Text(_tHqCurriculum(context, 'Create Snapshot')),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: _buildAdvanceStatusButton(curriculum),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ScholesaColors.textPrimary,
                    side: const BorderSide(color: ScholesaColors.border),
                  ),
                  onPressed: () async {
                    TelemetryService.instance.logEvent(
                      event: 'rubric.applied',
                      metadata: <String, dynamic>{
                        'module': 'hq_curriculum',
                        'curriculum_id': curriculum.id,
                        'source': 'curriculum_details_sheet',
                      },
                    );
                    Navigator.pop(context);
                    _showRubricWorkflowDialog(curriculum);
                  },
                  icon: const Icon(Icons.rule_rounded),
                  label: Text(_tHqCurriculum(context, 'Apply Rubric')),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ScholesaColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    TelemetryService.instance.logEvent(
                      event: 'rubric.marked_parent_summary_ready',
                      metadata: <String, dynamic>{
                        'module': 'hq_curriculum',
                        'curriculum_id': curriculum.id,
                        'source': 'curriculum_details_sheet',
                      },
                    );
                    Navigator.pop(context);
                    await _markParentSummaryReady(curriculum);
                  },
                  icon: const Icon(Icons.share_rounded),
                  label: Text(
                    _tHqCurriculum(context, 'Mark Parent Summary Ready'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdvanceStatusButton(_Curriculum curriculum) {
    final _CurriculumStatus? targetStatus = _nextStatus(curriculum.status);
    if (targetStatus == null) {
      return const SizedBox.shrink();
    }

    final bool isPublishing = targetStatus == _CurriculumStatus.published;
    final String label = isPublishing
        ? _tHqCurriculum(context, 'Publish Curriculum')
        : _tHqCurriculum(context, 'Submit for Review');

    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: ScholesaColors.primary,
        foregroundColor: Colors.white,
      ),
      onPressed: () async {
        TelemetryService.instance.logEvent(
          event: 'curriculum.status.transition',
          metadata: <String, dynamic>{
            'module': 'hq_curriculum',
            'curriculum_id': curriculum.id,
            'from_status': curriculum.status.name,
            'to_status': targetStatus.name,
            'source': 'curriculum_details_sheet',
          },
        );
        Navigator.pop(context);
        await _advanceCurriculumStatus(curriculum, targetStatus);
      },
      icon: Icon(
        isPublishing ? Icons.publish_rounded : Icons.rate_review_rounded,
      ),
      label: Text(label),
    );
  }

  _CurriculumStatus? _nextStatus(_CurriculumStatus current) {
    switch (current) {
      case _CurriculumStatus.draft:
        return _CurriculumStatus.review;
      case _CurriculumStatus.review:
        return _CurriculumStatus.published;
      case _CurriculumStatus.published:
        return null;
    }
  }

  Future<void> _advanceCurriculumStatus(
    _Curriculum curriculum,
    _CurriculumStatus targetStatus,
  ) async {
    final FirestoreService? firestoreService = _maybeFirestoreService();
    final AppState? appState = _maybeAppState();
    if (firestoreService == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tHqCurriculum(context, 'Transition failed'))),
      );
      return;
    }

    final DateTime now = DateTime.now();
    final bool isPublishing = targetStatus == _CurriculumStatus.published;

    try {
      final Map<String, dynamic> updates = <String, dynamic>{
        'status': targetStatus.name,
        'published': isPublishing,
        'approvalStatus': isPublishing ? 'approved' : 'in_review',
      };

      if (targetStatus == _CurriculumStatus.review) {
        updates['reviewSubmittedAt'] = FieldValue.serverTimestamp();
        updates['reviewSubmittedBy'] = appState?.userId;
      }

      if (isPublishing) {
        updates['publishedAt'] = FieldValue.serverTimestamp();
        updates['publishedBy'] = appState?.userId;
      }

      await firestoreService.updateDocument('missions', curriculum.id, updates);

      _replaceLocalCurriculum(
        curriculum.id,
        approvalStatus: isPublishing ? 'approved' : 'in_review',
        status: targetStatus,
        lastUpdated: now,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tHqCurriculum(
              context,
              isPublishing ? 'Curriculum published' : 'Moved to In Review',
            ),
          ),
        ),
      );

      if (_tabController.index != targetStatus.index) {
        _tabController.animateTo(targetStatus.index);
      }

      await _loadCurricula();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tHqCurriculum(context, 'Transition failed'))),
      );
    }
  }

  void _showEditDialog(_Curriculum curriculum) {
    final TextEditingController titleController =
        TextEditingController(text: curriculum.title);
    final TextEditingController descriptionController =
        TextEditingController(text: curriculum.description);
    final TextEditingController misconceptionTagsController =
        TextEditingController(text: curriculum.misconceptionTags.join(', '));
    final TextEditingController capabilityMappingsController =
        TextEditingController(text: curriculum.capabilityTitles.join(', '));
    String selectedPillar = curriculum.pillar;
    String selectedTemplate = curriculum.template;
    String selectedDifficulty = curriculum.difficulty;
    String selectedMediaFormat = curriculum.mediaFormat;
    bool isSubmitting = false;

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context,
            void Function(void Function()) setLocalState) {
          return AlertDialog(
            backgroundColor: ScholesaColors.surface,
            surfaceTintColor: ScholesaColors.surface,
            scrollable: true,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            title: Text(_tHqCurriculum(context, 'Edit')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  controller: titleController,
                  style: const TextStyle(
                    color: ScholesaColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    labelText: _tHqCurriculum(context, 'Title'),
                    labelStyle:
                        const TextStyle(color: ScholesaColors.textSecondary),
                    filled: true,
                    fillColor: ScholesaColors.surfaceVariant,
                    border: const OutlineInputBorder(),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: ScholesaColors.border),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide:
                          BorderSide(color: ScholesaColors.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  style: const TextStyle(
                    color: ScholesaColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    labelText: _tHqCurriculum(context, 'Description'),
                    labelStyle:
                        const TextStyle(color: ScholesaColors.textSecondary),
                    filled: true,
                    fillColor: ScholesaColors.surfaceVariant,
                    border: const OutlineInputBorder(),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: ScholesaColors.border),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide:
                          BorderSide(color: ScholesaColors.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedPillar,
                  style: const TextStyle(
                    color: ScholesaColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  dropdownColor: ScholesaColors.surface,
                  iconEnabledColor: ScholesaColors.textSecondary,
                  decoration: InputDecoration(
                    labelText: _tHqCurriculum(context, 'Pillar'),
                    labelStyle:
                        const TextStyle(color: ScholesaColors.textSecondary),
                    filled: true,
                    fillColor: ScholesaColors.surfaceVariant,
                    border: const OutlineInputBorder(),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: ScholesaColors.border),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide:
                          BorderSide(color: ScholesaColors.primary, width: 1.5),
                    ),
                  ),
                  items: <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                      value: 'Future Skills',
                      child: Text(_tHqCurriculum(context, 'Future Skills')),
                    ),
                    DropdownMenuItem<String>(
                      value: 'Leadership & Agency',
                      child:
                          Text(_tHqCurriculum(context, 'Leadership & Agency')),
                    ),
                    DropdownMenuItem<String>(
                      value: 'Impact & Innovation',
                      child:
                          Text(_tHqCurriculum(context, 'Impact & Innovation')),
                    ),
                  ],
                  onChanged: (String? value) {
                    if (value != null) {
                      setLocalState(() => selectedPillar = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedTemplate,
                  decoration: _dialogDecoration(context, 'Template'),
                  items: _templateOptions
                      .map((String option) => DropdownMenuItem<String>(
                            value: option,
                            child: Text(_tHqCurriculum(context, option)),
                          ))
                      .toList(),
                  onChanged: (String? value) {
                    if (value != null) {
                      setLocalState(() => selectedTemplate = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedDifficulty,
                  decoration: _dialogDecoration(context, 'Difficulty'),
                  items: _difficultyOptions
                      .map((String option) => DropdownMenuItem<String>(
                            value: option,
                            child: Text(_tHqCurriculum(context, option)),
                          ))
                      .toList(),
                  onChanged: (String? value) {
                    if (value != null) {
                      setLocalState(() => selectedDifficulty = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedMediaFormat,
                  decoration: _dialogDecoration(context, 'Media format'),
                  items: _mediaFormatOptions
                      .map((String option) => DropdownMenuItem<String>(
                            value: option,
                            child: Text(_tHqCurriculum(context, option)),
                          ))
                      .toList(),
                  onChanged: (String? value) {
                    if (value != null) {
                      setLocalState(() => selectedMediaFormat = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: misconceptionTagsController,
                  style: const TextStyle(
                    color: ScholesaColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: _dialogDecoration(context, 'Misconception tags'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: capabilityMappingsController,
                  minLines: 2,
                  maxLines: 4,
                  style: const TextStyle(
                    color: ScholesaColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: _dialogDecoration(
                    context,
                    'Capability statements (comma-separated)',
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: ScholesaColors.textPrimary,
                ),
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(_tHqCurriculum(context, 'Cancel')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ScholesaColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final String title = titleController.text.trim();
                        final List<String> capabilityLabels =
                            _splitCommaSeparated(
                          capabilityMappingsController.text,
                        );
                        if (title.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  _tHqCurriculum(context, 'Title is required')),
                            ),
                          );
                          return;
                        }
                        if (capabilityLabels.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_tHqCurriculum(
                                context,
                                'At least one capability mapping is required',
                              )),
                            ),
                          );
                          return;
                        }

                        setLocalState(() => isSubmitting = true);
                        final bool updated = await _updateCurriculum(
                          curriculum,
                          title: title,
                          description: descriptionController.text.trim(),
                          pillar: selectedPillar,
                          template: selectedTemplate,
                          difficulty: selectedDifficulty,
                          misconceptionTags: _splitCommaSeparated(
                            misconceptionTagsController.text,
                          ),
                          mediaFormat: selectedMediaFormat,
                          capabilityLabels: capabilityLabels,
                        );
                        if (!mounted || !dialogContext.mounted) return;
                        if (updated) {
                          Navigator.pop(dialogContext);
                        } else {
                          setLocalState(() => isSubmitting = false);
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_tHqCurriculum(context, 'Edit')),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label,
              style: const TextStyle(
                color: ScholesaColors.textSecondary,
                fontWeight: FontWeight.w600,
              )),
          Text(
            value,
            style: const TextStyle(
              color: ScholesaColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _dialogDecoration(BuildContext context, String label) {
    return InputDecoration(
      labelText: _tHqCurriculum(context, label),
      labelStyle: const TextStyle(color: ScholesaColors.textSecondary),
      filled: true,
      fillColor: ScholesaColors.surfaceVariant,
      border: const OutlineInputBorder(),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: ScholesaColors.border),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: ScholesaColors.primary, width: 1.5),
      ),
    );
  }

  List<String> _splitCommaSeparated(String raw) {
    return raw
        .split(',')
        .map((String entry) => entry.trim())
        .where((String entry) => entry.isNotEmpty)
        .toList();
  }

  void _showCreateDialog({String? initialPillar}) {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController misconceptionTagsController =
        TextEditingController();
    final TextEditingController capabilityMappingsController =
        TextEditingController();
    String selectedPillar = initialPillar ?? 'Future Skills';
    String selectedTemplate = _templateOptions.first;
    String selectedDifficulty = _difficultyOptions[1];
    String selectedMediaFormat = _mediaFormatOptions.first;
    bool isSubmitting = false;

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context,
            void Function(void Function()) setLocalState) {
          return AlertDialog(
            backgroundColor: ScholesaColors.surface,
            surfaceTintColor: ScholesaColors.surface,
            scrollable: true,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            title: Text(_tHqCurriculum(context, 'New Curriculum')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  controller: titleController,
                  style: const TextStyle(
                    color: ScholesaColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    labelText: _tHqCurriculum(context, 'Title'),
                    labelStyle:
                        const TextStyle(color: ScholesaColors.textSecondary),
                    filled: true,
                    fillColor: ScholesaColors.surfaceVariant,
                    border: const OutlineInputBorder(),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: ScholesaColors.border),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide:
                          BorderSide(color: ScholesaColors.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  style: const TextStyle(
                    color: ScholesaColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: _dialogDecoration(context, 'Description'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedPillar,
                  style: const TextStyle(
                    color: ScholesaColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  dropdownColor: ScholesaColors.surface,
                  iconEnabledColor: ScholesaColors.textSecondary,
                  decoration: InputDecoration(
                    labelText: _tHqCurriculum(context, 'Pillar'),
                    labelStyle:
                        const TextStyle(color: ScholesaColors.textSecondary),
                    filled: true,
                    fillColor: ScholesaColors.surfaceVariant,
                    border: const OutlineInputBorder(),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: ScholesaColors.border),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide:
                          BorderSide(color: ScholesaColors.primary, width: 1.5),
                    ),
                  ),
                  items: <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                      value: 'Future Skills',
                      child: Text(_tHqCurriculum(context, 'Future Skills')),
                    ),
                    DropdownMenuItem<String>(
                      value: 'Leadership & Agency',
                      child:
                          Text(_tHqCurriculum(context, 'Leadership & Agency')),
                    ),
                    DropdownMenuItem<String>(
                      value: 'Impact & Innovation',
                      child:
                          Text(_tHqCurriculum(context, 'Impact & Innovation')),
                    ),
                  ],
                  onChanged: (String? value) {
                    if (value != null) {
                      setLocalState(() => selectedPillar = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedTemplate,
                  decoration: _dialogDecoration(context, 'Template'),
                  items: _templateOptions
                      .map((String option) => DropdownMenuItem<String>(
                            value: option,
                            child: Text(_tHqCurriculum(context, option)),
                          ))
                      .toList(),
                  onChanged: (String? value) {
                    if (value != null) {
                      setLocalState(() => selectedTemplate = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedDifficulty,
                  decoration: _dialogDecoration(context, 'Difficulty'),
                  items: _difficultyOptions
                      .map((String option) => DropdownMenuItem<String>(
                            value: option,
                            child: Text(_tHqCurriculum(context, option)),
                          ))
                      .toList(),
                  onChanged: (String? value) {
                    if (value != null) {
                      setLocalState(() => selectedDifficulty = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedMediaFormat,
                  decoration: _dialogDecoration(context, 'Media format'),
                  items: _mediaFormatOptions
                      .map((String option) => DropdownMenuItem<String>(
                            value: option,
                            child: Text(_tHqCurriculum(context, option)),
                          ))
                      .toList(),
                  onChanged: (String? value) {
                    if (value != null) {
                      setLocalState(() => selectedMediaFormat = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: misconceptionTagsController,
                  style: const TextStyle(
                    color: ScholesaColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: _dialogDecoration(context, 'Misconception tags'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: capabilityMappingsController,
                  minLines: 2,
                  maxLines: 4,
                  style: const TextStyle(
                    color: ScholesaColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: _dialogDecoration(
                    context,
                    'Capability statements (comma-separated)',
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: ScholesaColors.textPrimary,
                ),
                onPressed: () {
                  TelemetryService.instance.logEvent(
                    event: 'cta.clicked',
                    metadata: const <String, dynamic>{
                      'module': 'hq_curriculum',
                      'cta_id': 'cancel_create_curriculum',
                      'surface': 'create_curriculum_dialog',
                    },
                  );
                  Navigator.pop(dialogContext);
                },
                child: Text(_tHqCurriculum(context, 'Cancel')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ScholesaColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final String title = titleController.text.trim();
                        final List<String> capabilityLabels =
                            _splitCommaSeparated(
                          capabilityMappingsController.text,
                        );
                        if (title.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(_tHqCurriculum(
                                    context, 'Title is required'))),
                          );
                          return;
                        }
                        if (capabilityLabels.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_tHqCurriculum(
                                context,
                                'At least one capability mapping is required',
                              )),
                            ),
                          );
                          return;
                        }

                        setLocalState(() => isSubmitting = true);

                        TelemetryService.instance.logEvent(
                          event: 'cta.clicked',
                          metadata: const <String, dynamic>{
                            'module': 'hq_curriculum',
                            'cta_id': 'submit_create_curriculum',
                            'surface': 'create_curriculum_dialog',
                          },
                        );
                        TelemetryService.instance.logEvent(
                          event: 'mission.snapshot.created',
                          metadata: <String, dynamic>{
                            'module': 'hq_curriculum',
                            'source': 'create_curriculum_dialog',
                          },
                        );

                        final bool created = await _createCurriculum(
                          title: title,
                          description: descriptionController.text.trim(),
                          pillar: selectedPillar,
                          template: selectedTemplate,
                          difficulty: selectedDifficulty,
                          misconceptionTags: _splitCommaSeparated(
                            misconceptionTagsController.text,
                          ),
                          mediaFormat: selectedMediaFormat,
                          capabilityLabels: capabilityLabels,
                        );

                        if (!mounted || !dialogContext.mounted) return;
                        if (created) {
                          Navigator.pop(dialogContext);
                        } else {
                          setLocalState(() => isSubmitting = false);
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_tHqCurriculum(context, 'Create')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openCapabilityMappingWorkflow(
    _SessionCapabilityReadiness readiness, {
    required _Curriculum? recommendedCurriculum,
  }) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'hq_curriculum',
        'cta_id': recommendedCurriculum == null
            ? 'create_mapped_curriculum_from_session_readiness'
            : 'open_curriculum_editor_from_session_readiness',
        'surface': 'session_capability_readiness',
        'session_id': readiness.id,
        'pillar_code': readiness.pillarCode,
      },
    );
    if (recommendedCurriculum != null) {
      _showEditDialog(recommendedCurriculum);
      return;
    }
    _tabController.animateTo(2);
    _showCreateDialog(initialPillar: readiness.pillar);
  }

  void _openCapabilityMappingWorkflowForRequest(
    _SessionCapabilityMappingRequest request,
  ) {
    final _Curriculum? recommendedCurriculum =
        _recommendedCurriculumForPillar(request.pillar);
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'hq_curriculum',
        'cta_id': recommendedCurriculum == null
            ? 'create_mapped_curriculum_from_mapping_request'
            : 'open_curriculum_editor_from_mapping_request',
        'surface': 'hq_mapping_requests',
        'request_id': request.id,
        'session_id': request.sessionId,
      },
    );
    if (recommendedCurriculum != null) {
      _showEditDialog(recommendedCurriculum);
      return;
    }
    _tabController.animateTo(2);
    _showCreateDialog(initialPillar: request.pillar);
  }

  Future<void> _showResolveMappingRequestDialog(
    _SessionCapabilityMappingRequest request,
  ) async {
    final TextEditingController noteController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: ScholesaColors.surface,
          surfaceTintColor: ScholesaColors.surface,
          title: Text(_tHqCurriculum(context, 'Resolve request')),
          content: TextField(
            controller: noteController,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: _tHqCurriculum(context, 'Resolution note (optional)'),
              hintText: _tHqCurriculum(
                context,
                'Explain what changed so school teams can verify the unblock.',
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_tHqCurriculum(context, 'Cancel')),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _resolveMappingRequest(
                  request,
                  operatorNote: noteController.text.trim(),
                );
              },
              child: Text(_tHqCurriculum(context, 'Resolve request')),
            ),
          ],
        );
      },
    );
    noteController.dispose();
  }

  Future<void> _resolveMappingRequest(
    _SessionCapabilityMappingRequest request, {
    required String operatorNote,
  }) async {
    final FirestoreService? firestoreService = _maybeFirestoreService();
    final AppState? appState = _maybeAppState();
    final _SessionCapabilityReadiness? readiness =
        _readinessForSessionId(request.sessionId);
    if (firestoreService == null) {
      return;
    }
    setState(() {
      _resolvingMappingRequestIds.add(request.id);
    });
    try {
      final _MappingResolutionDetails resolutionDetails =
          await _buildMappingResolutionDetails(
        firestoreService: firestoreService,
        request: request,
        readiness: readiness,
        operatorNote: operatorNote,
      );
      await firestoreService.updateDocument(
        'supportRequests',
        request.id,
        <String, dynamic>{
          'status': 'resolved',
          'resolvedAt': FieldValue.serverTimestamp(),
          'resolvedBy': appState?.userId,
          'resolvedByRole': appState?.role?.name,
          'resolutionType': 'capability_mapping_completed',
          'resolutionSummary': resolutionDetails.summary,
          'resolutionOperatorNote': resolutionDetails.operatorNote,
          'resolutionSupportingCapabilityCount':
              resolutionDetails.supportingCapabilityCount,
          'resolutionSupportingCapabilityIds':
              resolutionDetails.supportingCapabilityIds,
          'resolutionSupportingCapabilityTitles':
              resolutionDetails.supportingCapabilityTitles,
          'resolutionSupportingCurriculumIds':
              resolutionDetails.supportingCurriculumIds,
          'resolutionSupportingCurriculumTitles':
              resolutionDetails.supportingCurriculumTitles,
          'resolutionPillarCode': resolutionDetails.pillarCode,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
      TelemetryService.instance.logEvent(
        event: 'hq.session_capability_mapping_request.resolved',
        metadata: <String, dynamic>{
          'request_id': request.id,
          'session_id': request.sessionId,
        },
      );
      if (!mounted) return;
      setState(() {
        _mappingRequests = _mappingRequests
            .where(
              (_SessionCapabilityMappingRequest entry) =>
                  entry.id != request.id,
            )
            .toList(growable: false);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tHqCurriculum(context, 'Mapping request resolved')),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tHqCurriculum(
              context,
              'Unable to resolve mapping request right now.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _resolvingMappingRequestIds.remove(request.id);
        });
      }
    }
  }

  Future<_MappingResolutionDetails> _buildMappingResolutionDetails({
    required FirestoreService firestoreService,
    required _SessionCapabilityMappingRequest request,
    required _SessionCapabilityReadiness? readiness,
    required String operatorNote,
  }) async {
    final String pillarCode = readiness?.pillarCode.trim().isNotEmpty == true
        ? readiness!.pillarCode.trim()
        : _pillarCodeFromLabel(request.pillar);
    final String scopedSiteId = readiness?.siteId?.trim().isNotEmpty == true
        ? readiness!.siteId!.trim()
        : request.siteId.trim();
    if (readiness == null) {
      return _MappingResolutionDetails(
        summary:
            'HQ resolved this request after manual review. Refresh the session readiness surface before educator capture resumes.',
        operatorNote: operatorNote,
        supportingCapabilityCount: 0,
        supportingCapabilityIds: const <String>[],
        supportingCapabilityTitles: const <String>[],
        supportingCurriculumIds: const <String>[],
        supportingCurriculumTitles: const <String>[],
        pillarCode: pillarCode,
      );
    }

    final List<_CapabilityRef> supportingCapabilities =
        await _loadSupportingCapabilityRefs(
      firestoreService: firestoreService,
      pillarCode: pillarCode,
      siteId: scopedSiteId,
    );
    final List<String> supportingCapabilityIds = supportingCapabilities
        .map((_CapabilityRef capability) => capability.id)
        .toList(growable: false);
    final List<String> supportingCapabilityTitles = supportingCapabilities
        .map((_CapabilityRef capability) => capability.title)
        .toList(growable: false);
    final List<_CurriculumEvidenceRef> supportingCurricula =
        await _loadSupportingCurriculumRefs(
      firestoreService: firestoreService,
      pillarCode: pillarCode,
      pillar: request.pillar,
      siteId: scopedSiteId,
      supportingCapabilityIds: supportingCapabilityIds,
      supportingCapabilityTitles: supportingCapabilityTitles,
    );
    final int supportingCapabilityCount = readiness.mappedCapabilityCount > 0
        ? readiness.mappedCapabilityCount
        : supportingCapabilities.length;
    final List<String> previewTitles =
        supportingCapabilityTitles.take(3).toList(growable: false);
    final int extraCount = supportingCapabilityCount > previewTitles.length
        ? supportingCapabilityCount - previewTitles.length
        : 0;
    final String capabilityNoun =
        supportingCapabilityCount == 1 ? 'capability' : 'capabilities';
    final String summary = previewTitles.isEmpty
        ? 'HQ resolved this request after confirming $supportingCapabilityCount mapped $capabilityNoun for ${request.pillar}.'
        : 'HQ resolved this request after confirming $supportingCapabilityCount mapped $capabilityNoun for ${request.pillar}: ${previewTitles.join(', ')}${extraCount > 0 ? ', +$extraCount more' : ''}.';

    return _MappingResolutionDetails(
      summary: summary,
      operatorNote: operatorNote,
      supportingCapabilityCount: supportingCapabilityCount,
      supportingCapabilityIds: supportingCapabilityIds,
      supportingCapabilityTitles: supportingCapabilityTitles,
      supportingCurriculumIds: supportingCurricula
          .map((_CurriculumEvidenceRef curriculum) => curriculum.id)
          .toList(growable: false),
      supportingCurriculumTitles: supportingCurricula
          .map((_CurriculumEvidenceRef curriculum) => curriculum.title)
          .toList(growable: false),
      pillarCode: pillarCode,
    );
  }

  Future<void> _showTrainingCyclesSheet() async {
    await _loadTrainingCycles();
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ScholesaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _tHqCurriculum(context, 'Training Cycles'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await _loadTrainingCycles();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(_tHqCurriculum(context, 'Refresh')),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showCreateTrainingCycleDialog();
                    },
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label:
                        Text(_tHqCurriculum(context, 'Create Training Cycle')),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_trainingCyclesError != null && _trainingCycles.isEmpty)
                _buildLoadErrorState(
                  title: _tHqCurriculum(
                    context,
                    'Training cycles are temporarily unavailable',
                  ),
                  message: _trainingCyclesError!,
                  onRetry: _loadTrainingCycles,
                )
              else if (_trainingCycles.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    _tHqCurriculum(context, 'No training cycles yet'),
                    style: const TextStyle(
                      color: ScholesaColors.textSecondary,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _trainingCycles.length +
                        (_trainingCyclesError != null ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (BuildContext context, int index) {
                      if (_trainingCyclesError != null && index == 0) {
                        return _buildStaleDataBanner(
                          _tHqCurriculum(
                            context,
                            'Unable to refresh training cycles right now. Showing the last successful data.',
                          ),
                        );
                      }
                      final int cycleIndex =
                          index - (_trainingCyclesError != null ? 1 : 0);
                      final _TrainingCycle cycle = _trainingCycles[cycleIndex];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: ScholesaColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    cycle.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                _TrainingPill(
                                  label: cycle.status,
                                  color: cycle.status == 'completed'
                                      ? ScholesaColors.success
                                      : ScholesaColors.hq,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${cycle.trainingType} • ${cycle.audience} • ${cycle.termLabel}',
                              style: const TextStyle(
                                color: ScholesaColors.textSecondary,
                              ),
                            ),
                            if (cycle.startsAt != null) ...<Widget>[
                              const SizedBox(height: 6),
                              Text(
                                '${_tHqCurriculum(context, 'Start Date')}: ${cycle.startsAt!.month}/${cycle.startsAt!.day}/${cycle.startsAt!.year}',
                              ),
                            ],
                            if ((cycle.notes ?? '')
                                .trim()
                                .isNotEmpty) ...<Widget>[
                              const SizedBox(height: 6),
                              Text(
                                cycle.notes!.trim(),
                                style: const TextStyle(
                                  color: ScholesaColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateTrainingCycleDialog() async {
    final BuildContext pageContext = context;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(pageContext);
    final TextEditingController titleController = TextEditingController();
    final TextEditingController termController =
        TextEditingController(text: 'Current term');
    final TextEditingController notesController = TextEditingController();
    String trainingType = 'term_launch';
    String audience = 'educators';
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context,
            void Function(void Function()) setLocalState) {
          return AlertDialog(
            title: Text(_tHqCurriculum(context, 'Create Training Cycle')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: _tHqCurriculum(context, 'Title'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: trainingType,
                    decoration: InputDecoration(
                      labelText: _tHqCurriculum(context, 'Training Type'),
                    ),
                    items: const <String>[
                      'term_launch',
                      'mid_term_clinic',
                      'trainer_of_trainers',
                    ]
                        .map((String value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ))
                        .toList(),
                    onChanged: (String? value) => setLocalState(
                      () => trainingType = value ?? 'term_launch',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: audience,
                    decoration: InputDecoration(
                      labelText: _tHqCurriculum(context, 'Audience'),
                    ),
                    items: const <String>['educators', 'parents', 'site']
                        .map((String value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ))
                        .toList(),
                    onChanged: (String? value) => setLocalState(
                      () => audience = value ?? 'educators',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: termController,
                    decoration: InputDecoration(
                      labelText: _tHqCurriculum(context, 'Term Label'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: _tHqCurriculum(context, 'Notes'),
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed:
                    isSubmitting ? null : () => Navigator.pop(dialogContext),
                child: Text(_tHqCurriculum(context, 'Cancel')),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final String title = titleController.text.trim();
                        if (title.isEmpty) {
                          return;
                        }
                        final String createdLabel = _tHqCurriculum(
                          pageContext,
                          'Training cycle created',
                        );
                        final String failedLabel = _tHqCurriculum(
                          pageContext,
                          'Training cycle create failed',
                        );
                        setLocalState(() => isSubmitting = true);
                        try {
                          final AppState? appState = _maybeAppState();
                          await _workflowBridgeService.upsertTrainingCycle(
                            <String, dynamic>{
                              'title': title,
                              'trainingType': trainingType,
                              'audience': audience,
                              'termLabel': termController.text.trim(),
                              'status': 'scheduled',
                              if ((appState?.activeSiteId ?? '').isNotEmpty)
                                'siteId': appState!.activeSiteId,
                              if (notesController.text.trim().isNotEmpty)
                                'notes': notesController.text.trim(),
                            },
                          );
                          if (!mounted || !dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          await _loadTrainingCycles();
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(createdLabel),
                            ),
                          );
                        } catch (_) {
                          if (!mounted) return;
                          setLocalState(() => isSubmitting = false);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(failedLabel),
                            ),
                          );
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_tHqCurriculum(context, 'Create')),
              ),
            ],
          );
        },
      ),
    );

    titleController.dispose();
    termController.dispose();
    notesController.dispose();
  }

  String _formatTime(DateTime time) {
    final Duration diff = DateTime.now().difference(time);
    if (diff.inHours < 24) {
      return '${diff.inHours}${_tHqCurriculum(context, 'h ago')}';
    }
    return '${diff.inDays}${_tHqCurriculum(context, 'd ago')}';
  }

  Future<void> _loadCurricula() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _curriculaError = null;
    });

    if (widget.curriculaLoader != null) {
      try {
        final List<Map<String, dynamic>> rows = await widget.curriculaLoader!();
        final List<_Curriculum> loaded = rows.map((Map<String, dynamic> data) {
          final String id = (data['id'] as String?) ?? 'curriculum';
          final String title =
              (data['title'] as String?)?.trim().isNotEmpty == true
                  ? (data['title'] as String).trim()
                  : 'Curriculum';
          final DateTime lastUpdated = _toDateTime(data['updatedAt']) ??
              _toDateTime(data['createdAt']) ??
              DateTime.now();
          return _Curriculum(
            id: id,
            title: title,
            description: (data['description'] as String? ?? '').trim(),
            pillar: _pillarFromData(data),
            template: (data['template'] as String? ?? 'Project sprint').trim(),
            difficulty:
                (data['difficulty'] as String? ?? 'Intermediate').trim(),
            misconceptionTags: _parseStringList(data['misconceptionTags']),
            mediaFormat:
                (data['mediaFormat'] as String? ?? 'Mixed media').trim(),
            capabilityIds: _parseStringList(data['capabilityIds']),
            capabilityTitles: _parseStringList(data['capabilityTitles']),
            version: (data['version'] as String?) ?? '1.0',
            approvalStatus:
                (data['approvalStatus'] as String? ?? 'draft').trim(),
            status: _parseCurriculumStatus(data['status'] as String?),
            lastUpdated: lastUpdated,
          );
        }).toList()
          ..sort((_Curriculum a, _Curriculum b) =>
              b.lastUpdated.compareTo(a.lastUpdated));
        if (!mounted) return;
        setState(() {
          _curricula = loaded;
          _curriculaError = null;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _curriculaError = _tHqCurriculum(
            context,
            'We could not load curricula right now. Retry to check the current state.',
          );
        });
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
      return;
    }

    final FirestoreService? firestoreService = _maybeFirestoreService();
    if (firestoreService == null) {
      setState(() {
        _curriculaError = _tHqCurriculum(
          context,
          'We could not load curricula right now. Retry to check the current state.',
        );
        _isLoading = false;
      });
      return;
    }

    try {
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await firestoreService.firestore
            .collection('missions')
            .orderBy('updatedAt', descending: true)
            .limit(200)
            .get();
      } catch (_) {
        snapshot = await firestoreService.firestore
            .collection('missions')
            .limit(200)
            .get();
      }

      final List<_Curriculum> loaded =
          snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        final String title =
            (data['title'] as String?)?.trim().isNotEmpty == true
                ? (data['title'] as String).trim()
                : 'Curriculum';

        final DateTime lastUpdated = _toDateTime(data['updatedAt']) ??
            _toDateTime(data['createdAt']) ??
            DateTime.now();

        return _Curriculum(
          id: doc.id,
          title: title,
          description: (data['description'] as String? ?? '').trim(),
          pillar: _pillarFromData(data),
          template: (data['template'] as String? ?? 'Project sprint').trim(),
          difficulty: (data['difficulty'] as String? ?? 'Intermediate').trim(),
          misconceptionTags: _parseStringList(data['misconceptionTags']),
          mediaFormat: (data['mediaFormat'] as String? ?? 'Mixed media').trim(),
          capabilityIds: _parseStringList(data['capabilityIds']),
          capabilityTitles: _parseStringList(data['capabilityTitles']),
          version: (data['version'] as String?) ?? '1.0',
          approvalStatus: (data['approvalStatus'] as String? ?? 'draft').trim(),
          status: _parseCurriculumStatus(data['status'] as String?),
          lastUpdated: lastUpdated,
        );
      }).toList();

      loaded.sort((_Curriculum a, _Curriculum b) =>
          b.lastUpdated.compareTo(a.lastUpdated));

      if (!mounted) return;
      setState(() {
        _curricula = loaded;
        _curriculaError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _curriculaError = _tHqCurriculum(
          context,
          'We could not load curricula right now. Retry to check the current state.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadTrainingCycles() async {
    if (widget.trainingCyclesLoader != null) {
      try {
        final List<Map<String, dynamic>> rows =
            await widget.trainingCyclesLoader!();
        final List<_TrainingCycle> cycles =
            rows.map((Map<String, dynamic> row) {
          return _TrainingCycle(
            id: row['id'] as String? ?? '',
            title: row['title'] as String? ?? 'Training Cycle',
            trainingType: row['trainingType'] as String? ?? 'term_launch',
            audience: row['audience'] as String? ?? 'educators',
            termLabel: row['termLabel'] as String? ?? 'Current term',
            status: row['status'] as String? ?? 'scheduled',
            updatedAt: WorkflowBridgeService.toDateTime(row['updatedAt']) ??
                WorkflowBridgeService.toDateTime(row['createdAt']) ??
                WorkflowBridgeService.toDateTime(row['startsAt']) ??
                DateTime.now(),
            siteId: row['siteId'] as String?,
            startsAt: WorkflowBridgeService.toDateTime(row['startsAt']),
            notes: row['notes'] as String?,
          );
        }).toList(growable: false)
              ..sort(
                (_TrainingCycle a, _TrainingCycle b) =>
                    b.updatedAt.compareTo(a.updatedAt),
              );
        if (!mounted) return;
        setState(() {
          _trainingCycles = cycles;
          _trainingCyclesError = null;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _trainingCyclesError = _tHqCurriculum(
            context,
            'We could not load training cycles right now. Retry to check the current state.',
          );
        });
      }
      return;
    }

    try {
      final List<Map<String, dynamic>> rows =
          await _workflowBridgeService.listTrainingCycles(limit: 80);
      final List<_TrainingCycle> cycles = rows.map((Map<String, dynamic> row) {
        return _TrainingCycle(
          id: row['id'] as String? ?? '',
          title: row['title'] as String? ?? 'Training Cycle',
          trainingType: row['trainingType'] as String? ?? 'term_launch',
          audience: row['audience'] as String? ?? 'educators',
          termLabel: row['termLabel'] as String? ?? 'Current term',
          status: row['status'] as String? ?? 'scheduled',
          updatedAt: WorkflowBridgeService.toDateTime(row['updatedAt']) ??
              WorkflowBridgeService.toDateTime(row['createdAt']) ??
              WorkflowBridgeService.toDateTime(row['startsAt']) ??
              DateTime.now(),
          siteId: row['siteId'] as String?,
          startsAt: WorkflowBridgeService.toDateTime(row['startsAt']),
          notes: row['notes'] as String?,
        );
      }).toList(growable: false)
        ..sort(
          (_TrainingCycle a, _TrainingCycle b) =>
              b.updatedAt.compareTo(a.updatedAt),
        );
      if (!mounted) return;
      setState(() {
        _trainingCycles = cycles;
        _trainingCyclesError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _trainingCyclesError = _tHqCurriculum(
          context,
          'We could not load training cycles right now. Retry to check the current state.',
        );
      });
    }
  }

  Future<void> _loadSessionReadiness() async {
    if (!mounted) return;
    setState(() {
      _isLoadingSessionReadiness = true;
      _sessionReadinessError = null;
    });

    if (widget.sessionReadinessLoader != null) {
      try {
        final List<Map<String, dynamic>> rows =
            await widget.sessionReadinessLoader!();
        final List<_SessionCapabilityReadiness> readiness =
            _mapSessionReadiness(rows);
        if (!mounted) return;
        setState(() {
          _sessionReadiness = readiness;
          _sessionReadinessError = null;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _sessionReadinessError = _tHqCurriculum(
            context,
            'We could not load upcoming session capability coverage right now. Retry to check the current state.',
          );
        });
      } finally {
        if (mounted) {
          setState(() => _isLoadingSessionReadiness = false);
        }
      }
      return;
    }

    final FirestoreService? firestoreService = _maybeFirestoreService();
    if (firestoreService == null) {
      if (!mounted) return;
      setState(() {
        _sessionReadinessError = _tHqCurriculum(
          context,
          'We could not load upcoming session capability coverage right now. Retry to check the current state.',
        );
        _isLoadingSessionReadiness = false;
      });
      return;
    }

    try {
      QuerySnapshot<Map<String, dynamic>> sessionSnapshot;
      try {
        sessionSnapshot = await firestoreService.firestore
            .collection('sessions')
            .orderBy('startTime')
            .limit(160)
            .get();
      } catch (_) {
        try {
          sessionSnapshot = await firestoreService.firestore
              .collection('sessions')
              .orderBy('createdAt', descending: true)
              .limit(160)
              .get();
        } catch (_) {
          sessionSnapshot = await firestoreService.firestore
              .collection('sessions')
              .limit(160)
              .get();
        }
      }

      final QuerySnapshot<Map<String, dynamic>> capabilitySnapshot =
          await firestoreService.firestore
              .collection('capabilities')
              .limit(500)
              .get();

      final DateTime cutoff = DateTime.now().subtract(const Duration(hours: 4));
      final Map<String, int> scopedCounts = <String, int>{};
      final Map<String, int> globalCounts = <String, int>{};
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in capabilitySnapshot.docs) {
        final Map<String, dynamic> capability = doc.data();
        final String pillarCode = _capabilityPillarCode(capability);
        if (pillarCode.isEmpty) {
          continue;
        }
        final String siteId = (capability['siteId'] as String? ?? '').trim();
        if (siteId.isEmpty) {
          globalCounts[pillarCode] = (globalCounts[pillarCode] ?? 0) + 1;
        } else {
          final String key = '$siteId|$pillarCode';
          scopedCounts[key] = (scopedCounts[key] ?? 0) + 1;
        }
      }

      final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in sessionSnapshot.docs) {
        final Map<String, dynamic> data = doc.data();
        final DateTime? startTime = _toDateTime(data['startTime']) ??
            _toDateTime(data['startDate']) ??
            _toDateTime(data['date']);
        if (startTime == null || startTime.isBefore(cutoff)) {
          continue;
        }
        final String pillar = _pillarFromData(data);
        final String pillarCode = _pillarCodeFromLabel(pillar);
        final String siteId = (data['siteId'] as String? ?? '').trim();
        final int mappedCapabilityCount =
            (scopedCounts['$siteId|$pillarCode'] ?? 0) +
                (globalCounts[pillarCode] ?? 0);
        final String title =
            ((data['title'] as String?) ?? (data['name'] as String?) ?? '')
                .trim();
        rows.add(<String, dynamic>{
          'id': doc.id,
          'title': title.isNotEmpty ? title : doc.id,
          'pillar': pillar,
          'pillarCode': pillarCode,
          'siteId': siteId,
          'educatorName': ((data['educatorName'] as String?) ??
                  (data['educatorDisplayName'] as String?) ??
                  (data['educatorId'] as String?) ??
                  '')
              .trim(),
          'startTime': startTime.toIso8601String(),
          'mappedCapabilityCount': mappedCapabilityCount,
        });
      }

      final List<_SessionCapabilityReadiness> readiness =
          _mapSessionReadiness(rows);
      if (!mounted) return;
      setState(() {
        _sessionReadiness = readiness;
        _sessionReadinessError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sessionReadinessError = _tHqCurriculum(
          context,
          'We could not load upcoming session capability coverage right now. Retry to check the current state.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingSessionReadiness = false);
      }
    }
  }

  Future<void> _loadMappingRequests() async {
    if (!mounted) return;
    setState(() {
      _isLoadingMappingRequests = true;
      _mappingRequestError = null;
    });

    if (widget.mappingRequestLoader != null) {
      try {
        final List<Map<String, dynamic>> rows =
            await widget.mappingRequestLoader!();
        final List<_SessionCapabilityMappingRequest> requests =
            _mapMappingRequests(rows);
        if (!mounted) return;
        setState(() {
          _mappingRequests = requests;
          _mappingRequestError = null;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _mappingRequestError = _tHqCurriculum(
            context,
            'We could not load HQ mapping requests right now. Retry to check the current state.',
          );
        });
      } finally {
        if (mounted) {
          setState(() => _isLoadingMappingRequests = false);
        }
      }
      return;
    }

    final FirestoreService? firestoreService = _maybeFirestoreService();
    if (firestoreService == null) {
      if (!mounted) return;
      setState(() {
        _mappingRequestError = _tHqCurriculum(
          context,
          'We could not load HQ mapping requests right now. Retry to check the current state.',
        );
        _isLoadingMappingRequests = false;
      });
      return;
    }

    try {
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await firestoreService.firestore
            .collection('supportRequests')
            .where('requestType', isEqualTo: 'session_capability_mapping')
            .orderBy('submittedAt', descending: true)
            .limit(80)
            .get();
      } catch (_) {
        snapshot = await firestoreService.firestore
            .collection('supportRequests')
            .where('requestType', isEqualTo: 'session_capability_mapping')
            .limit(80)
            .get();
      }

      final List<Map<String, dynamic>> rows = snapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
            final Map<String, dynamic> data = doc.data();
            final String status = (data['status'] as String? ?? 'open').trim();
            if (status == 'resolved' || status == 'closed') {
              return <String, dynamic>{};
            }
            final Map<String, dynamic> metadata = Map<String, dynamic>.from(
              data['metadata'] as Map? ?? <String, dynamic>{},
            );
            return <String, dynamic>{
              'id': doc.id,
              'sessionId': metadata['sessionId'],
              'sessionTitle': metadata['sessionTitle'] ?? data['subject'],
              'pillar': metadata['pillar'],
              'siteId': data['siteId'],
              'requesterName': data['userName'],
              'requesterRole': data['role'],
              'submittedAt': data['submittedAt'],
              'message': data['message'],
            };
          })
          .where((Map<String, dynamic> row) => row.isNotEmpty)
          .toList(growable: false);

      final List<_SessionCapabilityMappingRequest> requests =
          _mapMappingRequests(rows);
      if (!mounted) return;
      setState(() {
        _mappingRequests = requests;
        _mappingRequestError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _mappingRequestError = _tHqCurriculum(
          context,
          'We could not load HQ mapping requests right now. Retry to check the current state.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingMappingRequests = false);
      }
    }
  }

  Future<bool> _createCurriculum({
    required String title,
    required String description,
    required String pillar,
    required String template,
    required String difficulty,
    required List<String> misconceptionTags,
    required String mediaFormat,
    required List<String> capabilityLabels,
  }) async {
    final AppState? appState = _maybeAppState();
    final FirestoreService? firestoreService = _maybeFirestoreService();
    if (firestoreService == null) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tHqCurriculum(context, 'Create failed'))),
      );
      return false;
    }

    try {
      final String pillarCode = _pillarCodeFromLabel(pillar);
      final String? actorRole = appState?.role?.name;
      final String? actorId = appState?.userId;
      final String? activeSiteId = appState?.activeSiteId;
      final List<_CapabilityRef> capabilities = await _resolveCapabilityRefs(
        firestoreService: firestoreService,
        pillar: pillar,
        capabilityLabels: capabilityLabels,
        siteId: activeSiteId,
        actorId: actorId,
      );

      final String createdId = await firestoreService.createDocument(
        'missions',
        <String, dynamic>{
          'title': title,
          'description': description,
          'pillar': pillar,
          'pillarCode': pillarCode,
          'pillarCodes': <String>[pillarCode],
          'template': template,
          'difficulty': difficulty,
          'misconceptionTags': misconceptionTags,
          'mediaFormat': mediaFormat,
          'capabilityIds': capabilities
              .map((_CapabilityRef capability) => capability.id)
              .toList(),
          'capabilityTitles': capabilities
              .map((_CapabilityRef capability) => capability.title)
              .toList(),
          'approvalStatus': 'draft',
          'siteId': activeSiteId,
          'createdBy': actorId,
          'createdByRole': actorRole,
          'publisherType': actorRole ?? 'hq',
          'published': false,
          'status': 'draft',
          'version': '1.0',
        },
      );

      final _Curriculum created = _Curriculum(
        id: createdId,
        title: title,
        description: description,
        pillar: pillar,
        template: template,
        difficulty: difficulty,
        misconceptionTags: misconceptionTags,
        mediaFormat: mediaFormat,
        capabilityIds: capabilities
            .map((_CapabilityRef capability) => capability.id)
            .toList(),
        capabilityTitles: capabilities
            .map((_CapabilityRef capability) => capability.title)
            .toList(),
        version: '1.0',
        approvalStatus: 'draft',
        status: _CurriculumStatus.draft,
        lastUpdated: DateTime.now(),
      );

      if (mounted) {
        setState(() {
          _curricula = <_Curriculum>[created, ..._curricula];
        });
      }

      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tHqCurriculum(context, 'Curriculum created'))),
      );
      await _loadCurricula();
      return true;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tHqCurriculum(context, 'Create failed'))),
      );
      return false;
    }
  }

  Future<bool> _updateCurriculum(
    _Curriculum curriculum, {
    required String title,
    required String description,
    required String pillar,
    required String template,
    required String difficulty,
    required List<String> misconceptionTags,
    required String mediaFormat,
    required List<String> capabilityLabels,
  }) async {
    final FirestoreService? firestoreService = _maybeFirestoreService();
    final AppState? appState = _maybeAppState();
    if (firestoreService == null) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tHqCurriculum(context, 'Update failed'))),
      );
      return false;
    }

    try {
      final String pillarCode = _pillarCodeFromLabel(pillar);
      final List<_CapabilityRef> capabilities = await _resolveCapabilityRefs(
        firestoreService: firestoreService,
        pillar: pillar,
        capabilityLabels: capabilityLabels,
        siteId: appState?.activeSiteId,
        actorId: appState?.userId,
      );
      await firestoreService
          .updateDocument('missions', curriculum.id, <String, dynamic>{
        'title': title,
        'description': description,
        'pillar': pillar,
        'pillarCode': pillarCode,
        'pillarCodes': <String>[pillarCode],
        'template': template,
        'difficulty': difficulty,
        'misconceptionTags': misconceptionTags,
        'mediaFormat': mediaFormat,
        'capabilityIds': capabilities
            .map((_CapabilityRef capability) => capability.id)
            .toList(),
        'capabilityTitles': capabilities
            .map((_CapabilityRef capability) => capability.title)
            .toList(),
      });

      _replaceLocalCurriculum(
        curriculum.id,
        title: title,
        description: description,
        pillar: pillar,
        template: template,
        difficulty: difficulty,
        misconceptionTags: misconceptionTags,
        mediaFormat: mediaFormat,
        capabilityIds: capabilities
            .map((_CapabilityRef capability) => capability.id)
            .toList(),
        capabilityTitles: capabilities
            .map((_CapabilityRef capability) => capability.title)
            .toList(),
        lastUpdated: DateTime.now(),
      );

      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tHqCurriculum(context, 'Curriculum updated'))),
      );
      await _loadCurricula();
      return true;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tHqCurriculum(context, 'Update failed'))),
      );
      return false;
    }
  }

  void _showRubricWorkflowDialog(_Curriculum curriculum) {
    final TextEditingController titleController = TextEditingController(
      text: '${curriculum.title} Rubric',
    );
    final TextEditingController criteriaController = TextEditingController(
      text: 'Clarity, Evidence, Agency',
    );
    final TextEditingController descriptorsController = TextEditingController();
    final TextEditingController checkpointMappingsController =
        TextEditingController(
      text: _defaultCheckpointMappingsDraft(),
    );
    bool isSubmitting = false;

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context,
            void Function(void Function()) setLocalState) {
          return AlertDialog(
            backgroundColor: ScholesaColors.surface,
            surfaceTintColor: ScholesaColors.surface,
            scrollable: true,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            title: Text(_tHqCurriculum(context, 'Create Rubric')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  controller: titleController,
                  style: const TextStyle(
                    color: ScholesaColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    labelText: _tHqCurriculum(context, 'Rubric title'),
                    labelStyle:
                        const TextStyle(color: ScholesaColors.textSecondary),
                    filled: true,
                    fillColor: ScholesaColors.surfaceVariant,
                    border: const OutlineInputBorder(),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: ScholesaColors.border),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide:
                          BorderSide(color: ScholesaColors.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: criteriaController,
                  minLines: 2,
                  maxLines: 4,
                  style: const TextStyle(
                    color: ScholesaColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    labelText:
                        _tHqCurriculum(context, 'Criteria (comma-separated)'),
                    labelStyle:
                        const TextStyle(color: ScholesaColors.textSecondary),
                    filled: true,
                    fillColor: ScholesaColors.surfaceVariant,
                    border: const OutlineInputBorder(),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: ScholesaColors.border),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide:
                          BorderSide(color: ScholesaColors.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptorsController,
                  minLines: 2,
                  maxLines: 4,
                  style: const TextStyle(
                    color: ScholesaColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    labelText: _tHqCurriculum(
                      context,
                      'Progression descriptors (one per line)',
                    ),
                    labelStyle:
                        const TextStyle(color: ScholesaColors.textSecondary),
                    filled: true,
                    fillColor: ScholesaColors.surfaceVariant,
                    border: const OutlineInputBorder(),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: ScholesaColors.border),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide:
                          BorderSide(color: ScholesaColors.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: checkpointMappingsController,
                  minLines: 4,
                  maxLines: 8,
                  style: const TextStyle(
                    color: ScholesaColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    labelText: _tHqCurriculum(
                      context,
                      'Checkpoint mappings (phase: guidance)',
                    ),
                    labelStyle:
                        const TextStyle(color: ScholesaColors.textSecondary),
                    filled: true,
                    fillColor: ScholesaColors.surfaceVariant,
                    border: const OutlineInputBorder(),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: ScholesaColors.border),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide:
                          BorderSide(color: ScholesaColors.primary, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: ScholesaColors.textPrimary,
                ),
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(_tHqCurriculum(context, 'Cancel')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ScholesaColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final String rubricTitle = titleController.text.trim();
                        final List<String> criteria = criteriaController.text
                            .split(',')
                            .map((String item) => item.trim())
                            .where((String item) => item.isNotEmpty)
                            .toList();
                        final List<String> progressionDescriptors =
                            _parseLineSeparatedValues(
                          descriptorsController.text,
                        );
                        final List<Map<String, dynamic>> checkpointMappings =
                            _parseCheckpointMappings(
                          checkpointMappingsController.text,
                        );

                        if (rubricTitle.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_tHqCurriculum(
                                  context, 'Rubric title is required')),
                            ),
                          );
                          return;
                        }

                        if (criteria.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_tHqCurriculum(context,
                                  'At least one criterion is required')),
                            ),
                          );
                          return;
                        }

                        setLocalState(() => isSubmitting = true);
                        final bool applied = await _createAndApplyRubric(
                          curriculum,
                          rubricTitle: rubricTitle,
                          criteriaLabels: criteria,
                          progressionDescriptors: progressionDescriptors,
                          checkpointMappings: checkpointMappings,
                        );

                        if (!mounted || !dialogContext.mounted) return;
                        if (applied) {
                          Navigator.pop(dialogContext);
                        } else {
                          setLocalState(() => isSubmitting = false);
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_tHqCurriculum(context, 'Apply Rubric')),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<bool> _createAndApplyRubric(
    _Curriculum curriculum, {
    required String rubricTitle,
    required List<String> criteriaLabels,
    required List<String> progressionDescriptors,
    required List<Map<String, dynamic>> checkpointMappings,
  }) async {
    final FirestoreService? firestoreService = _maybeFirestoreService();
    final AppState? appState = _maybeAppState();
    if (firestoreService == null) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tHqCurriculum(context, 'Rubric apply failed'))),
      );
      return false;
    }

    try {
      if (curriculum.capabilityIds.isEmpty ||
          curriculum.capabilityTitles.isEmpty) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_tHqCurriculum(
              context,
              'Add capability mappings before creating a rubric',
            )),
          ),
        );
        return false;
      }

      final List<Map<String, dynamic>> criteria = criteriaLabels
          .asMap()
          .entries
          .map((MapEntry<int, String> entry) => <String, dynamic>{
                'id': 'c${entry.key + 1}',
            'label': entry.value,
                'pillarCode': _pillarCodeFromLabel(curriculum.pillar),
                'capabilityId': entry.key < curriculum.capabilityIds.length
                    ? curriculum.capabilityIds[entry.key]
                    : null,
                'capabilityTitle':
                    entry.key < curriculum.capabilityTitles.length
                        ? curriculum.capabilityTitles[entry.key]
                        : entry.value,
                'levels': <int>[0, 1, 2, 3, 4],
              })
          .toList();

      final String rubricId = await firestoreService.createDocument(
        'rubrics',
        <String, dynamic>{
          'title': rubricTitle,
          'siteId': appState?.activeSiteId,
          'criteria': criteria,
          'capabilityIds': curriculum.capabilityIds,
          'capabilityTitles': curriculum.capabilityTitles,
          'progressionDescriptors': progressionDescriptors,
          'checkpointMappings': checkpointMappings,
          'createdBy': appState?.userId,
          'createdByRole': appState?.role?.name,
        },
      );

      await firestoreService
          .updateDocument('missions', curriculum.id, <String, dynamic>{
        'rubricApplied': true,
        'rubricId': rubricId,
        'rubricTitle': rubricTitle,
        'progressionDescriptors': progressionDescriptors,
        'checkpointMappings': checkpointMappings,
        'rubricAppliedBy': appState?.userId,
        'rubricAppliedAt': FieldValue.serverTimestamp(),
        'status': 'review',
      });

      _replaceLocalCurriculum(
        curriculum.id,
        status: _CurriculumStatus.review,
        lastUpdated: DateTime.now(),
      );

      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              _tHqCurriculum(context, 'Rubric applied to this curriculum')),
        ),
      );
      await _loadCurricula();
      return true;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tHqCurriculum(context, 'Rubric apply failed'))),
      );
      return false;
    }
  }

  List<String> _parseLineSeparatedValues(String raw) {
    return raw
        .split(RegExp(r'\r?\n'))
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _parseCheckpointMappings(String raw) {
    final List<String> lines = _parseLineSeparatedValues(raw);
    return lines.map((String line) {
      final List<String> parts = line.split(':');
      final String phaseKey = _normalizeCheckpointPhaseKey(parts.first);
      final String guidance =
          parts.length > 1 ? parts.sublist(1).join(':').trim() : '';
      return <String, dynamic>{
        'phaseKey': phaseKey,
        'phaseLabel': _phaseLabelForCheckpointKey(phaseKey),
        'guidance': guidance,
      };
    }).where((Map<String, dynamic> item) {
      final String phaseKey = (item['phaseKey'] as String?)?.trim() ?? '';
      final String guidance = (item['guidance'] as String?)?.trim() ?? '';
      return phaseKey.isNotEmpty && guidance.isNotEmpty;
    }).toList(growable: false);
  }

  String _normalizeCheckpointPhaseKey(String raw) {
    final String normalized = raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    switch (normalized) {
      case 'retrieval_warm_up':
      case 'retrieval_warmup':
      case 'retrieval':
        return 'retrieval_warm_up';
      case 'mini_lesson':
      case 'mini_lesson_micro_skill':
      case 'mini_lesson_micro_skills':
      case 'micro_skill':
      case 'micro_skills':
      case 'mini_skill':
        return 'mini_lesson';
      case 'build_sprint':
      case 'build':
        return 'build_sprint';
      case 'checkpoint':
        return 'checkpoint';
      case 'share_out':
      case 'share':
        return 'share_out';
      case 'reflection':
      case 'reflect':
        return 'reflection';
      case 'portfolio_artifact':
      case 'artifact':
      case 'portfolio':
        return 'portfolio_artifact';
      default:
        return normalized;
    }
  }

  String _phaseLabelForCheckpointKey(String key) {
    switch (_normalizeCheckpointPhaseKey(key)) {
      case 'retrieval_warm_up':
        return 'Retrieval Warm-up';
      case 'mini_lesson':
        return 'Mini-lesson / Micro-skill';
      case 'build_sprint':
        return 'Build Sprint';
      case 'checkpoint':
        return 'Checkpoint';
      case 'share_out':
        return 'Share-out';
      case 'reflection':
        return 'Reflection';
      case 'portfolio_artifact':
        return 'Portfolio Artifact';
      default:
        return key.trim();
    }
  }

  String _defaultCheckpointMappingsDraft() {
    return <String>[
      'build_sprint: Note which learner action shows the capability in progress.',
      'checkpoint: Record the explanation, artifact, or demonstration that proves current understanding.',
      'reflection: Capture what changed, what still needs verification, and the next claim to test.',
    ].join('\n');
  }

  Future<void> _createMissionSnapshot(_Curriculum curriculum) async {
    final FirestoreService? firestoreService = _maybeFirestoreService();
    final AppState? appState = _maybeAppState();
    if (firestoreService == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_tHqCurriculum(context, 'Snapshot create failed'))),
      );
      return;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> missionDoc =
          await firestoreService.firestore
              .collection('missions')
              .doc(curriculum.id)
              .get();
      final Map<String, dynamic> mission =
          missionDoc.data() ?? <String, dynamic>{};

      final String currentVersion =
          (mission['version'] as String?)?.trim().isNotEmpty == true
              ? (mission['version'] as String).trim()
              : curriculum.version;
      final String nextVersion = _incrementVersion(currentVersion);
      final String title =
          (mission['title'] as String?)?.trim().isNotEmpty == true
              ? (mission['title'] as String).trim()
              : curriculum.title;
      final String description =
          (mission['description'] as String?)?.trim().isNotEmpty == true
              ? (mission['description'] as String).trim()
              : title;
      final List<dynamic> pillarCodes = (mission['pillarCodes'] as List?) ??
          <dynamic>[_pillarCodeFromLabel(curriculum.pillar)];

      final String hashSource = <String>[
        curriculum.id,
        title,
        description,
        pillarCodes.join(','),
        currentVersion,
        DateTime.now().toUtc().toIso8601String(),
      ].join('|');
      final String contentHash = _simpleHash(hashSource);

      final String snapshotId = await firestoreService.createDocument(
        'missionSnapshots',
        <String, dynamic>{
          'missionId': curriculum.id,
          'contentHash': contentHash,
          'title': title,
          'description': description,
          'pillarCodes': pillarCodes,
          'skillIds': (mission['skillIds'] as List?) ?? <dynamic>[],
          'bodyJson': mission['bodyJson'],
          'publisherType': appState?.role?.name ?? 'hq',
          'publisherId': appState?.userId,
          'publishedAt': FieldValue.serverTimestamp(),
          'sourceVersion': currentVersion,
          'snapshotVersion': nextVersion,
        },
      );

      await firestoreService
          .updateDocument('missions', curriculum.id, <String, dynamic>{
        'version': nextVersion,
        'latestSnapshotId': snapshotId,
        'latestContentHash': contentHash,
      });

      TelemetryService.instance.logEvent(
        event: 'mission.snapshot.created',
        metadata: <String, dynamic>{
          'module': 'hq_curriculum',
          'mission_id': curriculum.id,
          'snapshot_id': snapshotId,
          'source_version': currentVersion,
          'snapshot_version': nextVersion,
        },
      );

      _replaceLocalCurriculum(
        curriculum.id,
        version: nextVersion,
        lastUpdated: DateTime.now(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tHqCurriculum(context, 'Snapshot created'))),
      );
      await _loadCurricula();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_tHqCurriculum(context, 'Snapshot create failed'))),
      );
    }
  }

  Future<void> _markParentSummaryReady(_Curriculum curriculum) async {
    final FirestoreService? firestoreService = _maybeFirestoreService();
    final AppState? appState = _maybeAppState();
    if (firestoreService == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tHqCurriculum(context, 'Share failed'))),
      );
      return;
    }

    try {
      await firestoreService
          .updateDocument('missions', curriculum.id, <String, dynamic>{
        'parentSummaryShared': true,
        'parentSummarySharedBy': appState?.userId,
        'parentSummarySharedAt': FieldValue.serverTimestamp(),
      });

      _replaceLocalCurriculum(
        curriculum.id,
        lastUpdated: DateTime.now(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tHqCurriculum(
              context,
              'Parent summary marked ready for sharing',
            ),
          ),
        ),
      );
      await _loadCurricula();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tHqCurriculum(context, 'Share failed'))),
      );
    }
  }

  void _replaceLocalCurriculum(
    String id, {
    String? title,
    String? description,
    String? pillar,
    String? template,
    String? difficulty,
    List<String>? misconceptionTags,
    String? mediaFormat,
    List<String>? capabilityIds,
    List<String>? capabilityTitles,
    String? version,
    String? approvalStatus,
    _CurriculumStatus? status,
    DateTime? lastUpdated,
  }) {
    if (!mounted) return;
    setState(() {
      _curricula = _curricula.map((_Curriculum entry) {
        if (entry.id != id) return entry;
        return _Curriculum(
          id: entry.id,
          title: title ?? entry.title,
          description: description ?? entry.description,
          pillar: pillar ?? entry.pillar,
          template: template ?? entry.template,
          difficulty: difficulty ?? entry.difficulty,
          misconceptionTags: misconceptionTags ?? entry.misconceptionTags,
          mediaFormat: mediaFormat ?? entry.mediaFormat,
          capabilityIds: capabilityIds ?? entry.capabilityIds,
          capabilityTitles: capabilityTitles ?? entry.capabilityTitles,
          version: version ?? entry.version,
          approvalStatus: approvalStatus ?? entry.approvalStatus,
          status: status ?? entry.status,
          lastUpdated: lastUpdated ?? entry.lastUpdated,
        );
      }).toList();
    });
  }

  _CurriculumStatus _parseCurriculumStatus(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'published':
      case 'active':
        return _CurriculumStatus.published;
      case 'review':
      case 'in_review':
      case 'pending_review':
        return _CurriculumStatus.review;
      default:
        return _CurriculumStatus.draft;
    }
  }

  String _pillarFromData(Map<String, dynamic> data) {
    final String? direct = data['pillar'] as String?;
    if (direct != null && direct.trim().isNotEmpty) {
      return direct.trim();
    }
    final String? pillarCode = data['pillarCode'] as String?;
    if (pillarCode != null && pillarCode.trim().isNotEmpty) {
      return _pillarLabelFromCode(pillarCode);
    }
    final List<dynamic> pillarCodes =
        (data['pillarCodes'] as List?) ?? <dynamic>[];
    if (pillarCodes.isNotEmpty) {
      return _pillarLabelFromCode(pillarCodes.first.toString());
    }
    return 'Future Skills';
  }

  List<_SessionCapabilityReadiness> _mapSessionReadiness(
    List<Map<String, dynamic>> rows,
  ) {
    final List<_SessionCapabilityReadiness> readiness = rows
        .map((Map<String, dynamic> data) {
          final DateTime? startTime = _toDateTime(data['startTime']) ??
              _toDateTime(data['startDate']) ??
              _toDateTime(data['date']) ??
              _toDateTime(data['scheduledAt']);
          if (startTime == null) {
            return null;
          }
          final String pillar = _pillarFromData(data);
          final dynamic rawCount = data['mappedCapabilityCount'];
          final int mappedCapabilityCount = rawCount is int
              ? rawCount
              : rawCount is num
                  ? rawCount.toInt()
                  : int.tryParse(rawCount?.toString() ?? '') ?? 0;
          return _SessionCapabilityReadiness(
            id: (data['id'] as String?) ?? 'session',
            title: ((data['title'] as String?) ?? 'Session').trim(),
            pillar: pillar,
            pillarCode:
                (data['pillarCode'] as String?)?.trim().isNotEmpty == true
                    ? (data['pillarCode'] as String).trim()
                    : _pillarCodeFromLabel(pillar),
            startTime: startTime,
            mappedCapabilityCount: mappedCapabilityCount,
            siteId: data['siteId'] as String?,
            educator: ((data['educatorName'] as String?) ??
                    (data['educatorDisplayName'] as String?) ??
                    (data['educatorId'] as String?))
                ?.trim(),
          );
        })
        .whereType<_SessionCapabilityReadiness>()
        .toList(growable: false)
      ..sort((_SessionCapabilityReadiness a, _SessionCapabilityReadiness b) {
        final int blockedCompare = (a.isBlocked ? 0 : 1).compareTo(
          b.isBlocked ? 0 : 1,
        );
        if (blockedCompare != 0) {
          return blockedCompare;
        }
        return a.startTime.compareTo(b.startTime);
      });
    return readiness;
  }

  List<_SessionCapabilityMappingRequest> _mapMappingRequests(
    List<Map<String, dynamic>> rows,
  ) {
    final List<_SessionCapabilityMappingRequest> requests = rows
        .map((Map<String, dynamic> data) {
          final DateTime submittedAt = _toDateTime(data['submittedAt']) ??
              _toDateTime(data['createdAt']) ??
              DateTime.now();
          final String sessionId = (data['sessionId'] as String? ?? '').trim();
          if (sessionId.isEmpty) {
            return null;
          }
          return _SessionCapabilityMappingRequest(
            id: (data['id'] as String? ?? '').trim(),
            sessionId: sessionId,
            sessionTitle:
                ((data['sessionTitle'] as String?) ?? 'Session').trim(),
            pillar: ((data['pillar'] as String?) ?? 'Future Skills').trim(),
            siteId: ((data['siteId'] as String?) ?? '').trim(),
            requesterName:
                ((data['requesterName'] as String?) ?? 'Unknown').trim(),
            requesterRole:
                ((data['requesterRole'] as String?) ?? 'site').trim(),
            submittedAt: submittedAt,
            message: (data['message'] as String?)?.trim(),
          );
        })
        .whereType<_SessionCapabilityMappingRequest>()
        .toList(growable: false)
      ..sort((_SessionCapabilityMappingRequest a,
              _SessionCapabilityMappingRequest b) =>
          b.submittedAt.compareTo(a.submittedAt));
    return requests;
  }

  Future<List<_CapabilityRef>> _loadSupportingCapabilityRefs({
    required FirestoreService firestoreService,
    required String pillarCode,
    required String? siteId,
  }) async {
    final String scopedSiteId = (siteId ?? '').trim();
    final QuerySnapshot<Map<String, dynamic>> snapshot = await firestoreService
        .firestore
        .collection('capabilities')
        .where('pillarCode', isEqualTo: pillarCode)
        .limit(100)
        .get();

    final List<_CapabilityRef> capabilities =
        snapshot.docs.where((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      final String existingSiteId =
          (doc.data()['siteId'] as String? ?? '').trim();
      if (scopedSiteId.isEmpty) {
        return existingSiteId.isEmpty;
      }
      return existingSiteId.isEmpty || existingSiteId == scopedSiteId;
    }).map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      final Map<String, dynamic> data = doc.data();
      return _CapabilityRef(
        id: doc.id,
        title: (data['title'] as String? ?? 'Capability').trim(),
        normalizedTitle: (data['normalizedTitle'] as String? ?? '').trim(),
        pillarCode: pillarCode,
        siteId: data['siteId'] as String?,
        descriptor: data['descriptor'] as String?,
      );
    }).toList(growable: false)
          ..sort((_CapabilityRef a, _CapabilityRef b) {
            final String leftSiteId = (a.siteId ?? '').trim();
            final String rightSiteId = (b.siteId ?? '').trim();
            final int scopedCompare = (leftSiteId == scopedSiteId ? 0 : 1)
                .compareTo(rightSiteId == scopedSiteId ? 0 : 1);
            if (scopedCompare != 0) {
              return scopedCompare;
            }
            return a.title.toLowerCase().compareTo(b.title.toLowerCase());
          });

    return capabilities;
  }

  Future<List<_CurriculumEvidenceRef>> _loadSupportingCurriculumRefs({
    required FirestoreService firestoreService,
    required String pillarCode,
    required String pillar,
    required String? siteId,
    required List<String> supportingCapabilityIds,
    required List<String> supportingCapabilityTitles,
  }) async {
    final String scopedSiteId = (siteId ?? '').trim();
    final Set<String> capabilityIdSet = supportingCapabilityIds.toSet();
    final Set<String> capabilityTitleSet = supportingCapabilityTitles
        .map((String title) => title.trim().toLowerCase())
        .where((String title) => title.isNotEmpty)
        .toSet();

    final QuerySnapshot<Map<String, dynamic>> snapshot = await firestoreService
        .firestore
        .collection('missions')
        .limit(120)
        .get();

    final List<_CurriculumEvidenceRef> curricula = snapshot.docs
        .where((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      final Map<String, dynamic> data = doc.data();
      final String existingSiteId = (data['siteId'] as String? ?? '').trim();
      final bool siteMatches = scopedSiteId.isEmpty
          ? existingSiteId.isEmpty
          : existingSiteId.isEmpty || existingSiteId == scopedSiteId;
      if (!siteMatches) {
        return false;
      }

      final String missionPillarCode =
          (data['pillarCode'] as String? ?? '').trim();
      final String missionPillar = _pillarFromData(data).trim().toLowerCase();
      final bool pillarMatches = missionPillarCode == pillarCode ||
          missionPillar == pillar.trim().toLowerCase();
      if (!pillarMatches) {
        return false;
      }

      final List<String> missionCapabilityIds = _parseStringList(
        data['capabilityIds'],
      );
      if (capabilityIdSet.isNotEmpty &&
          missionCapabilityIds.any(capabilityIdSet.contains)) {
        return true;
      }

      final List<String> missionCapabilityTitles = _parseStringList(
        data['capabilityTitles'],
      ).map((String title) => title.toLowerCase()).toList(growable: false);
      if (capabilityTitleSet.isNotEmpty &&
          missionCapabilityTitles.any(capabilityTitleSet.contains)) {
        return true;
      }

      return capabilityIdSet.isEmpty && capabilityTitleSet.isEmpty;
    }).map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      final Map<String, dynamic> data = doc.data();
      return _CurriculumEvidenceRef(
        id: doc.id,
        title: (data['title'] as String? ?? 'Curriculum').trim(),
      );
    }).toList(growable: false)
      ..sort((_CurriculumEvidenceRef a, _CurriculumEvidenceRef b) =>
          a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    return curricula;
  }

  _SessionCapabilityReadiness? _readinessForSessionId(String sessionId) {
    for (final _SessionCapabilityReadiness readiness in _sessionReadiness) {
      if (readiness.id == sessionId) {
        return readiness;
      }
    }
    return null;
  }

  _Curriculum? _recommendedCurriculumForPillar(String pillar) {
    for (final _Curriculum curriculum in _curricula) {
      if (curriculum.pillar == pillar &&
          curriculum.status == _CurriculumStatus.draft) {
        return curriculum;
      }
    }
    for (final _Curriculum curriculum in _curricula) {
      if (curriculum.pillar == pillar) {
        return curriculum;
      }
    }
    return null;
  }

  List<String> _parseStringList(dynamic value) {
    return List<String>.from(value as List<dynamic>? ?? const <String>[])
        .map((String entry) => entry.trim())
        .where((String entry) => entry.isNotEmpty)
        .toList();
  }

  Future<List<_CapabilityRef>> _resolveCapabilityRefs({
    required FirestoreService firestoreService,
    required String pillar,
    required List<String> capabilityLabels,
    required String? siteId,
    required String? actorId,
  }) async {
    final String pillarCode = _pillarCodeFromLabel(pillar);
    final String scopedSiteId = (siteId ?? '').trim();
    final List<_CapabilityRef> resolved = <_CapabilityRef>[];

    for (final String rawLabel in capabilityLabels) {
      final String label = rawLabel.trim();
      if (label.isEmpty) {
        continue;
      }
      final String normalizedTitle = _normalizeCapabilityLabel(label);
      final QuerySnapshot<Map<String, dynamic>> existingSnapshot =
          await firestoreService.firestore
              .collection('capabilities')
              .where('normalizedTitle', isEqualTo: normalizedTitle)
              .limit(20)
              .get();

      QueryDocumentSnapshot<Map<String, dynamic>>? matchingDoc;
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in existingSnapshot.docs) {
        final Map<String, dynamic> data = doc.data();
        final String existingPillarCode =
            (data['pillarCode'] as String? ?? '').trim();
        final String existingSiteId = (data['siteId'] as String? ?? '').trim();
        final bool samePillar = existingPillarCode == pillarCode;
        final bool sameSite = scopedSiteId.isNotEmpty
            ? existingSiteId == scopedSiteId || existingSiteId.isEmpty
            : existingSiteId.isEmpty;
        if (samePillar && sameSite) {
          matchingDoc = doc;
          if (existingSiteId == scopedSiteId || scopedSiteId.isEmpty) {
            break;
          }
        }
      }

      if (matchingDoc != null) {
        final Map<String, dynamic> data = matchingDoc.data();
        resolved.add(
          _CapabilityRef(
            id: matchingDoc.id,
            title: (data['title'] as String? ?? label).trim(),
            normalizedTitle: normalizedTitle,
            pillarCode: pillarCode,
            siteId: data['siteId'] as String?,
            descriptor: data['descriptor'] as String?,
          ),
        );
        continue;
      }

      final String createdId = await firestoreService.createDocument(
        'capabilities',
        <String, dynamic>{
          'title': label,
          'normalizedTitle': normalizedTitle,
          'pillarCode': pillarCode,
          'pillarLabel': pillar,
          'siteId': scopedSiteId.isEmpty ? null : scopedSiteId,
          'descriptor': label,
          'createdBy': actorId,
          'source': 'hq_curriculum',
        },
      );

      resolved.add(
        _CapabilityRef(
          id: createdId,
          title: label,
          normalizedTitle: normalizedTitle,
          pillarCode: pillarCode,
          siteId: scopedSiteId.isEmpty ? null : scopedSiteId,
          descriptor: label,
        ),
      );
    }

    return resolved;
  }

  String _normalizeCapabilityLabel(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  String _pillarLabelFromCode(String raw) {
    final String code = raw.trim().toUpperCase();
    switch (code) {
      case 'LEAD':
      case 'LEADERSHIP':
        return 'Leadership & Agency';
      case 'IMP':
      case 'IMPACT':
        return 'Impact & Innovation';
      default:
        return 'Future Skills';
    }
  }

  String _pillarCodeFromLabel(String label) {
    final String value = label.trim().toLowerCase();
    if (value.contains('leadership')) return 'LEAD';
    if (value.contains('impact')) return 'IMP';
    return 'FS';
  }

  String _capabilityPillarCode(Map<String, dynamic> data) {
    final String direct = (data['pillarCode'] as String? ?? '').trim();
    if (direct.isNotEmpty) {
      return direct.toUpperCase();
    }
    final String label = (data['pillarLabel'] as String? ?? '').trim();
    if (label.isNotEmpty) {
      return _pillarCodeFromLabel(label);
    }
    return '';
  }

  String _formatSessionStart(DateTime startTime) {
    final DateTime local = startTime.toLocal();
    final String month = local.month.toString().padLeft(2, '0');
    final String day = local.day.toString().padLeft(2, '0');
    final int hour = local.hour == 0
        ? 12
        : local.hour > 12
            ? local.hour - 12
            : local.hour;
    final String minute = local.minute.toString().padLeft(2, '0');
    final String suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '$month/$day • $hour:$minute $suffix';
  }

  String _incrementVersion(String rawVersion) {
    final List<String> parts = rawVersion.trim().split('.');
    final int major = int.tryParse(parts.isNotEmpty ? parts[0] : '1') ?? 1;
    final int minor = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final int patch = int.tryParse(parts.length > 2 ? parts[2] : '0') ?? 0;
    return '$major.$minor.${patch + 1}';
  }

  String _simpleHash(String input) {
    final int hash = input.hashCode & 0x7fffffff;
    return hash.toRadixString(16).padLeft(8, '0');
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }

  FirestoreService? _maybeFirestoreService() {
    try {
      return context.read<FirestoreService>();
    } catch (_) {
      return null;
    }
  }

  AppState? _maybeAppState() {
    try {
      return context.read<AppState>();
    } catch (_) {
      return null;
    }
  }
}

class _TrainingPill extends StatelessWidget {
  const _TrainingPill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
