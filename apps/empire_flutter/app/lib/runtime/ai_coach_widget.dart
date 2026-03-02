import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'bos_models.dart';
import 'bos_service.dart';
import 'learning_runtime_provider.dart';
import 'voice_runtime_service.dart';
import '../services/telemetry_service.dart';
import '../auth/app_state.dart';

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
    required this.actorRole,
    this.allowBosFallback = true,
    this.missionId,
    this.checkpointId,
    this.conceptTags = const <String>[],
    super.key,
  });

  final LearningRuntimeProvider runtime;
  final UserRole actorRole;
  final bool allowBosFallback;
  final String? missionId;
  final String? checkpointId;
  final List<String> conceptTags;

  @override
  State<AiCoachWidget> createState() => _AiCoachWidgetState();
}

class _AiCoachWidgetState extends State<AiCoachWidget> {
  final TextEditingController _inputController = TextEditingController();
  final List<_ChatMessage> _messages = <_ChatMessage>[];
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<void>? _playerCompleteSub;
  StreamSubscription<PlayerState>? _playerStateSub;
  AiCoachMode _selectedMode = AiCoachMode.hint;
  bool _loading = false;
  bool _isListening = false;
  bool _speechAvailable = false;
  bool _uploadSttAvailable = false;
  bool _usingUploadStt = false;
  bool _voiceOutputEnabled = true;
  bool _isSpeaking = false;
  final List<String> _learningGoals = <String>[];
  AiCoachResponse? _lastResponse;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeVoiceStack());
  }

  Future<void> _initializeVoiceStack() async {
    try {
      final bool speechReady = await _speechToText.initialize(
        onError: (_) {
          if (!mounted) return;
          setState(() => _isListening = false);
        },
        onStatus: (String status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            setState(() => _isListening = false);
          }
        },
      );
      await _flutterTts.setSpeechRate(0.45);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.awaitSpeakCompletion(true);

      if (Platform.isIOS || Platform.isMacOS) {
        await _flutterTts.setSharedInstance(true);
        await _flutterTts.autoStopSharedSession(false);
      }

      if (Platform.isIOS) {
        await _flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          <IosTextToSpeechAudioCategoryOptions>[
            IosTextToSpeechAudioCategoryOptions.duckOthers,
            IosTextToSpeechAudioCategoryOptions.allowAirPlay,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          ],
          IosTextToSpeechAudioMode.spokenAudio,
        );
      }

      await _audioPlayer.setAudioContext(
        AudioContextConfig(
          route: AudioContextConfigRoute.system,
          focus: AudioContextConfigFocus.duckOthers,
          respectSilence: false,
        ).build(),
      );

      _playerCompleteSub?.cancel();
      _playerCompleteSub = _audioPlayer.onPlayerComplete.listen((_) {
        if (!mounted) return;
        setState(() => _isSpeaking = false);
      });

      _playerStateSub?.cancel();
      _playerStateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
        if (!mounted) return;
        if (state == PlayerState.stopped || state == PlayerState.completed) {
          setState(() => _isSpeaking = false);
        }
      });

      _flutterTts.setStartHandler(() {
        if (!mounted) return;
        setState(() => _isSpeaking = true);
      });
      _flutterTts.setCompletionHandler(() {
        if (!mounted) return;
        setState(() => _isSpeaking = false);
      });
      _flutterTts.setErrorHandler((_) {
        if (!mounted) return;
        setState(() => _isSpeaking = false);
      });

      final bool uploadReady = await _audioRecorder.hasPermission();
      if (!mounted) return;
      setState(() {
        _speechAvailable = speechReady;
        _uploadSttAvailable = uploadReady;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _speechAvailable = false;
        _uploadSttAvailable = false;
      });
    }
  }

  @override
  void dispose() {
    unawaited(_speechToText.stop());
    unawaited(_flutterTts.stop());
    unawaited(_audioPlayer.stop());
    unawaited(_audioPlayer.dispose());
    unawaited(_audioRecorder.dispose());
    _playerCompleteSub?.cancel();
    _playerStateSub?.cancel();
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _startUploadRecording() async {
    if (_isSpeaking) {
      await _audioPlayer.stop();
      await _flutterTts.stop();
      if (mounted) setState(() => _isSpeaking = false);
    }

    final String path =
        '${Directory.systemTemp.path}/ai-coach-${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 16000,
      ),
      path: path,
    );
    if (!mounted) return;
    setState(() {
      _isListening = true;
      _usingUploadStt = true;
    });
  }

  Future<void> _stopUploadRecordingAndTranscribe() async {
    final String? path = await _audioRecorder.stop();
    if (!mounted) return;
    setState(() {
      _isListening = false;
      _usingUploadStt = false;
    });
    if (path == null || path.isEmpty) return;

    try {
      final TranscribeVoiceResponse transcribed =
          await VoiceRuntimeService.instance.transcribeAudioFile(
        audioFilePath: path,
        locale: Localizations.localeOf(context).toLanguageTag(),
      );

      if (!mounted) return;
      setState(() {
        _inputController.text = transcribed.transcript;
        _inputController.selection = TextSelection.fromPosition(
          TextPosition(offset: _inputController.text.length),
        );
      });

      await TelemetryService.instance.logEvent(
        event: 'voice.transcribe',
        metadata: <String, dynamic>{
          'source': 'voice_api_upload',
          'surface': 'ai_coach_widget',
          'chars': transcribed.transcript.length,
          'confidence': transcribed.confidence,
          'traceId': transcribed.traceId,
          'latencyMs': transcribed.latencyMs,
          'modelVersion': transcribed.modelVersion,
          'mode': _selectedMode.name,
        },
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice transcription unavailable. Please type your question.'),
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      try {
        final File file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
  }

  Future<void> _toggleListening() async {
    if (_loading) return;

    if (!_speechAvailable && !_uploadSttAvailable) {
      final bool uploadReady = await _audioRecorder.hasPermission();
      if (!mounted) return;
      if (uploadReady) {
        setState(() => _uploadSttAvailable = true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required for voice input.'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
    }

    if (_isListening) {
      if (_usingUploadStt) {
        await _stopUploadRecordingAndTranscribe();
        return;
      }
      await _speechToText.stop();
      if (!mounted) return;
      setState(() => _isListening = false);
      return;
    }

    if (_uploadSttAvailable) {
      await _startUploadRecording();
      return;
    }

    final bool started = await _speechToText.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _inputController.text = result.recognizedWords;
          _inputController.selection = TextSelection.fromPosition(
            TextPosition(offset: _inputController.text.length),
          );
        });

        if (result.finalResult) {
          TelemetryService.instance.logEvent(
            event: 'voice.transcribe',
            metadata: <String, dynamic>{
              'source': 'speech_to_text',
              'surface': 'ai_coach_widget',
              'chars': result.recognizedWords.length,
              'mode': _selectedMode.name,
            },
          );
        }
      },
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.confirmation,
        cancelOnError: true,
        partialResults: true,
      ),
    );

    if (!mounted) return;
    setState(() => _isListening = started);
  }

  Future<void> _speakText(String text, {String? traceId}) async {
    if (!_voiceOutputEnabled) return;

    if (_isSpeaking) {
      await _audioPlayer.stop();
      await _flutterTts.stop();
      if (mounted) setState(() => _isSpeaking = false);
    }

    if (_lastResponse?.voiceAvailable == true &&
        _lastResponse?.voiceAudioUrl != null &&
        _lastResponse!.voiceAudioUrl!.isNotEmpty) {
      try {
        await _flutterTts.stop();
        await _audioPlayer.stop();
        if (mounted) setState(() => _isSpeaking = true);
        await _audioPlayer.play(UrlSource(_lastResponse!.voiceAudioUrl!));
        await TelemetryService.instance.logEvent(
          event: 'voice.tts',
          metadata: <String, dynamic>{
            'source': 'voice_api_audio',
            'surface': 'ai_coach_widget',
            'traceId': traceId,
            'audioUrlAvailable': true,
          },
        );
        return;
      } catch (_) {
        // Fall through to local TTS fallback.
      }
    }

    await _flutterTts.stop();
    if (mounted) setState(() => _isSpeaking = true);
    await _flutterTts.speak(text);
    await TelemetryService.instance.logEvent(
      event: 'voice.tts',
      metadata: <String, dynamic>{
        'source': 'flutter_tts',
        'surface': 'ai_coach_widget',
        'chars': text.length,
        'traceId': traceId,
      },
    );
  }

  String _coachDirectiveForMode(AiCoachMode mode) {
    switch (mode) {
      case AiCoachMode.hint:
        return 'Give one focused hint first, then ask a short guiding question.';
      case AiCoachMode.verify:
        return 'Verify reasoning with evidence checks and ask for one concrete proof step.';
      case AiCoachMode.explain:
        return 'Explain in simple steps and relate to one practical example.';
      case AiCoachMode.debug:
        return 'Diagnose likely causes, suggest one small test, and ask what changed recently.';
    }
  }

  List<String> _recentConversationTurns({int limit = 6}) {
    if (_messages.isEmpty) return const <String>[];
    final Iterable<_ChatMessage> window = _messages.reversed.take(limit).toList().reversed;
    return window
        .map((m) => '${m.isUser ? 'Learner' : 'Coach'}: ${m.text.replaceAll('\n', ' ').trim()}')
        .toList();
  }

  String _roleInstruction(UserRole role) {
    switch (role) {
      case UserRole.learner:
        return 'Speak directly to a learner using supportive, age-appropriate coaching language.';
      case UserRole.parent:
        return 'Coach with parent-friendly phrasing that supports the learner without giving answers.';
      case UserRole.educator:
      case UserRole.site:
      case UserRole.partner:
      case UserRole.hq:
        return 'Respond as an instructional co-pilot with concise pedagogical suggestions.';
    }
  }

  String _stateSnapshot() {
    final XHat? state = widget.runtime.state?.xHat;
    if (state == null) return 'unknown';
    return 'cognition=${state.cognition.toStringAsFixed(2)}, engagement=${state.engagement.toStringAsFixed(2)}, integrity=${state.integrity.toStringAsFixed(2)}';
  }

  String _buildConversationalPrompt(String userInput) {
    final List<String> turns = _recentConversationTurns();
    final String conversation = turns.isEmpty
        ? 'No prior turns.'
        : turns.join('\n');
    final String mission = (widget.missionId ?? '').trim();
    final String checkpoint = (widget.checkpointId ?? '').trim();
    final String occurrence = (widget.runtime.sessionOccurrenceId ?? '').trim();
    final String tags = widget.conceptTags.join(', ');
    final String goals = _learningGoals.isEmpty
      ? 'none yet'
      : _learningGoals.map((g) => '- $g').join('\n');

    return '''
You are Scholesa AI Coach in a live conversation.
${_roleInstruction(widget.actorRole)}
Mode: ${_selectedMode.name}. ${_coachDirectiveForMode(_selectedMode)}
Safety: Do not provide final graded answers; scaffold thinking.

Context:
- siteId: ${widget.runtime.siteId}
- learnerId: ${widget.runtime.learnerId}
- sessionOccurrenceId: ${occurrence.isEmpty ? 'unknown' : occurrence}
- missionId: ${mission.isEmpty ? 'unknown' : mission}
- checkpointId: ${checkpoint.isEmpty ? 'unknown' : checkpoint}
- conceptTags: ${tags.isEmpty ? 'none' : tags}
- stateEstimate: ${_stateSnapshot()}

Session learning goals:
$goals

Recent conversation:
$conversation

Learner message:
$userInput

Response style:
- Be conversational and concise.
- Reflect the learner's message in one sentence.
- Give 1-3 concrete next steps.
- End with one coaching follow-up question.
''';
  }

  String? _extractLearningGoalCandidate(String input) {
    final String text = input.trim();
    if (text.isEmpty) return null;

    const List<String> cues = <String>[
      'i want to',
      'i need to',
      'help me',
      'i am trying to',
      'i\'m trying to',
      'learn',
      'understand',
      'debug',
      'fix',
      'improve',
      'build',
      'explain',
    ];

    final String lower = text.toLowerCase();
    final bool hasCue = cues.any(lower.contains);
    if (!hasCue && text.length < 24) return null;

    final String normalized = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[.!?]+$'), '')
        .trim();
    if (normalized.length < 8) return null;

    return normalized.length > 120
        ? '${normalized.substring(0, 117)}...'
        : normalized;
  }

  void _updateLearningGoals(String userInput) {
    final String? candidate = _extractLearningGoalCandidate(userInput);
    if (candidate == null) return;

    final String candidateKey = candidate.toLowerCase();
    final bool exists = _learningGoals
        .map((g) => g.toLowerCase())
        .contains(candidateKey);
    if (exists) return;

    _learningGoals.insert(0, candidate);
    if (_learningGoals.length > 3) {
      _learningGoals.removeRange(3, _learningGoals.length);
    }
  }

  bool get _canClearGoals {
    return widget.actorRole == UserRole.educator || widget.actorRole == UserRole.hq;
  }

  Future<void> _clearLearningGoals() async {
    if (_learningGoals.isEmpty) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Clear current goals?'),
          content: const Text(
            'This removes the in-session coaching goals memory for this assistant conversation.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      await TelemetryService.instance.logEvent(
        event: 'cta.clicked',
        metadata: <String, dynamic>{
          'module': 'ai_coach_widget',
          'cta_id': 'clear_learning_goals_cancel',
          'surface': 'current_goals_dialog',
          'role': widget.actorRole.name,
        },
      );
      return;
    }

    setState(() => _learningGoals.clear());
    await TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'ai_coach_widget',
        'cta_id': 'clear_learning_goals_confirm',
        'surface': 'current_goals_dialog',
        'role': widget.actorRole.name,
      },
    );
  }

  String _enrichCoachReply(String text) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) return 'Let\'s try that again. What part feels most confusing right now?';
    if (trimmed.contains('?')) return trimmed;
    switch (_selectedMode) {
      case AiCoachMode.hint:
        return '$trimmed\n\nWhat have you tried so far?';
      case AiCoachMode.verify:
        return '$trimmed\n\nCan you show the evidence for your answer?';
      case AiCoachMode.explain:
        return '$trimmed\n\nHow would you explain that in your own words?';
      case AiCoachMode.debug:
        return '$trimmed\n\nWhat changed right before the issue started?';
    }
  }

  Future<void> _interruptSpeaking() async {
    try {
      await HapticFeedback.selectionClick();
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {
      // Best-effort cue only.
    }

    await _audioPlayer.stop();
    await _flutterTts.stop();
    if (!mounted) return;
    setState(() => _isSpeaking = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Playback stopped'),
        duration: Duration(milliseconds: 1200),
      ),
    );
    await TelemetryService.instance.logEvent(
      event: 'voice.tts',
      metadata: <String, dynamic>{
        'source': 'user_interrupt',
        'surface': 'ai_coach_widget',
        'mode': _selectedMode.name,
      },
    );
  }

  Future<void> _sendMessage() async {
    final String input = _inputController.text.trim();
    if (_loading || input.isEmpty) return;
    _updateLearningGoals(input);
    final String conversationalPrompt = _buildConversationalPrompt(input);

    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'ai_coach_widget',
        'cta_id': 'send_message',
        'surface': 'input_bar',
        'mode': _selectedMode.name,
        'has_input': input.isNotEmpty,
      },
    );

    setState(() {
      _messages.add(_ChatMessage(text: input, isUser: true));
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

      late final AiCoachResponse response;

      try {
        response = await VoiceRuntimeService.instance.requestCopilot(
          VoiceCopilotRequest(
            message: conversationalPrompt,
            locale: Localizations.localeOf(context).toLanguageTag(),
            gradeBand: widget.runtime.gradeBand,
            context: <String, dynamic>{
              'userInput': input,
              'conversationTurns': _recentConversationTurns(),
              'learningGoals': _learningGoals,
              'learnerId': widget.runtime.learnerId,
              'siteId': widget.runtime.siteId,
              'missionId': widget.missionId,
              'checkpointId': widget.checkpointId,
              'sessionOccurrenceId': widget.runtime.sessionOccurrenceId,
              'mode': _selectedMode.name,
              'role': widget.actorRole.name,
            },
            voiceEnabled: true,
            voiceOutput: _voiceOutputEnabled,
          ),
        );
        await TelemetryService.instance.logEvent(
          event: 'voice.message',
          metadata: <String, dynamic>{
            'surface': 'ai_coach_widget',
            'mode': _selectedMode.name,
            'traceId': response.traceId,
            'safetyOutcome': response.safetyOutcome,
            'policyVersion': response.policyVersion,
          },
        );
      } catch (_) {
        if (!widget.allowBosFallback) {
          rethrow;
        }
        response = await BosService.instance.callAiCoach(request);
        await TelemetryService.instance.logEvent(
          event: 'voice.message',
          metadata: <String, dynamic>{
            'surface': 'ai_coach_widget',
            'mode': _selectedMode.name,
            'source': 'bos_fallback',
            'role': widget.actorRole.name,
          },
        );
      }

      setState(() {
        _lastResponse = response;
        final String conversationalReply = _enrichCoachReply(response.message);
        _messages.add(_ChatMessage(
          text: conversationalReply,
          isUser: false,
          response: response,
        ));
        _loading = false;
      });

      await _speakText(
        _messages.last.text,
        traceId: response.traceId,
      );

      // Emit ai_help_used (client-side tracking)
      widget.runtime.trackEvent(
        'ai_help_used',
        missionId: widget.missionId,
        checkpointId: widget.checkpointId,
        payload: <String, dynamic>{
          'mode': _selectedMode.name,
          'mvlGateActive': response.mvlGateActive,
          'requiresExplainBack': response.requiresExplainBack,
          'traceId': response.traceId,
          'source': response.policyVersion == null ? 'bos_callable' : 'voice_api',
        },
      );

      widget.runtime.trackEvent(
        'ai_coach_response',
        missionId: widget.missionId,
        checkpointId: widget.checkpointId,
        payload: <String, dynamic>{
          'mode': _selectedMode.name,
          'traceId': response.traceId,
          'policyVersion': response.policyVersion,
          'safetyOutcome': response.safetyOutcome,
          'mvlGateActive': response.mvlGateActive,
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
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'ai_coach_widget',
        'cta_id': helpful ? 'feedback_helpful' : 'feedback_not_helpful',
        'surface': 'chat_bubble',
        'mode': _selectedMode.name,
      },
    );
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
        content: Text(
            helpful ? 'Thanks for the feedback!' : 'Noted — we\'ll improve.'),
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
          onChanged: (AiCoachMode mode) {
            TelemetryService.instance.logEvent(
              event: 'cta.clicked',
              metadata: <String, dynamic>{
                'module': 'ai_coach_widget',
                'cta_id': 'set_coach_mode',
                'surface': 'mode_selector',
                'mode': mode.name,
              },
            );
            setState(() => _selectedMode = mode);
          },
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
                Icon(Icons.verified_user,
                    color: Colors.amber.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Verification active — show your understanding first.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.amber.shade900),
                  ),
                ),
              ],
            ),
          ),

        if (_learningGoals.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      'Current goals',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (_canClearGoals)
                      TextButton(
                        onPressed: _clearLearningGoals,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                        child: Text(
                          'Clear goals',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _learningGoals
                      .map(
                        (goal) => Chip(
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            goal,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                      )
                      .toList(),
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
                        Icon(Icons.smart_toy_outlined,
                            size: 48,
                            color: theme.colorScheme.primary.withAlpha(128)),
                        const SizedBox(height: 12),
                        Text(
                          'AI Coach',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(color: theme.colorScheme.primary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select a mode and ask for help.\nI\'ll guide your thinking — not give answers.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: _messages.length,
                  itemBuilder: (BuildContext context, int index) {
                    return _ChatBubble(
                      message: _messages[index],
                      onFeedback: index == _messages.length - 1 &&
                              !_messages[index].isUser
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
                if (_speechAvailable || _uploadSttAvailable)
                  IconButton(
                    onPressed: (_loading || _isSpeaking) ? null : _toggleListening,
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                    ),
                    tooltip: _isListening ? 'Stop listening' : 'Use voice input',
                  ),
                IconButton(
                  onPressed: (_loading || _isSpeaking)
                      ? null
                      : () {
                          setState(() => _voiceOutputEnabled = !_voiceOutputEnabled);
                        },
                  icon: Icon(
                    _voiceOutputEnabled
                        ? Icons.volume_up_outlined
                        : Icons.volume_off_outlined,
                  ),
                  tooltip: _voiceOutputEnabled
                      ? 'Disable voice output'
                      : 'Enable voice output',
                ),
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    enabled: !_isSpeaking,
                    decoration: InputDecoration(
                      hintText: _isSpeaking ? 'Speaking…' : _modeHint(_selectedMode),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    maxLines: 3,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                if (_isSpeaking)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Speaking…',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _interruptSpeaking,
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Tap to interrupt',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                IconButton.filled(
                  onPressed: (_loading || _isSpeaking) ? null : _sendMessage,
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
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
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
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
                color: isUser
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
            ),

            // MVL gate indicator
            if (message.response?.mvlGateActive == true)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.verified_user,
                        size: 14, color: Colors.amber.shade700),
                    const SizedBox(width: 4),
                    Text(
                      'Verification required',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: Colors.amber.shade700),
                    ),
                  ],
                ),
              ),

            // Suggested next steps
            if (message.response != null &&
                message.response!.suggestedNextSteps.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      message.response!.suggestedNextSteps.map((String step) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('→ ',
                              style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontSize: 12)),
                          Expanded(
                            child: Text(
                              step,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant),
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
