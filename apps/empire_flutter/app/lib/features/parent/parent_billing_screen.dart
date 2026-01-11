import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../auth/app_state.dart';

class ParentBillingScreen extends StatefulWidget {
  const ParentBillingScreen({super.key});

  @override
  State<ParentBillingScreen> createState() => _ParentBillingScreenState();
}

class _ParentBillingScreenState extends State<ParentBillingScreen> {
  late Future<List<OrderModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<OrderModel>> _load() async {
    final appState = context.read<AppState>();
    final userId = appState.user?.uid;
    if (userId == null) return <OrderModel>[];
    return OrderRepository().listByUser(userId: userId, siteId: appState.primarySiteId, limit: 50);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Billing')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<OrderModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final orders = snapshot.data ?? <OrderModel>[];
            if (orders.isEmpty) {
              return const Center(child: Text('No orders found.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: orders.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final order = orders[index];
                return ListTile(
                  leading: const Icon(Icons.receipt_long),
                  title: Text('Order ${order.id} • ${order.amount} ${order.currency}'),
                  subtitle: Text('Status: ${order.status} • Product: ${order.productId}'),
                  trailing: Text(order.paidAt?.toDate().toLocal().toString().split('.').first ?? ''),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
