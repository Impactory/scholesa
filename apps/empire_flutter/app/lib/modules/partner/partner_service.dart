import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../services/firestore_service.dart';
import '../../services/workflow_bridge_service.dart';
import 'partner_models.dart';

bool _isMissingFirebaseAppError(Object error) {
  final String message = error.toString();
  return message.contains("No Firebase App '[DEFAULT]' has been created") ||
      message.contains('core/no-app');
}

/// Service for partner operations
class PartnerService extends ChangeNotifier {
  PartnerService({
    required FirestoreService firestoreService,
    required String partnerId,
    WorkflowBridgeService? workflowBridgeService,
  })  : _firestoreService = firestoreService,
        _partnerId = partnerId,
        _workflowBridgeService =
            workflowBridgeService ?? WorkflowBridgeService.instance;

  final FirestoreService _firestoreService;
  final String _partnerId;
  final WorkflowBridgeService _workflowBridgeService;

  List<MarketplaceListing> _listings = <MarketplaceListing>[];
  List<PartnerContract> _contracts = <PartnerContract>[];
  List<PartnerLaunch> _partnerLaunches = <PartnerLaunch>[];
  List<Payout> _payouts = <Payout>[];
  bool _isLoading = false;
  String? _error;

  String get partnerId => _partnerId;
  List<MarketplaceListing> get listings =>
      List<MarketplaceListing>.unmodifiable(_listings);
  List<PartnerContract> get contracts =>
      List<PartnerContract>.unmodifiable(_contracts);
  List<PartnerLaunch> get partnerLaunches =>
      List<PartnerLaunch>.unmodifiable(_partnerLaunches);
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
      final List<Map<String, dynamic>> data =
          await _firestoreService.queryCollection(
        'marketplaceListings',
        where: <List<dynamic>>[
          <dynamic>['partnerId', _partnerId]
        ],
      );

      _listings = data
          .map((Map<String, dynamic> doc) => MarketplaceListing(
                id: doc['id'] as String? ?? '',
                partnerId: doc['partnerId'] as String? ?? _partnerId,
                title: doc['title'] as String? ?? '',
                description: doc['description'] as String? ?? '',
                status: _parseListingStatus(doc['status'] as String?),
                category: doc['category'] as String? ?? 'General',
                productId: doc['productId'] as String? ?? '',
                currency: doc['currency'] as String? ?? 'USD',
                price: (doc['price'] as num?)?.toDouble(),
                imageUrl: doc['imageUrl'] as String?,
              ))
          .toList();
    } catch (e) {
      debugPrint('Failed to load listings: $e');
      _error = 'Failed to load listings';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new listing and reflect it immediately in local state
  Future<MarketplaceListing?> createListing({
    required String title,
    required String description,
    required String category,
    required String productId,
    required double price,
    String currency = 'USD',
  }) async {
    _error = null;
    notifyListeners();

    try {
      final String listingId = await _firestoreService.createDocument(
        'marketplaceListings',
        <String, dynamic>{
          'partnerId': _partnerId,
          'title': title,
          'description': description,
          'category': category,
          'productId': productId,
          'price': price,
          'currency': currency,
          'status': 'draft',
        },
      );

      final MarketplaceListing listing = MarketplaceListing(
        id: listingId,
        partnerId: _partnerId,
        title: title,
        description: description,
        status: ListingStatus.draft,
        category: category,
        productId: productId,
        currency: currency,
        price: price,
      );

      _listings = <MarketplaceListing>[listing, ..._listings];
      notifyListeners();
      return listing;
    } catch (e) {
      debugPrint('Failed to create listing: $e');
      _error = 'Failed to create listing';
      notifyListeners();
      return null;
    }
  }

  /// Load contracts for this partner
  Future<void> loadContracts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final List<Map<String, dynamic>> data =
          await _firestoreService.queryCollection(
        'partnerContracts',
        where: <List<dynamic>>[
          <dynamic>['partnerId', _partnerId]
        ],
      );

      _contracts = data
          .map((Map<String, dynamic> doc) => PartnerContract(
                id: doc['id'] as String? ?? '',
                partnerId: doc['partnerId'] as String? ?? _partnerId,
                siteId: doc['siteId'] as String? ?? '',
                title: doc['title'] as String? ?? '',
                status: _parseContractStatus(doc['status'] as String?),
                totalValue: (doc['totalValue'] as num?)?.toDouble() ?? 0,
              ))
          .toList();
    } catch (e) {
      debugPrint('Failed to load contracts: $e');
      _error = 'Failed to load contracts';
      _contracts = <PartnerContract>[];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPartnerLaunches() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final List<Map<String, dynamic>> data =
          await _workflowBridgeService.listPartnerLaunches(limit: 80);
      _partnerLaunches = data
          .map((Map<String, dynamic> doc) => PartnerLaunch(
                id: doc['id'] as String? ?? '',
                partnerId: doc['partnerId'] as String? ?? _partnerId,
                siteId: doc['siteId'] as String?,
                partnerName: doc['partnerName'] as String? ?? '',
                region: doc['region'] as String? ?? 'global',
                locale: doc['locale'] as String? ?? 'en',
                dueDiligenceStatus:
                    doc['dueDiligenceStatus'] as String? ?? 'pending',
                contractStatus: doc['contractStatus'] as String? ?? 'draft',
                planningWorkshopStatus:
                    doc['planningWorkshopStatus'] as String? ?? 'pending',
                trainerOfTrainersStatus:
                    doc['trainerOfTrainersStatus'] as String? ?? 'pending',
                kpiLoggingStatus:
                    doc['kpiLoggingStatus'] as String? ?? 'pending',
                review90DayStatus:
                    doc['review90DayStatus'] as String? ?? 'pending',
                pilotCohortCount: (doc['pilotCohortCount'] as num?)?.toInt(),
                notes: doc['notes'] as String?,
                status: doc['status'] as String? ?? 'planning',
                updatedAt: WorkflowBridgeService.toDateTime(doc['updatedAt']) ??
                    WorkflowBridgeService.toDateTime(doc['createdAt']),
              ))
          .toList()
        ..sort((PartnerLaunch a, PartnerLaunch b) {
          final DateTime aTime =
              a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final DateTime bTime =
              b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
    } catch (e) {
      debugPrint('Failed to load partner launches: $e');
      _error = 'Failed to load partner launches';
      _partnerLaunches = <PartnerLaunch>[];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<PartnerLaunch?> createPartnerLaunch({
    required String partnerName,
    required String region,
    required String locale,
    required int pilotCohortCount,
    String? siteId,
    String? notes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final String? id = await _workflowBridgeService.upsertPartnerLaunch(
        <String, dynamic>{
          if ((siteId ?? '').trim().isNotEmpty) 'siteId': siteId!.trim(),
          if (_partnerId.trim().isNotEmpty) 'partnerId': _partnerId.trim(),
          'partnerName': partnerName.trim(),
          'region': region.trim(),
          'locale': locale.trim(),
          'pilotCohortCount': pilotCohortCount,
          if ((notes ?? '').trim().isNotEmpty) 'notes': notes!.trim(),
        },
      );
      await loadPartnerLaunches();
      if (id == null || id.isEmpty) {
        return null;
      }
      return _partnerLaunches.firstWhere(
        (PartnerLaunch launch) => launch.id == id,
        orElse: () => PartnerLaunch(
          id: id,
          partnerId: _partnerId,
          siteId: siteId,
          partnerName: partnerName.trim(),
          region: region.trim(),
          locale: locale.trim(),
          dueDiligenceStatus: 'pending',
          contractStatus: 'draft',
          planningWorkshopStatus: 'pending',
          trainerOfTrainersStatus: 'pending',
          kpiLoggingStatus: 'pending',
          review90DayStatus: 'pending',
          pilotCohortCount: pilotCohortCount,
          notes: notes?.trim(),
          status: 'planning',
          updatedAt: DateTime.now(),
        ),
      );
    } catch (e) {
      debugPrint('Failed to create partner launch: $e');
      _error = 'Failed to create partner launch';
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load payouts for this partner
  Future<void> loadPayouts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('listPartnerPayouts');
      final HttpsCallableResult<dynamic> result =
          await callable.call(<String, dynamic>{'limit': 200});
      final Map<String, dynamic> payload =
          Map<String, dynamic>.from(result.data as Map<dynamic, dynamic>);
      final List<dynamic> rows =
          payload['payouts'] as List<dynamic>? ?? <dynamic>[];
      final List<Map<String, dynamic>> data = rows
          .whereType<Map<dynamic, dynamic>>()
          .map((Map<dynamic, dynamic> row) => row.map(
              (dynamic key, dynamic value) => MapEntry(key.toString(), value)))
          .toList();

      _payouts = data
          .map((Map<String, dynamic> doc) => Payout(
                id: doc['id'] as String? ?? '',
                partnerId: doc['partnerId'] as String? ?? _partnerId,
                amount: (doc['amount'] as num?)?.toDouble() ?? 0,
                status: _parsePayoutStatus(doc['status'] as String?),
                contractId: doc['contractId'] as String?,
              ))
          .toList();
    } catch (e) {
      if (!_isMissingFirebaseAppError(e)) {
        debugPrint('Failed to load payouts: $e');
      }
      _error = 'Unable to load payouts right now.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  ListingStatus _parseListingStatus(String? status) {
    switch (status) {
      case 'draft':
        return ListingStatus.draft;
      case 'submitted':
        return ListingStatus.submitted;
      case 'approved':
        return ListingStatus.approved;
      case 'published':
        return ListingStatus.published;
      case 'rejected':
        return ListingStatus.rejected;
      case 'archived':
        return ListingStatus.archived;
      default:
        return ListingStatus.draft;
    }
  }

  ContractStatus _parseContractStatus(String? status) {
    switch (status) {
      case 'draft':
        return ContractStatus.draft;
      case 'submitted':
        return ContractStatus.submitted;
      case 'negotiation':
        return ContractStatus.negotiation;
      case 'approved':
        return ContractStatus.approved;
      case 'active':
        return ContractStatus.active;
      case 'completed':
        return ContractStatus.completed;
      case 'terminated':
        return ContractStatus.terminated;
      default:
        return ContractStatus.draft;
    }
  }

  PayoutStatus _parsePayoutStatus(String? status) {
    switch (status) {
      case 'pending':
        return PayoutStatus.pending;
      case 'approved':
        return PayoutStatus.approved;
      case 'paid':
        return PayoutStatus.paid;
      case 'failed':
        return PayoutStatus.failed;
      default:
        return PayoutStatus.pending;
    }
  }
}
