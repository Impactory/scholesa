import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../../services/firestore_service.dart';
import 'parent_models.dart';

const String _fallbackLearnerName = 'Learner unavailable';

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
            evidenceSummary:
              _parseEvidenceSummary(learner['evidenceSummary']),
            growthSummary: _parseGrowthSummary(learner['growthSummary']),
            portfolioSnapshot:
                _parsePortfolioSnapshot(learner['portfolioSnapshot']),
            portfolioItemsPreview:
              _parsePortfolioItemsPreview(learner['portfolioItemsPreview']),
            ideationPassport:
                _parseIdeationPassport(learner['ideationPassport']),
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
    final List<Map<String, dynamic>> masteryRows = capabilityMasterySnapshot.docs
      .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.data())
      .toList(growable: false);

    final QuerySnapshot<Map<String, dynamic>> capabilityGrowthSnapshot =
      await _firestore
        .collection('capabilityGrowthEvents')
        .where('learnerId', isEqualTo: learnerId)
        .limit(120)
        .get();
    final List<Map<String, dynamic>> growthRows = capabilityGrowthSnapshot.docs
      .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.data())
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
    final List<Map<String, dynamic>> missionAttemptRows = missionAttemptsSnapshot
      .docs
      .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.data())
      .toList(growable: false);

    final EvidenceSummary evidenceSummary = _buildEvidenceSummary(evidenceRows);
    final GrowthSummary growthSummary =
      _buildGrowthSummary(masteryRows, growthRows);
    final CapabilitySnapshot capabilitySnapshot =
      _buildCapabilitySnapshot(masteryRows);
    final PortfolioSnapshot portfolioSummary =
      _buildPortfolioSnapshot(portfolioRows);
    final List<PortfolioPreviewItem> portfolioItemsPreview =
      _buildPortfolioPreviewItems(portfolioRows);
    final IdeationPassport ideationPassport = _buildIdeationPassport(
      missionAttemptRows,
      reflectionRows,
      evidenceRows,
      masteryRows,
      growthRows,
      portfolioRows,
    );

    return LearnerSummary(
      learnerId: learnerId,
      learnerName: (learnerData['displayName'] as String?)?.trim().isNotEmpty ==
          true
          ? (learnerData['displayName'] as String).trim()
          : _fallbackLearnerName,
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
      capabilitySnapshot: capabilitySnapshot,
      evidenceSummary: evidenceSummary,
      growthSummary: growthSummary,
      portfolioSnapshot: portfolioSummary,
      portfolioItemsPreview: portfolioItemsPreview,
      ideationPassport: ideationPassport,
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

  List<PortfolioPreviewItem> _parsePortfolioItemsPreview(dynamic value) {
    if (value is! List) return const <PortfolioPreviewItem>[];
    return value
        .whereType<Map>()
        .map((Map item) => PortfolioPreviewItem(
              id: _asTrimmedString(item['id']),
              title: _asTrimmedString(item['title']),
              description: _asTrimmedString(item['description']),
              pillar: _asTrimmedString(item['pillar']).isEmpty
                  ? 'Future Skills'
                  : _asTrimmedString(item['pillar']),
              type: _asTrimmedString(item['type']).isEmpty
                  ? 'project'
                  : _asTrimmedString(item['type']),
              completedAt: _parseTimestamp(item['completedAt']) ?? DateTime.now(),
              verificationStatus: _asTrimmedString(item['verificationStatus'])
                      .isEmpty
                  ? null
                  : _asTrimmedString(item['verificationStatus']),
              evidenceLinked: item['evidenceLinked'] == true,
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
                  ? 'Future Skills'
                  : _asTrimmedString(item['pillar']),
              latestLevel: _toInt(item['latestLevel']) ?? 0,
              evidenceCount: _toInt(item['evidenceCount']) ?? 0,
              verifiedArtifactCount: _toInt(item['verifiedArtifactCount']) ?? 0,
              latestEvidenceAt: _parseTimestamp(item['latestEvidenceAt']),
              verificationStatus: _asTrimmedString(item['verificationStatus'])
                      .isEmpty
                  ? null
                  : _asTrimmedString(item['verificationStatus']),
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
      return rubricStatus == 'linked' || growthStatus == 'updated';
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
    final double averageLevel =
        levels.isEmpty ? 0 : levels.reduce((int a, int b) => a + b) / levels.length;
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
          .map((Map<String, dynamic> row) => _asTrimmedString(row['capabilityId']))
          .where((String value) => value.isNotEmpty)
          .toSet()
          .length,
      averageLevel: averageLevel,
      latestLevel: latestLevels.isEmpty ? 0 : latestLevels.first,
      latestGrowthAt: growthDates.isEmpty ? null : growthDates.first,
    );
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
    final double overall =
        nonZero.isEmpty ? 0 : nonZero.reduce((double a, double b) => a + b) / nonZero.length;
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
    final int evidenceLinkedArtifactCount = rows.where((Map<String, dynamic> row) {
      final List<dynamic> evidenceRecordIds =
          row['evidenceRecordIds'] as List<dynamic>? ?? <dynamic>[];
      return evidenceRecordIds.isNotEmpty;
    }).length;
    final int verifiedArtifactCount = rows.where((Map<String, dynamic> row) {
      final String verificationStatus =
          _asTrimmedString(row['verificationStatus']).toLowerCase();
      return verificationStatus == 'reviewed' || verificationStatus == 'verified';
    }).length;
    final int badgeCount = rows.where((Map<String, dynamic> row) {
      final String title = _asTrimmedString(row['title']).toLowerCase();
      return title.contains('badge');
    }).length;
    final List<DateTime> artifactDates = rows
        .map((Map<String, dynamic> row) =>
            _parseTimestamp(row['updatedAt']) ?? _parseTimestamp(row['createdAt']))
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
  ) {
    final List<PortfolioPreviewItem> items = rows
        .map((Map<String, dynamic> row) => PortfolioPreviewItem(
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
              verificationStatus: _asTrimmedString(row['verificationStatus'])
                      .isEmpty
                  ? null
                  : _asTrimmedString(row['verificationStatus']),
              evidenceLinked:
                  (row['evidenceRecordIds'] as List<dynamic>? ?? <dynamic>[])
                      .isNotEmpty,
            ))
        .toList(growable: false);
    items.sort((PortfolioPreviewItem a, PortfolioPreviewItem b) =>
        b.completedAt.compareTo(a.completedAt));
    return items;
  }

  IdeationPassport _buildIdeationPassport(
    List<Map<String, dynamic>> missionAttemptRows,
    List<Map<String, dynamic>> reflectionRows,
    List<Map<String, dynamic>> evidenceRows,
    List<Map<String, dynamic>> masteryRows,
    List<Map<String, dynamic>> growthRows,
    List<Map<String, dynamic>> portfolioRows,
  ) {
    final int completedMissions = missionAttemptRows.where((Map<String, dynamic> row) {
      final String status = _asTrimmedString(row['status']).toLowerCase();
      return status == 'reviewed' ||
          status == 'completed' ||
          status == 'approved';
    }).length;
    final int voiceInteractions = missionAttemptRows.where((Map<String, dynamic> row) {
      final Map<dynamic, dynamic>? proofBundleSummary =
          row['proofBundleSummary'] as Map<dynamic, dynamic>?;
      return proofBundleSummary?['hasOralCheck'] == true;
    }).length;
    final int collaborationSignals = reflectionRows.where((Map<String, dynamic> row) {
      final String reflectionType = _asTrimmedString(row['reflectionType']);
      return reflectionType == 'shout_out' || reflectionType == 'weekly_review';
    }).length;
    final List<DateTime> reflectionDates = reflectionRows
        .map((Map<String, dynamic> row) => _parseTimestamp(row['createdAt']))
        .whereType<DateTime>()
        .toList(growable: false);
    reflectionDates.sort((DateTime a, DateTime b) => b.compareTo(a));
    final List<PassportClaim> claims = _buildPassportClaims(
      evidenceRows,
      masteryRows,
      growthRows,
      portfolioRows,
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
          ? 'No verified capability claims are available yet.'
          : '${claims.length} capability claims are backed by reviewed evidence and verified artifacts.',
      claims: claims,
    );
  }

  List<PassportClaim> _buildPassportClaims(
    List<Map<String, dynamic>> evidenceRows,
    List<Map<String, dynamic>> masteryRows,
    List<Map<String, dynamic>> growthRows,
    List<Map<String, dynamic>> portfolioRows,
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
          .where((Map<String, dynamic> row) =>
              List<String>.from(
                row['capabilityIds'] as List? ?? const <String>[],
              ).contains(capabilityId))
          .toList(growable: false);
      final List<Map<String, dynamic>> matchingGrowth = growthRows
          .where((Map<String, dynamic> row) =>
              _asTrimmedString(row['capabilityId']) == capabilityId)
          .toList(growable: false);
      final String title = <String>[
        ...matchingPortfolio.expand((Map<String, dynamic> row) =>
            List<String>.from(
              row['capabilityTitles'] as List? ?? const <String>[],
            )),
        ...matchingEvidence
            .map((Map<String, dynamic> row) => _asTrimmedString(row['capabilityLabel'])),
      ].firstWhere(
        (String value) => value.trim().isNotEmpty,
        orElse: () => capabilityId,
      );
      final List<DateTime> evidenceDates = <DateTime>[
        ...matchingEvidence
            .map((Map<String, dynamic> row) => _parseTimestamp(row['observedAt']))
            .whereType<DateTime>(),
        ...matchingGrowth
            .map((Map<String, dynamic> row) => _parseTimestamp(row['createdAt']))
            .whereType<DateTime>(),
      ]..sort((DateTime a, DateTime b) => b.compareTo(a));
      final int verifiedArtifactCount = matchingPortfolio.where((Map<String, dynamic> row) {
        final String verificationStatus =
            _asTrimmedString(row['verificationStatus']).toLowerCase();
        return verificationStatus == 'reviewed' || verificationStatus == 'verified';
      }).length;
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
          latestEvidenceAt: evidenceDates.isEmpty ? null : evidenceDates.first,
          verificationStatus: verifiedArtifactCount > 0
              ? 'reviewed'
              : matchingEvidence.isNotEmpty
                  ? 'captured'
                  : null,
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
      switch (_normalizePillarCode(code)) {
        case 'futureSkills':
          return 'Future Skills';
        case 'leadership':
          return 'Leadership & Agency';
        case 'impact':
          return 'Impact & Innovation';
      }
    }
    return 'Future Skills';
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
