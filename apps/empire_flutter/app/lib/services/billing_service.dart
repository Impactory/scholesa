import 'package:cloud_functions/cloud_functions.dart';

class BillingProductCatalogEntry {
  const BillingProductCatalogEntry({
    required this.id,
    required this.label,
    required this.amount,
    required this.currency,
  });

  final String id;
  final String label;
  final String amount;
  final String currency;

  double get amountValue => double.tryParse(amount) ?? 0;
}

class BillingService {
  BillingService._();
  static final BillingService instance = BillingService._();

  static const Map<String, BillingProductCatalogEntry> productCatalog =
      <String, BillingProductCatalogEntry>{
    'learner-seat': BillingProductCatalogEntry(
      id: 'learner-seat',
      label: 'Learner Seat',
      amount: '49',
      currency: 'USD',
    ),
    'educator-seat': BillingProductCatalogEntry(
      id: 'educator-seat',
      label: 'Educator Seat',
      amount: '99',
      currency: 'USD',
    ),
    'parent-seat': BillingProductCatalogEntry(
      id: 'parent-seat',
      label: 'Parent Seat',
      amount: '29',
      currency: 'USD',
    ),
    'site-license': BillingProductCatalogEntry(
      id: 'site-license',
      label: 'Site License',
      amount: '499',
      currency: 'USD',
    ),
  };

  FirebaseFunctions? _functions;

  FirebaseFunctions? get _safeFunctions {
    if (_functions != null) return _functions;
    try {
      _functions = FirebaseFunctions.instance;
    } catch (_) {
      return null;
    }
    return _functions;
  }

  Future<Map<String, dynamic>?> createCheckoutIntent({
    required String siteId,
    required String userId,
    required String productId,
    required String idempotencyKey,
    String? listingId,
  }) async {
    final functions = _safeFunctions;
    if (functions == null) return null;
    try {
      final result = await functions
          .httpsCallable('createCheckoutIntent')
          .call(<String, dynamic>{
        'siteId': siteId,
        'userId': userId,
        'productId': productId,
        'idempotencyKey': idempotencyKey,
        if (listingId != null && listingId.trim().isNotEmpty)
          'listingId': listingId.trim(),
      });
      return Map<String, dynamic>.from(result.data as Map);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> completeCheckout({
    required String intentId,
    String? amount,
    String? currency,
  }) async {
    final functions = _safeFunctions;
    if (functions == null) return null;
    try {
      final result = await functions
          .httpsCallable('completeCheckout')
          .call(<String, dynamic>{
        'intentId': intentId,
        if (amount != null) 'amount': amount,
        if (currency != null) 'currency': currency,
      });
      return Map<String, dynamic>.from(result.data as Map);
    } catch (_) {
      return null;
    }
  }
}
