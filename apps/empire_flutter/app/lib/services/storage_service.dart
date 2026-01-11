import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';

class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  Future<String?> pickAndUploadDeliverable({required String contractId}) async {
    final result = await FilePicker.platform.pickFiles(withData: true, allowMultiple: false);
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final Uint8List? bytes = file.bytes;
    if (bytes == null) return null;

    final sanitizedName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9_\.\-]'), '_');
    final path = 'partnerDeliverables/$contractId/${DateTime.now().millisecondsSinceEpoch}-$sanitizedName';
    final ref = FirebaseStorage.instance.ref().child(path);
    final contentType = lookupMimeType(file.name, headerBytes: bytes.length >= 12 ? bytes.sublist(0, 12) : bytes) ?? 'application/octet-stream';
    final metadata = SettableMetadata(contentType: contentType);
    final task = ref.putData(bytes, metadata);
    final snapshot = await task.whenComplete(() {});
    return snapshot.ref.getDownloadURL();
  }

  Future<String?> pickAndUploadNotificationAttachment({required String threadId}) async {
    final result = await FilePicker.platform.pickFiles(withData: true, allowMultiple: false);
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final Uint8List? bytes = file.bytes;
    if (bytes == null) return null;
    final sanitizedName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9_\.\-]'), '_');
    final path = 'notificationUploads/$threadId/${DateTime.now().millisecondsSinceEpoch}-$sanitizedName';
    final ref = FirebaseStorage.instance.ref().child(path);
    final contentType = lookupMimeType(file.name, headerBytes: bytes.length >= 12 ? bytes.sublist(0, 12) : bytes) ?? 'application/octet-stream';
    final metadata = SettableMetadata(contentType: contentType);
    final task = ref.putData(bytes, metadata);
    final snapshot = await task.whenComplete(() {});
    return snapshot.ref.getDownloadURL();
  }
}
