import 'package:flutter/material.dart';

class HqAuditLogsScreen extends StatelessWidget {
  const HqAuditLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audit & Logs')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('Audit log review/export (stub).'),
          SizedBox(height: 12),
          Text('Wire to AuditLog and export flows per doc 43.'),
        ],
      ),
    );
  }
}
