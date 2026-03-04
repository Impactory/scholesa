import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'bos_models.dart';
import 'bos_service.dart';
import 'learning_runtime_provider.dart';
import 'voice_runtime_service.dart';
import '../services/telemetry_service.dart';
import '../auth/app_state.dart';
import '../ui/localization/app_strings.dart';

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

  String _t(String key) => AppStrings.of(context, key);

  @override
  void initState() {
    super.initState();
    unawaited(_restoreLearningGoals());
    unawaited(_initializeVoiceStack());
  }

  String get _learningGoalsKey {
    return 'bos_mia.learning_goals.${widget.runtime.siteId}.${widget.runtime.learnerId}';
  }

  Future<void> _restoreLearningGoals() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> storedGoals =
          prefs.getStringList(_learningGoalsKey) ?? <String>[];
      if (!mounted || storedGoals.isEmpty) {
        return;
      }

      setState(() {
        _learningGoals
          ..clear()
          ..addAll(storedGoals.take(3));
      });
    } catch (_) {
      // Keep AI available even if local persistence fails.
    }
  }

  Future<void> _persistLearningGoals() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          _learningGoalsKey, _learningGoals.take(3).toList());
    } catch (_) {
      // Keep AI available even if local persistence fails.
    }
  }

  List<String> _bosMiaLoopTags() {
    final Set<String> tags = <String>{
      ...widget.conceptTags.where((String tag) => tag.trim().isNotEmpty),
      'bos_mia_loop',
      'continuous_improvement',
      'learner_${widget.runtime.learnerId}',
      'site_${widget.runtime.siteId}',
      'role_${widget.actorRole.name}',
      'mode_${_selectedMode.name}',
      if (widget.missionId != null && widget.missionId!.trim().isNotEmpty)
        'mission_${widget.missionId!}',
      if (widget.checkpointId != null &&
          widget.checkpointId!.trim().isNotEmpty)
        'checkpoint_${widget.checkpointId!}',
      ..._learningGoals.map(
        (String goal) =>
            'goal_${goal.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '')}',
      ),
    };
    return tags.where((String tag) => tag.isNotEmpty).toList();
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

      final bool isApplePlatform = !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS);

      if (isApplePlatform) {
        await _flutterTts.setSharedInstance(true);
        await _flutterTts.autoStopSharedSession(false);
      }

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
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

      final bool uploadReady = kIsWeb ? false : await _audioRecorder.hasPermission();
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

    if (mounted) {
      setState(() => _loading = true);
    }

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
        SnackBar(
          content: Text(_t('ai.voice.transcriptionUnavailable')),
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
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
      bool speechReady = false;
      try {
        speechReady = await _speechToText.initialize(
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
      } catch (_) {
        speechReady = false;
      }

      final bool uploadReady = kIsWeb ? false : await _audioRecorder.hasPermission();
      if (!mounted) return;
      setState(() {
        _speechAvailable = speechReady;
        _uploadSttAvailable = uploadReady;
      });

      if (!speechReady && !uploadReady) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('ai.voice.microphonePermissionRequired')),
            duration: const Duration(seconds: 2),
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

    if (_speechAvailable) {
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
      return;
    }

    if (_uploadSttAvailable && !kIsWeb) {
      await _startUploadRecording();
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_t('ai.voice.microphonePermissionRequired')),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _speakText(String text, {String? traceId}) async {
    if (!_voiceOutputEnabled) return;

    if (_isSpeaking) {
      await _audioPlayer.stop();
      await _flutterTts.stop();
      if (mounted) setState(() => _isSpeaking = false);
    }

    bool played = false;
    if (_lastResponse?.voiceAvailable == true &&
        _lastResponse?.voiceAudioUrl != null &&
        _lastResponse!.voiceAudioUrl!.isNotEmpty) {
      try {
        await _flutterTts.stop();
        await _audioPlayer.stop();
        if (mounted) setState(() => _isSpeaking = true);
        await _audioPlayer.play(UrlSource(_lastResponse!.voiceAudioUrl!));
        played = true;
        await TelemetryService.instance.logEvent(
          event: 'voice.tts',
          metadata: <String, dynamic>{
            'source': 'voice_api_audio',
            'surface': 'ai_coach_widget',
            'traceId': traceId,
            'audioUrlAvailable': true,
          },
        );
      } catch (_) {
        if (mounted) setState(() => _isSpeaking = false);
      }
    }

    if (!played) {
      try {
        await _audioPlayer.stop();
        await _flutterTts.stop();
        if (mounted) setState(() => _isSpeaking = true);
        await _flutterTts.speak(text);
        played = true;
        await TelemetryService.instance.logEvent(
          event: 'voice.tts',
          metadata: <String, dynamic>{
            'source': kIsWeb ? 'flutter_tts_web' : 'flutter_tts',
            'surface': 'ai_coach_widget',
            'chars': text.length,
            'traceId': traceId,
          },
        );
      } catch (_) {
        if (mounted) setState(() => _isSpeaking = false);
      }
    }

    if (!played) {
      await TelemetryService.instance.logEvent(
        event: 'voice.tts',
        metadata: <String, dynamic>{
          'source': 'voice_unavailable',
          'surface': 'ai_coach_widget',
          'traceId': traceId,
          'chars': text.length,
          'web': kIsWeb,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb
                ? _t('ai.voice.outputUnavailableWeb')
                : _t('ai.voice.outputUnavailable'),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _coachDirectiveForMode(AiCoachMode mode) {
    switch (mode) {
      case AiCoachMode.hint:
        return _t('ai.directive.hint');
      case AiCoachMode.verify:
        return _t('ai.directive.verify');
      case AiCoachMode.explain:
        return _t('ai.directive.explain');
      case AiCoachMode.debug:
        return _t('ai.directive.debug');
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
        return _t('ai.role.learner');
      case UserRole.parent:
        return _t('ai.role.parent');
      case UserRole.educator:
      case UserRole.site:
      case UserRole.partner:
      case UserRole.hq:
        return _t('ai.role.staff');
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
    final String tags = _bosMiaLoopTags().join(', ');
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
- bosMiaLoop: Always stay in BOS/MIA closed-loop coaching and improve this specific learner over time.

Session learning goals:
$goals

Recent conversation:
$conversation

Learner message:
$userInput

Response style:
- Be conversational, warm, and age-appropriate for a learner.
- Use simple words and short sentences that sound natural when spoken aloud.
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
    unawaited(_persistLearningGoals());
    widget.runtime.trackEvent(
      'ai_learning_goal_updated',
      missionId: widget.missionId,
      checkpointId: widget.checkpointId,
      payload: <String, dynamic>{
        'goals_count': _learningGoals.length,
        'latest_goal': candidate,
      },
    );
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
          title: Text(_t('ai.clearGoals.title')),
          content: Text(_t('ai.clearGoals.body')),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(AppStrings.of(dialogContext, 'auth.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(_t('ai.clear')),
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
    await _persistLearningGoals();
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
    if (trimmed.isEmpty) return _t('ai.enrich.retryPrompt');
    if (trimmed.contains('?')) return trimmed;
    switch (_selectedMode) {
      case AiCoachMode.hint:
        return '$trimmed\n\n${_t('ai.enrich.hintFollowup')}';
      case AiCoachMode.verify:
        return '$trimmed\n\n${_t('ai.enrich.verifyFollowup')}';
      case AiCoachMode.explain:
        return '$trimmed\n\n${_t('ai.enrich.explainFollowup')}';
      case AiCoachMode.debug:
        return '$trimmed\n\n${_t('ai.enrich.debugFollowup')}';
    }
  }

  String _buildOfflineFallbackReply(String learnerInput) {
    final String normalized = learnerInput.trim();
    final String safeInput = normalized.isEmpty ? _t('ai.enrich.retryPrompt') : normalized;

    switch (_selectedMode) {
      case AiCoachMode.hint:
        return 'Let\'s keep moving. From your message, "$safeInput", what is one small next step you can try now?';
      case AiCoachMode.verify:
        return 'Good check-in. Based on "$safeInput", can you explain your reasoning in 2 short steps and what evidence supports it?';
      case AiCoachMode.explain:
        return 'Let\'s simplify this. In your own words, what is the main idea behind "$safeInput" and where did you get stuck?';
      case AiCoachMode.debug:
        return 'Let\'s debug together. For "$safeInput", what did you expect to happen, what actually happened, and what changed right before it?';
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
      SnackBar(
        content: Text(_t('ai.voice.playbackStopped')),
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
    // Immediately stop any ongoing speech, whether from user or AI
    if (_isListening) {
      if (_usingUploadStt) {
        await _stopUploadRecordingAndTranscribe();
      } else {
        await _speechToText.stop();
      }
      if (mounted) setState(() => _isListening = false);
    }
    if (_isSpeaking) {
      await _interruptSpeaking();
    }

    final String input = _inputController.text.trim();
    if (_loading || input.isEmpty) return;
    _updateLearningGoals(input);

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
      final AiCoachResponse response = await _fetchAndProcessResponse(input);
      if (!mounted) return;

      _lastResponse = response;
      final String conversationalReply = _enrichCoachReply(response.message);
      final _ChatMessage aiMessage = _ChatMessage(
        text: conversationalReply,
        isUser: false,
        response: response,
      );

      setState(() {
        _messages.add(aiMessage);
        _loading = false;
      });

      await _speakText(
        aiMessage.text,
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
    } catch (e) {
      final String fallbackReply = _buildOfflineFallbackReply(input);
      await TelemetryService.instance.logEvent(
        event: 'voice.message',
        metadata: <String, dynamic>{
          'surface': 'ai_coach_widget',
          'mode': _selectedMode.name,
          'source': 'local_fallback',
          'error': e.toString(),
          'role': widget.actorRole.name,
        },
      );

      if (kDebugMode) {
        debugPrint('AI request failed, using local fallback: $e');
      }

      setState(() {
        _messages.add(_ChatMessage(
          text: fallbackReply,
          isUser: false,
          isError: false,
        ));
        _loading = false;
      });
    }
  }

  Future<AiCoachResponse> _fetchAndProcessResponse(String prompt) async {
    final AiCoachRequest request = AiCoachRequest(
      siteId: widget.runtime.siteId,
      learnerId: widget.runtime.learnerId,
      gradeBand: widget.runtime.gradeBand,
      mode: _selectedMode,
      sessionOccurrenceId: widget.runtime.sessionOccurrenceId,
      missionId: widget.missionId,
      checkpointId: widget.checkpointId,
      conceptTags: _bosMiaLoopTags(),
      learnerState: widget.runtime.state?.xHat,
      studentInput: prompt.isNotEmpty ? prompt : null,
      personaInstructions:
          'Your response should be friendly, conversational, and encouraging, suitable for being spoken aloud as a helpful guide. Do not provide direct answers, but help the user discover the answer themselves.',
    );

    late final AiCoachResponse response;

    try {
      response = await VoiceRuntimeService.instance.requestCopilot(
        VoiceCopilotRequest(
          message: _buildConversationalPrompt(prompt),
          locale: Localizations.localeOf(context).toLanguageTag(),
          gradeBand: widget.runtime.gradeBand,
          context: <String, dynamic>{
            'userInput': prompt,
            'conversationTurns': _recentConversationTurns(),
            'learningGoals': _learningGoals,
            'learnerId': widget.runtime.learnerId,
            'siteId': widget.runtime.siteId,
            'missionId': widget.missionId,
            'checkpointId': widget.checkpointId,
            'sessionOccurrenceId': widget.runtime.sessionOccurrenceId,
            'mode': _selectedMode.name,
            'role': widget.actorRole.name,
            'bosMiaLoop': true,
            'loopTags': _bosMiaLoopTags(),
            'personaInstructions':
                'Kid-friendly, conversational coaching voice. Keep it warm, simple, and spoken. Never give final answers; guide step-by-step.',
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

    // MVL Gating Logic (client-side override)
    if (widget.allowBosFallback &&
        widget.runtime.hasMvlGate &&
        response.mvlGateActive) {
      widget.runtime.trackEvent(
        'mvl.gate.triggered',
        missionId: widget.missionId,
        checkpointId: widget.checkpointId,
        payload: <String, dynamic>{
          'mode': _selectedMode.name,
          'gated_response': response.message
        },
      );
      return response.copyWith(
        message: _t('ai.mvl.gatedResponse'),
      );
    }

    return response;
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
            helpful ? _t('ai.feedback.thanks') : _t('ai.feedback.noted')),
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
              color: theme.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.tertiary),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.verified_user,
                    color: theme.colorScheme.onTertiaryContainer, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _t('ai.banner.verification'),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onTertiaryContainer),
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
                      _t('ai.currentGoals'),
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
                          _t('ai.clearGoals.cta'),
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
                          _t('ai.empty.title'),
                          style: theme.textTheme.titleMedium
                              ?.copyWith(color: theme.colorScheme.primary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _t('ai.empty.subtitle'),
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
                    tooltip: _isListening
                        ? _t('ai.voice.stopListening')
                        : _t('ai.voice.useInput'),
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
                      ? _t('ai.voice.disableOutput')
                      : _t('ai.voice.enableOutput'),
                ),
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    enabled: !_isSpeaking,
                    decoration: InputDecoration(
                      hintText: _isSpeaking ? _t('ai.voice.speaking') : _modeHint(_selectedMode),
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
                          _t('ai.voice.speaking'),
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
                            _t('ai.voice.tapInterrupt'),
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
        return _t('ai.mode.hintPlaceholder');
      case AiCoachMode.verify:
        return _t('ai.mode.verifyPlaceholder');
      case AiCoachMode.explain:
        return _t('ai.mode.explainPlaceholder');
      case AiCoachMode.debug:
        return _t('ai.mode.debugPlaceholder');
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
              label: Text(_modeLabel(context, mode)),
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

  String _modeLabel(BuildContext context, AiCoachMode mode) {
    switch (mode) {
      case AiCoachMode.hint:
        return AppStrings.of(context, 'ai.mode.hintLabel');
      case AiCoachMode.verify:
        return AppStrings.of(context, 'ai.mode.verifyLabel');
      case AiCoachMode.explain:
        return AppStrings.of(context, 'ai.mode.explainLabel');
      case AiCoachMode.debug:
        return AppStrings.of(context, 'ai.mode.debugLabel');
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
                  ? theme.colorScheme.errorContainer
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
                        size: 14, color: theme.colorScheme.tertiary),
                    const SizedBox(width: 4),
                    Text(
                      AppStrings.of(context, 'ai.chat.verificationRequired'),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.tertiary),
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
                    Text(
                      AppStrings.of(context, 'ai.chat.helpful'),
                      style: theme.textTheme.labelSmall,
                    ),
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
