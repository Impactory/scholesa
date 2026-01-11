import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/repositories.dart';
import '../../services/telemetry_service.dart';
import '../offline/offline_actions.dart';
import '../offline/offline_queue.dart';
import '../offline/offline_service.dart';

class LeadCaptureCard extends StatefulWidget {
  const LeadCaptureCard({
    super.key,
    required this.source,
    this.slug,
  });

  final String source;
  final String? slug;

  @override
  State<LeadCaptureCard> createState() => _LeadCaptureCardState();
}

class _LeadCaptureCardState extends State<LeadCaptureCard> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  final _siteController = TextEditingController();
  bool _isSubmitting = false;
  String? _feedback;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    _siteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_nameController.text.trim().isEmpty || _emailController.text.trim().isEmpty) {
      setState(() {
        _feedback = 'Name and email are required.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _feedback = null;
    });

    final offline = context.read<OfflineService>();
    final queue = context.read<OfflineQueue>();
    final leadRepository = LeadRepository();
    final trimmedName = _nameController.text.trim();
    final trimmedEmail = _emailController.text.trim();
    final trimmedMessage = _messageController.text.trim();
    final trimmedSite = _siteController.text.trim();

    try {
      if (offline.isOffline) {
        await OfflineActions.queueLead(
          queue,
          name: trimmedName,
          email: trimmedEmail,
          source: widget.source,
          message: trimmedMessage.isEmpty ? null : trimmedMessage,
          siteId: trimmedSite.isEmpty ? null : trimmedSite,
          slug: widget.slug,
        );
        setState(() {
          _feedback = 'Saved offline. We will reach out once you are back online.';
        });
      } else {
        await leadRepository.createLead(
          name: trimmedName,
          email: trimmedEmail,
          source: widget.source,
          message: trimmedMessage.isEmpty ? null : trimmedMessage,
          siteId: trimmedSite.isEmpty ? null : trimmedSite,
          slug: widget.slug,
        );
        await TelemetryService.instance.logEvent(
          event: 'lead.submitted',
          metadata: {
            'source': widget.source,
            if (widget.slug != null) 'slug': widget.slug,
          },
        );
        setState(() {
          _feedback = 'Thanks — we will reach out shortly.';
        });
      }

      _nameController.clear();
      _emailController.clear();
      _messageController.clear();
      _siteController.clear();
    } catch (_) {
      setState(() {
        _feedback = 'Could not send right now. Please retry.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mail_outline, color: Colors.white70),
              const SizedBox(width: 8),
              Text('Talk to us', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          Text('Share your site or studio and we will set up your Scholesa workspace.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
          const SizedBox(height: 14),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(label: 'Name', hint: 'Your name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(label: 'Email', hint: 'you@example.com'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _siteController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(label: 'Site / Studio', hint: 'City or site code (optional)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _messageController,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(label: 'What do you need?', hint: 'e.g., onboarding 50 learners next month'),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  foregroundColor: const Color(0xFF0B1224),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Request a call', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              if (_feedback != null)
                Expanded(
                  child: Text(
                    _feedback!,
                    style: TextStyle(color: _feedback!.contains('Thanks') ? Colors.greenAccent : Colors.amberAccent),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration({required String label, required String hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: const TextStyle(color: Colors.white70),
    hintStyle: const TextStyle(color: Colors.white38),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.04),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.white24),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.white70, width: 1.2),
    ),
  );
}
