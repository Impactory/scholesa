import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../auth/app_state.dart';
import '../../services/telemetry_service.dart';

class HqApprovalsScreen extends StatefulWidget {
  const HqApprovalsScreen({super.key});

  @override
  State<HqApprovalsScreen> createState() => _HqApprovalsScreenState();
}

class _HqApprovalsScreenState extends State<HqApprovalsScreen> {
  late Future<_ApprovalData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ApprovalData> _load() async {
    final listings = await MarketplaceListingRepository().listPendingApproval(limit: 50);
    final contracts = await PartnerContractRepository().listPendingApproval(limit: 50);
    final payouts = await PayoutRepository().listPendingApproval(limit: 50);
    return _ApprovalData(listings: listings, contracts: contracts, payouts: payouts);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
  }

  Future<void> _approveListing(MarketplaceListingModel listing) async {
    final approverId = context.read<AppState>().user?.uid ?? 'hq';
    final listingId = listing.id;
    try {
      await MarketplaceListingRepository().approve(id: listingId, approverId: approverId);
      await MarketplaceListingRepository().publish(id: listingId);
      await AuditLogRepository().log(
        AuditLogModel(
          id: 'audit-listing-approve-$listingId-${DateTime.now().millisecondsSinceEpoch}',
          actorId: approverId,
          actorRole: 'hq',
          action: 'listing.approve',
          entityType: 'marketplaceListing',
          entityId: listingId,
          details: {
            'partnerOrgId': listing.partnerOrgId,
            'title': listing.title,
            'price': listing.price,
            'currency': listing.currency,
          },
        ),
      );
      await TelemetryService.instance.logEvent(
        event: 'contract.approved',
        role: 'hq',
        metadata: {'entity': 'listing', 'id': listingId},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing approved and published')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to approve listing')));
      }
    } finally {
      await _refresh();
    }
  }

  Future<void> _approveContract(PartnerContractModel contract) async {
    final approverId = context.read<AppState>().user?.uid ?? 'hq';
    final contractId = contract.id;
    try {
      await PartnerContractRepository().approve(id: contractId, approvedBy: approverId);
      await AuditLogRepository().log(
        AuditLogModel(
          id: 'audit-contract-approve-$contractId-${DateTime.now().millisecondsSinceEpoch}',
          actorId: approverId,
          actorRole: 'hq',
          action: 'contract.approve',
          entityType: 'partnerContract',
          entityId: contractId,
          details: {
            'partnerOrgId': contract.partnerOrgId,
            'title': contract.title,
            'amount': contract.amount,
            'currency': contract.currency,
          },
        ),
      );
      await TelemetryService.instance.logEvent(
        event: 'contract.approved',
        role: 'hq',
        metadata: {'entity': 'contract', 'id': contractId},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contract approved')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to approve contract')));
      }
    } finally {
      await _refresh();
    }
  }

  Future<void> _approvePayout(PayoutModel payout) async {
    final approverId = context.read<AppState>().user?.uid ?? 'hq';
    final payoutId = payout.id;
    try {
      await PayoutRepository().approve(id: payoutId, approvedBy: approverId);
      await AuditLogRepository().log(
        AuditLogModel(
          id: 'audit-payout-approve-$payoutId-${DateTime.now().millisecondsSinceEpoch}',
          actorId: approverId,
          actorRole: 'hq',
          action: 'payout.approve',
          entityType: 'payout',
          entityId: payoutId,
          details: {
            'contractId': payout.contractId,
            'amount': payout.amount,
            'currency': payout.currency,
          },
        ),
      );
      await TelemetryService.instance.logEvent(
        event: 'payout.approved',
        role: 'hq',
        metadata: {'entity': 'payout', 'id': payoutId},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payout approved')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to approve payout')));
      }
    } finally {
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Approvals Queue')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_ApprovalData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data ?? const _ApprovalData();
            if (data.isEmpty) {
              return const Center(child: Text('No pending approvals.'));
            }
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                const Text('Marketplace listings', style: TextStyle(fontWeight: FontWeight.bold)),
                if (data.listings.isEmpty)
                  const ListTile(title: Text('None pending'))
                else
                  ...data.listings.map(
                    (l) => ListTile(
                      leading: const Icon(Icons.storefront),
                      title: Text(l.title),
                      subtitle: Text('${l.price} ${l.currency} • Partner: ${l.partnerOrgId}'),
                      trailing: TextButton(onPressed: () => _approveListing(l), child: const Text('Approve')),
                    ),
                  ),
                const Divider(),
                const Text('Partner contracts', style: TextStyle(fontWeight: FontWeight.bold)),
                if (data.contracts.isEmpty)
                  const ListTile(title: Text('None pending'))
                else
                  ...data.contracts.map(
                    (c) => ListTile(
                      leading: const Icon(Icons.handshake),
                      title: Text(c.title),
                      subtitle: Text('${c.amount} ${c.currency} • Partner: ${c.partnerOrgId}'),
                      trailing: TextButton(onPressed: () => _approveContract(c), child: const Text('Approve')),
                    ),
                  ),
                const Divider(),
                const Text('Payouts', style: TextStyle(fontWeight: FontWeight.bold)),
                if (data.payouts.isEmpty)
                  const ListTile(title: Text('None pending'))
                else
                  ...data.payouts.map(
                    (p) => ListTile(
                      leading: const Icon(Icons.payments_outlined),
                      title: Text('${p.amount} ${p.currency}'),
                      subtitle: Text('Contract: ${p.contractId} • Status: ${p.status}'),
                      trailing: TextButton(onPressed: () => _approvePayout(p), child: const Text('Approve')),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ApprovalData {
  const _ApprovalData({
    this.listings = const <MarketplaceListingModel>[],
    this.contracts = const <PartnerContractModel>[],
    this.payouts = const <PayoutModel>[],
  });

  final List<MarketplaceListingModel> listings;
  final List<PartnerContractModel> contracts;
  final List<PayoutModel> payouts;

  bool get isEmpty => listings.isEmpty && contracts.isEmpty && payouts.isEmpty;
}
