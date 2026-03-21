import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/app_state.dart';
import '../../i18n/site_surface_i18n.dart';
import '../../services/billing_service.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';

typedef SiteCreateCheckoutIntent = Future<Map<String, dynamic>?> Function({
  required String siteId,
  required String userId,
  required String productId,
  required String idempotencyKey,
  String? listingId,
});
typedef SiteCompleteCheckout = Future<Map<String, dynamic>?> Function({
  required String intentId,
  String? amount,
  String? currency,
});
typedef SiteMarketplaceSnapshotLoader = Future<SiteMarketplaceSnapshot>
    Function({
  required String siteId,
  required String userId,
});

class SiteMarketplaceSnapshot {
  const SiteMarketplaceSnapshot({
    this.listings = const <Map<String, dynamic>>[],
    this.orders = const <Map<String, dynamic>>[],
    this.entitlements = const <Map<String, dynamic>>[],
    this.fulfillments = const <Map<String, dynamic>>[],
  });

  final List<Map<String, dynamic>> listings;
  final List<Map<String, dynamic>> orders;
  final List<Map<String, dynamic>> entitlements;
  final List<Map<String, dynamic>> fulfillments;
}

class SiteMarketplacePanel extends StatefulWidget {
  const SiteMarketplacePanel({
    super.key,
    this.firestore,
    this.marketplaceSnapshotLoader,
    this.createCheckoutIntent,
    this.completeCheckout,
  });

  final FirebaseFirestore? firestore;
  final SiteMarketplaceSnapshotLoader? marketplaceSnapshotLoader;
  final SiteCreateCheckoutIntent? createCheckoutIntent;
  final SiteCompleteCheckout? completeCheckout;

  @override
  State<SiteMarketplacePanel> createState() => _SiteMarketplacePanelState();
}

class _SiteMarketplacePanelState extends State<SiteMarketplacePanel> {
  bool _isLoading = false;
  String? _error;
  bool _hasLoadedSnapshot = false;
  String? _processingListingId;
  List<_MarketplaceListingItem> _marketplaceListings =
      <_MarketplaceListingItem>[];
  List<_OrderItem> _orders = <_OrderItem>[];
  List<_EntitlementItem> _entitlements = <_EntitlementItem>[];
  List<_FulfillmentItem> _fulfillments = <_FulfillmentItem>[];

  FirebaseFirestore get _firestore => widget.firestore ?? FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMarketplaceData();
    });
  }

  String _t(BuildContext context, String input) {
    return SiteSurfaceI18n.text(context, input);
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, String> listingTitles = <String, String>{
      for (final _MarketplaceListingItem listing in _marketplaceListings)
        listing.id: listing.title,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
              child: Text(
                _t(context, 'Marketplace'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ScholesaColors.textPrimary,
                ),
              ),
            ),
            IconButton(
              tooltip: _t(context, 'Refresh'),
              onPressed: _isLoading ? null : _loadMarketplaceData,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _t(context,
              'Browse purchasable partner offerings with server-backed checkout intents.'),
          style: const TextStyle(
            fontSize: 13,
            color: ScholesaColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        if (_error != null && !_hasLoadedSnapshot)
          _buildLoadErrorCard(
            _t(context, 'Unable to load marketplace data right now'),
          )
        else ...<Widget>[
          if (_error != null)
            _buildStaleDataBanner(
              _t(
                context,
                'Unable to refresh marketplace data right now. Showing the last successful data.',
              ),
            ),
          if (_marketplaceListings.isEmpty)
            _buildInfoCard(
              _t(context, 'No published marketplace offerings are available yet.'),
            )
          else
            Column(
              children: _marketplaceListings
                  .map((item) => _buildMarketplaceCard(context, item))
                  .toList(),
            ),
          const SizedBox(height: 24),
          Text(
            _t(context, 'Purchases & Fulfillment'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ScholesaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _t(context,
                'Track paid orders, granted entitlements, and fulfillment handoff status in one place.'),
            style: const TextStyle(
              fontSize: 13,
              color: ScholesaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: ScholesaColors.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildStatusList(
                    context,
                    title: 'Recent Orders',
                    emptyText: 'No paid orders yet',
                    rows: _orders
                        .map((order) => _StatusRow(
                              title: listingTitles[order.listingId] ??
                                  _productLabel(order.productId),
                              subtitle:
                                  '${_formatMoney(order.amount, order.currency)} • ${order.status}',
                              trailing: order.paidAt != null
                                  ? _formatDate(order.paidAt!)
                                  : order.id,
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  _buildStatusList(
                    context,
                    title: 'Entitlements',
                    emptyText: 'No entitlements granted yet',
                    rows: _entitlements
                        .map((entitlement) => _StatusRow(
                              title: _productLabel(entitlement.productId),
                              subtitle: entitlement.roles.isEmpty
                                  ? _t(context, 'No role grants')
                                  : entitlement.roles.join(', '),
                              trailing: entitlement.createdAt != null
                                  ? _formatDate(entitlement.createdAt!)
                                  : entitlement.id,
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  _buildStatusList(
                    context,
                    title: 'Fulfillment Queue',
                    emptyText: 'No fulfillment records yet',
                    rows: _fulfillments
                        .map((fulfillment) => _StatusRow(
                              title: listingTitles[fulfillment.listingId] ??
                                  fulfillment.listingId,
                              subtitle:
                                  '${fulfillment.status}${fulfillment.note == null || fulfillment.note!.trim().isEmpty ? '' : ' • ${fulfillment.note!.trim()}'}',
                              trailing: fulfillment.updatedAt != null
                                  ? _formatDate(fulfillment.updatedAt!)
                                  : fulfillment.orderId,
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoCard(String message, {Color? tone}) {
    return Card(
      color: ScholesaColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          style: TextStyle(color: tone ?? ScholesaColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildLoadErrorCard(String message) {
    return Card(
      color: ScholesaColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              message,
              style: const TextStyle(color: ScholesaColors.warning),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _isLoading ? null : _loadMarketplaceData,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(_t(context, 'Retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaleDataBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: ScholesaColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketplaceCard(BuildContext context, _MarketplaceListingItem item) {
    final BillingProductCatalogEntry product =
        BillingService.productCatalog[item.productId] ??
            BillingService.productCatalog.values.first;
    final bool isProcessing = _processingListingId == item.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: ScholesaColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.category,
                        style: const TextStyle(
                          fontSize: 12,
                          color: ScholesaColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: ScholesaColors.billingGradient.colors.first
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _formatMoney(item.price ?? product.amountValue, item.currency),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: ScholesaColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            if (item.description?.trim().isNotEmpty == true) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                item.description!.trim(),
                style: const TextStyle(color: ScholesaColors.textSecondary),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _buildPill(context, product.label),
                _buildPill(context, 'SKU: ${item.productId}'),
                if (item.publishedAt != null)
                  _buildPill(context, _formatDate(item.publishedAt!)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isProcessing ? null : () => _purchaseListing(item),
                child: isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_t(context, 'Purchase')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPill(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ScholesaColors.textSecondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _t(context, label),
        style: const TextStyle(
          fontSize: 12,
          color: ScholesaColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildStatusList(
    BuildContext context, {
    required String title,
    required String emptyText,
    required List<_StatusRow> rows,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _t(context, title),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: ScholesaColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          Text(
            _t(context, emptyText),
            style: const TextStyle(color: ScholesaColors.textSecondary),
          )
        else
          Column(
            children: rows
                .map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                row.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: ScholesaColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                row.subtitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: ScholesaColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          row.trailing,
                          style: const TextStyle(
                            fontSize: 12,
                            color: ScholesaColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Future<void> _loadMarketplaceData() async {
    final AppState? appState = _maybeAppState();
    if (appState == null || appState.userId == null) {
      return;
    }
    final String siteId = _siteIdFromState(appState);
    final String userId = appState.userId!.trim();
    if (siteId.isEmpty || userId.isEmpty) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final SiteMarketplaceSnapshot snapshot =
          await _loadMarketplaceSnapshot(siteId: siteId, userId: userId);

      final List<_MarketplaceListingItem> listings = snapshot.listings
          .map(_MarketplaceListingItem.fromData)
          .where(
            (item) => item.productId.trim().isNotEmpty &&
                BillingService.productCatalog.containsKey(item.productId),
          )
          .toList()
        ..sort((a, b) => _compareDates(b.publishedAt, a.publishedAt));

      final List<_OrderItem> orders = snapshot.orders
          .map(_OrderItem.fromData)
          .where((order) => order.siteId == siteId)
          .toList()
        ..sort((a, b) =>
            _compareDates(b.paidAt ?? b.createdAt, a.paidAt ?? a.createdAt));

      final List<_EntitlementItem> entitlements = snapshot.entitlements
          .map(_EntitlementItem.fromData)
          .where((entitlement) => entitlement.siteId == siteId)
          .toList()
        ..sort((a, b) => _compareDates(b.createdAt, a.createdAt));

      final List<_FulfillmentItem> fulfillments = snapshot.fulfillments
          .map(_FulfillmentItem.fromData)
          .where((fulfillment) =>
              fulfillment.siteId == null || fulfillment.siteId == siteId)
          .toList()
        ..sort((a, b) => _compareDates(
            b.updatedAt ?? b.createdAt, a.updatedAt ?? a.createdAt));

      if (!mounted) return;
      setState(() {
        _marketplaceListings = listings;
        _orders = orders;
        _entitlements = entitlements;
        _fulfillments = fulfillments;
        _hasLoadedSnapshot = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _hasLoadedSnapshot
            ? _t(
                context,
                'Unable to refresh marketplace data right now. Showing the last successful data.',
              )
            : _t(context, 'Unable to load marketplace data right now');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<SiteMarketplaceSnapshot> _loadMarketplaceSnapshot({
    required String siteId,
    required String userId,
  }) async {
    if (widget.marketplaceSnapshotLoader != null) {
      return widget.marketplaceSnapshotLoader!(siteId: siteId, userId: userId);
    }

    final QuerySnapshot<Map<String, dynamic>> listingSnapshot = await _firestore
        .collection('marketplaceListings')
        .where('status', isEqualTo: 'published')
        .limit(12)
        .get();
    final QuerySnapshot<Map<String, dynamic>> orderSnapshot = await _firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .limit(20)
        .get();
    final QuerySnapshot<Map<String, dynamic>> entitlementSnapshot =
        await _firestore
            .collection('entitlements')
            .where('userId', isEqualTo: userId)
            .limit(20)
            .get();
    final QuerySnapshot<Map<String, dynamic>> fulfillmentSnapshot =
        await _firestore
            .collection('fulfillments')
            .where('userId', isEqualTo: userId)
            .limit(20)
            .get();

    return SiteMarketplaceSnapshot(
      listings: listingSnapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              <String, dynamic>{'id': doc.id, ...doc.data()})
          .toList(),
      orders: orderSnapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              <String, dynamic>{'id': doc.id, ...doc.data()})
          .toList(),
      entitlements: entitlementSnapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              <String, dynamic>{'id': doc.id, ...doc.data()})
          .toList(),
      fulfillments: fulfillmentSnapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              <String, dynamic>{'id': doc.id, ...doc.data()})
          .toList(),
    );
  }

  Future<void> _purchaseListing(_MarketplaceListingItem listing) async {
    final AppState? appState = _maybeAppState();
    final String userId = (appState?.userId ?? '').trim();
    final String siteId = appState == null ? '' : _siteIdFromState(appState);
    if (userId.isEmpty || siteId.isEmpty) {
      return;
    }

    setState(() => _processingListingId = listing.id);
    try {
      TelemetryService.instance.logEvent(
        event: 'cta.clicked',
        metadata: <String, dynamic>{
          'module': 'site_billing',
          'cta_id': 'purchase_marketplace_listing',
          'surface': 'marketplace_card',
          'listing_id': listing.id,
          'product_id': listing.productId,
        },
      );

      final Map<String, dynamic>? intentResponse =
          await (widget.createCheckoutIntent ??
              BillingService.instance.createCheckoutIntent)(
        siteId: siteId,
        userId: userId,
        productId: listing.productId,
        idempotencyKey:
            'site-$siteId-user-$userId-listing-${listing.id}-${DateTime.now().millisecondsSinceEpoch}',
        listingId: listing.id,
      );
      final String intentId = ((intentResponse?['intentId'] as String?) ??
              (intentResponse?['orderId'] as String?) ??
              '')
          .trim();
      if (intentId.isEmpty) {
        throw StateError('Missing checkout intent id');
      }

      final Map<String, dynamic>? result = await (widget.completeCheckout ??
          BillingService.instance.completeCheckout)(
        intentId: intentId,
      );
      if (result == null) {
        throw StateError('Checkout completion failed');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(context, 'Marketplace purchase recorded and fulfillment queued'),
          ),
          backgroundColor: ScholesaColors.success,
        ),
      );
      await _loadMarketplaceData();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(context, 'Unable to complete marketplace checkout right now'),
          ),
          backgroundColor: ScholesaColors.warning,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _processingListingId = null);
      }
    }
  }

  AppState? _maybeAppState() {
    try {
      return context.read<AppState>();
    } catch (_) {
      return null;
    }
  }

  String _siteIdFromState(AppState appState) {
    return (appState.activeSiteId ??
            (appState.siteIds.isNotEmpty ? appState.siteIds.first : ''))
        .trim();
  }

  String _productLabel(String productId) {
    return BillingService.productCatalog[productId]?.label ?? productId;
  }

  String _formatMoney(double amount, String currency) {
    final String symbol = currency.toUpperCase() == 'USD' ? '\$' : currency;
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  int _compareDates(DateTime? left, DateTime? right) {
    final int leftMillis = left?.millisecondsSinceEpoch ?? 0;
    final int rightMillis = right?.millisecondsSinceEpoch ?? 0;
    return leftMillis.compareTo(rightMillis);
  }

  String _formatDate(DateTime value) {
    const List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[value.month - 1]} ${value.day}, ${value.year}';
  }
}

class _MarketplaceListingItem {
  const _MarketplaceListingItem({
    required this.id,
    required this.title,
    required this.category,
    required this.productId,
    required this.currency,
    this.description,
    this.price,
    this.publishedAt,
  });

  factory _MarketplaceListingItem.fromData(Map<String, dynamic> data) {
    final dynamic rawPublishedAt = data['publishedAt'];
    return _MarketplaceListingItem(
      id: data['id'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      category: data['category'] as String? ?? 'General',
      productId: data['productId'] as String? ?? '',
      currency: data['currency'] as String? ?? 'USD',
      price: (data['price'] as num?)?.toDouble(),
      publishedAt: rawPublishedAt is Timestamp
          ? rawPublishedAt.toDate()
          : rawPublishedAt is DateTime
              ? rawPublishedAt
          : null,
    );
  }

  final String id;
  final String title;
  final String? description;
  final String category;
  final String productId;
  final String currency;
  final double? price;
  final DateTime? publishedAt;
}

class _OrderItem {
  const _OrderItem({
    required this.id,
    required this.siteId,
    required this.productId,
    required this.amount,
    required this.currency,
    required this.status,
    this.listingId,
    this.createdAt,
    this.paidAt,
  });

  factory _OrderItem.fromData(Map<String, dynamic> data) {
    final dynamic rawAmount = data['amount'];
    final dynamic rawCreatedAt = data['createdAt'];
    final dynamic rawPaidAt = data['paidAt'];
    final double parsedAmount = rawAmount is num
        ? rawAmount.toDouble()
        : double.tryParse(rawAmount?.toString() ?? '0') ?? 0;
    return _OrderItem(
      id: data['id'] as String? ?? '',
      siteId: data['siteId'] as String? ?? '',
      productId: data['productId'] as String? ?? '',
      amount: parsedAmount,
      currency: data['currency'] as String? ?? 'USD',
      status: data['status'] as String? ?? 'paid',
      listingId: data['listingId'] as String?,
      createdAt: rawCreatedAt is Timestamp
          ? rawCreatedAt.toDate()
          : rawCreatedAt is DateTime
              ? rawCreatedAt
          : null,
      paidAt: rawPaidAt is Timestamp
          ? rawPaidAt.toDate()
          : rawPaidAt is DateTime
              ? rawPaidAt
          : null,
    );
  }

  final String id;
  final String siteId;
  final String productId;
  final double amount;
  final String currency;
  final String status;
  final String? listingId;
  final DateTime? createdAt;
  final DateTime? paidAt;
}

class _EntitlementItem {
  const _EntitlementItem({
    required this.id,
    required this.siteId,
    required this.productId,
    required this.roles,
    this.createdAt,
  });

  factory _EntitlementItem.fromData(Map<String, dynamic> data) {
    final dynamic rawCreatedAt = data['createdAt'];
    return _EntitlementItem(
      id: data['id'] as String? ?? '',
      siteId: data['siteId'] as String? ?? '',
      productId: data['productId'] as String? ?? '',
      roles: List<String>.from(data['roles'] as List? ?? const <String>[]),
      createdAt: rawCreatedAt is Timestamp
          ? rawCreatedAt.toDate()
          : rawCreatedAt is DateTime
              ? rawCreatedAt
          : null,
    );
  }

  final String id;
  final String siteId;
  final String productId;
  final List<String> roles;
  final DateTime? createdAt;
}

class _FulfillmentItem {
  const _FulfillmentItem({
    required this.id,
    required this.orderId,
    required this.listingId,
    required this.status,
    this.siteId,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  factory _FulfillmentItem.fromData(Map<String, dynamic> data) {
    final dynamic rawCreatedAt = data['createdAt'];
    final dynamic rawUpdatedAt = data['updatedAt'];
    return _FulfillmentItem(
      id: data['id'] as String? ?? '',
      orderId: data['orderId'] as String? ?? '',
      listingId: data['listingId'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      siteId: data['siteId'] as String?,
      note: data['note'] as String?,
      createdAt: rawCreatedAt is Timestamp
          ? rawCreatedAt.toDate()
          : rawCreatedAt is DateTime
              ? rawCreatedAt
          : null,
      updatedAt: rawUpdatedAt is Timestamp
          ? rawUpdatedAt.toDate()
          : rawUpdatedAt is DateTime
              ? rawUpdatedAt
          : null,
    );
  }

  final String id;
  final String orderId;
  final String listingId;
  final String status;
  final String? siteId;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class _StatusRow {
  const _StatusRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final String trailing;
}
