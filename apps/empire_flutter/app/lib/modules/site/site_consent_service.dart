import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models.dart';

class SiteConsentGuardianOption {
  const SiteConsentGuardianOption({
    required this.parentId,
    required this.parentName,
  });

  final String parentId;
  final String parentName;
}

class SiteConsentRecord {
  const SiteConsentRecord({
    required this.learnerId,
    required this.learnerName,
    required this.guardians,
    this.mediaConsent,
    this.researchConsent,
    this.researchParentName,
  });

  final String learnerId;
  final String learnerName;
  final List<SiteConsentGuardianOption> guardians;
  final MediaConsentModel? mediaConsent;
  final ResearchConsentModel? researchConsent;
  final String? researchParentName;
}

class SiteConsentService {
  SiteConsentService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<SiteConsentRecord>> listRecords(String siteId) async {
    final List<QuerySnapshot<Map<String, dynamic>>> snapshots =
        await Future.wait(<Future<QuerySnapshot<Map<String, dynamic>>>>[
      _firestore.collection('learnerProfiles').where('siteId', isEqualTo: siteId).get(),
      _firestore.collection('mediaConsents').where('siteId', isEqualTo: siteId).get(),
      _firestore.collection('researchConsents').where('siteId', isEqualTo: siteId).get(),
      _firestore.collection('guardianLinks').where('siteId', isEqualTo: siteId).get(),
    ]);

    final QuerySnapshot<Map<String, dynamic>> learnerProfilesSnapshot = snapshots[0];
    final QuerySnapshot<Map<String, dynamic>> mediaConsentsSnapshot = snapshots[1];
    final QuerySnapshot<Map<String, dynamic>> researchConsentsSnapshot = snapshots[2];
    final QuerySnapshot<Map<String, dynamic>> guardianLinksSnapshot = snapshots[3];

    final Map<String, String> learnerNames =
        _buildLearnerNamesFromProfiles(learnerProfilesSnapshot.docs);
    final Set<String> learnerIds = <String>{
      ...learnerNames.keys,
      ...mediaConsentsSnapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => _optionalString(doc.data()['learnerId']))
          .whereType<String>(),
      ...researchConsentsSnapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => _optionalString(doc.data()['learnerId']))
          .whereType<String>(),
      ...guardianLinksSnapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => _optionalString(doc.data()['learnerId']))
          .whereType<String>(),
    };

    final Map<String, String> learnerUserNames =
        await _loadUserDisplayNames(learnerIds);

    final Map<String, MediaConsentModel> mediaByLearner =
        <String, MediaConsentModel>{};
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in mediaConsentsSnapshot.docs) {
      final MediaConsentModel model = MediaConsentModel.fromDoc(doc);
      if (model.learnerId.trim().isNotEmpty) {
        mediaByLearner[model.learnerId.trim()] = model;
      }
    }

    final Map<String, ResearchConsentModel> researchByLearner =
        <String, ResearchConsentModel>{};
    final Set<String> parentIds = <String>{};
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in researchConsentsSnapshot.docs) {
      final ResearchConsentModel model = ResearchConsentModel.fromDoc(doc);
      if (model.learnerId.trim().isNotEmpty) {
        researchByLearner[model.learnerId.trim()] = model;
      }
      if (model.parentId.trim().isNotEmpty) {
        parentIds.add(model.parentId.trim());
      }
    }

    final Map<String, List<String>> parentIdsByLearner = <String, List<String>>{};
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in guardianLinksSnapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      final String learnerId = _optionalString(data['learnerId']) ?? '';
      final String parentId = _optionalString(data['parentId']) ?? '';
      if (learnerId.isEmpty || parentId.isEmpty) {
        continue;
      }
      parentIdsByLearner
          .putIfAbsent(learnerId, () => <String>[])
          .add(parentId);
      parentIds.add(parentId);
    }

    final Map<String, Map<String, dynamic>> parentProfiles =
        await _loadParentProfiles(parentIds);
    final Map<String, String> parentNames = await _loadUserDisplayNames(parentIds);

    final List<SiteConsentRecord> records = learnerIds.map((String learnerId) {
      final ResearchConsentModel? researchConsent = researchByLearner[learnerId];
      final List<SiteConsentGuardianOption> guardians =
          (parentIdsByLearner[learnerId] ?? const <String>[])
              .map(
                (String parentId) => SiteConsentGuardianOption(
                  parentId: parentId,
                  parentName: _resolveParentName(
                    parentId: parentId,
                    parentProfiles: parentProfiles,
                    userDisplayNames: parentNames,
                  ),
                ),
              )
              .toList(growable: false);
      return SiteConsentRecord(
        learnerId: learnerId,
        learnerName: _nonEmptyOrFallback(
          learnerNames[learnerId] ?? learnerUserNames[learnerId],
          learnerId,
        ),
        guardians: guardians,
        mediaConsent: mediaByLearner[learnerId],
        researchConsent: researchConsent,
        researchParentName: researchConsent == null
            ? null
            : _resolveParentName(
                parentId: researchConsent.parentId,
                parentProfiles: parentProfiles,
                userDisplayNames: parentNames,
              ),
      );
    }).toList(growable: false);

    records.sort(
      (SiteConsentRecord a, SiteConsentRecord b) =>
          a.learnerName.toLowerCase().compareTo(b.learnerName.toLowerCase()),
    );
    return records;
  }

  Future<void> saveMediaConsent({
    required String siteId,
    required String learnerId,
    required String actorId,
    required String actorRole,
    required bool photoCaptureAllowed,
    required bool shareWithLinkedParents,
    required bool marketingUseAllowed,
    required String consentStatus,
    String? consentStartDate,
    String? consentEndDate,
    String? consentDocumentUrl,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> existingSnapshot = await _firestore
        .collection('mediaConsents')
        .where('siteId', isEqualTo: siteId)
        .where('learnerId', isEqualTo: learnerId)
        .limit(1)
        .get();
    final DocumentReference<Map<String, dynamic>> docRef =
        existingSnapshot.docs.isNotEmpty
            ? existingSnapshot.docs.first.reference
            : _firestore.collection('mediaConsents').doc();
    final Timestamp now = Timestamp.now();
    final Map<String, dynamic> payload = <String, dynamic>{
      'siteId': siteId,
      'learnerId': learnerId,
      'photoCaptureAllowed': photoCaptureAllowed,
      'shareWithLinkedParents': shareWithLinkedParents,
      'marketingUseAllowed': marketingUseAllowed,
      'consentStatus': consentStatus,
      'createdAt':
          existingSnapshot.docs.isNotEmpty ? existingSnapshot.docs.first.data()['createdAt'] ?? now : now,
      'updatedAt': now,
      'consentStartDate': _nullableString(consentStartDate),
      'consentEndDate': _nullableString(consentEndDate),
      'consentDocumentUrl': _nullableString(consentDocumentUrl),
    };
    await docRef.set(payload, SetOptions(merge: true));
    await _writeAuditLog(
      siteId: siteId,
      actorId: actorId,
      actorRole: actorRole,
      action: 'consent.media.updated',
      entityType: 'mediaConsent',
      entityId: docRef.id,
      details: <String, dynamic>{
        'learnerId': learnerId,
        'photoCaptureAllowed': photoCaptureAllowed,
        'shareWithLinkedParents': shareWithLinkedParents,
        'marketingUseAllowed': marketingUseAllowed,
        'consentStatus': consentStatus,
      },
    );
  }

  Future<void> saveResearchConsent({
    required String siteId,
    required String learnerId,
    required String parentId,
    required String actorId,
    required String actorRole,
    required bool consentGiven,
    required String dataShareScope,
    String? consentDocumentUrl,
    String? consentVersion,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> existingSnapshot = await _firestore
        .collection('researchConsents')
        .where('siteId', isEqualTo: siteId)
        .where('learnerId', isEqualTo: learnerId)
        .limit(1)
        .get();
    final DocumentReference<Map<String, dynamic>> docRef =
        existingSnapshot.docs.isNotEmpty
            ? existingSnapshot.docs.first.reference
            : _firestore.collection('researchConsents').doc();
    final Timestamp now = Timestamp.now();
    final Map<String, dynamic> payload = <String, dynamic>{
      'siteId': siteId,
      'learnerId': learnerId,
      'parentId': parentId,
      'consentGiven': consentGiven,
      'dataShareScope': dataShareScope,
      'createdAt':
          existingSnapshot.docs.isNotEmpty ? existingSnapshot.docs.first.data()['createdAt'] ?? now : now,
      'updatedAt': now,
      'consentDocumentUrl': _nullableString(consentDocumentUrl),
      'consentVersion': _nullableString(consentVersion),
      'revokedAt': consentGiven ? FieldValue.delete() : now,
    };
    await docRef.set(payload, SetOptions(merge: true));
    await _writeAuditLog(
      siteId: siteId,
      actorId: actorId,
      actorRole: actorRole,
      action: 'consent.research.updated',
      entityType: 'researchConsent',
      entityId: docRef.id,
      details: <String, dynamic>{
        'learnerId': learnerId,
        'parentId': parentId,
        'consentGiven': consentGiven,
        'dataShareScope': dataShareScope,
      },
    );
  }

  Future<void> _writeAuditLog({
    required String siteId,
    required String actorId,
    required String actorRole,
    required String action,
    required String entityType,
    required String entityId,
    required Map<String, dynamic> details,
  }) {
    return _firestore.collection('auditLogs').add(<String, dynamic>{
      'siteId': siteId,
      'actorId': actorId,
      'actorRole': actorRole,
      'action': action,
      'entityType': entityType,
      'entityId': entityId,
      'details': details,
      'createdAt': Timestamp.now(),
    });
  }

  Map<String, String> _buildLearnerNamesFromProfiles(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final Map<String, String> names = <String, String>{};
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
      final Map<String, dynamic> data = doc.data();
      final String learnerId = _optionalString(data['learnerId']) ?? '';
      if (learnerId.isEmpty) {
        continue;
      }
      names[learnerId] = _nonEmptyOrFallback(
        _optionalString(data['preferredName']) ??
            _optionalString(data['legalName']) ??
            _optionalString(data['displayName']),
        learnerId,
      );
    }
    return names;
  }

  Future<Map<String, Map<String, dynamic>>> _loadParentProfiles(
    Set<String> parentIds,
  ) async {
    if (parentIds.isEmpty) {
      return <String, Map<String, dynamic>>{};
    }
    final List<Future<DocumentSnapshot<Map<String, dynamic>>>> reads = parentIds
        .map(
          (String parentId) => _firestore.collection('parentProfiles').doc(parentId).get(),
        )
        .toList(growable: false);
    final List<DocumentSnapshot<Map<String, dynamic>>> snapshots =
        await Future.wait(reads);
    final Map<String, Map<String, dynamic>> profiles =
        <String, Map<String, dynamic>>{};
    for (final DocumentSnapshot<Map<String, dynamic>> snapshot in snapshots) {
      final Map<String, dynamic>? data = snapshot.data();
      if (data == null) {
        continue;
      }
      profiles[snapshot.id] = data;
    }
    return profiles;
  }

  Future<Map<String, String>> _loadUserDisplayNames(Set<String> userIds) async {
    if (userIds.isEmpty) {
      return <String, String>{};
    }
    final List<Future<DocumentSnapshot<Map<String, dynamic>>>> reads = userIds
        .map((String id) => _firestore.collection('users').doc(id).get())
        .toList(growable: false);
    final List<DocumentSnapshot<Map<String, dynamic>>> snapshots =
        await Future.wait(reads);
    final Map<String, String> names = <String, String>{};
    for (final DocumentSnapshot<Map<String, dynamic>> snapshot in snapshots) {
      final Map<String, dynamic>? data = snapshot.data();
      if (data == null) {
        continue;
      }
      names[snapshot.id] = _nonEmptyOrFallback(
        _optionalString(data['displayName']) ?? _optionalString(data['email']),
        snapshot.id,
      );
    }
    return names;
  }

  String _resolveParentName({
    required String parentId,
    required Map<String, Map<String, dynamic>> parentProfiles,
    required Map<String, String> userDisplayNames,
  }) {
    final Map<String, dynamic> parentProfile =
        parentProfiles[parentId] ?? const <String, dynamic>{};
    return _nonEmptyOrFallback(
      _optionalString(parentProfile['preferredName']) ??
          _optionalString(parentProfile['legalName']) ??
          _optionalString(parentProfile['displayName']) ??
          userDisplayNames[parentId],
      parentId,
    );
  }

  String? _optionalString(dynamic value) {
    final String trimmed = value?.toString().trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _nullableString(String? value) {
    final String trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  String _nonEmptyOrFallback(String? value, String fallback) {
    final String trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? fallback : trimmed;
  }
}
