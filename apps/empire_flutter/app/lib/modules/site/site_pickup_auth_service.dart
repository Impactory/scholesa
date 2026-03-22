import 'package:cloud_firestore/cloud_firestore.dart';

import '../../modules/checkin/checkin_models.dart';

const String kPickupAuthorizationFallbackSource = 'guardian_links_fallback';

class SitePickupAuthorizationRecord {
  const SitePickupAuthorizationRecord({
    required this.id,
    required this.siteId,
    required this.learnerId,
    required this.learnerName,
    required this.pickups,
    required this.updatedBy,
    required this.source,
    this.updatedAt,
  });

  final String id;
  final String siteId;
  final String learnerId;
  final String learnerName;
  final List<AuthorizedPickup> pickups;
  final String updatedBy;
  final String source;
  final DateTime? updatedAt;

  bool get isFallback => source == kPickupAuthorizationFallbackSource;
}

class SitePickupAuthorizationLearnerOption {
  const SitePickupAuthorizationLearnerOption({
    required this.learnerId,
    required this.learnerName,
  });

  final String learnerId;
  final String learnerName;
}

class SitePickupAuthorizationService {
  SitePickupAuthorizationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<SitePickupAuthorizationLearnerOption>> listLearners(
    String siteId,
  ) async {
    final List<QuerySnapshot<Map<String, dynamic>>> snapshots =
        await Future.wait(<Future<QuerySnapshot<Map<String, dynamic>>>>[
      _firestore
          .collection('learnerProfiles')
          .where('siteId', isEqualTo: siteId)
          .get(),
      _firestore
          .collection('pickupAuthorizations')
          .where('siteId', isEqualTo: siteId)
          .get(),
      _firestore
          .collection('guardianLinks')
          .where('siteId', isEqualTo: siteId)
          .get(),
    ]);
    final QuerySnapshot<Map<String, dynamic>> learnerProfiles = snapshots[0];
    final QuerySnapshot<Map<String, dynamic>> explicitAuthorizations =
        snapshots[1];
    final QuerySnapshot<Map<String, dynamic>> guardianLinks = snapshots[2];

    final Map<String, String> learnerNames =
        _buildLearnerNamesFromProfiles(learnerProfiles.docs);
    final Set<String> learnerIds = <String>{
      ...learnerNames.keys,
      ...explicitAuthorizations.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              _optionalString(doc.data()['learnerId']))
          .whereType<String>(),
      ...guardianLinks.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              _optionalString(doc.data()['learnerId']))
          .whereType<String>(),
    };
    final Map<String, String> userNames =
        await _loadUserDisplayNames(learnerIds);

    final List<SitePickupAuthorizationLearnerOption> learners = learnerIds
        .map(
          (String learnerId) => SitePickupAuthorizationLearnerOption(
            learnerId: learnerId,
            learnerName: _nonEmptyOrFallback(
              learnerNames[learnerId] ?? userNames[learnerId],
              learnerId,
            ),
          ),
        )
        .toList(growable: false);
    learners.sort(
      (
        SitePickupAuthorizationLearnerOption a,
        SitePickupAuthorizationLearnerOption b,
      ) =>
          a.learnerName.toLowerCase().compareTo(b.learnerName.toLowerCase()),
    );
    return learners;
  }

  Future<List<SitePickupAuthorizationRecord>> listRecords(String siteId) async {
    final List<QuerySnapshot<Map<String, dynamic>>> snapshots =
        await Future.wait(<Future<QuerySnapshot<Map<String, dynamic>>>>[
      _firestore
          .collection('pickupAuthorizations')
          .where('siteId', isEqualTo: siteId)
          .get(),
      _firestore
          .collection('guardianLinks')
          .where('siteId', isEqualTo: siteId)
          .get(),
      _firestore
          .collection('learnerProfiles')
          .where('siteId', isEqualTo: siteId)
          .get(),
    ]);

    final QuerySnapshot<Map<String, dynamic>> explicitSnapshot = snapshots[0];
    final QuerySnapshot<Map<String, dynamic>> guardianLinksSnapshot =
        snapshots[1];
    final QuerySnapshot<Map<String, dynamic>> learnerProfilesSnapshot =
        snapshots[2];

    final Map<String, String> learnerNames =
        _buildLearnerNamesFromProfiles(learnerProfilesSnapshot.docs);
    final Set<String> learnerIds = <String>{
      ...learnerNames.keys,
      ...explicitSnapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              _optionalString(doc.data()['learnerId']))
          .whereType<String>(),
      ...guardianLinksSnapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              _optionalString(doc.data()['learnerId']))
          .whereType<String>(),
    };
    final Map<String, String> learnerUserNames =
        await _loadUserDisplayNames(learnerIds);

    final List<SitePickupAuthorizationRecord> records =
        <SitePickupAuthorizationRecord>[];
    final Set<String> learnersWithExplicitAuth = <String>{};

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in explicitSnapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      final String learnerId = _optionalString(data['learnerId']) ?? '';
      if (learnerId.isEmpty) {
        continue;
      }
      final List<dynamic> rawPickups =
          data['authorizedPickup'] as List<dynamic>? ?? const <dynamic>[];
      final List<AuthorizedPickup> pickups = <AuthorizedPickup>[];
      for (int index = 0; index < rawPickups.length; index += 1) {
        final dynamic entry = rawPickups[index];
        if (entry is! Map) {
          continue;
        }
        pickups.add(
          _authorizedPickupFromMap(
            raw: Map<String, dynamic>.from(entry),
            learnerId: learnerId,
            fallbackId: '${doc.id}-$index',
          ),
        );
      }
      if (pickups.isEmpty) {
        continue;
      }
      learnersWithExplicitAuth.add(learnerId);
      records.add(
        SitePickupAuthorizationRecord(
          id: doc.id,
          siteId: siteId,
          learnerId: learnerId,
          learnerName: _nonEmptyOrFallback(
            learnerNames[learnerId] ?? learnerUserNames[learnerId],
            learnerId,
          ),
          pickups: pickups,
          updatedBy: _optionalString(data['updatedBy']) ?? '',
          source: 'explicit',
          updatedAt: _parseTimestamp(data['updatedAt']) ??
              _parseTimestamp(data['createdAt']),
        ),
      );
    }

    final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
        guardianLinksByLearner =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    final Set<String> parentIds = <String>{};
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in guardianLinksSnapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      final String learnerId = _optionalString(data['learnerId']) ?? '';
      final String parentId = _optionalString(data['parentId']) ?? '';
      if (learnerId.isEmpty ||
          parentId.isEmpty ||
          learnersWithExplicitAuth.contains(learnerId)) {
        continue;
      }
      guardianLinksByLearner
          .putIfAbsent(
            learnerId,
            () => <QueryDocumentSnapshot<Map<String, dynamic>>>[],
          )
          .add(doc);
      parentIds.add(parentId);
    }

    final Map<String, Map<String, dynamic>> parentProfiles =
        await _loadParentProfiles(parentIds);
    final Map<String, String> parentNames =
        await _loadUserDisplayNames(parentIds);

    guardianLinksByLearner.forEach((
      String learnerId,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> links,
    ) {
      final List<AuthorizedPickup> pickups = links.asMap().entries.map(
          (MapEntry<int, QueryDocumentSnapshot<Map<String, dynamic>>> entry) {
        final Map<String, dynamic> data = entry.value.data();
        final String parentId = _optionalString(data['parentId']) ?? '';
        final Map<String, dynamic> parentProfile =
            parentProfiles[parentId] ?? const <String, dynamic>{};
        return _authorizedPickupFromMap(
          raw: <String, dynamic>{
            'id': entry.value.id,
            'name': _nonEmptyOrFallback(
              _optionalString(parentProfile['preferredName']) ??
                  _optionalString(parentProfile['legalName']) ??
                  parentNames[parentId],
              parentId,
            ),
            'phone': parentProfile['phone'],
            'email': parentProfile['email'],
            'relationship': data['relationship'],
            'isPrimary': data['isPrimary'],
          },
          learnerId: learnerId,
          fallbackId: '${entry.value.id}-${entry.key}',
          fallbackPrimary: data['isPrimary'] == true,
        );
      }).toList(growable: false);
      if (pickups.isEmpty) {
        return;
      }
      final DateTime? updatedAt = links
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                _parseTimestamp(doc.data()['updatedAt']) ??
                _parseTimestamp(doc.data()['createdAt']),
          )
          .whereType<DateTime>()
          .fold<DateTime?>(
            null,
            (DateTime? current, DateTime next) =>
                current == null || next.isAfter(current) ? next : current,
          );
      records.add(
        SitePickupAuthorizationRecord(
          id: 'guardian-links-$learnerId',
          siteId: siteId,
          learnerId: learnerId,
          learnerName: _nonEmptyOrFallback(
            learnerNames[learnerId] ?? learnerUserNames[learnerId],
            learnerId,
          ),
          pickups: pickups,
          updatedBy: '',
          source: kPickupAuthorizationFallbackSource,
          updatedAt: updatedAt,
        ),
      );
    });

    records.sort(
        (SitePickupAuthorizationRecord a, SitePickupAuthorizationRecord b) {
      if (a.isFallback != b.isFallback) {
        return a.isFallback ? 1 : -1;
      }
      final int updatedAtComparison = (b.updatedAt?.millisecondsSinceEpoch ?? 0)
          .compareTo(a.updatedAt?.millisecondsSinceEpoch ?? 0);
      if (updatedAtComparison != 0) {
        return updatedAtComparison;
      }
      return a.learnerName.toLowerCase().compareTo(b.learnerName.toLowerCase());
    });
    return records;
  }

  Future<void> saveAuthorization({
    required String siteId,
    required String learnerId,
    required List<AuthorizedPickup> pickups,
    required String updatedBy,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> existingSnapshot =
        await _firestore
            .collection('pickupAuthorizations')
            .where('siteId', isEqualTo: siteId)
            .where('learnerId', isEqualTo: learnerId)
            .limit(1)
            .get();
    final DocumentReference<Map<String, dynamic>> docRef =
        existingSnapshot.docs.isNotEmpty
            ? existingSnapshot.docs.first.reference
            : _firestore.collection('pickupAuthorizations').doc();
    final Timestamp now = Timestamp.now();
    await docRef.set(<String, dynamic>{
      'siteId': siteId,
      'learnerId': learnerId,
      'authorizedPickup': pickups
          .map((AuthorizedPickup pickup) => _authorizedPickupToMap(pickup))
          .toList(growable: false),
      'updatedBy': updatedBy,
      'createdAt': existingSnapshot.docs.isNotEmpty
          ? existingSnapshot.docs.first.data()['createdAt'] ?? now
          : now,
      'updatedAt': now,
    }, SetOptions(merge: true));
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
          (String parentId) =>
              _firestore.collection('parentProfiles').doc(parentId).get(),
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

  AuthorizedPickup _authorizedPickupFromMap({
    required Map<String, dynamic> raw,
    required String learnerId,
    required String fallbackId,
    bool fallbackPrimary = false,
  }) {
    return AuthorizedPickup(
      id: _optionalString(raw['id']) ?? fallbackId,
      learnerId: learnerId,
      name: _nonEmptyOrFallback(
        _optionalString(raw['name']),
        fallbackId,
      ),
      phone: _optionalString(raw['phone']),
      email: _optionalString(raw['email']),
      relationship: _optionalString(raw['relationship']) ?? 'Authorized pickup',
      photoUrl: _optionalString(raw['photoUrl']),
      isPrimaryContact: raw['isPrimaryContact'] == true ||
          raw['isPrimary'] == true ||
          fallbackPrimary,
      expiresAt: _parseTimestamp(raw['expiresAt']),
      verificationCode: _extractVerificationCode(raw),
    );
  }

  Map<String, dynamic> _authorizedPickupToMap(AuthorizedPickup pickup) {
    return <String, dynamic>{
      'id': pickup.id,
      'name': pickup.name,
      if (pickup.phone != null) 'phone': pickup.phone,
      if (pickup.email != null) 'email': pickup.email,
      'relationship': pickup.relationship,
      if (pickup.photoUrl != null) 'photoUrl': pickup.photoUrl,
      'isPrimaryContact': pickup.isPrimaryContact,
      if (pickup.expiresAt != null)
        'expiresAt': Timestamp.fromDate(pickup.expiresAt!),
      if (pickup.verificationCode != null)
        'verificationCode': pickup.verificationCode,
    };
  }

  String? _extractVerificationCode(Map<String, dynamic> data) {
    for (final String key in const <String>[
      'verificationCode',
      'pickupCode',
      'code',
      'qrCode',
      'qrValue',
      'token',
    ]) {
      final String? value = _optionalString(data[key]);
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }

  String _nonEmptyOrFallback(String? value, String fallback) {
    final String trimmed = (value ?? '').trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  String? _optionalString(dynamic value) {
    final String trimmed = value?.toString().trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
