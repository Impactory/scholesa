import { httpsCallable } from 'firebase/functions';
import { functions } from '@/src/firebase/client-init';
import type { UserRole } from '@/src/types/user';
import { normalizeUserRole } from '@/src/lib/auth/roleAliases';

export interface RoleDashboardStat {
  label: string;
  value: string;
  icon?: string;
  color?: string;
  trend?: string;
  positive?: boolean;
}

export interface RoleDashboardSnapshot {
  role: UserRole;
  siteId: string | null;
  period: string;
  stats: RoleDashboardStat[];
}

export interface RosterEntry {
  id: string;
  uid: string;
  displayName: string;
  email?: string | null;
  role?: UserRole | null;
  siteIds?: string[];
  activeSiteId?: string | null;
}

export interface RoleLinkedRoster {
  role: UserRole;
  siteId: string | null;
  learners: RosterEntry[];
  parents: RosterEntry[];
  educators: RosterEntry[];
  counts: {
    learners: number;
    parents: number;
    educators: number;
  };
}

export interface ParentDashboardBundle {
  parentId: string;
  siteId: string | null;
  locale: string;
  range: string;
  linkedLearnerCount: number;
  learners: Array<{
    learnerId: string;
    learnerName: string;
    currentLevel: number | null;
    totalXp: number | null;
    missionsCompleted: number | null;
    currentStreak: number | null;
    attendanceRate: number | null;
    pillarProgress?: Record<string, number>;
    capabilitySnapshot?: {
      futureSkills: number | null;
      leadership: number | null;
      impact: number | null;
      overall: number | null;
      band: string | null;
    };
    portfolioSnapshot?: {
      artifactCount: number | null;
      publishedArtifactCount: number | null;
      badgeCount: number | null;
      projectCount: number | null;
      latestArtifactAt?: string | null;
    };
    ideationPassport?: {
      missionAttempts: number | null;
      completedMissions: number | null;
      reflectionsSubmitted: number | null;
      voiceInteractions: number | null;
      collaborationSignals: number | null;
      lastReflectionAt?: string | null;
    };
    recentActivities: Array<Record<string, unknown>>;
    upcomingEvents: Array<Record<string, unknown>>;
  }>;
}

function normalizeFiniteNumber(raw: unknown): number | null {
  return typeof raw === 'number' && Number.isFinite(raw) ? raw : null;
}

function normalizeStat(raw: unknown): RoleDashboardStat | null {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null;
  const input = raw as Record<string, unknown>;
  if (typeof input.label !== 'string' || typeof input.value !== 'string') {
    return null;
  }
  return {
    label: input.label,
    value: input.value,
    icon: typeof input.icon === 'string' ? input.icon : undefined,
    color: typeof input.color === 'string' ? input.color : undefined,
    trend: typeof input.trend === 'string' ? input.trend : undefined,
    positive: typeof input.positive === 'boolean' ? input.positive : undefined
  };
}

function normalizeRosterEntry(raw: unknown): RosterEntry | null {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null;
  const input = raw as Record<string, unknown>;
  const id = typeof input.id === 'string' ? input.id : typeof input.uid === 'string' ? input.uid : '';
  if (!id) return null;
  return {
    id,
    uid: typeof input.uid === 'string' ? input.uid : id,
    displayName: typeof input.displayName === 'string' ? input.displayName : id,
    email: typeof input.email === 'string' ? input.email : null,
    role: normalizeUserRole(input.role),
    siteIds: Array.isArray(input.siteIds) ? input.siteIds.filter((item): item is string => typeof item === 'string') : [],
    activeSiteId: typeof input.activeSiteId === 'string' ? input.activeSiteId : null
  };
}

function normalizeNumberMap(raw: unknown): Record<string, number> | undefined {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return undefined;
  return Object.entries(raw as Record<string, unknown>).reduce<Record<string, number>>((acc, [key, value]) => {
    if (typeof value === 'number') {
      acc[key] = value;
    }
    return acc;
  }, {});
}

export async function fetchRoleDashboardSnapshot(params: {
  role: UserRole;
  siteId?: string | null;
  period?: string;
}): Promise<RoleDashboardSnapshot> {
  const callable = httpsCallable(functions, 'getRoleDashboardSnapshot');
  const response = await callable({
    role: params.role,
    siteId: params.siteId || undefined,
    period: params.period || 'week'
  });
  const payload = (response.data || {}) as Record<string, unknown>;
  const role = normalizeUserRole(payload.role) || params.role;
  const stats = Array.isArray(payload.stats)
    ? payload.stats.map(normalizeStat).filter((item): item is RoleDashboardStat => item !== null)
    : [];

  return {
    role,
    siteId: typeof payload.siteId === 'string' ? payload.siteId : null,
    period: typeof payload.period === 'string' ? payload.period : 'week',
    stats
  };
}

export async function fetchRoleLinkedRoster(params: {
  role: UserRole;
  siteId?: string | null;
  parentId?: string;
  educatorId?: string;
}): Promise<RoleLinkedRoster> {
  const callable = httpsCallable(functions, 'getRoleLinkedRoster');
  const response = await callable({
    role: params.role,
    siteId: params.siteId || undefined,
    parentId: params.parentId,
    educatorId: params.educatorId
  });
  const payload = (response.data || {}) as Record<string, unknown>;

  const learners = Array.isArray(payload.learners)
    ? payload.learners.map(normalizeRosterEntry).filter((item): item is RosterEntry => item !== null)
    : [];
  const parents = Array.isArray(payload.parents)
    ? payload.parents.map(normalizeRosterEntry).filter((item): item is RosterEntry => item !== null)
    : [];
  const educators = Array.isArray(payload.educators)
    ? payload.educators.map(normalizeRosterEntry).filter((item): item is RosterEntry => item !== null)
    : [];
  const countsRaw = payload.counts as Record<string, unknown> | undefined;

  return {
    role: normalizeUserRole(payload.role) || params.role,
    siteId: typeof payload.siteId === 'string' ? payload.siteId : null,
    learners,
    parents,
    educators,
    counts: {
      learners: typeof countsRaw?.learners === 'number' ? countsRaw.learners : learners.length,
      parents: typeof countsRaw?.parents === 'number' ? countsRaw.parents : parents.length,
      educators: typeof countsRaw?.educators === 'number' ? countsRaw.educators : educators.length
    }
  };
}

export async function fetchParentDashboardBundle(params: {
  siteId?: string | null;
  locale?: string;
  range?: string;
}): Promise<ParentDashboardBundle> {
  const callable = httpsCallable(functions, 'getParentDashboardBundle');
  const response = await callable({
    siteId: params.siteId || undefined,
    locale: params.locale,
    range: params.range || 'week'
  });
  const payload = (response.data || {}) as Record<string, unknown>;
  const learners: ParentDashboardBundle['learners'] = [];
  if (Array.isArray(payload.learners)) {
    for (const item of payload.learners) {
      if (!item || typeof item !== 'object' || Array.isArray(item)) continue;
      const row = item as Record<string, unknown>;
      if (typeof row.learnerId !== 'string' || typeof row.learnerName !== 'string') continue;
      learners.push({
        learnerId: row.learnerId,
        learnerName: row.learnerName,
        currentLevel: normalizeFiniteNumber(row.currentLevel),
        totalXp: normalizeFiniteNumber(row.totalXp),
        missionsCompleted: normalizeFiniteNumber(row.missionsCompleted),
        currentStreak: normalizeFiniteNumber(row.currentStreak),
        attendanceRate: normalizeFiniteNumber(row.attendanceRate),
        pillarProgress: normalizeNumberMap(row.pillarProgress),
        capabilitySnapshot: row.capabilitySnapshot && typeof row.capabilitySnapshot === 'object' && !Array.isArray(row.capabilitySnapshot)
          ? {
              futureSkills: normalizeFiniteNumber((row.capabilitySnapshot as Record<string, unknown>).futureSkills),
              leadership: normalizeFiniteNumber((row.capabilitySnapshot as Record<string, unknown>).leadership),
              impact: normalizeFiniteNumber((row.capabilitySnapshot as Record<string, unknown>).impact),
              overall: normalizeFiniteNumber((row.capabilitySnapshot as Record<string, unknown>).overall),
              band: typeof (row.capabilitySnapshot as Record<string, unknown>).band === 'string' ? (row.capabilitySnapshot as Record<string, unknown>).band as string : null
            }
          : undefined,
        portfolioSnapshot: row.portfolioSnapshot && typeof row.portfolioSnapshot === 'object' && !Array.isArray(row.portfolioSnapshot)
          ? {
              artifactCount: normalizeFiniteNumber((row.portfolioSnapshot as Record<string, unknown>).artifactCount),
              publishedArtifactCount: normalizeFiniteNumber((row.portfolioSnapshot as Record<string, unknown>).publishedArtifactCount),
              badgeCount: normalizeFiniteNumber((row.portfolioSnapshot as Record<string, unknown>).badgeCount),
              projectCount: normalizeFiniteNumber((row.portfolioSnapshot as Record<string, unknown>).projectCount),
              latestArtifactAt: typeof (row.portfolioSnapshot as Record<string, unknown>).latestArtifactAt === 'string' ? (row.portfolioSnapshot as Record<string, unknown>).latestArtifactAt as string : null
            }
          : undefined,
        ideationPassport: row.ideationPassport && typeof row.ideationPassport === 'object' && !Array.isArray(row.ideationPassport)
          ? {
              missionAttempts: normalizeFiniteNumber((row.ideationPassport as Record<string, unknown>).missionAttempts),
              completedMissions: normalizeFiniteNumber((row.ideationPassport as Record<string, unknown>).completedMissions),
              reflectionsSubmitted: normalizeFiniteNumber((row.ideationPassport as Record<string, unknown>).reflectionsSubmitted),
              voiceInteractions: normalizeFiniteNumber((row.ideationPassport as Record<string, unknown>).voiceInteractions),
              collaborationSignals: normalizeFiniteNumber((row.ideationPassport as Record<string, unknown>).collaborationSignals),
              lastReflectionAt: typeof (row.ideationPassport as Record<string, unknown>).lastReflectionAt === 'string' ? (row.ideationPassport as Record<string, unknown>).lastReflectionAt as string : null
            }
          : undefined,
        recentActivities: Array.isArray(row.recentActivities) ? row.recentActivities.filter((entry): entry is Record<string, unknown> => !!entry && typeof entry === 'object' && !Array.isArray(entry)) : [],
        upcomingEvents: Array.isArray(row.upcomingEvents) ? row.upcomingEvents.filter((entry): entry is Record<string, unknown> => !!entry && typeof entry === 'object' && !Array.isArray(entry)) : []
      });
    }
  }

  return {
    parentId: typeof payload.parentId === 'string' ? payload.parentId : '',
    siteId: typeof payload.siteId === 'string' ? payload.siteId : null,
    locale: typeof payload.locale === 'string' ? payload.locale : 'en',
    range: typeof payload.range === 'string' ? payload.range : 'week',
    linkedLearnerCount:
      typeof payload.linkedLearnerCount === 'number' ? payload.linkedLearnerCount : 0,
    learners
  };
}
