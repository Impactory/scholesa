import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../auth/app_state.dart';
import '../../services/telemetry_service.dart';
import '../../services/billing_service.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  late Future<_MarketplaceData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_MarketplaceData> _load() async {
    final appState = context.read<AppState>();
    final userId = appState.user?.uid;
    if (userId == null) return const _MarketplaceData();
    final siteId = appState.primarySiteId;
    final listings = await MarketplaceListingRepository().listPublished(limit: 50);
    final orders = await OrderRepository().listByUser(userId: userId, siteId: appState.primarySiteId, limit: 20);
    final fulfillments = await FulfillmentRepository().listByUser(userId, limit: 20);
    final entitlements = await EntitlementRepository().listByUser(userId: userId, siteId: siteId, limit: 50);
    return _MarketplaceData(listings: listings, orders: orders, fulfillments: fulfillments, entitlements: entitlements);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
  }

  Future<void> _checkout(MarketplaceListingModel listing) async {
    final appState = context.read<AppState>();
    final userId = appState.user?.uid;
    final siteId = appState.primarySiteId;
    final role = appState.role;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to checkout')));
      return;
    }
    if (siteId == null || siteId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a site before checkout')));
      return;
    }

    try {
      final allowedServerRoles = <String>{'hq', 'site'};
      final useServerFlow = role != null && allowedServerRoles.contains(role);

      if (useServerFlow) {
        final intent = await BillingService.instance.createCheckoutIntent(
          siteId: siteId,
          userId: userId,
          productId: listing.id,
          idempotencyKey: '${userId}_${listing.id}_${DateTime.now().millisecondsSinceEpoch}',
        );
        if (intent == null || intent['orderId'] == null) {
          throw Exception('Checkout intent failed');
        }

        final intentId = intent['orderId'] as String;
        final completion = await BillingService.instance.completeCheckout(
          intentId: intentId,
          amount: listing.price,
          currency: listing.currency,
        );

        final orderId = completion?['orderId'] as String? ?? intentId;
        await FulfillmentRepository().createPending(
          orderId: orderId,
          listingId: listing.id,
          userId: userId,
          siteId: siteId,
          note: 'Auto-created from server checkout',
        );
        await TelemetryService.instance.logEvent(
          event: 'order.paid',
          role: role,
          siteId: siteId,
          metadata: <String, dynamic>{
            'orderId': orderId,
            'listingId': listing.id,
            'amount': listing.price,
            'currency': listing.currency,
            'via': 'server',
          },
        );
      } else {
        await TelemetryService.instance.logEvent(
          event: 'order.intent',
          role: role,
          siteId: siteId,
          metadata: <String, dynamic>{
            'listingId': listing.id,
            'price': listing.price,
            'currency': listing.currency,
            'roles': listing.entitlementRoles,
            'via': 'client',
          },
        );

        final orderId = await OrderRepository().createPaidOrder(
          siteId: siteId,
          userId: userId,
          productId: listing.id,
          amount: listing.price,
          currency: listing.currency,
          entitlementRoles: listing.entitlementRoles,
        );
        await EntitlementRepository().grant(
          userId: userId,
          siteId: siteId,
          productId: listing.id,
          roles: listing.entitlementRoles,
        );
        await FulfillmentRepository().createPending(
          orderId: orderId,
          listingId: listing.id,
          userId: userId,
          siteId: siteId,
          note: 'Auto-created from marketplace checkout',
        );
        await TelemetryService.instance.logEvent(
          event: 'order.paid',
          role: role,
          siteId: siteId,
          metadata: <String, dynamic>{
            'orderId': orderId,
            'listingId': listing.id,
            'amount': listing.price,
            'currency': listing.currency,
            'via': 'client',
          },
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checkout complete. Entitlement granted.')));
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Checkout failed: $e')));
    }
  }

  bool _hasEntitlement(
    MarketplaceListingModel listing,
    List<EntitlementModel> entitlements,
    String? siteId,
  ) {
    for (final ent in entitlements) {
      final siteMatches = siteId == null || siteId.isEmpty || ent.siteId == siteId;
      if (!siteMatches) continue;
      if (listing.entitlementRoles.any((role) => ent.roles.contains(role))) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final siteId = appState.primarySiteId;
    return Scaffold(
      appBar: AppBar(title: const Text('Marketplace')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_MarketplaceData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data ?? const _MarketplaceData();
            final listingById = <String, MarketplaceListingModel>{
              for (final l in data.listings) l.id: l,
            };
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Available listings', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (data.listings.isEmpty)
                  const Text('No published listings yet.')
                else
                  ...data.listings.map((l) {
                    final hasEntitlement = _hasEntitlement(l, data.entitlements, siteId);
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.shopping_bag_outlined),
                        title: Text(l.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${l.price} ${l.currency} • Roles: ${l.entitlementRoles.join(', ')}'),
                            if (l.description != null && l.description!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(l.description!, style: Theme.of(context).textTheme.bodySmall),
                              ),
                            if (hasEntitlement)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Already entitled for this site',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.green.shade700),
                                ),
                              ),
                          ],
                        ),
                        trailing: TextButton(
                          onPressed: hasEntitlement ? null : () => _checkout(l),
                          child: Text(hasEntitlement ? 'Entitled' : 'Checkout'),
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 24),
                Text('Your orders', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (data.orders.isEmpty)
                  const Text('No orders yet.')
                else
                  ...data.orders.map((o) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.receipt_long),
                          title: Text('Order ${o.id.substring(0, 6)} • ${o.amount} ${o.currency}'),
                          subtitle: Text('Status: ${o.status} • Product: ${o.productId}'),
                        ),
                      )),
                const SizedBox(height: 24),
                Text('Fulfillment', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (data.fulfillments.isEmpty)
                  const Text('No fulfillments yet.')
                else
                  ...data.fulfillments.map((f) => Card(
                        child: ListTile(
                          leading: Icon(
                            f.status == 'completed' ? Icons.check_circle : Icons.hourglass_bottom,
                            color: f.status == 'completed' ? Colors.green : Colors.orange,
                          ),
                          title: Text(listingById[f.listingId]?.title ?? 'Listing ${f.listingId}'),
                          subtitle: Text('Status: ${f.status}${f.note != null ? ' • ${f.note}' : ''}'),
                        ),
                      )),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MarketplaceData {
  const _MarketplaceData({
    this.listings = const <MarketplaceListingModel>[],
    this.orders = const <OrderModel>[],
    this.fulfillments = const <FulfillmentModel>[],
    this.entitlements = const <EntitlementModel>[],
  });

  final List<MarketplaceListingModel> listings;
  final List<OrderModel> orders;
  final List<FulfillmentModel> fulfillments;
  final List<EntitlementModel> entitlements;
}
