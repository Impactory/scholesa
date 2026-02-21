class UserProfileException implements Exception {
  UserProfileException(
    this.message, {
    this.statusCode,
  });

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      statusCode == null ? 'UserProfileException: $message' : 'UserProfileException($statusCode): $message';
}
