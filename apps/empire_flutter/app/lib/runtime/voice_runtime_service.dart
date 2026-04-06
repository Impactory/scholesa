import 'dart:convert';

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

  static const Duration _timeout = Duration(seconds: 25);

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
        .timeout(_timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'Voice help is unavailable right now (${response.statusCode}).');
    }

    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;

    return AiCoachResponse.fromMap(<String, dynamic>{
      'message': (json['text'] as String?)?.trim() ?? '',
      'mode': 'hint',
      'suggestedNextSteps': const <String>[],
      'metadata': json['metadata'] as Map<String, dynamic>? ??
          const <String, dynamic>{},
      'tts': json['tts'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      'meta': <String, dynamic>{
        'version': 'voice-api-v1',
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
      throw Exception('Audio file transcription is not available on web. Use the Web Speech API instead.');
    }

    request.files
        .add(await http.MultipartFile.fromPath('audio', audioFilePath));

    final http.StreamedResponse streamed =
        await request.send().timeout(_timeout);
    final http.Response response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'Voice transcription is unavailable right now (${response.statusCode}).');
    }

    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;
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
      'https://us-central1-$projectId.cloudfunctions.net/voiceApi$cleanedPath',
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
