@Deprecated(
  'Use apps/empire_flutter/app/lib/services/user_profile_api_service.dart instead.',
)
class ApiService {
  const ApiService();

  Future<String> fetchUserProfile(String userId) {
    throw UnsupportedError(
      'Legacy root ApiService is deprecated. Use UserProfileApiService in the Flutter app package.',
    );
  }
}