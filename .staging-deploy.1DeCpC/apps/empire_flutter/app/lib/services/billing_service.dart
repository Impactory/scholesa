import 'package:cloud_functions/cloud_functions.dart';

class BillingService {
  BillingService._();
  static final BillingService instance = BillingService._();

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
  }) async {
    final functions = _safeFunctions;
    if (functions == null) return null;
    try {
      final result = await functions.httpsCallable('createCheckoutIntent').call(<String, dynamic>{
        'siteId': siteId,
        'userId': userId,
        'productId': productId,
        'idempotencyKey': idempotencyKey,
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
      final result = await functions.httpsCallable('completeCheckout').call(<String, dynamic>{
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
