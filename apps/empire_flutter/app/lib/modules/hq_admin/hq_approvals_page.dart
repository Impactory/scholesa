import 'package:flutter/material.dart';
import '../../ui/theme/scholesa_theme.dart';

/// HQ Approvals page for approving partner contracts, curriculum, etc.
/// Based on docs/16_PARTNER_CONTRACTING_WORKFLOWS_SPEC.md
class HqApprovalsPage extends StatefulWidget {
  const HqApprovalsPage({super.key});

  @override
  State<HqApprovalsPage> createState() => _HqApprovalsPageState();
}

enum _ApprovalType { partnerContract, curriculum, siteConfig, userRole }
enum _ApprovalStatus { pending, approved, rejected }

class _ApprovalItem {
  const _ApprovalItem({
    required this.id,
    required this.title,
    required this.type,
    required this.submittedBy,
    required this.submittedAt,
    required this.status,
    this.notes,
  });

  final String id;
  final String title;
  final _ApprovalType type;
  final String submittedBy;
  final DateTime submittedAt;
  final _ApprovalStatus status;
  final String? notes;
}

class _HqApprovalsPageState extends State<HqApprovalsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  final List<_ApprovalItem> _approvals = <_ApprovalItem>[
    _ApprovalItem(
      id: '1',
      title: 'New Partner: TechEd Solutions',
      type: _ApprovalType.partnerContract,
      submittedBy: 'Site Lead - Downtown',
      submittedAt: DateTime.now().subtract(const Duration(hours: 2)),
      status: _ApprovalStatus.pending,
    ),
    _ApprovalItem(
      id: '2',
      title: 'Curriculum: AI Fundamentals v2.0',
      type: _ApprovalType.curriculum,
      submittedBy: 'Curriculum Team',
      submittedAt: DateTime.now().subtract(const Duration(days: 1)),
      status: _ApprovalStatus.pending,
    ),
    _ApprovalItem(
      id: '3',
      title: 'Role Change: Jane D. → Site Lead',
      type: _ApprovalType.userRole,
      submittedBy: 'HR Admin',
      submittedAt: DateTime.now().subtract(const Duration(days: 2)),
      status: _ApprovalStatus.approved,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        title: const Text('Approvals'),
        backgroundColor: ScholesaColors.hqGradient.colors.first,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const <Widget>[
            Tab(text: 'Pending'),
            Tab(text: 'Completed'),
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
    final List<_ApprovalItem> filtered = _approvals
        .where((_ApprovalItem a) => a.status == statusFilter)
        .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.green.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'No pending approvals',
              style: TextStyle(fontSize: 16, color: ScholesaColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (BuildContext context, int index) => _buildApprovalCard(filtered[index]),
    );
  }

  Widget _buildCompletedList() {
    final List<_ApprovalItem> completed = _approvals
        .where((_ApprovalItem a) => a.status != _ApprovalStatus.pending)
        .toList();

    if (completed.isEmpty) {
      return Center(
        child: Text('No completed approvals', style: TextStyle(color: ScholesaColors.textSecondary)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: completed.length,
      itemBuilder: (BuildContext context, int index) => _buildApprovalCard(completed[index], showActions: false),
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
                        item.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'By ${item.submittedBy}',
                        style: TextStyle(fontSize: 13, color: ScholesaColors.textSecondary),
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
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleApprove(item),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text('Approve'),
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
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
    );
  }

  void _handleApprove(_ApprovalItem item) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Approved: ${item.title}'), backgroundColor: Colors.green),
    );
  }

  void _handleReject(_ApprovalItem item) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Rejected: ${item.title}'), backgroundColor: Colors.red),
    );
  }
}
