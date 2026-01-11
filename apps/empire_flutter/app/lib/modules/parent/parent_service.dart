import 'package:cloud_firestore/cloud_firestore.dart';
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
      // Load learners linked to this parent
      final QuerySnapshot<Map<String, dynamic>> learnersSnapshot = await _firestore
          .collection('users')
          .where('parentIds', arrayContains: parentId)
          .where('role', isEqualTo: 'learner')
          .get();

      final List<LearnerSummary> summaries = <LearnerSummary>[];
      
      for (final QueryDocumentSnapshot<Map<String, dynamic>> learnerDoc in learnersSnapshot.docs) {
        final Map<String, dynamic> learnerData = learnerDoc.data();
        final String learnerId = learnerDoc.id;

        // Get learner progress data
        final DocumentSnapshot<Map<String, dynamic>> progressDoc = await _firestore
            .collection('learnerProgress')
            .doc(learnerId)
            .get();
        
        final Map<String, dynamic>? progressData = progressDoc.data();

        // Get recent activities
        final QuerySnapshot<Map<String, dynamic>> activitiesSnapshot = await _firestore
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

        // Get upcoming events
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

        // Calculate attendance rate from records
        final QuerySnapshot<Map<String, dynamic>> attendanceSnapshot = await _firestore
            .collection('attendanceRecords')
            .where('learnerId', isEqualTo: learnerId)
            .orderBy('timestamp', descending: true)
            .limit(30)
            .get();

        int presentCount = 0;
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in attendanceSnapshot.docs) {
          if (doc.data()['status'] == 'present') {
            presentCount++;
          }
        }
        final double attendanceRate = attendanceSnapshot.docs.isNotEmpty
            ? presentCount / attendanceSnapshot.docs.length
            : 0.0;

        summaries.add(LearnerSummary(
          learnerId: learnerId,
          learnerName: learnerData['displayName'] as String? ?? 'Unknown',
          photoUrl: learnerData['photoUrl'] as String?,
          currentLevel: progressData?['level'] as int? ?? 1,
          totalXp: progressData?['totalXp'] as int? ?? 0,
          missionsCompleted: progressData?['missionsCompleted'] as int? ?? 0,
          currentStreak: progressData?['currentStreak'] as int? ?? 0,
          attendanceRate: attendanceRate,
          pillarProgress: <String, double>{
            'futureSkills': (progressData?['futureSkillsProgress'] as num?)?.toDouble() ?? 0.0,
            'leadership': (progressData?['leadershipProgress'] as num?)?.toDouble() ?? 0.0,
            'impact': (progressData?['impactProgress'] as num?)?.toDouble() ?? 0.0,
          },
          recentActivities: activities,
          upcomingEvents: events,
        ));
      }

      _learnerSummaries = summaries;

      // Load billing summary
      await _loadBillingSummary();

      debugPrint('Loaded ${_learnerSummaries.length} learner summaries for parent');
    } catch (e) {
      debugPrint('Error loading parent data: $e');
      _error = 'Failed to load data: $e';
      _learnerSummaries = <LearnerSummary>[];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load billing summary from Firebase
  Future<void> _loadBillingSummary() async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> billingDoc = await _firestore
          .collection('billingAccounts')
          .doc(parentId)
          .get();

      if (!billingDoc.exists) {
        _billingSummary = null;
        return;
      }

      final Map<String, dynamic>? data = billingDoc.data();
      if (data == null) {
        _billingSummary = null;
        return;
      }

      // Get recent payments
      final QuerySnapshot<Map<String, dynamic>> paymentsSnapshot = await _firestore
          .collection('payments')
          .where('parentId', isEqualTo: parentId)
          .orderBy('date', descending: true)
          .limit(10)
          .get();

      final List<PaymentHistory> payments = paymentsSnapshot.docs.map(
        (QueryDocumentSnapshot<Map<String, dynamic>> doc) {
          final Map<String, dynamic> payData = doc.data();
          return PaymentHistory(
            id: doc.id,
            amount: (payData['amount'] as num?)?.toDouble() ?? 0.0,
            date: _parseTimestamp(payData['date']) ?? DateTime.now(),
            status: payData['status'] as String? ?? 'unknown',
            description: payData['description'] as String? ?? '',
          );
        },
      ).toList();

      _billingSummary = BillingSummary(
        currentBalance: (data['currentBalance'] as num?)?.toDouble() ?? 0.0,
        nextPaymentAmount: (data['nextPaymentAmount'] as num?)?.toDouble() ?? 0.0,
        nextPaymentDate: _parseTimestamp(data['nextPaymentDate']),
        subscriptionPlan: data['subscriptionPlan'] as String? ?? 'Basic',
        recentPayments: payments,
      );
    } catch (e) {
      debugPrint('Error loading billing summary: $e');
      _billingSummary = null;
    }
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
