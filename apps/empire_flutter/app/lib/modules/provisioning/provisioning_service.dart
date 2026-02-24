import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../services/api_client.dart';
import 'provisioning_models.dart';

/// Service for user provisioning operations
class ProvisioningService extends ChangeNotifier {
  ProvisioningService({
    required ApiClient apiClient,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _apiClient = apiClient,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;
  final ApiClient _apiClient;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  List<LearnerProfile> _learners = <LearnerProfile>[];
  List<ParentProfile> _parents = <ParentProfile>[];
  List<GuardianLink> _guardianLinks = <GuardianLink>[];
  bool _isLoading = false;
  String? _error;

  List<LearnerProfile> get learners => _learners;
  List<ParentProfile> get parents => _parents;
  List<GuardianLink> get guardianLinks => _guardianLinks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load learners for site
  Future<void> loadLearners(String siteId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final Map<String, dynamic> response =
          await _apiClient.get('/v1/sites/$siteId/learners');
      final List<dynamic> items = response['items'] as List? ?? <dynamic>[];
      _learners = items
          .map((e) => LearnerProfile.fromJson(e as Map<String, dynamic>))
          .toList();
      if (_learners.isEmpty) {
        await _loadLearnersFromFirestore(siteId);
      }
    } catch (e) {
      debugPrint('Failed to load learners via API, falling back: $e');
      try {
        await _loadLearnersFromFirestore(siteId);
      } catch (fallbackError) {
        _error = 'Failed to load learners: $fallbackError';
        debugPrint(_error);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load parents for site
  Future<void> loadParents(String siteId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final Map<String, dynamic> response =
          await _apiClient.get('/v1/sites/$siteId/parents');
      final List<dynamic> items = response['items'] as List? ?? <dynamic>[];
      _parents = items
          .map((e) => ParentProfile.fromJson(e as Map<String, dynamic>))
          .toList();
      if (_parents.isEmpty) {
        await _loadParentsFromFirestore(siteId);
      }
    } catch (e) {
      debugPrint('Failed to load parents via API, falling back: $e');
      try {
        await _loadParentsFromFirestore(siteId);
      } catch (fallbackError) {
        _error = 'Failed to load parents: $fallbackError';
        debugPrint(_error);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load guardian links for site
  Future<void> loadGuardianLinks(String siteId) async {
    try {
      final Map<String, dynamic> response = await _apiClient
          .get('/v1/guardian-links', queryParams: <String, String>{
        'siteId': siteId,
      });
      final List<dynamic> items = response['items'] as List? ?? <dynamic>[];
      _guardianLinks = items
          .map((e) => GuardianLink.fromJson(e as Map<String, dynamic>))
          .toList();
      if (_guardianLinks.isEmpty) {
        await _loadGuardianLinksFromFirestore(siteId);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load guardian links via API, falling back: $e');
      try {
        await _loadGuardianLinksFromFirestore(siteId);
        notifyListeners();
      } catch (fallbackError) {
        debugPrint('Failed to load guardian links: $fallbackError');
      }
    }
  }

  /// Create learner profile
  Future<LearnerProfile?> createLearner({
    required String siteId,
    required String email,
    required String displayName,
    int? gradeLevel,
    DateTime? dateOfBirth,
    String? notes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final Map<String, dynamic> response = await _apiClient.post(
        '/v1/sites/$siteId/learners',
        body: <String, dynamic>{
          'email': email,
          'displayName': displayName,
          if (gradeLevel != null) 'gradeLevel': gradeLevel,
          if (dateOfBirth != null)
            'dateOfBirth': dateOfBirth.millisecondsSinceEpoch,
          if (notes != null) 'notes': notes,
        },
      );

      final LearnerProfile learner = LearnerProfile.fromJson(response);
      _learners.add(learner);
      notifyListeners();
      return learner;
    } catch (e) {
      _error = 'Failed to create learner: $e';
      debugPrint(_error);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create parent profile
  Future<ParentProfile?> createParent({
    required String siteId,
    required String email,
    required String displayName,
    String? phone,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final Map<String, dynamic> response = await _apiClient.post(
        '/v1/sites/$siteId/parents',
        body: <String, dynamic>{
          'email': email,
          'displayName': displayName,
          if (phone != null) 'phone': phone,
        },
      );

      final ParentProfile parent = ParentProfile.fromJson(response);
      _parents.add(parent);
      notifyListeners();
      return parent;
    } catch (e) {
      _error = 'Failed to create parent: $e';
      debugPrint(_error);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create guardian link
  Future<GuardianLink?> createGuardianLink({
    required String siteId,
    required String parentId,
    required String learnerId,
    required String relationship,
    bool isPrimary = false,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final Map<String, dynamic> response = await _apiClient.post(
        '/v1/guardian-links',
        body: <String, dynamic>{
          'siteId': siteId,
          'parentId': parentId,
          'learnerId': learnerId,
          'relationship': relationship,
          'isPrimary': isPrimary,
        },
      );

      final GuardianLink link = GuardianLink.fromJson(response);
      _guardianLinks.add(link);
      notifyListeners();
      return link;
    } catch (e) {
      debugPrint('Failed to create guardian link via API, falling back: $e');
      try {
        final DocumentReference<Map<String, dynamic>> ref =
            _firestore.collection('guardianLinks').doc();
        final String createdBy = _auth.currentUser?.uid ?? 'system';
        await ref.set(<String, dynamic>{
          'siteId': siteId,
          'parentId': parentId,
          'learnerId': learnerId,
          'relationship': relationship,
          'isPrimary': isPrimary,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': createdBy,
        });
        try {
          await _syncLearnerParentIds(
            learnerId: learnerId,
            parentId: parentId,
            add: true,
          );
        } catch (syncError) {
          debugPrint(
            'Guardian link created but parentIds sync failed: $syncError',
          );
        }

        final Map<String, String> displayNames =
            await _loadDisplayNames(<String>{parentId, learnerId});
        final GuardianLink link = GuardianLink(
          id: ref.id,
          siteId: siteId,
          parentId: parentId,
          learnerId: learnerId,
          relationship: relationship,
          isPrimary: isPrimary,
          createdAt: DateTime.now(),
          createdBy: createdBy,
          parentName: displayNames[parentId],
          learnerName: displayNames[learnerId],
        );
        _guardianLinks.add(link);
        notifyListeners();
        return link;
      } catch (fallbackError) {
        _error = 'Failed to create guardian link: $fallbackError';
        debugPrint(_error);
        return null;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete guardian link
  Future<bool> deleteGuardianLink(String linkId) async {
    try {
      await _apiClient.delete('/v1/guardian-links/$linkId');
      _guardianLinks.removeWhere((GuardianLink l) => l.id == linkId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to delete guardian link via API, falling back: $e');
      try {
        GuardianLink? existing;
        for (final GuardianLink link in _guardianLinks) {
          if (link.id == linkId) {
            existing = link;
            break;
          }
        }
        await _firestore.collection('guardianLinks').doc(linkId).delete();
        if (existing != null) {
          try {
            await _syncLearnerParentIds(
              learnerId: existing.learnerId,
              parentId: existing.parentId,
              add: false,
            );
          } catch (syncError) {
            debugPrint(
              'Guardian link deleted but parentIds sync failed: $syncError',
            );
          }
        }
        _guardianLinks.removeWhere((GuardianLink l) => l.id == linkId);
        notifyListeners();
        return true;
      } catch (fallbackError) {
        _error = 'Failed to delete guardian link: $fallbackError';
        debugPrint(_error);
        return false;
      }
    }
  }

  /// Update an existing learner profile
  Future<LearnerProfile?> updateLearner({
    required String siteId,
    required String learnerId,
    required String displayName,
    int? gradeLevel,
    DateTime? dateOfBirth,
    String? notes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final Map<String, dynamic> response = await _apiClient.patch(
        '/v1/sites/$siteId/learners/$learnerId',
        body: <String, dynamic>{
          'displayName': displayName,
          if (gradeLevel != null) 'gradeLevel': gradeLevel,
          if (dateOfBirth != null)
            'dateOfBirth': dateOfBirth.millisecondsSinceEpoch,
          if (notes != null) 'notes': notes,
        },
      );

      final LearnerProfile updated = LearnerProfile.fromJson(response);
      final int idx =
          _learners.indexWhere((LearnerProfile l) => l.id == learnerId);
      if (idx >= 0) {
        _learners[idx] = updated;
      }
      notifyListeners();
      return updated;
    } catch (e) {
      _error = 'Failed to update learner: $e';
      debugPrint(_error);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update an existing parent profile
  Future<ParentProfile?> updateParent({
    required String siteId,
    required String parentId,
    required String displayName,
    String? phone,
    String? email,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final Map<String, dynamic> response = await _apiClient.patch(
        '/v1/sites/$siteId/parents/$parentId',
        body: <String, dynamic>{
          'displayName': displayName,
          if (phone != null) 'phone': phone,
          if (email != null) 'email': email,
        },
      );

      final ParentProfile updated = ParentProfile.fromJson(response);
      final int idx =
          _parents.indexWhere((ParentProfile p) => p.id == parentId);
      if (idx >= 0) {
        _parents[idx] = updated;
      }
      notifyListeners();
      return updated;
    } catch (e) {
      _error = 'Failed to update parent: $e';
      debugPrint(_error);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> _loadLearnersFromFirestore(String siteId) async {
    final QuerySnapshot<Map<String, dynamic>> usersSnapshot = await _firestore
        .collection('users')
        .where('siteIds', arrayContains: siteId)
        .get();

    final List<LearnerProfile> userLearners = usersSnapshot.docs
        .where((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
            _canonicalRole(doc.data()['role']) == 'learner')
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      final Map<String, dynamic> data = doc.data();
      return LearnerProfile(
        id: doc.id,
        siteId: siteId,
        userId: doc.id,
        displayName: _stringOrDefault(data['displayName'], data['email'], '?'),
        gradeLevel: _toInt(data['gradeLevel']),
        dateOfBirth: _toDateTime(data['dateOfBirth']),
        notes: data['notes'] as String?,
      );
    }).toList();

    if (userLearners.isNotEmpty) {
      userLearners.sort((LearnerProfile a, LearnerProfile b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
      _learners = userLearners;
      return;
    }

    final QuerySnapshot<Map<String, dynamic>> profileSnapshot = await _firestore
        .collection('learnerProfiles')
        .where('siteId', isEqualTo: siteId)
        .get();

    _learners = profileSnapshot.docs.map((doc) {
      final Map<String, dynamic> data = doc.data();
      final String userId =
          (data['userId'] as String?)?.trim().isNotEmpty == true
              ? (data['userId'] as String).trim()
              : doc.id;
      return LearnerProfile(
        id: userId,
        siteId: siteId,
        userId: userId,
        displayName: _stringOrDefault(data['displayName'], data['name'], '?'),
        gradeLevel: _toInt(data['gradeLevel']),
        dateOfBirth: _toDateTime(data['dateOfBirth']),
        notes: data['notes'] as String?,
      );
    }).toList();

    _learners.sort((LearnerProfile a, LearnerProfile b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
  }

  Future<void> _loadParentsFromFirestore(String siteId) async {
    final QuerySnapshot<Map<String, dynamic>> usersSnapshot = await _firestore
        .collection('users')
        .where('siteIds', arrayContains: siteId)
        .get();

    final List<ParentProfile> userParents = usersSnapshot.docs
        .where((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
            _canonicalRole(doc.data()['role']) == 'parent')
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      final Map<String, dynamic> data = doc.data();
      return ParentProfile(
        id: doc.id,
        siteId: siteId,
        userId: doc.id,
        displayName: _stringOrDefault(data['displayName'], data['email'], '?'),
        phone: data['phone'] as String?,
        email: data['email'] as String?,
      );
    }).toList();

    if (userParents.isNotEmpty) {
      userParents.sort((ParentProfile a, ParentProfile b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
      _parents = userParents;
      return;
    }

    final QuerySnapshot<Map<String, dynamic>> profileSnapshot = await _firestore
        .collection('parentProfiles')
        .where('siteId', isEqualTo: siteId)
        .get();

    _parents = profileSnapshot.docs.map((doc) {
      final Map<String, dynamic> data = doc.data();
      final String userId =
          (data['userId'] as String?)?.trim().isNotEmpty == true
              ? (data['userId'] as String).trim()
              : doc.id;
      return ParentProfile(
        id: userId,
        siteId: siteId,
        userId: userId,
        displayName: _stringOrDefault(data['displayName'], data['name'], '?'),
        phone: data['phone'] as String?,
        email: data['email'] as String?,
      );
    }).toList();

    _parents.sort((ParentProfile a, ParentProfile b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
  }

  Future<void> _loadGuardianLinksFromFirestore(String siteId) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('guardianLinks')
        .where('siteId', isEqualTo: siteId)
        .get();

    final Set<String> userIds = <String>{};
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      final String? parentId = data['parentId'] as String?;
      final String? learnerId = data['learnerId'] as String?;
      if (parentId != null && parentId.isNotEmpty) {
        userIds.add(parentId);
      }
      if (learnerId != null && learnerId.isNotEmpty) {
        userIds.add(learnerId);
      }
    }

    final Map<String, String> displayNames = await _loadDisplayNames(userIds);

    _guardianLinks = snapshot.docs.map((doc) {
      final Map<String, dynamic> data = doc.data();
      final String parentId = data['parentId'] as String? ?? '';
      final String learnerId = data['learnerId'] as String? ?? '';
      return GuardianLink(
        id: doc.id,
        siteId: data['siteId'] as String? ?? siteId,
        parentId: parentId,
        learnerId: learnerId,
        relationship: data['relationship'] as String? ?? 'Parent',
        isPrimary: data['isPrimary'] as bool? ?? false,
        createdAt: _toDateTime(data['createdAt']) ?? DateTime.now(),
        createdBy: data['createdBy'] as String? ?? '',
        parentName: displayNames[parentId],
        learnerName: displayNames[learnerId],
      );
    }).toList();

    _guardianLinks.sort(
      (GuardianLink a, GuardianLink b) => b.createdAt.compareTo(a.createdAt),
    );
  }

  Future<Map<String, String>> _loadDisplayNames(Set<String> userIds) async {
    final Map<String, String> names = <String, String>{
      for (final ParentProfile parent in _parents)
        parent.id: parent.displayName,
      for (final LearnerProfile learner in _learners)
        learner.id: learner.displayName,
    };

    final List<String> unresolvedIds =
        userIds.where((String id) => !names.containsKey(id)).toList();
    if (unresolvedIds.isEmpty) {
      return names;
    }

    final List<DocumentSnapshot<Map<String, dynamic>>> docs = await Future.wait(
      unresolvedIds
          .map((String id) => _firestore.collection('users').doc(id).get()),
    );
    for (final DocumentSnapshot<Map<String, dynamic>> doc in docs) {
      if (!doc.exists) continue;
      final Map<String, dynamic>? data = doc.data();
      if (data == null) continue;
      names[doc.id] =
          _stringOrDefault(data['displayName'], data['email'], doc.id);
    }

    return names;
  }

  Future<void> _syncLearnerParentIds({
    required String learnerId,
    required String parentId,
    required bool add,
  }) async {
    final DocumentReference<Map<String, dynamic>> learnerRef =
        _firestore.collection('users').doc(learnerId);

    if (add) {
      await learnerRef.set(<String, dynamic>{
        'parentIds': FieldValue.arrayUnion(<String>[parentId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    final QuerySnapshot<Map<String, dynamic>> activeLinks = await _firestore
        .collection('guardianLinks')
        .where('learnerId', isEqualTo: learnerId)
        .where('parentId', isEqualTo: parentId)
        .limit(1)
        .get();
    if (activeLinks.docs.isNotEmpty) {
      return;
    }

    await learnerRef.set(<String, dynamic>{
      'parentIds': FieldValue.arrayRemove(<String>[parentId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String _canonicalRole(dynamic role) {
    if (role is! String) return '';
    final String value = role.trim().toLowerCase();
    switch (value) {
      case 'student':
        return 'learner';
      case 'guardian':
        return 'parent';
      case 'sitelead':
      case 'site_lead':
        return 'site';
      default:
        return value;
    }
  }

  String _stringOrDefault(dynamic a, dynamic b, String fallback) {
    if (a is String && a.trim().isNotEmpty) {
      return a.trim();
    }
    if (b is String && b.trim().isNotEmpty) {
      return b.trim();
    }
    return fallback;
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
