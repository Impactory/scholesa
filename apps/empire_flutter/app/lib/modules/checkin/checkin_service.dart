import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../services/firestore_service.dart';
import 'checkin_models.dart';

/// Service for site check-in/check-out operations - wired to Firebase
class CheckinService extends ChangeNotifier {

  CheckinService({
    required FirestoreService firestoreService,
    required this.siteId,
  }) : _firestoreService = firestoreService;
  final FirestoreService _firestoreService;
  final String siteId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  /// Load today's check-in data from Firebase
  Future<void> loadTodayData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final DateTime now = DateTime.now();
      final DateTime startOfDay = DateTime(now.year, now.month, now.day);
      final DateTime endOfDay = startOfDay.add(const Duration(days: 1));

      // Query presence records for today
      final QuerySnapshot<Map<String, dynamic>> recordsSnapshot = await _firestore
          .collection('presenceRecords')
          .where('siteId', isEqualTo: siteId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('timestamp', descending: true)
          .get();

      // Build today's records
      _todayRecords = recordsSnapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return CheckRecord(
          id: doc.id,
          learnerId: data['learnerId'] as String? ?? '',
          learnerName: data['learnerName'] as String? ?? 'Unknown',
          siteId: siteId,
          status: data['type'] == 'checkin' ? CheckStatus.checkedIn : CheckStatus.checkedOut,
          timestamp: _parseTimestamp(data['timestamp']) ?? DateTime.now(),
          visitorId: data['recordedBy'] as String? ?? '',
          visitorName: data['recorderName'] as String? ?? '',
          notes: data['notes'] as String?,
        );
      }).toList();

      // Group records by learner to build summaries
      final Map<String, List<CheckRecord>> byLearner = <String, List<CheckRecord>>{};
      for (final CheckRecord record in _todayRecords) {
        byLearner.putIfAbsent(record.learnerId, () => <CheckRecord>[]).add(record);
      }

      // Get all learners enrolled at this site
      final QuerySnapshot<Map<String, dynamic>> learnersSnapshot = await _firestore
          .collection('users')
          .where('siteIds', arrayContains: siteId)
          .where('role', isEqualTo: 'learner')
          .get();

      _learnerSummaries = learnersSnapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        final List<CheckRecord> records = byLearner[doc.id] ?? <CheckRecord>[];
        
        // Find latest checkin and checkout
        CheckRecord? latestCheckin;
        CheckRecord? latestCheckout;
        for (final CheckRecord r in records) {
          if (r.status == CheckStatus.checkedIn && (latestCheckin == null || r.timestamp.isAfter(latestCheckin.timestamp))) {
            latestCheckin = r;
          }
          if (r.status == CheckStatus.checkedOut && (latestCheckout == null || r.timestamp.isAfter(latestCheckout.timestamp))) {
            latestCheckout = r;
          }
        }

        // Determine current status
        CheckStatus? currentStatus;
        if (latestCheckout != null && latestCheckin != null) {
          currentStatus = latestCheckout.timestamp.isAfter(latestCheckin.timestamp)
              ? CheckStatus.checkedOut
              : CheckStatus.checkedIn;
        } else if (latestCheckin != null) {
          currentStatus = CheckStatus.checkedIn;
        }

        return LearnerDaySummary(
          learnerId: doc.id,
          learnerName: data['displayName'] as String? ?? 'Unknown',
          currentStatus: currentStatus,
          checkedInAt: latestCheckin?.timestamp,
          checkedInBy: latestCheckin?.visitorName,
          checkedOutAt: latestCheckout?.timestamp,
          checkedOutBy: latestCheckout?.visitorName,
          authorizedPickups: <AuthorizedPickup>[], // Will be loaded separately if needed
        );
      }).toList();

      debugPrint('Loaded ${_learnerSummaries.length} learners and ${_todayRecords.length} records');
    } catch (e) {
      debugPrint('Error loading checkin data: $e');
      _error = 'Failed to load check-in data: $e';
      _learnerSummaries = <LearnerDaySummary>[];
      _todayRecords = <CheckRecord>[];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
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
}
