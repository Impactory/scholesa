import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models.dart';

const String _parentConsentFallbackLearnerName = 'Learner unavailable';

class ParentConsentRecord {
  const ParentConsentRecord({
    required this.learnerId,
    required this.learnerName,
    this.siteId,
    this.mediaConsent,
    this.researchConsent,
  });

  final String learnerId;
  final String learnerName;
  final String? siteId;
  final MediaConsentModel? mediaConsent;
  final ResearchConsentModel? researchConsent;
}

class ParentConsentService {
  ParentConsentService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<ParentConsentRecord>> listRecords(String parentId) async {
    final List<String> learnerIds = await _resolveLinkedLearnerIds(parentId);
    if (learnerIds.isEmpty) {
      return const <ParentConsentRecord>[];
    }

    final List<ParentConsentRecord> records = <ParentConsentRecord>[];
    for (final String learnerId in learnerIds) {
      final ParentConsentRecord? record =
          await _buildConsentRecord(parentId: parentId, learnerId: learnerId);
      if (record != null) {
        records.add(record);
      }
    }

    records.sort(
      (ParentConsentRecord a, ParentConsentRecord b) =>
          a.learnerName.toLowerCase().compareTo(b.learnerName.toLowerCase()),
    );
    return records;
  }

  Future<ParentConsentRecord?> _buildConsentRecord({
    required String parentId,
    required String learnerId,
  }) async {
    final DocumentSnapshot<Map<String, dynamic>> learnerSnapshot =
        await _firestore.collection('users').doc(learnerId).get();
    if (!learnerSnapshot.exists) {
      return null;
    }

    final Map<String, dynamic> learnerData =
        learnerSnapshot.data() ?? const <String, dynamic>{};
    final String role = _normalizedRole(learnerData['role']);
    if (role.isNotEmpty && role != 'learner') {
      return null;
    }

    final QuerySnapshot<Map<String, dynamic>> learnerProfilesSnapshot =
        await _firestore
            .collection('learnerProfiles')
            .where('learnerId', isEqualTo: learnerId)
            .limit(1)
            .get();
    final Map<String, dynamic> learnerProfile =
        learnerProfilesSnapshot.docs.isEmpty
            ? const <String, dynamic>{}
            : learnerProfilesSnapshot.docs.first.data();

    final QuerySnapshot<Map<String, dynamic>> mediaSnapshot = await _firestore
        .collection('mediaConsents')
        .where('learnerId', isEqualTo: learnerId)
        .limit(1)
        .get();
    final QuerySnapshot<Map<String, dynamic>> researchSnapshot =
        await _firestore
            .collection('researchConsents')
            .where('learnerId', isEqualTo: learnerId)
            .where('parentId', isEqualTo: parentId)
            .limit(1)
            .get();

    return ParentConsentRecord(
      learnerId: learnerId,
      learnerName: _resolveLearnerName(
        learnerId: learnerId,
        learnerData: learnerData,
        learnerProfile: learnerProfile,
      ),
      siteId: _nonEmptyOrNull(
        learnerProfile['siteId'] ?? learnerData['activeSiteId'],
      ),
      mediaConsent: mediaSnapshot.docs.isEmpty
          ? null
          : MediaConsentModel.fromDoc(mediaSnapshot.docs.first),
      researchConsent: researchSnapshot.docs.isEmpty
          ? null
          : ResearchConsentModel.fromDoc(researchSnapshot.docs.first),
    );
  }

  Future<List<String>> _resolveLinkedLearnerIds(String parentId) async {
    final Set<String> learnerIds = <String>{};

    final QuerySnapshot<Map<String, dynamic>> links = await _firestore
        .collection('guardianLinks')
        .where('parentId', isEqualTo: parentId)
        .get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in links.docs) {
      final String learnerId = _nonEmptyOrNull(doc.data()['learnerId']) ?? '';
      if (learnerId.isNotEmpty) {
        learnerIds.add(learnerId);
      }
    }

    final DocumentSnapshot<Map<String, dynamic>> parentSnapshot =
        await _firestore.collection('users').doc(parentId).get();
    final List<dynamic> parentLearners =
        parentSnapshot.data()?['learnerIds'] as List<dynamic>? ?? <dynamic>[];
    for (final dynamic value in parentLearners) {
      final String learnerId = _nonEmptyOrNull(value) ?? '';
      if (learnerId.isNotEmpty) {
        learnerIds.add(learnerId);
      }
    }

    final QuerySnapshot<Map<String, dynamic>> userFallbackSnapshot =
        await _firestore
            .collection('users')
            .where('parentIds', arrayContains: parentId)
            .get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in userFallbackSnapshot.docs) {
      if (_normalizedRole(doc.data()['role']) == 'learner') {
        learnerIds.add(doc.id);
      }
    }

    return learnerIds.toList(growable: false);
  }

  String _resolveLearnerName({
    required String learnerId,
    required Map<String, dynamic> learnerData,
    required Map<String, dynamic> learnerProfile,
  }) {
    return _nonEmptyOrNull(
          learnerProfile['preferredName'] ??
              learnerProfile['legalName'] ??
              learnerData['displayName'] ??
              learnerData['email'],
        ) ??
        _parentConsentFallbackLearnerName;
  }

  String _normalizedRole(dynamic value) {
    final String normalized = value?.toString().trim().toLowerCase() ?? '';
    if (normalized == 'student') {
      return 'learner';
    }
    return normalized;
  }

  String? _nonEmptyOrNull(dynamic value) {
    final String normalized = value?.toString().trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
