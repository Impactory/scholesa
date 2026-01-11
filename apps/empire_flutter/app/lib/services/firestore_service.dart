import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for direct Firestore operations
class FirestoreService {
  FirestoreService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  // ==================== USER OPERATIONS ====================

  /// Get current user's profile from Firestore
  Future<Map<String, dynamic>?> getUserProfile() async {
    final User? user = _auth.currentUser;
    if (user == null) return null;

    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _firestore.collection('users').doc(user.uid).get();

    if (!doc.exists) {
      // Create default profile if doesn't exist
      final Map<String, dynamic> defaultProfile = <String, dynamic>{
        'email': user.email ?? '',
        'displayName': user.displayName ?? user.email?.split('@')[0] ?? '',
        'role': 'learner',
        'siteIds': <String>[],
        'entitlements': <Map<String, dynamic>>[],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await _firestore.collection('users').doc(user.uid).set(defaultProfile);
      
      return <String, dynamic>{
        'userId': user.uid,
        'email': defaultProfile['email'],
        'displayName': defaultProfile['displayName'],
        'role': defaultProfile['role'],
        'activeSiteId': null,
        'siteIds': <String>[],
        'entitlements': <Map<String, dynamic>>[],
      };
    }

    final Map<String, dynamic> data = doc.data()!;
    return <String, dynamic>{
      'userId': user.uid,
      'email': data['email'] ?? user.email,
      'displayName': data['displayName'] ?? user.displayName,
      'role': data['role'] ?? 'learner',
      'activeSiteId': data['activeSiteId'] ?? (data['siteIds'] as List<dynamic>?)?.firstOrNull,
      'siteIds': List<String>.from(data['siteIds'] ?? <dynamic>[]),
      'entitlements': List<Map<String, dynamic>>.from(data['entitlements'] ?? <dynamic>[]),
    };
  }

  /// Update user profile in Firestore
  Future<void> updateUserProfile(Map<String, dynamic> updates) async {
    final User? user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    await _firestore.collection('users').doc(user.uid).update(<String, dynamic>{
      ...updates,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Create user profile after registration
  Future<void> createUserProfile({
    required String displayName,
    String role = 'learner',
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    await _firestore.collection('users').doc(user.uid).set(<String, dynamic>{
      'email': user.email ?? '',
      'displayName': displayName,
      'role': role,
      'siteIds': <String>[],
      'entitlements': <Map<String, dynamic>>[],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ==================== SITE OPERATIONS ====================

  /// Get sites for current user
  Future<List<Map<String, dynamic>>> getUserSites() async {
    final User? user = _auth.currentUser;
    if (user == null) return <Map<String, dynamic>>[];

    final DocumentSnapshot<Map<String, dynamic>> userDoc =
        await _firestore.collection('users').doc(user.uid).get();
    
    if (!userDoc.exists) return <Map<String, dynamic>>[];
    
    final List<String> siteIds = List<String>.from(userDoc.data()?['siteIds'] ?? <dynamic>[]);
    if (siteIds.isEmpty) return <Map<String, dynamic>>[];

    final List<Map<String, dynamic>> sites = <Map<String, dynamic>>[];
    for (final String siteId in siteIds) {
      final DocumentSnapshot<Map<String, dynamic>> siteDoc =
          await _firestore.collection('sites').doc(siteId).get();
      if (siteDoc.exists) {
        sites.add(<String, dynamic>{
          'id': siteDoc.id,
          ...siteDoc.data()!,
        });
      }
    }
    return sites;
  }

  /// Get site by ID
  Future<Map<String, dynamic>?> getSite(String siteId) async {
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _firestore.collection('sites').doc(siteId).get();
    if (!doc.exists) return null;
    return <String, dynamic>{
      'id': doc.id,
      ...doc.data()!,
    };
  }

  // ==================== ATTENDANCE OPERATIONS ====================

  /// Record attendance
  Future<String> recordAttendance({
    required String siteId,
    required String learnerId,
    required String sessionOccurrenceId,
    required String status,
    String? notes,
  }) async {
    final DocumentReference<Map<String, dynamic>> docRef =
        await _firestore.collection('attendanceRecords').add(<String, dynamic>{
      'siteId': siteId,
      'learnerId': learnerId,
      'sessionOccurrenceId': sessionOccurrenceId,
      'status': status,
      'notes': notes,
      'recordedBy': _auth.currentUser?.uid,
      'recordedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Get attendance records for a session
  Future<List<Map<String, dynamic>>> getSessionAttendance(String sessionOccurrenceId) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('attendanceRecords')
        .where('sessionOccurrenceId', isEqualTo: sessionOccurrenceId)
        .get();
    
    return snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => <String, dynamic>{
      'id': doc.id,
      ...doc.data(),
    }).toList();
  }

  // ==================== CHECKIN OPERATIONS ====================

  /// Record presence checkin
  Future<String> recordCheckin({
    required String siteId,
    required String learnerId,
  }) async {
    final DocumentReference<Map<String, dynamic>> docRef =
        await _firestore.collection('presenceRecords').add(<String, dynamic>{
      'siteId': siteId,
      'learnerId': learnerId,
      'type': 'checkin',
      'timestamp': FieldValue.serverTimestamp(),
      'recordedBy': _auth.currentUser?.uid,
    });
    return docRef.id;
  }

  /// Record presence checkout
  Future<String> recordCheckout({
    required String siteId,
    required String learnerId,
  }) async {
    final DocumentReference<Map<String, dynamic>> docRef =
        await _firestore.collection('presenceRecords').add(<String, dynamic>{
      'siteId': siteId,
      'learnerId': learnerId,
      'type': 'checkout',
      'timestamp': FieldValue.serverTimestamp(),
      'recordedBy': _auth.currentUser?.uid,
    });
    return docRef.id;
  }

  // ==================== MISSION OPERATIONS ====================

  /// Get missions for a learner
  Future<List<Map<String, dynamic>>> getLearnerMissions(String learnerId) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('missionAssignments')
        .where('learnerId', isEqualTo: learnerId)
        .orderBy('createdAt', descending: true)
        .get();
    
    return snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => <String, dynamic>{
      'id': doc.id,
      ...doc.data(),
    }).toList();
  }

  /// Submit mission attempt
  Future<String> submitMissionAttempt({
    required String missionId,
    required String learnerId,
    required Map<String, dynamic> submission,
  }) async {
    final DocumentReference<Map<String, dynamic>> docRef =
        await _firestore.collection('missionAttempts').add(<String, dynamic>{
      'missionId': missionId,
      'learnerId': learnerId,
      'submission': submission,
      'status': 'pending_review',
      'submittedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  // ==================== INCIDENT OPERATIONS ====================

  /// Submit an incident
  Future<String> submitIncident({
    required String siteId,
    required String type,
    required String description,
    List<String>? involvedLearnerIds,
  }) async {
    final DocumentReference<Map<String, dynamic>> docRef =
        await _firestore.collection('incidents').add(<String, dynamic>{
      'siteId': siteId,
      'type': type,
      'description': description,
      'involvedLearnerIds': involvedLearnerIds ?? <String>[],
      'reportedBy': _auth.currentUser?.uid,
      'status': 'open',
      'reportedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  // ==================== MESSAGE OPERATIONS ====================

  /// Send a message
  Future<String> sendMessage({
    required String conversationId,
    required String content,
    String? attachmentUrl,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final DocumentReference<Map<String, dynamic>> docRef =
        await _firestore.collection('messages').add(<String, dynamic>{
      'conversationId': conversationId,
      'senderId': user.uid,
      'content': content,
      'attachmentUrl': attachmentUrl,
      'readBy': <String>[user.uid],
      'sentAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update conversation last message
    await _firestore.collection('conversations').doc(conversationId).update(<String, dynamic>{
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessagePreview': content.length > 50 ? '${content.substring(0, 50)}...' : content,
    });

    return docRef.id;
  }

  /// Get messages for a conversation
  Stream<List<Map<String, dynamic>>> getMessages(String conversationId) {
    return _firestore
        .collection('messages')
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('sentAt', descending: false)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
            .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => <String, dynamic>{
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList());
  }

  // ==================== SESSION OPERATIONS ====================

  /// Get sessions for a site
  Future<List<Map<String, dynamic>>> getSiteSessions(String siteId) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('sessions')
        .where('siteId', isEqualTo: siteId)
        .orderBy('createdAt', descending: true)
        .get();
    
    return snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => <String, dynamic>{
      'id': doc.id,
      ...doc.data(),
    }).toList();
  }

  /// Get session occurrences for today
  Future<List<Map<String, dynamic>>> getTodaySessionOccurrences(String siteId) async {
    final DateTime now = DateTime.now();
    final DateTime startOfDay = DateTime(now.year, now.month, now.day);
    final DateTime endOfDay = startOfDay.add(const Duration(days: 1));

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('sessionOccurrences')
        .where('siteId', isEqualTo: siteId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .get();
    
    return snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => <String, dynamic>{
      'id': doc.id,
      ...doc.data(),
    }).toList();
  }

  // ==================== SKILL OPERATIONS ====================

  /// Get skills by pillar
  Future<List<Map<String, dynamic>>> getSkillsByPillar(String pillarCode) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('skills')
        .where('pillarCode', isEqualTo: pillarCode)
        .orderBy('name')
        .get();
    
    return snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => <String, dynamic>{
      'id': doc.id,
      ...doc.data(),
    }).toList();
  }

  /// Get learner skill assessments
  Future<List<Map<String, dynamic>>> getLearnerSkillAssessments(String learnerId) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('skillAssessments')
        .where('learnerId', isEqualTo: learnerId)
        .orderBy('assessedAt', descending: true)
        .get();
    
    return snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => <String, dynamic>{
      'id': doc.id,
      ...doc.data(),
    }).toList();
  }

  // ==================== GENERIC OPERATIONS ====================

  /// Generic document get
  Future<Map<String, dynamic>?> getDocument(String collection, String docId) async {
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _firestore.collection(collection).doc(docId).get();
    if (!doc.exists) return null;
    return <String, dynamic>{
      'id': doc.id,
      ...doc.data()!,
    };
  }

  /// Generic collection query
  Future<List<Map<String, dynamic>>> queryCollection(
    String collection, {
    List<List<dynamic>>? where,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) async {
    Query<Map<String, dynamic>> query = _firestore.collection(collection);
    
    if (where != null) {
      for (final List<dynamic> condition in where) {
        query = query.where(condition[0] as String, isEqualTo: condition[1]);
      }
    }
    
    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }
    
    if (limit != null) {
      query = query.limit(limit);
    }
    
    final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
    return snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => <String, dynamic>{
      'id': doc.id,
      ...doc.data(),
    }).toList();
  }

  /// Generic document create
  Future<String> createDocument(String collection, Map<String, dynamic> data) async {
    final DocumentReference<Map<String, dynamic>> docRef =
        await _firestore.collection(collection).add(<String, dynamic>{
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Generic document update
  Future<void> updateDocument(String collection, String docId, Map<String, dynamic> data) async {
    await _firestore.collection(collection).doc(docId).update(<String, dynamic>{
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Generic document delete
  Future<void> deleteDocument(String collection, String docId) async {
    await _firestore.collection(collection).doc(docId).delete();
  }

  /// Get Firestore instance for direct queries
  FirebaseFirestore get firestore => _firestore;
}
