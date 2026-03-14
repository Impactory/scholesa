/// Partner module data models
/// Based on docs/16_PARTNER_CONTRACTING_WORKFLOWS_SPEC.md
library;

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
    required this.productId,
    this.currency = 'USD',
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
  final String productId;
  final String currency;
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

/// Partner launch workflow model
class PartnerLaunch {
  const PartnerLaunch({
    required this.id,
    required this.partnerId,
    required this.partnerName,
    required this.region,
    required this.locale,
    required this.dueDiligenceStatus,
    required this.contractStatus,
    required this.planningWorkshopStatus,
    required this.trainerOfTrainersStatus,
    required this.kpiLoggingStatus,
    required this.review90DayStatus,
    required this.status,
    this.siteId,
    this.pilotCohortCount,
    this.notes,
    this.updatedAt,
  });

  final String id;
  final String partnerId;
  final String partnerName;
  final String region;
  final String locale;
  final String dueDiligenceStatus;
  final String contractStatus;
  final String planningWorkshopStatus;
  final String trainerOfTrainersStatus;
  final String kpiLoggingStatus;
  final String review90DayStatus;
  final String status;
  final String? siteId;
  final int? pilotCohortCount;
  final String? notes;
  final DateTime? updatedAt;
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
