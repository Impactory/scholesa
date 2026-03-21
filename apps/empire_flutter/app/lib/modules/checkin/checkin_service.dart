import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../offline/offline_queue.dart';
import '../../offline/sync_coordinator.dart';
import '../../services/firestore_service.dart';
import 'checkin_models.dart';

const String _fallbackLearnerName = 'Learner unavailable';
const String _fallbackPickupName = 'Authorized pickup';

class CheckinDaySnapshot {
  const CheckinDaySnapshot({
    required this.learnerSummaries,
    required this.todayRecords,
  });

  final List<LearnerDaySummary> learnerSummaries;
  final List<CheckRecord> todayRecords;
}

/// Service for site check-in/check-out operations - wired to Firebase
class CheckinService extends ChangeNotifier {
  CheckinService({
    required FirestoreService firestoreService,
    required this.siteId,
    SyncCoordinator? syncCoordinator,
    Future<CheckinDaySnapshot> Function()? daySnapshotLoader,
  })  : _firestoreService = firestoreService,
        _syncCoordinator = syncCoordinator,
        _daySnapshotLoader = daySnapshotLoader;
  final FirestoreService _firestoreService;
  final SyncCoordinator? _syncCoordinator;
  final String siteId;
  final Future<CheckinDaySnapshot> Function()? _daySnapshotLoader;
  FirebaseFirestore get _firestore => _firestoreService.firestore;

  List<LearnerDaySummary> _learnerSummaries = <LearnerDaySummary>[];
  List<CheckRecord> _todayRecords = <CheckRecord>[];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  CheckStatus? _statusFilter;

  // Getters
  List<LearnerDaySummary> get learnerSummaries => _filteredSummaries;
  List<CheckRecord> get todayRecords => _todayRecords;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  CheckStatus? get statusFilter => _statusFilter;

  List<LearnerDaySummary> get _filteredSummaries {
    return _learnerSummaries.where((LearnerDaySummary summary) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final String query = _searchQuery.toLowerCase();
        if (!summary.learnerName.toLowerCase().contains(query)) {
          return false;
        }
      }

      // Status filter
      if (_statusFilter != null && summary.currentStatus != _statusFilter) {
        return false;
      }

      return true;
    }).toList();
  }

  // Stats
  int get totalLearners => _learnerSummaries.length;
  int get presentCount => _learnerSummaries
      .where((LearnerDaySummary s) => s.isCurrentlyPresent)
      .length;
  int get absentCount => _learnerSummaries
      .where((LearnerDaySummary s) => s.currentStatus == null)
      .length;
  int get checkedOutCount => _learnerSummaries
      .where((LearnerDaySummary s) => s.currentStatus == CheckStatus.checkedOut)
      .length;

  // Filters
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setStatusFilter(CheckStatus? status) {
    _statusFilter = status;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _statusFilter = null;
    notifyListeners();
  }

  List<PickupLookupMatch> findPickupMatches(String query) {
    final String trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return const <PickupLookupMatch>[];
    }

    final String normalizedQuery = trimmedQuery.toLowerCase();
    final String digitQuery = _digitsOnly(trimmedQuery);
    final Map<String, _ScoredPickupLookupMatch> scoredMatches =
        <String, _ScoredPickupLookupMatch>{};

    void addMatch(
      LearnerDaySummary summary,
      AuthorizedPickup pickup,
      int score,
      String matchSource,
    ) {
      final String key = '${summary.learnerId}:${pickup.id}';
      final _ScoredPickupLookupMatch? existing = scoredMatches[key];
      if (existing != null && existing.score >= score) {
        return;
      }
      scoredMatches[key] = _ScoredPickupLookupMatch(
        match: PickupLookupMatch(
          summary: summary,
          pickup: pickup,
          matchSource: matchSource,
        ),
        score: score,
      );
    }

    for (final LearnerDaySummary summary in _learnerSummaries) {
      if (!summary.isCurrentlyPresent || summary.authorizedPickups.isEmpty) {
        continue;
      }
      final List<AuthorizedPickup> activePickups = summary.authorizedPickups
          .where((AuthorizedPickup pickup) => !_isPickupExpired(pickup))
          .toList();
      if (activePickups.isEmpty) {
        continue;
      }

      final AuthorizedPickup preferredPickup = _preferredPickup(activePickups);
      final String learnerId = summary.learnerId.trim().toLowerCase();
      final String learnerName = summary.learnerName.trim().toLowerCase();
      if (learnerId == normalizedQuery) {
        addMatch(summary, preferredPickup, 90, 'learner_id');
      } else if (learnerName == normalizedQuery) {
        addMatch(summary, preferredPickup, 80, 'learner_name');
      } else if (learnerName.contains(normalizedQuery)) {
        addMatch(summary, preferredPickup, 60, 'learner_name');
      }

      for (final AuthorizedPickup pickup in activePickups) {
        final String? verificationCode =
            _optionalString(pickup.verificationCode)?.toLowerCase();
        final String pickupName = pickup.name.trim().toLowerCase();
        final String pickupPhone = _digitsOnly(pickup.phone);
        final String pickupEmail =
            _optionalString(pickup.email)?.toLowerCase() ?? '';
        final String pickupId = pickup.id.trim().toLowerCase();

        if (verificationCode != null && verificationCode == normalizedQuery) {
          addMatch(summary, pickup, 100, 'pickup_code');
          continue;
        }
        if (pickupPhone.isNotEmpty &&
            digitQuery.isNotEmpty &&
            pickupPhone == digitQuery) {
          addMatch(summary, pickup, 95, 'pickup_phone');
          continue;
        }
        if (pickupId == normalizedQuery) {
          addMatch(summary, pickup, 92, 'pickup_id');
          continue;
        }
        if (pickupName == normalizedQuery) {
          addMatch(summary, pickup, 85, 'pickup_name');
          continue;
        }
        if (pickupEmail == normalizedQuery) {
          addMatch(summary, pickup, 82, 'pickup_email');
          continue;
        }
        if (pickupName.contains(normalizedQuery)) {
          addMatch(summary, pickup, 70, 'pickup_name');
          continue;
        }
        if (pickupEmail.contains(normalizedQuery)) {
          addMatch(summary, pickup, 68, 'pickup_email');
          continue;
        }
        if (pickupPhone.isNotEmpty &&
            digitQuery.isNotEmpty &&
            pickupPhone.contains(digitQuery)) {
          addMatch(summary, pickup, 72, 'pickup_phone');
        }
      }
    }

    final List<_ScoredPickupLookupMatch> ranked =
        scoredMatches.values.toList()
          ..sort((_ScoredPickupLookupMatch a, _ScoredPickupLookupMatch b) {
            final int scoreOrder = b.score.compareTo(a.score);
            if (scoreOrder != 0) {
              return scoreOrder;
            }
            return a.match.summary.learnerName.compareTo(
              b.match.summary.learnerName,
            );
          });
    return ranked
        .map((_ScoredPickupLookupMatch item) => item.match)
        .take(8)
        .toList();
  }

  /// Load today's check-in data from Firebase
  Future<void> loadTodayData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
        final CheckinDaySnapshot snapshot = _daySnapshotLoader != null
          ? await _daySnapshotLoader()
          : await _loadDaySnapshot();

      _todayRecords = snapshot.todayRecords;
      _learnerSummaries = snapshot.learnerSummaries;

      debugPrint(
          'Loaded ${_learnerSummaries.length} learners and ${_todayRecords.length} records');
    } catch (e) {
      debugPrint('Error loading checkin data: $e');
      _error = 'Failed to load check-in data: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<CheckinDaySnapshot> _loadDaySnapshot() async {
    final DateTime now = DateTime.now();
    final DateTime startOfDay = DateTime(now.year, now.month, now.day);
    final DateTime endOfDay = startOfDay.add(const Duration(days: 1));

    final QuerySnapshot<Map<String, dynamic>> recordsSnapshot = await _firestore
        .collection('checkins')
        .where('siteId', isEqualTo: siteId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('timestamp', descending: true)
        .get();

    final List<CheckRecord> todayRecords = recordsSnapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      final Map<String, dynamic> data = doc.data();
      final String type = data['type'] as String? ?? '';
      return CheckRecord(
        id: doc.id,
        learnerId: data['learnerId'] as String? ?? '',
        learnerName: _nonEmptyOrFallback(
          data['learnerName'] as String?,
          _fallbackLearnerName,
        ),
        siteId: siteId,
        status: type == 'checkin'
            ? CheckStatus.checkedIn
            : type == 'late'
                ? CheckStatus.late
                : CheckStatus.checkedOut,
        timestamp: _parseTimestamp(data['timestamp']) ?? DateTime.now(),
        visitorId: data['recordedBy'] as String? ?? '',
        visitorName: data['recorderName'] as String? ?? '',
        notes: data['notes'] as String?,
      );
    }).toList();

    final Map<String, List<CheckRecord>> byLearner = <String, List<CheckRecord>>{};
    for (final CheckRecord record in todayRecords) {
      byLearner.putIfAbsent(record.learnerId, () => <CheckRecord>[]).add(record);
    }

    final QuerySnapshot<Map<String, dynamic>> learnersSnapshot = await _firestore
        .collection('users')
        .where('siteIds', arrayContains: siteId)
        .where('role', isEqualTo: 'learner')
        .get();
    final Map<String, List<AuthorizedPickup>> authorizedPickupsByLearner =
        await _loadAuthorizedPickupsByLearner();

    final List<LearnerDaySummary> learnerSummaries = learnersSnapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      final Map<String, dynamic> data = doc.data();
      final List<CheckRecord> records = byLearner[doc.id] ?? <CheckRecord>[];

      CheckRecord? latestCheckin;
      CheckRecord? latestCheckout;
      CheckRecord? latestLate;
      for (final CheckRecord record in records) {
        if (record.status == CheckStatus.checkedIn &&
            (latestCheckin == null ||
                record.timestamp.isAfter(latestCheckin.timestamp))) {
          latestCheckin = record;
        }
        if (record.status == CheckStatus.checkedOut &&
            (latestCheckout == null ||
                record.timestamp.isAfter(latestCheckout.timestamp))) {
          latestCheckout = record;
        }
        if (record.status == CheckStatus.late &&
            (latestLate == null ||
                record.timestamp.isAfter(latestLate.timestamp))) {
          latestLate = record;
        }
      }

      CheckStatus? currentStatus;
      final DateTime? latestInOrLateTime =
          latestCheckin != null || latestLate != null
              ? ((latestCheckin?.timestamp ??
                          DateTime.fromMillisecondsSinceEpoch(0))
                      .isAfter(latestLate?.timestamp ??
                          DateTime.fromMillisecondsSinceEpoch(0))
                  ? latestCheckin!.timestamp
                  : latestLate!.timestamp)
              : null;

      if (latestCheckout != null && latestInOrLateTime != null) {
        currentStatus = latestCheckout.timestamp.isAfter(latestInOrLateTime)
            ? CheckStatus.checkedOut
            : (latestLate != null && latestLate.timestamp == latestInOrLateTime
                ? CheckStatus.late
                : CheckStatus.checkedIn);
      } else if (latestCheckin != null) {
        currentStatus = CheckStatus.checkedIn;
      } else if (latestLate != null) {
        currentStatus = CheckStatus.late;
      }

      return LearnerDaySummary(
        learnerId: doc.id,
        learnerName: _nonEmptyOrFallback(
          data['displayName'] as String?,
          _fallbackLearnerName,
        ),
        currentStatus: currentStatus,
        checkedInAt: latestCheckin?.timestamp,
        checkedInBy: latestCheckin?.visitorName,
        checkedOutAt: latestCheckout?.timestamp,
        checkedOutBy: latestCheckout?.visitorName,
        authorizedPickups:
            authorizedPickupsByLearner[doc.id] ?? const <AuthorizedPickup>[],
      );
    }).toList();

    return CheckinDaySnapshot(
      learnerSummaries: learnerSummaries,
      todayRecords: todayRecords,
    );
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
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

  String _digitsOnly(String? value) {
    return (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  }

  bool _isPickupExpired(AuthorizedPickup pickup) {
    final DateTime? expiresAt = pickup.expiresAt;
    if (expiresAt == null) {
      return false;
    }
    return expiresAt.isBefore(DateTime.now());
  }

  AuthorizedPickup _preferredPickup(List<AuthorizedPickup> pickups) {
    return pickups.firstWhere(
      (AuthorizedPickup pickup) =>
          pickup.isPrimaryContact && !_isPickupExpired(pickup),
      orElse: () => pickups.firstWhere(
        (AuthorizedPickup pickup) => !_isPickupExpired(pickup),
        orElse: () => pickups.first,
      ),
    );
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
        _fallbackPickupName,
      ),
      phone: _optionalString(raw['phone']),
      email: _optionalString(raw['email']),
      relationship:
          _optionalString(raw['relationship']) ?? 'Authorized pickup',
      photoUrl: _optionalString(raw['photoUrl']),
      isPrimaryContact:
          raw['isPrimaryContact'] == true || raw['isPrimary'] == true || fallbackPrimary,
      expiresAt: _parseTimestamp(raw['expiresAt']),
      verificationCode: _extractVerificationCode(raw),
    );
  }

  Future<Map<String, String>> _loadUserDisplayNames(Set<String> userIds) async {
    final Map<String, String> names = <String, String>{};
    if (userIds.isEmpty) {
      return names;
    }
    final List<Future<DocumentSnapshot<Map<String, dynamic>>>> reads =
        userIds.map((String id) => _firestore.collection('users').doc(id).get()).toList();
    final List<DocumentSnapshot<Map<String, dynamic>>> snapshots =
        await Future.wait(reads);
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

  Future<Map<String, List<AuthorizedPickup>>> _loadAuthorizedPickupsByLearner() async {
    final Map<String, List<AuthorizedPickup>> byLearner =
        <String, List<AuthorizedPickup>>{};

    final QuerySnapshot<Map<String, dynamic>> pickupSnapshot = await _firestore
        .collection('pickupAuthorizations')
        .where('siteId', isEqualTo: siteId)
        .get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in pickupSnapshot.docs) {
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
        final Map<String, dynamic> pickupData =
            Map<String, dynamic>.from(entry);
        pickups.add(
          _authorizedPickupFromMap(
            raw: pickupData,
            learnerId: learnerId,
            fallbackId: '${doc.id}-$index',
          ),
        );
      }
      if (pickups.isNotEmpty) {
        byLearner[learnerId] = pickups;
      }
    }

    final QuerySnapshot<Map<String, dynamic>> guardianLinksSnapshot =
        await _firestore
            .collection('guardianLinks')
            .where('siteId', isEqualTo: siteId)
            .get();
    final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
        linksByLearner =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    final Set<String> parentIds = <String>{};
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in guardianLinksSnapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      final String learnerId = _optionalString(data['learnerId']) ?? '';
      final String parentId = _optionalString(data['parentId']) ?? '';
      if (learnerId.isEmpty || parentId.isEmpty) {
        continue;
      }
      if (byLearner.containsKey(learnerId)) {
        continue;
      }
      linksByLearner
          .putIfAbsent(
            learnerId,
            () => <QueryDocumentSnapshot<Map<String, dynamic>>>[],
          )
          .add(doc);
      parentIds.add(parentId);
    }

    if (linksByLearner.isEmpty) {
      return byLearner;
    }

    final List<Future<DocumentSnapshot<Map<String, dynamic>>>> parentProfileReads =
        parentIds
            .map((String parentId) =>
                _firestore.collection('parentProfiles').doc(parentId).get())
            .toList();
    final List<DocumentSnapshot<Map<String, dynamic>>> parentProfileSnapshots =
        await Future.wait(parentProfileReads);
    final Map<String, Map<String, dynamic>> parentProfiles =
        <String, Map<String, dynamic>>{};
    for (final DocumentSnapshot<Map<String, dynamic>> snapshot
        in parentProfileSnapshots) {
      final Map<String, dynamic>? data = snapshot.data();
      if (data == null) {
        continue;
      }
      parentProfiles[snapshot.id] = data;
    }

    final Map<String, String> displayNames = await _loadUserDisplayNames(parentIds);

    linksByLearner.forEach(
      (
        String learnerId,
        List<QueryDocumentSnapshot<Map<String, dynamic>>> links,
      ) {
        byLearner[learnerId] = links
            .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
              final Map<String, dynamic> data = doc.data();
              final String parentId = _optionalString(data['parentId']) ?? '';
              final Map<String, dynamic> parentProfile =
                  parentProfiles[parentId] ?? const <String, dynamic>{};
              return _authorizedPickupFromMap(
                raw: <String, dynamic>{
                  'id': doc.id,
                  'name': displayNames[parentId],
                  'phone': parentProfile['phone'],
                  'email': parentProfile['email'],
                  'relationship': data['relationship'],
                  'isPrimary': data['isPrimary'],
                },
                learnerId: learnerId,
                fallbackId: doc.id,
                fallbackPrimary: data['isPrimary'] == true,
              );
            })
            .toList();
      },
    );

    return byLearner;
  }

  /// Check in a learner
  Future<bool> checkIn({
    required String learnerId,
    required String learnerName,
    required String visitorId,
    required String visitorName,
    String? notes,
  }) async {
    try {
      final DateTime now = DateTime.now();
      final Map<String, dynamic> payload = <String, dynamic>{
        'siteId': siteId,
        'learnerId': learnerId,
        'learnerName': learnerName,
        'type': 'checkin',
        'status': 'completed',
        'timestamp': now.millisecondsSinceEpoch,
        'recordedBy': visitorId,
        'recorderName': visitorName,
        'notes': notes,
      };

      String createdId = 'offline-checkin-${now.microsecondsSinceEpoch}';
      if (_syncCoordinator?.isOnline ?? true) {
        final DocumentReference<Map<String, dynamic>> createdRef =
            await _firestore.collection('checkins').add(<String, dynamic>{
          ...payload,
          'timestamp': FieldValue.serverTimestamp(),
        });
        createdId = createdRef.id;
      } else {
        final QueuedOp queued = await _syncCoordinator!.queueOperation(
          OpType.presenceCheckin,
          payload,
        );
        createdId = queued.idempotencyKey ?? queued.id;
      }

      final CheckRecord record = CheckRecord(
        id: createdId,
        visitorId: visitorId,
        visitorName: visitorName,
        learnerId: learnerId,
        learnerName: learnerName,
        siteId: siteId,
        timestamp: now,
        status: CheckStatus.checkedIn,
        notes: notes,
      );

      _todayRecords = <CheckRecord>[record, ..._todayRecords];

      // Update learner summary
      final int index = _learnerSummaries
          .indexWhere((LearnerDaySummary s) => s.learnerId == learnerId);
      if (index != -1) {
        final LearnerDaySummary summary = _learnerSummaries[index];
        _learnerSummaries[index] = LearnerDaySummary(
          learnerId: summary.learnerId,
          learnerName: summary.learnerName,
          learnerPhoto: summary.learnerPhoto,
          currentStatus: CheckStatus.checkedIn,
          checkedInAt: now,
          checkedInBy: visitorName,
          authorizedPickups: summary.authorizedPickups,
        );
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Check out a learner
  Future<bool> checkOut({
    required String learnerId,
    required String learnerName,
    required String visitorId,
    required String visitorName,
    String? notes,
  }) async {
    try {
      final DateTime now = DateTime.now();
      final Map<String, dynamic> payload = <String, dynamic>{
        'siteId': siteId,
        'learnerId': learnerId,
        'learnerName': learnerName,
        'type': 'checkout',
        'status': 'completed',
        'timestamp': now.millisecondsSinceEpoch,
        'recordedBy': visitorId,
        'recorderName': visitorName,
        'notes': notes,
      };

      String createdId = 'offline-checkout-${now.microsecondsSinceEpoch}';
      if (_syncCoordinator?.isOnline ?? true) {
        final DocumentReference<Map<String, dynamic>> createdRef =
            await _firestore.collection('checkins').add(<String, dynamic>{
          ...payload,
          'timestamp': FieldValue.serverTimestamp(),
        });
        createdId = createdRef.id;
      } else {
        final QueuedOp queued = await _syncCoordinator!.queueOperation(
          OpType.presenceCheckout,
          payload,
        );
        createdId = queued.idempotencyKey ?? queued.id;
      }

      final CheckRecord record = CheckRecord(
        id: createdId,
        visitorId: visitorId,
        visitorName: visitorName,
        learnerId: learnerId,
        learnerName: learnerName,
        siteId: siteId,
        timestamp: now,
        status: CheckStatus.checkedOut,
        notes: notes,
      );

      _todayRecords = <CheckRecord>[record, ..._todayRecords];

      // Update learner summary
      final int index = _learnerSummaries
          .indexWhere((LearnerDaySummary s) => s.learnerId == learnerId);
      if (index != -1) {
        final LearnerDaySummary summary = _learnerSummaries[index];
        _learnerSummaries[index] = LearnerDaySummary(
          learnerId: summary.learnerId,
          learnerName: summary.learnerName,
          learnerPhoto: summary.learnerPhoto,
          currentStatus: CheckStatus.checkedOut,
          checkedInAt: summary.checkedInAt,
          checkedInBy: summary.checkedInBy,
          checkedOutAt: now,
          checkedOutBy: visitorName,
          authorizedPickups: summary.authorizedPickups,
        );
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Mark learner as late
  Future<bool> markLate({
    required String learnerId,
    required String learnerName,
    String? notes,
  }) async {
    try {
      await _firestore.collection('checkins').add(<String, dynamic>{
        'siteId': siteId,
        'learnerId': learnerId,
        'learnerName': learnerName,
        'type': 'late',
        'status': 'completed',
        'timestamp': FieldValue.serverTimestamp(),
        'notes': notes,
      });

      final int index = _learnerSummaries
          .indexWhere((LearnerDaySummary s) => s.learnerId == learnerId);
      if (index != -1) {
        final LearnerDaySummary summary = _learnerSummaries[index];
        _learnerSummaries[index] = LearnerDaySummary(
          learnerId: summary.learnerId,
          learnerName: summary.learnerName,
          learnerPhoto: summary.learnerPhoto,
          currentStatus: CheckStatus.late,
          checkedInAt: DateTime.now(),
          authorizedPickups: summary.authorizedPickups,
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}

class _ScoredPickupLookupMatch {
  const _ScoredPickupLookupMatch({
    required this.match,
    required this.score,
  });

  final PickupLookupMatch match;
  final int score;
}
