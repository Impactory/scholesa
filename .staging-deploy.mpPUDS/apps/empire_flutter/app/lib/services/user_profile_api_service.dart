import 'package:http/http.dart' as http;
import '../app_config.dart';
import 'user_profile_exceptions.dart';

class UserProfileApiService {
  UserProfileApiService({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  Future<String> fetchUserProfile(String userId) async {
    final Uri requestUri = Uri.parse('$_baseUrl/users/$userId');
    final http.Response response = await _client.get(requestUri);

    if (response.statusCode == 200) {
      return response.body;
    }

    throw UserProfileException(
      'Failed to load user profile',
      statusCode: response.statusCode,
    );
  }

  void dispose() {
    _client.close();
  }
}
