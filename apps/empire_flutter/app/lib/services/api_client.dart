import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../app_config.dart';

/// HTTP client that adds Firebase auth token to requests
class ApiClient {

  ApiClient({
    http.Client? httpClient,
    FirebaseAuth? auth,
    String? baseUrl,
  })  : _httpClient = httpClient ?? http.Client(),
        _auth = auth ?? FirebaseAuth.instance,
        _baseUrl = baseUrl ?? AppConfig.apiBaseUrl;
  final http.Client _httpClient;
  final FirebaseAuth _auth;
  final String _baseUrl;

  /// Get current auth token
  Future<String?> _getToken() async {
    final User? user = _auth.currentUser;
    if (user == null) return null;
    return user.getIdToken();
  }

  /// Build headers with auth token
  Future<Map<String, String>> _buildHeaders({
    String? idempotencyKey,
  }) async {
    final String? token = await _getToken();
    return <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
    };
  }

  /// GET request
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    final Uri uri = Uri.parse('$_baseUrl$path').replace(queryParameters: queryParams);
    final Map<String, String> headers = await _buildHeaders();
    
    final http.Response response = await _httpClient.get(uri, headers: headers);
    return _handleResponse(response);
  }

  /// POST request
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    String? idempotencyKey,
  }) async {
    final Uri uri = Uri.parse('$_baseUrl$path');
    final Map<String, String> headers = await _buildHeaders(idempotencyKey: idempotencyKey);
    
    final http.Response response = await _httpClient.post(
      uri,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  /// PATCH request
  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    String? idempotencyKey,
  }) async {
    final Uri uri = Uri.parse('$_baseUrl$path');
    final Map<String, String> headers = await _buildHeaders(idempotencyKey: idempotencyKey);
    
    final http.Response response = await _httpClient.patch(
      uri,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  /// DELETE request
  Future<Map<String, dynamic>> delete(String path) async {
    final Uri uri = Uri.parse('$_baseUrl$path');
    final Map<String, String> headers = await _buildHeaders();
    
    final http.Response response = await _httpClient.delete(uri, headers: headers);
    return _handleResponse(response);
  }

  /// Handle HTTP response
  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return <String, dynamic>{};
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    final Map<String, dynamic> errorBody = response.body.isNotEmpty
        ? jsonDecode(response.body) as Map<String, dynamic>
        : <String, dynamic>{};

    throw ApiException(
      statusCode: response.statusCode,
      code: errorBody['code'] as String? ?? 'UNKNOWN_ERROR',
      message: errorBody['message'] as String? ?? 'An error occurred',
    );
  }

  void dispose() {
    _httpClient.close();
  }
}

/// API exception with structured error info
class ApiException implements Exception {

  ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });
  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): [$code] $message';

  bool get isPermissionDenied => code == 'PERMISSION_DENIED';
  bool get isNotFound => code == 'NOT_FOUND';
  bool get isInvalidArgument => code == 'INVALID_ARGUMENT';
  bool get isFailedPrecondition => code == 'FAILED_PRECONDITION';
}
