import 'package:flutter/material.dart';
import '../../ui/theme/scholesa_theme.dart';

/// HQ Audit page for viewing audit logs and compliance reports
/// Based on docs/43_EXPORT_RETENTION_BACKUP_SPEC.md
class HqAuditPage extends StatefulWidget {
  const HqAuditPage({super.key});

  @override
  State<HqAuditPage> createState() => _HqAuditPageState();
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
    this.ipAddress,
  });

  final String id;
  final String action;
  final _AuditCategory category;
  final String actor;
  final DateTime timestamp;
  final String details;
  final String? ipAddress;
}

class _HqAuditPageState extends State<HqAuditPage> {
  final List<_AuditLog> _auditLogs = <_AuditLog>[
    _AuditLog(
      id: '1',
      action: 'User Login',
      category: _AuditCategory.auth,
      actor: 'admin@scholesa.io',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      details: 'Successful login from web client',
      ipAddress: '192.168.1.100',
    ),
    _AuditLog(
      id: '2',
      action: 'Role Changed',
      category: _AuditCategory.admin,
      actor: 'admin@scholesa.io',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      details: 'Changed user jane@school.edu role from educator to site_lead',
    ),
    _AuditLog(
      id: '3',
      action: 'Data Export',
      category: _AuditCategory.data,
      actor: 'reports@scholesa.io',
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      details: 'Exported learner progress report for Site: Downtown',
    ),
    _AuditLog(
      id: '4',
      action: 'Config Update',
      category: _AuditCategory.system,
      actor: 'system',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      details: 'Feature flag "new_dashboard" enabled globally',
    ),
  ];

  _AuditCategory? _filterCategory;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: const Text('Audit Logs'),
        backgroundColor: ScholesaColors.hqGradient.colors.first,
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () => _showFilterDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Exporting audit logs...')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _buildSummaryHeader(),
          Expanded(child: _buildAuditList()),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: ScholesaColors.surface,
      child: Row(
        children: <Widget>[
          Expanded(child: _buildSummaryStat('Total', _auditLogs.length.toString(), Colors.blue)),
          Expanded(child: _buildSummaryStat('Auth', _auditLogs.where((_AuditLog l) => l.category == _AuditCategory.auth).length.toString(), Colors.green)),
          Expanded(child: _buildSummaryStat('Admin', _auditLogs.where((_AuditLog l) => l.category == _AuditCategory.admin).length.toString(), Colors.orange)),
          Expanded(child: _buildSummaryStat('System', _auditLogs.where((_AuditLog l) => l.category == _AuditCategory.system).length.toString(), Colors.purple)),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, Color color) {
    return Column(
      children: <Widget>[
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: ScholesaColors.textSecondary)),
      ],
    );
  }

  Widget _buildAuditList() {
    final List<_AuditLog> filtered = _filterCategory == null
        ? _auditLogs
        : _auditLogs.where((_AuditLog l) => l.category == _filterCategory).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (BuildContext context, int index) => _buildAuditCard(filtered[index]),
    );
  }

  Widget _buildAuditCard(_AuditLog log) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: _buildCategoryIcon(log.category),
        title: Text(log.action, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(log.details, style: TextStyle(fontSize: 12, color: ScholesaColors.textSecondary)),
            const SizedBox(height: 4),
            Text(
              '${log.actor} • ${_formatTime(log.timestamp)}',
              style: TextStyle(fontSize: 11, color: ScholesaColors.textSecondary),
            ),
          ],
        ),
        isThreeLine: true,
        onTap: () => _showLogDetails(log),
      ),
    );
  }

  Widget _buildCategoryIcon(_AuditCategory category) {
    IconData icon;
    Color color;
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

  void _showFilterDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: ScholesaColors.surface,
        title: const Text('Filter by Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _buildFilterOption('All', null),
            _buildFilterOption('Auth', _AuditCategory.auth),
            _buildFilterOption('Data', _AuditCategory.data),
            _buildFilterOption('Admin', _AuditCategory.admin),
            _buildFilterOption('System', _AuditCategory.system),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(String label, _AuditCategory? category) {
    return ListTile(
      title: Text(label),
      leading: Radio<_AuditCategory?>(
        value: category,
        groupValue: _filterCategory,
        onChanged: (_AuditCategory? value) {
          setState(() => _filterCategory = value);
          Navigator.pop(context);
        },
      ),
      onTap: () {
        setState(() => _filterCategory = category);
        Navigator.pop(context);
      },
    );
  }

  void _showLogDetails(_AuditLog log) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ScholesaColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(log.action, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildDetailRow('Category', log.category.name.toUpperCase()),
            _buildDetailRow('Actor', log.actor),
            _buildDetailRow('Time', _formatTime(log.timestamp)),
            if (log.ipAddress != null) _buildDetailRow('IP Address', log.ipAddress!),
            const SizedBox(height: 8),
            Text('Details', style: TextStyle(fontWeight: FontWeight.w600, color: ScholesaColors.textSecondary)),
            const SizedBox(height: 4),
            Text(log.details),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: TextStyle(color: ScholesaColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final Duration diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
