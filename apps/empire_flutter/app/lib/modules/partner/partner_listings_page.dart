import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../i18n/workflow_surface_i18n.dart';
import '../../services/billing_service.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';
import 'partner_models.dart';
import 'partner_service.dart';

String _tPartnerListings(BuildContext context, String input) {
  return WorkflowSurfaceI18n.text(context, input);
}

/// Partner listings management page
/// Based on docs/15_LMS_MARKETPLACE_SPEC.md
class PartnerListingsPage extends StatefulWidget {
  const PartnerListingsPage({super.key});

  @override
  State<PartnerListingsPage> createState() => _PartnerListingsPageState();
}

class _PartnerListingsPageState extends State<PartnerListingsPage> {
  BillingProductCatalogEntry _productEntry(String productId) {
    return BillingService.productCatalog[productId] ??
        const BillingProductCatalogEntry(
          id: 'custom',
          label: 'Custom Offering',
          amount: '0',
          currency: 'USD',
        );
  }

  String _formatMoney(double amount, String currency) {
    final String symbol = currency.toUpperCase() == 'USD' ? '\$' : currency;
    return '$symbol${amount.toStringAsFixed(2)}';
  }

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
        title: Text(_tPartnerListings(context, 'My Listings')),
        backgroundColor: ScholesaColors.partnerGradient.colors.first,
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'module': 'partner_listings',
                  'cta_id': 'open_create_listing',
                  'surface': 'appbar',
                },
              );
              _showCreateListingDialog(context);
            },
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
            onRefresh: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'module': 'partner_listings',
                  'cta_id': 'refresh_listings',
                  'surface': 'listings_list',
                },
              );
              return service.loadListings();
            },
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
              color: ScholesaColors.partnerGradient.colors.first
                  .withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.storefront_rounded,
              size: 64,
              color: ScholesaColors.partnerGradient.colors.first,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _tPartnerListings(context, 'No Listings Yet'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ScholesaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _tPartnerListings(context, 'Create your first marketplace listing'),
            style: TextStyle(
              fontSize: 14,
              color: ScholesaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'module': 'partner_listings',
                  'cta_id': 'open_create_listing',
                  'surface': 'empty_state',
                },
              );
              _showCreateListingDialog(context);
            },
            icon: const Icon(Icons.add_rounded),
            label: Text(_tPartnerListings(context, 'Create Listing')),
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
                child: const Icon(Icons.inventory_2_rounded,
                    color: Colors.white, size: 28),
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
                      style: const TextStyle(
                        fontSize: 13,
                        color: ScholesaColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _productEntry(listing.productId).label,
                      style: const TextStyle(
                        fontSize: 12,
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
                            _formatMoney(listing.price!, listing.currency),
                            style: const TextStyle(
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
              const Icon(Icons.chevron_right_rounded,
                  color: ScholesaColors.textSecondary),
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
        label = _tPartnerListings(context, 'Draft');
      case ListingStatus.submitted:
        color = Colors.orange;
        label = _tPartnerListings(context, 'Submitted');
      case ListingStatus.approved:
        color = Colors.blue;
        label = _tPartnerListings(context, 'Approved');
      case ListingStatus.published:
        color = Colors.green;
        label = _tPartnerListings(context, 'Published');
      case ListingStatus.rejected:
        color = Colors.red;
        label = _tPartnerListings(context, 'Rejected');
      case ListingStatus.archived:
        color = Colors.grey;
        label = _tPartnerListings(context, 'Archived');
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
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'partner_listings',
        'cta_id': 'open_create_listing_dialog',
        'surface': 'dialog',
      },
    );
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    String selectedCategory = 'Programs';
    String selectedProductId = 'learner-seat';
    bool isSubmitting = false;

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context,
                void Function(void Function()) setLocalState) =>
            AlertDialog(
          backgroundColor: ScholesaColors.surface,
          title: Text(_tPartnerListings(context, 'Create Listing')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: _tPartnerListings(context, 'Title'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: _tPartnerListings(context, 'Description'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedProductId,
                  decoration: InputDecoration(
                    labelText: _tPartnerListings(context, 'Product'),
                    border: OutlineInputBorder(),
                  ),
                  items: BillingService.productCatalog.values
                      .map((BillingProductCatalogEntry product) =>
                          DropdownMenuItem<String>(
                            value: product.id,
                            child: Text(
                              '${_tPartnerListings(context, product.label)} • ${_formatMoney(product.amountValue, product.currency)}',
                            ),
                          ))
                      .toList(),
                  onChanged: (String? value) {
                    if (value != null) {
                      setLocalState(() => selectedProductId = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: InputDecoration(
                    labelText: _tPartnerListings(context, 'Category'),
                    border: OutlineInputBorder(),
                  ),
                  items: <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                      value: 'Programs',
                      child: Text(_tPartnerListings(context, 'Programs')),
                    ),
                    DropdownMenuItem<String>(
                      value: 'Workshops',
                      child: Text(_tPartnerListings(context, 'Workshops')),
                    ),
                    DropdownMenuItem<String>(
                      value: 'Resources',
                      child: Text(_tPartnerListings(context, 'Resources')),
                    ),
                    DropdownMenuItem<String>(
                      value: 'General',
                      child: Text(_tPartnerListings(context, 'General')),
                    ),
                  ],
                  onChanged: (String? value) {
                    if (value != null) {
                      setLocalState(() => selectedCategory = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_tPartnerListings(context, 'Checkout price')}: ${_formatMoney(_productEntry(selectedProductId).amountValue, _productEntry(selectedProductId).currency)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: ScholesaColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () {
                      Navigator.pop(dialogContext);
                    },
              child: Text(_tPartnerListings(context, 'Cancel')),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final String title = titleController.text.trim();
                      final String description =
                          descriptionController.text.trim();
                      if (title.isEmpty || description.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_tPartnerListings(
                                context, 'Title and description are required')),
                          ),
                        );
                        return;
                      }

                      setLocalState(() => isSubmitting = true);
                      final BillingProductCatalogEntry product =
                          _productEntry(selectedProductId);
                      final PartnerService service =
                          context.read<PartnerService>();
                      final MarketplaceListing? created =
                          await service.createListing(
                        title: title,
                        description: description,
                        category: selectedCategory,
                        productId: selectedProductId,
                        price: product.amountValue,
                        currency: product.currency,
                      );

                      if (!context.mounted) {
                        return;
                      }

                      setLocalState(() => isSubmitting = false);

                      if (created == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              service.error ??
                                  _tPartnerListings(
                                      context, 'Failed to create listing'),
                            ),
                          ),
                        );
                        return;
                      }

                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: <String, dynamic>{
                          'module': 'partner_listings',
                          'cta_id': 'submit_create_listing',
                          'surface': 'create_listing_dialog',
                          'listing_id': created.id,
                          'category': created.category,
                          'product_id': created.productId,
                        },
                      );
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_tPartnerListings(
                              context, 'Listing created and added to list')),
                        ),
                      );
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_tPartnerListings(context, 'Create')),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      titleController.dispose();
      descriptionController.dispose();
    });
  }

  void _showListingDetails(MarketplaceListing listing) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'partner_listings',
        'cta_id': 'open_listing_details',
        'surface': 'listing_card',
        'listing_id': listing.id,
        'status': listing.status.name,
      },
    );
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
            Text(
              _productEntry(listing.productId).label,
              style: const TextStyle(
                fontSize: 13,
                color: ScholesaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                _buildStatusChip(listing.status),
                const Spacer(),
                if (listing.price != null)
                  Text(
                    _formatMoney(listing.price!, listing.currency),
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
                    child: Text(_tPartnerListings(context, 'Close')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: <String, dynamic>{
                          'module': 'partner_listings',
                          'cta_id': 'open_edit_listing',
                          'surface': 'listing_details_sheet',
                          'listing_id': listing.id,
                        },
                      );
                      Navigator.pop(context);
                      _showEditListingDialog(context, listing);
                    },
                    child: Text(_tPartnerListings(context, 'Edit')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditListingDialog(
      BuildContext context, MarketplaceListing listing) {
    final TextEditingController titleController =
        TextEditingController(text: listing.title);
    final TextEditingController descriptionController =
        TextEditingController(text: listing.description);

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(_tPartnerListings(context, 'Edit Listing')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: titleController,
              decoration:
                  InputDecoration(labelText: _tPartnerListings(context, 'Title')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                  labelText: _tPartnerListings(context, 'Description')),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_tPartnerListings(context, 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'module': 'partner_listings',
                  'cta_id': 'save_edit_listing',
                  'surface': 'edit_listing_dialog',
                  'listing_id': listing.id,
                },
              );
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      '${_tPartnerListings(context, 'Listing updated')}: ${titleController.text.trim()}'),
                ),
              );
            },
            child: Text(_tPartnerListings(context, 'Save')),
          ),
        ],
      ),
    );
  }
}
