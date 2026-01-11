import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Service for Firebase Storage operations
class StorageService {
  StorageService({
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  })  : _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  /// Upload a file to Firebase Storage
  /// Returns the download URL
  Future<String> uploadFile({
    required String path,
    required Uint8List data,
    String? contentType,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final Reference ref = _storage.ref().child(path);
    
    final SettableMetadata metadata = SettableMetadata(
      contentType: contentType,
      customMetadata: <String, String>{
        'uploadedBy': user.uid,
        'uploadedAt': DateTime.now().toIso8601String(),
      },
    );

    final UploadTask task = ref.putData(data, metadata);
    final TaskSnapshot snapshot = await task;
    
    return await snapshot.ref.getDownloadURL();
  }

  /// Upload a profile photo
  Future<String> uploadProfilePhoto({
    required Uint8List data,
    String contentType = 'image/jpeg',
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final String path = 'users/${user.uid}/profile.jpg';
    return uploadFile(path: path, data: data, contentType: contentType);
  }

  /// Upload a mission submission (image, video, document)
  Future<String> uploadMissionSubmission({
    required String missionId,
    required String filename,
    required Uint8List data,
    String? contentType,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String path = 'submissions/${user.uid}/$missionId/${timestamp}_$filename';
    return uploadFile(path: path, data: data, contentType: contentType);
  }

  /// Upload a site asset (logo, banner, etc.)
  Future<String> uploadSiteAsset({
    required String siteId,
    required String assetType,
    required Uint8List data,
    String? contentType,
  }) async {
    final String path = 'sites/$siteId/assets/$assetType';
    return uploadFile(path: path, data: data, contentType: contentType);
  }

  /// Upload a message attachment
  Future<String> uploadMessageAttachment({
    required String conversationId,
    required String filename,
    required Uint8List data,
    String? contentType,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String path = 'messages/$conversationId/${timestamp}_$filename';
    return uploadFile(path: path, data: data, contentType: contentType);
  }

  /// Delete a file from storage
  Future<void> deleteFile(String path) async {
    await _storage.ref().child(path).delete();
  }

  /// Get download URL for a file
  Future<String> getDownloadUrl(String path) async {
    return await _storage.ref().child(path).getDownloadURL();
  }

  /// Get Firebase Storage instance for direct operations
  FirebaseStorage get storage => _storage;
}
