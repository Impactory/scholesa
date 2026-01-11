/// Partner module data models
/// Based on docs/16_PARTNER_CONTRACTING_WORKFLOWS_SPEC.md

/// Marketplace listing status
enum ListingStatus {
  draft,
  submitted,
  approved,
  published,
  rejected,
  archived,
}

/// Contract status workflow
enum ContractStatus {
  draft,
  submitted,
  negotiation,
  approved,
  active,
  completed,
  terminated,
}

/// Deliverable status
enum DeliverableStatus {
  planned,
  inProgress,
  submitted,
  accepted,
  rejected,
}

/// Payout status
enum PayoutStatus {
  pending,
  approved,
  paid,
  failed,
}

/// Marketplace listing model
class MarketplaceListing {
  const MarketplaceListing({
    required this.id,
    required this.partnerId,
    required this.title,
    required this.description,
    required this.status,
    required this.category,
    this.price,
    this.imageUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String partnerId;
  final String title;
  final String description;
  final ListingStatus status;
  final String category;
  final double? price;
  final String? imageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

/// Partner contract model
class PartnerContract {
  const PartnerContract({
    required this.id,
    required this.partnerId,
    required this.siteId,
    required this.title,
    required this.status,
    required this.totalValue,
    this.startDate,
    this.endDate,
    this.deliverables = const <PartnerDeliverable>[],
  });

  final String id;
  final String partnerId;
  final String siteId;
  final String title;
  final ContractStatus status;
  final double totalValue;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<PartnerDeliverable> deliverables;
}

/// Partner deliverable model
class PartnerDeliverable {
  const PartnerDeliverable({
    required this.id,
    required this.contractId,
    required this.title,
    required this.status,
    this.dueDate,
    this.submittedAt,
    this.notes,
  });

  final String id;
  final String contractId;
  final String title;
  final DeliverableStatus status;
  final DateTime? dueDate;
  final DateTime? submittedAt;
  final String? notes;
}

/// Payout model
class Payout {
  const Payout({
    required this.id,
    required this.partnerId,
    required this.amount,
    required this.status,
    this.contractId,
    this.requestedAt,
    this.paidAt,
    this.notes,
  });

  final String id;
  final String partnerId;
  final double amount;
  final PayoutStatus status;
  final String? contractId;
  final DateTime? requestedAt;
  final DateTime? paidAt;
  final String? notes;
}
