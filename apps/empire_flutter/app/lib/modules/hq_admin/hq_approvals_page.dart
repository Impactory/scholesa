import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../i18n/workflow_surface_i18n.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';

String _tHqApprovals(BuildContext context, String input) {
  return WorkflowSurfaceI18n.text(context, input);
}

/// HQ Approvals page for approving partner contracts, curriculum, etc.
/// Based on docs/16_PARTNER_CONTRACTING_WORKFLOWS_SPEC.md
class HqApprovalsPage extends StatefulWidget {
  const HqApprovalsPage({
    super.key,
    this.loadApprovals,
    this.decideApproval,
  });

  final Future<List<Map<String, dynamic>>> Function()? loadApprovals;
  final Future<void> Function({required String id, required String status})?
      decideApproval;

  @override
  State<HqApprovalsPage> createState() => _HqApprovalsPageState();
}

enum _ApprovalType { partnerContract, payout, curriculum, siteConfig, userRole }

enum _ApprovalStatus { pending, approved, rejected }

class _ApprovalItem {
  const _ApprovalItem({
    required this.id,
    required this.title,
    required this.type,
    required this.submittedBy,
    required this.submittedAt,
    required this.status,
    required this.sourceCollection,
  });

  final String id;
  final String title;
  final _ApprovalType type;
  final String submittedBy;
  final DateTime submittedAt;
  final _ApprovalStatus status;
  final String sourceCollection;
}

class _HqApprovalsPageState extends State<HqApprovalsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String? _loadError;

  List<_ApprovalItem> _approvals = <_ApprovalItem>[];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadApprovals();
    });
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
        title: Text(_tHqApprovals(context, 'Approvals')),
        backgroundColor: ScholesaColors.hqGradient.colors.first,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: <Widget>[
            Tab(text: _tHqApprovals(context, 'Pending')),
            Tab(text: _tHqApprovals(context, 'Completed')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          _buildApprovalList(_ApprovalStatus.pending),
          _buildCompletedList(),
        ],
      ),
    );
  }

  Widget _buildApprovalList(_ApprovalStatus statusFilter) {
    if (_isLoading && _approvals.isEmpty) {
      return Center(
        child: Text(
          _tHqApprovals(context, 'Loading...'),
          style: const TextStyle(color: ScholesaColors.textSecondary),
        ),
      );
    }

    if (_loadError != null && _approvals.isEmpty) {
      return _buildLoadErrorState(
        _tHqApprovals(context, 'Approvals are temporarily unavailable'),
        _loadError!,
      );
    }

    final List<_ApprovalItem> filtered = _approvals
        .where((_ApprovalItem a) => a.status == statusFilter)
        .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.check_circle_outline_rounded,
                size: 64, color: Colors.green.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              _tHqApprovals(context, 'No pending approvals'),
              style:
                  TextStyle(fontSize: 16, color: ScholesaColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        if (_loadError != null)
          _buildStaleDataBanner(
            _tHqApprovals(context, 'Unable to refresh approvals right now. Showing the last successful data.'),
          ),
        ...filtered.map(
          (_ApprovalItem item) => _buildApprovalCard(item),
        ),
      ],
    );
  }

  Widget _buildCompletedList() {
    if (_loadError != null && _approvals.isEmpty && !_isLoading) {
      return _buildLoadErrorState(
        _tHqApprovals(context, 'Approvals are temporarily unavailable'),
        _loadError!,
      );
    }

    final List<_ApprovalItem> completed = _approvals
        .where((_ApprovalItem a) => a.status != _ApprovalStatus.pending)
        .toList();

    if (completed.isEmpty) {
      return Center(
        child: Text(_tHqApprovals(context, 'No completed approvals'),
            style: const TextStyle(color: ScholesaColors.textSecondary)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        if (_loadError != null)
          _buildStaleDataBanner(
            _tHqApprovals(context, 'Unable to refresh approvals right now. Showing the last successful data.'),
          ),
        ...completed.map(
          (_ApprovalItem item) =>
              _buildApprovalCard(item, showActions: false),
        ),
      ],
    );
  }

  Widget _buildLoadErrorState(String title, String message) {
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
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ScholesaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ScholesaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadApprovals,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(_tHqApprovals(context, 'Retry')),
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

  Widget _buildApprovalCard(_ApprovalItem item, {bool showActions = true}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _buildTypeIcon(item.type),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _tHqApprovals(context, item.title),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_tHqApprovals(context, 'By')} ${_tHqApprovals(context, item.submittedBy)}',
                        style: const TextStyle(
                            fontSize: 13, color: ScholesaColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (!showActions) _buildStatusBadge(item.status),
              ],
            ),
            if (showActions) ...<Widget>[
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _handleReject(item),
                      style:
                          OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      child: Text(_tHqApprovals(context, 'Reject')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleApprove(item),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green),
                      child: Text(_tHqApprovals(context, 'Approve')),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTypeIcon(_ApprovalType type) {
    IconData icon;
    Color color;
    switch (type) {
      case _ApprovalType.partnerContract:
        icon = Icons.handshake_rounded;
        color = Colors.purple;
      case _ApprovalType.payout:
        icon = Icons.account_balance_wallet_rounded;
        color = Colors.green;
      case _ApprovalType.curriculum:
        icon = Icons.menu_book_rounded;
        color = Colors.blue;
      case _ApprovalType.siteConfig:
        icon = Icons.settings_rounded;
        color = Colors.orange;
      case _ApprovalType.userRole:
        icon = Icons.person_rounded;
        color = Colors.teal;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildStatusBadge(_ApprovalStatus status) {
    Color color;
    String label;
    switch (status) {
      case _ApprovalStatus.pending:
        color = Colors.orange;
        label = 'Pending';
      case _ApprovalStatus.approved:
        color = Colors.green;
        label = 'Approved';
      case _ApprovalStatus.rejected:
        color = Colors.red;
        label = 'Rejected';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(_tHqApprovals(context, label),
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w500, color: color)),
    );
  }

  Future<void> _handleApprove(_ApprovalItem item) async {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'hq_approvals_approve',
        'approval_id': item.id
      },
    );
    if (item.type == _ApprovalType.partnerContract) {
      TelemetryService.instance.logEvent(
        event: 'contract.approved',
        metadata: <String, dynamic>{
          'approval_id': item.id,
          'source': 'hq_approvals_page',
        },
      );
    } else if (item.type == _ApprovalType.payout) {
      TelemetryService.instance.logEvent(
        event: 'payout.approved',
        metadata: <String, dynamic>{
          'approval_id': item.id,
          'source': 'hq_approvals_page',
        },
      );
    }
    await _updateApprovalStatus(item, _ApprovalStatus.approved);
  }

  Future<void> _handleReject(_ApprovalItem item) async {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'hq_approvals_reject',
        'approval_id': item.id
      },
    );
    await _updateApprovalStatus(item, _ApprovalStatus.rejected);
  }

  Future<void> _loadApprovals() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final List<_ApprovalItem> loaded = <_ApprovalItem>[];
      final List<dynamic> rows;
      if (widget.loadApprovals != null) {
      rows = await widget.loadApprovals!();
      } else {
      final HttpsCallable callable = FirebaseFunctions.instance
        .httpsCallable('listWorkflowApprovals');
      final HttpsCallableResult<dynamic> result =
        await callable.call(<String, dynamic>{'limit': 200});
      final Map<String, dynamic> payload =
        Map<String, dynamic>.from(result.data as Map<dynamic, dynamic>);
      rows = payload['approvals'] as List<dynamic>? ?? <dynamic>[];
      }

      for (final dynamic row in rows) {
        if (row is! Map) continue;
        final Map<String, dynamic> data = row.map((dynamic key, dynamic value) =>
            MapEntry(key.toString(), value));
        final String sourceCollection =
            (data['sourceCollection'] as String?) ?? 'partnerContracts';
        final _ApprovalType type = sourceCollection == 'payouts'
            ? _ApprovalType.payout
            : _ApprovalType.partnerContract;
        loaded.add(
          _ApprovalItem(
            id: (data['id'] as String?) ?? '',
            title: (data['title'] as String?)?.trim().isNotEmpty == true
                ? (data['title'] as String).trim()
                : 'Approval Item',
            type: type,
            submittedBy: (data['submittedBy'] as String?) ?? 'Ops',
            submittedAt: _toDateTime(data['updatedAt']) ??
                _toDateTime(data['createdAt']) ??
                DateTime.now(),
            status: _parseStatus(data['status'] as String?),
            sourceCollection: sourceCollection,
          ),
        );
      }

      loaded.sort((_ApprovalItem a, _ApprovalItem b) =>
          b.submittedAt.compareTo(a.submittedAt));

      if (!mounted) return;
      setState(() {
        _approvals = loaded;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = _tHqApprovals(
          context,
          'We could not load the approvals queue. Retry to check the current state.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateApprovalStatus(
      _ApprovalItem item, _ApprovalStatus newStatus) async {
    final String statusLabel =
        newStatus == _ApprovalStatus.approved ? 'approved' : 'rejected';

    try {
      if (widget.decideApproval != null) {
        await widget.decideApproval!(id: item.id, status: statusLabel);
      } else {
        final HttpsCallable callable = FirebaseFunctions.instance
            .httpsCallable('decideWorkflowApproval');
        await callable.call(<String, dynamic>{
          'id': item.id,
          'status': statusLabel,
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${newStatus == _ApprovalStatus.approved ? _tHqApprovals(context, 'Approved:') : _tHqApprovals(context, 'Rejected:')} ${_tHqApprovals(context, item.title)}',
          ),
          backgroundColor:
              newStatus == _ApprovalStatus.approved ? Colors.green : Colors.red,
        ),
      );
      await _loadApprovals();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tHqApprovals(context, 'Approval update failed')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  _ApprovalStatus _parseStatus(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'approved':
      case 'accepted':
      case 'published':
        return _ApprovalStatus.approved;
      case 'rejected':
      case 'denied':
      case 'declined':
        return _ApprovalStatus.rejected;
      default:
        return _ApprovalStatus.pending;
    }
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is Map && value['seconds'] is int) {
      final int seconds = value['seconds'] as int;
      final int nanos = (value['nanoseconds'] as int?) ?? 0;
      return DateTime.fromMillisecondsSinceEpoch(
          (seconds * 1000) + (nanos ~/ 1000000));
    }
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }
}
