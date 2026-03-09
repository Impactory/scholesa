import 'package:flutter/material.dart';

import '../ui/localization/inline_locale_text.dart';
import 'bos_models.dart';
import 'bos_service.dart';
import 'learning_runtime_provider.dart';

const Map<String, String> _mvlGateZhCn = <String, String>{
  "Great work! You've demonstrated your understanding. Keep going!":
      '做得很好！你已经展示了自己的理解。继续保持！',
  'Almost there — can you provide one more piece of evidence?':
      '快完成了，还能再提供一项证据吗？',
  'Good start! Share one more insight to complete the verification.':
      '开了个好头！再分享一个见解即可完成验证。',
  'Something went wrong. Please try again.': '发生了一些问题，请重试。',
  'Learner disagrees with verification requirement': '学习者不同意该验证要求',
  'Your feedback has been sent to your educator for review.': '你的反馈已发送给导师审核。',
  'Unable to send feedback right now.': '目前无法发送反馈。',
  'Show Your Understanding': '展示你的理解',
  "Take a moment to demonstrate what you've learned.": '花一点时间展示你学到了什么。',
  'Explain in your own words:': '用你自己的话解释：',
  'What have you learned? How would you explain this concept to a friend?':
      '你学到了什么？你会如何向朋友解释这个概念？',
  ' evidence item': ' 条证据',
  's': '',
  ' submitted': ' 已提交',
  ' — scoring...': '，正在评分...',
  ' — 1 more needed': '，还需要 1 条',
  'Submitting...': '提交中...',
  'Submit Evidence': '提交证据',
  "I think this check isn't needed": '我认为这项检查没有必要',
};

const Map<String, String> _mvlGateZhTw = <String, String>{
  "Great work! You've demonstrated your understanding. Keep going!":
      '做得很好！你已經展示了自己的理解。繼續保持！',
  'Almost there — can you provide one more piece of evidence?':
      '快完成了，還能再提供一項證據嗎？',
  'Good start! Share one more insight to complete the verification.':
      '開了個好頭！再分享一個見解即可完成驗證。',
  'Something went wrong. Please try again.': '發生了一些問題，請再試一次。',
  'Learner disagrees with verification requirement': '學習者不同意這項驗證要求',
  'Your feedback has been sent to your educator for review.': '你的回饋已送交導師審核。',
  'Unable to send feedback right now.': '目前無法送出回饋。',
  'Show Your Understanding': '展示你的理解',
  "Take a moment to demonstrate what you've learned.": '花一點時間展示你學到了什麼。',
  'Explain in your own words:': '用你自己的話解釋：',
  'What have you learned? How would you explain this concept to a friend?':
      '你學到了什麼？你會如何向朋友解釋這個概念？',
  ' evidence item': ' 項證據',
  's': '',
  ' submitted': ' 已提交',
  ' — scoring...': '，正在評分...',
  ' — 1 more needed': '，還需要 1 項',
  'Submitting...': '提交中...',
  'Submit Evidence': '提交證據',
  "I think this check isn't needed": '我認為這項檢查沒有必要',
};

String _tMvlGate(BuildContext context, String input) {
  return InlineLocaleText.of(
    context,
    input,
    zhCn: _mvlGateZhCn,
    zhTw: _mvlGateZhTw,
  );
}

// ──────────────────────────────────────────────────────
// MVL Gate Widget — Metacognitive Verification Loop
// Spec: BOS_MIA_HOW_TO_IMPLEMENT.md §8, Math Contract §8
//
// Non-punitive formative gate. When active:
// - Blocks submission/progression
// - Prompts learner for evidence of understanding
// - Accepts: explain-it-back, source checks, artifacts
// - Feeds evidence back into FDM → state estimation
//
// "Verify / explain / show evidence" — never "cheating."
// ──────────────────────────────────────────────────────

/// MVL Gate overlay — shows when `runtime.hasMvlGate == true`.
///
/// Usage: Wrap mission content with this widget.
/// ```dart
/// MvlGateWidget(
///   runtime: runtime,
///   child: MissionContentWidget(...),
/// )
/// ```
class MvlGateWidget extends StatelessWidget {
  const MvlGateWidget({
    required this.runtime,
    required this.child,
    super.key,
  });

  final LearningRuntimeProvider runtime;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!runtime.hasMvlGate) return child;

    return Stack(
      children: <Widget>[
        // Dimmed content behind the gate
        Opacity(opacity: 0.3, child: IgnorePointer(child: child)),

        // Gate overlay
        _MvlGateOverlay(runtime: runtime),
      ],
    );
  }
}

/// The actual gate overlay panel.
class _MvlGateOverlay extends StatefulWidget {
  const _MvlGateOverlay({required this.runtime});

  final LearningRuntimeProvider runtime;

  @override
  State<_MvlGateOverlay> createState() => _MvlGateOverlayState();
}

class _MvlGateOverlayState extends State<_MvlGateOverlay> {
  final TextEditingController _explainController = TextEditingController();
  bool _submitting = false;
  String? _feedback;
  final List<String> _submittedEvidenceIds = <String>[];

  MvlEpisode? get _episode => widget.runtime.activeMvl;

  @override
  void dispose() {
    _explainController.dispose();
    super.dispose();
  }

  Future<void> _submitExplainItBack() async {
    final String explanation = _explainController.text.trim();
    if (explanation.isEmpty || _submitting) return;

    setState(() => _submitting = true);

    try {
      // 1. Emit explain_it_back_submitted event (feeds FDM y_t)
      widget.runtime.trackEvent(
        'explain_it_back_submitted',
        payload: <String, dynamic>{
          'mvlEpisodeId': _episode?.id,
          'explanationLength': explanation.length,
          // Privacy-minimized: don't store raw text, only derived features
          'hasSubstance': explanation.split(' ').length > 5,
        },
      );

      // 2. Store as evidence event and add to MVL episode
      final String evidenceEventId =
          'eib_${DateTime.now().millisecondsSinceEpoch}';
      _submittedEvidenceIds.add(evidenceEventId);

      // 3. Submit evidence to the MVL episode
      if (_episode != null) {
        await BosService.instance.submitMvlEvidence(
          episodeId: _episode!.id,
          eventIds: <String>[evidenceEventId],
        );

        // Emit mvl_evidence_attached
        widget.runtime.trackEvent(
          'mvl_evidence_attached',
          payload: <String, dynamic>{
            'mvlEpisodeId': _episode!.id,
            'evidenceType': 'explain_it_back',
            'evidenceCount': _submittedEvidenceIds.length,
          },
        );

        // 4. Try to score the MVL episode
        if (_submittedEvidenceIds.length >= 2) {
          final String resolution = await BosService.instance.scoreMvl(
            episodeId: _episode!.id,
          );

          // Emit mvl_passed or mvl_failed
          widget.runtime.trackEvent(
            resolution == 'passed' ? 'mvl_passed' : 'mvl_failed',
            payload: <String, dynamic>{
              'mvlEpisodeId': _episode!.id,
              'evidenceCount': _submittedEvidenceIds.length,
            },
          );

          setState(() {
            _feedback = resolution == 'passed'
                ? _tMvlGate(context,
                    'Great work! You\'ve demonstrated your understanding. Keep going!')
                : _tMvlGate(context,
                    'Almost there — can you provide one more piece of evidence?');
          });
        } else {
          setState(() {
            _feedback = _tMvlGate(context,
                'Good start! Share one more insight to complete the verification.');
          });
        }
      }

      _explainController.clear();
    } catch (e) {
      setState(() {
        _feedback =
            _tMvlGate(context, 'Something went wrong. Please try again.');
      });
    } finally {
      setState(() => _submitting = false);
    }
  }

  Future<void> _requestContestability() async {
    if (_episode == null) return;

    widget.runtime.trackEvent(
      'contestability_requested',
      payload: <String, dynamic>{
        'mvlEpisodeId': _episode!.id,
      },
    );

    try {
      await BosService.instance.requestContestability(
        episodeId: _episode!.id,
        reason:
            _tMvlGate(context, 'Learner disagrees with verification requirement'),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tMvlGate(
              context, 'Your feedback has been sent to your educator for review.')),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(_tMvlGate(context, 'Unable to send feedback right now.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          elevation: 8,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Header
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.verified_user,
                          color: Colors.amber.shade800, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _tMvlGate(context, 'Show Your Understanding'),
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _tMvlGate(context,
                                'Take a moment to demonstrate what you\'ve learned.'),
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Explanation prompt
                Text(
                  _tMvlGate(context, 'Explain in your own words:'),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _explainController,
                  decoration: InputDecoration(
                    hintText: _tMvlGate(context,
                      'What have you learned? How would you explain this concept to a friend?'),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerLow,
                  ),
                  maxLines: 4,
                  minLines: 3,
                ),

                const SizedBox(height: 12),

                // Evidence count indicator
                if (_submittedEvidenceIds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.check_circle,
                            size: 16, color: Colors.green.shade600),
                        const SizedBox(width: 6),
                        Text(
                          '${_submittedEvidenceIds.length}${_tMvlGate(context, ' evidence item')}${_submittedEvidenceIds.length != 1 ? _tMvlGate(context, 's') : ''}${_tMvlGate(context, ' submitted')}'
                          '${_submittedEvidenceIds.length >= 2 ? _tMvlGate(context, ' — scoring...') : _tMvlGate(context, ' — 1 more needed')}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.green.shade700),
                        ),
                      ],
                    ),
                  ),

                // Feedback message
                if (_feedback != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.info_outline,
                            size: 18, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_feedback!,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: Colors.blue.shade800)),
                        ),
                      ],
                    ),
                  ),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : _submitExplainItBack,
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send),
                      label: Text(_submitting
                        ? _tMvlGate(context, 'Submitting...')
                        : _tMvlGate(context, 'Submit Evidence')),
                  ),
                ),

                const SizedBox(height: 12),

                // Contestability link (non-punitive, learner agency)
                Center(
                  child: TextButton.icon(
                    onPressed: _requestContestability,
                    icon: const Icon(Icons.feedback_outlined, size: 16),
                    label: Text(
                        _tMvlGate(context, 'I think this check isn\'t needed')),
                    style: TextButton.styleFrom(
                      textStyle: theme.textTheme.bodySmall,
                      foregroundColor: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
