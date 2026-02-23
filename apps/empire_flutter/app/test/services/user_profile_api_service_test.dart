import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scholesa_app/services/user_profile_api_service.dart';
import 'package:scholesa_app/services/user_profile_exceptions.dart';

void main() {
  group('UserProfileApiService', () {
    test('fetchUserProfile returns user data on successful call', () async {
      final MockClient mockClient = MockClient((http.Request request) async {
        return http.Response('{"id": "123", "name": "Simon"}', 200);
      });

      final UserProfileApiService apiService = UserProfileApiService(
        client: mockClient,
        baseUrl: 'https://example.com',
      );

      final String profile = await apiService.fetchUserProfile('123');

      expect(profile, contains('Simon'));
    });

    test('fetchUserProfile throws UserProfileException on failed call',
        () async {
      final MockClient mockClient = MockClient((http.Request request) async {
        return http.Response('Not Found', 404);
      });

      final UserProfileApiService apiService = UserProfileApiService(
        client: mockClient,
        baseUrl: 'https://example.com',
      );

      expect(
        () => apiService.fetchUserProfile('123'),
        throwsA(isA<UserProfileException>()),
      );
    });
  });
}
