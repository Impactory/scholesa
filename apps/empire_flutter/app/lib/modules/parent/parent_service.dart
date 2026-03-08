import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../../services/firestore_service.dart';
import 'parent_models.dart';

/// Service for parent-specific views
class ParentService extends ChangeNotifier {
  ParentService({
    required FirestoreService firestoreService,
    required this.parentId,
  }) : _firestoreService = firestoreService;
  final FirestoreService _firestoreService;
  final String parentId;
  FirebaseFirestore get _firestore => _firestoreService.firestore;

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
      final List<LearnerSummary> callableSummaries =
          await _loadParentBundleFromCallable();
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
      _error = 'Failed to load data: $e';
      _learnerSummaries = <LearnerSummary>[];
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
            currentLevel: _toInt(learner['currentLevel']) ?? 1,
            totalXp: _toInt(learner['totalXp']) ?? 0,
            missionsCompleted: _toInt(learner['missionsCompleted']) ?? 0,
            currentStreak: _toInt(learner['currentStreak']) ?? 0,
            attendanceRate: _toDouble(learner['attendanceRate']) ?? 0.0,
            pillarProgress: _parsePillarProgress(learner['pillarProgress']),
            capabilitySnapshot:
                _parseCapabilitySnapshot(learner['capabilitySnapshot']),
            portfolioSnapshot:
                _parsePortfolioSnapshot(learner['portfolioSnapshot']),
            ideationPassport:
                _parseIdeationPassport(learner['ideationPassport']),
            recentActivities: activities,
            upcomingEvents: events,
          ),
        );
      }
      return parsed;
    } catch (error) {
      debugPrint(
          'Parent callable bundle unavailable, using Firestore fallback: $error');
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

    final QuerySnapshot<Map<String, dynamic>> activitiesSnapshot =
        await _firestore
            .collection('activities')
            .where('learnerId', isEqualTo: learnerId)
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

    final DateTime now = DateTime.now();
    final QuerySnapshot<Map<String, dynamic>> eventsSnapshot = await _firestore
        .collection('events')
        .where('learnerId', isEqualTo: learnerId)
        .where('dateTime', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('dateTime')
        .limit(5)
        .get();

    final List<UpcomingEvent> events = eventsSnapshot.docs.map(
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

    return LearnerSummary(
      learnerId: learnerId,
      learnerName: learnerData['displayName'] as String? ?? 'Unknown',
      photoUrl: learnerData['photoUrl'] as String?,
      currentLevel: _toInt(progressData?['level']) ?? 1,
      totalXp: _toInt(progressData?['totalXp']) ?? 0,
      missionsCompleted: _toInt(progressData?['missionsCompleted']) ?? 0,
      currentStreak: _toInt(progressData?['currentStreak']) ?? 0,
      attendanceRate: attendanceRate,
      pillarProgress: <String, double>{
        'futureSkills': _toDouble(progressData?['futureSkillsProgress']) ?? 0.0,
        'leadership': _toDouble(progressData?['leadershipProgress']) ?? 0.0,
        'impact': _toDouble(progressData?['impactProgress']) ?? 0.0,
      },
      recentActivities: activities,
      upcomingEvents: events,
    );
  }

  /// Load billing summary from Firebase
  Future<void> _loadBillingSummary() async {
    try {
      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('getParentBillingSummary');
      final HttpsCallableResult<dynamic> result =
          await callable.call(<String, dynamic>{'parentId': parentId});
      final Map<String, dynamic>? payload = _asStringDynamicMap(result.data);
      final Map<String, dynamic>? summary =
          _asStringDynamicMap(payload?['summary']);
      if (summary != null) {
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
          subscriptionPlan:
              _asTrimmedString(summary['subscriptionPlan']).isEmpty
                  ? 'Basic'
                  : _asTrimmedString(summary['subscriptionPlan']),
          recentPayments: payments,
        );
        return;
      }
    } catch (error) {
      debugPrint('Parent billing callable request failed: $error');
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
      latestArtifactAt: _parseTimestamp(value['latestArtifactAt']),
    );
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
