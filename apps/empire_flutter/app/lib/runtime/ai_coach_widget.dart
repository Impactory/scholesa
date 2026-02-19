import 'package:flutter/material.dart';
import 'bos_models.dart';
import 'bos_service.dart';
import 'learning_runtime_provider.dart';

// ──────────────────────────────────────────────────────
// AI Coach Widget — Control Surface
// Spec: BOS_MIA_HOW_TO_IMPLEMENT.md §5, A0–A2
//
// AI is a control surface in the closed-loop runtime:
//   Sense → Detect → Estimate → Control → Gate → Govern
//
// Modes: hint (low assist), verify (evidence check),
//        explain (scaffolding), debug (guided debugging).
// Forbidden: final answers, doing student's work, punitive language.
// ──────────────────────────────────────────────────────

/// AI Coach chat panel for learner missions.
///
/// Emits events: ai_help_opened, ai_help_used, ai_coach_feedback.
/// Respects MVL gating — intercepted responses trigger verification.
class AiCoachWidget extends StatefulWidget {
  const AiCoachWidget({
    required this.runtime,
    this.missionId,
    this.checkpointId,
    this.conceptTags = const <String>[],
    super.key,
  });

  final LearningRuntimeProvider runtime;
  final String? missionId;
  final String? checkpointId;
  final List<String> conceptTags;

  @override
  State<AiCoachWidget> createState() => _AiCoachWidgetState();
}

class _AiCoachWidgetState extends State<AiCoachWidget> {
  final TextEditingController _inputController = TextEditingController();
  final List<_ChatMessage> _messages = <_ChatMessage>[];
  AiCoachMode _selectedMode = AiCoachMode.hint;
  bool _loading = false;
  AiCoachResponse? _lastResponse;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final String input = _inputController.text.trim();
    if (_loading) return;

    setState(() {
      if (input.isNotEmpty) {
        _messages.add(_ChatMessage(text: input, isUser: true));
      }
      _loading = true;
      _inputController.clear();
    });

    // Emit ai_help_opened (client-side tracking)
    widget.runtime.trackEvent(
      'ai_help_opened',
      missionId: widget.missionId,
      checkpointId: widget.checkpointId,
      payload: <String, dynamic>{'mode': _selectedMode.name},
    );

    try {
      final AiCoachRequest request = AiCoachRequest(
        siteId: widget.runtime.siteId,
        learnerId: widget.runtime.learnerId,
        gradeBand: widget.runtime.gradeBand,
        mode: _selectedMode,
        sessionOccurrenceId: widget.runtime.sessionOccurrenceId,
        missionId: widget.missionId,
        checkpointId: widget.checkpointId,
        conceptTags: widget.conceptTags,
        learnerState: widget.runtime.state?.xHat,
        studentInput: input.isNotEmpty ? input : null,
      );

      final AiCoachResponse response = await BosService.instance.callAiCoach(request);

      setState(() {
        _lastResponse = response;
        _messages.add(_ChatMessage(
          text: response.message,
          isUser: false,
          response: response,
        ));
        _loading = false;
      });

      // Emit ai_help_used (client-side tracking)
      widget.runtime.trackEvent(
        'ai_help_used',
        missionId: widget.missionId,
        checkpointId: widget.checkpointId,
        payload: <String, dynamic>{
          'mode': _selectedMode.name,
          'mvlGateActive': response.mvlGateActive,
          'requiresExplainBack': response.requiresExplainBack,
        },
      );
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(
          text: 'Unable to reach AI Coach right now. Try again in a moment.',
          isUser: false,
          isError: true,
        ));
        _loading = false;
      });
    }
  }

  void _sendFeedback(bool helpful) {
    widget.runtime.trackEvent(
      'ai_coach_feedback',
      missionId: widget.missionId,
      checkpointId: widget.checkpointId,
      payload: <String, dynamic>{
        'helpful': helpful,
        'mode': _selectedMode.name,
        'aiHelpOpenedEventId': _lastResponse?.aiHelpOpenedEventId,
      },
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(helpful ? 'Thanks for the feedback!' : 'Noted — we\'ll improve.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasMvl = widget.runtime.hasMvlGate;

    return Column(
      children: <Widget>[
        // ── Mode selector ──
        _ModeSelector(
          selected: _selectedMode,
          onChanged: (AiCoachMode mode) => setState(() => _selectedMode = mode),
        ),

        if (hasMvl)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.verified_user, color: Colors.amber.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Verification active — show your understanding first.',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.amber.shade900),
                  ),
                ),
              ],
            ),
          ),

        // ── Chat messages ──
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.smart_toy_outlined, size: 48, color: theme.colorScheme.primary.withAlpha(128)),
                        const SizedBox(height: 12),
                        Text(
                          'AI Coach',
                          style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select a mode and ask for help.\nI\'ll guide your thinking — not give answers.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: _messages.length,
                  itemBuilder: (BuildContext context, int index) {
                    return _ChatBubble(
                      message: _messages[index],
                      onFeedback: index == _messages.length - 1 && !_messages[index].isUser
                          ? _sendFeedback
                          : null,
                    );
                  },
                ),
        ),

        // ── Input bar ──
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(top: BorderSide(color: theme.dividerColor)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    decoration: InputDecoration(
                      hintText: _modeHint(_selectedMode),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    maxLines: 3,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _loading ? null : _sendMessage,
                  icon: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _modeHint(AiCoachMode mode) {
    switch (mode) {
      case AiCoachMode.hint:
        return 'Ask for a hint...';
      case AiCoachMode.verify:
        return 'Describe your approach to verify...';
      case AiCoachMode.explain:
        return 'What would you like explained?';
      case AiCoachMode.debug:
        return 'Describe the issue you\'re seeing...';
    }
  }
}

// ──── Mode selector chip bar ────

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.selected, required this.onChanged});

  final AiCoachMode selected;
  final ValueChanged<AiCoachMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: AiCoachMode.values.map((AiCoachMode mode) {
          final bool isSelected = mode == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(_modeLabel(mode)),
              selected: isSelected,
              onSelected: (_) => onChanged(mode),
              avatar: Icon(_modeIcon(mode), size: 16),
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
      ),
    );
  }

  String _modeLabel(AiCoachMode mode) {
    switch (mode) {
      case AiCoachMode.hint:
        return 'Hint';
      case AiCoachMode.verify:
        return 'Verify';
      case AiCoachMode.explain:
        return 'Explain';
      case AiCoachMode.debug:
        return 'Debug';
    }
  }

  IconData _modeIcon(AiCoachMode mode) {
    switch (mode) {
      case AiCoachMode.hint:
        return Icons.lightbulb_outline;
      case AiCoachMode.verify:
        return Icons.check_circle_outline;
      case AiCoachMode.explain:
        return Icons.school_outlined;
      case AiCoachMode.debug:
        return Icons.bug_report_outlined;
    }
  }
}

// ──── Chat message model ────

class _ChatMessage {
  _ChatMessage({
    required this.text,
    required this.isUser,
    this.response,
    this.isError = false,
  });

  final String text;
  final bool isUser;
  final AiCoachResponse? response;
  final bool isError;
}

// ──── Chat bubble ────

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, this.onFeedback});

  final _ChatMessage message;
  final void Function(bool helpful)? onFeedback;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primary
              : message.isError
                  ? Colors.red.shade50
                  : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              message.text,
              style: TextStyle(
                color: isUser ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
              ),
            ),

            // MVL gate indicator
            if (message.response?.mvlGateActive == true)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.verified_user, size: 14, color: Colors.amber.shade700),
                    const SizedBox(width: 4),
                    Text(
                      'Verification required',
                      style: theme.textTheme.labelSmall?.copyWith(color: Colors.amber.shade700),
                    ),
                  ],
                ),
              ),

            // Suggested next steps
            if (message.response != null && message.response!.suggestedNextSteps.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: message.response!.suggestedNextSteps.map((String step) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('→ ', style: TextStyle(color: theme.colorScheme.primary, fontSize: 12)),
                          Expanded(
                            child: Text(
                              step,
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

            // Feedback buttons (last AI message only)
            if (onFeedback != null && !isUser)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text('Helpful?', style: theme.textTheme.labelSmall),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => onFeedback!(true),
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.thumb_up_outlined, size: 16),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => onFeedback!(false),
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.thumb_down_outlined, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
