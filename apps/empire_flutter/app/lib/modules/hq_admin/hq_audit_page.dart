import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../i18n/workflow_surface_i18n.dart';
import '../../services/telemetry_service.dart';
import '../../services/workflow_bridge_service.dart';
import '../../ui/theme/scholesa_theme.dart';

String _tHqAudit(BuildContext context, String input) {
  return WorkflowSurfaceI18n.text(context, input);
}

enum _AuditCategory { auth, data, admin, system }

class _AuditLog {
  const _AuditLog({
    required this.id,
    required this.action,
    required this.category,
    required this.actor,
    required this.timestamp,
    required this.details,
  });

  final String id;
  final String action;
  final _AuditCategory category;
  final String actor;
  final DateTime timestamp;
  final String details;
}

class _RedTeamReview {
  const _RedTeamReview({
    required this.id,
    required this.title,
    required this.decision,
    required this.partnerStatus,
    required this.recommendations,
    required this.nextAction,
    required this.updatedAt,
    this.siteId,
  });

  final String id;
  final String title;
  final String decision;
  final String partnerStatus;
  final String recommendations;
  final String nextAction;
  final DateTime updatedAt;
  final String? siteId;
}

class HqAuditPage extends StatefulWidget {
  const HqAuditPage({super.key});

  @override
  State<HqAuditPage> createState() => _HqAuditPageState();
}

class _HqAuditPageState extends State<HqAuditPage> {
  final WorkflowBridgeService _workflowBridgeService =
      WorkflowBridgeService.instance;

  List<_AuditLog> _auditLogs = <_AuditLog>[];
  List<_RedTeamReview> _redTeamReviews = <_RedTeamReview>[];
  bool _isLoading = false;
  _AuditCategory? _filterCategory;

  void _logAuditEvent(String cta, [Map<String, dynamic>? metadata]) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'hq_audit',
        'cta': cta,
        if (metadata != null) ...metadata,
      },
    );
  }

  String _categoryLabel(_AuditCategory category) {
    switch (category) {
      case _AuditCategory.auth:
        return _tHqAudit(context, 'Auth');
      case _AuditCategory.data:
        return _tHqAudit(context, 'Data');
      case _AuditCategory.admin:
        return _tHqAudit(context, 'Admin');
      case _AuditCategory.system:
        return _tHqAudit(context, 'System');
    }
  }

  String _decisionLabel(String value) {
    switch (value.trim().toLowerCase()) {
      case 'continue':
        return _tHqAudit(context, 'Continue');
      case 'stabilize':
        return _tHqAudit(context, 'Stabilize');
      case 'intervene':
        return _tHqAudit(context, 'Intervene');
      default:
        return value;
    }
  }

  String _partnerStatusLabel(String value) {
    switch (value.trim().toLowerCase()) {
      case 'active':
        return _tHqAudit(context, 'Active');
      case 'watch':
        return _tHqAudit(context, 'Watch');
      case 'hold':
        return _tHqAudit(context, 'Hold');
      default:
        return value;
    }
  }

  String _siteScopeLabel(String? value) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return _tHqAudit(context, 'Global');
    }
    return trimmed;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<_AuditLog> filteredLogs = _filterCategory == null
        ? _auditLogs
        : _auditLogs
            .where((_AuditLog log) => log.category == _filterCategory)
            .toList();

    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: Text(_tHqAudit(context, 'Audit Logs')),
        backgroundColor: ScholesaColors.hqGradient.colors.first,
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () {
              _logAuditEvent('hq_audit_filter_open');
              _showFilterDialog();
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_task_rounded),
            onPressed: () {
              _logAuditEvent('hq_audit_create_review_open');
              _showCreateReviewDialog();
            },
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: () {
              _logAuditEvent('hq_audit_export_logs');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_tHqAudit(context, 'Exporting audit logs...')),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _buildSummaryHeader(),
            const SizedBox(height: 16),
            _buildSectionHeader(
              title: _tHqAudit(context, 'Audit Logs'),
              count: filteredLogs.length,
            ),
            const SizedBox(height: 8),
            if (_isLoading && filteredLogs.isEmpty)
              _buildLoadingCard()
            else if (filteredLogs.isEmpty)
              _buildEmptyCard(_tHqAudit(context, 'No audit logs found'))
            else
              ...filteredLogs.map(_buildAuditCard),
            const SizedBox(height: 20),
            _buildSectionHeader(
              title: _tHqAudit(context, 'Red Team Reviews'),
              count: _redTeamReviews.length,
              trailing: TextButton.icon(
                onPressed: () {
                  _logAuditEvent('hq_audit_create_review_open');
                  _showCreateReviewDialog();
                },
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: Text(_tHqAudit(context, 'Create Review')),
              ),
            ),
            const SizedBox(height: 8),
            if (_isLoading && _redTeamReviews.isEmpty)
              _buildLoadingCard()
            else if (_redTeamReviews.isEmpty)
              _buildEmptyCard(_tHqAudit(context, 'No red team reviews yet'))
            else
              ..._redTeamReviews.map(_buildReviewCard),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ScholesaColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _buildSummaryStat(
              _tHqAudit(context, 'Total'),
              _auditLogs.length.toString(),
              Colors.blue,
            ),
          ),
          Expanded(
            child: _buildSummaryStat(
              _tHqAudit(context, 'Auth'),
              _auditLogs
                  .where((_AuditLog log) => log.category == _AuditCategory.auth)
                  .length
                  .toString(),
              Colors.green,
            ),
          ),
          Expanded(
            child: _buildSummaryStat(
              _tHqAudit(context, 'Admin'),
              _auditLogs
                  .where(
                    (_AuditLog log) => log.category == _AuditCategory.admin,
                  )
                  .length
                  .toString(),
              Colors.orange,
            ),
          ),
          Expanded(
            child: _buildSummaryStat(
              _tHqAudit(context, 'Reviews'),
              _redTeamReviews.length.toString(),
              Colors.purple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, Color color) {
    return Column(
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
          style: const TextStyle(
            fontSize: 11,
            color: ScholesaColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required int count,
    Widget? trailing,
  }) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            '$title ($count)',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildLoadingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(_tHqAudit(context, 'Loading...')),
        ),
      ),
    );
  }

  Widget _buildEmptyCard(String label) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          label,
          style: const TextStyle(color: ScholesaColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildAuditCard(_AuditLog log) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _buildCategoryIcon(log.category),
        title: Text(log.action),
        subtitle: Text('${log.actor} • ${_formatTime(log.timestamp)}'),
        onTap: () => _showLogDetails(log),
      ),
    );
  }

  Widget _buildReviewCard(_RedTeamReview review) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.security_update_good_rounded),
        title: Text(review.title),
        subtitle: Text(
          '${_siteScopeLabel(review.siteId)} • ${_decisionLabel(review.decision)} • ${_formatTime(review.updatedAt)}',
        ),
        trailing: _AuditPill(
          label: _partnerStatusLabel(review.partnerStatus),
          color: review.partnerStatus == 'active'
              ? Colors.green
              : review.partnerStatus == 'watch'
                  ? Colors.orange
                  : Colors.red,
        ),
        onTap: () => _showReviewDetails(review),
      ),
    );
  }

  Widget _buildCategoryIcon(_AuditCategory category) {
    late final IconData icon;
    late final Color color;
    switch (category) {
      case _AuditCategory.auth:
        icon = Icons.login_rounded;
        color = Colors.green;
      case _AuditCategory.data:
        icon = Icons.storage_rounded;
        color = Colors.blue;
      case _AuditCategory.admin:
        icon = Icons.admin_panel_settings_rounded;
        color = Colors.orange;
      case _AuditCategory.system:
        icon = Icons.settings_rounded;
        color = Colors.purple;
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Future<void> _loadData() async {
    _logAuditEvent('hq_audit_refresh');
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('listAuditLogs');
      final HttpsCallableResult<dynamic> result =
          await callable.call(<String, dynamic>{'limit': 120});
      final Map<String, dynamic> payload =
          WorkflowBridgeService.asMap(result.data);
      final List<Map<String, dynamic>> rows =
          (payload['logs'] as List<dynamic>? ?? <dynamic>[])
              .map(WorkflowBridgeService.asMap)
              .toList(growable: false);
      final List<_AuditLog> loadedLogs = rows
          .map((Map<String, dynamic> row) {
            final String actionRaw =
                (row['action'] as String? ?? 'unknown').trim();
            return _AuditLog(
              id: row['id'] as String? ?? '',
              action: _titleFromAction(actionRaw),
              category: _categoryFromAction(actionRaw),
              actor: (row['actorEmail'] as String?)?.trim().isNotEmpty == true
                  ? (row['actorEmail'] as String).trim()
                  : (row['actorId'] as String? ?? 'system'),
              timestamp: WorkflowBridgeService.toDateTime(
                    row['createdAt'] ?? row['timestamp'] ?? row['updatedAt'],
                  ) ??
                  DateTime.now(),
              details: _detailsToText(row['details']),
            );
          })
          .where((_AuditLog log) => log.id.isNotEmpty)
          .toList(growable: false)
        ..sort(
            (_AuditLog a, _AuditLog b) => b.timestamp.compareTo(a.timestamp));

      final List<Map<String, dynamic>> reviewsRaw =
          await _workflowBridgeService.listRedTeamReviews(limit: 80);
      final List<_RedTeamReview> loadedReviews =
          reviewsRaw.map((Map<String, dynamic> row) {
        return _RedTeamReview(
          id: row['id'] as String? ?? '',
          title: row['title'] as String? ?? _tHqAudit(context, 'Red Team Review'),
          decision: row['decision'] as String? ?? 'continue',
          partnerStatus: row['partnerStatus'] as String? ?? 'active',
          recommendations: row['recommendations'] as String? ?? '',
          nextAction: row['nextAction'] as String? ?? '',
          updatedAt: WorkflowBridgeService.toDateTime(row['updatedAt']) ??
              WorkflowBridgeService.toDateTime(row['createdAt']) ??
              DateTime.now(),
          siteId: row['siteId'] as String?,
        );
      }).toList(growable: false)
            ..sort(
              (_RedTeamReview a, _RedTeamReview b) =>
                  b.updatedAt.compareTo(a.updatedAt),
            );

      if (!mounted) return;
      setState(() {
        _auditLogs = loadedLogs;
        _redTeamReviews = loadedReviews;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _auditLogs = <_AuditLog>[];
        _redTeamReviews = <_RedTeamReview>[];
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showFilterDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(_tHqAudit(context, 'Filter by Category')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _buildFilterOption(_tHqAudit(context, 'All'), null),
            _buildFilterOption(_categoryLabel(_AuditCategory.auth), _AuditCategory.auth),
            _buildFilterOption(_categoryLabel(_AuditCategory.data), _AuditCategory.data),
            _buildFilterOption(_categoryLabel(_AuditCategory.admin), _AuditCategory.admin),
            _buildFilterOption(_categoryLabel(_AuditCategory.system), _AuditCategory.system),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(String label, _AuditCategory? category) {
    return ListTile(
      title: Text(label),
      leading: Icon(
        _filterCategory == category
            ? Icons.radio_button_checked
            : Icons.radio_button_off,
      ),
      onTap: () {
        _logAuditEvent(
          'hq_audit_filter_apply',
          <String, dynamic>{'category': category?.name ?? 'all'},
        );
        setState(() => _filterCategory = category);
        Navigator.pop(context);
      },
    );
  }

  void _showLogDetails(_AuditLog log) {
    _logAuditEvent(
      'hq_audit_log_open',
      <String, dynamic>{'category': log.category.name, 'log_id': log.id},
    );
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ScholesaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              log.action,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildDetailRow(_tHqAudit(context, 'Actor'), log.actor),
            _buildDetailRow(_tHqAudit(context, 'Time'), _formatTime(log.timestamp)),
            const SizedBox(height: 8),
            Text(log.details),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_tHqAudit(context, 'Close')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReviewDetails(_RedTeamReview review) {
    _logAuditEvent(
      'hq_audit_review_open',
      <String, dynamic>{'review_id': review.id, 'decision': review.decision},
    );
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ScholesaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            Text(
              review.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildDetailRow(
              _tHqAudit(context, 'Decision'),
              _decisionLabel(review.decision),
            ),
            _buildDetailRow(
              _tHqAudit(context, 'Partner Status'),
              _partnerStatusLabel(review.partnerStatus),
            ),
            if ((review.siteId ?? '').trim().isNotEmpty)
              _buildDetailRow(_tHqAudit(context, 'Site ID'), review.siteId!),
            const SizedBox(height: 8),
            Text(
              _tHqAudit(context, 'Recommendations'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(review.recommendations),
            const SizedBox(height: 12),
            Text(
              _tHqAudit(context, 'Next Action'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(review.nextAction),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_tHqAudit(context, 'Close')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateReviewDialog() async {
    final BuildContext pageContext = context;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(pageContext);
    final TextEditingController titleController = TextEditingController();
    final TextEditingController siteIdController = TextEditingController();
    final TextEditingController kpiPackIdController = TextEditingController();
    final TextEditingController recommendationsController =
        TextEditingController();
    final TextEditingController nextActionController = TextEditingController();
    String decision = 'continue';
    String partnerStatus = 'active';
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context,
            void Function(void Function()) setLocalState) {
          return AlertDialog(
            title: Text(_tHqAudit(context, 'Create Review')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: _tHqAudit(context, 'Title'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: siteIdController,
                    decoration: InputDecoration(
                      labelText: _tHqAudit(context, 'Site ID'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: kpiPackIdController,
                    decoration: InputDecoration(
                      labelText: _tHqAudit(context, 'KPI Pack ID'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: decision,
                    decoration: InputDecoration(
                      labelText: _tHqAudit(context, 'Decision'),
                    ),
                    items: const <String>['continue', 'stabilize', 'intervene']
                        .map((String value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(_decisionLabel(value)),
                            ))
                        .toList(),
                    onChanged: (String? value) =>
                        setLocalState(() => decision = value ?? 'continue'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: partnerStatus,
                    decoration: InputDecoration(
                      labelText: _tHqAudit(context, 'Partner Status'),
                    ),
                    items: const <String>['active', 'watch', 'hold']
                        .map((String value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(_partnerStatusLabel(value)),
                            ))
                        .toList(),
                    onChanged: (String? value) =>
                        setLocalState(() => partnerStatus = value ?? 'active'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: recommendationsController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: _tHqAudit(context, 'Recommendations'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nextActionController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: _tHqAudit(context, 'Next Action'),
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed:
                    isSubmitting ? null : () => Navigator.pop(dialogContext),
                child: Text(_tHqAudit(context, 'Close')),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (titleController.text.trim().isEmpty) {
                          return;
                        }
                        final String reviewCreatedLabel =
                            _tHqAudit(pageContext, 'Review created');
                        final String reviewFailedLabel =
                            _tHqAudit(pageContext, 'Failed to create review');
                        setLocalState(() => isSubmitting = true);
                        try {
                          await _workflowBridgeService.upsertRedTeamReview(
                            <String, dynamic>{
                              'title': titleController.text.trim(),
                              if (siteIdController.text.trim().isNotEmpty)
                                'siteId': siteIdController.text.trim(),
                              if (kpiPackIdController.text.trim().isNotEmpty)
                                'kpiPackId': kpiPackIdController.text.trim(),
                              'decision': decision,
                              'partnerStatus': partnerStatus,
                              'recommendations':
                                  recommendationsController.text.trim(),
                              'nextAction': nextActionController.text.trim(),
                            },
                          );
                          if (!mounted || !dialogContext.mounted) {
                            return;
                          }
                          Navigator.pop(dialogContext);
                          await _loadData();
                          if (!mounted) return;
                          _logAuditEvent(
                            'hq_audit_create_review_submit',
                            <String, dynamic>{
                              'decision': decision,
                              'partner_status': partnerStatus,
                              'has_site_id':
                                  siteIdController.text.trim().isNotEmpty,
                            },
                          );
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(reviewCreatedLabel),
                            ),
                          );
                        } catch (_) {
                          if (!mounted) return;
                          _logAuditEvent(
                            'hq_audit_create_review_error',
                            <String, dynamic>{
                              'decision': decision,
                              'partner_status': partnerStatus,
                            },
                          );
                          setLocalState(() => isSubmitting = false);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(reviewFailedLabel),
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
                    : Text(_tHqAudit(context, 'Create Review')),
              ),
            ],
          );
        },
      ),
    );

    titleController.dispose();
    siteIdController.dispose();
    kpiPackIdController.dispose();
    recommendationsController.dispose();
    nextActionController.dispose();
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(color: ScholesaColors.textSecondary),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  _AuditCategory _categoryFromAction(String action) {
    final String value = action.toLowerCase();
    if (value.contains('login') || value.contains('auth')) {
      return _AuditCategory.auth;
    }
    if (value.contains('export') || value.contains('data')) {
      return _AuditCategory.data;
    }
    if (value.contains('config') || value.contains('system')) {
      return _AuditCategory.system;
    }
    return _AuditCategory.admin;
  }

  String _titleFromAction(String action) {
    final List<String> parts = action
        .replaceAll('_', ' ')
        .replaceAll('.', ' ')
        .split(' ')
        .where((String part) => part.isNotEmpty)
        .toList(growable: false);
    return parts
        .map(
          (String part) =>
              '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String _detailsToText(dynamic details) {
    if (details is String && details.trim().isNotEmpty) {
      return details.trim();
    }
    if (details is Map) {
      final Map<String, dynamic> asMap = WorkflowBridgeService.asMap(details);
      return asMap.entries
          .where((MapEntry<String, dynamic> entry) => entry.value != null)
          .map((MapEntry<String, dynamic> entry) =>
              '${entry.key}: ${entry.value}')
          .join(', ');
    }
    return '';
  }

  String _formatTime(DateTime time) {
    final Duration diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h';
    }
    return '${diff.inDays}d';
  }
}

class _AuditPill extends StatelessWidget {
  const _AuditPill({
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
        color: color.withValues(alpha: 0.14),
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
