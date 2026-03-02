import 'dart:convert';

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

  Future<AiCoachResponse> requestCopilot(VoiceCopilotRequest request) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Authentication required for voice copilot request.');
    }

    final String? idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Unable to resolve auth token for voice copilot request.');
    }
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
      throw Exception('Voice API error (${response.statusCode}): ${response.body}');
    }

    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;

    return AiCoachResponse.fromMap(<String, dynamic>{
      'message': (json['text'] as String?)?.trim() ?? '',
      'mode': 'hint',
      'suggestedNextSteps': const <String>[],
      'metadata': json['metadata'] as Map<String, dynamic>? ??
          const <String, dynamic>{},
      'tts': json['tts'] as Map<String, dynamic>? ??
          const <String, dynamic>{},
      'meta': <String, dynamic>{
        'version': 'voice-api-v1',
      },
    });
  }

  Uri _voiceApiUri(String path) {
    final String projectId = Firebase.app().options.projectId;
    final String cleanedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse(
      'https://us-central1-$projectId.cloudfunctions.net/voiceApi$cleanedPath',
    );
  }
}
