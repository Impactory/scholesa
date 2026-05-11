import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service for direct Firestore operations
class FirestoreService {
  FirestoreService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _functionsOverride = functions;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions? _functionsOverride;

  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instance;

  FirebaseAuth get auth => _auth;

  // ==================== USER OPERATIONS ====================

  /// Get current user's profile from Firestore
  Future<Map<String, dynamic>?> getUserProfile() async {
    final User? user = _auth.currentUser;
    if (user == null) return null;

    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _firestore.collection('users').doc(user.uid).get();

    if (!doc.exists) {
      throw StateError('User profile does not exist');
    }

    final Map<String, dynamic> data = doc.data()!;

    // Parse entitlements safely
    List<Map<String, dynamic>> entitlements = <Map<String, dynamic>>[];
    try {
      final dynamic entsData = data['entitlements'];
      if (entsData is List) {
        for (final dynamic e in entsData) {
          if (e is Map<String, dynamic>) {
            entitlements.add(e);
          }
        }
      }
    } catch (e) {
      debugPrint('Warning: Failed to parse entitlements: $e');
    }

    return <String, dynamic>{
      'userId': user.uid,
      'email': data['email'] ?? user.email,
      'displayName': data['displayName'] ?? user.displayName,
      'role': data['role'] ?? 'learner',
      'activeSiteId': data['activeSiteId'] ??
          (data['siteIds'] as List<dynamic>?)?.firstOrNull,
      'siteIds': List<String>.from(data['siteIds'] ?? <dynamic>[]),
      'localeCode': _preferenceString(data, 'locale', fallback: 'en'),
      'timeZone': _preferenceString(data, 'timeZone', fallback: 'auto'),
      'notificationsEnabled':
          _preferenceBool(data, 'notificationsEnabled', fallback: true),
      'emailNotifications':
          _preferenceBool(data, 'emailNotifications', fallback: true),
      'pushNotifications':
          _preferenceBool(data, 'pushNotifications', fallback: true),
      'biometricEnabled':
          _preferenceBool(data, 'biometricEnabled', fallback: false),
      'entitlements': entitlements,
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

  String _preferenceString(
    Map<String, dynamic> data,
    String key, {
    required String fallback,
  }) {
    final dynamic rawPreferences = data['preferences'];
    final Map<String, dynamic> preferences = rawPreferences is Map
        ? rawPreferences.map((dynamic mapKey, dynamic value) =>
            MapEntry<String, dynamic>(mapKey.toString(), value))
        : <String, dynamic>{};
    final String? value = preferences[key] as String? ?? data[key] as String?;
    return (value?.trim().isNotEmpty ?? false) ? value!.trim() : fallback;
  }

  bool _preferenceBool(
    Map<String, dynamic> data,
    String key, {
    required bool fallback,
  }) {
    final dynamic rawPreferences = data['preferences'];
    final Map<String, dynamic> preferences = rawPreferences is Map
        ? rawPreferences.map((dynamic mapKey, dynamic value) =>
            MapEntry<String, dynamic>(mapKey.toString(), value))
        : <String, dynamic>{};
    return preferences[key] as bool? ?? data[key] as bool? ?? fallback;
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

  /// Delete current user's profile from Firestore
  Future<void> deleteCurrentUserProfile() async {
    final User? user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    await _firestore.collection('users').doc(user.uid).delete();
  }

  // ==================== SITE OPERATIONS ====================

  /// Get sites for current user
  Future<List<Map<String, dynamic>>> getUserSites() async {
    final User? user = _auth.currentUser;
    if (user == null) return <Map<String, dynamic>>[];

    final DocumentSnapshot<Map<String, dynamic>> userDoc =
        await _firestore.collection('users').doc(user.uid).get();

    if (!userDoc.exists) return <Map<String, dynamic>>[];

    final List<String> siteIds =
        List<String>.from(userDoc.data()?['siteIds'] ?? <dynamic>[]);
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
      'timestamp': FieldValue.serverTimestamp(),
      'recordedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Get attendance records for a session
  Future<List<Map<String, dynamic>>> getSessionAttendance(
      String sessionOccurrenceId) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('attendanceRecords')
        .where('sessionOccurrenceId', isEqualTo: sessionOccurrenceId)
        .get();

    return snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
            <String, dynamic>{
              'id': doc.id,
              ...doc.data(),
            })
        .toList();
  }

  // ==================== CHECKIN OPERATIONS ====================

  /// Record presence checkin
  Future<String> recordCheckin({
    required String siteId,
    required String learnerId,
  }) async {
    final DocumentReference<Map<String, dynamic>> docRef =
        await _firestore.collection('checkins').add(<String, dynamic>{
      'siteId': siteId,
      'learnerId': learnerId,
      'type': 'checkin',
      'status': 'completed',
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
        await _firestore.collection('checkins').add(<String, dynamic>{
      'siteId': siteId,
      'learnerId': learnerId,
      'type': 'checkout',
      'status': 'completed',
      'timestamp': FieldValue.serverTimestamp(),
      'recordedBy': _auth.currentUser?.uid,
    });
    return docRef.id;
  }

  // ==================== MISSION OPERATIONS ====================

  /// Get missions for a learner
  Future<List<Map<String, dynamic>>> getLearnerMissions(
      String learnerId) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('missionAssignments')
        .where('learnerId', isEqualTo: learnerId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
            <String, dynamic>{
              'id': doc.id,
              ...doc.data(),
            })
        .toList();
  }

  /// Submit mission attempt
  Future<String> submitMissionAttempt({
    required String missionId,
    required String learnerId,
    required String siteId,
    required Map<String, dynamic> submission,
  }) async {
    final DocumentReference<Map<String, dynamic>> docRef =
        await _firestore.collection('missionAttempts').add(<String, dynamic>{
      'missionId': missionId,
      'learnerId': learnerId,
      'siteId': siteId,
      'submission': submission,
      'status': 'submitted',
      'submittedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
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

  /// Submit an in-app support or account request.
  Future<String> submitSupportRequest({
    required String requestType,
    required String source,
    required String siteId,
    required String userId,
    required String userEmail,
    required String userName,
    required String role,
    required String subject,
    String? message,
    Map<String, dynamic>? metadata,
  }) async {
    final DocumentReference<Map<String, dynamic>> docRef =
        await _firestore.collection('supportRequests').add(<String, dynamic>{
      'requestType': requestType,
      'source': source,
      'siteId': siteId,
      'userId': userId,
      'userEmail': userEmail,
      'userName': userName,
      'role': role,
      'subject': subject,
      'message': message,
      'metadata': metadata ?? <String, dynamic>{},
      'status': 'open',
      'submittedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
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

    final DocumentSnapshot<Map<String, dynamic>> senderDoc =
        await _firestore.collection('users').doc(user.uid).get();
    final Map<String, dynamic>? senderData = senderDoc.data();
    final String senderName = senderData?['displayName'] as String? ??
        user.displayName ??
        user.email ??
        user.uid;

    final DocumentReference<Map<String, dynamic>> threadRef =
        _firestore.collection('messageThreads').doc(conversationId);
    final DocumentSnapshot<Map<String, dynamic>> threadDoc =
        await threadRef.get();
    final List<String> participantIds =
        List<String>.from(threadDoc.data()?['participantIds'] ?? <dynamic>[]);
    final List<String> participantNames =
        List<String>.from(threadDoc.data()?['participantNames'] ?? <dynamic>[]);

    if (!threadDoc.exists || !participantIds.contains(user.uid)) {
      throw Exception('Conversation does not exist or is not accessible');
    }

    await threadRef.set(<String, dynamic>{
      'participantIds': participantIds,
      'participantNames': participantNames,
      'status': 'open',
      'lastMessagePreview':
          content.length > 120 ? '${content.substring(0, 120)}...' : content,
      'lastMessageSenderId': user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final String recipientId = participantIds.firstWhere(
      (String participantId) => participantId != user.uid,
      orElse: () => user.uid,
    );

    final DocumentReference<Map<String, dynamic>> docRef =
        await _firestore.collection('messages').add(<String, dynamic>{
      'threadId': conversationId,
      'title': 'Direct message',
      'body': content,
      'type': 'direct',
      'priority': 'normal',
      'senderId': user.uid,
      'senderName': senderName,
      'recipientId': recipientId,
      'attachmentUrl': attachmentUrl,
      'isRead': false,
      'status': 'sent',
      'metadata': <String, dynamic>{'threadId': conversationId},
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Get messages for a conversation
  Stream<List<Map<String, dynamic>>> getMessages(String conversationId) {
    return _firestore
        .collection('messages')
        .where('threadId', isEqualTo: conversationId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
            .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                <String, dynamic>{
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

    return snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
            <String, dynamic>{
              'id': doc.id,
              ...doc.data(),
            })
        .toList();
  }

  /// Get session occurrences for today
  Future<List<Map<String, dynamic>>> getTodaySessionOccurrences(
      String siteId) async {
    final DateTime now = DateTime.now();
    final DateTime startOfDay = DateTime(now.year, now.month, now.day);
    final DateTime endOfDay = startOfDay.add(const Duration(days: 1));

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('sessionOccurrences')
        .where('siteId', isEqualTo: siteId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    return snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
            <String, dynamic>{
              'id': doc.id,
              ...doc.data(),
            })
        .toList();
  }

  // ==================== SKILL OPERATIONS ====================

  /// Get skills by pillar
  Future<List<Map<String, dynamic>>> getSkillsByPillar(
      String pillarCode) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('skills')
        .where('pillarCode', isEqualTo: pillarCode)
        .orderBy('name')
        .get();

    return snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
            <String, dynamic>{
              'id': doc.id,
              ...doc.data(),
            })
        .toList();
  }

  /// Get learner skill assessments
  Future<List<Map<String, dynamic>>> getLearnerSkillAssessments(
      String learnerId) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('skillAssessments')
        .where('learnerId', isEqualTo: learnerId)
        .orderBy('assessedAt', descending: true)
        .get();

    return snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
            <String, dynamic>{
              'id': doc.id,
              ...doc.data(),
            })
        .toList();
  }

  // ==================== EVIDENCE CHAIN OPERATIONS ====================

  /// Submit a checkpoint result
  Future<String> submitCheckpointResult({
    required String learnerId,
    required String missionId,
    required String siteId,
    String? sessionId,
    String? skillId,
    required String question,
    required String learnerResponse,
    required bool isCorrect,
    bool explainItBackRequired = false,
  }) async {
    final DocumentReference<Map<String, dynamic>> docRef =
        await _firestore.collection('checkpointHistory').add(<String, dynamic>{
      'learnerId': learnerId,
      'missionId': missionId,
      'siteId': siteId,
      'sessionId': sessionId,
      'skillId': skillId,
      'question': question,
      'learnerResponse': learnerResponse,
      'isCorrect': isCorrect,
      'explainItBackRequired': explainItBackRequired,
      'recordedBy': _auth.currentUser?.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // S2-2: Auto-create SkillEvidence record when checkpoint is submitted
    if (skillId != null && skillId.isNotEmpty) {
      await _firestore.collection('skillEvidence').add(<String, dynamic>{
        'learnerId': learnerId,
        'siteId': siteId,
        'microSkillId': skillId,
        'evidenceType': 'quiz',
        'description': 'Checkpoint response for mission $missionId',
        'selfScore': isCorrect ? 'proficient' : 'developing',
        'status': 'submitted',
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    return docRef.id;
  }

  /// Submit a learner reflection
  Future<String> submitReflection({
    required String learnerId,
    required String siteId,
    String? sessionId,
    String? missionId,
    required String prompt,
    required String response,
    int? engagementRating,
    int? confidenceRating,
    bool? aiAssistanceUsed,
    String? aiAssistanceDetails,
  }) async {
    final HttpsCallable callable = _functions.httpsCallable('submitReflection');
    final HttpsCallableResult<dynamic> result =
        await callable.call(<String, dynamic>{
      'learnerId': learnerId,
      'siteId': siteId,
      'sessionId': sessionId,
      'missionId': missionId,
      'prompt': prompt,
      'response': response,
      'engagementRating': engagementRating,
      'confidenceRating': confidenceRating,
      if (aiAssistanceUsed != null) 'aiAssistanceUsed': aiAssistanceUsed,
      if (aiAssistanceDetails != null && aiAssistanceDetails.trim().isNotEmpty)
        'aiAssistanceDetails': aiAssistanceDetails.trim(),
    });
    final dynamic data = result.data;
    if (data is Map && data['reflectionId'] is String) {
      return data['reflectionId'] as String;
    }
    throw StateError('submitReflection callable did not return a reflectionId');
  }

  /// Log a MiloOS interaction
  Future<String> logAICoachInteraction({
    required String learnerId,
    required String siteId,
    String? sessionId,
    required String mode,
    required String question,
    required String response,
    bool explainItBackRequired = false,
    List<String> toolsUsed = const <String>[],
    int? durationMs,
  }) async {
    final DocumentReference<Map<String, dynamic>> docRef = await _firestore
        .collection('aiCoachInteractions')
        .add(<String, dynamic>{
      'learnerId': learnerId,
      'siteId': siteId,
      'sessionId': sessionId,
      'mode': mode,
      'question': question,
      'response': response,
      'explainItBackRequired': explainItBackRequired,
      'toolsUsed': toolsUsed,
      'durationMs': durationMs,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Submit peer feedback
  Future<String> submitPeerFeedback({
    required String fromLearnerId,
    required String toLearnerId,
    required String missionAttemptId,
    required String siteId,
    String? sessionId,
    int? rating,
    String? strengths,
    String? suggestions,
  }) async {
    final DocumentReference<Map<String, dynamic>> docRef =
        await _firestore.collection('peerFeedback').add(<String, dynamic>{
      'fromLearnerId': fromLearnerId,
      'authorId': fromLearnerId,
      'toLearnerId': toLearnerId,
      'targetLearnerId': toLearnerId,
      'missionAttemptId': missionAttemptId,
      'siteId': siteId,
      'sessionId': sessionId,
      'rating': rating,
      'strengths': strengths,
      'suggestions': suggestions,
      'iLike': strengths,
      'iWonder': suggestions,
      'nextStep': null,
      'status': 'submitted',
      'flagged': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Create a proof-of-learning bundle
  Future<String> createProofOfLearningBundle({
    required String learnerId,
    required String siteId,
    required String portfolioItemId,
    String? capabilityId,
  }) async {
    final DocumentReference<Map<String, dynamic>> docRef = await _firestore
        .collection('proofOfLearningBundles')
        .add(<String, dynamic>{
      'learnerId': learnerId,
      'siteId': siteId,
      'portfolioItemId': portfolioItemId,
      'capabilityId': capabilityId,
      'hasExplainItBack': false,
      'hasOralCheck': false,
      'hasMiniRebuild': false,
      'verificationStatus': 'missing',
      'version': 1,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Update proof-of-learning bundle with verification methods
  Future<void> updateProofOfLearningBundle({
    required String bundleId,
    bool? hasExplainItBack,
    bool? hasOralCheck,
    bool? hasMiniRebuild,
    String? explainItBackExcerpt,
    String? oralCheckExcerpt,
    String? miniRebuildExcerpt,
  }) async {
    final Map<String, dynamic> updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (hasExplainItBack != null) {
      updates['hasExplainItBack'] = hasExplainItBack;
    }
    if (hasOralCheck != null) updates['hasOralCheck'] = hasOralCheck;
    if (hasMiniRebuild != null) updates['hasMiniRebuild'] = hasMiniRebuild;
    if (explainItBackExcerpt != null) {
      updates['explainItBackExcerpt'] = explainItBackExcerpt;
    }
    if (oralCheckExcerpt != null) {
      updates['oralCheckExcerpt'] = oralCheckExcerpt;
    }
    if (miniRebuildExcerpt != null) {
      updates['miniRebuildExcerpt'] = miniRebuildExcerpt;
    }

    final bool eib = hasExplainItBack ?? false;
    final bool oc = hasOralCheck ?? false;
    final bool mr = hasMiniRebuild ?? false;
    if (eib && oc && mr) {
      // Learner can only reach pending_review; educator verification is
      // server-owned through verifyProofOfLearning().
      updates['verificationStatus'] = 'pending_review';
    } else if (eib || oc || mr) {
      updates['verificationStatus'] = 'partial';
    }

    await _firestore
        .collection('proofOfLearningBundles')
        .doc(bundleId)
        .update(updates);
  }

  /// Educator verifies proof of learning through the server-owned callable.
  Future<void> verifyProofOfLearning({
    required String portfolioItemId,
    required String verificationStatus,
    required String proofOfLearningStatus,
    Map<String, dynamic> proofChecks = const <String, dynamic>{},
    Map<String, dynamic> excerpts = const <String, dynamic>{},
    String? educatorNotes,
    String? resubmissionReason,
  }) async {
    final HttpsCallable callable = _functions.httpsCallable(
      'verifyProofOfLearning',
    );
    await callable.call(<String, dynamic>{
      'portfolioItemId': portfolioItemId,
      'verificationStatus': verificationStatus,
      'proofOfLearningStatus': proofOfLearningStatus,
      'proofChecks': proofChecks,
      'excerpts': excerpts,
      if (educatorNotes != null && educatorNotes.trim().isNotEmpty)
        'educatorNotes': educatorNotes.trim(),
      if (resubmissionReason != null && resubmissionReason.trim().isNotEmpty)
        'resubmissionReason': resubmissionReason.trim(),
    });
  }

  Future<void> requestProofRevision({
    required String portfolioItemId,
    required String reason,
    Map<String, dynamic> proofChecks = const <String, dynamic>{},
    Map<String, dynamic> excerpts = const <String, dynamic>{},
  }) async {
    await verifyProofOfLearning(
      portfolioItemId: portfolioItemId,
      verificationStatus: 'pending',
      proofOfLearningStatus: 'partial',
      proofChecks: proofChecks,
      excerpts: excerpts,
      educatorNotes: reason,
      resubmissionReason: reason,
    );
  }

  /// Educator applies a rubric judgment
  Future<String> applyRubric({
    required String learnerId,
    required String capabilityId,
    required String educatorId,
    required String level,
    String? feedback,
    List<String> evidenceRefIds = const <String>[],
    required String siteId,
  }) async {
    final List<String> evidenceRecordIds = evidenceRefIds
        .map((String id) => id.trim())
        .where((String id) => id.isNotEmpty)
        .toList(growable: false);
    if (evidenceRecordIds.isEmpty) {
      throw StateError(
        'Rubric application requires evidence context; use GrowthEngineService with verified evidence.',
      );
    }

    final HttpsCallableResult<dynamic> result = await _functions
        .httpsCallable('applyRubricToEvidence')
        .call(<String, dynamic>{
      'learnerId': learnerId,
      'siteId': siteId,
      'evidenceRecordIds': evidenceRecordIds,
      'scores': <Map<String, dynamic>>[
        <String, dynamic>{
          'criterionId': 'firestore-service-rubric',
          'capabilityId': capabilityId,
          'pillarCode': 'FUTURE_SKILLS',
          'score': _scoreFromRubricLevel(level),
          'maxScore': 4,
        },
      ],
      if (feedback != null && feedback.trim().isNotEmpty) 'feedback': feedback,
    });
    final Map<dynamic, dynamic>? data = result.data is Map<dynamic, dynamic>
        ? result.data as Map<dynamic, dynamic>
        : null;
    return data?['rubricApplicationId'] as String? ?? '';
  }

  /// Update capability mastery level
  Future<void> updateCapabilityMastery({
    required String learnerId,
    required String capabilityId,
    required String newLevel,
    required String educatorId,
  }) async {
    throw StateError(
      'capabilityMastery is server-owned; use applyRubricToEvidence or processCheckpointMasteryUpdate.',
    );
  }

  /// Create an append-only capability growth event (immutable provenance)
  Future<String> createCapabilityGrowthEvent({
    required String learnerId,
    required String capabilityId,
    String? fromLevel,
    required String toLevel,
    required String educatorId,
    String? rubricApplicationId,
    List<String> evidenceIds = const <String>[],
    required String siteId,
  }) async {
    throw StateError(
      'capabilityGrowthEvents are server-owned append-only output; use applyRubricToEvidence or processCheckpointMasteryUpdate.',
    );
  }

  int _scoreFromRubricLevel(String level) {
    final int? numericScore = int.tryParse(level.trim());
    if (numericScore != null) {
      return numericScore.clamp(1, 4).toInt();
    }

    switch (level.trim().toLowerCase()) {
      case 'advanced':
        return 4;
      case 'proficient':
        return 3;
      case 'developing':
        return 2;
      case 'emerging':
      default:
        return 1;
    }
  }

  /// Get checkpoints by learner
  Future<List<Map<String, dynamic>>> getCheckpointsByLearner(
      String learnerId) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('checkpointHistory')
        .where('learnerId', isEqualTo: learnerId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
            <String, dynamic>{'id': doc.id, ...doc.data()})
        .toList();
  }

  /// Get portfolio items by learner
  Future<List<Map<String, dynamic>>> getPortfolioItemsByLearner(
      String learnerId) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('portfolioItems')
        .where('learnerId', isEqualTo: learnerId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
            <String, dynamic>{'id': doc.id, ...doc.data()})
        .toList();
  }

  /// Get proof bundles by learner
  Future<List<Map<String, dynamic>>> getProofBundlesByLearner(
      String learnerId) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('proofOfLearningBundles')
        .where('learnerId', isEqualTo: learnerId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
            <String, dynamic>{'id': doc.id, ...doc.data()})
        .toList();
  }

  /// Get evidence records by site
  Future<List<Map<String, dynamic>>> getEvidenceRecordsBySite(
      String siteId) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('evidenceRecords')
        .where('siteId', isEqualTo: siteId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
            <String, dynamic>{'id': doc.id, ...doc.data()})
        .toList();
  }

  /// Get capability mastery by learner
  Future<List<Map<String, dynamic>>> getCapabilityMasteryByLearner(
      String learnerId) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('capabilityMastery')
        .where('learnerId', isEqualTo: learnerId)
        .get();
    return snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
            <String, dynamic>{'id': doc.id, ...doc.data()})
        .toList();
  }

  /// Get growth events by learner
  Future<List<Map<String, dynamic>>> getGrowthEventsByLearner(
      String learnerId) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('capabilityGrowthEvents')
        .where('learnerId', isEqualTo: learnerId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
            <String, dynamic>{'id': doc.id, ...doc.data()})
        .toList();
  }

  // ==================== GENERIC OPERATIONS ====================

  /// Generic document get
  Future<Map<String, dynamic>?> getDocument(
      String collection, String docId) async {
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
        final String field = condition[0] as String;
        if (condition.length >= 3) {
          final String operator = condition[1] as String;
          final dynamic value = condition[2];
          switch (operator) {
            case 'arrayContains':
              query = query.where(field, arrayContains: value);
              break;
            default:
              throw ArgumentError(
                  'Unsupported Firestore query operator: $operator');
          }
        } else {
          query = query.where(field, isEqualTo: condition[1]);
        }
      }
    }

    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
    return snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
            <String, dynamic>{
              'id': doc.id,
              ...doc.data(),
            })
        .toList();
  }

  /// Generic document create
  Future<String> createDocument(
      String collection, Map<String, dynamic> data) async {
    final DocumentReference<Map<String, dynamic>> docRef =
        await _firestore.collection(collection).add(<String, dynamic>{
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Generic document update
  Future<void> updateDocument(
      String collection, String docId, Map<String, dynamic> data) async {
    await _firestore.collection(collection).doc(docId).update(<String, dynamic>{
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Generic document set
  Future<void> setDocument(
    String collection,
    String docId,
    Map<String, dynamic> data, {
    bool merge = false,
  }) async {
    await _firestore.collection(collection).doc(docId).set(
      <String, dynamic>{
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: merge),
    );
  }

  /// Generic document delete
  Future<void> deleteDocument(String collection, String docId) async {
    await _firestore.collection(collection).doc(docId).delete();
  }

  /// Get Firestore instance for direct queries
  FirebaseFirestore get firestore => _firestore;
}
