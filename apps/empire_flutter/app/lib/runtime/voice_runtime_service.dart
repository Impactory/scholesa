import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

import 'bos_models.dart';

class VoiceCopilotRequest {
  const VoiceCopilotRequest({
    required this.message,
    required this.locale,
    required this.gradeBand,
    this.screenId = 'ai_coach_widget',
    this.context = const <String, dynamic>{},
    this.voiceEnabled = true,
    this.voiceOutput = true,
  });

  final String message;
  final String locale;
  final GradeBand gradeBand;
  final String screenId;
  final Map<String, dynamic> context;
  final bool voiceEnabled;
  final bool voiceOutput;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'message': message,
        'locale': locale,
        'screenId': screenId,
        'gradeBand': _gradeBandForVoice(gradeBand),
        'context': context,
        'voice': <String, dynamic>{
          'enabled': voiceEnabled,
          'output': voiceOutput,
        },
      };

  static String _gradeBandForVoice(GradeBand gradeBand) {
    switch (gradeBand) {
      case GradeBand.g1_3:
        return 'K-5';
      case GradeBand.g4_6:
        return 'K-5';
      case GradeBand.g7_9:
        return '6-8';
      case GradeBand.g10_12:
        return '9-12';
    }
  }
}

class VoiceRuntimeService {
  VoiceRuntimeService._();
  static final VoiceRuntimeService instance = VoiceRuntimeService._();

  /// Cloud Function region. Override for non-default deployments.
  static String region = 'us-central1';

  /// HTTP timeout for all voice API calls.
  static Duration timeout = const Duration(seconds: 25);

  Future<String> _requiredIdToken() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Sign in to use MiloOS by voice.');
    }
    final String? idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw Exception(
          'Sign-in could not be confirmed for MiloOS voice support.');
    }
    return idToken;
  }

  Future<AiCoachResponse> requestCopilot(VoiceCopilotRequest request) async {
    final String idToken = await _requiredIdToken();
    final Uri endpoint = _voiceApiUri('/copilot/message');

    final http.Response response = await http
        .post(
          endpoint,
          headers: <String, String>{
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
            'x-scholesa-locale': request.locale,
          },
          body: jsonEncode(request.toMap()),
        )
        .timeout(timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'Voice help is unavailable right now (${response.statusCode}): '
          '${response.body}');
    }

    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;

    final Map<String, dynamic> metadata =
        json['metadata'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final Map<String, dynamic> bos =
        json['bos'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final Map<String, dynamic> tts =
        json['tts'] as Map<String, dynamic>? ?? const <String, dynamic>{};

    // Derive mode from BOS policy hint if available, else from metadata.
    final String effectiveMode = (bos['mode'] as String?) ??
        (metadata['understanding'] is Map
            ? ((metadata['understanding'] as Map)['responseMode'] as String? ?? 'hint')
            : 'hint');

    return AiCoachResponse.fromMap(<String, dynamic>{
      'message': (json['text'] as String?)?.trim() ?? '',
      'mode': effectiveMode,
      'suggestedNextSteps': const <String>[],
      'metadata': metadata,
      'tts': tts,
      // Forward BOS policy data for MVL gating and risk assessment.
      if (bos.isNotEmpty) 'mvl': <String, dynamic>{
        'gateActive': bos['triggerMvl'] == true,
        'reason': (bos['reasonCodes'] as List<dynamic>?)?.isNotEmpty == true
            ? (bos['reasonCodes'] as List<dynamic>).first.toString()
            : null,
      },
      'requiresExplainBack': bos['requiresExplainBack'] == true,
      'meta': <String, dynamic>{
        'version': 'voice-api-v1',
        'traceId': metadata['traceId'],
        'policyVersion': metadata['policyVersion'],
      },
    });
  }

  Future<TranscribeVoiceResponse> transcribeAudioFile({
    required String audioFilePath,
    required String locale,
    bool partial = false,
    String? traceId,
  }) async {
    final String idToken = await _requiredIdToken();
    final Uri endpoint = _voiceApiUri('/voice/transcribe');

    final http.MultipartRequest request =
        http.MultipartRequest('POST', endpoint)
          ..headers.addAll(<String, String>{
            'Authorization': 'Bearer $idToken',
            'x-scholesa-locale': locale,
          })
          ..fields['locale'] = locale
          ..fields['partial'] = partial ? 'true' : 'false';

    if (traceId != null && traceId.isNotEmpty) {
      request.fields['traceId'] = traceId;
      request.headers['x-trace-id'] = traceId;
    }

    if (kIsWeb) {
      throw Exception(
        'Audio file transcription is not available on web. '
        'Use transcribeAudioBase64 or the Web Speech API instead.',
      );
    }

    request.files
        .add(await http.MultipartFile.fromPath('audio', audioFilePath));

    final http.StreamedResponse streamed =
        await request.send().timeout(timeout);
    final http.Response response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'Voice transcription is unavailable right now (${response.statusCode}): '
          '${response.body}');
    }

    return _parseTranscribeResponse(response.body);
  }

  /// Transcribe audio on the server using a base64-encoded audio payload.
  ///
  /// This is the web-compatible alternative to [transcribeAudioFile] — the
  /// backend already accepts `audioBase64` in a JSON body.
  Future<TranscribeVoiceResponse> transcribeAudioBase64({
    required Uint8List audioBytes,
    required String mimeType,
    required String locale,
    String? traceId,
  }) async {
    final String idToken = await _requiredIdToken();
    final Uri endpoint = _voiceApiUri('/voice/transcribe');

    final Map<String, dynamic> body = <String, dynamic>{
      'audioBase64': base64Encode(audioBytes),
      'mimeType': mimeType,
      'locale': locale,
    };
    if (traceId != null && traceId.isNotEmpty) {
      body['traceId'] = traceId;
    }

    final http.Response response = await http
        .post(
          endpoint,
          headers: <String, String>{
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
            'x-scholesa-locale': locale,
            if (traceId != null && traceId.isNotEmpty) 'x-trace-id': traceId,
          },
          body: jsonEncode(body),
        )
        .timeout(timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'Voice transcription is unavailable right now (${response.statusCode}): '
          '${response.body}');
    }

    return _parseTranscribeResponse(response.body);
  }

  TranscribeVoiceResponse _parseTranscribeResponse(String responseBody) {
    final Map<String, dynamic> json =
        jsonDecode(responseBody) as Map<String, dynamic>;
    final Map<String, dynamic> metadata =
        json['metadata'] as Map<String, dynamic>? ?? const <String, dynamic>{};

    return TranscribeVoiceResponse(
      transcript: (json['transcript'] as String?)?.trim() ?? '',
      confidence: _readFiniteConfidence(json['confidence']),
      traceId: metadata['traceId'] as String?,
      latencyMs: (metadata['latencyMs'] as num?)?.toInt(),
      modelVersion: metadata['modelVersion'] as String?,
      locale: metadata['locale'] as String?,
    );
  }

  double? _readFiniteConfidence(dynamic value) {
    if (value is! num) {
      return null;
    }
    final double confidence = value.toDouble();
    if (!confidence.isFinite) {
      return null;
    }
    return (confidence.clamp(0.0, 1.0) as num).toDouble();
  }

  Uri _voiceApiUri(String path) {
    final String projectId = Firebase.app().options.projectId;
    final String cleanedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse(
      'https://$region-$projectId.cloudfunctions.net/voiceApi$cleanedPath',
    );
  }
}

class TranscribeVoiceResponse {
  const TranscribeVoiceResponse({
    required this.transcript,
    required this.confidence,
    this.traceId,
    this.latencyMs,
    this.modelVersion,
    this.locale,
  });

  final String transcript;
  final double? confidence;
  final String? traceId;
  final int? latencyMs;
  final String? modelVersion;
  final String? locale;
}
