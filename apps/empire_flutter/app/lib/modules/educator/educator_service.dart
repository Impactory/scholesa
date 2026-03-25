import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../services/firestore_service.dart';
import '../../services/telemetry_service.dart';
import 'educator_models.dart';

const String _fallbackLearnerName = 'Learner unavailable';

class TodayScheduleSnapshot {
  const TodayScheduleSnapshot({
    required this.todayClasses,
    required this.dayStats,
  });

  final List<TodayClass> todayClasses;
  final EducatorDayStats dayStats;
}

class EducatorLearnersSnapshot {
  const EducatorLearnersSnapshot({
    required this.learners,
  });

  final List<EducatorLearner> learners;
}

class EducatorSessionsSnapshot {
  const EducatorSessionsSnapshot({
    required this.sessions,
  });

  final List<EducatorSession> sessions;
}

/// Service for educator-specific features - wired to Firebase
class EducatorService extends ChangeNotifier {
  EducatorService({
    required FirestoreService firestoreService,
    required this.educatorId,
    this.siteId,
    Future<TodayScheduleSnapshot> Function()? todayScheduleLoader,
    Future<EducatorSessionsSnapshot> Function()? sessionsLoader,
    Future<EducatorLearnersSnapshot> Function()? learnersLoader,
  })  : _firestoreService = firestoreService,
        _todayScheduleLoader = todayScheduleLoader,
        _sessionsLoader = sessionsLoader,
        _learnersLoader = learnersLoader;
  final FirestoreService _firestoreService;
  final Future<TodayScheduleSnapshot> Function()? _todayScheduleLoader;
  final Future<EducatorSessionsSnapshot> Function()? _sessionsLoader;
  final Future<EducatorLearnersSnapshot> Function()? _learnersLoader;
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
      final TodayScheduleSnapshot snapshot = _todayScheduleLoader != null
          ? await _todayScheduleLoader()
          : await _loadTodayScheduleSnapshot();

      _todayClasses = snapshot.todayClasses;
      _dayStats = snapshot.dayStats;
      debugPrint(
          'Loaded ${_todayClasses.length} classes for educator $educatorId');
    } catch (e) {
      debugPrint('Error loading educator schedule: $e');
      _error = 'Failed to load schedule: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<TodayScheduleSnapshot> _loadTodayScheduleSnapshot() async {
    final DateTime now = DateTime.now();
    final DateTime startOfDay = DateTime(now.year, now.month, now.day);
    final DateTime endOfDay = startOfDay.add(const Duration(days: 1));

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> occurrenceDocs =
        await _loadTodayOccurrenceDocs(
      startOfDay: startOfDay,
      endOfDay: endOfDay,
    );

    final List<TodayClass> todayClasses = occurrenceDocs
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
        title: _stringOrDefault(data['title'], data['sessionTitle'], 'Session'),
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

    final List<TodayClass> previousClasses = _todayClasses;
    _todayClasses = todayClasses;
    final EducatorDayStats dayStats = _calculateStats();
    _todayClasses = previousClasses;

    return TodayScheduleSnapshot(
      todayClasses: todayClasses,
      dayStats: dayStats,
    );
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

  List<List<String>> _parseCsvRows(String source) {
    final List<List<String>> rows = <List<String>>[];
    final StringBuffer field = StringBuffer();
    List<String> currentRow = <String>[];
    bool inQuotes = false;

    void commitField() {
      currentRow.add(field.toString().trim());
      field.clear();
    }

    void commitRow() {
      commitField();
      if (currentRow.any((String cell) => cell.isNotEmpty)) {
        rows.add(List<String>.from(currentRow));
      }
      currentRow = <String>[];
    }

    for (int index = 0; index < source.length; index += 1) {
      final String char = source[index];
      if (char == '"') {
        final bool escapedQuote =
            inQuotes && index + 1 < source.length && source[index + 1] == '"';
        if (escapedQuote) {
          field.write('"');
          index += 1;
          continue;
        }
        inQuotes = !inQuotes;
        continue;
      }
      if (!inQuotes && char == ',') {
        commitField();
        continue;
      }
      if (!inQuotes && (char == '\n' || char == '\r')) {
        if (char == '\r' &&
            index + 1 < source.length &&
            source[index + 1] == '\n') {
          index += 1;
        }
        commitRow();
        continue;
      }
      field.write(char);
    }

    if (field.isNotEmpty || currentRow.isNotEmpty) {
      commitRow();
    }
    return rows;
  }

  String _normalizeHeader(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }

  String? _readRowValue(
    Map<String, int> headerIndex,
    List<String> row,
    List<String> acceptedHeaders,
  ) {
    for (final String header in acceptedHeaders) {
      final int? index = headerIndex[header];
      if (index == null || index >= row.length) {
        continue;
      }
      final String value = row[index].trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findUserByEmail(
    String email,
  ) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return null;
    }
    return snapshot.docs.first;
  }

  Future<bool> _enrollmentExists({
    required String sessionId,
    required String learnerId,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('enrollments')
        .where('sessionId', isEqualTo: sessionId)
        .where('learnerId', isEqualTo: learnerId)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<RosterImportOutcome?> importRosterCsv({
    required String sessionId,
    required String csvContent,
  }) async {
    _error = null;
    notifyListeners();

    try {
      final List<List<String>> rows = _parseCsvRows(csvContent);
      if (rows.length < 2) {
        _error = 'No valid roster rows found in CSV import.';
        notifyListeners();
        return null;
      }

      final List<String> headers =
          rows.first.map(_normalizeHeader).toList(growable: false);
      final Map<String, int> headerIndex = <String, int>{
        for (int index = 0; index < headers.length; index += 1)
          headers[index]: index,
      };
      final DocumentSnapshot<Map<String, dynamic>> sessionDoc =
          await _firestore.collection('sessions').doc(sessionId).get();
      if (!sessionDoc.exists) {
        _error = 'Session not found for roster import.';
        notifyListeners();
        return null;
      }

      final Map<String, dynamic> sessionData =
          sessionDoc.data() ?? <String, dynamic>{};
      final String resolvedSiteId =
          (sessionData['siteId'] as String?)?.trim().isNotEmpty == true
              ? (sessionData['siteId'] as String).trim()
              : (siteId?.trim() ?? '');
      final List<String> educatorIds = _normalizedDistinctIds(<String>[
        educatorId,
        ..._asStringIterable(sessionData['educatorIds']),
      ]);

      final WriteBatch batch = _firestore.batch();
      int importedCount = 0;
      int queuedCount = 0;
      int duplicateCount = 0;
      final List<String> queuedEmails = <String>[];

      for (int rowIndex = 1; rowIndex < rows.length; rowIndex += 1) {
        final List<String> row = rows[rowIndex];
        final String? learnerIdValue = _readRowValue(
          headerIndex,
          row,
          const <String>['learner_id', 'userid', 'user_id', 'id'],
        );
        final String? emailValue = _readRowValue(
          headerIndex,
          row,
          const <String>['email', 'email_address', 'mail'],
        );
        final String displayName = _readRowValue(
              headerIndex,
              row,
              const <String>[
                'name',
                'display_name',
                'learner_name',
                'full_name'
              ],
            ) ??
            emailValue ??
            learnerIdValue ??
            'Learner $rowIndex';

        String? resolvedLearnerId = learnerIdValue?.trim();
        if ((resolvedLearnerId == null || resolvedLearnerId.isEmpty) &&
            emailValue != null) {
          final DocumentSnapshot<Map<String, dynamic>>? userDoc =
              await _findUserByEmail(emailValue);
          final Map<String, dynamic>? userData = userDoc?.data();
          if (userDoc != null &&
              userDoc.exists &&
              _recordMatchesSite(userData ?? <String, dynamic>{})) {
            resolvedLearnerId = userDoc.id;
          }
        }

        if (resolvedLearnerId == null || resolvedLearnerId.isEmpty) {
          final DocumentReference<Map<String, dynamic>> rosterImportRef =
              _firestore.collection('rosterImports').doc();
          batch.set(rosterImportRef, <String, dynamic>{
            if (resolvedSiteId.isNotEmpty) 'siteId': resolvedSiteId,
            'sessionId': sessionId,
            'educatorId': educatorId,
            'status': 'pending_provisioning',
            'source': 'csv_import',
            'rowNumber': rowIndex + 1,
            'displayName': displayName,
            if (emailValue != null) 'email': emailValue.trim().toLowerCase(),
            if (learnerIdValue != null) 'learnerIdCandidate': learnerIdValue,
            'rawRow': row,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          queuedCount += 1;
          if (emailValue != null && emailValue.trim().isNotEmpty) {
            queuedEmails.add(emailValue.trim().toLowerCase());
          }
          continue;
        }

        if (await _enrollmentExists(
          sessionId: sessionId,
          learnerId: resolvedLearnerId,
        )) {
          duplicateCount += 1;
          continue;
        }

        final DocumentReference<Map<String, dynamic>> enrollmentRef =
            _firestore.collection('enrollments').doc();
        batch.set(enrollmentRef, <String, dynamic>{
          if (resolvedSiteId.isNotEmpty) 'siteId': resolvedSiteId,
          'sessionId': sessionId,
          'learnerId': resolvedLearnerId,
          'educatorId': educatorId,
          'educatorIds': educatorIds,
          'status': 'active',
          'source': 'csv_import',
          'displayName': displayName,
          if (emailValue != null) 'email': emailValue.trim().toLowerCase(),
          'importedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        importedCount += 1;
      }

      batch.set(
          sessionDoc.reference,
          <String, dynamic>{
            'lastRosterSyncAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            if (importedCount > 0)
              'enrolledCount': FieldValue.increment(importedCount),
          },
          SetOptions(merge: true));

      await batch.commit();

      await TelemetryService.instance.logEvent(
        event: 'roster.imported',
        siteId: resolvedSiteId.isNotEmpty ? resolvedSiteId : null,
        metadata: <String, dynamic>{
          'session_id': sessionId,
          'total_rows': rows.length - 1,
          'imported_count': importedCount,
          'queued_count': queuedCount,
          'duplicate_count': duplicateCount,
        },
      );

      await loadSessions();
      await loadLearners();

      return RosterImportOutcome(
        totalRows: rows.length - 1,
        importedCount: importedCount,
        queuedCount: queuedCount,
        duplicateCount: duplicateCount,
        queuedEmails: queuedEmails,
      );
    } catch (e) {
      _error = 'Failed to import roster CSV: $e';
      notifyListeners();
      return null;
    }
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

  String _normalizePillarKey(String? value) {
    switch ((value ?? '').trim()) {
      case 'futureSkills':
      case 'future_skills':
        return 'future_skills';
      case 'leadership':
        return 'leadership';
      case 'impact':
        return 'impact';
      default:
        return '';
    }
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
    _error = null;
    notifyListeners();
    try {
      final EducatorSessionsSnapshot snapshot = _sessionsLoader != null
          ? await _sessionsLoader()
          : await _loadSessionsSnapshot();

      _sessions = snapshot.sessions;

      debugPrint('Loaded ${_sessions.length} sessions for educator');
    } catch (e) {
      debugPrint('Error loading sessions: $e');
      _error = 'Failed to load sessions: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<EducatorSessionsSnapshot> _loadSessionsSnapshot() async {
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> sessionDocs =
        await _loadEducatorSessionDocs();
    final Map<String, Map<String, dynamic>> missionsById =
        await _loadLinkedMissionsById(sessionDocs);
    final Map<String, Map<String, dynamic>> missionsBySessionId =
        await _loadLinkedMissionsBySessionId(sessionDocs);

    final List<EducatorSession> sessions =
        sessionDocs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      final Map<String, dynamic> data = doc.data();
      final String linkedMissionId = _linkedMissionId(data);
      final Map<String, dynamic>? missionData = linkedMissionId.isNotEmpty
          ? missionsById[linkedMissionId]
          : missionsBySessionId[doc.id];
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
      final List<String> capabilityTitles = _stringListOrFallback(
        data['capabilityTitles'],
        missionData == null ? null : missionData['capabilityTitles'],
      );
      final List<String> progressionDescriptors = _stringListOrFallback(
        data['progressionDescriptors'],
        missionData == null ? null : missionData['progressionDescriptors'],
      );
      final List<EducatorCheckpointMapping> checkpointMappings =
          _checkpointMappingsOrFallback(
        data['checkpointMappings'],
        missionData == null ? null : missionData['checkpointMappings'],
      );
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
        missionId: linkedMissionId.isNotEmpty
            ? linkedMissionId
            : _stringValue(missionData == null ? null : missionData['id']),
        rubricId: _stringValue(data['rubricId']) ??
            _stringValue(missionData == null ? null : missionData['rubricId']),
        rubricTitle: _stringValue(data['rubricTitle']) ??
            _stringValue(
              missionData == null ? null : missionData['rubricTitle'],
            ),
        capabilityTitles: capabilityTitles,
        progressionDescriptors: progressionDescriptors,
        checkpointMappings: checkpointMappings,
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

    return EducatorSessionsSnapshot(sessions: sessions);
  }

  String _linkedMissionId(Map<String, dynamic> data) {
    return _stringValue(data['missionId']) ??
        _stringValue(data['curriculumId']) ??
        _stringValue(data['linkedMissionId']) ??
        '';
  }

  Future<Map<String, Map<String, dynamic>>> _loadLinkedMissionsById(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> sessionDocs,
  ) async {
    final Set<String> missionIds = sessionDocs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
            _linkedMissionId(doc.data()))
        .where((String id) => id.isNotEmpty)
        .toSet();
    if (missionIds.isEmpty) {
      return <String, Map<String, dynamic>>{};
    }

    final List<DocumentSnapshot<Map<String, dynamic>>> docs =
        await Future.wait(
      missionIds.map(
        (String missionId) =>
            _firestore.collection('missions').doc(missionId).get(),
      ),
    );

    final Map<String, Map<String, dynamic>> missions =
        <String, Map<String, dynamic>>{};
    for (final DocumentSnapshot<Map<String, dynamic>> doc in docs) {
      if (!doc.exists) {
        continue;
      }
      final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
      missions[doc.id] = <String, dynamic>{'id': doc.id, ...data};
    }
    return missions;
  }

  Future<Map<String, Map<String, dynamic>>> _loadLinkedMissionsBySessionId(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> sessionDocs,
  ) async {
    final Set<String> sessionIds = sessionDocs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.id)
        .where((String id) => id.trim().isNotEmpty)
        .toSet();
    if (sessionIds.isEmpty) {
      return <String, Map<String, dynamic>>{};
    }

    final Map<String, Map<String, dynamic>> missionsBySessionId =
        <String, Map<String, dynamic>>{};
    for (final List<String> chunk in _chunked(sessionIds.toList(), 10)) {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('missions')
          .where('sessionId', whereIn: chunk)
          .get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs) {
        final Map<String, dynamic> data = doc.data();
        final String sessionId = _stringValue(data['sessionId']) ?? '';
        if (sessionId.isEmpty || missionsBySessionId.containsKey(sessionId)) {
          continue;
        }
        missionsBySessionId[sessionId] = <String, dynamic>{
          'id': doc.id,
          ...data,
        };
      }
    }
    return missionsBySessionId;
  }

  String? _stringValue(dynamic value) {
    final String normalized = (value as String?)?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  List<String> _stringListOrFallback(dynamic primary, dynamic fallback) {
    final List<String> direct =
        _asStringIterable(primary).toList(growable: false);
    if (direct.isNotEmpty) {
      return direct;
    }
    return _asStringIterable(fallback).toList(growable: false);
  }

  List<EducatorCheckpointMapping> _checkpointMappingsOrFallback(
    dynamic primary,
    dynamic fallback,
  ) {
    final List<EducatorCheckpointMapping> direct =
        _parseCheckpointMappings(primary);
    if (direct.isNotEmpty) {
      return direct;
    }
    return _parseCheckpointMappings(fallback);
  }

  List<EducatorCheckpointMapping> _parseCheckpointMappings(dynamic raw) {
    if (raw is! List) {
      return const <EducatorCheckpointMapping>[];
    }

    return raw
        .whereType<Map>()
        .map((Map value) => Map<String, dynamic>.from(value))
        .map((Map<String, dynamic> item) {
          final String phaseKey = _normalizeCheckpointPhaseKey(
            _stringValue(item['phaseKey']) ?? _stringValue(item['phase']) ?? '',
          );
          final String guidance = _stringValue(item['guidance']) ??
              _stringValue(item['prompt']) ??
              '';
          if (phaseKey.isEmpty || guidance.isEmpty) {
            return null;
          }
          final String canonicalLabel = _checkpointPhaseLabel(phaseKey);
          final String storedLabel =
              _stringValue(item['phaseLabel']) ?? _stringValue(item['label']) ?? '';
          return EducatorCheckpointMapping(
            phaseKey: phaseKey,
            phaseLabel: storedLabel.isNotEmpty ? canonicalLabel : canonicalLabel,
            guidance: guidance,
          );
        })
        .whereType<EducatorCheckpointMapping>()
        .toList(growable: false);
  }

  String _normalizeCheckpointPhaseKey(String raw) {
    final String normalized = raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    switch (normalized) {
      case 'retrieval_warm_up':
      case 'retrieval_warmup':
      case 'retrieval':
        return 'retrieval_warm_up';
      case 'mini_lesson':
      case 'mini_lesson_micro_skill':
      case 'mini_lesson_micro_skills':
      case 'micro_skill':
      case 'micro_skills':
      case 'mini_skill':
        return 'mini_lesson';
      case 'build_sprint':
      case 'build':
        return 'build_sprint';
      case 'checkpoint':
        return 'checkpoint';
      case 'share_out':
      case 'share':
        return 'share_out';
      case 'reflection':
      case 'reflect':
        return 'reflection';
      case 'portfolio_artifact':
      case 'artifact':
      case 'portfolio':
        return 'portfolio_artifact';
      default:
        return normalized;
    }
  }

  String _checkpointPhaseLabel(String phaseKey) {
    switch (phaseKey) {
      case 'retrieval_warm_up':
        return 'Retrieval Warm-up';
      case 'mini_lesson':
        return 'Mini-lesson / Micro-skill';
      case 'build_sprint':
        return 'Build Sprint';
      case 'checkpoint':
        return 'Checkpoint';
      case 'share_out':
        return 'Share-out';
      case 'reflection':
        return 'Reflection';
      case 'portfolio_artifact':
        return 'Portfolio Artifact';
      default:
        return phaseKey;
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
    _error = null;
    notifyListeners();
    try {
      final EducatorLearnersSnapshot snapshot = _learnersLoader != null
          ? await _learnersLoader()
          : await _loadLearnersSnapshot();
      _learners = snapshot.learners;
      debugPrint('Loaded ${_learners.length} learners for educator');
    } catch (e) {
      debugPrint('Error loading learners: $e');
      _error = 'Failed to load learners: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<EducatorLearnersSnapshot> _loadLearnersSnapshot() async {
    final Set<String> learnerIds = await _resolveLearnerIdsForEducator();

    if (learnerIds.isEmpty) {
      return const EducatorLearnersSnapshot(learners: <EducatorLearner>[]);
    }

    final List<EducatorLearner> loadedLearners = <EducatorLearner>[];
    for (final String learnerId in learnerIds) {
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await _firestore.collection('users').doc(learnerId).get();
      if (doc.exists) {
        final Map<String, dynamic> data = doc.data()!;
        if (!_recordMatchesSite(data)) {
          continue;
        }
        final Map<String, double> evidencePillarProgress =
            await _loadEvidencePillarProgress(learnerId);
        loadedLearners.add(EducatorLearner(
          id: doc.id,
          name: (data['displayName'] as String?)?.trim().isNotEmpty == true
              ? (data['displayName'] as String).trim()
              : _fallbackLearnerName,
          email: data['email'] as String? ?? '',
          attendanceRate: (data['attendanceRate'] as num?)?.toInt() ?? 0,
          missionsCompleted: data['missionsCompleted'] as int? ?? 0,
          pillarProgress: evidencePillarProgress,
          enrolledSessionIds: List<String>.from(
              data['enrolledSessionIds'] as List<dynamic>? ?? <dynamic>[]),
        ));
      }
    }

    return EducatorLearnersSnapshot(learners: loadedLearners);
  }

  Future<Map<String, double>> _loadEvidencePillarProgress(
    String learnerId,
  ) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('capabilityMastery')
        .where('learnerId', isEqualTo: learnerId)
        .get();

    final Map<String, List<double>> progressByPillar = <String, List<double>>{
      'future_skills': <double>[],
      'leadership': <double>[],
      'impact': <double>[],
    };

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      if (!_recordMatchesSite(data)) {
        continue;
      }
      final String pillar = _normalizePillarKey(data['pillarCode'] as String?);
      if (!progressByPillar.containsKey(pillar)) {
        continue;
      }
      final double normalizedLevel =
          (((data['latestLevel'] as num?)?.toDouble() ?? 0) / 4)
              .clamp(0, 1)
              .toDouble();
      if (normalizedLevel <= 0) {
        continue;
      }
      progressByPillar[pillar]!.add(normalizedLevel);
    }

    return progressByPillar.map(
      (String pillar, List<double> values) => MapEntry<String, double>(
        pillar,
        values.isEmpty
            ? 0
            : values.reduce((double a, double b) => a + b) / values.length,
      ),
    );
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
