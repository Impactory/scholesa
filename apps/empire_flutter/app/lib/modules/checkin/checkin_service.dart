import 'package:flutter/foundation.dart';
import '../../services/api_client.dart';
import 'checkin_models.dart';

/// Service for site check-in/check-out operations
class CheckinService extends ChangeNotifier {

  CheckinService({
    required ApiClient apiClient,
    required this.siteId,
  }) : _apiClient = apiClient;
  final ApiClient _apiClient;
  final String siteId;

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
  int get presentCount =>
      _learnerSummaries.where((LearnerDaySummary s) => s.isCurrentlyPresent).length;
  int get absentCount =>
      _learnerSummaries.where((LearnerDaySummary s) => s.currentStatus == null).length;
  int get checkedOutCount =>
      _learnerSummaries.where((LearnerDaySummary s) => s.currentStatus == CheckStatus.checkedOut).length;

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

  /// Load today's check-in data
  Future<void> loadTodayData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // TODO: Replace with real API call
      await Future.delayed(const Duration(milliseconds: 500));
      _learnerSummaries = _generateMockSummaries();
      _todayRecords = _generateMockRecords();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
      final CheckRecord record = CheckRecord(
        id: 'rec_${DateTime.now().millisecondsSinceEpoch}',
        visitorId: visitorId,
        visitorName: visitorName,
        learnerId: learnerId,
        learnerName: learnerName,
        siteId: siteId,
        timestamp: DateTime.now(),
        status: CheckStatus.checkedIn,
        notes: notes,
      );

      _todayRecords = <CheckRecord>[record, ..._todayRecords];

      // Update learner summary
      final int index = _learnerSummaries.indexWhere((LearnerDaySummary s) => s.learnerId == learnerId);
      if (index != -1) {
        final LearnerDaySummary summary = _learnerSummaries[index];
        _learnerSummaries[index] = LearnerDaySummary(
          learnerId: summary.learnerId,
          learnerName: summary.learnerName,
          learnerPhoto: summary.learnerPhoto,
          currentStatus: CheckStatus.checkedIn,
          checkedInAt: DateTime.now(),
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
      final CheckRecord record = CheckRecord(
        id: 'rec_${DateTime.now().millisecondsSinceEpoch}',
        visitorId: visitorId,
        visitorName: visitorName,
        learnerId: learnerId,
        learnerName: learnerName,
        siteId: siteId,
        timestamp: DateTime.now(),
        status: CheckStatus.checkedOut,
        notes: notes,
      );

      _todayRecords = <CheckRecord>[record, ..._todayRecords];

      // Update learner summary
      final int index = _learnerSummaries.indexWhere((LearnerDaySummary s) => s.learnerId == learnerId);
      if (index != -1) {
        final LearnerDaySummary summary = _learnerSummaries[index];
        _learnerSummaries[index] = LearnerDaySummary(
          learnerId: summary.learnerId,
          learnerName: summary.learnerName,
          learnerPhoto: summary.learnerPhoto,
          currentStatus: CheckStatus.checkedOut,
          checkedInAt: summary.checkedInAt,
          checkedInBy: summary.checkedInBy,
          checkedOutAt: DateTime.now(),
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
      final int index = _learnerSummaries.indexWhere((LearnerDaySummary s) => s.learnerId == learnerId);
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

  // Mock data generators
  List<LearnerDaySummary> _generateMockSummaries() {
    return <LearnerDaySummary>[
      LearnerDaySummary(
        learnerId: 'learner_001',
        learnerName: 'Alex Chen',
        currentStatus: CheckStatus.checkedIn,
        checkedInAt: DateTime.now().subtract(const Duration(hours: 3)),
        checkedInBy: 'Wei Chen',
        authorizedPickups: const <AuthorizedPickup>[
          AuthorizedPickup(
            id: 'pickup_001',
            learnerId: 'learner_001',
            name: 'Wei Chen',
            phone: '+1234567890',
            relationship: 'Father',
            isPrimaryContact: true,
          ),
          AuthorizedPickup(
            id: 'pickup_002',
            learnerId: 'learner_001',
            name: 'Lin Chen',
            phone: '+1234567891',
            relationship: 'Mother',
          ),
        ],
      ),
      LearnerDaySummary(
        learnerId: 'learner_002',
        learnerName: 'Emma Rodriguez',
        currentStatus: CheckStatus.checkedIn,
        checkedInAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 30)),
        checkedInBy: 'Sofia Rodriguez',
        authorizedPickups: const <AuthorizedPickup>[
          AuthorizedPickup(
            id: 'pickup_003',
            learnerId: 'learner_002',
            name: 'Sofia Rodriguez',
            phone: '+1234567892',
            relationship: 'Mother',
            isPrimaryContact: true,
          ),
        ],
      ),
      LearnerDaySummary(
        learnerId: 'learner_003',
        learnerName: 'Noah Williams',
        currentStatus: CheckStatus.late,
        checkedInAt: DateTime.now().subtract(const Duration(hours: 1)),
        checkedInBy: 'John Williams',
        authorizedPickups: const <AuthorizedPickup>[
          AuthorizedPickup(
            id: 'pickup_004',
            learnerId: 'learner_003',
            name: 'John Williams',
            phone: '+1234567893',
            relationship: 'Father',
            isPrimaryContact: true,
          ),
        ],
      ),
      LearnerDaySummary(
        learnerId: 'learner_004',
        learnerName: 'Sophia Martinez',
        currentStatus: CheckStatus.checkedOut,
        checkedInAt: DateTime.now().subtract(const Duration(hours: 4)),
        checkedInBy: 'Maria Martinez',
        checkedOutAt: DateTime.now().subtract(const Duration(minutes: 30)),
        checkedOutBy: 'Maria Martinez',
        authorizedPickups: const <AuthorizedPickup>[
          AuthorizedPickup(
            id: 'pickup_005',
            learnerId: 'learner_004',
            name: 'Maria Martinez',
            phone: '+1234567894',
            relationship: 'Mother',
            isPrimaryContact: true,
          ),
        ],
      ),
      const LearnerDaySummary(
        learnerId: 'learner_005',
        learnerName: 'Liam Johnson',
        authorizedPickups: <AuthorizedPickup>[
          AuthorizedPickup(
            id: 'pickup_006',
            learnerId: 'learner_005',
            name: 'Sarah Johnson',
            phone: '+1234567895',
            relationship: 'Mother',
            isPrimaryContact: true,
          ),
        ],
      ),
      const LearnerDaySummary(
        learnerId: 'learner_006',
        learnerName: 'Olivia Brown',
      ),
    ];
  }

  List<CheckRecord> _generateMockRecords() {
    return <CheckRecord>[
      CheckRecord(
        id: 'rec_001',
        visitorId: 'parent_001',
        visitorName: 'Wei Chen',
        learnerId: 'learner_001',
        learnerName: 'Alex Chen',
        siteId: siteId,
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        status: CheckStatus.checkedIn,
      ),
      CheckRecord(
        id: 'rec_002',
        visitorId: 'parent_002',
        visitorName: 'Sofia Rodriguez',
        learnerId: 'learner_002',
        learnerName: 'Emma Rodriguez',
        siteId: siteId,
        timestamp: DateTime.now().subtract(const Duration(hours: 2, minutes: 30)),
        status: CheckStatus.checkedIn,
      ),
      CheckRecord(
        id: 'rec_003',
        visitorId: 'parent_003',
        visitorName: 'John Williams',
        learnerId: 'learner_003',
        learnerName: 'Noah Williams',
        siteId: siteId,
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        status: CheckStatus.late,
        notes: 'Arrived 30 minutes late',
      ),
      CheckRecord(
        id: 'rec_004',
        visitorId: 'parent_004',
        visitorName: 'Maria Martinez',
        learnerId: 'learner_004',
        learnerName: 'Sophia Martinez',
        siteId: siteId,
        timestamp: DateTime.now().subtract(const Duration(hours: 4)),
        status: CheckStatus.checkedIn,
      ),
      CheckRecord(
        id: 'rec_005',
        visitorId: 'parent_004',
        visitorName: 'Maria Martinez',
        learnerId: 'learner_004',
        learnerName: 'Sophia Martinez',
        siteId: siteId,
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        status: CheckStatus.checkedOut,
      ),
    ];
  }
}
