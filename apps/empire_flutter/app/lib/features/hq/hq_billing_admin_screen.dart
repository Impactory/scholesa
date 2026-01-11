import 'package:flutter/material.dart';

class HqBillingAdminScreen extends StatelessWidget {
  const HqBillingAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Billing Admin')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('Entitlements and accounts admin (stub).'),
          SizedBox(height: 12),
          Text('Wire to BillingAccount, Subscription, EntitlementGrant per doc 13.'),
        ],
      ),
    );
  }
}
