/// Exception thrown when fetching a user profile fails.
class UserProfileException implements Exception {
  final String message;

  UserProfileException(
      [this.message = 'An unknown error occurred while fetching the user profile.']);

  @override
  String toString() => 'UserProfileException: $message';
}