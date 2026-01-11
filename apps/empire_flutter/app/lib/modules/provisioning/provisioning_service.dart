import 'package:flutter/foundation.dart';
import '../../services/api_client.dart';
import 'provisioning_models.dart';

/// Service for user provisioning operations
class ProvisioningService extends ChangeNotifier {

  ProvisioningService({required ApiClient apiClient}) : _apiClient = apiClient;
  final ApiClient _apiClient;

  List<LearnerProfile> _learners = <LearnerProfile>[];
  List<ParentProfile> _parents = <ParentProfile>[];
  List<GuardianLink> _guardianLinks = <GuardianLink>[];
  bool _isLoading = false;
  String? _error;

  List<LearnerProfile> get learners => _learners;
  List<ParentProfile> get parents => _parents;
  List<GuardianLink> get guardianLinks => _guardianLinks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load learners for site
  Future<void> loadLearners(String siteId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final Map<String, dynamic> response = await _apiClient.get('/v1/sites/$siteId/learners');
      final List<dynamic> items = response['items'] as List? ?? <dynamic>[];
      _learners = items
          .map((e) => LearnerProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = 'Failed to load learners: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load parents for site
  Future<void> loadParents(String siteId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final Map<String, dynamic> response = await _apiClient.get('/v1/sites/$siteId/parents');
      final List<dynamic> items = response['items'] as List? ?? <dynamic>[];
      _parents = items
          .map((e) => ParentProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = 'Failed to load parents: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load guardian links for site
  Future<void> loadGuardianLinks(String siteId) async {
    try {
      final Map<String, dynamic> response = await _apiClient.get('/v1/guardian-links', queryParams: <String, String>{
        'siteId': siteId,
      });
      final List<dynamic> items = response['items'] as List? ?? <dynamic>[];
      _guardianLinks = items
          .map((e) => GuardianLink.fromJson(e as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load guardian links: $e');
    }
  }

  /// Create learner profile
  Future<LearnerProfile?> createLearner({
    required String siteId,
    required String email,
    required String displayName,
    int? gradeLevel,
    DateTime? dateOfBirth,
    String? notes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final Map<String, dynamic> response = await _apiClient.post(
        '/v1/sites/$siteId/learners',
        body: <String, dynamic>{
          'email': email,
          'displayName': displayName,
          if (gradeLevel != null) 'gradeLevel': gradeLevel,
          if (dateOfBirth != null)
            'dateOfBirth': dateOfBirth.millisecondsSinceEpoch,
          if (notes != null) 'notes': notes,
        },
      );
      
      final LearnerProfile learner = LearnerProfile.fromJson(response);
      _learners.add(learner);
      notifyListeners();
      return learner;
    } catch (e) {
      _error = 'Failed to create learner: $e';
      debugPrint(_error);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create parent profile
  Future<ParentProfile?> createParent({
    required String siteId,
    required String email,
    required String displayName,
    String? phone,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final Map<String, dynamic> response = await _apiClient.post(
        '/v1/sites/$siteId/parents',
        body: <String, dynamic>{
          'email': email,
          'displayName': displayName,
          if (phone != null) 'phone': phone,
        },
      );
      
      final ParentProfile parent = ParentProfile.fromJson(response);
      _parents.add(parent);
      notifyListeners();
      return parent;
    } catch (e) {
      _error = 'Failed to create parent: $e';
      debugPrint(_error);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create guardian link
  Future<GuardianLink?> createGuardianLink({
    required String siteId,
    required String parentId,
    required String learnerId,
    required String relationship,
    bool isPrimary = false,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final Map<String, dynamic> response = await _apiClient.post(
        '/v1/guardian-links',
        body: <String, dynamic>{
          'siteId': siteId,
          'parentId': parentId,
          'learnerId': learnerId,
          'relationship': relationship,
          'isPrimary': isPrimary,
        },
      );
      
      final GuardianLink link = GuardianLink.fromJson(response);
      _guardianLinks.add(link);
      notifyListeners();
      return link;
    } catch (e) {
      _error = 'Failed to create guardian link: $e';
      debugPrint(_error);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete guardian link
  Future<bool> deleteGuardianLink(String linkId) async {
    try {
      await _apiClient.delete('/v1/guardian-links/$linkId');
      _guardianLinks.removeWhere((GuardianLink l) => l.id == linkId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete guardian link: $e';
      debugPrint(_error);
      return false;
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
