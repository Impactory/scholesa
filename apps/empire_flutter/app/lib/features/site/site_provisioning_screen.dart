import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/repositories.dart';
import '../auth/app_state.dart';

class SiteProvisioningScreen extends StatefulWidget {
  const SiteProvisioningScreen({super.key});

  @override
  State<SiteProvisioningScreen> createState() => _SiteProvisioningScreenState();
}

class _SiteProvisioningScreenState extends State<SiteProvisioningScreen> {
  final TextEditingController _parentController = TextEditingController();
  final TextEditingController _learnerController = TextEditingController();
  final TextEditingController _relationshipController = TextEditingController();
  late TextEditingController _siteController;
  bool _isPrimary = true;
  bool _submitting = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    final siteId = context.read<AppState>().primarySiteId ?? '';
    _siteController = TextEditingController(text: siteId);
  }

  @override
  void dispose() {
    _parentController.dispose();
    _learnerController.dispose();
    _relationshipController.dispose();
    _siteController.dispose();
    super.dispose();
  }

  Future<void> _linkGuardian() async {
    final parentId = _parentController.text.trim();
    final learnerId = _learnerController.text.trim();
    final siteId = _siteController.text.trim();
    if (parentId.isEmpty || learnerId.isEmpty || siteId.isEmpty) return;
    setState(() {
      _submitting = true;
      _message = null;
    });
    try {
      await GuardianLinkRepository().create(
        parentId: parentId,
        learnerId: learnerId,
        siteId: siteId,
        relationship: _relationshipController.text.trim().isEmpty ? null : _relationshipController.text.trim(),
        isPrimary: _isPrimary,
      );
      setState(() => _message = 'Guardian linked successfully');
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Provisioning')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Provision users, link guardians, set roles (phase 1).'),
          const SizedBox(height: 12),
          TextField(
            controller: _siteController,
            decoration: const InputDecoration(labelText: 'Site ID'),
          ),
          TextField(
            controller: _parentController,
            decoration: const InputDecoration(labelText: 'Parent user ID'),
          ),
          TextField(
            controller: _learnerController,
            decoration: const InputDecoration(labelText: 'Learner user ID'),
          ),
          TextField(
            controller: _relationshipController,
            decoration: const InputDecoration(labelText: 'Relationship (optional)'),
          ),
          Row(
            children: [
              Checkbox(
                value: _isPrimary,
                onChanged: (value) => setState(() => _isPrimary = value ?? true),
              ),
              const Text('Primary guardian'),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _submitting ? null : _linkGuardian,
            child: _submitting ? const CircularProgressIndicator() : const Text('Create guardian link'),
          ),
          if (_message != null) ...[
            const SizedBox(height: 8),
            Text(_message!, style: const TextStyle(color: Colors.green)),
          ],
          const SizedBox(height: 16),
          const Text('Follow docs 06/41/46 for deeper provisioning (roles, invites, onboarding).'),
        ],
      ),
    );
  }
}
