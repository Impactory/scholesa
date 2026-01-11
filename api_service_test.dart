import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'c:/Users/simon/OneDrive/Desktop/My codes/scholesa-edu-2/api_service.dart';
import 'c:/Users/simon/OneDrive/Desktop/My codes/scholesa-edu-2/exceptions.dart';

void main() {
  group('ApiService', () {
    test('fetchUserProfile returns user data on a successful call', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"id": "123", "name": "Simon"}', 200);
      });

      final apiService = ApiService(client: mockClient);
      final profile = await apiService.fetchUserProfile('123');

      expect(profile, contains('Simon'));
    });

    test(
        'fetchUserProfile throws UserProfileException on a failed call',
        () async {
      final mockClient = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final apiService = ApiService(client: mockClient);

      // Verify that the correct, specific exception is thrown.
      expect(
          () => apiService.fetchUserProfile('123'),
          throwsA(isA<UserProfileException>()));
    });
  });
}