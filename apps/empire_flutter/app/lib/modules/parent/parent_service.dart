import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import '../../services/firestore_service.dart';
import '../../domain/curriculum/curriculum_display.g.dart';
import 'parent_models.dart';

const String _fallbackLearnerName = 'Learner unavailable';
const String _parentDataLoadErrorMessage =
    'We could not load family progress right now. Refresh, or check again after the app reconnects.';

bool _isMissingFirebaseAppError(Object error) {
  final String message = error.toString();
  return message.contains("No Firebase App '[DEFAULT]' has been created") ||
      message.contains('core/no-app');
}

/// Service for parent-specific views
class ParentService extends ChangeNotifier {
  ParentService({
    required FirestoreService firestoreService,
    required this.parentId,
    this.activeSiteId,
    Future<List<LearnerSummary>> Function()? bundleLoader,
    Future<BillingSummary?> Function()? billingLoader,
  })  : _firestoreService = firestoreService,
        _bundleLoader = bundleLoader,
        _billingLoader = billingLoader;
  final FirestoreService _firestoreService;
  final String parentId;
  final String? activeSiteId;
  final Future<List<LearnerSummary>> Function()? _bundleLoader;
  final Future<BillingSummary?> Function()? _billingLoader;
  FirestoreService get firestoreService => _firestoreService;
  FirebaseFirestore get _firestore => _firestoreService.firestore;

  @visibleForTesting
  static int currentLevelFromBundleValue(dynamic value) {
    if (value is int) {
      return value > 0 ? value : 0;
    }
    if (value is num && value.isFinite) {
      final int rounded = value.round();
      return rounded > 0 ? rounded : 0;
    }
    return 0;
  }

  List<LearnerSummary> _learnerSummaries = <LearnerSummary>[];
  BillingSummary? _billingSummary;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<LearnerSummary> get learnerSummaries => _learnerSummaries;
  BillingSummary? get billingSummary => _billingSummary;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load all data for parent dashboard from Firebase
  Future<void> loadParentData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final List<LearnerSummary> callableSummaries = _bundleLoader != null
          ? await _bundleLoader()
          : await _loadParentBundleFromCallable();
      if (callableSummaries.isNotEmpty) {
        _learnerSummaries = callableSummaries;
      } else {
        final List<String> learnerIds = await _resolveLinkedLearnerIds();
        final List<LearnerSummary> summaries = <LearnerSummary>[];
        for (final String learnerId in learnerIds) {
          final LearnerSummary? summary = await _buildLearnerSummary(learnerId);
          if (summary != null) {
            summaries.add(summary);
          }
        }
        _learnerSummaries = summaries;
      }

      // Load billing summary
      await _loadBillingSummary();

      debugPrint(
          'Loaded ${_learnerSummaries.length} learner summaries for parent');
    } catch (e) {
      debugPrint('Error loading parent data: $e');
      _error = _parentDataLoadErrorMessage;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<LearnerSummary>> _loadParentBundleFromCallable() async {
    try {
      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('getParentDashboardBundle');
      final HttpsCallableResult<dynamic> result =
          await callable.call(<String, dynamic>{'range': 'week'});
      final Map<String, dynamic>? payload = _asStringDynamicMap(result.data);
      if (payload == null) {
        return <LearnerSummary>[];
      }
      final List<dynamic> learnersRaw =
          payload['learners'] as List<dynamic>? ?? <dynamic>[];
      final List<LearnerSummary> parsed = <LearnerSummary>[];
      for (final dynamic learnerRaw in learnersRaw) {
        final Map<String, dynamic>? learner = _asStringDynamicMap(learnerRaw);
        if (learner == null) continue;
        final String learnerId = _asTrimmedString(learner['learnerId']);
        final String learnerName = _asTrimmedString(learner['learnerName']);
        if (learnerId.isEmpty || learnerName.isEmpty) continue;

        final List<RecentActivity> activities = _parseRecentActivities(
          learner['recentActivities'] as List<dynamic>? ?? <dynamic>[],
        );
        final List<UpcomingEvent> events = _parseUpcomingEvents(
          learner['upcomingEvents'] as List<dynamic>? ?? <dynamic>[],
        );

        parsed.add(
          LearnerSummary(
            learnerId: learnerId,
            learnerName: learnerName,
            photoUrl: learner['photoUrl'] as String?,
            currentLevel: currentLevelFromBundleValue(learner['currentLevel']),
            totalXp: _toInt(learner['totalXp']) ?? 0,
            missionsCompleted: _toInt(learner['missionsCompleted']) ?? 0,
            currentStreak: _toInt(learner['currentStreak']) ?? 0,
            attendanceRate: _toDouble(learner['attendanceRate']) ?? 0.0,
            pillarProgress: _parsePillarProgress(learner['pillarProgress']),
            capabilitySnapshot:
                _parseCapabilitySnapshot(learner['capabilitySnapshot']),
            evidenceSummary: _parseEvidenceSummary(learner['evidenceSummary']),
            growthSummary: _parseGrowthSummary(learner['growthSummary']),
            portfolioSnapshot:
                _parsePortfolioSnapshot(learner['portfolioSnapshot']),
            portfolioItemsPreview:
                _parsePortfolioItemsPreview(learner['portfolioItemsPreview']),
            ideationPassport:
                _parseIdeationPassport(learner['ideationPassport']),
            growthTimeline: _parseGrowthTimeline(learner['growthTimeline']),
            recentActivities: activities,
            upcomingEvents: events,
          ),
        );
      }
      return parsed;
    } catch (error) {
      if (!_isMissingFirebaseAppError(error)) {
        debugPrint(
          'Parent callable bundle unavailable, using Firestore fallback: $error',
        );
      }
      return <LearnerSummary>[];
    }
  }

  Future<List<String>> _resolveLinkedLearnerIds() async {
    final Set<String> learnerIds = <String>{};

    try {
      final QuerySnapshot<Map<String, dynamic>> links = await _firestore
          .collection('guardianLinks')
          .where('parentId', isEqualTo: parentId)
          .get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in links.docs) {
        final String learnerId =
            (doc.data()['learnerId'] as String? ?? '').trim();
        if (learnerId.isNotEmpty) {
          learnerIds.add(learnerId);
        }
      }
    } catch (error) {
      debugPrint('guardianLinks lookup failed for parent $parentId: $error');
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> parentDoc =
          await _firestore.collection('users').doc(parentId).get();
      final List<String> parentLearnerIds = List<String>.from(
        parentDoc.data()?['learnerIds'] as List<dynamic>? ?? <dynamic>[],
      )
          .map((String value) => value.trim())
          .where((String value) => value.isNotEmpty)
          .toList();
      learnerIds.addAll(parentLearnerIds);
    } catch (error) {
      debugPrint(
          'parent learnerIds lookup failed for parent $parentId: $error');
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> learnersSnapshot =
          await _firestore
              .collection('users')
              .where('parentIds', arrayContains: parentId)
              .get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in learnersSnapshot.docs) {
        final String role = _canonicalRole(doc.data()['role']);
        if (role == 'learner') {
          learnerIds.add(doc.id);
        }
      }
    } catch (error) {
      debugPrint(
          'users parentIds fallback lookup failed for parent $parentId: $error');
    }

    return learnerIds.toList();
  }

  Future<Map<String, String>> _loadUserDisplayNames(
      Iterable<String> userIds) async {
    final Map<String, String> names = <String, String>{};
    for (final String userId in userIds) {
      final String trimmed = userId.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      try {
        final DocumentSnapshot<Map<String, dynamic>> doc =
            await _firestore.collection('users').doc(trimmed).get();
        final Map<String, dynamic>? data = doc.data();
        final String displayName =
            (data?['displayName'] as String? ?? '').trim();
        final String email = (data?['email'] as String? ?? '').trim();
        final String resolved = displayName.isNotEmpty
            ? displayName
            : email.isNotEmpty
                ? email
                : '';
        if (resolved.isNotEmpty) {
          names[trimmed] = resolved;
        }
      } catch (_) {
        // Keep the parent surface honest by omitting missing reviewer identity
        // rather than fabricating one.
      }
    }
    return names;
  }

  Future<Map<String, Map<String, dynamic>>> _loadProofBundleDetails(
      Iterable<String> proofBundleIds) async {
    final Map<String, Map<String, dynamic>> details =
        <String, Map<String, dynamic>>{};
    for (final String proofBundleId in proofBundleIds) {
      final String trimmed = proofBundleId.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      try {
        final DocumentSnapshot<Map<String, dynamic>> doc = await _firestore
            .collection('proofOfLearningBundles')
            .doc(trimmed)
            .get();
        if (doc.exists && doc.data() != null) {
          details[trimmed] = <String, dynamic>{...doc.data()!, 'id': doc.id};
        }
      } catch (_) {
        // Omit missing proof detail instead of synthesizing it.
      }
    }
    return details;
  }

  String? _excerpt(String? value) {
    final String trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  Future<LearnerSummary?> _buildLearnerSummary(String learnerId) async {
    final DocumentSnapshot<Map<String, dynamic>> learnerDoc =
        await _firestore.collection('users').doc(learnerId).get();
    if (!learnerDoc.exists) return null;
    final Map<String, dynamic> learnerData =
        learnerDoc.data() ?? <String, dynamic>{};
    final String role = _canonicalRole(learnerData['role']);
    if (role.isNotEmpty && role != 'learner') return null;

    final DocumentSnapshot<Map<String, dynamic>> progressDoc =
        await _firestore.collection('learnerProgress').doc(learnerId).get();
    final Map<String, dynamic>? progressData = progressDoc.data();

    Query<Map<String, dynamic>> activitiesQuery = _firestore
        .collection('activities')
        .where('learnerId', isEqualTo: learnerId);
    final String normalizedActiveSiteId = activeSiteId?.trim() ?? '';
    if (normalizedActiveSiteId.isNotEmpty) {
      activitiesQuery = activitiesQuery.where(
        'siteId',
        isEqualTo: normalizedActiveSiteId,
      );
    }
    final QuerySnapshot<Map<String, dynamic>> activitiesSnapshot =
        await activitiesQuery
            .orderBy('timestamp', descending: true)
            .limit(10)
            .get();

    final List<RecentActivity> activities = activitiesSnapshot.docs.map(
      (QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return RecentActivity(
          id: doc.id,
          title: data['title'] as String? ?? '',
          description: data['description'] as String? ?? '',
          type: data['type'] as String? ?? 'activity',
          emoji: data['emoji'] as String? ?? '📝',
          timestamp: _parseTimestamp(data['timestamp']) ?? DateTime.now(),
        );
      },
    ).toList();

    final List<UpcomingEvent> events =
        await _loadUpcomingEventsForLearner(learnerId);

    QuerySnapshot<Map<String, dynamic>> attendanceSnapshot;
    try {
      attendanceSnapshot = await _firestore
          .collection('attendanceRecords')
          .where('learnerId', isEqualTo: learnerId)
          .orderBy('recordedAt', descending: true)
          .limit(30)
          .get();
    } catch (_) {
      attendanceSnapshot = await _firestore
          .collection('attendanceRecords')
          .where('learnerId', isEqualTo: learnerId)
          .orderBy('timestamp', descending: true)
          .limit(30)
          .get();
    }

    int presentCount = 0;
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in attendanceSnapshot.docs) {
      if (doc.data()['status'] == 'present') {
        presentCount++;
      }
    }
    final double attendanceRate = attendanceSnapshot.docs.isNotEmpty
        ? presentCount / attendanceSnapshot.docs.length
        : 0.0;

    final QuerySnapshot<Map<String, dynamic>> evidenceSnapshot =
        await _firestore
            .collection('evidenceRecords')
            .where('learnerId', isEqualTo: learnerId)
            .limit(120)
            .get();
    final List<Map<String, dynamic>> evidenceRows = evidenceSnapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
            <String, dynamic>{...doc.data(), 'id': doc.id})
        .toList(growable: false);

    final QuerySnapshot<Map<String, dynamic>> capabilityMasterySnapshot =
        await _firestore
            .collection('capabilityMastery')
            .where('learnerId', isEqualTo: learnerId)
            .limit(120)
            .get();
    final List<Map<String, dynamic>> masteryRows = capabilityMasterySnapshot
        .docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.data())
        .toList(growable: false);

    final QuerySnapshot<Map<String, dynamic>> capabilityGrowthSnapshot =
        await _firestore
            .collection('capabilityGrowthEvents')
            .where('learnerId', isEqualTo: learnerId)
            .limit(120)
            .get();
    final List<Map<String, dynamic>> growthRows = capabilityGrowthSnapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
            <String, dynamic>{...doc.data(), 'id': doc.id})
        .toList(growable: false);
    final QuerySnapshot<Map<String, dynamic>> portfolioSnapshot =
        await _firestore
            .collection('portfolioItems')
            .where('learnerId', isEqualTo: learnerId)
            .limit(120)
            .get();
    final List<Map<String, dynamic>> portfolioRows = portfolioSnapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
            <String, dynamic>{...doc.data(), 'id': doc.id})
        .toList(growable: false);

    final QuerySnapshot<Map<String, dynamic>> reflectionsSnapshot =
        await _firestore
            .collection('learnerReflections')
            .where('learnerId', isEqualTo: learnerId)
            .limit(120)
            .get();
    final List<Map<String, dynamic>> reflectionRows = reflectionsSnapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.data())
        .toList(growable: false);

    final QuerySnapshot<Map<String, dynamic>> missionAttemptsSnapshot =
        await _firestore
            .collection('missionAttempts')
            .where('learnerId', isEqualTo: learnerId)
            .limit(120)
            .get();
    final List<Map<String, dynamic>> missionAttemptRows =
        missionAttemptsSnapshot.docs
            .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                <String, dynamic>{...doc.data(), 'id': doc.id})
            .toList(growable: false);
    final Map<String, String> reviewerNames =
        await _loadUserDisplayNames(<String>{
      ...growthRows
          .map(
              (Map<String, dynamic> row) => _asTrimmedString(row['educatorId']))
          .where((String value) => value.isNotEmpty),
      ...portfolioRows
          .map(
              (Map<String, dynamic> row) => _asTrimmedString(row['educatorId']))
          .where((String value) => value.isNotEmpty),
      ...missionAttemptRows
          .map(
              (Map<String, dynamic> row) => _asTrimmedString(row['reviewedBy']))
          .where((String value) => value.isNotEmpty),
    });

    final QuerySnapshot<Map<String, dynamic>> interactionEventsSnapshot =
        await _firestore
            .collection('interactionEvents')
            .where('actorId', isEqualTo: learnerId)
            .limit(400)
            .get();
    final List<Map<String, dynamic>> interactionEventRows =
        interactionEventsSnapshot.docs
            .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                <String, dynamic>{...doc.data(), 'id': doc.id})
            .toList(growable: false);
    final Map<String, Map<String, dynamic>> proofBundleDetails =
        await _loadProofBundleDetails(<String>{
      ...missionAttemptRows
          .map((Map<String, dynamic> row) =>
              _asTrimmedString(row['proofBundleId']))
          .where((String value) => value.isNotEmpty),
      ...portfolioRows
          .map((Map<String, dynamic> row) =>
              _asTrimmedString(row['proofBundleId']))
          .where((String value) => value.isNotEmpty),
    });

    final EvidenceSummary evidenceSummary = _buildEvidenceSummary(evidenceRows);
    final GrowthSummary growthSummary =
        _buildGrowthSummary(masteryRows, growthRows);
    final List<GrowthTimelineEntry> growthTimeline = _buildGrowthTimeline(
      masteryRows,
      evidenceRows,
      growthRows,
      portfolioRows,
      reviewerNames,
    );
    final CapabilitySnapshot capabilitySnapshot =
        _buildCapabilitySnapshot(masteryRows);
    final PortfolioSnapshot portfolioSummary =
        _buildPortfolioSnapshot(portfolioRows);
    final List<PortfolioPreviewItem> portfolioItemsPreview =
        _buildPortfolioPreviewItems(
      portfolioRows,
      missionAttemptRows,
      interactionEventRows,
      growthRows,
      reviewerNames,
      proofBundleDetails,
    );
    final IdeationPassport ideationPassport = _buildIdeationPassport(
      missionAttemptRows,
      interactionEventRows,
      reflectionRows,
      evidenceRows,
      masteryRows,
      growthRows,
      portfolioRows,
      reviewerNames,
      proofBundleDetails,
    );
    final int evidenceBackedCurrentLevel = growthSummary.averageLevel > 0
        ? math.max(1, growthSummary.averageLevel.round())
        : (_toInt(progressData?['level']) ?? 1);

    return LearnerSummary(
      learnerId: learnerId,
      learnerName:
          (learnerData['displayName'] as String?)?.trim().isNotEmpty == true
              ? (learnerData['displayName'] as String).trim()
              : _fallbackLearnerName,
      photoUrl: learnerData['photoUrl'] as String?,
      currentLevel: evidenceBackedCurrentLevel,
      totalXp: _toInt(progressData?['totalXp']) ?? 0,
      missionsCompleted: _toInt(progressData?['missionsCompleted']) ?? 0,
      currentStreak: _toInt(progressData?['currentStreak']) ?? 0,
      attendanceRate: attendanceRate,
      pillarProgress: <String, double>{
        'futureSkills': capabilitySnapshot.futureSkills,
        'leadership': capabilitySnapshot.leadership,
        'impact': capabilitySnapshot.impact,
      },
      capabilitySnapshot: capabilitySnapshot,
      evidenceSummary: evidenceSummary,
      growthSummary: growthSummary,
      portfolioSnapshot: portfolioSummary,
      portfolioItemsPreview: portfolioItemsPreview,
      ideationPassport: ideationPassport,
      growthTimeline: growthTimeline,
      recentActivities: activities,
      upcomingEvents: events,
    );
  }

  Future<List<UpcomingEvent>> _loadUpcomingEventsForLearner(
    String learnerId,
  ) async {
    final DateTime now = DateTime.now();
    final QuerySnapshot<Map<String, dynamic>> enrollmentsSnapshot =
        await _firestore
            .collection('enrollments')
            .where('learnerId', isEqualTo: learnerId)
            .where('status', isEqualTo: 'active')
            .get();

    final Set<String> sessionIds = enrollmentsSnapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
            (doc.data()['sessionId'] as String? ?? '').trim())
        .where((String sessionId) => sessionId.isNotEmpty)
        .toSet();

    final List<UpcomingEvent> sessionEvents = <UpcomingEvent>[];
    for (final String sessionId in sessionIds) {
      final QuerySnapshot<Map<String, dynamic>> occurrencesSnapshot =
          await _firestore
              .collection('sessionOccurrences')
              .where('sessionId', isEqualTo: sessionId)
              .limit(20)
              .get();

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in occurrencesSnapshot.docs) {
        final Map<String, dynamic> data = doc.data();
        final DateTime? startTime =
            _parseTimestamp(data['startTime']) ?? _parseTimestamp(data['date']);
        if (startTime == null || startTime.isBefore(now)) {
          continue;
        }
        sessionEvents.add(
          UpcomingEvent(
            id: doc.id,
            title: data['title'] as String? ??
                data['sessionTitle'] as String? ??
                'Session',
            description: data['description'] as String?,
            dateTime: startTime,
            type: 'session',
            location:
                data['roomName'] as String? ?? data['location'] as String?,
          ),
        );
      }
    }

    sessionEvents.sort(
      (UpcomingEvent left, UpcomingEvent right) =>
          left.dateTime.compareTo(right.dateTime),
    );
    if (sessionEvents.isNotEmpty) {
      return sessionEvents.take(5).toList();
    }

    final QuerySnapshot<Map<String, dynamic>> eventsSnapshot = await _firestore
        .collection('events')
        .where('learnerId', isEqualTo: learnerId)
        .where('dateTime', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('dateTime')
        .limit(5)
        .get();

    return eventsSnapshot.docs.map(
      (QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return UpcomingEvent(
          id: doc.id,
          title: data['title'] as String? ?? '',
          description: data['description'] as String?,
          dateTime: _parseTimestamp(data['dateTime']) ?? DateTime.now(),
          type: data['type'] as String? ?? 'event',
          location: data['location'] as String?,
        );
      },
    ).toList();
  }

  /// Load billing summary from Firebase
  Future<void> _loadBillingSummary() async {
    if (_billingLoader != null) {
      _billingSummary = await _billingLoader();
      return;
    }
    try {
      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('getParentBillingSummary');
      final HttpsCallableResult<dynamic> result =
          await callable.call(<String, dynamic>{'parentId': parentId});
      final Map<String, dynamic>? payload = _asStringDynamicMap(result.data);
      final Map<String, dynamic>? summary =
          _asStringDynamicMap(payload?['summary']);
      if (summary == null) {
        _billingSummary = null;
        return;
      }
      final List<dynamic> paymentsRaw =
          summary['recentPayments'] as List<dynamic>? ?? <dynamic>[];
      final List<PaymentHistory> payments = paymentsRaw
          .map(_asStringDynamicMap)
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> payData) => PaymentHistory(
                id: _asTrimmedString(payData['id']),
                amount: _toDouble(payData['amount']) ?? 0.0,
                date: _parseTimestamp(payData['date']) ?? DateTime.now(),
                status: _asTrimmedString(payData['status']).isEmpty
                    ? 'unknown'
                    : _asTrimmedString(payData['status']),
                description: _asTrimmedString(payData['description']),
              ))
          .toList();

      _billingSummary = BillingSummary(
        currentBalance: _toDouble(summary['currentBalance']) ?? 0.0,
        nextPaymentAmount: _toDouble(summary['nextPaymentAmount']) ?? 0.0,
        nextPaymentDate: _parseTimestamp(summary['nextPaymentDate']),
        subscriptionPlan: _asTrimmedString(summary['subscriptionPlan']),
        recentPayments: payments,
      );
      return;
    } catch (error) {
      if (!_isMissingFirebaseAppError(error)) {
        debugPrint('Parent billing callable request failed: $error');
      }
      _billingSummary = null;
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

  Map<String, dynamic>? _asStringDynamicMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map(
        (dynamic key, dynamic nestedValue) =>
            MapEntry<String, dynamic>(key.toString(), nestedValue),
      );
    }
    return null;
  }

  List<RecentActivity> _parseRecentActivities(List<dynamic> values) {
    return values
        .map(_asStringDynamicMap)
        .whereType<Map<String, dynamic>>()
        .map((Map<String, dynamic> activity) => RecentActivity(
              id: _asTrimmedString(activity['id']),
              title: _asTrimmedString(activity['title']),
              description: _asTrimmedString(activity['description']),
              type: _asTrimmedString(activity['type']).isEmpty
                  ? 'activity'
                  : _asTrimmedString(activity['type']),
              emoji: _asTrimmedString(activity['emoji']).isEmpty
                  ? '📝'
                  : _asTrimmedString(activity['emoji']),
              timestamp:
                  _parseTimestamp(activity['timestamp']) ?? DateTime.now(),
            ))
        .toList();
  }

  List<UpcomingEvent> _parseUpcomingEvents(List<dynamic> values) {
    return values
        .map(_asStringDynamicMap)
        .whereType<Map<String, dynamic>>()
        .map((Map<String, dynamic> event) => UpcomingEvent(
              id: _asTrimmedString(event['id']),
              title: _asTrimmedString(event['title']),
              description: event['description'] as String?,
              dateTime: _parseTimestamp(event['dateTime']) ?? DateTime.now(),
              type: _asTrimmedString(event['type']).isEmpty
                  ? 'event'
                  : _asTrimmedString(event['type']),
              location: event['location'] as String?,
            ))
        .toList();
  }

  Map<String, double> _parsePillarProgress(dynamic value) {
    if (value is! Map) {
      return <String, double>{
        'futureSkills': 0,
        'leadership': 0,
        'impact': 0,
      };
    }

    final Map<String, double> parsed = <String, double>{
      'futureSkills': _toDouble(value['futureSkills']) ?? 0,
      'leadership': _toDouble(value['leadership']) ?? 0,
      'impact': _toDouble(value['impact']) ?? 0,
    };
    return parsed;
  }

  CapabilitySnapshot _parseCapabilitySnapshot(dynamic value) {
    if (value is! Map) return const CapabilitySnapshot();
    return CapabilitySnapshot(
      futureSkills: _toDouble(value['futureSkills']) ?? 0,
      leadership: _toDouble(value['leadership']) ?? 0,
      impact: _toDouble(value['impact']) ?? 0,
      overall: _toDouble(value['overall']) ?? 0,
      band: _asTrimmedString(value['band']).isEmpty
          ? 'emerging'
          : _asTrimmedString(value['band']),
    );
  }

  PortfolioSnapshot _parsePortfolioSnapshot(dynamic value) {
    if (value is! Map) return const PortfolioSnapshot();
    return PortfolioSnapshot(
      artifactCount: _toInt(value['artifactCount']) ?? 0,
      publishedArtifactCount: _toInt(value['publishedArtifactCount']) ?? 0,
      badgeCount: _toInt(value['badgeCount']) ?? 0,
      projectCount: _toInt(value['projectCount']) ?? 0,
      evidenceLinkedArtifactCount:
          _toInt(value['evidenceLinkedArtifactCount']) ?? 0,
      verifiedArtifactCount: _toInt(value['verifiedArtifactCount']) ?? 0,
      latestArtifactAt: _parseTimestamp(value['latestArtifactAt']),
    );
  }

  EvidenceSummary _parseEvidenceSummary(dynamic value) {
    if (value is! Map) return const EvidenceSummary();
    return EvidenceSummary(
      recordCount: _toInt(value['recordCount']) ?? 0,
      reviewedCount: _toInt(value['reviewedCount']) ?? 0,
      portfolioLinkedCount: _toInt(value['portfolioLinkedCount']) ?? 0,
      verificationPromptCount: _toInt(value['verificationPromptCount']) ?? 0,
      latestEvidenceAt: _parseTimestamp(value['latestEvidenceAt']),
    );
  }

  GrowthSummary _parseGrowthSummary(dynamic value) {
    if (value is! Map) return const GrowthSummary();
    return GrowthSummary(
      capabilityCount: _toInt(value['capabilityCount']) ?? 0,
      updatedCapabilityCount: _toInt(value['updatedCapabilityCount']) ?? 0,
      averageLevel: _toDouble(value['averageLevel']) ?? 0,
      latestLevel: _toInt(value['latestLevel']) ?? 0,
      latestGrowthAt: _parseTimestamp(value['latestGrowthAt']),
    );
  }

  List<GrowthTimelineEntry> _parseGrowthTimeline(dynamic value) {
    if (value is! List) return const <GrowthTimelineEntry>[];
    return value
        .whereType<Map>()
        .map((Map item) => GrowthTimelineEntry(
              capabilityId: _asTrimmedString(item['capabilityId']),
              title: _asTrimmedString(item['title']).isEmpty
                  ? _asTrimmedString(item['capabilityId'])
                  : _asTrimmedString(item['title']),
              pillar: _asTrimmedString(item['pillar']).isEmpty
                  ? CurriculumDisplay.legacyFamilyStorageLabel(
                      CurriculumLegacyFamilyCode.future_skills,
                    )
                  : _asTrimmedString(item['pillar']),
              level: _toInt(item['level']) ?? 0,
              linkedEvidenceRecordIds: List<String>.from(
                item['linkedEvidenceRecordIds'] as List? ?? const <String>[],
              ),
              linkedPortfolioItemIds: List<String>.from(
                item['linkedPortfolioItemIds'] as List? ?? const <String>[],
              ),
              proofOfLearningStatus:
                  _asTrimmedString(item['proofOfLearningStatus']).isEmpty
                      ? null
                      : _asTrimmedString(item['proofOfLearningStatus']),
              occurredAt: _parseTimestamp(item['occurredAt']),
              reviewingEducatorName:
                  _asTrimmedString(item['reviewingEducatorName']).isEmpty
                      ? null
                      : _asTrimmedString(item['reviewingEducatorName']),
              rubricRawScore: _toInt(item['rubricRawScore']),
              rubricMaxScore: _toInt(item['rubricMaxScore']),
              missionAttemptId:
                  _asTrimmedString(item['missionAttemptId']).isEmpty
                      ? null
                      : _asTrimmedString(item['missionAttemptId']),
            ))
        .where((GrowthTimelineEntry entry) => entry.capabilityId.isNotEmpty)
        .toList(growable: false);
  }

  List<ProofCheckpointPreview> _parseProofCheckpoints(dynamic value) {
    if (value is! List) return const <ProofCheckpointPreview>[];
    return value
        .whereType<Map>()
        .map((Map item) => ProofCheckpointPreview(
              id: _asTrimmedString(item['id']),
              summary: _asTrimmedString(item['summary']),
              artifactNote: _asTrimmedString(item['artifactNote']).isEmpty
                  ? null
                  : _asTrimmedString(item['artifactNote']),
              actorId: _asTrimmedString(item['actorId']).isEmpty
                  ? null
                  : _asTrimmedString(item['actorId']),
              actorRole: _asTrimmedString(item['actorRole']).isEmpty
                  ? null
                  : _asTrimmedString(item['actorRole']),
              createdAt: _parseTimestamp(item['createdAt']),
            ))
        .where((ProofCheckpointPreview checkpoint) =>
            checkpoint.id.isNotEmpty || checkpoint.summary.isNotEmpty)
        .toList(growable: false);
  }

  List<String> _stringListFromDynamic(dynamic value) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .map(_asTrimmedString)
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
  }

  List<VerificationCheckpointMapping> _checkpointMappingsFromDynamic(
      dynamic value) {
    if (value is! List) {
      return const <VerificationCheckpointMapping>[];
    }
    return value
        .whereType<Map>()
        .map((Map item) => VerificationCheckpointMapping(
              phase: _asTrimmedString(item['phase']),
              guidance: _asTrimmedString(item['guidance']),
            ))
        .where((VerificationCheckpointMapping item) =>
            item.phase.isNotEmpty || item.guidance.isNotEmpty)
        .toList(growable: false);
  }

  List<PortfolioPreviewItem> _parsePortfolioItemsPreview(dynamic value) {
    if (value is! List) return const <PortfolioPreviewItem>[];
    return value
        .whereType<Map>()
        .map((Map item) => PortfolioPreviewItem(
              id: _asTrimmedString(item['id']),
              title: _asTrimmedString(item['title']),
              description: _asTrimmedString(item['description']),
              pillar: _asTrimmedString(item['pillar']).isEmpty
                  ? CurriculumDisplay.legacyFamilyStorageLabel(
                      CurriculumLegacyFamilyCode.future_skills,
                    )
                  : _asTrimmedString(item['pillar']),
              type: _asTrimmedString(item['type']).isEmpty
                  ? 'project'
                  : _asTrimmedString(item['type']),
              completedAt:
                  _parseTimestamp(item['completedAt']) ?? DateTime.now(),
              verificationStatus:
                  _asTrimmedString(item['verificationStatus']).isEmpty
                      ? null
                      : _asTrimmedString(item['verificationStatus']),
              evidenceLinked: item['evidenceLinked'] == true,
              capabilityTitles: List<String>.from(
                item['capabilityTitles'] as List? ?? const <String>[],
              ),
              evidenceRecordIds: List<String>.from(
                item['evidenceRecordIds'] as List? ?? const <String>[],
              ),
              missionAttemptId:
                  _asTrimmedString(item['missionAttemptId']).isEmpty
                      ? null
                      : _asTrimmedString(item['missionAttemptId']),
              verificationPrompt:
                  _asTrimmedString(item['verificationPrompt']).isEmpty
                      ? null
                      : _asTrimmedString(item['verificationPrompt']),
              progressionDescriptors:
                  _stringListFromDynamic(item['progressionDescriptors']),
              checkpointMappings:
                  _checkpointMappingsFromDynamic(item['checkpointMappings']),
              proofOfLearningStatus:
                  _asTrimmedString(item['proofOfLearningStatus']).isEmpty
                      ? null
                      : _asTrimmedString(item['proofOfLearningStatus']),
              aiDisclosureStatus:
                  _asTrimmedString(item['aiDisclosureStatus']).isEmpty
                      ? null
                      : _asTrimmedString(item['aiDisclosureStatus']),
              proofHasExplainItBack: item['proofHasExplainItBack'] == true,
              proofHasOralCheck: item['proofHasOralCheck'] == true,
              proofHasMiniRebuild: item['proofHasMiniRebuild'] == true,
              proofCheckpointCount: _toInt(item['proofCheckpointCount']) ?? 0,
              proofExplainItBackExcerpt:
                  _asTrimmedString(item['proofExplainItBackExcerpt']).isEmpty
                      ? null
                      : _asTrimmedString(item['proofExplainItBackExcerpt']),
              proofOralCheckExcerpt:
                  _asTrimmedString(item['proofOralCheckExcerpt']).isEmpty
                      ? null
                      : _asTrimmedString(item['proofOralCheckExcerpt']),
              proofMiniRebuildExcerpt:
                  _asTrimmedString(item['proofMiniRebuildExcerpt']).isEmpty
                      ? null
                      : _asTrimmedString(item['proofMiniRebuildExcerpt']),
              proofCheckpoints:
                  _parseProofCheckpoints(item['proofCheckpoints']),
              aiHasLearnerDisclosure: item['aiHasLearnerDisclosure'] == true,
              aiLearnerDeclaredUsed: item['aiLearnerDeclaredUsed'] == true,
              aiHelpEventCount: _toInt(item['aiHelpEventCount']) ?? 0,
              aiHasExplainItBackEvidence:
                  item['aiHasExplainItBackEvidence'] == true,
              aiHasEducatorAiFeedback: item['aiHasEducatorAiFeedback'] == true,
              aiAssistanceDetails:
                  _asTrimmedString(item['aiAssistanceDetails']).isEmpty
                      ? null
                      : _asTrimmedString(item['aiAssistanceDetails']),
              reviewingEducatorName:
                  _asTrimmedString(item['reviewingEducatorName']).isEmpty
                      ? null
                      : _asTrimmedString(item['reviewingEducatorName']),
              reviewedAt: _parseTimestamp(item['reviewedAt']),
              rubricRawScore: _toInt(item['rubricRawScore']),
              rubricMaxScore: _toInt(item['rubricMaxScore']),
              rubricLevel: _toInt(item['rubricLevel']),
              aiFeedbackEducatorName:
                  _asTrimmedString(item['aiFeedbackEducatorName']).isEmpty
                      ? null
                      : _asTrimmedString(item['aiFeedbackEducatorName']),
              aiFeedbackAt: _parseTimestamp(item['aiFeedbackAt']),
            ))
        .toList(growable: false);
  }

  IdeationPassport _parseIdeationPassport(dynamic value) {
    if (value is! Map) return const IdeationPassport();
    return IdeationPassport(
      missionAttempts: _toInt(value['missionAttempts']) ?? 0,
      completedMissions: _toInt(value['completedMissions']) ?? 0,
      reflectionsSubmitted: _toInt(value['reflectionsSubmitted']) ?? 0,
      voiceInteractions: _toInt(value['voiceInteractions']) ?? 0,
      collaborationSignals: _toInt(value['collaborationSignals']) ?? 0,
      lastReflectionAt: _parseTimestamp(value['lastReflectionAt']),
      generatedAt: _parseTimestamp(value['generatedAt']),
      summary: _asTrimmedString(value['summary']).isEmpty
          ? null
          : _asTrimmedString(value['summary']),
      claims: _parsePassportClaims(value['claims']),
    );
  }

  List<PassportClaim> _parsePassportClaims(dynamic value) {
    if (value is! List) return const <PassportClaim>[];
    return value
        .whereType<Map>()
        .map((Map item) => PassportClaim(
              capabilityId: _asTrimmedString(item['capabilityId']),
              title: _asTrimmedString(item['title']).isEmpty
                  ? _asTrimmedString(item['capabilityId'])
                  : _asTrimmedString(item['title']),
              pillar: _asTrimmedString(item['pillar']).isEmpty
                  ? CurriculumDisplay.legacyFamilyStorageLabel(
                      CurriculumLegacyFamilyCode.future_skills,
                    )
                  : _asTrimmedString(item['pillar']),
              latestLevel: _toInt(item['latestLevel']) ?? 0,
              evidenceCount: _toInt(item['evidenceCount']) ?? 0,
              verifiedArtifactCount: _toInt(item['verifiedArtifactCount']) ?? 0,
              evidenceRecordIds: List<String>.from(
                item['evidenceRecordIds'] as List? ?? const <String>[],
              ),
              portfolioItemIds: List<String>.from(
                item['portfolioItemIds'] as List? ?? const <String>[],
              ),
              missionAttemptIds: List<String>.from(
                item['missionAttemptIds'] as List? ?? const <String>[],
              ),
              progressionDescriptors:
                  _stringListFromDynamic(item['progressionDescriptors']),
              checkpointMappings:
                  _checkpointMappingsFromDynamic(item['checkpointMappings']),
              proofOfLearningStatus:
                  _asTrimmedString(item['proofOfLearningStatus']).isEmpty
                      ? null
                      : _asTrimmedString(item['proofOfLearningStatus']),
              aiDisclosureStatus:
                  _asTrimmedString(item['aiDisclosureStatus']).isEmpty
                      ? null
                      : _asTrimmedString(item['aiDisclosureStatus']),
              latestEvidenceAt: _parseTimestamp(item['latestEvidenceAt']),
              verificationStatus:
                  _asTrimmedString(item['verificationStatus']).isEmpty
                      ? null
                      : _asTrimmedString(item['verificationStatus']),
              proofHasExplainItBack: item['proofHasExplainItBack'] == true,
              proofHasOralCheck: item['proofHasOralCheck'] == true,
              proofHasMiniRebuild: item['proofHasMiniRebuild'] == true,
              proofCheckpointCount: _toInt(item['proofCheckpointCount']) ?? 0,
              proofExplainItBackExcerpt:
                  _asTrimmedString(item['proofExplainItBackExcerpt']).isEmpty
                      ? null
                      : _asTrimmedString(item['proofExplainItBackExcerpt']),
              proofOralCheckExcerpt:
                  _asTrimmedString(item['proofOralCheckExcerpt']).isEmpty
                      ? null
                      : _asTrimmedString(item['proofOralCheckExcerpt']),
              proofMiniRebuildExcerpt:
                  _asTrimmedString(item['proofMiniRebuildExcerpt']).isEmpty
                      ? null
                      : _asTrimmedString(item['proofMiniRebuildExcerpt']),
              proofCheckpoints:
                  _parseProofCheckpoints(item['proofCheckpoints']),
              aiHasLearnerDisclosure: item['aiHasLearnerDisclosure'] == true,
              aiLearnerDeclaredUsed: item['aiLearnerDeclaredUsed'] == true,
              aiHelpEventCount: _toInt(item['aiHelpEventCount']) ?? 0,
              aiHasExplainItBackEvidence:
                  item['aiHasExplainItBackEvidence'] == true,
              aiHasEducatorAiFeedback: item['aiHasEducatorAiFeedback'] == true,
              aiAssistanceDetails:
                  _asTrimmedString(item['aiAssistanceDetails']).isEmpty
                      ? null
                      : _asTrimmedString(item['aiAssistanceDetails']),
              reviewingEducatorName:
                  _asTrimmedString(item['reviewingEducatorName']).isEmpty
                      ? null
                      : _asTrimmedString(item['reviewingEducatorName']),
              reviewedAt: _parseTimestamp(item['reviewedAt']),
              rubricRawScore: _toInt(item['rubricRawScore']),
              rubricMaxScore: _toInt(item['rubricMaxScore']),
              aiFeedbackEducatorName:
                  _asTrimmedString(item['aiFeedbackEducatorName']).isEmpty
                      ? null
                      : _asTrimmedString(item['aiFeedbackEducatorName']),
              aiFeedbackAt: _parseTimestamp(item['aiFeedbackAt']),
            ))
        .where((PassportClaim claim) => claim.capabilityId.isNotEmpty)
        .toList(growable: false);
  }

  EvidenceSummary _buildEvidenceSummary(List<Map<String, dynamic>> rows) {
    final List<DateTime> evidenceDates = rows
        .map((Map<String, dynamic> row) =>
            _parseTimestamp(row['observedAt']) ??
            _parseTimestamp(row['growthUpdatedAt']) ??
            _parseTimestamp(row['createdAt']))
        .whereType<DateTime>()
        .toList(growable: false);
    final int reviewedCount = rows.where((Map<String, dynamic> row) {
      final String rubricStatus = _asTrimmedString(row['rubricStatus']);
      final String growthStatus = _asTrimmedString(row['growthStatus']);
      return rubricStatus == 'linked' ||
          rubricStatus == 'applied' ||
          growthStatus == 'updated' ||
          growthStatus == 'recorded';
    }).length;
    final int portfolioLinkedCount = rows.where((Map<String, dynamic> row) {
      return _asTrimmedString(row['linkedPortfolioItemId']).isNotEmpty ||
          _asTrimmedString(row['portfolioStatus']) == 'linked';
    }).length;
    final int verificationPromptCount = rows.where((Map<String, dynamic> row) {
      return _asTrimmedString(row['nextVerificationPrompt']).isNotEmpty;
    }).length;
    evidenceDates.sort((DateTime a, DateTime b) => b.compareTo(a));
    return EvidenceSummary(
      recordCount: rows.length,
      reviewedCount: reviewedCount,
      portfolioLinkedCount: portfolioLinkedCount,
      verificationPromptCount: verificationPromptCount,
      latestEvidenceAt: evidenceDates.isEmpty ? null : evidenceDates.first,
    );
  }

  GrowthSummary _buildGrowthSummary(
    List<Map<String, dynamic>> masteryRows,
    List<Map<String, dynamic>> growthRows,
  ) {
    final List<int> levels = masteryRows
        .map((Map<String, dynamic> row) => _toInt(row['latestLevel']) ?? 0)
        .where((int value) => value > 0)
        .toList(growable: false);
    final double averageLevel = levels.isEmpty
        ? 0
        : levels.reduce((int a, int b) => a + b) / levels.length;
    final List<DateTime> growthDates = growthRows
        .map((Map<String, dynamic> row) => _parseTimestamp(row['createdAt']))
        .whereType<DateTime>()
        .toList(growable: false);
    growthDates.sort((DateTime a, DateTime b) => b.compareTo(a));
    final List<int> latestLevels = growthRows
        .map((Map<String, dynamic> row) => _toInt(row['level']) ?? 0)
        .where((int value) => value > 0)
        .toList(growable: false);
    return GrowthSummary(
      capabilityCount: masteryRows.length,
      updatedCapabilityCount: growthRows
          .map((Map<String, dynamic> row) =>
              _asTrimmedString(row['capabilityId']))
          .where((String value) => value.isNotEmpty)
          .toSet()
          .length,
      averageLevel: averageLevel,
      latestLevel: latestLevels.isEmpty ? 0 : latestLevels.first,
      latestGrowthAt: growthDates.isEmpty ? null : growthDates.first,
    );
  }

  List<GrowthTimelineEntry> _buildGrowthTimeline(
    List<Map<String, dynamic>> masteryRows,
    List<Map<String, dynamic>> evidenceRows,
    List<Map<String, dynamic>> growthRows,
    List<Map<String, dynamic>> portfolioRows,
    Map<String, String> reviewerNames,
  ) {
    final Map<String, String> masteryPillars = <String, String>{
      for (final Map<String, dynamic> row in masteryRows)
        _asTrimmedString(row['capabilityId']): _pillarLabelFromCodes(<String>[
          _asTrimmedString(row['pillarCode']),
        ]),
    };
    final Map<String, String> evidenceTitles = <String, String>{
      for (final Map<String, dynamic> row in evidenceRows)
        if (_asTrimmedString(row['capabilityId']).isNotEmpty &&
            _asTrimmedString(row['capabilityLabel']).isNotEmpty)
          _asTrimmedString(row['capabilityId']):
              _asTrimmedString(row['capabilityLabel']),
    };
    final Map<String, String> portfolioTitles = <String, String>{};
    for (final Map<String, dynamic> row in portfolioRows) {
      final List<String> capabilityIds =
          List<String>.from(row['capabilityIds'] as List? ?? const <String>[]);
      final List<String> capabilityTitles = List<String>.from(
        row['capabilityTitles'] as List? ?? const <String>[],
      );
      for (int index = 0; index < capabilityIds.length; index++) {
        final String capabilityId = capabilityIds[index].trim();
        if (capabilityId.isEmpty) {
          continue;
        }
        final String title = index < capabilityTitles.length
            ? capabilityTitles[index].trim()
            : '';
        if (title.isNotEmpty) {
          portfolioTitles[capabilityId] = title;
        }
      }
    }
    final List<GrowthTimelineEntry> entries = growthRows
        .map((Map<String, dynamic> row) {
          final String capabilityId = _asTrimmedString(row['capabilityId']);
          final String title = portfolioTitles[capabilityId] ??
              evidenceTitles[capabilityId] ??
              capabilityId;
          final String pillar = _pillarLabelFromCodes(<String>[
            _asTrimmedString(row['pillarCode']),
            masteryPillars[capabilityId] ?? '',
          ]);
          final String reviewerId = _asTrimmedString(row['educatorId']);
          return GrowthTimelineEntry(
            capabilityId: capabilityId,
            title: title,
            pillar: pillar,
            level: _toInt(row['level']) ?? 0,
            linkedEvidenceRecordIds: List<String>.from(
              row['linkedEvidenceRecordIds'] as List? ?? const <String>[],
            ),
            linkedPortfolioItemIds: List<String>.from(
              row['linkedPortfolioItemIds'] as List? ?? const <String>[],
            ),
            proofOfLearningStatus:
                _asTrimmedString(row['proofOfLearningStatus']).isEmpty
                    ? null
                    : _asTrimmedString(row['proofOfLearningStatus']),
            occurredAt: _parseTimestamp(row['createdAt']),
            reviewingEducatorName: reviewerNames[reviewerId],
            rubricRawScore: _toInt(row['rawScore']),
            rubricMaxScore: _toInt(row['maxScore']),
            missionAttemptId: _asTrimmedString(row['missionAttemptId']).isEmpty
                ? null
                : _asTrimmedString(row['missionAttemptId']),
          );
        })
        .where((GrowthTimelineEntry entry) => entry.capabilityId.isNotEmpty)
        .toList(growable: false)
      ..sort((GrowthTimelineEntry a, GrowthTimelineEntry b) {
        final DateTime aDate = a.occurredAt ?? DateTime(1970);
        final DateTime bDate = b.occurredAt ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });
    return entries;
  }

  List<ProofCheckpointPreview> _buildProofCheckpoints(
      Map<String, dynamic>? proofBundle) {
    if (proofBundle == null) {
      return const <ProofCheckpointPreview>[];
    }
    final List<ProofCheckpointPreview> checkpoints =
        ((proofBundle['versionHistory'] as List?) ?? const <dynamic>[])
            .whereType<Map>()
            .map((Map item) => ProofCheckpointPreview(
                  id: _asTrimmedString(item['id']),
                  summary: _asTrimmedString(item['summary']),
                  artifactNote: _asTrimmedString(item['artifactNote']).isEmpty
                      ? null
                      : _asTrimmedString(item['artifactNote']),
                  actorId: _asTrimmedString(item['actorId']).isEmpty
                      ? null
                      : _asTrimmedString(item['actorId']),
                  actorRole: _asTrimmedString(item['actorRole']).isEmpty
                      ? null
                      : _asTrimmedString(item['actorRole']),
                  createdAt: _parseTimestamp(item['createdAt']),
                ))
            .where((ProofCheckpointPreview checkpoint) =>
                checkpoint.id.isNotEmpty || checkpoint.summary.isNotEmpty)
            .toList(growable: false)
          ..sort((ProofCheckpointPreview a, ProofCheckpointPreview b) {
            final DateTime aDate = a.createdAt ?? DateTime(1970);
            final DateTime bDate = b.createdAt ?? DateTime(1970);
            return aDate.compareTo(bDate);
          });
    return checkpoints;
  }

  CapabilitySnapshot _buildCapabilitySnapshot(List<Map<String, dynamic>> rows) {
    double sumForPillar(String pillarCode) {
      final List<double> values = rows
          .where((Map<String, dynamic> row) =>
              _normalizePillarCode(_asTrimmedString(row['pillarCode'])) ==
              pillarCode)
          .map((Map<String, dynamic> row) =>
              (((_toDouble(row['latestLevel']) ?? 0) / 4).clamp(0, 1))
                  .toDouble())
          .toList(growable: false);
      if (values.isEmpty) {
        return 0;
      }
      return values.reduce((double a, double b) => a + b) / values.length;
    }

    final double futureSkills = sumForPillar('futureSkills');
    final double leadership = sumForPillar('leadership');
    final double impact = sumForPillar('impact');
    final List<double> nonZero = <double>[futureSkills, leadership, impact]
        .where((double value) => value > 0)
        .toList(growable: false);
    final double overall = nonZero.isEmpty
        ? 0
        : nonZero.reduce((double a, double b) => a + b) / nonZero.length;
    final String band = overall >= 0.75
        ? 'strong'
        : overall >= 0.45
            ? 'developing'
            : 'emerging';
    return CapabilitySnapshot(
      futureSkills: futureSkills,
      leadership: leadership,
      impact: impact,
      overall: overall,
      band: band,
    );
  }

  PortfolioSnapshot _buildPortfolioSnapshot(List<Map<String, dynamic>> rows) {
    final int artifactCount = rows.length;
    final int evidenceLinkedArtifactCount =
        rows.where((Map<String, dynamic> row) {
      final List<dynamic> evidenceRecordIds =
          row['evidenceRecordIds'] as List<dynamic>? ?? <dynamic>[];
      return evidenceRecordIds.isNotEmpty;
    }).length;
    final int verifiedArtifactCount = rows.where((Map<String, dynamic> row) {
      final String verificationStatus =
          _asTrimmedString(row['verificationStatus']).toLowerCase();
      return verificationStatus == 'reviewed' ||
          verificationStatus == 'verified';
    }).length;
    final int badgeCount = rows.where((Map<String, dynamic> row) {
      final String title = _asTrimmedString(row['title']).toLowerCase();
      return title.contains('badge');
    }).length;
    final List<DateTime> artifactDates = rows
        .map((Map<String, dynamic> row) =>
            _parseTimestamp(row['updatedAt']) ??
            _parseTimestamp(row['createdAt']))
        .whereType<DateTime>()
        .toList(growable: false);
    artifactDates.sort((DateTime a, DateTime b) => b.compareTo(a));
    return PortfolioSnapshot(
      artifactCount: artifactCount,
      publishedArtifactCount: verifiedArtifactCount,
      badgeCount: badgeCount,
      projectCount: artifactCount - badgeCount,
      evidenceLinkedArtifactCount: evidenceLinkedArtifactCount,
      verifiedArtifactCount: verifiedArtifactCount,
      latestArtifactAt: artifactDates.isEmpty ? null : artifactDates.first,
    );
  }

  List<PortfolioPreviewItem> _buildPortfolioPreviewItems(
    List<Map<String, dynamic>> rows,
    List<Map<String, dynamic>> missionAttemptRows,
    List<Map<String, dynamic>> interactionEventRows,
    List<Map<String, dynamic>> growthRows,
    Map<String, String> reviewerNames,
    Map<String, Map<String, dynamic>> proofBundleDetails,
  ) {
    final List<PortfolioPreviewItem> items =
        rows.map((Map<String, dynamic> row) {
      final String missionAttemptId = _asTrimmedString(row['missionAttemptId']);
      final Map<String, dynamic>? matchingMissionAttempt =
          missionAttemptId.isEmpty
              ? null
              : missionAttemptRows.cast<Map<String, dynamic>?>().firstWhere(
                    (Map<String, dynamic>? attempt) =>
                        attempt != null &&
                        _asTrimmedString(attempt['id']) == missionAttemptId,
                    orElse: () => null,
                  );
      final String sessionOccurrenceId = matchingMissionAttempt == null
          ? ''
          : _asTrimmedString(matchingMissionAttempt['sessionOccurrenceId']);
      final List<Map<String, dynamic>> matchingInteractionEvents =
          sessionOccurrenceId.isEmpty
              ? const <Map<String, dynamic>>[]
              : interactionEventRows.where((Map<String, dynamic> event) {
                  return _asTrimmedString(event['sessionOccurrenceId']) ==
                      sessionOccurrenceId;
                }).toList(growable: false);
      final Map<dynamic, dynamic>? proofBundleSummary =
          matchingMissionAttempt == null
              ? null
              : matchingMissionAttempt['proofBundleSummary']
                  as Map<dynamic, dynamic>?;
      final String proofBundleId = _asTrimmedString(
        row['proofBundleId'] ??
            (matchingMissionAttempt == null
                ? null
                : matchingMissionAttempt['proofBundleId']),
      );
      final Map<String, dynamic>? proofBundle =
          proofBundleId.isEmpty ? null : proofBundleDetails[proofBundleId];
      final bool hasExplainItBack =
          proofBundleSummary?['hasExplainItBack'] == true;
      final bool hasOralCheck = proofBundleSummary?['hasOralCheck'] == true;
      final bool hasMiniRebuild = proofBundleSummary?['hasMiniRebuild'] == true;
      final int proofCheckpointCount =
          _toInt(proofBundleSummary?['checkpointCount']) ??
              ((proofBundle?['versionHistory'] as List?)?.length ?? 0);
      final bool hasLearnerAiDisclosure =
          proofBundleSummary?['hasLearnerAiDisclosure'] == true;
      final bool learnerAiDeclaredUsed =
          proofBundleSummary?['aiAssistanceUsed'] == true;
      final String directProofOfLearningStatus =
          _asTrimmedString(row['proofOfLearningStatus']);
      final String proofOfLearningStatus =
          directProofOfLearningStatus.isNotEmpty
              ? directProofOfLearningStatus
              : matchingMissionAttempt == null
                  ? 'not-available'
                  : hasExplainItBack && hasOralCheck && hasMiniRebuild
                      ? 'verified'
                      : hasExplainItBack || hasOralCheck || hasMiniRebuild
                          ? 'partial'
                          : 'missing';
      final int learnerAiEventCount = matchingInteractionEvents.where(
        (Map<String, dynamic> event) {
          final String eventType =
              _asTrimmedString(event['eventType']).toLowerCase();
          return eventType == 'ai_help_used' || eventType == 'ai_help_opened';
        },
      ).length;
      final bool hasLearnerExplainBackEvent = matchingInteractionEvents.any(
        (Map<String, dynamic> event) =>
            _asTrimmedString(event['eventType']).toLowerCase() ==
            'explain_it_back_submitted',
      );
      final bool hasAiFeedbackSignal =
          _asTrimmedString(row['aiFeedbackDraft']).isNotEmpty ||
              _asTrimmedString(row['aiFeedbackBy']).isNotEmpty ||
              _parseTimestamp(row['aiFeedbackAt']) != null ||
              (matchingMissionAttempt != null &&
                  (_asTrimmedString(
                              matchingMissionAttempt['aiFeedbackDraft'])
                          .isNotEmpty ||
                      _asTrimmedString(matchingMissionAttempt['aiFeedbackBy'])
                          .isNotEmpty ||
                      _parseTimestamp(matchingMissionAttempt['aiFeedbackAt']) !=
                          null));
      final String directAiDisclosureStatus =
          _asTrimmedString(row['aiDisclosureStatus']);
      final String aiAssistanceDetails = _asTrimmedString(
        row['aiAssistanceDetails'] ??
            (matchingMissionAttempt == null
                ? null
                : matchingMissionAttempt['aiAssistanceDetails']) ??
            proofBundle?['aiAssistanceDetails'],
      );
      final List<String> growthEventIds = List<String>.from(
        row['growthEventIds'] as List? ?? const <String>[],
      );
      final List<Map<String, dynamic>> matchingGrowth =
          growthRows.where((Map<String, dynamic> event) {
        final String growthId = _asTrimmedString(event['id']);
        final String growthMissionAttemptId =
            _asTrimmedString(event['missionAttemptId']);
        return (growthId.isNotEmpty && growthEventIds.contains(growthId)) ||
            (missionAttemptId.isNotEmpty &&
                growthMissionAttemptId == missionAttemptId);
      }).toList(growable: false)
            ..sort((Map<String, dynamic> a, Map<String, dynamic> b) {
              final DateTime aTimestamp =
                  _parseTimestamp(a['createdAt']) ?? DateTime(1970);
              final DateTime bTimestamp =
                  _parseTimestamp(b['createdAt']) ?? DateTime(1970);
              return bTimestamp.compareTo(aTimestamp);
            });
      final Map<String, dynamic>? latestGrowth =
          matchingGrowth.isEmpty ? null : matchingGrowth.first;
      final String reviewerId = latestGrowth == null
          ? _asTrimmedString(
              row['educatorId'] ??
                  (matchingMissionAttempt == null
                      ? null
                      : matchingMissionAttempt['reviewedBy']),
            )
          : _asTrimmedString(latestGrowth['educatorId']);
      final String reviewerName = reviewerNames[reviewerId] ?? '';
      final DateTime? reviewedAt = latestGrowth == null
          ? _parseTimestamp(
              row['updatedAt'] ??
                  row['reviewedAt'] ??
                  (matchingMissionAttempt == null
                      ? null
                      : matchingMissionAttempt['reviewedAt']),
            )
          : _parseTimestamp(latestGrowth['createdAt']);
      final int? rubricRawScore = latestGrowth == null
          ? _toInt(
              row['rubricTotalScore'] ??
                  (matchingMissionAttempt == null
                      ? null
                      : matchingMissionAttempt['rubricTotalScore']),
            )
          : _toInt(latestGrowth['rawScore']);
      final int? rubricMaxScore = latestGrowth == null
          ? _toInt(
              row['rubricMaxScore'] ??
                  (matchingMissionAttempt == null
                      ? null
                      : matchingMissionAttempt['rubricMaxScore']),
            )
          : _toInt(latestGrowth['maxScore']);
      final int? rubricLevel =
          latestGrowth == null ? null : _toInt(latestGrowth['level']);
      final String aiFeedbackEducatorId = _asTrimmedString(
        row['aiFeedbackBy'] ??
            (matchingMissionAttempt == null
                ? null
                : matchingMissionAttempt['aiFeedbackBy']),
      );
      final String? aiFeedbackEducatorName = aiFeedbackEducatorId.isEmpty
          ? (hasAiFeedbackSignal && reviewerName.isNotEmpty
              ? reviewerName
              : null)
          : reviewerNames[aiFeedbackEducatorId] ??
              (reviewerName.isEmpty ? null : reviewerName);
      final DateTime? aiFeedbackAt = _parseTimestamp(
            row['aiFeedbackAt'] ??
                (matchingMissionAttempt == null
                    ? null
                    : matchingMissionAttempt['aiFeedbackAt']),
          ) ??
          (hasAiFeedbackSignal ? reviewedAt : null);
      final String aiDisclosureStatus = directAiDisclosureStatus.isNotEmpty
          ? directAiDisclosureStatus
          : hasLearnerAiDisclosure
              ? learnerAiDeclaredUsed
                  ? hasExplainItBack
                      ? 'learner-ai-verified'
                      : 'learner-ai-verification-gap'
                  : 'learner-ai-not-used'
              : learnerAiEventCount > 0
                  ? hasLearnerExplainBackEvent
                      ? 'learner-ai-verified'
                      : 'learner-ai-verification-gap'
                  : hasAiFeedbackSignal
                      ? 'educator-feedback-ai'
                      : matchingMissionAttempt != null
                          ? 'no-learner-ai-signal'
                          : 'not-available';
      final List<String> progressionDescriptors = _stringListFromDynamic(
                  row['progressionDescriptors'])
              .isNotEmpty
          ? _stringListFromDynamic(row['progressionDescriptors'])
          : latestGrowth == null
              ? const <String>[]
              : _stringListFromDynamic(latestGrowth['progressionDescriptors']);
      final List<VerificationCheckpointMapping> checkpointMappings =
          _checkpointMappingsFromDynamic(row['checkpointMappings']).isNotEmpty
              ? _checkpointMappingsFromDynamic(row['checkpointMappings'])
              : latestGrowth == null
                  ? const <VerificationCheckpointMapping>[]
                  : _checkpointMappingsFromDynamic(
                      latestGrowth['checkpointMappings'],
                    );
      return PortfolioPreviewItem(
        id: _asTrimmedString(row['id']),
        title: _asTrimmedString(row['title']).isEmpty
            ? 'Portfolio artifact'
            : _asTrimmedString(row['title']),
        description: _asTrimmedString(row['description']).isEmpty
            ? 'Evidence-backed portfolio artifact.'
            : _asTrimmedString(row['description']),
        pillar: _pillarLabelFromCodes(
          List<String>.from(row['pillarCodes'] as List? ?? const <String>[]),
        ),
        type: _asTrimmedString(row['title']).toLowerCase().contains('badge')
            ? 'badge'
            : 'project',
        completedAt: _parseTimestamp(row['updatedAt']) ??
            _parseTimestamp(row['createdAt']) ??
            DateTime.now(),
        verificationStatus: _asTrimmedString(row['verificationStatus']).isEmpty
            ? null
            : _asTrimmedString(row['verificationStatus']),
        evidenceLinked:
            (row['evidenceRecordIds'] as List<dynamic>? ?? <dynamic>[])
                .isNotEmpty,
        capabilityTitles: List<String>.from(
          row['capabilityTitles'] as List? ?? const <String>[],
        ),
        evidenceRecordIds: List<String>.from(
          row['evidenceRecordIds'] as List? ?? const <String>[],
        ),
        missionAttemptId: missionAttemptId.isEmpty ? null : missionAttemptId,
        verificationPrompt: _asTrimmedString(row['verificationPrompt']).isEmpty
            ? null
            : _asTrimmedString(row['verificationPrompt']),
        progressionDescriptors: progressionDescriptors,
        checkpointMappings: checkpointMappings,
        proofOfLearningStatus: proofOfLearningStatus,
        aiDisclosureStatus: aiDisclosureStatus,
        proofHasExplainItBack: hasExplainItBack,
        proofHasOralCheck: hasOralCheck,
        proofHasMiniRebuild: hasMiniRebuild,
        proofCheckpointCount: proofCheckpointCount,
        proofExplainItBackExcerpt: _excerpt(
          proofBundle == null ? null : proofBundle['explainItBack'] as String?,
        ),
        proofOralCheckExcerpt: _excerpt(
          proofBundle == null
              ? null
              : proofBundle['oralCheckResponse'] as String?,
        ),
        proofMiniRebuildExcerpt: _excerpt(
          proofBundle == null
              ? null
              : proofBundle['miniRebuildPlan'] as String?,
        ),
        proofCheckpoints: _buildProofCheckpoints(proofBundle),
        aiHasLearnerDisclosure: hasLearnerAiDisclosure,
        aiLearnerDeclaredUsed: learnerAiDeclaredUsed,
        aiHelpEventCount: learnerAiEventCount,
        aiHasExplainItBackEvidence:
            hasExplainItBack || hasLearnerExplainBackEvent,
        aiHasEducatorAiFeedback: hasAiFeedbackSignal,
        aiAssistanceDetails:
            aiAssistanceDetails.isEmpty ? null : aiAssistanceDetails,
        reviewingEducatorName: reviewerName.isEmpty ? null : reviewerName,
        reviewedAt: reviewedAt,
        rubricRawScore: rubricRawScore,
        rubricMaxScore: rubricMaxScore,
        rubricLevel: rubricLevel,
        aiFeedbackEducatorName: aiFeedbackEducatorName,
        aiFeedbackAt: aiFeedbackAt,
      );
    }).toList(growable: false);
    items.sort((PortfolioPreviewItem a, PortfolioPreviewItem b) =>
        b.completedAt.compareTo(a.completedAt));
    return items;
  }

  IdeationPassport _buildIdeationPassport(
    List<Map<String, dynamic>> missionAttemptRows,
    List<Map<String, dynamic>> interactionEventRows,
    List<Map<String, dynamic>> reflectionRows,
    List<Map<String, dynamic>> evidenceRows,
    List<Map<String, dynamic>> masteryRows,
    List<Map<String, dynamic>> growthRows,
    List<Map<String, dynamic>> portfolioRows,
    Map<String, String> reviewerNames,
    Map<String, Map<String, dynamic>> proofBundleDetails,
  ) {
    final int completedMissions =
        missionAttemptRows.where((Map<String, dynamic> row) {
      final String status = _asTrimmedString(row['status']).toLowerCase();
      return status == 'reviewed' ||
          status == 'completed' ||
          status == 'approved';
    }).length;
    final int voiceInteractions =
        missionAttemptRows.where((Map<String, dynamic> row) {
      final Map<dynamic, dynamic>? proofBundleSummary =
          row['proofBundleSummary'] as Map<dynamic, dynamic>?;
      return proofBundleSummary?['hasOralCheck'] == true;
    }).length;
    final int collaborationSignals =
        reflectionRows.where((Map<String, dynamic> row) {
      final String reflectionType = _asTrimmedString(row['reflectionType']);
      return reflectionType == 'shout_out' || reflectionType == 'weekly_review';
    }).length;
    final List<DateTime> reflectionDates = reflectionRows
        .map((Map<String, dynamic> row) => _parseTimestamp(row['createdAt']))
        .whereType<DateTime>()
        .toList(growable: false);
    reflectionDates.sort((DateTime a, DateTime b) => b.compareTo(a));
    final List<PassportClaim> claims = _buildPassportClaims(
      missionAttemptRows,
      interactionEventRows,
      evidenceRows,
      masteryRows,
      growthRows,
      portfolioRows,
      reviewerNames,
      proofBundleDetails,
    );
    return IdeationPassport(
      missionAttempts: missionAttemptRows.length,
      completedMissions: completedMissions,
      reflectionsSubmitted: reflectionRows.length,
      voiceInteractions: voiceInteractions,
      collaborationSignals: collaborationSignals,
      lastReflectionAt: reflectionDates.isEmpty ? null : reflectionDates.first,
      generatedAt: DateTime.now(),
      summary: claims.isEmpty
          ? 'No capability claims backed by reviewed evidence are available yet.'
          : '${claims.length} capability claims are backed by reviewed evidence and reviewed or verified artifacts.',
      claims: claims,
    );
  }

  List<PassportClaim> _buildPassportClaims(
    List<Map<String, dynamic>> missionAttemptRows,
    List<Map<String, dynamic>> interactionEventRows,
    List<Map<String, dynamic>> evidenceRows,
    List<Map<String, dynamic>> masteryRows,
    List<Map<String, dynamic>> growthRows,
    List<Map<String, dynamic>> portfolioRows,
    Map<String, String> reviewerNames,
    Map<String, Map<String, dynamic>> proofBundleDetails,
  ) {
    final List<PassportClaim> claims = <PassportClaim>[];
    for (final Map<String, dynamic> mastery in masteryRows) {
      final String capabilityId = _asTrimmedString(mastery['capabilityId']);
      if (capabilityId.isEmpty) {
        continue;
      }
      final List<Map<String, dynamic>> matchingEvidence = evidenceRows
          .where((Map<String, dynamic> row) =>
              _asTrimmedString(row['capabilityId']) == capabilityId)
          .toList(growable: false);
      final List<Map<String, dynamic>> matchingPortfolio = portfolioRows
          .where((Map<String, dynamic> row) => List<String>.from(
                row['capabilityIds'] as List? ?? const <String>[],
              ).contains(capabilityId))
          .toList(growable: false);
      final List<Map<String, dynamic>> matchingGrowth = growthRows
          .where((Map<String, dynamic> row) =>
              _asTrimmedString(row['capabilityId']) == capabilityId)
          .toList(growable: false)
        ..sort((Map<String, dynamic> a, Map<String, dynamic> b) {
          final DateTime aTimestamp =
              _parseTimestamp(a['createdAt']) ?? DateTime(1970);
          final DateTime bTimestamp =
              _parseTimestamp(b['createdAt']) ?? DateTime(1970);
          return bTimestamp.compareTo(aTimestamp);
        });
      final List<Map<String, dynamic>> matchingPortfolioByRecency =
          List<Map<String, dynamic>>.from(matchingPortfolio)
            ..sort((Map<String, dynamic> a, Map<String, dynamic> b) {
              final DateTime aTimestamp = _parseTimestamp(a['updatedAt']) ??
                  _parseTimestamp(a['createdAt']) ??
                  DateTime(1970);
              final DateTime bTimestamp = _parseTimestamp(b['updatedAt']) ??
                  _parseTimestamp(b['createdAt']) ??
                  DateTime(1970);
              return bTimestamp.compareTo(aTimestamp);
            });
      final Set<String> missionAttemptIds = <String>{
        _asTrimmedString(mastery['latestMissionAttemptId']),
        ...matchingEvidence.map(
          (Map<String, dynamic> row) =>
              _asTrimmedString(row['linkedMissionAttemptId']),
        ),
        ...matchingGrowth.map(
          (Map<String, dynamic> row) =>
              _asTrimmedString(row['missionAttemptId']),
        ),
        ...matchingPortfolio.map(
          (Map<String, dynamic> row) =>
              _asTrimmedString(row['missionAttemptId']),
        ),
      }..removeWhere((String value) => value.isEmpty);
      final List<Map<String, dynamic>> matchingMissionAttempts =
          missionAttemptRows.where((Map<String, dynamic> row) {
        return missionAttemptIds.contains(_asTrimmedString(row['id']));
      }).toList(growable: false);
      final Set<String> sessionOccurrenceIds = matchingMissionAttempts
          .map((Map<String, dynamic> row) =>
              _asTrimmedString(row['sessionOccurrenceId']))
          .where((String value) => value.isNotEmpty)
          .toSet();
      final List<Map<String, dynamic>> matchingInteractionEvents =
          interactionEventRows.where((Map<String, dynamic> row) {
        return sessionOccurrenceIds.contains(
          _asTrimmedString(row['sessionOccurrenceId']),
        );
      }).toList(growable: false);
      final String title = <String>[
        ...matchingPortfolio
            .expand((Map<String, dynamic> row) => List<String>.from(
                  row['capabilityTitles'] as List? ?? const <String>[],
                )),
        ...matchingEvidence.map((Map<String, dynamic> row) =>
            _asTrimmedString(row['capabilityLabel'])),
      ].firstWhere(
        (String value) => value.trim().isNotEmpty,
        orElse: () => capabilityId,
      );
      final List<DateTime> evidenceDates = <DateTime>[
        ...matchingEvidence
            .map((Map<String, dynamic> row) =>
                _parseTimestamp(row['observedAt']))
            .whereType<DateTime>(),
        ...matchingGrowth
            .map(
                (Map<String, dynamic> row) => _parseTimestamp(row['createdAt']))
            .whereType<DateTime>(),
      ]..sort((DateTime a, DateTime b) => b.compareTo(a));
      final int verifiedArtifactCount =
          matchingPortfolio.where((Map<String, dynamic> row) {
        final String verificationStatus =
            _asTrimmedString(row['verificationStatus']).toLowerCase();
        return verificationStatus == 'reviewed' ||
            verificationStatus == 'verified';
      }).length;
      final String directProofOfLearningStatus = matchingPortfolioByRecency
          .map((Map<String, dynamic> row) =>
              _asTrimmedString(row['proofOfLearningStatus']))
          .firstWhere(
            (String value) => value.isNotEmpty,
            orElse: () => '',
          );
      final String directAiDisclosureStatus = matchingPortfolioByRecency
          .map((Map<String, dynamic> row) =>
              _asTrimmedString(row['aiDisclosureStatus']))
          .firstWhere(
            (String value) => value.isNotEmpty,
            orElse: () => '',
          );
      final bool hasExplainItBack =
          matchingMissionAttempts.any((Map<String, dynamic> row) {
        final Map<dynamic, dynamic>? summary =
            row['proofBundleSummary'] as Map<dynamic, dynamic>?;
        return summary?['hasExplainItBack'] == true;
      });
      final bool hasOralCheck =
          matchingMissionAttempts.any((Map<String, dynamic> row) {
        final Map<dynamic, dynamic>? summary =
            row['proofBundleSummary'] as Map<dynamic, dynamic>?;
        return summary?['hasOralCheck'] == true;
      });
      final bool hasMiniRebuild =
          matchingMissionAttempts.any((Map<String, dynamic> row) {
        final Map<dynamic, dynamic>? summary =
            row['proofBundleSummary'] as Map<dynamic, dynamic>?;
        return summary?['hasMiniRebuild'] == true;
      });
      final bool hasLearnerAiDisclosure = matchingMissionAttempts.any(
        (Map<String, dynamic> row) {
          final Map<dynamic, dynamic>? summary =
              row['proofBundleSummary'] as Map<dynamic, dynamic>?;
          return summary?['hasLearnerAiDisclosure'] == true;
        },
      );
      final bool learnerAiDeclaredUsed = matchingMissionAttempts.any(
        (Map<String, dynamic> row) {
          final Map<dynamic, dynamic>? summary =
              row['proofBundleSummary'] as Map<dynamic, dynamic>?;
          return summary?['aiAssistanceUsed'] == true;
        },
      );
      final String proofOfLearningStatus =
          directProofOfLearningStatus.isNotEmpty
              ? directProofOfLearningStatus
              : hasExplainItBack && hasOralCheck && hasMiniRebuild
                  ? 'verified'
                  : hasExplainItBack || hasOralCheck || hasMiniRebuild
                      ? 'partial'
                      : 'missing';
      final bool hasAiFeedbackSignal = matchingMissionAttempts.any(
            (Map<String, dynamic> row) =>
                _asTrimmedString(row['aiFeedbackDraft']).isNotEmpty ||
                _asTrimmedString(row['aiFeedbackBy']).isNotEmpty ||
                _parseTimestamp(row['aiFeedbackAt']) != null,
          ) ||
          matchingPortfolioByRecency.any(
            (Map<String, dynamic> row) =>
                _asTrimmedString(row['aiFeedbackDraft']).isNotEmpty ||
                _asTrimmedString(row['aiFeedbackBy']).isNotEmpty ||
                _parseTimestamp(row['aiFeedbackAt']) != null,
          );
      final int learnerAiEventCount = matchingInteractionEvents.where(
        (Map<String, dynamic> row) {
          final String eventType =
              _asTrimmedString(row['eventType']).toLowerCase();
          return eventType == 'ai_help_used' || eventType == 'ai_help_opened';
        },
      ).length;
      final bool hasLearnerExplainBackEvent = matchingInteractionEvents.any(
        (Map<String, dynamic> row) =>
            _asTrimmedString(row['eventType']).toLowerCase() ==
            'explain_it_back_submitted',
      );
      final String aiDisclosureStatus = directAiDisclosureStatus.isNotEmpty
          ? directAiDisclosureStatus
          : hasLearnerAiDisclosure
              ? learnerAiDeclaredUsed
                  ? hasExplainItBack
                      ? 'learner-ai-verified'
                      : 'learner-ai-verification-gap'
                  : 'learner-ai-not-used'
              : learnerAiEventCount > 0
                  ? hasLearnerExplainBackEvent
                      ? 'learner-ai-verified'
                      : 'learner-ai-verification-gap'
                  : hasAiFeedbackSignal
                      ? 'educator-feedback-ai'
                      : matchingMissionAttempts.isNotEmpty
                          ? 'no-learner-ai-signal'
                          : 'not-available';
      final Map<String, dynamic>? latestGrowth =
          matchingGrowth.isEmpty ? null : matchingGrowth.first;
      final Map<String, dynamic>? latestMissionAttempt =
          matchingMissionAttempts.isEmpty
              ? null
              : matchingMissionAttempts.first;
      final Map<String, dynamic>? latestPortfolio =
          matchingPortfolioByRecency.isEmpty
              ? null
              : matchingPortfolioByRecency.first;
      final String proofBundleId = _asTrimmedString(
        latestPortfolio?['proofBundleId'] ??
            latestMissionAttempt?['proofBundleId'],
      );
      final Map<String, dynamic>? proofBundle =
          proofBundleId.isEmpty ? null : proofBundleDetails[proofBundleId];
      final int proofCheckpointCount =
          matchingMissionAttempts.map((Map<String, dynamic> row) {
        final Map<dynamic, dynamic>? summary =
            row['proofBundleSummary'] as Map<dynamic, dynamic>?;
        return _toInt(summary?['checkpointCount']) ?? 0;
      }).fold<int>(0, math.max);
      final String reviewerId = latestGrowth == null
          ? _asTrimmedString(
              latestPortfolio?['educatorId'] ??
                  latestMissionAttempt?['reviewedBy'],
            )
          : _asTrimmedString(latestGrowth['educatorId']);
      final String reviewerName = reviewerNames[reviewerId] ?? '';
      final DateTime? reviewedAt = latestGrowth == null
          ? _parseTimestamp(
              latestPortfolio?['updatedAt'] ??
                  latestPortfolio?['reviewedAt'] ??
                  latestMissionAttempt?['reviewedAt'],
            )
          : _parseTimestamp(latestGrowth['createdAt']);
      final int? rubricRawScore = latestGrowth == null
          ? _toInt(
              latestPortfolio?['rubricTotalScore'] ??
                  latestMissionAttempt?['rubricTotalScore'],
            )
          : _toInt(latestGrowth['rawScore']);
      final int? rubricMaxScore = latestGrowth == null
          ? _toInt(
              latestPortfolio?['rubricMaxScore'] ??
                  latestMissionAttempt?['rubricMaxScore'],
            )
          : _toInt(latestGrowth['maxScore']);
      final String aiFeedbackEducatorId = _asTrimmedString(
        latestPortfolio?['aiFeedbackBy'] ??
            latestMissionAttempt?['aiFeedbackBy'],
      );
      final String? aiFeedbackEducatorName = aiFeedbackEducatorId.isEmpty
          ? (hasAiFeedbackSignal && reviewerName.isNotEmpty
              ? reviewerName
              : null)
          : reviewerNames[aiFeedbackEducatorId] ??
              (reviewerName.isEmpty ? null : reviewerName);
      final DateTime? aiFeedbackAt = _parseTimestamp(
            latestPortfolio?['aiFeedbackAt'] ??
                latestMissionAttempt?['aiFeedbackAt'],
          ) ??
          (hasAiFeedbackSignal ? reviewedAt : null);
      final String aiAssistanceDetails = _asTrimmedString(
        latestPortfolio?['aiAssistanceDetails'] ??
            latestMissionAttempt?['aiAssistanceDetails'] ??
            proofBundle?['aiAssistanceDetails'],
      );
      final List<String> progressionDescriptors = _stringListFromDynamic(
        latestPortfolio?['progressionDescriptors'],
      ).isNotEmpty
          ? _stringListFromDynamic(latestPortfolio?['progressionDescriptors'])
          : _stringListFromDynamic(latestGrowth?['progressionDescriptors']);
      final List<VerificationCheckpointMapping> checkpointMappings =
          _checkpointMappingsFromDynamic(
        latestPortfolio?['checkpointMappings'],
      ).isNotEmpty
              ? _checkpointMappingsFromDynamic(
                  latestPortfolio?['checkpointMappings'],
                )
              : _checkpointMappingsFromDynamic(
                  latestGrowth?['checkpointMappings'],
                );
      claims.add(
        PassportClaim(
          capabilityId: capabilityId,
          title: title,
          pillar: _pillarLabelFromCodes(<String>[
            _asTrimmedString(mastery['pillarCode']),
          ]),
          latestLevel: _toInt(mastery['latestLevel']) ?? 0,
          evidenceCount: matchingEvidence.length,
          verifiedArtifactCount: verifiedArtifactCount,
          evidenceRecordIds: matchingEvidence
              .map((Map<String, dynamic> row) => _asTrimmedString(row['id']))
              .where((String value) => value.isNotEmpty)
              .toList(growable: false),
          portfolioItemIds: matchingPortfolio
              .map((Map<String, dynamic> row) => _asTrimmedString(row['id']))
              .where((String value) => value.isNotEmpty)
              .toList(growable: false),
          missionAttemptIds: missionAttemptIds.toList(growable: false),
          progressionDescriptors: progressionDescriptors,
          checkpointMappings: checkpointMappings,
          proofOfLearningStatus: proofOfLearningStatus,
          aiDisclosureStatus: aiDisclosureStatus,
          latestEvidenceAt: evidenceDates.isEmpty ? null : evidenceDates.first,
          verificationStatus: verifiedArtifactCount > 0
              ? 'reviewed'
              : matchingEvidence.isNotEmpty
                  ? 'captured'
                  : null,
          proofHasExplainItBack: hasExplainItBack,
          proofHasOralCheck: hasOralCheck,
          proofHasMiniRebuild: hasMiniRebuild,
          proofCheckpointCount: proofCheckpointCount,
          proofExplainItBackExcerpt: _excerpt(
            proofBundle == null
                ? null
                : proofBundle['explainItBack'] as String?,
          ),
          proofOralCheckExcerpt: _excerpt(
            proofBundle == null
                ? null
                : proofBundle['oralCheckResponse'] as String?,
          ),
          proofMiniRebuildExcerpt: _excerpt(
            proofBundle == null
                ? null
                : proofBundle['miniRebuildPlan'] as String?,
          ),
          proofCheckpoints: _buildProofCheckpoints(proofBundle),
          aiHasLearnerDisclosure: hasLearnerAiDisclosure,
          aiLearnerDeclaredUsed: learnerAiDeclaredUsed,
          aiHelpEventCount: learnerAiEventCount,
          aiHasExplainItBackEvidence:
              hasExplainItBack || hasLearnerExplainBackEvent,
          aiHasEducatorAiFeedback: hasAiFeedbackSignal,
          aiAssistanceDetails:
              aiAssistanceDetails.isEmpty ? null : aiAssistanceDetails,
          reviewingEducatorName: reviewerName.isEmpty ? null : reviewerName,
          reviewedAt: reviewedAt,
          rubricRawScore: rubricRawScore,
          rubricMaxScore: rubricMaxScore,
          aiFeedbackEducatorName: aiFeedbackEducatorName,
          aiFeedbackAt: aiFeedbackAt,
        ),
      );
    }
    claims.sort((PassportClaim a, PassportClaim b) {
      final int levelCompare = b.latestLevel.compareTo(a.latestLevel);
      if (levelCompare != 0) {
        return levelCompare;
      }
      return b.evidenceCount.compareTo(a.evidenceCount);
    });
    return claims;
  }

  String _normalizePillarCode(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'future_skills':
      case 'futureskills':
      case 'future skills':
        return 'futureSkills';
      case 'leadership':
      case 'leadership_agency':
      case 'leadership & agency':
        return 'leadership';
      case 'impact':
      case 'impact_innovation':
      case 'impact & innovation':
        return 'impact';
      default:
        return '';
    }
  }

  String _pillarLabelFromCodes(List<String> codes) {
    for (final String code in codes) {
      final CurriculumLegacyFamilyCode? familyCode =
          CurriculumDisplay.legacyFamilyCodeFromAny(code);
      if (familyCode != null) {
        return CurriculumDisplay.legacyFamilyLabel(familyCode);
      }
    }
    return CurriculumDisplay.legacyFamilyLabel(
      CurriculumLegacyFamilyCode.future_skills,
    );
  }

  String _asTrimmedString(dynamic value) {
    if (value is! String) return '';
    return value.trim();
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  String _canonicalRole(dynamic role) {
    if (role is! String) return '';
    switch (role.trim().toLowerCase()) {
      case 'student':
      case 'learner':
        return 'learner';
      case 'guardian':
      case 'parent':
        return 'parent';
      case 'teacher':
      case 'educator':
        return 'educator';
      case 'sitelead':
      case 'site_lead':
      case 'site':
        return 'site';
      default:
        return role.trim().toLowerCase();
    }
  }
}
