import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../services/firestore_service.dart';
import 'educator_models.dart';

/// Service for educator-specific features - wired to Firebase
class EducatorService extends ChangeNotifier {
  EducatorService({
    required FirestoreService firestoreService,
    required this.educatorId,
    this.siteId,
  }) : _firestoreService = firestoreService;
  final FirestoreService _firestoreService;
  final String educatorId;
  final String? siteId;
  FirebaseFirestore get _firestore => _firestoreService.firestore;

  List<TodayClass> _todayClasses = <TodayClass>[];
  EducatorDayStats? _dayStats;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<TodayClass> get todayClasses => _todayClasses;
  TodayClass? get currentClass =>
      _todayClasses.where((TodayClass c) => c.isNow).firstOrNull;
  List<TodayClass> get upcomingClasses =>
      _todayClasses.where((TodayClass c) => c.status == 'upcoming').toList();
  EducatorDayStats? get dayStats => _dayStats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load today's schedule from Firebase
  Future<void> loadTodaySchedule() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final DateTime now = DateTime.now();
      final DateTime startOfDay = DateTime(now.year, now.month, now.day);
      final DateTime endOfDay = startOfDay.add(const Duration(days: 1));

      final List<QueryDocumentSnapshot<Map<String, dynamic>>> occurrenceDocs =
          await _loadTodayOccurrenceDocs(
        startOfDay: startOfDay,
        endOfDay: endOfDay,
      );

      _todayClasses = occurrenceDocs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        final DateTime startTime = _parseTimestamp(data['startTime']) ??
            _parseTimestamp(data['date']) ??
            DateTime.now();
        final DateTime endTime = _parseTimestamp(data['endTime']) ??
            startTime.add(const Duration(hours: 1));
        return TodayClass(
          id: doc.id,
          sessionId: data['sessionId'] as String? ?? '',
          title:
              _stringOrDefault(data['title'], data['sessionTitle'], 'Session'),
          description: _stringOrDefault(data['description'], null, ''),
          startTime: startTime,
          endTime: endTime,
          location: _stringOrDefault(data['location'], data['roomName'], ''),
          enrolledCount: (data['enrolledCount'] as num?)?.toInt() ?? 0,
          presentCount: (data['presentCount'] as num?)?.toInt() ?? 0,
          status: _stringOrDefault(data['status'], null, 'upcoming'),
          learners: const <EnrolledLearner>[],
        );
      }).toList()
        ..sort(
            (TodayClass a, TodayClass b) => a.startTime.compareTo(b.startTime));

      _dayStats = _calculateStats();
      debugPrint(
          'Loaded ${_todayClasses.length} classes for educator $educatorId');
    } catch (e) {
      debugPrint('Error loading educator schedule: $e');
      _error = 'Failed to load schedule: $e';
      _todayClasses = <TodayClass>[];
      _dayStats = const EducatorDayStats(
        totalClasses: 0,
        completedClasses: 0,
        totalLearners: 0,
        presentLearners: 0,
        missionsToReview: 0,
        unreadMessages: 0,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }

  String _stringOrDefault(
      dynamic primary, dynamic fallback, String defaultValue) {
    if (primary is String && primary.trim().isNotEmpty) {
      return primary.trim();
    }
    if (fallback is String && fallback.trim().isNotEmpty) {
      return fallback.trim();
    }
    return defaultValue;
  }

  Iterable<String> _asStringIterable(dynamic value) {
    if (value is List<dynamic>) {
      return value
          .whereType<String>()
          .map((String item) => item.trim())
          .where((String item) => item.isNotEmpty);
    }
    return const <String>[];
  }

  List<String> _normalizedDistinctIds(Iterable<String> values) {
    final Set<String> deduped = values
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toSet();
    return deduped.toList()..sort();
  }

  String _generateJoinCode() {
    const String alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final Random random = Random.secure();
    return List<String>.generate(
      6,
      (int index) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }

  bool _recordMatchesEducator(Map<String, dynamic> data) {
    if ((data['educatorId'] as String?)?.trim() == educatorId) {
      return true;
    }
    if ((data['teacherId'] as String?)?.trim() == educatorId) {
      return true;
    }
    final Set<String> educatorIds = <String>{
      ..._asStringIterable(data['educatorIds']),
      ..._asStringIterable(data['teacherIds']),
    };
    return educatorIds.contains(educatorId);
  }

  bool _recordMatchesSite(Map<String, dynamic> data) {
    final String normalizedSiteId = siteId?.trim() ?? '';
    if (normalizedSiteId.isEmpty) {
      return true;
    }

    final String directSiteId = (data['siteId'] as String?)?.trim() ?? '';
    if (directSiteId == normalizedSiteId) {
      return true;
    }

    final Set<String> siteIds = <String>{
      ..._asStringIterable(data['siteIds']),
      ..._asStringIterable(data['sites']),
    };
    return siteIds.contains(normalizedSiteId);
  }

  Future<void> _appendOccurrenceQueryResults({
    required Query<Map<String, dynamic>> query,
    required Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> sink,
    bool filterByEducator = false,
    bool filterBySite = false,
  }) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs) {
        if (filterByEducator && !_recordMatchesEducator(doc.data())) {
          continue;
        }
        if (filterBySite && !_recordMatchesSite(doc.data())) {
          continue;
        }
        sink[doc.id] = doc;
      }
    } catch (error) {
      debugPrint('Educator occurrence query fallback skipped: $error');
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _loadTodayOccurrenceDocs({
    required DateTime startOfDay,
    required DateTime endOfDay,
  }) async {
    final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> merged =
        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

    final Timestamp startTs = Timestamp.fromDate(startOfDay);
    final Timestamp endTs = Timestamp.fromDate(endOfDay);

    await _appendOccurrenceQueryResults(
      query: _firestore
          .collection('sessionOccurrences')
          .where('educatorId', isEqualTo: educatorId)
          .where('startTime', isGreaterThanOrEqualTo: startTs)
          .where('startTime', isLessThan: endTs)
          .orderBy('startTime'),
      sink: merged,
      filterBySite: true,
    );

    if (merged.isEmpty) {
      await _appendOccurrenceQueryResults(
        query: _firestore
            .collection('sessionOccurrences')
            .where('startTime', isGreaterThanOrEqualTo: startTs)
            .where('startTime', isLessThan: endTs)
            .orderBy('startTime'),
        sink: merged,
        filterByEducator: true,
        filterBySite: true,
      );
    }

    if (merged.isEmpty) {
      await _appendOccurrenceQueryResults(
        query: _firestore
            .collection('sessionOccurrences')
            .where('educatorId', isEqualTo: educatorId)
            .where('date', isGreaterThanOrEqualTo: startTs)
            .where('date', isLessThan: endTs)
            .orderBy('date')
            .orderBy('startTime'),
        sink: merged,
        filterBySite: true,
      );
    }

    if (merged.isEmpty) {
      await _appendOccurrenceQueryResults(
        query: _firestore
            .collection('sessionOccurrences')
            .where('date', isGreaterThanOrEqualTo: startTs)
            .where('date', isLessThan: endTs)
            .orderBy('date')
            .orderBy('startTime'),
        sink: merged,
        filterByEducator: true,
        filterBySite: true,
      );
    }

    return merged.values.toList();
  }

  EducatorDayStats _calculateStats() {
    final int completed =
        _todayClasses.where((TodayClass c) => c.status == 'completed').length;
    final int totalLearners =
        _todayClasses.fold(0, (int sum, TodayClass c) => sum + c.enrolledCount);
    final int presentLearners =
        _todayClasses.fold(0, (int sum, TodayClass c) => sum + c.presentCount);
    return EducatorDayStats(
      totalClasses: _todayClasses.length,
      completedClasses: completed,
      totalLearners: totalLearners,
      presentLearners: presentLearners,
      missionsToReview: 0,
      unreadMessages: 0,
    );
  }

  /// Start a class (transition to in_progress)
  Future<bool> startClass(String classId) async {
    try {
      final int index =
          _todayClasses.indexWhere((TodayClass c) => c.id == classId);
      if (index == -1) return false;

      await _firestore
          .collection('sessionOccurrences')
          .doc(classId)
          .set(<String, dynamic>{
        'status': 'in_progress',
        'startedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final TodayClass existing = _todayClasses[index];
      _todayClasses[index] = TodayClass(
        id: existing.id,
        sessionId: existing.sessionId,
        title: existing.title,
        description: existing.description,
        startTime: existing.startTime,
        endTime: existing.endTime,
        location: existing.location,
        enrolledCount: existing.enrolledCount,
        presentCount: existing.presentCount,
        status: 'in_progress',
        learners: existing.learners,
      );
      _dayStats = _calculateStats();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Quick attendance mark - saves to Firebase
  Future<bool> markAttendance(
      String classId, String learnerId, String status) async {
    try {
      await _firestore.collection('attendanceRecords').add(<String, dynamic>{
        if ((siteId?.trim() ?? '').isNotEmpty) 'siteId': siteId!.trim(),
        'sessionOccurrenceId': classId,
        'learnerId': learnerId,
        'status': status,
        'recordedBy': educatorId,
        'timestamp': FieldValue.serverTimestamp(),
        'recordedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ========== Sessions Management ==========
  List<EducatorSession> _sessions = <EducatorSession>[];
  List<EducatorSession> get sessions => _sessions;

  /// Load sessions from Firebase
  Future<void> loadSessions() async {
    _isLoading = true;
    notifyListeners();
    try {
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> sessionDocs =
          await _loadEducatorSessionDocs();

      _sessions =
          sessionDocs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        final String pillar = _stringOrDefault(
          data['pillar'],
          (data['pillarCodes'] is List<dynamic> &&
                  (data['pillarCodes'] as List<dynamic>).isNotEmpty)
              ? data['pillarCodes'][0]
              : null,
          'future_skills',
        );
        final DateTime startTime = _parseTimestamp(data['startTime']) ??
            _parseTimestamp(data['startDate']) ??
            DateTime.now();
        final DateTime endTime = _parseTimestamp(data['endTime']) ??
            _parseTimestamp(data['endDate']) ??
            startTime.add(const Duration(hours: 1));
        return EducatorSession(
          id: doc.id,
          title: _stringOrDefault(data['title'], null, 'Session'),
          description: _stringOrDefault(data['description'], null, ''),
          pillar: pillar,
          startTime: startTime,
          endTime: endTime,
          location: _stringOrDefault(data['location'], data['roomName'], ''),
          enrolledCount: (data['enrolledCount'] as num?)?.toInt() ?? 0,
          maxCapacity: (data['maxCapacity'] as num?)?.toInt() ?? 20,
          status: _stringOrDefault(data['status'], null, 'upcoming'),
          joinCode: (data['joinCode'] as String?)?.trim(),
          teacherIds: _normalizedDistinctIds(
            <String>[
              ..._asStringIterable(data['teacherIds']),
              if ((data['educatorId'] as String?)?.trim().isNotEmpty == true)
                (data['educatorId'] as String).trim(),
            ],
          ),
          coTeacherIds:
              _normalizedDistinctIds(_asStringIterable(data['coTeacherIds'])),
          aideIds: _normalizedDistinctIds(_asStringIterable(data['aideIds'])),
        );
      }).toList()
            ..sort(
              (EducatorSession a, EducatorSession b) =>
                  b.startTime.compareTo(a.startTime),
            );

      debugPrint('Loaded ${_sessions.length} sessions for educator');
    } catch (e) {
      debugPrint('Error loading sessions: $e');
      _error = 'Failed to load sessions: $e';
      _sessions = <EducatorSession>[];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new session and reflect it immediately in local state
  Future<EducatorSession?> createSession({
    required String title,
    required String pillar,
    required DateTime startTime,
    required DateTime endTime,
    String? description,
    String? location,
    int maxCapacity = 20,
    List<String> coTeacherIds = const <String>[],
    List<String> aideIds = const <String>[],
    bool generateJoinCode = true,
    String? joinCode,
  }) async {
    _error = null;
    notifyListeners();

    try {
      final List<String> teacherIds =
          _normalizedDistinctIds(<String>[educatorId]);
      final List<String> normalizedCoTeacherIds =
          _normalizedDistinctIds(coTeacherIds);
      final List<String> normalizedAideIds = _normalizedDistinctIds(aideIds);
      final List<String> educatorIds = _normalizedDistinctIds(<String>[
        ...teacherIds,
        ...normalizedCoTeacherIds,
        ...normalizedAideIds,
      ]);
      final String? resolvedJoinCode = generateJoinCode
          ? ((joinCode?.trim().isNotEmpty ?? false)
              ? joinCode!.trim().toUpperCase()
              : _generateJoinCode())
          : null;

      final String sessionId = await _firestoreService.createDocument(
        'sessions',
        <String, dynamic>{
          if ((siteId?.trim() ?? '').isNotEmpty) 'siteId': siteId!.trim(),
          'educatorId': educatorId,
          'educatorIds': educatorIds,
          'teacherIds': teacherIds,
          'coTeacherIds': normalizedCoTeacherIds,
          'aideIds': normalizedAideIds,
          'title': title,
          'description': description ?? '',
          'pillar': pillar,
          'startTime': Timestamp.fromDate(startTime),
          'endTime': Timestamp.fromDate(endTime),
          'location': location ?? '',
          'enrolledCount': 0,
          'maxCapacity': maxCapacity,
          'status': 'upcoming',
          if (resolvedJoinCode != null) 'joinCode': resolvedJoinCode,
          if (resolvedJoinCode != null)
            'joinCodeCreatedAt': FieldValue.serverTimestamp(),
        },
      );

      final EducatorSession created = EducatorSession(
        id: sessionId,
        title: title,
        description: description,
        pillar: pillar,
        startTime: startTime,
        endTime: endTime,
        location: location ?? '',
        enrolledCount: 0,
        maxCapacity: maxCapacity,
        status: 'upcoming',
        joinCode: resolvedJoinCode,
        teacherIds: teacherIds,
        coTeacherIds: normalizedCoTeacherIds,
        aideIds: normalizedAideIds,
      );

      _sessions = <EducatorSession>[created, ..._sessions];
      notifyListeners();
      return created;
    } catch (e) {
      _error = 'Failed to create session: $e';
      notifyListeners();
      return null;
    }
  }

  // ========== Learners Management ==========
  List<EducatorLearner> _learners = <EducatorLearner>[];
  List<EducatorLearner> get learners => _learners;

  /// Load learners from Firebase
  Future<void> loadLearners() async {
    _isLoading = true;
    notifyListeners();
    try {
      final Set<String> learnerIds = await _resolveLearnerIdsForEducator();

      if (learnerIds.isEmpty) {
        _learners = <EducatorLearner>[];
        return;
      }

      // Fetch learner profiles
      final List<EducatorLearner> loadedLearners = <EducatorLearner>[];
      for (final String learnerId in learnerIds) {
        final DocumentSnapshot<Map<String, dynamic>> doc =
            await _firestore.collection('users').doc(learnerId).get();
        if (doc.exists) {
          final Map<String, dynamic> data = doc.data()!;
          if (!_recordMatchesSite(data)) {
            continue;
          }
          loadedLearners.add(EducatorLearner(
            id: doc.id,
            name: data['displayName'] as String? ?? 'Unknown',
            email: data['email'] as String? ?? '',
            attendanceRate: (data['attendanceRate'] as num?)?.toInt() ?? 0,
            missionsCompleted: data['missionsCompleted'] as int? ?? 0,
            pillarProgress: <String, double>{
              'future_skills':
                  (data['futureSkillsProgress'] as num?)?.toDouble() ?? 0,
              'leadership':
                  (data['leadershipProgress'] as num?)?.toDouble() ?? 0,
              'impact': (data['impactProgress'] as num?)?.toDouble() ?? 0,
            },
            enrolledSessionIds: List<String>.from(
                data['enrolledSessionIds'] as List<dynamic>? ?? <dynamic>[]),
          ));
        }
      }
      _learners = loadedLearners;
      debugPrint('Loaded ${_learners.length} learners for educator');
    } catch (e) {
      debugPrint('Error loading learners: $e');
      _error = 'Failed to load learners: $e';
      _learners = <EducatorLearner>[];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _appendSessionQueryResults({
    required Query<Map<String, dynamic>> query,
    required Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> sink,
    bool filterByEducator = false,
    bool filterBySite = false,
  }) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs) {
        if (filterByEducator && !_recordMatchesEducator(doc.data())) {
          continue;
        }
        if (filterBySite && !_recordMatchesSite(doc.data())) {
          continue;
        }
        sink[doc.id] = doc;
      }
    } catch (error) {
      debugPrint('Educator session query fallback skipped: $error');
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _loadEducatorSessionDocs() async {
    final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> merged =
        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

    await _appendSessionQueryResults(
      query: _firestore
          .collection('sessions')
          .where('educatorId', isEqualTo: educatorId)
          .orderBy('startTime', descending: true),
      sink: merged,
      filterBySite: true,
    );

    await _appendSessionQueryResults(
      query: _firestore
          .collection('sessions')
          .where('educatorIds', arrayContains: educatorId)
          .orderBy('startTime', descending: true),
      sink: merged,
      filterBySite: true,
    );

    if (merged.isEmpty) {
      await _appendSessionQueryResults(
        query: _firestore
            .collection('sessions')
            .where('educatorId', isEqualTo: educatorId)
            .orderBy('startDate', descending: true),
        sink: merged,
        filterBySite: true,
      );
      await _appendSessionQueryResults(
        query: _firestore
            .collection('sessions')
            .where('educatorIds', arrayContains: educatorId)
            .orderBy('startDate', descending: true),
        sink: merged,
        filterBySite: true,
      );
    }

    if (merged.isEmpty) {
      await _appendSessionQueryResults(
        query: _firestore
            .collection('sessions')
            .orderBy('createdAt', descending: true)
            .limit(300),
        sink: merged,
        filterByEducator: true,
        filterBySite: true,
      );
    }

    return merged.values.toList();
  }

  Future<void> _appendEnrollmentQueryResults({
    required Query<Map<String, dynamic>> query,
    required Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> sink,
    bool filterByEducator = false,
    bool filterBySite = false,
  }) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs) {
        if (filterByEducator && !_recordMatchesEducator(doc.data())) {
          continue;
        }
        if (filterBySite && !_recordMatchesSite(doc.data())) {
          continue;
        }
        sink[doc.id] = doc;
      }
    } catch (error) {
      debugPrint('Educator enrollment query fallback skipped: $error');
    }
  }

  Iterable<List<String>> _chunked(List<String> values, int size) sync* {
    if (size <= 0) {
      yield values;
      return;
    }
    for (int index = 0; index < values.length; index += size) {
      final int end =
          (index + size < values.length) ? index + size : values.length;
      yield values.sublist(index, end);
    }
  }

  Future<Set<String>> _resolveSessionIdsForEducator() async {
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> sessionDocs =
        await _loadEducatorSessionDocs();
    return sessionDocs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.id)
        .where((String id) => id.isNotEmpty)
        .toSet();
  }

  Future<Set<String>> _resolveLearnerIdsFromSessions(
      Set<String> sessionIds) async {
    if (sessionIds.isEmpty) {
      return <String>{};
    }
    final Set<String> learnerIds = <String>{};
    for (final List<String> chunk in _chunked(sessionIds.toList(), 10)) {
      try {
        final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
            .collection('enrollments')
            .where('sessionId', whereIn: chunk)
            .get();
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in snapshot.docs) {
          final String? learnerId = doc.data()['learnerId'] as String?;
          if (learnerId != null && learnerId.trim().isNotEmpty) {
            learnerIds.add(learnerId.trim());
          }
        }
      } catch (error) {
        debugPrint('Session enrollment fallback skipped: $error');
      }
    }
    return learnerIds;
  }

  Future<Set<String>> _resolveLearnerIdsForEducator() async {
    final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> enrollments =
        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

    await _appendEnrollmentQueryResults(
      query: _firestore
          .collection('enrollments')
          .where('educatorId', isEqualTo: educatorId),
      sink: enrollments,
      filterBySite: true,
    );

    if (enrollments.isEmpty) {
      await _appendEnrollmentQueryResults(
        query: _firestore
            .collection('enrollments')
            .where('educatorIds', arrayContains: educatorId),
        sink: enrollments,
        filterBySite: true,
      );
    }

    final Set<String> learnerIds = enrollments.values
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
            doc.data()['learnerId'] as String?)
        .whereType<String>()
        .map((String id) => id.trim())
        .where((String id) => id.isNotEmpty)
        .toSet();

    if (learnerIds.isEmpty) {
      final Set<String> sessionIds = await _resolveSessionIdsForEducator();
      learnerIds.addAll(await _resolveLearnerIdsFromSessions(sessionIds));
    }

    if (learnerIds.isEmpty) {
      try {
        final DocumentSnapshot<Map<String, dynamic>> educatorDoc =
            await _firestore.collection('users').doc(educatorId).get();
        final Map<String, dynamic>? data = educatorDoc.data();
        learnerIds.addAll(_asStringIterable(data?['learnerIds']));
        learnerIds.addAll(_asStringIterable(data?['studentIds']));
      } catch (error) {
        debugPrint('Educator learnerIds fallback skipped: $error');
      }
    }

    return learnerIds;
  }
}
