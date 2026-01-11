import 'package:http/http.dart' as http;
import 'c:/Users/simon/OneDrive/Desktop/My codes/scholesa-edu-2/environment_config.dart';
import 'c:/Users/simon/OneDrive/Desktop/My codes/scholesa-edu-2/exceptions.dart';

class ApiService {
  final http.Client _client;

  static const String _baseUrl = EnvironmentConfig.apiUrl;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<String> fetchUserProfile(String userId) async {
    final requestUri = Uri.parse(_baseUrl).replace(path: '/users/$userId');

    final response = await _client.get(requestUri);

    if (response.statusCode == 200) {
      return response.body;
    }

    // Throw a specific exception with details for production logging.
    throw UserProfileException(
        'Failed to load user profile. Status code: ${response.statusCode}');
  }
}