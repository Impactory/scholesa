import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../ui/theme/scholesa_theme.dart';
import 'partner_models.dart';
import 'partner_service.dart';

/// Partner listings management page
/// Based on docs/15_LMS_MARKETPLACE_SPEC.md
class PartnerListingsPage extends StatefulWidget {
  const PartnerListingsPage({super.key});

  @override
  State<PartnerListingsPage> createState() => _PartnerListingsPageState();
}

class _PartnerListingsPageState extends State<PartnerListingsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PartnerService>().loadListings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: const Text('My Listings'),
        backgroundColor: ScholesaColors.partnerGradient.colors.first,
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showCreateListingDialog(context),
          ),
        ],
      ),
      body: Consumer<PartnerService>(
        builder: (BuildContext context, PartnerService service, _) {
          if (service.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (service.listings.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () => service.loadListings(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: service.listings.length,
              itemBuilder: (BuildContext context, int index) {
                return _buildListingCard(service.listings[index]);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ScholesaColors.partnerGradient.colors.first.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.storefront_rounded,
              size: 64,
              color: ScholesaColors.partnerGradient.colors.first,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Listings Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ScholesaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first marketplace listing',
            style: TextStyle(
              fontSize: 14,
              color: ScholesaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showCreateListingDialog(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create Listing'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ScholesaColors.partnerGradient.colors.first,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListingCard(MarketplaceListing listing) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showListingDetails(listing),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: ScholesaColors.partnerGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      listing.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: ScholesaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      listing.category,
                      style: TextStyle(
                        fontSize: 13,
                        color: ScholesaColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        _buildStatusChip(listing.status),
                        const Spacer(),
                        if (listing.price != null)
                          Text(
                            '\$${listing.price!.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: ScholesaColors.success,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: ScholesaColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(ListingStatus status) {
    Color color;
    String label;
    switch (status) {
      case ListingStatus.draft:
        color = Colors.grey;
        label = 'Draft';
      case ListingStatus.submitted:
        color = Colors.orange;
        label = 'Submitted';
      case ListingStatus.approved:
        color = Colors.blue;
        label = 'Approved';
      case ListingStatus.published:
        color = Colors.green;
        label = 'Published';
      case ListingStatus.rejected:
        color = Colors.red;
        label = 'Rejected';
      case ListingStatus.archived:
        color = Colors.grey;
        label = 'Archived';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  void _showCreateListingDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: ScholesaColors.surface,
        title: const Text('Create Listing'),
        content: const Text('Listing creation form would go here.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Listing creation coming soon!')),
              );
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showListingDetails(MarketplaceListing listing) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ScholesaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              listing.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(listing.description),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                _buildStatusChip(listing.status),
                const Spacer(),
                if (listing.price != null)
                  Text(
                    '\$${listing.price!.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Edit coming soon!')),
                      );
                    },
                    child: const Text('Edit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
