import 'package:flutter/foundation.dart';
import '../../services/firestore_service.dart';
import 'partner_models.dart';

/// Service for partner operations
class PartnerService extends ChangeNotifier {
  PartnerService({
    required FirestoreService firestoreService,
    required String partnerId,
  })  : _firestoreService = firestoreService,
        _partnerId = partnerId;

  final FirestoreService _firestoreService;
  final String _partnerId;

  List<MarketplaceListing> _listings = <MarketplaceListing>[];
  List<PartnerContract> _contracts = <PartnerContract>[];
  List<Payout> _payouts = <Payout>[];
  bool _isLoading = false;
  String? _error;

  List<MarketplaceListing> get listings => List<MarketplaceListing>.unmodifiable(_listings);
  List<PartnerContract> get contracts => List<PartnerContract>.unmodifiable(_contracts);
  List<Payout> get payouts => List<Payout>.unmodifiable(_payouts);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load listings for this partner
  Future<void> loadListings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load from Firestore
      final List<Map<String, dynamic>> data = await _firestoreService.queryCollection(
        'marketplaceListings',
        where: <List<dynamic>>[<dynamic>['partnerId', _partnerId]],
      );

      _listings = data.map((Map<String, dynamic> doc) => MarketplaceListing(
        id: doc['id'] as String? ?? '',
        partnerId: doc['partnerId'] as String? ?? _partnerId,
        title: doc['title'] as String? ?? '',
        description: doc['description'] as String? ?? '',
        status: _parseListingStatus(doc['status'] as String?),
        category: doc['category'] as String? ?? 'General',
        price: (doc['price'] as num?)?.toDouble(),
        imageUrl: doc['imageUrl'] as String?,
      )).toList();
    } catch (e) {
      debugPrint('Failed to load listings: $e');
      _error = 'Failed to load listings';
      _listings = <MarketplaceListing>[];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load contracts for this partner
  Future<void> loadContracts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final List<Map<String, dynamic>> data = await _firestoreService.queryCollection(
        'partnerContracts',
        where: <List<dynamic>>[<dynamic>['partnerId', _partnerId]],
      );

      _contracts = data.map((Map<String, dynamic> doc) => PartnerContract(
        id: doc['id'] as String? ?? '',
        partnerId: doc['partnerId'] as String? ?? _partnerId,
        siteId: doc['siteId'] as String? ?? '',
        title: doc['title'] as String? ?? '',
        status: _parseContractStatus(doc['status'] as String?),
        totalValue: (doc['totalValue'] as num?)?.toDouble() ?? 0,
      )).toList();
    } catch (e) {
      debugPrint('Failed to load contracts: $e');
      _contracts = <PartnerContract>[];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load payouts for this partner
  Future<void> loadPayouts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final List<Map<String, dynamic>> data = await _firestoreService.queryCollection(
        'payouts',
        where: <List<dynamic>>[<dynamic>['partnerId', _partnerId]],
      );

      _payouts = data.map((Map<String, dynamic> doc) => Payout(
        id: doc['id'] as String? ?? '',
        partnerId: doc['partnerId'] as String? ?? _partnerId,
        amount: (doc['amount'] as num?)?.toDouble() ?? 0,
        status: _parsePayoutStatus(doc['status'] as String?),
        contractId: doc['contractId'] as String?,
      )).toList();
    } catch (e) {
      debugPrint('Failed to load payouts: $e');
      _payouts = <Payout>[];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  ListingStatus _parseListingStatus(String? status) {
    switch (status) {
      case 'draft': return ListingStatus.draft;
      case 'submitted': return ListingStatus.submitted;
      case 'approved': return ListingStatus.approved;
      case 'published': return ListingStatus.published;
      case 'rejected': return ListingStatus.rejected;
      case 'archived': return ListingStatus.archived;
      default: return ListingStatus.draft;
    }
  }

  ContractStatus _parseContractStatus(String? status) {
    switch (status) {
      case 'draft': return ContractStatus.draft;
      case 'submitted': return ContractStatus.submitted;
      case 'negotiation': return ContractStatus.negotiation;
      case 'approved': return ContractStatus.approved;
      case 'active': return ContractStatus.active;
      case 'completed': return ContractStatus.completed;
      case 'terminated': return ContractStatus.terminated;
      default: return ContractStatus.draft;
    }
  }

  PayoutStatus _parsePayoutStatus(String? status) {
    switch (status) {
      case 'pending': return PayoutStatus.pending;
      case 'approved': return PayoutStatus.approved;
      case 'paid': return PayoutStatus.paid;
      case 'failed': return PayoutStatus.failed;
      default: return PayoutStatus.pending;
    }
  }
}
