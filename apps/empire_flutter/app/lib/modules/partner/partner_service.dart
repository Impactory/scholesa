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
      // Try to load from Firestore
      final List<Map<String, dynamic>> data = await _firestoreService.queryCollection(
        'marketplaceListings',
        where: <List<dynamic>>[<dynamic>['partnerId', _partnerId]],
      );

      if (data.isNotEmpty) {
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
      } else {
        // Mock data for demo
        _listings = <MarketplaceListing>[
          MarketplaceListing(
            id: 'listing_1',
            partnerId: _partnerId,
            title: 'AI Coding Workshop',
            description: 'Interactive coding workshop for K-9 learners',
            status: ListingStatus.published,
            category: 'Future Skills',
            price: 299.00,
            createdAt: DateTime.now().subtract(const Duration(days: 30)),
          ),
          MarketplaceListing(
            id: 'listing_2',
            partnerId: _partnerId,
            title: 'Robotics Kit Bundle',
            description: 'Complete robotics kit with curriculum',
            status: ListingStatus.draft,
            category: 'Future Skills',
            price: 499.00,
            createdAt: DateTime.now().subtract(const Duration(days: 7)),
          ),
        ];
      }
    } catch (e) {
      debugPrint('Failed to load listings: $e');
      _error = 'Failed to load listings';
      // Fallback to mock data
      _listings = <MarketplaceListing>[
        MarketplaceListing(
          id: 'listing_1',
          partnerId: _partnerId,
          title: 'AI Coding Workshop',
          description: 'Interactive coding workshop for K-9 learners',
          status: ListingStatus.published,
          category: 'Future Skills',
          price: 299.00,
        ),
      ];
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

      if (data.isNotEmpty) {
        _contracts = data.map((Map<String, dynamic> doc) => PartnerContract(
          id: doc['id'] as String? ?? '',
          partnerId: doc['partnerId'] as String? ?? _partnerId,
          siteId: doc['siteId'] as String? ?? '',
          title: doc['title'] as String? ?? '',
          status: _parseContractStatus(doc['status'] as String?),
          totalValue: (doc['totalValue'] as num?)?.toDouble() ?? 0,
        )).toList();
      } else {
        // Mock data
        _contracts = <PartnerContract>[
          PartnerContract(
            id: 'contract_1',
            partnerId: _partnerId,
            siteId: 'site_1',
            title: 'Q1 Workshop Series',
            status: ContractStatus.active,
            totalValue: 5000.00,
            startDate: DateTime.now().subtract(const Duration(days: 30)),
            endDate: DateTime.now().add(const Duration(days: 60)),
          ),
          PartnerContract(
            id: 'contract_2',
            partnerId: _partnerId,
            siteId: 'site_2',
            title: 'Annual Curriculum License',
            status: ContractStatus.negotiation,
            totalValue: 12000.00,
          ),
        ];
      }
    } catch (e) {
      debugPrint('Failed to load contracts: $e');
      _contracts = <PartnerContract>[
        PartnerContract(
          id: 'contract_1',
          partnerId: _partnerId,
          siteId: 'site_1',
          title: 'Q1 Workshop Series',
          status: ContractStatus.active,
          totalValue: 5000.00,
        ),
      ];
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

      if (data.isNotEmpty) {
        _payouts = data.map((Map<String, dynamic> doc) => Payout(
          id: doc['id'] as String? ?? '',
          partnerId: doc['partnerId'] as String? ?? _partnerId,
          amount: (doc['amount'] as num?)?.toDouble() ?? 0,
          status: _parsePayoutStatus(doc['status'] as String?),
          contractId: doc['contractId'] as String?,
        )).toList();
      } else {
        // Mock data
        _payouts = <Payout>[
          Payout(
            id: 'payout_1',
            partnerId: _partnerId,
            amount: 2500.00,
            status: PayoutStatus.paid,
            contractId: 'contract_1',
            requestedAt: DateTime.now().subtract(const Duration(days: 15)),
            paidAt: DateTime.now().subtract(const Duration(days: 10)),
          ),
          Payout(
            id: 'payout_2',
            partnerId: _partnerId,
            amount: 1500.00,
            status: PayoutStatus.pending,
            contractId: 'contract_1',
            requestedAt: DateTime.now().subtract(const Duration(days: 2)),
          ),
        ];
      }
    } catch (e) {
      debugPrint('Failed to load payouts: $e');
      _payouts = <Payout>[
        Payout(
          id: 'payout_1',
          partnerId: _partnerId,
          amount: 2500.00,
          status: PayoutStatus.paid,
          paidAt: DateTime.now().subtract(const Duration(days: 10)),
        ),
      ];
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
