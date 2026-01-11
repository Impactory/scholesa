import 'package:flutter/material.dart';

class HqSafetyScreen extends StatelessWidget {
  const HqSafetyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safety Oversight')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('Major/critical incidents oversight (stub).'),
          SizedBox(height: 12),
          Text('Wire to IncidentReport export/escalation per docs 41/43.'),
        ],
      ),
    );
  }
}
