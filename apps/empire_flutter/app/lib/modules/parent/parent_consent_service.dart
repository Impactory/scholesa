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
    this.activeReportShares = const <ParentReportShareRequest>[],
  });

  final String learnerId;
  final String learnerName;
  final String? siteId;
  final MediaConsentModel? mediaConsent;
  final ResearchConsentModel? researchConsent;
  final List<ParentReportShareRequest> activeReportShares;
}

class ParentReportShareRequest {
  const ParentReportShareRequest({
    required this.id,
    required this.learnerId,
    required this.status,
    required this.reportAction,
    required this.audience,
    required this.visibility,
    required this.meetsDeliveryContract,
    required this.meetsProvenanceContract,
    this.siteId,
    this.reportDelivery,
    this.source,
    this.surface,
    this.fileName,
    this.createdAt,
    this.expiresAt,
  });

  final String id;
  final String learnerId;
  final String? siteId;
  final String status;
  final String reportAction;
  final String? reportDelivery;
  final String audience;
  final String visibility;
  final String? source;
  final String? surface;
  final String? fileName;
  final bool meetsDeliveryContract;
  final bool meetsProvenanceContract;
  final DateTime? createdAt;
  final DateTime? expiresAt;
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

    final String? siteId = _nonEmptyOrNull(
      learnerProfile['siteId'] ?? learnerData['activeSiteId'],
    );

    Query<Map<String, dynamic>> mediaQuery = _firestore
        .collection('mediaConsents')
        .where('learnerId', isEqualTo: learnerId);
    if (siteId != null) {
      mediaQuery = mediaQuery.where('siteId', isEqualTo: siteId);
    }
    final QuerySnapshot<Map<String, dynamic>> mediaSnapshot =
        await mediaQuery.limit(1).get();
    final QuerySnapshot<Map<String, dynamic>> researchSnapshot =
        await _firestore
            .collection('researchConsents')
            .where('learnerId', isEqualTo: learnerId)
            .where('parentId', isEqualTo: parentId)
            .limit(1)
            .get();
    final List<ParentReportShareRequest> activeReportShares =
        await _listActiveReportShares(learnerId: learnerId, siteId: siteId);

    return ParentConsentRecord(
      learnerId: learnerId,
      learnerName: _resolveLearnerName(
        learnerId: learnerId,
        learnerData: learnerData,
        learnerProfile: learnerProfile,
      ),
      siteId: siteId,
      mediaConsent: mediaSnapshot.docs.isEmpty
          ? null
          : MediaConsentModel.fromDoc(mediaSnapshot.docs.first),
      researchConsent: researchSnapshot.docs.isEmpty
          ? null
          : ResearchConsentModel.fromDoc(researchSnapshot.docs.first),
      activeReportShares: activeReportShares,
    );
  }

  Future<List<ParentReportShareRequest>> _listActiveReportShares(
      {required String learnerId, required String? siteId}) async {
    if ((siteId ?? '').trim().isEmpty) {
      return const <ParentReportShareRequest>[];
    }
    final QuerySnapshot<Map<String, dynamic>> sharesSnapshot = await _firestore
        .collection('reportShareRequests')
        .where('learnerId', isEqualTo: learnerId)
        .where('siteId', isEqualTo: siteId!.trim())
        .get();
    final List<ParentReportShareRequest> shares = sharesSnapshot.docs
        .map(_buildReportShareRequest)
        .where((ParentReportShareRequest share) => share.status == 'active')
        .toList(growable: false);
    shares.sort((ParentReportShareRequest a, ParentReportShareRequest b) {
      final DateTime left =
          a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime right =
          b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return right.compareTo(left);
    });
    return shares;
  }

  ParentReportShareRequest _buildReportShareRequest(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();
    final Map<String, dynamic> provenance =
        data['provenance'] is Map<String, dynamic>
            ? data['provenance'] as Map<String, dynamic>
            : const <String, dynamic>{};
    return ParentReportShareRequest(
      id: _nonEmptyOrNull(data['id']) ?? doc.id,
      learnerId: _nonEmptyOrNull(data['learnerId']) ?? '',
      siteId: _nonEmptyOrNull(data['siteId']),
      status: _nonEmptyOrNull(data['status']) ?? 'unknown',
      reportAction: _nonEmptyOrNull(data['reportAction']) ?? 'unknown',
      reportDelivery: _nonEmptyOrNull(data['reportDelivery']),
      audience: _nonEmptyOrNull(data['audience']) ?? 'unknown',
      visibility: _nonEmptyOrNull(data['visibility']) ?? 'unknown',
      source: _nonEmptyOrNull(data['source']),
      surface: _nonEmptyOrNull(data['surface']),
      fileName: _nonEmptyOrNull(data['fileName']),
      meetsDeliveryContract: provenance['meetsDeliveryContract'] == true,
      meetsProvenanceContract: provenance['meetsProvenanceContract'] == true,
      createdAt: _dateTimeOrNull(data['createdAt']),
      expiresAt: _dateTimeOrNull(data['expiresAt']),
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

  DateTime? _dateTimeOrNull(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }
}
