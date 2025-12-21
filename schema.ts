export type Role = 'learner' | 'educator' | 'parent' | 'site' | 'partner' | 'hq';

export interface User {
  uid: string;
  email: string;
  displayName?: string;
  photoURL?: string;
  role: Role;
  siteIds: string[]; // Users can belong to multiple sites
  parentIds?: string[]; // For learners, links to their parents
  organizationId?: string; // For partners/HQ
  createdAt: number; // Timestamp (ms)
  updatedAt: number;
}

export interface Site {
  id: string;
  name: string;
  location?: string;
  siteLeadIds: string[];
  createdAt: number;
}

// --- Learning & Sessions ---

export interface Session {
  id: string;
  title: string;
  description?: string;
  siteId: string;
  educatorIds: string[];
  pillarCodes: string[]; // e.g., 'tech', 'arts'
  startDate: number;
  endDate: number;
  recurrence?: string; // e.g., 'weekly'
}

export interface SessionOccurrence {
  id: string;
  sessionId: string;
  siteId: string;
  startTime: number;
  endTime: number;
  educatorId?: string; // The specific educator for this occurrence
  status: 'scheduled' | 'completed' | 'cancelled';
}

export interface Enrollment {
  id: string;
  sessionId: string;
  learnerId: string;
  siteId: string;
  enrolledAt: number;
  status: 'active' | 'dropped' | 'completed';
}

export interface AttendanceRecord {
  id: string;
  sessionOccurrenceId: string;
  learnerId: string;
  siteId: string;
  status: 'present' | 'absent' | 'late' | 'excused';
  timestamp: number;
  notes?: string;
}

// --- Pillars & Skills ---

export interface Pillar {
  code: string; // ID
  name: string;
  description?: string;
  color?: string;
}

export interface Skill {
  id: string;
  pillarCode: string;
  name: string;
  description?: string;
  level: number;
}

export interface SkillMastery {
  id: string;
  learnerId: string;
  skillId: string;
  levelAchieved: number;
  achievedAt: number;
  evidenceIds?: string[]; // Links to portfolio items
}

// --- Missions ---

export interface Mission {
  id: string;
  title: string;
  description: string;
  pillarCodes: string[];
  difficulty: 'beginner' | 'intermediate' | 'advanced';
  estimatedDurationMinutes?: number;
}

export interface MissionPlan {
  id: string;
  learnerId: string;
  missionId: string;
  status: 'planned' | 'in-progress' | 'completed';
  dueDate?: number;
}

export interface MissionAttempt {
  id: string;
  missionId: string;
  learnerId: string;
  sessionOccurrenceId?: string;
  siteId: string;
  startedAt: number;
  completedAt?: number;
  status: 'started' | 'submitted' | 'approved' | 'rejected';
  submissionUrl?: string;
  feedback?: string;
}

// --- Portfolio ---

export interface Portfolio {
  id: string;
  learnerId: string;
  title: string;
  description?: string;
  createdAt: number;
  updatedAt: number;
}

export interface PortfolioItem {
  id: string;
  portfolioId: string;
  title: string;
  description?: string;
  mediaUrl?: string;
  mediaType: 'image' | 'video' | 'document' | 'link';
  relatedSkillIds?: string[];
  createdAt: number;
}

export interface Credential {
  id: string;
  learnerId: string;
  title: string;
  issuer: string;
  issuedAt: number;
  expiresAt?: number;
  metadata?: Record<string, any>;
}

// --- Accountability ---

export interface AccountabilityCycle {
  id: string;
  siteId: string;
  name: string; // e.g., "Q1 2024"
  startDate: number;
  endDate: number;
  status: 'active' | 'closed';
}

export interface AccountabilityKPI {
  id: string;
  cycleId: string;
  siteId: string;
  metricName: string;
  targetValue: number;
  actualValue?: number;
  unit: string;
}

export interface AccountabilityCommitment {
  id: string;
  cycleId: string;
  userId: string; // Educator or Site Lead
  description: string;
  status: 'pending' | 'fulfilled' | 'missed';
}

export interface AccountabilityReview {
  id: string;
  cycleId: string;
  reviewerId: string;
  revieweeId: string; // Could be a site or a person
  rating: number;
  comments: string;
  createdAt: number;
}

export interface AuditLog {
  id: string;
  userId: string;
  action: string;
  collection?: string;
  documentId?: string;
  timestamp: number;
  details?: Record<string, any>;
}