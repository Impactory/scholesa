import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../auth/app_state.dart';

class PartnerListingsScreen extends StatefulWidget {
  const PartnerListingsScreen({super.key});

  @override
  State<PartnerListingsScreen> createState() => _PartnerListingsScreenState();
}

class _PartnerListingsScreenState extends State<PartnerListingsScreen> {
  late Future<_ListingData> _future;
  String? _selectedOrgId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ListingData> _load() async {
    final userId = context.read<AppState>().user?.uid;
    if (userId == null) return const _ListingData();
    final orgs = await PartnerOrgRepository().listMine(userId);
    final orgId = _selectedOrgId ?? (orgs.isNotEmpty ? orgs.first.id : null);
    if (orgId == null) return const _ListingData(orgs: <PartnerOrgModel>[]);
    final listings = await MarketplaceListingRepository().listByPartner(orgId, limit: 50);
    _selectedOrgId = orgId;
    return _ListingData(orgs: orgs, listings: listings);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
  }

  Future<void> _createListing(String orgId) async {
    final userId = context.read<AppState>().user?.uid;
    if (userId == null) return;
    final titleController = TextEditingController();
    final priceController = TextEditingController();
    final entitlementsController = TextEditingController();
    String currency = 'USD';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('New listing'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  TextField(
                    controller: priceController,
                    decoration: const InputDecoration(labelText: 'Price (amount)'),
                    keyboardType: TextInputType.number,
                  ),
                  DropdownMenu<String>(
                    initialSelection: currency,
                    label: const Text('Currency'),
                    dropdownMenuEntries: const ['USD', 'EUR', 'GBP']
                        .map((c) => DropdownMenuEntry<String>(value: c, label: c))
                        .toList(),
                    onSelected: (value) => setStateDialog(() => currency = value ?? 'USD'),
                  ),
                  TextField(
                    controller: entitlementsController,
                    decoration: const InputDecoration(labelText: 'Entitlement roles (comma separated)'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  if (titleController.text.trim().isEmpty || priceController.text.trim().isEmpty) return;
                  Navigator.pop(context, true);
                },
                child: const Text('Create'),
              ),
            ],
          );
        });
      },
    );

    if (!mounted || confirmed != true) return;
    final entitlements = entitlementsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    await MarketplaceListingRepository().createDraft(
      partnerOrgId: orgId,
      title: titleController.text.trim(),
      price: priceController.text.trim(),
      currency: currency,
      entitlementRoles: entitlements,
      createdBy: userId,
    );
    await _refresh();
  }

  Future<void> _submitListing(String id) async {
    final userId = context.read<AppState>().user?.uid;
    if (userId == null) return;
    await MarketplaceListingRepository().submit(id: id, submittedBy: userId);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Listings')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_ListingData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data ?? const _ListingData();
            if (data.orgs.isEmpty) {
              return const Center(child: Text('No partner organizations found for this account.'));
            }
            final listings = data.listings;
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: listings.length + 2,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return DropdownMenu<String>(
                    initialSelection: _selectedOrgId ?? data.orgs.first.id,
                    label: const Text('Partner org'),
                    dropdownMenuEntries:
                        data.orgs.map((o) => DropdownMenuEntry<String>(value: o.id, label: o.name)).toList(),
                    onSelected: (value) {
                      setState(() {
                        _selectedOrgId = value;
                        _future = _load();
                      });
                    },
                  );
                }
                if (index == 1) {
                  return ListTile(
                    leading: const Icon(Icons.add_circle_outline),
                    title: const Text('Create new listing'),
                    onTap: () {
                      final orgId = _selectedOrgId ?? data.orgs.first.id;
                      _createListing(orgId);
                    },
                  );
                }
                final listing = listings[index - 2];
                return ListTile(
                  leading: const Icon(Icons.storefront),
                  title: Text(listing.title),
                  subtitle: Text('${listing.price} ${listing.currency} • Status: ${listing.status}'),
                  trailing: listing.status == 'draft'
                      ? TextButton(onPressed: () => _submitListing(listing.id), child: const Text('Submit'))
                      : null,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ListingData {
  const _ListingData({this.orgs = const <PartnerOrgModel>[], this.listings = const <MarketplaceListingModel>[]});

  final List<PartnerOrgModel> orgs;
  final List<MarketplaceListingModel> listings;
}
