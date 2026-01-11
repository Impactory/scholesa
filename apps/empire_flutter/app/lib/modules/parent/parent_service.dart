import 'package:flutter/foundation.dart';
import '../../services/api_client.dart';
import 'parent_models.dart';

/// Service for parent-specific views
class ParentService extends ChangeNotifier {

  ParentService({
    required ApiClient apiClient,
    required this.parentId,
  }) : _apiClient = apiClient;
  final ApiClient _apiClient;
  final String parentId;

  List<LearnerSummary> _learnerSummaries = <LearnerSummary>[];
  BillingSummary? _billingSummary;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<LearnerSummary> get learnerSummaries => _learnerSummaries;
  BillingSummary? get billingSummary => _billingSummary;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load all data for parent dashboard
  Future<void> loadParentData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.delayed(const Duration(milliseconds: 500));
      _learnerSummaries = _generateMockLearnerSummaries();
      _billingSummary = _generateMockBillingSummary();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Mock data generators
  List<LearnerSummary> _generateMockLearnerSummaries() {
    final DateTime now = DateTime.now();
    return <LearnerSummary>[
      LearnerSummary(
        learnerId: 'learner_001',
        learnerName: 'Alex Chen',
        currentLevel: 5,
        totalXp: 1250,
        missionsCompleted: 8,
        currentStreak: 12,
        attendanceRate: 0.95,
        pillarProgress: <String, double>const {
          'futureSkills': 0.72,
          'leadership': 0.58,
          'impact': 0.45,
        },
        recentActivities: <RecentActivity>[
          RecentActivity(
            id: 'act_001',
            title: 'Completed Coding Mission',
            description: 'Built a Calculator App',
            type: 'mission',
            emoji: '🚀',
            timestamp: now.subtract(const Duration(hours: 3)),
          ),
          RecentActivity(
            id: 'act_002',
            title: 'Morning Reading',
            description: '15 minutes completed',
            type: 'habit',
            emoji: '📖',
            timestamp: now.subtract(const Duration(hours: 8)),
          ),
          RecentActivity(
            id: 'act_003',
            title: 'Achievement Unlocked',
            description: '10-day streak badge',
            type: 'achievement',
            emoji: '🏆',
            timestamp: now.subtract(const Duration(days: 1)),
          ),
          RecentActivity(
            id: 'act_004',
            title: 'Attended Science Class',
            description: 'On time',
            type: 'attendance',
            emoji: '✅',
            timestamp: now.subtract(const Duration(days: 1)),
          ),
        ],
        upcomingEvents: <UpcomingEvent>[
          UpcomingEvent(
            id: 'evt_001',
            title: 'Math Class',
            dateTime: now.add(const Duration(hours: 2)),
            type: 'class',
            location: 'Room 101',
          ),
          UpcomingEvent(
            id: 'evt_002',
            title: 'Website Mission Due',
            description: 'Code Your First Website',
            dateTime: now.add(const Duration(days: 5)),
            type: 'mission_due',
          ),
          UpcomingEvent(
            id: 'evt_003',
            title: 'Parent-Teacher Conference',
            dateTime: now.add(const Duration(days: 3)),
            type: 'conference',
            location: 'Main Hall',
          ),
        ],
      ),
      LearnerSummary(
        learnerId: 'learner_002',
        learnerName: 'Emma Chen',
        currentLevel: 3,
        totalXp: 680,
        missionsCompleted: 4,
        currentStreak: 5,
        attendanceRate: 0.88,
        pillarProgress: <String, double>const {
          'futureSkills': 0.45,
          'leadership': 0.62,
          'impact': 0.35,
        },
        recentActivities: <RecentActivity>[
          RecentActivity(
            id: 'act_005',
            title: 'Led Team Discussion',
            description: 'Community project brainstorm',
            type: 'mission',
            emoji: '👑',
            timestamp: now.subtract(const Duration(hours: 6)),
          ),
          RecentActivity(
            id: 'act_006',
            title: 'Mindful Breathing',
            description: '5 minutes completed',
            type: 'habit',
            emoji: '🧘',
            timestamp: now.subtract(const Duration(hours: 10)),
          ),
        ],
        upcomingEvents: <UpcomingEvent>[
          UpcomingEvent(
            id: 'evt_004',
            title: 'Art Class',
            dateTime: now.add(const Duration(hours: 4)),
            type: 'class',
            location: 'Art Room',
          ),
        ],
      ),
    ];
  }

  BillingSummary _generateMockBillingSummary() {
    final DateTime now = DateTime.now();
    return BillingSummary(
      currentBalance: 0.00,
      nextPaymentAmount: 299.00,
      nextPaymentDate: DateTime(now.year, now.month + 1),
      subscriptionPlan: 'Family Premium',
      recentPayments: <PaymentHistory>[
        PaymentHistory(
          id: 'pay_001',
          amount: 299.00,
          date: DateTime(now.year, now.month),
          status: 'paid',
          description: 'Monthly subscription',
        ),
        PaymentHistory(
          id: 'pay_002',
          amount: 299.00,
          date: DateTime(now.year, now.month - 1),
          status: 'paid',
          description: 'Monthly subscription',
        ),
      ],
    );
  }
}
