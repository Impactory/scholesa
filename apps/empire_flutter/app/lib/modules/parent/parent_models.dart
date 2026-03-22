import 'package:equatable/equatable.dart';

/// Model for a learner's summary visible to parents
class LearnerSummary extends Equatable {
  // Progress per pillar (0-1)

  const LearnerSummary({
    required this.learnerId,
    required this.learnerName,
    this.photoUrl,
    required this.currentLevel,
    required this.totalXp,
    required this.missionsCompleted,
    required this.currentStreak,
    required this.attendanceRate,
    this.recentActivities = const [],
    this.upcomingEvents = const [],
    this.pillarProgress = const {},
    this.capabilitySnapshot = const CapabilitySnapshot(),
    this.evidenceSummary = const EvidenceSummary(),
    this.growthSummary = const GrowthSummary(),
    this.portfolioSnapshot = const PortfolioSnapshot(),
    this.portfolioItemsPreview = const [],
    this.ideationPassport = const IdeationPassport(),
    this.growthTimeline = const [],
  });
  final String learnerId;
  final String learnerName;
  final String? photoUrl;
  final int currentLevel;
  final int totalXp;
  final int missionsCompleted;
  final int currentStreak;
  final double attendanceRate;
  final List<RecentActivity> recentActivities;
  final List<UpcomingEvent> upcomingEvents;
  final Map<String, double> pillarProgress;
  final CapabilitySnapshot capabilitySnapshot;
  final EvidenceSummary evidenceSummary;
  final GrowthSummary growthSummary;
  final PortfolioSnapshot portfolioSnapshot;
  final List<PortfolioPreviewItem> portfolioItemsPreview;
  final IdeationPassport ideationPassport;
  final List<GrowthTimelineEntry> growthTimeline;

  @override
  List<Object?> get props => <Object?>[
        learnerId,
        learnerName,
        photoUrl,
        currentLevel,
        totalXp,
        missionsCompleted,
        currentStreak,
        attendanceRate,
        recentActivities,
        upcomingEvents,
        pillarProgress,
        capabilitySnapshot,
        evidenceSummary,
        growthSummary,
        portfolioSnapshot,
        portfolioItemsPreview,
        ideationPassport,
        growthTimeline,
      ];
}

class EvidenceSummary extends Equatable {
  const EvidenceSummary({
    this.recordCount = 0,
    this.reviewedCount = 0,
    this.portfolioLinkedCount = 0,
    this.verificationPromptCount = 0,
    this.latestEvidenceAt,
  });

  final int recordCount;
  final int reviewedCount;
  final int portfolioLinkedCount;
  final int verificationPromptCount;
  final DateTime? latestEvidenceAt;

  @override
  List<Object?> get props => <Object?>[
        recordCount,
        reviewedCount,
        portfolioLinkedCount,
        verificationPromptCount,
        latestEvidenceAt,
      ];
}

class GrowthSummary extends Equatable {
  const GrowthSummary({
    this.capabilityCount = 0,
    this.updatedCapabilityCount = 0,
    this.averageLevel = 0,
    this.latestLevel = 0,
    this.latestGrowthAt,
  });

  final int capabilityCount;
  final int updatedCapabilityCount;
  final double averageLevel;
  final int latestLevel;
  final DateTime? latestGrowthAt;

  @override
  List<Object?> get props => <Object?>[
        capabilityCount,
        updatedCapabilityCount,
        averageLevel,
        latestLevel,
        latestGrowthAt,
      ];
}

class GrowthTimelineEntry extends Equatable {
  const GrowthTimelineEntry({
    required this.capabilityId,
    required this.title,
    required this.pillar,
    required this.level,
    this.occurredAt,
    this.reviewingEducatorName,
    this.rubricRawScore,
    this.rubricMaxScore,
    this.missionAttemptId,
  });

  final String capabilityId;
  final String title;
  final String pillar;
  final int level;
  final DateTime? occurredAt;
  final String? reviewingEducatorName;
  final int? rubricRawScore;
  final int? rubricMaxScore;
  final String? missionAttemptId;

  @override
  List<Object?> get props => <Object?>[
        capabilityId,
        title,
        pillar,
        level,
        occurredAt,
        reviewingEducatorName,
        rubricRawScore,
        rubricMaxScore,
        missionAttemptId,
      ];
}

class ProofCheckpointPreview extends Equatable {
  const ProofCheckpointPreview({
    required this.id,
    required this.summary,
    this.artifactNote,
    this.createdAt,
  });

  final String id;
  final String summary;
  final String? artifactNote;
  final DateTime? createdAt;

  @override
  List<Object?> get props => <Object?>[
        id,
        summary,
        artifactNote,
        createdAt,
      ];
}

class CapabilitySnapshot extends Equatable {
  const CapabilitySnapshot({
    this.futureSkills = 0,
    this.leadership = 0,
    this.impact = 0,
    this.overall = 0,
    this.band = 'emerging',
  });

  final double futureSkills;
  final double leadership;
  final double impact;
  final double overall;
  final String band;

  @override
  List<Object?> get props => <Object?>[
        futureSkills,
        leadership,
        impact,
        overall,
        band,
      ];
}

class PortfolioSnapshot extends Equatable {
  const PortfolioSnapshot({
    this.artifactCount = 0,
    this.publishedArtifactCount = 0,
    this.badgeCount = 0,
    this.projectCount = 0,
    this.evidenceLinkedArtifactCount = 0,
    this.verifiedArtifactCount = 0,
    this.latestArtifactAt,
  });

  final int artifactCount;
  final int publishedArtifactCount;
  final int badgeCount;
  final int projectCount;
  final int evidenceLinkedArtifactCount;
  final int verifiedArtifactCount;
  final DateTime? latestArtifactAt;

  @override
  List<Object?> get props => <Object?>[
        artifactCount,
        publishedArtifactCount,
        badgeCount,
        projectCount,
        evidenceLinkedArtifactCount,
        verifiedArtifactCount,
        latestArtifactAt,
      ];
}

class PortfolioPreviewItem extends Equatable {
  const PortfolioPreviewItem({
    required this.id,
    required this.title,
    required this.description,
    required this.pillar,
    required this.type,
    required this.completedAt,
    this.verificationStatus,
    this.evidenceLinked = false,
    this.capabilityTitles = const [],
    this.evidenceRecordIds = const [],
    this.missionAttemptId,
    this.verificationPrompt,
    this.proofOfLearningStatus,
    this.aiDisclosureStatus,
    this.proofHasExplainItBack = false,
    this.proofHasOralCheck = false,
    this.proofHasMiniRebuild = false,
    this.aiHasLearnerDisclosure = false,
    this.aiLearnerDeclaredUsed = false,
    this.aiHelpEventCount = 0,
    this.aiHasExplainItBackEvidence = false,
    this.aiHasEducatorAiFeedback = false,
    this.proofCheckpointCount = 0,
    this.proofExplainItBackExcerpt,
    this.proofOralCheckExcerpt,
    this.proofMiniRebuildExcerpt,
    this.proofCheckpoints = const [],
    this.aiAssistanceDetails,
    this.reviewingEducatorName,
    this.reviewedAt,
    this.rubricRawScore,
    this.rubricMaxScore,
    this.rubricLevel,
  });

  final String id;
  final String title;
  final String description;
  final String pillar;
  final String type;
  final DateTime completedAt;
  final String? verificationStatus;
  final bool evidenceLinked;
  final List<String> capabilityTitles;
  final List<String> evidenceRecordIds;
  final String? missionAttemptId;
  final String? verificationPrompt;
  final String? proofOfLearningStatus;
  final String? aiDisclosureStatus;
  final bool proofHasExplainItBack;
  final bool proofHasOralCheck;
  final bool proofHasMiniRebuild;
  final int proofCheckpointCount;
  final String? proofExplainItBackExcerpt;
  final String? proofOralCheckExcerpt;
  final String? proofMiniRebuildExcerpt;
  final List<ProofCheckpointPreview> proofCheckpoints;
  final bool aiHasLearnerDisclosure;
  final bool aiLearnerDeclaredUsed;
  final int aiHelpEventCount;
  final bool aiHasExplainItBackEvidence;
  final bool aiHasEducatorAiFeedback;
  final String? aiAssistanceDetails;
  final String? reviewingEducatorName;
  final DateTime? reviewedAt;
  final int? rubricRawScore;
  final int? rubricMaxScore;
  final int? rubricLevel;

  @override
  List<Object?> get props => <Object?>[
        id,
        title,
        description,
        pillar,
        type,
        completedAt,
        verificationStatus,
        evidenceLinked,
        capabilityTitles,
        evidenceRecordIds,
        missionAttemptId,
        verificationPrompt,
        proofOfLearningStatus,
        aiDisclosureStatus,
        proofHasExplainItBack,
        proofHasOralCheck,
        proofHasMiniRebuild,
        aiHasLearnerDisclosure,
        aiLearnerDeclaredUsed,
        aiHelpEventCount,
        aiHasExplainItBackEvidence,
        aiHasEducatorAiFeedback,
        proofCheckpointCount,
        proofExplainItBackExcerpt,
        proofOralCheckExcerpt,
        proofMiniRebuildExcerpt,
        proofCheckpoints,
        aiAssistanceDetails,
        reviewingEducatorName,
        reviewedAt,
        rubricRawScore,
        rubricMaxScore,
        rubricLevel,
      ];
}

class IdeationPassport extends Equatable {
  const IdeationPassport({
    this.missionAttempts = 0,
    this.completedMissions = 0,
    this.reflectionsSubmitted = 0,
    this.voiceInteractions = 0,
    this.collaborationSignals = 0,
    this.lastReflectionAt,
    this.generatedAt,
    this.summary,
    this.claims = const [],
  });

  final int missionAttempts;
  final int completedMissions;
  final int reflectionsSubmitted;
  final int voiceInteractions;
  final int collaborationSignals;
  final DateTime? lastReflectionAt;
  final DateTime? generatedAt;
  final String? summary;
  final List<PassportClaim> claims;

  @override
  List<Object?> get props => <Object?>[
        missionAttempts,
        completedMissions,
        reflectionsSubmitted,
        voiceInteractions,
        collaborationSignals,
        lastReflectionAt,
        generatedAt,
        summary,
        claims,
      ];
}

class PassportClaim extends Equatable {
  const PassportClaim({
    required this.capabilityId,
    required this.title,
    required this.pillar,
    required this.latestLevel,
    required this.evidenceCount,
    required this.verifiedArtifactCount,
    this.evidenceRecordIds = const [],
    this.portfolioItemIds = const [],
    this.missionAttemptIds = const [],
    this.proofOfLearningStatus,
    this.aiDisclosureStatus,
    this.latestEvidenceAt,
    this.verificationStatus,
    this.proofHasExplainItBack = false,
    this.proofHasOralCheck = false,
    this.proofHasMiniRebuild = false,
    this.proofCheckpointCount = 0,
    this.proofExplainItBackExcerpt,
    this.proofOralCheckExcerpt,
    this.proofMiniRebuildExcerpt,
    this.proofCheckpoints = const [],
    this.aiHasLearnerDisclosure = false,
    this.aiLearnerDeclaredUsed = false,
    this.aiHelpEventCount = 0,
    this.aiHasExplainItBackEvidence = false,
    this.aiHasEducatorAiFeedback = false,
    this.aiAssistanceDetails,
    this.reviewingEducatorName,
    this.reviewedAt,
    this.rubricRawScore,
    this.rubricMaxScore,
  });

  final String capabilityId;
  final String title;
  final String pillar;
  final int latestLevel;
  final int evidenceCount;
  final int verifiedArtifactCount;
  final List<String> evidenceRecordIds;
  final List<String> portfolioItemIds;
  final List<String> missionAttemptIds;
  final String? proofOfLearningStatus;
  final String? aiDisclosureStatus;
  final DateTime? latestEvidenceAt;
  final String? verificationStatus;
  final bool proofHasExplainItBack;
  final bool proofHasOralCheck;
  final bool proofHasMiniRebuild;
  final int proofCheckpointCount;
  final String? proofExplainItBackExcerpt;
  final String? proofOralCheckExcerpt;
  final String? proofMiniRebuildExcerpt;
  final List<ProofCheckpointPreview> proofCheckpoints;
  final bool aiHasLearnerDisclosure;
  final bool aiLearnerDeclaredUsed;
  final int aiHelpEventCount;
  final bool aiHasExplainItBackEvidence;
  final bool aiHasEducatorAiFeedback;
  final String? aiAssistanceDetails;
  final String? reviewingEducatorName;
  final DateTime? reviewedAt;
  final int? rubricRawScore;
  final int? rubricMaxScore;

  @override
  List<Object?> get props => <Object?>[
        capabilityId,
        title,
        pillar,
        latestLevel,
        evidenceCount,
        verifiedArtifactCount,
        evidenceRecordIds,
        portfolioItemIds,
        missionAttemptIds,
        proofOfLearningStatus,
        aiDisclosureStatus,
        latestEvidenceAt,
        verificationStatus,
        proofHasExplainItBack,
        proofHasOralCheck,
        proofHasMiniRebuild,
        proofCheckpointCount,
        proofExplainItBackExcerpt,
        proofOralCheckExcerpt,
        proofMiniRebuildExcerpt,
        proofCheckpoints,
        aiHasLearnerDisclosure,
        aiLearnerDeclaredUsed,
        aiHelpEventCount,
        aiHasExplainItBackEvidence,
        aiHasEducatorAiFeedback,
        aiAssistanceDetails,
        reviewingEducatorName,
        reviewedAt,
        rubricRawScore,
        rubricMaxScore,
      ];
}

/// Recent activity item
class RecentActivity extends Equatable {
  const RecentActivity({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.emoji,
    required this.timestamp,
  });
  final String id;
  final String title;
  final String description;
  final String type; // mission, habit, achievement, attendance
  final String emoji;
  final DateTime timestamp;

  @override
  List<Object?> get props =>
      <Object?>[id, title, description, type, emoji, timestamp];
}

/// Upcoming event for calendar
class UpcomingEvent extends Equatable {
  const UpcomingEvent({
    required this.id,
    required this.title,
    this.description,
    required this.dateTime,
    required this.type,
    this.location,
  });
  final String id;
  final String title;
  final String? description;
  final DateTime dateTime;
  final String type; // class, mission_due, event, conference
  final String? location;

  @override
  List<Object?> get props =>
      <Object?>[id, title, description, dateTime, type, location];
}

/// Billing summary for parents
class BillingSummary extends Equatable {
  const BillingSummary({
    required this.currentBalance,
    required this.nextPaymentAmount,
    this.nextPaymentDate,
    required this.subscriptionPlan,
    this.recentPayments = const [],
  });
  final double currentBalance;
  final double nextPaymentAmount;
  final DateTime? nextPaymentDate;
  final String subscriptionPlan;
  final List<PaymentHistory> recentPayments;

  @override
  List<Object?> get props => <Object?>[
        currentBalance,
        nextPaymentAmount,
        nextPaymentDate,
        subscriptionPlan,
        recentPayments,
      ];
}

/// Payment history item
class PaymentHistory extends Equatable {
  const PaymentHistory({
    required this.id,
    required this.amount,
    required this.date,
    required this.status,
    required this.description,
  });
  final String id;
  final double amount;
  final DateTime date;
  final String status; // paid, pending, failed
  final String description;

  @override
  List<Object?> get props => <Object?>[id, amount, date, status, description];
}
