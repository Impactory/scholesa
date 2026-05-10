import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'bos_models.dart';
import 'bos_service.dart';
import 'learning_runtime_provider.dart';
import 'voice_runtime_service.dart';
import 'web_speech.dart';
import '../services/telemetry_service.dart';
import '../auth/app_state.dart';
import '../ui/localization/app_strings.dart';

// ──────────────────────────────────────────────────────
// AI Help Widget — Control Surface
// Spec: BOS_MIA_HOW_TO_IMPLEMENT.md §5, A0–A2
//
// AI is a control surface in the closed-loop runtime:
//   Sense → Detect → Estimate → Control → Gate → Govern
//
// Modes: hint (low assist), verify (evidence check),
//        explain (scaffolding), debug (guided debugging).
// Forbidden: final answers, doing student's work, punitive language.
// ──────────────────────────────────────────────────────

/// AI Help chat panel for learner missions.
///
/// Emits events: ai_help_opened, ai_help_used, ai_coach_feedback.
/// Respects MVL gating — intercepted responses trigger verification.
class AiCoachWidget extends StatefulWidget {
  const AiCoachWidget({
    required this.runtime,
    required this.actorRole,
    this.autoSpeakGreeting = false,
    this.autoAssistOnHesitation = false,
    this.hesitationInactivityThreshold = const Duration(seconds: 35),
    this.autoAssistCooldown = const Duration(seconds: 120),
    this.proactiveScanInterval = const Duration(seconds: 8),
    this.skipVoiceInitializationForTesting = false,
    this.onSpeakOverride,
    this.onInterventionRequest,
    this.onAutoResponseRequest,
    this.onResponseRequest,
    this.voiceOnlyConversation = false,
    this.missionId,
    this.checkpointId,
    this.conceptTags = const <String>[],
    super.key,
  });

  final LearningRuntimeProvider runtime;
  final UserRole actorRole;
  final bool autoSpeakGreeting;
  final bool autoAssistOnHesitation;
  final Duration hesitationInactivityThreshold;
  final Duration autoAssistCooldown;
  final Duration proactiveScanInterval;
  final bool skipVoiceInitializationForTesting;
  final Future<void> Function(String text)? onSpeakOverride;
  final Future<BosIntervention?> Function()? onInterventionRequest;
  final Future<AiCoachResponse> Function(String prompt, AiCoachMode mode)?
      onAutoResponseRequest;
  final Future<AiCoachResponse> Function(String prompt, AiCoachMode mode)?
      onResponseRequest;
  final bool voiceOnlyConversation;
  final String? missionId;
  final String? checkpointId;
  final List<String> conceptTags;

  @override
  State<AiCoachWidget> createState() => _AiCoachWidgetState();
}

class _AiCoachWidgetState extends State<AiCoachWidget> {
  final TextEditingController _inputController = TextEditingController();
  final List<_ChatMessage> _messages = <_ChatMessage>[];
  final ScrollController _scrollController = ScrollController();
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  AudioPlayer? _audioPlayer;
  AudioRecorder? _audioRecorder;
  StreamSubscription<void>? _playerCompleteSub;
  StreamSubscription<PlayerState>? _playerStateSub;
  Timer? _proactiveAssistTimer;
  AiCoachMode _selectedMode = AiCoachMode.hint;
  bool _loading = false;
  bool _isListening = false;
  bool _speechAvailable = false;
  bool _uploadSttAvailable = false;
  bool _webSpeechAvailable = false;
  WebSpeechRecognition? _webSpeechRecognition;
  bool _webAudioContextUnlocked = false;
  bool _usingUploadStt = false;
  bool _voiceOutputEnabled = true;
  bool _isSpeaking = false;
  final List<String> _learningGoals = <String>[];
  AiCoachResponse? _lastResponse;
  bool _hasSpokenGreeting = false;
  bool _autoAssistInFlight = false;
  bool _listenAfterSpeech = false;
  bool _awaitingExplainBack = false;
  String? _explainBackInteractionId;
  DateTime _lastLearnerActivityAt = DateTime.now();
  DateTime? _lastAutoAssistAt;
  Timer? _interactionSignalTimer;
  DateTime? _typingBurstStartedAt;
  DateTime? _lastTypingSignalAt;
  String _lastInputSnapshot = '';
  int _typingChangeCount = 0;
  int _typingCharsAdded = 0;
  int _typingCharsRemoved = 0;
  bool _suppressInteractionTracking = false;

  String _t(String key) => AppStrings.of(context, key);

  @override
  void initState() {
    super.initState();
    _attachRuntimeListener();
    _startProactiveAssistLoop();
    unawaited(_restoreLearningGoals());
    unawaited(_initializeVoiceStack());
  }

  @override
  void didUpdateWidget(covariant AiCoachWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.runtime, widget.runtime)) {
      oldWidget.runtime.removeListener(_handleRuntimeSignalChange);
      _attachRuntimeListener();
    }
    if (oldWidget.autoAssistOnHesitation != widget.autoAssistOnHesitation ||
        oldWidget.actorRole != widget.actorRole) {
      _proactiveAssistTimer?.cancel();
      _startProactiveAssistLoop();
    }
  }

  String get _learningGoalsKey {
    return 'bos_mia.learning_goals.${widget.runtime.siteId}.${widget.runtime.learnerId}';
  }

  AudioPlayer _ensureAudioPlayer() {
    return _audioPlayer ??= AudioPlayer();
  }

  AudioRecorder _ensureAudioRecorder() {
    return _audioRecorder ??= AudioRecorder();
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
      'ai_help_loop',
      'bos_mia_loop',
      'continuous_improvement',
      'learner_${widget.runtime.learnerId}',
      'site_${widget.runtime.siteId}',
      'role_${widget.actorRole.name}',
      'mode_${_selectedMode.name}',
      if (widget.missionId != null && widget.missionId!.trim().isNotEmpty)
        'mission_${widget.missionId!}',
      if (widget.checkpointId != null && widget.checkpointId!.trim().isNotEmpty)
        'checkpoint_${widget.checkpointId!}',
      ..._learningGoals.map(
        (String goal) =>
            'goal_${goal.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '')}',
      ),
    };
    return tags.where((String tag) => tag.isNotEmpty).toList();
  }

  Future<void> _initializeVoiceStack() async {
    if (widget.skipVoiceInitializationForTesting) {
      if (mounted) {
        setState(() {
          _speechAvailable = false;
          _uploadSttAvailable = false;
          _webSpeechAvailable = false;
        });
      }
      unawaited(_maybeSpeakInitialGreeting());
      return;
    }

    // On web/WASM: prefer the native Web Speech API over Flutter plugins.
    if (kIsWeb) {
      _webSpeechAvailable = WebSpeechRecognition.isSupported;
    }

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
      await _flutterTts.setSpeechRate(kIsWeb ? 0.86 : 0.42);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.04);
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

      final AudioPlayer audioPlayer = _ensureAudioPlayer();
      final AudioRecorder audioRecorder = _ensureAudioRecorder();

      await audioPlayer.setAudioContext(
        AudioContextConfig(
          route: AudioContextConfigRoute.system,
          focus: AudioContextConfigFocus.duckOthers,
          respectSilence: false,
        ).build(),
      );

      _playerCompleteSub?.cancel();
      _playerCompleteSub = audioPlayer.onPlayerComplete.listen((_) {
        if (!mounted) return;
        setState(() => _isSpeaking = false);
        if (_listenAfterSpeech) {
          _listenAfterSpeech = false;
          unawaited(_toggleListening());
        }
      });

      _playerStateSub?.cancel();
      _playerStateSub = audioPlayer.onPlayerStateChanged.listen((state) {
        if (!mounted) return;
        if (state == PlayerState.stopped || state == PlayerState.completed) {
          setState(() => _isSpeaking = false);
          if (_listenAfterSpeech) {
            _listenAfterSpeech = false;
            unawaited(_toggleListening());
          }
        }
      });

      _flutterTts.setStartHandler(() {
        if (!mounted) return;
        setState(() => _isSpeaking = true);
      });
      _flutterTts.setCompletionHandler(() {
        if (!mounted) return;
        setState(() => _isSpeaking = false);
        if (_listenAfterSpeech) {
          _listenAfterSpeech = false;
          unawaited(_toggleListening());
        }
      });
      _flutterTts.setErrorHandler((_) {
        if (!mounted) return;
        setState(() => _isSpeaking = false);
        _listenAfterSpeech = false;
      });

      final bool uploadReady =
          await audioRecorder.hasPermission();
      if (!mounted) return;
      setState(() {
        _speechAvailable = speechReady;
        _uploadSttAvailable = uploadReady;
      });
      unawaited(_maybeSpeakInitialGreeting());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _speechAvailable = false;
        _uploadSttAvailable = false;
      });
    }
  }

  void _attachRuntimeListener() {
    widget.runtime.addListener(_handleRuntimeSignalChange);
  }

  void _handleRuntimeSignalChange() {
    if (!mounted) return;
    unawaited(_evaluateBosAutoAssist(trigger: 'runtime_state_change'));
  }

  bool get _shouldCaptureInteractionSignals {
    return widget.actorRole == UserRole.learner;
  }

  void _markLearnerActivity() {
    _lastLearnerActivityAt = DateTime.now();
  }

  void _handleInputChanged(String value) {
    _markLearnerActivity();
    if (_suppressInteractionTracking || !_shouldCaptureInteractionSignals) {
      _lastInputSnapshot = value;
      return;
    }

    final DateTime now = DateTime.now();
    if (_lastTypingSignalAt != null &&
        now.difference(_lastTypingSignalAt!) > const Duration(seconds: 4)) {
      _flushInteractionSignal(reason: 'inactivity_window');
    }

    _typingBurstStartedAt ??= now;
    final int delta = value.length - _lastInputSnapshot.length;
    if (delta > 0) {
      _typingCharsAdded += delta;
    } else if (delta < 0) {
      _typingCharsRemoved += delta.abs();
    }
    _typingChangeCount += 1;
    _lastTypingSignalAt = now;
    _lastInputSnapshot = value;
    _scheduleInteractionSignalFlush();
  }

  void _scheduleInteractionSignalFlush() {
    _interactionSignalTimer?.cancel();
    _interactionSignalTimer = Timer(
      const Duration(seconds: 4),
      () => _flushInteractionSignal(reason: 'idle_flush'),
    );
  }

  void _flushInteractionSignal({required String reason}) {
    _interactionSignalTimer?.cancel();
    if (!_shouldCaptureInteractionSignals || _typingChangeCount == 0) {
      _resetInteractionSignalState();
      return;
    }

    final DateTime endAt = _lastTypingSignalAt ?? DateTime.now();
    final DateTime startAt = _typingBurstStartedAt ?? endAt;
    final int durationMs = endAt.difference(startAt).inMilliseconds;

    widget.runtime.trackEvent(
      'interaction_signal_observed',
      missionId: widget.missionId,
      checkpointId: widget.checkpointId,
      payload: <String, dynamic>{
        'signalFamily': 'keystroke',
        'source': 'ai_coach_input',
        'reason': reason,
        'interactionCount': _typingChangeCount,
        'charsAdded': _typingCharsAdded,
        'charsRemoved': _typingCharsRemoved,
        'textLengthBucket': _lengthBucket(_lastInputSnapshot.length),
        'burstDurationBucket': _durationBucket(durationMs),
      },
    );

    _resetInteractionSignalState();
  }

  void _resetInteractionSignalState() {
    _typingBurstStartedAt = null;
    _lastTypingSignalAt = null;
    _typingChangeCount = 0;
    _typingCharsAdded = 0;
    _typingCharsRemoved = 0;
  }

  String _lengthBucket(int length) {
    if (length <= 0) return 'empty';
    if (length <= 12) return '1_12';
    if (length <= 40) return '13_40';
    if (length <= 120) return '41_120';
    return '121_plus';
  }

  String _durationBucket(int durationMs) {
    if (durationMs < 1500) return 'under_1_5s';
    if (durationMs < 5000) return '1_5s_to_5s';
    if (durationMs < 12000) return '5s_to_12s';
    return '12s_plus';
  }

  void _replaceInputText(String value) {
    _suppressInteractionTracking = true;
    _inputController.text = value;
    _inputController.selection = TextSelection.fromPosition(
      TextPosition(offset: _inputController.text.length),
    );
    _lastInputSnapshot = value;
    _suppressInteractionTracking = false;
    _markLearnerActivity();
  }

  void _clearInputText() {
    _suppressInteractionTracking = true;
    _inputController.clear();
    _lastInputSnapshot = '';
    _suppressInteractionTracking = false;
  }

  void _startProactiveAssistLoop() {
    if (!widget.autoAssistOnHesitation ||
        widget.actorRole != UserRole.learner) {
      return;
    }
    _proactiveAssistTimer = Timer.periodic(widget.proactiveScanInterval, (_) {
      if (!mounted) return;
      unawaited(_evaluateBosAutoAssist(trigger: 'periodic_idle_scan'));
    });
  }

  bool _isHesitating(XHat state) {
    return state.engagement <= 0.42 || state.cognition <= 0.38;
  }

  String _buildHesitationPrompt(XHat state) {
    final String profile =
        'cognition=${state.cognition.toStringAsFixed(2)}, engagement=${state.engagement.toStringAsFixed(2)}, integrity=${state.integrity.toStringAsFixed(2)}';
    return _t('ai.autoAssist.hesitationPrompt')
        .replaceFirst('{state}', profile);
  }

  String _buildInterventionPrompt(BosIntervention intervention) {
    final String reasons = intervention.reasonCodes.isEmpty
        ? 'none'
        : intervention.reasonCodes.join(', ');
    return _t('ai.autoAssist.interventionPrompt')
        .replaceFirst('{type}', intervention.type.name)
        .replaceFirst('{salience}', intervention.salience.name)
        .replaceFirst('{reasons}', reasons);
  }

  Future<void> _maybeSpeakInitialGreeting() async {
    if (!widget.autoSpeakGreeting || _hasSpokenGreeting || !mounted) {
      return;
    }
    _hasSpokenGreeting = true;

    await Future<void>.delayed(const Duration(milliseconds: 240));
    if (!mounted) return;

    final String greeting = _t('ai.greeting.initial');
    setState(() {
      _messages.add(_ChatMessage(text: greeting, isUser: false));
    });
    _scrollToBottom();
    await _speakText(greeting);

    await TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'ai_coach_widget',
        'cta_id': 'assistant_auto_greeting',
        'surface': 'floating_assistant',
        'role': widget.actorRole.name,
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _evaluateBosAutoAssist({required String trigger}) async {
    if (!widget.autoAssistOnHesitation ||
        widget.actorRole != UserRole.learner ||
        _autoAssistInFlight ||
        _loading ||
        _isListening ||
        _isSpeaking) {
      return;
    }

    final XHat? state = widget.runtime.state?.xHat;

    final DateTime now = DateTime.now();
    if (now.difference(_lastLearnerActivityAt) <
        widget.hesitationInactivityThreshold) {
      return;
    }
    if (_lastAutoAssistAt != null &&
        now.difference(_lastAutoAssistAt!) < widget.autoAssistCooldown) {
      return;
    }

    _autoAssistInFlight = true;
    try {
      BosIntervention? intervention;
      if ((widget.runtime.sessionOccurrenceId ?? '').trim().isNotEmpty) {
        intervention = widget.onInterventionRequest != null
            ? await widget.onInterventionRequest!()
            : await BosService.instance.getIntervention(
                siteId: widget.runtime.siteId,
                learnerId: widget.runtime.learnerId,
                sessionOccurrenceId: widget.runtime.sessionOccurrenceId!,
                gradeBand: widget.runtime.gradeBand,
              );
        if (intervention?.mode != null && mounted) {
          setState(() => _selectedMode = intervention!.mode!);
        }
      }

      final bool triggeredByState = state != null && _isHesitating(state);
      final bool triggeredByIntervention =
          intervention != null && intervention.salience != Salience.low;
      if (!triggeredByState && !triggeredByIntervention) {
        return;
      }

      final String autoPrompt;
      if (triggeredByState) {
        autoPrompt = _buildHesitationPrompt(state);
      } else if (intervention != null) {
        autoPrompt = _buildInterventionPrompt(intervention);
      } else {
        autoPrompt = _t('ai.autoAssist.fallbackPrompt');
      }

      widget.runtime.trackEvent(
        'idle_detected',
        missionId: widget.missionId,
        checkpointId: widget.checkpointId,
        payload: <String, dynamic>{
          'trigger': trigger,
          if (state != null) 'engagement': state.engagement,
          if (state != null) 'cognition': state.cognition,
          if (intervention != null) 'interventionType': intervention.type.name,
          if (intervention != null)
            'interventionSalience': intervention.salience.name,
          'reasonCodes': intervention?.reasonCodes ?? const <String>[],
          'autoAssist': true,
        },
      );

      widget.runtime.trackEvent(
        'ai_help_opened',
        missionId: widget.missionId,
        checkpointId: widget.checkpointId,
        payload: <String, dynamic>{
          'mode': _selectedMode.name,
          'source': 'bos_auto_hesitation',
          'trigger': trigger,
        },
      );

      final AiCoachResponse response = widget.onAutoResponseRequest != null
          ? await widget.onAutoResponseRequest!(autoPrompt, _selectedMode)
          : await _fetchAndProcessResponse(autoPrompt);
      if (!mounted) return;

      _lastResponse = response;
      final _ChatMessage aiMessage = _ChatMessage(
        text: _enrichCoachReply(response.message),
        isUser: false,
        response: response,
      );

      setState(() => _messages.add(aiMessage));
      _scrollToBottom();
      await _speakText(
        aiMessage.text,
        traceId: response.traceId,
        responseOverride: response,
      );

      widget.runtime.trackEvent(
        'ai_help_used',
        missionId: widget.missionId,
        checkpointId: widget.checkpointId,
        payload: <String, dynamic>{
          'mode': _selectedMode.name,
          'source': 'bos_auto_hesitation',
          'trigger': trigger,
          'traceId': response.traceId,
        },
      );

      _lastAutoAssistAt = DateTime.now();
    } catch (_) {
      // Keep learner flow resilient if BOS auto-assist fails.
    } finally {
      _autoAssistInFlight = false;
    }
  }

  @override
  void dispose() {
    widget.runtime.removeListener(_handleRuntimeSignalChange);
    _proactiveAssistTimer?.cancel();
    _flushInteractionSignal(reason: 'dispose');
    _interactionSignalTimer?.cancel();
    _webSpeechRecognition?.abort();
    _webSpeechRecognition = null;
    unawaited(_speechToText.stop());
    unawaited(_flutterTts.stop());
    if (kIsWeb) {
      WebSpeechSynthesis.cancel();
    }
    if (_audioPlayer != null) {
      unawaited(_audioPlayer!.stop());
      unawaited(_audioPlayer!.dispose());
    }
    if (_audioRecorder != null) {
      unawaited(_audioRecorder!.dispose());
    }
    _playerCompleteSub?.cancel();
    _playerStateSub?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startUploadRecording() async {
    if (_isSpeaking) {
      await _audioPlayer?.stop();
      await _flutterTts.stop();
      if (mounted) setState(() => _isSpeaking = false);
    }

    final String path;
    if (kIsWeb) {
      path = 'ai-coach-${DateTime.now().millisecondsSinceEpoch}.webm';
    } else {
      final dir = await getTemporaryDirectory();
      path = '${dir.path}/ai-coach-${DateTime.now().millisecondsSinceEpoch}.m4a';
    }
    await _ensureAudioRecorder().start(
      RecordConfig(
        encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc,
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
    final String? path = await _audioRecorder?.stop();
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
      final String locale = Localizations.localeOf(context).toLanguageTag();
      final TranscribeVoiceResponse transcribed;

      if (kIsWeb) {
        // On web, stop() returns a blob URL. Fetch it to get raw bytes.
        final http.Response blobResponse = await http.get(Uri.parse(path));
        final Uint8List audioBytes = blobResponse.bodyBytes;
        transcribed =
            await VoiceRuntimeService.instance.transcribeAudioBase64(
          audioBytes: audioBytes,
          mimeType: 'audio/webm;codecs=opus',
          locale: locale,
        );
      } else {
        transcribed =
            await VoiceRuntimeService.instance.transcribeAudioFile(
          audioFilePath: path,
          locale: locale,
        );
      }

      if (!mounted) return;
      setState(() {
        _replaceInputText(transcribed.transcript);
      });

      await TelemetryService.instance.logEvent(
        event: 'voice.transcribe',
        metadata: <String, dynamic>{
          'source': 'voice_api_upload',
          'surface': 'ai_coach_widget',
          'chars': transcribed.transcript.length,
          if (transcribed.confidence != null)
            'confidence': transcribed.confidence,
          'traceId': transcribed.traceId,
          'latencyMs': transcribed.latencyMs,
          'modelVersion': transcribed.modelVersion,
          'mode': _selectedMode.name,
        },
      );
      widget.runtime.trackEvent(
        'voice_stt_completed',
        missionId: widget.missionId,
        checkpointId: widget.checkpointId,
        payload: <String, dynamic>{
          'source': kIsWeb ? 'voice_api_upload_web' : 'voice_api_upload',
          'chars': transcribed.transcript.length,
          if (transcribed.confidence != null)
            'confidence': transcribed.confidence,
          if (transcribed.latencyMs != null)
            'latencyMs': transcribed.latencyMs,
        },
      );

      if (widget.voiceOnlyConversation) {
        if (mounted) {
          setState(() => _loading = false);
        }
        await _sendMessageWithInput(
          transcribed.transcript,
          source: 'voice_upload_auto',
        );
      }
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
    }
  }

  void _startWebSpeechListening() {
    final WebSpeechRecognition recognition = WebSpeechRecognition();
    _webSpeechRecognition = recognition;

    recognition.onResult = (String transcript, bool isFinal) {
      if (!mounted) return;
      setState(() {
        _replaceInputText(transcript);
      });

      if (isFinal) {
        TelemetryService.instance.logEvent(
          event: 'voice.transcribe',
          metadata: <String, dynamic>{
            'source': 'web_speech_api',
            'surface': 'ai_coach_widget',
            'chars': transcript.length,
            'mode': _selectedMode.name,
          },
        );
        widget.runtime.trackEvent(
          'voice_stt_completed',
          missionId: widget.missionId,
          checkpointId: widget.checkpointId,
          payload: <String, dynamic>{
            'source': 'web_speech_api',
            'chars': transcript.length,
          },
        );
        if (widget.voiceOnlyConversation) {
          recognition.stop();
          if (mounted) setState(() => _isListening = false);
          unawaited(_sendMessageWithInput(
            transcript,
            source: 'web_speech_api_auto',
          ));
        }
      }
    };

    recognition.onError = (String error) {
      if (!mounted) return;
      setState(() => _isListening = false);
      _webSpeechRecognition = null;
      if (error != 'aborted' && error != 'no-speech') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('ai.voice.transcriptionUnavailable')),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    };

    recognition.onEnd = () {
      if (!mounted) return;
      setState(() => _isListening = false);
      _webSpeechRecognition = null;
    };

    final String locale = Localizations.localeOf(context).toLanguageTag();
    recognition.start(locale: locale);
    if (mounted) setState(() => _isListening = true);
  }

  Future<void> _toggleListening() async {
    _markLearnerActivity();
    if (_loading) return;

    // Unlock Web Audio context on first user gesture (required by browsers).
    if (kIsWeb && !_webAudioContextUnlocked) {
      _webAudioContextUnlocked = true;
      unawaited(unlockWebAudioContext());
    }

    if (!_speechAvailable && !_uploadSttAvailable && !_webSpeechAvailable) {
      // Re-check Web Speech API support on web.
      if (kIsWeb) {
        _webSpeechAvailable = WebSpeechRecognition.isSupported;
      }

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

      final bool uploadReady =
          await _ensureAudioRecorder().hasPermission();
      if (!mounted) return;
      setState(() {
        _speechAvailable = speechReady;
        _uploadSttAvailable = uploadReady;
      });

      if (!speechReady && !uploadReady && !_webSpeechAvailable) {
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
      if (_webSpeechRecognition != null && _webSpeechRecognition!.isActive) {
        _webSpeechRecognition!.stop();
        if (mounted) setState(() => _isListening = false);
        return;
      }
      await _speechToText.stop();
      if (!mounted) return;
      setState(() => _isListening = false);
      return;
    }

    // Priority 1: Web Speech API on web (most reliable for WASM).
    if (kIsWeb && _webSpeechAvailable) {
      _startWebSpeechListening();
      return;
    }

    // Priority 2: speech_to_text plugin (native, may work on some web browsers).
    if (_speechAvailable) {
      final bool started = await _speechToText.listen(
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            _replaceInputText(result.recognizedWords);
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
            widget.runtime.trackEvent(
              'voice_stt_completed',
              missionId: widget.missionId,
              checkpointId: widget.checkpointId,
              payload: <String, dynamic>{
                'source': 'speech_to_text',
                'chars': result.recognizedWords.length,
                if (result.confidence > 0)
                  'confidence': result.confidence,
              },
            );
            if (widget.voiceOnlyConversation) {
              unawaited(_speechToText.stop());
              if (mounted) {
                setState(() => _isListening = false);
              }
              unawaited(_sendMessageWithInput(
                result.recognizedWords,
                source: 'speech_to_text_auto',
              ));
            }
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

    // Priority 3: Upload-based STT (native + web via base64).
    if (_uploadSttAvailable) {
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

  Future<void> _speakText(
    String text, {
    String? traceId,
    AiCoachResponse? responseOverride,
  }) async {
    if (!_voiceOutputEnabled) return;

    // Capture locale before any async gap to avoid use_build_context_synchronously.
    final String capturedLocale =
        Localizations.localeOf(context).toLanguageTag();

    if (widget.onSpeakOverride != null) {
      await widget.onSpeakOverride!(text);
      await TelemetryService.instance.logEvent(
        event: 'voice.tts',
        metadata: <String, dynamic>{
          'source': 'test_override',
          'surface': 'ai_coach_widget',
          'chars': text.length,
          'traceId': traceId,
        },
      );
      return;
    }

    _listenAfterSpeech = widget.voiceOnlyConversation;

    if (_isSpeaking) {
      await _audioPlayer?.stop();
      await _flutterTts.stop();
      if (mounted) setState(() => _isSpeaking = false);
    }

    bool played = false;
    final AiCoachResponse? responseForPlayback =
        responseOverride ?? _lastResponse;
    if (responseForPlayback?.voiceAvailable == true &&
        responseForPlayback?.voiceAudioUrl != null &&
        responseForPlayback!.voiceAudioUrl!.isNotEmpty) {
      final AudioPlayer audioPlayer = _ensureAudioPlayer();
      try {
        await _flutterTts.stop();
        await audioPlayer.stop();
        if (mounted) setState(() => _isSpeaking = true);
        await audioPlayer.play(UrlSource(responseForPlayback.voiceAudioUrl!));
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
        widget.runtime.trackEvent(
          'voice_tts_played',
          missionId: widget.missionId,
          checkpointId: widget.checkpointId,
          payload: <String, dynamic>{
            'source': 'voice_api_audio',
            'chars': text.length,
          },
        );
      } catch (_) {
        if (mounted) setState(() => _isSpeaking = false);
      }
    }

    if (!played) {
      try {
        await _audioPlayer?.stop();
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
        widget.runtime.trackEvent(
          'voice_tts_played',
          missionId: widget.missionId,
          checkpointId: widget.checkpointId,
          payload: <String, dynamic>{
            'source': kIsWeb ? 'flutter_tts_web' : 'flutter_tts',
            'chars': text.length,
          },
        );
      } catch (_) {
        if (mounted) setState(() => _isSpeaking = false);
      }
    }

    // Fallback: direct browser speechSynthesis via Web Speech API.
    if (!played && kIsWeb && WebSpeechSynthesis.isSupported) {
      try {
        if (mounted) setState(() => _isSpeaking = true);
        await WebSpeechSynthesis.speak(
          text,
          locale: capturedLocale,
          rate: 0.86,
          pitch: 1.04,
        );
        played = true;
        if (mounted) setState(() => _isSpeaking = false);
        await TelemetryService.instance.logEvent(
          event: 'voice.tts',
          metadata: <String, dynamic>{
            'source': 'web_speech_synthesis',
            'surface': 'ai_coach_widget',
            'chars': text.length,
            'traceId': traceId,
          },
        );
        widget.runtime.trackEvent(
          'voice_tts_played',
          missionId: widget.missionId,
          checkpointId: widget.checkpointId,
          payload: <String, dynamic>{
            'source': 'web_speech_synthesis',
            'chars': text.length,
          },
        );
        if (_listenAfterSpeech) {
          _listenAfterSpeech = false;
          unawaited(_toggleListening());
        }
      } catch (_) {
        if (mounted) setState(() => _isSpeaking = false);
      }
    }

    if (!played) {
      _listenAfterSpeech = false;
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
    final Iterable<_ChatMessage> window =
        _messages.reversed.take(limit).toList().reversed;
    return window
        .map((m) =>
            '${m.isUser ? 'Learner' : 'Coach'}: ${m.text.replaceAll('\n', ' ').trim()}')
        .toList();
  }

  String _privacySafeText(String text, {int maxLength = 240}) {
    String sanitized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    sanitized = sanitized.replaceAll(
      RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b'),
      '[email]',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'(\+\d{1,3}[-.]?)?\(?\d{3}\)?[-.]?\d{3}[-.]?\d{4}'),
      '[phone]',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'\b[A-Za-z0-9]{20,}\b'),
      '[id]',
    );
    if (sanitized.length <= maxLength) {
      return sanitized;
    }
    return '${sanitized.substring(0, maxLength - 1)}...';
  }

  List<String> _privacySafeConversationTurns({int limit = 6}) {
    return _recentConversationTurns(limit: limit)
        .map((String turn) => _privacySafeText(turn, maxLength: 180))
        .toList();
  }

  List<String> _privacySafeLearningGoals() {
    return _learningGoals
        .map((String goal) => _privacySafeText(goal, maxLength: 80))
        .where((String goal) => goal.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> _buildPrivacySafeCopilotContext(String sanitizedInput) {
    final List<String> safeGoals = _privacySafeLearningGoals();
    return <String, dynamic>{
      'userInput': sanitizedInput,
      'conversationTurns': _privacySafeConversationTurns(),
      'learningGoals': safeGoals,
      if (widget.missionId != null) 'missionId': widget.missionId,
      if (widget.checkpointId != null) 'checkpointId': widget.checkpointId,
      if (widget.runtime.sessionOccurrenceId != null)
        'sessionOccurrenceId': widget.runtime.sessionOccurrenceId,
      'mode': _selectedMode.name,
      'role': widget.actorRole.name,
      'aiHelpLoop': true,
      'bosMiaLoop': true,
      'loopTags': _bosMiaLoopTags(),
      'loopLineage':
          'mathematical_learner_state_model + synthetic_training_baseline_not_learner_evidence + live_session_updates',
      'personaInstructions':
          'Kid-friendly, conversational coaching voice. Keep it warm, simple, and spoken. Never give final answers; guide step-by-step.',
      // BOS orchestration state from live Firestore listener.
      if (widget.runtime.state != null) 'orchestrationState': <String, dynamic>{
        'xHat': <String, double>{
          'cognition': widget.runtime.state!.xHat.cognition,
          'engagement': widget.runtime.state!.xHat.engagement,
          'integrity': widget.runtime.state!.xHat.integrity,
        },
        if (widget.runtime.confidence != null)
          'confidence': widget.runtime.confidence,
        'stateStatus': widget.runtime.stateStatus.name,
      },
      // Active MVL episode context.
      if (widget.runtime.hasMvlGate) 'activeMvl': <String, dynamic>{
        'active': true,
        if (widget.runtime.activeMvl?.triggerReason != null)
          'triggerReason': widget.runtime.activeMvl!.triggerReason,
        if (widget.runtime.activeMvl?.evidenceEventIds != null)
          'evidenceCount': widget.runtime.activeMvl!.evidenceEventIds.length,
      },
    };
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
    if (state == null) return 'unavailable';
    return 'cognition=${state.cognition.toStringAsFixed(2)}, engagement=${state.engagement.toStringAsFixed(2)}, integrity=${state.integrity.toStringAsFixed(2)}';
  }

  _RuntimeHonestyStatus? _runtimeHonestyStatus() {
    if (widget.runtime.stateStatus == LearningRuntimeStateStatus.malformed) {
      return _RuntimeHonestyStatus.malformed;
    }
    final double? confidence = widget.runtime.confidence;
    if (widget.runtime.stateStatus == LearningRuntimeStateStatus.unavailable ||
        confidence == null) {
      return _RuntimeHonestyStatus.unavailable;
    }
    if (widget.actorRole == UserRole.learner && confidence < 0.97) {
      return _RuntimeHonestyStatus.guarded;
    }
    return null;
  }

  String _runtimeHonestyText(_RuntimeHonestyStatus status) {
    switch (status) {
      case _RuntimeHonestyStatus.unavailable:
        return _t('ai.banner.runtimeUnavailable');
      case _RuntimeHonestyStatus.malformed:
        return _t('ai.banner.runtimeMalformed');
      case _RuntimeHonestyStatus.guarded:
        final String percent =
            ((widget.runtime.confidence ?? 0.0) * 100).toStringAsFixed(0);
        return _t('ai.banner.learnerGuarded')
            .replaceFirst('{percent}', percent);
    }
  }

  String _buildConversationalPrompt(String userInput) {
    final List<String> turns = _privacySafeConversationTurns();
    final String conversation =
        turns.isEmpty ? 'No prior turns.' : turns.join('\n');
    final String tags = _bosMiaLoopTags().join(', ');
    final List<String> safeGoals = _privacySafeLearningGoals();
    final String goals = safeGoals.isEmpty
        ? 'none yet'
        : safeGoals.map((g) => '- $g').join('\n');

    return '''
You are MiloOS in a live spoken conversation.
${_roleInstruction(widget.actorRole)}
Mode: ${_selectedMode.name}. ${_coachDirectiveForMode(_selectedMode)}
Safety: Do not provide final graded answers; scaffold thinking.

Context:
- missionContextAvailable: ${(widget.missionId ?? '').trim().isEmpty ? 'no' : 'yes'}
- checkpointContextAvailable: ${(widget.checkpointId ?? '').trim().isEmpty ? 'no' : 'yes'}
- sessionContextAvailable: ${(widget.runtime.sessionOccurrenceId ?? '').trim().isEmpty ? 'no' : 'yes'}
- conceptTags: ${tags.isEmpty ? 'none' : tags}
- stateEstimate: ${_stateSnapshot()}
- runtimeLoop: Stay in the live spoken support loop and improve support for this specific learner over time.
- loopLineage: Use the mathematical learner-state model, control policy, and synthetic-trained runtime baseline for pretraining only, never as learner evidence, before adapting to this live session.

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
    final bool exists =
        _learningGoals.map((g) => g.toLowerCase()).contains(candidateKey);
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
    return widget.actorRole == UserRole.educator ||
        widget.actorRole == UserRole.hq;
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

  Future<void> _interruptSpeaking() async {
    try {
      await HapticFeedback.selectionClick();
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {
      // Best-effort cue only.
    }

    await _audioPlayer?.stop();
    await _flutterTts.stop();
    _listenAfterSpeech = false;
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
    _markLearnerActivity();
    // Immediately stop any ongoing speech, whether from user or AI
    if (_isListening) {
      if (_usingUploadStt) {
        await _stopUploadRecordingAndTranscribe();
      } else if (_webSpeechRecognition != null &&
          _webSpeechRecognition!.isActive) {
        _webSpeechRecognition!.stop();
      } else {
        await _speechToText.stop();
      }
      if (mounted) setState(() => _isListening = false);
    }
    if (_isSpeaking) {
      await _interruptSpeaking();
    }

    await _sendMessageWithInput(
      _inputController.text,
      source: 'manual',
    );
  }

  Future<void> _submitExplainBack(String explanation) async {
    _awaitingExplainBack = false;
    final String interactionId = _explainBackInteractionId ?? '';
    _explainBackInteractionId = null;

    setState(() {
      _messages.add(_ChatMessage(text: explanation, isUser: true));
      _loading = true;
      _clearInputText();
    });
    _scrollToBottom();

    try {
      final String siteId = widget.runtime.siteId;
      final ExplainBackResult result =
          await BosService.instance.submitExplainBack(
        siteId: siteId,
        interactionId: interactionId,
        explainBack: explanation,
      );

      if (!mounted) return;

      widget.runtime.trackEvent(
        'explain_it_back_submitted',
        missionId: widget.missionId,
        checkpointId: widget.checkpointId,
        payload: <String, dynamic>{
          'approved': result.approved,
          'interactionId': interactionId,
          'explainBackLength': explanation.length,
        },
      );

      setState(() {
        _messages.add(_ChatMessage(
          text: result.feedback,
          isUser: false,
          isSystemPrompt: true,
        ));
        _loading = false;
      });
      _scrollToBottom();
      if (widget.voiceOnlyConversation) {
        await _speakText(result.feedback);
      }

      if (!result.approved) {
        // Prompt learner to try again.
        _awaitingExplainBack = true;
        _explainBackInteractionId = interactionId;
      } else if (widget.runtime.hasMvlGate) {
        // Approved explain-back is strong evidence for lifting MVL gate.
        final MvlEpisode? episode = widget.runtime.activeMvl;
        if (episode != null && interactionId.isNotEmpty) {
          try {
            await BosService.instance.submitMvlEvidence(
              episodeId: episode.id,
              eventIds: <String>[interactionId],
            );
          } catch (_) {
            // Non-critical.
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(
          text: _t('ai.explainBack.error'),
          isUser: false,
          isSystemPrompt: true,
          isError: true,
        ));
        _loading = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _sendMessageWithInput(
    String rawInput, {
    required String source,
  }) async {
    final String input = rawInput.trim();
    if (_loading || input.isEmpty) return;

    // Intercept: if we're awaiting an explain-it-back, submit it
    // instead of sending a normal copilot request.
    if (_awaitingExplainBack) {
      await _submitExplainBack(input);
      return;
    }

    if (source == 'manual') {
      _flushInteractionSignal(reason: 'submitted');
    }
    _updateLearningGoals(input);

    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'ai_coach_widget',
        'cta_id': 'send_message',
        'surface': 'input_bar',
        'source': source,
        'mode': _selectedMode.name,
        'has_input': input.isNotEmpty,
      },
    );

    setState(() {
      _messages.add(_ChatMessage(text: input, isUser: true));
      _loading = true;
      _clearInputText();
    });
    _scrollToBottom();

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
      _scrollToBottom();

      await _speakText(
        aiMessage.text,
        traceId: response.traceId,
        responseOverride: response,
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
          'source':
              response.policyVersion == null ? 'bos_callable' : 'voice_api',
        },
      );

      // Trigger explain-it-back prompt when BOS requires it.
      if (response.requiresExplainBack &&
          widget.actorRole == UserRole.learner &&
          mounted) {
        _awaitingExplainBack = true;
        _explainBackInteractionId =
            response.traceId ?? response.aiHelpOpenedEventId;
        setState(() {
          _messages.add(_ChatMessage(
            text: _t('ai.explainBack.prompt'),
            isUser: false,
            isSystemPrompt: true,
          ));
        });
        _scrollToBottom();
        if (widget.voiceOnlyConversation) {
          await _speakText(_t('ai.explainBack.prompt'));
        }
      }

      // Submit chat interaction as MVL evidence when gate is active.
      if (widget.runtime.hasMvlGate &&
          widget.actorRole == UserRole.learner) {
        final MvlEpisode? episode = widget.runtime.activeMvl;
        final String? eventId =
            response.aiHelpOpenedEventId ?? response.traceId;
        if (episode != null && eventId != null && eventId.isNotEmpty) {
          try {
            await BosService.instance.submitMvlEvidence(
              episodeId: episode.id,
              eventIds: <String>[eventId],
            );
            widget.runtime.trackEvent(
              'mvl_evidence_submitted',
              missionId: widget.missionId,
              checkpointId: widget.checkpointId,
              payload: <String, dynamic>{
                'episodeId': episode.id,
                'source': 'ai_coach_chat',
                'mode': _selectedMode.name,
              },
            );
          } catch (_) {
            // Non-critical — evidence submission failure should not
            // disrupt the chat flow.
          }
        }
      }
    } catch (e) {
      await TelemetryService.instance.logEvent(
        event: 'voice.message',
        metadata: <String, dynamic>{
          'surface': 'ai_coach_widget',
          'mode': _selectedMode.name,
          'source': 'safe_escalation',
          'error': e.toString(),
          'role': widget.actorRole.name,
        },
      );

      if (kDebugMode) {
        debugPrint('MiloOS request failed, returning safe escalation: $e');
      }

      setState(() {
        _messages.add(_ChatMessage(
          text: _t('ai.error.safeEscalation'),
          isUser: false,
          isError: true,
        ));
        _loading = false;
      });
      _scrollToBottom();
    }
  }

  Future<AiCoachResponse> _fetchAndProcessResponse(String prompt) async {
    if (widget.onResponseRequest != null) {
      return widget.onResponseRequest!(
        _buildConversationalPrompt(_privacySafeText(prompt, maxLength: 320)),
        _selectedMode,
      );
    }

    final String sanitizedPrompt = _privacySafeText(prompt, maxLength: 320);
    final AiCoachResponse response =
        await VoiceRuntimeService.instance.requestCopilot(
      VoiceCopilotRequest(
        message: _buildConversationalPrompt(sanitizedPrompt),
        locale: Localizations.localeOf(context).toLanguageTag(),
        gradeBand: widget.runtime.gradeBand,
        context: _buildPrivacySafeCopilotContext(sanitizedPrompt),
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
    if (widget.runtime.hasMvlGate && response.mvlGateActive) {
      widget.runtime.trackEvent(
        'mvl_gate_triggered',
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
        content:
            Text(helpful ? _t('ai.feedback.thanks') : _t('ai.feedback.noted')),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasMvl = widget.runtime.hasMvlGate;
    final _RuntimeHonestyStatus? runtimeHonestyStatus = _runtimeHonestyStatus();

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
            if (mode == AiCoachMode.debug) {
              widget.runtime.trackEvent('debug_attempted', payload: <String, dynamic>{
                'missionId': widget.missionId ?? '',
              });
            }
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
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer),
                  ),
                ),
              ],
            ),
          ),

        if (runtimeHonestyStatus != null)
          _RuntimeHonestyBanner(
            status: runtimeHonestyStatus,
            text: _runtimeHonestyText(runtimeHonestyStatus),
          ),

        _LineageDisclosureBanner(
          text: _t('ai.banner.lineageDisclosure'),
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
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: _messages.length,
                  itemBuilder: (BuildContext context, int index) {
                    return _ChatBubble(
                      message: _messages[index],
                      voiceOnlyConversation: widget.voiceOnlyConversation,
                      onReplay: !_messages[index].isUser &&
                              widget.voiceOnlyConversation &&
                              _messages[index].response != null
                          ? () => _speakText(
                                _messages[index].text,
                                traceId: _messages[index].response!.traceId,
                                responseOverride: _messages[index].response,
                              )
                          : null,
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
                if (widget.voiceOnlyConversation ||
                    _speechAvailable ||
                    _uploadSttAvailable ||
                    _webSpeechAvailable)
                  IconButton(
                    onPressed:
                        (_loading || _isSpeaking) ? null : _toggleListening,
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
                          setState(
                              () => _voiceOutputEnabled = !_voiceOutputEnabled);
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
                if (widget.voiceOnlyConversation)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _isListening
                            ? _t('ai.voiceOnly.listening')
                            : _t('ai.voiceOnly.promptTap'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      enabled: !_isSpeaking,
                      decoration: InputDecoration(
                        hintText: _isSpeaking
                            ? _t('ai.voice.speaking')
                            : _modeHint(_selectedMode),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.send,
                      onChanged: _handleInputChanged,
                      onSubmitted: (_) => _sendMessage(),
                      maxLines: 3,
                      minLines: 1,
                    ),
                  ),
                if (!widget.voiceOnlyConversation) const SizedBox(width: 8),
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
                if (!widget.voiceOnlyConversation)
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

enum _RuntimeHonestyStatus {
  unavailable,
  malformed,
  guarded,
}

class _RuntimeHonestyBanner extends StatelessWidget {
  const _RuntimeHonestyBanner({
    required this.status,
    required this.text,
  });

  final _RuntimeHonestyStatus status;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final _RuntimeHonestyTone tone = switch (status) {
      _RuntimeHonestyStatus.unavailable => _RuntimeHonestyTone(
          icon: Icons.analytics_outlined,
          background: theme.colorScheme.secondaryContainer,
          foreground: theme.colorScheme.onSecondaryContainer,
          border: theme.colorScheme.secondary,
        ),
      _RuntimeHonestyStatus.malformed => _RuntimeHonestyTone(
          icon: Icons.warning_amber_rounded,
          background: theme.colorScheme.errorContainer,
          foreground: theme.colorScheme.onErrorContainer,
          border: theme.colorScheme.error,
        ),
      _RuntimeHonestyStatus.guarded => _RuntimeHonestyTone(
          icon: Icons.shield_outlined,
          background: theme.colorScheme.tertiaryContainer,
          foreground: theme.colorScheme.onTertiaryContainer,
          border: theme.colorScheme.tertiary,
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tone.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(tone.icon, color: tone.foreground, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: tone.foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RuntimeHonestyTone {
  const _RuntimeHonestyTone({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.border,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final Color border;
}

class _LineageDisclosureBanner extends StatelessWidget {
  const _LineageDisclosureBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.info_outline_rounded,
            color: theme.colorScheme.onSurfaceVariant,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.selected, required this.onChanged});

  final AiCoachMode selected;
  final ValueChanged<AiCoachMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: AiCoachMode.values.map((AiCoachMode mode) {
          final bool isSelected = mode == selected;
          return ChoiceChip(
            label: Text(_modeLabel(context, mode)),
            selected: isSelected,
            onSelected: (_) => onChanged(mode),
            avatar: Icon(_modeIcon(mode), size: 16),
            visualDensity: VisualDensity.compact,
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
    this.isSystemPrompt = false,
  });

  final String text;
  final bool isUser;
  final AiCoachResponse? response;
  final bool isError;
  final bool isSystemPrompt;
}

// ──── Chat bubble ────

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    this.voiceOnlyConversation = false,
    this.onReplay,
    this.onFeedback,
  });

  final _ChatMessage message;
  final bool voiceOnlyConversation;
  final Future<void> Function()? onReplay;
  final void Function(bool helpful)? onFeedback;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isUser = message.isUser;
    final bool hideAiTranscript = voiceOnlyConversation && !isUser;

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
              : message.isSystemPrompt
                  ? theme.colorScheme.tertiaryContainer
                  : message.isError
                      ? theme.colorScheme.errorContainer
                      : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (hideAiTranscript)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    AppStrings.of(context, 'ai.voiceOnly.answeredOutLoud'),
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (onReplay != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextButton.icon(
                        onPressed: () => onReplay!(),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          foregroundColor: theme.colorScheme.primary,
                        ),
                        icon: const Icon(Icons.volume_up_outlined, size: 16),
                        label:
                            Text(AppStrings.of(context, 'ai.voiceOnly.replay')),
                      ),
                    ),
                ],
              )
            else
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
