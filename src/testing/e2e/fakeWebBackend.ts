'use client';

import type { User as FirebaseUser } from 'firebase/auth';
import { Timestamp } from 'firebase/firestore';
import { buildLocaleHeaders } from '@/src/lib/i18n/localeHeaders';
import { normalizeLocale, type SupportedLocale } from '@/src/lib/i18n/config';
import type { UserProfile, UserRole } from '@/src/types/user';
import type { AICoachRequest, AICoachResponse } from '@/src/lib/motivation/sdtMotivation';
import type { MiloOSLearnerLoopInsights } from '@/src/lib/miloos/learnerLoopInsights';
import type {
  WorkflowContext,
  WorkflowCreateInput,
  WorkflowLoadResult,
  WorkflowMutationTarget,
  WorkflowRecord,
} from '@/src/features/workflows/workflowData';
import type { E2ESessionPayload } from './fakeSession';

const STORE_KEY = 'scholesa:e2e:store';
const CURRENT_USER_KEY = 'scholesa:e2e:current-user';
const AUTH_EVENT = 'scholesa:e2e-auth-changed';
const DEFAULT_TIMESTAMP = '2026-03-07T18:00:00.000Z';

type SeedUser = {
  uid: string;
  email: string;
  displayName: string;
  role: UserRole;
  siteIds?: string[];
  activeSiteId?: string;
  learnerIds?: string[];
  parentIds?: string[];
};

type SiteRecord = {
  id: string;
  name: string;
  location: string;
  status: string;
  updatedAt: string;
};

type MissionRecord = {
  id: string;
  title: string;
  description: string;
  status: string;
  updatedAt: string;
};

type SessionRecord = {
  id: string;
  siteId: string;
  title: string;
  educatorIds: string[];
  status: string;
  updatedAt: string;
};

type EnrollmentRecord = {
  id: string;
  learnerId: string;
  sessionId: string;
  siteId: string;
  status: string;
};

type EducatorLearnerLinkRecord = {
  id: string;
  educatorId: string;
  learnerId: string;
  siteId: string;
};

type GuardianLinkRecord = {
  id: string;
  parentId: string;
  parentName: string;
  learnerId: string;
  learnerName: string;
  siteId: string;
  relationship: string;
  status: string;
  isPrimary: boolean;
  updatedAt: string;
};

type LearnerProgressRecord = {
  learnerId: string;
  level: number;
  totalXp: number;
  updatedAt: string;
};

type AttendanceRecord = {
  id: string;
  learnerId: string;
  learnerName: string;
  siteId: string;
  sessionOccurrenceId: string;
  status: string;
  recordedBy?: string;
  notes?: string;
  updatedAt: string;
};

type PortfolioRecord = {
  id: string;
  learnerId: string;
  siteId: string;
  title: string;
  description: string;
  mediaType: string;
  status: string;
  updatedAt: string;
};

type MissionAttemptRecord = {
  id: string;
  learnerId: string;
  missionId: string;
  notes: string;
  status: string;
  updatedAt: string;
};

type MarketplaceListingRecord = {
  id: string;
  partnerId: string;
  title: string;
  description: string;
  category: string;
  status: string;
  updatedAt: string;
};

type InteractionEventRecord = {
  id: string;
  siteId: string | null;
  actorId: string;
  learnerId?: string;
  eventType: string;
  createdAt: string;
  timestamp: string;
  interactionId?: string;
  mode?: string;
  studentInput?: string;
  explainBack?: string;
};

type SeedInteractionEventInput = {
  id?: string;
  siteId: string | null;
  actorId: string;
  learnerId?: string;
  eventType: string;
  createdAt?: string;
  timestamp?: string;
  interactionId?: string;
  mode?: string;
  studentInput?: string;
  explainBack?: string;
};

type SyntheticMiloOSGoldStateRecord = {
  id: string;
  siteId: string;
  sourcePack: string;
  noMasteryWrites: boolean;
  states: Record<string, string>;
  modeSupport?: string[];
  usage?: string;
};

type SeedSyntheticMiloOSGoldStateInput = SyntheticMiloOSGoldStateRecord;

type StoreState = {
  users: SeedUser[];
  sites: SiteRecord[];
  missions: MissionRecord[];
  sessions: SessionRecord[];
  enrollments: EnrollmentRecord[];
  educatorLearnerLinks: EducatorLearnerLinkRecord[];
  guardianLinks: GuardianLinkRecord[];
  learnerProgress: LearnerProgressRecord[];
  attendanceRecords: AttendanceRecord[];
  portfolioItems: PortfolioRecord[];
  missionAttempts: MissionAttemptRecord[];
  marketplaceListings: MarketplaceListingRecord[];
  interactionEvents: InteractionEventRecord[];
  syntheticMiloOSGoldStates: SyntheticMiloOSGoldStateRecord[];
};

const USERS: SeedUser[] = [
  {
    uid: 'learner-alpha',
    email: 'learner.alpha@scholesa.test',
    displayName: 'Learner Alpha',
    role: 'learner',
    siteIds: ['site-alpha'],
    activeSiteId: 'site-alpha',
    parentIds: ['parent-alpha'],
  },
  {
    uid: 'educator-alpha',
    email: 'educator.alpha@scholesa.test',
    displayName: 'Educator Alpha',
    role: 'educator',
    siteIds: ['site-alpha'],
    activeSiteId: 'site-alpha',
  },
  {
    uid: 'parent-alpha',
    email: 'parent.alpha@scholesa.test',
    displayName: 'Parent Alpha',
    role: 'parent',
    siteIds: ['site-alpha'],
    activeSiteId: 'site-alpha',
    learnerIds: ['learner-alpha'],
  },
  {
    uid: 'site-alpha-admin',
    email: 'site.alpha@scholesa.test',
    displayName: 'Site Alpha Admin',
    role: 'site',
    siteIds: ['site-alpha'],
    activeSiteId: 'site-alpha',
  },
  {
    uid: 'partner-alpha',
    email: 'partner.alpha@scholesa.test',
    displayName: 'Partner Alpha',
    role: 'partner',
    siteIds: ['site-alpha'],
    activeSiteId: 'site-alpha',
  },
  {
    uid: 'hq-alpha',
    email: 'hq.alpha@scholesa.test',
    displayName: 'HQ Alpha',
    role: 'hq',
    siteIds: ['site-alpha', 'site-beta'],
    activeSiteId: 'site-alpha',
  },
  {
    uid: 'learner-beta',
    email: 'learner.beta@scholesa.test',
    displayName: 'Learner Beta',
    role: 'learner',
    siteIds: ['site-alpha'],
    activeSiteId: 'site-alpha',
  },
  {
    uid: 'parent-beta',
    email: 'parent.beta@scholesa.test',
    displayName: 'Parent Beta',
    role: 'parent',
    siteIds: ['site-alpha'],
    activeSiteId: 'site-alpha',
  },
];

function nowIso(): string {
  return new Date().toISOString();
}

function cloneState<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T;
}

function defaultState(): StoreState {
  return {
    users: cloneState(USERS),
    sites: [
      { id: 'site-alpha', name: 'Site Alpha Campus', location: 'Vancouver', status: 'active', updatedAt: DEFAULT_TIMESTAMP },
      { id: 'site-beta', name: 'Site Beta Campus', location: 'Burnaby', status: 'active', updatedAt: DEFAULT_TIMESTAMP },
    ],
    missions: [
      {
        id: 'mission-robotics',
        title: 'Robotics Mission',
        description: 'Build and document a robotics prototype.',
        status: 'active',
        updatedAt: DEFAULT_TIMESTAMP,
      },
    ],
    sessions: [
      {
        id: 'session-future-skills',
        siteId: 'site-alpha',
        title: 'Skills Studio',
        educatorIds: ['educator-alpha'],
        status: 'scheduled',
        updatedAt: DEFAULT_TIMESTAMP,
      },
    ],
    enrollments: [
      { id: 'enrollment-alpha', learnerId: 'learner-alpha', sessionId: 'session-future-skills', siteId: 'site-alpha', status: 'active' },
    ],
    educatorLearnerLinks: [
      { id: 'educator-link-alpha', educatorId: 'educator-alpha', learnerId: 'learner-alpha', siteId: 'site-alpha' },
    ],
    guardianLinks: [
      {
        id: 'guardian-link-alpha',
        parentId: 'parent-alpha',
        parentName: 'Parent Alpha',
        learnerId: 'learner-alpha',
        learnerName: 'Learner Alpha',
        siteId: 'site-alpha',
        relationship: 'guardian',
        status: 'active',
        isPrimary: true,
        updatedAt: DEFAULT_TIMESTAMP,
      },
    ],
    learnerProgress: [
      { learnerId: 'learner-alpha', level: 7, totalXp: 420, updatedAt: DEFAULT_TIMESTAMP },
    ],
    attendanceRecords: [
      {
        id: 'attendance-parent-summary',
        learnerId: 'learner-alpha',
        learnerName: 'Learner Alpha',
        siteId: 'site-alpha',
        sessionOccurrenceId: 'session-future-skills',
        status: 'present',
        updatedAt: DEFAULT_TIMESTAMP,
      },
    ],
    portfolioItems: [
      {
        id: 'portfolio-linked-alpha',
        learnerId: 'learner-alpha',
        siteId: 'site-alpha',
        title: 'Learner Build Log',
        description: 'Documented the prototype iteration.',
        mediaType: 'document',
        status: 'published',
        updatedAt: DEFAULT_TIMESTAMP,
      },
      {
        id: 'portfolio-unlinked-beta',
        learnerId: 'learner-beta',
        siteId: 'site-alpha',
        title: 'Other Learner Artifact',
        description: 'Should remain hidden from unrelated parents.',
        mediaType: 'image',
        status: 'published',
        updatedAt: DEFAULT_TIMESTAMP,
      },
    ],
    missionAttempts: [],
    marketplaceListings: [],
    interactionEvents: [],
    syntheticMiloOSGoldStates: [],
  };
}

function hasWindow(): boolean {
  return typeof window !== 'undefined' && typeof window.localStorage !== 'undefined';
}

function readStore(): StoreState {
  if (!hasWindow()) {
    return defaultState();
  }

  const raw = window.localStorage.getItem(STORE_KEY);
  if (!raw) {
    const next = defaultState();
    writeStore(next);
    return next;
  }

  try {
    return JSON.parse(raw) as StoreState;
  } catch {
    const next = defaultState();
    writeStore(next);
    return next;
  }
}

function writeStore(state: StoreState): void {
  if (!hasWindow()) return;
  window.localStorage.setItem(STORE_KEY, JSON.stringify(state));
}

function currentUserId(): string | null {
  if (!hasWindow()) return null;
  return window.localStorage.getItem(CURRENT_USER_KEY);
}

function setCurrentUserId(uid: string | null): void {
  if (!hasWindow()) return;
  if (uid) {
    window.localStorage.setItem(CURRENT_USER_KEY, uid);
  } else {
    window.localStorage.removeItem(CURRENT_USER_KEY);
  }
}

function emitAuthChange(): void {
  if (!hasWindow()) return;
  window.dispatchEvent(new CustomEvent(AUTH_EVENT));
}

function getUserById(uid: string | null, state = readStore()): SeedUser | null {
  if (!uid) return null;
  return state.users.find((user) => user.uid === uid) || null;
}

function buildProfile(user: SeedUser): UserProfile {
  const timestamp = Timestamp.fromDate(new Date(DEFAULT_TIMESTAMP));
  return {
    uid: user.uid,
    email: user.email,
    displayName: user.displayName,
    role: user.role,
    siteIds: user.siteIds || [],
    activeSiteId: user.activeSiteId,
    isActive: true,
    createdAt: timestamp,
    updatedAt: timestamp,
  };
}

function buildFirebaseUser(user: SeedUser): FirebaseUser {
  return {
    uid: user.uid,
    email: user.email,
    displayName: user.displayName,
    emailVerified: true,
    isAnonymous: false,
    metadata: {} as FirebaseUser['metadata'],
    phoneNumber: null,
    photoURL: null,
    providerData: [],
    providerId: 'custom',
    refreshToken: 'e2e-refresh-token',
    tenantId: null,
    delete: async () => undefined,
    getIdToken: async () => `e2e:${user.uid}`,
    getIdTokenResult: async () => ({
      token: `e2e:${user.uid}`,
      authTime: DEFAULT_TIMESTAMP,
      expirationTime: DEFAULT_TIMESTAMP,
      issuedAtTime: DEFAULT_TIMESTAMP,
      signInProvider: 'custom',
      signInSecondFactor: null,
      claims: { role: user.role },
    }),
    reload: async () => undefined,
    toJSON: () => ({ uid: user.uid, email: user.email, displayName: user.displayName }),
  } as FirebaseUser;
}

function resolveClientLocale(explicitLocale?: string): SupportedLocale {
  if (explicitLocale) {
    return normalizeLocale(explicitLocale);
  }

  if (typeof document !== 'undefined' && document.documentElement.lang) {
    return normalizeLocale(document.documentElement.lang);
  }

  return 'en';
}

async function postSession(path: string, locale?: string, body?: Record<string, unknown>): Promise<void> {
  const response = await fetch(path, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...buildLocaleHeaders(resolveClientLocale(locale)),
    },
    credentials: 'include',
    cache: 'no-store',
    body: JSON.stringify(body || {}),
  });

  if (!response.ok) {
    throw new Error(`Session endpoint failed (${response.status}) for ${path}`);
  }
}

function activeSiteIdFromContext(ctx: WorkflowContext): string | null {
  return ctx.profile?.activeSiteId || ctx.profile?.siteIds?.[0] || null;
}

function linkedLearnerIdsForParent(uid: string, state: StoreState): string[] {
  const linked = state.guardianLinks.filter((entry) => entry.parentId === uid).map((entry) => entry.learnerId);
  const direct = getUserById(uid, state)?.learnerIds || [];
  return Array.from(new Set([...linked, ...direct]));
}

function nextId(prefix: string): string {
  return `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

function toRecord(input: Omit<WorkflowRecord, 'metadata'> & { metadata?: Record<string, string> }): WorkflowRecord {
  return {
    metadata: {},
    ...input,
  };
}

function emptyResult(): WorkflowLoadResult {
  return {
    records: [],
    canCreate: false,
    canRefresh: true,
    createLabel: 'Create',
    createConfig: null,
  };
}

export function subscribeE2EAuthState(listener: (user: FirebaseUser | null, profile: UserProfile | null) => void): () => void {
  const emit = () => {
    const state = readStore();
    const user = getUserById(currentUserId(), state);
    listener(user ? buildFirebaseUser(user) : null, user ? buildProfile(user) : null);
  };

  emit();

  const handleStorage = (event: StorageEvent) => {
    if (event.key === STORE_KEY || event.key === CURRENT_USER_KEY) {
      emit();
    }
  };

  window.addEventListener(AUTH_EVENT, emit);
  window.addEventListener('storage', handleStorage);

  return () => {
    window.removeEventListener(AUTH_EVENT, emit);
    window.removeEventListener('storage', handleStorage);
  };
}

export async function resetE2EState(locale?: string): Promise<void> {
  writeStore(defaultState());
  setCurrentUserId(null);
  emitAuthChange();
  await postSession('/api/auth/session-logout', locale);
}

export async function signInE2EUser(uid: string, locale?: string): Promise<{ uid: string | null }> {
  const state = readStore();
  const user = getUserById(uid, state);

  if (!user) {
    throw new Error(`Unknown E2E user: ${uid}`);
  }

  setCurrentUserId(uid);
  emitAuthChange();

  const sessionPayload: E2ESessionPayload = {
    uid: user.uid,
    email: user.email,
    displayName: user.displayName,
    role: user.role,
    siteIds: user.siteIds || [],
    activeSiteId: user.activeSiteId || null,
  };
  await postSession('/api/auth/session-login', locale, { e2eSession: sessionPayload });
  return { uid: user.uid };
}

export async function signOutE2EUser(locale?: string): Promise<void> {
  setCurrentUserId(null);
  emitAuthChange();
  await postSession('/api/auth/session-logout', locale);
}

export function currentE2EUid(): string | null {
  return currentUserId();
}

export function getE2ECollection(collectionName: string): Array<Record<string, unknown>> {
  const state = readStore() as unknown as Record<string, Array<Record<string, unknown>>>;
  const collection = state[collectionName];
  return Array.isArray(collection) ? cloneState(collection) : [];
}

export function seedE2EInteractionEvents(events: SeedInteractionEventInput[]): void {
  const state = readStore();
  events.forEach((input, index) => {
    const createdAt = input.createdAt || input.timestamp || nowIso();
    state.interactionEvents.push({
      id: input.id || nextId(`seeded-miloos-event-${index}`),
      siteId: input.siteId,
      actorId: input.actorId,
      learnerId: input.learnerId,
      eventType: input.eventType,
      createdAt,
      timestamp: input.timestamp || createdAt,
      interactionId: input.interactionId,
      mode: input.mode,
      studentInput: input.studentInput,
      explainBack: input.explainBack,
    });
  });
  writeStore(state);
}

export function seedE2ESyntheticMiloOSGoldStates(
  records: SeedSyntheticMiloOSGoldStateInput[]
): void {
  const state = readStore();
  const nextById = new Map(
    state.syntheticMiloOSGoldStates.map((record) => [record.id, record])
  );
  records.forEach((record) => {
    nextById.set(record.id, cloneState(record));
  });
  state.syntheticMiloOSGoldStates = Array.from(nextById.values());
  writeStore(state);
}

function appendInteractionEvent(
  state: StoreState,
  input: Omit<InteractionEventRecord, 'createdAt' | 'timestamp'>
): InteractionEventRecord {
  const createdAt = nowIso();
  const event = {
    ...input,
    createdAt,
    timestamp: createdAt,
  };
  state.interactionEvents.push(event);
  return event;
}

function countEvents(events: InteractionEventRecord[], eventType: string): number {
  return events.filter((event) => event.eventType === eventType).length;
}

export async function requestE2EAICoach(
  learnerId: string,
  siteId: string,
  request: AICoachRequest
): Promise<AICoachResponse> {
  const state = readStore();
  const openedEvent = appendInteractionEvent(state, {
    id: nextId('miloos-opened'),
    siteId,
    actorId: learnerId,
    learnerId,
    eventType: 'ai_help_opened',
    mode: request.mode,
    studentInput: request.studentInput,
  });
  appendInteractionEvent(state, {
    id: nextId('miloos-used'),
    siteId,
    actorId: learnerId,
    learnerId,
    eventType: 'ai_help_used',
    interactionId: openedEvent.id,
    mode: request.mode,
    studentInput: request.studentInput,
  });
  appendInteractionEvent(state, {
    id: nextId('miloos-response'),
    siteId,
    actorId: learnerId,
    learnerId,
    eventType: 'ai_coach_response',
    interactionId: openedEvent.id,
    mode: request.mode,
    studentInput: request.studentInput,
  });
  writeStore(state);

  return {
    message:
      'Try one small comparison test, write what changed, and explain why that evidence helps your prototype decision.',
    mode: request.mode,
    requiresExplainBack: true,
    suggestedNextSteps: [
      'Change one variable in the prototype',
      'Record what changed before deciding the next move',
    ],
    learnerState: { cognition: 0.72, engagement: 0.68, integrity: 0.91 },
    risk: {
      reliability: { riskType: 'none', method: 'e2e_fake_backend', riskScore: 0, threshold: 1 },
      autonomy: { riskType: 'none', signals: ['hint_only'], riskScore: 0, threshold: 1 },
    },
    mvl: { gateActive: false, episodeId: null, reason: null },
    meta: {
      version: 'e2e-miloos-learner-loop',
      gradeBand: request.gradeBand || 'G7_9',
      conceptTags: request.conceptTags || [],
      aiHelpOpenedEventId: openedEvent.id,
    },
  };
}

export async function submitE2EExplainBack(
  learnerId: string,
  siteId: string,
  interactionId: string,
  explainBack: string
): Promise<{ approved: boolean; feedback?: string }> {
  const state = readStore();
  const openedEvent = state.interactionEvents.find(
    (event) => event.id === interactionId && event.actorId === learnerId && event.siteId === siteId
  );

  if (!openedEvent) {
    throw new Error('Unknown E2E MiloOS interaction.');
  }

  appendInteractionEvent(state, {
    id: nextId('miloos-explain-back'),
    siteId,
    actorId: learnerId,
    learnerId,
    eventType: 'explain_it_back_submitted',
    interactionId,
    mode: openedEvent.mode,
    explainBack,
  });
  writeStore(state);

  return {
    approved: true,
    feedback: 'Explain-back submitted. Your reflection is now attached to this MiloOS session.',
  };
}

export async function getE2EMiloOSLearnerLoopInsights(params: {
  learnerId: string;
  siteId: string;
  lookbackDays?: number;
}): Promise<MiloOSLearnerLoopInsights> {
  const state = readStore();
  const events = state.interactionEvents.filter(
    (event) => event.actorId === params.learnerId && event.siteId === params.siteId
  );
  const aiHelpOpened = countEvents(events, 'ai_help_opened');
  const aiHelpUsed = countEvents(events, 'ai_help_used');
  const explainBackSubmitted = countEvents(events, 'explain_it_back_submitted');
  const explainedInteractionIds = new Set(
    events
      .filter((event) => event.eventType === 'explain_it_back_submitted')
      .map((event) => event.interactionId)
      .filter((interactionId): interactionId is string => Boolean(interactionId))
  );
  const pendingSupportInteractions = events
    .filter((event) => event.eventType === 'ai_help_opened' && !explainedInteractionIds.has(event.id))
    .map((event) => ({
      interactionId: event.id,
      mode: event.mode,
      studentInput: event.studentInput,
      createdAt: event.createdAt,
    }))
    .slice(0, 5);

  return {
    siteId: params.siteId,
    learnerId: params.learnerId,
    lookbackDays: params.lookbackDays || 30,
    state: events.length > 0 ? { cognition: 0.72, engagement: 0.68, integrity: 0.91 } : null,
    trend: events.length > 0
      ? { cognitionDelta: 0.04, engagementDelta: 0.03, integrityDelta: 0.02, improvementScore: 0.03 }
      : null,
    stateAvailability: {
      validSamples: events.length > 0 ? 1 : 0,
      hasCurrentState: events.length > 0,
      hasTrendBaseline: events.length > 1,
    },
    eventCounts: events.reduce<Record<string, number>>((counts, event) => {
      counts[event.eventType] = (counts[event.eventType] || 0) + 1;
      return counts;
    }, {}),
    verification: {
      aiHelpOpened,
      aiHelpUsed,
      explainBackSubmitted,
      pendingExplainBack: Math.max(aiHelpOpened - explainBackSubmitted, 0),
      pendingSupportInteractions,
    },
    mvl: {
      active: 0,
      passed: 0,
      failed: 0,
    },
    activeGoals: [],
    generatedAt: nowIso(),
  };
}

export async function getE2EParentDashboardBundle(params: {
  parentId: string;
  siteId: string;
}): Promise<{ learners: Array<Record<string, unknown>> }> {
  const state = readStore();
  const linkedLearnerIds = linkedLearnerIdsForParent(params.parentId, state);
  const learners = state.users.filter(
    (user) =>
      user.role === 'learner' &&
      linkedLearnerIds.includes(user.uid) &&
      user.siteIds?.includes(params.siteId)
  );

  return {
    learners: learners.map((learner) => {
      const supportEvents = state.interactionEvents.filter(
        (event) =>
          event.siteId === params.siteId &&
          (event.actorId === learner.uid || event.learnerId === learner.uid)
      );
      const supportOpened = countEvents(supportEvents, 'ai_help_opened');
      const supportUsed = countEvents(supportEvents, 'ai_help_used');
      const explainBackSubmitted = countEvents(supportEvents, 'explain_it_back_submitted');
      const pendingExplainBack = Math.max(supportOpened - explainBackSubmitted, 0);
      const recentSupportAt = supportEvents
        .map((event) => event.createdAt || event.timestamp)
        .filter(Boolean)
        .sort()
        .at(-1) || null;
      const portfolioItemsPreview = state.portfolioItems
        .filter((item) => item.siteId === params.siteId && item.learnerId === learner.uid)
        .map((item) => ({
          id: item.id,
          title: item.title,
          capabilityTitles: ['Prototype iteration'],
          verificationStatus: item.status === 'published' ? 'verified' : 'pending',
          aiDisclosureStatus: 'learner-ai-not-used',
        }));

      return {
        learnerId: learner.uid,
        learnerName: learner.displayName,
        capabilitySnapshot: {
          overall: 0.52,
          band: 'developing',
          familyLabels: {
            futureSkills: 'Think',
            leadership: 'Lead',
            impact: 'Build for the World',
          },
        },
        pillarProgress: {
          futureSkills: 0.6,
          leadership: 0.45,
          impact: 0.5,
        },
        portfolioItemsPreview,
        portfolioSnapshot: {
          artifactCount: portfolioItemsPreview.length,
          verifiedCount: portfolioItemsPreview.length,
          badgeCount: 0,
        },
        evidenceSummary: {
          recordCount: 0,
          reviewedCount: 0,
          portfolioLinkedCount: portfolioItemsPreview.length,
        },
        miloosSupportSummary: {
          supportOpened,
          supportUsed,
          explainBackSubmitted,
          pendingExplainBack,
          recentSupportAt,
          status: pendingExplainBack > 0
            ? 'pending-explain-back'
            : supportOpened > 0
            ? 'support-verified'
            : 'no-support-yet',
          isMasteryEvidence: false,
        },
      };
    }),
  };
}

export async function loadE2EWorkflowRecords(ctx: WorkflowContext): Promise<WorkflowLoadResult> {
  const state = readStore();

  switch (ctx.routePath) {
  case '/learner/today': {
    const sessionIds = state.enrollments.filter((entry) => entry.learnerId === ctx.uid).map((entry) => entry.sessionId);
    return {
      ...emptyResult(),
      records: state.sessions
        .filter((entry) => sessionIds.includes(entry.id))
        .map((entry) => toRecord({
          id: entry.id,
          title: entry.title,
          subtitle: 'Active learner schedule',
          status: entry.status,
          updatedAt: entry.updatedAt,
          siteId: entry.siteId,
          collectionName: 'sessions',
          routePath: ctx.routePath,
          canEdit: false,
          canDelete: false,
        })),
    };
  }
  case '/learner/missions':
    return {
      ...emptyResult(),
      canCreate: true,
      createLabel: 'Start mission',
      createConfig: {
        title: 'Start mission attempt',
        submitLabel: 'Start mission',
        fields: [
          {
            name: 'missionId',
            label: 'Mission',
            type: 'select',
            required: true,
            options: state.missions.map((entry) => ({ value: entry.id, label: entry.title })),
          },
          {
            name: 'notes',
            label: 'Notes',
            type: 'textarea',
            required: true,
          },
        ],
      },
      records: state.missionAttempts
        .filter((entry) => entry.learnerId === ctx.uid)
        .map((entry) => {
          const mission = state.missions.find((missionEntry) => missionEntry.id === entry.missionId);
          return toRecord({
            id: entry.id,
            title: mission?.title || entry.missionId,
            subtitle: entry.notes || mission?.description || 'Mission attempt',
            status: entry.status,
            updatedAt: entry.updatedAt,
            siteId: activeSiteIdFromContext(ctx),
            collectionName: 'missionAttempts',
            routePath: ctx.routePath,
            canEdit: entry.status === 'started',
            canDelete: false,
            primaryActionLabel: entry.status === 'started' ? 'Submit attempt' : undefined,
          });
        }),
    };
  case '/educator/today':
    return {
      ...emptyResult(),
      records: state.sessions
        .filter((entry) => entry.educatorIds.includes(ctx.uid))
        .map((entry) => toRecord({
          id: entry.id,
          title: entry.title,
          subtitle: 'Educator queue',
          status: entry.status,
          updatedAt: entry.updatedAt,
          siteId: entry.siteId,
          collectionName: 'sessions',
          routePath: ctx.routePath,
          canEdit: false,
          canDelete: false,
        })),
    };
  case '/educator/attendance': {
    const learnerOptions = state.educatorLearnerLinks
      .filter((entry) => entry.educatorId === ctx.uid)
      .map((entry) => getUserById(entry.learnerId, state))
      .filter((entry): entry is SeedUser => Boolean(entry))
      .map((entry) => ({ value: entry.uid, label: entry.displayName }));
    const sessionOptions = state.sessions
      .filter((entry) => entry.educatorIds.includes(ctx.uid))
      .map((entry) => ({ value: entry.id, label: entry.title }));

    return {
      ...emptyResult(),
      canCreate: true,
      createLabel: 'Record attendance',
      createConfig: {
        title: 'Record attendance',
        submitLabel: 'Save attendance',
        fields: [
          {
            name: 'learnerId',
            label: 'Learner',
            type: 'select',
            required: true,
            options: learnerOptions,
          },
          {
            name: 'sessionOccurrenceId',
            label: 'Session',
            type: 'select',
            required: true,
            options: sessionOptions,
          },
          {
            name: 'status',
            label: 'Status',
            type: 'select',
            required: true,
            options: [
              { value: 'present', label: 'present' },
              { value: 'absent', label: 'absent' },
              { value: 'late', label: 'late' },
            ],
          },
          {
            name: 'notes',
            label: 'Notes',
            type: 'textarea',
          },
        ],
      },
      records: state.attendanceRecords
        .filter((entry) => entry.siteId === activeSiteIdFromContext(ctx))
        .map((entry) => toRecord({
          id: entry.id,
          title: entry.learnerName,
          subtitle: entry.notes || entry.sessionOccurrenceId,
          status: entry.status,
          updatedAt: entry.updatedAt,
          siteId: entry.siteId,
          collectionName: 'attendanceRecords',
          routePath: ctx.routePath,
          canEdit: false,
          canDelete: false,
        })),
    };
  }
  case '/parent/summary': {
    const learnerIds = linkedLearnerIdsForParent(ctx.uid, state);
    return {
      ...emptyResult(),
      records: learnerIds.map((learnerId) => {
        const learner = getUserById(learnerId, state);
        const progress = state.learnerProgress.find((entry) => entry.learnerId === learnerId);
        return toRecord({
          id: learnerId,
          title: learner?.displayName || learnerId,
          subtitle: progress ? `Level ${progress.level} • ${progress.totalXp} XP` : 'No progress yet',
          status: 'active',
          updatedAt: progress?.updatedAt || DEFAULT_TIMESTAMP,
          siteId: learner?.activeSiteId || null,
          collectionName: 'learnerProgress',
          routePath: ctx.routePath,
          canEdit: false,
          canDelete: false,
        });
      }),
    };
  }
  case '/parent/portfolio': {
    const learnerIds = new Set(linkedLearnerIdsForParent(ctx.uid, state));
    return {
      ...emptyResult(),
      records: state.portfolioItems
        .filter((entry) => learnerIds.has(entry.learnerId))
        .map((entry) => toRecord({
          id: entry.id,
          title: entry.title,
          subtitle: entry.description,
          status: entry.status,
          updatedAt: entry.updatedAt,
          siteId: entry.siteId,
          collectionName: 'portfolioItems',
          routePath: ctx.routePath,
          canEdit: false,
          canDelete: false,
        })),
    };
  }
  case '/site/dashboard': {
    const site = state.sites.find((entry) => entry.id === activeSiteIdFromContext(ctx));
    return {
      ...emptyResult(),
      records: site ? [toRecord({
        id: site.id,
        title: site.name,
        subtitle: site.location,
        status: site.status,
        updatedAt: site.updatedAt,
        siteId: site.id,
        collectionName: 'sites',
        routePath: ctx.routePath,
        canEdit: false,
        canDelete: false,
      })] : [],
    };
  }
  case '/site/provisioning': {
    const siteId = activeSiteIdFromContext(ctx) || '';
    return {
      ...emptyResult(),
      canCreate: true,
      createLabel: 'Add link',
      createConfig: {
        title: 'Provision guardian link',
        submitLabel: 'Save link',
        fields: [
          {
            name: 'action',
            label: 'Action',
            type: 'select',
            required: true,
            defaultValue: 'guardianLink',
            options: [{ value: 'guardianLink', label: 'guardianLink' }],
          },
          {
            name: 'parentId',
            label: 'Parent',
            type: 'select',
            required: true,
            options: state.users
              .filter((entry) => entry.role === 'parent' && (entry.siteIds || []).includes(siteId))
              .map((entry) => ({ value: entry.uid, label: entry.displayName })),
          },
          {
            name: 'learnerId',
            label: 'Learner',
            type: 'select',
            required: true,
            options: state.users
              .filter((entry) => entry.role === 'learner' && (entry.siteIds || []).includes(siteId))
              .map((entry) => ({ value: entry.uid, label: entry.displayName })),
          },
          {
            name: 'relationship',
            label: 'Relationship',
            type: 'select',
            required: true,
            options: [
              { value: 'guardian', label: 'guardian' },
              { value: 'caregiver', label: 'caregiver' },
            ],
          },
          {
            name: 'isPrimary',
            label: 'Primary link',
            type: 'checkbox',
            defaultValue: false,
          },
        ],
      },
      records: state.guardianLinks
        .filter((entry) => entry.siteId === siteId)
        .map((entry) => toRecord({
          id: entry.id,
          title: entry.parentId,
          subtitle: `${entry.parentName} -> ${entry.learnerName}`,
          status: entry.status,
          updatedAt: entry.updatedAt,
          siteId: entry.siteId,
          collectionName: 'guardianLinks',
          routePath: ctx.routePath,
          canEdit: false,
          canDelete: false,
        })),
    };
  }
  case '/site/clever':
    return {
      ...emptyResult(),
      canCreate: true,
      createLabel: 'Connect Clever',
      createConfig: {
        title: 'Connect Clever',
        submitLabel: 'Start Clever connect',
        fields: [],
      },
      records: [],
    };
  case '/partner/listings':
    return {
      ...emptyResult(),
      canCreate: true,
      createLabel: 'Create listing',
      createConfig: {
        title: 'Create partner listing',
        submitLabel: 'Save listing',
        fields: [
          { name: 'title', label: 'Title', type: 'text', required: true },
          { name: 'description', label: 'Description', type: 'textarea', required: true },
          { name: 'category', label: 'Category', type: 'text', required: true },
        ],
      },
      records: state.marketplaceListings
        .filter((entry) => entry.partnerId === ctx.uid)
        .map((entry) => toRecord({
          id: entry.id,
          title: entry.title,
          subtitle: entry.description,
          status: entry.status,
          updatedAt: entry.updatedAt,
          siteId: activeSiteIdFromContext(ctx),
          collectionName: 'marketplaceListings',
          routePath: ctx.routePath,
          canEdit: entry.status === 'draft',
          canDelete: false,
          primaryActionLabel: entry.status === 'draft' ? 'Publish listing' : undefined,
        })),
    };
  case '/hq/sites':
    return {
      ...emptyResult(),
      canCreate: true,
      createLabel: 'Create site',
      createConfig: {
        title: 'Create site',
        submitLabel: 'Save site',
        fields: [
          { name: 'name', label: 'Name', type: 'text', required: true },
          { name: 'location', label: 'Location', type: 'text', required: true },
        ],
      },
      records: state.sites.map((entry) => toRecord({
        id: entry.id,
        title: entry.name,
        subtitle: entry.location,
        status: entry.status,
        updatedAt: entry.updatedAt,
        siteId: entry.id,
        collectionName: 'sites',
        routePath: ctx.routePath,
        canEdit: entry.status === 'pending',
        canDelete: false,
        primaryActionLabel: entry.status === 'pending' ? 'Activate site' : undefined,
      })),
    };
  default:
    return emptyResult();
  }
}

export async function createE2EWorkflowRecord(ctx: WorkflowContext, input: WorkflowCreateInput): Promise<void> {
  const state = readStore();
  const values = input.values;

  switch (ctx.routePath) {
  case '/learner/missions': {
    const missionId = typeof values.missionId === 'string' ? values.missionId : '';
    state.missionAttempts.push({
      id: nextId('mission-attempt'),
      learnerId: ctx.uid,
      missionId,
      notes: typeof values.notes === 'string' ? values.notes : '',
      status: 'started',
      updatedAt: nowIso(),
    });
    break;
  }
  case '/educator/attendance': {
    const learnerId = typeof values.learnerId === 'string' ? values.learnerId : '';
    const learner = getUserById(learnerId, state);
    state.attendanceRecords.push({
      id: nextId('attendance'),
      learnerId,
      learnerName: learner?.displayName || learnerId,
      siteId: activeSiteIdFromContext(ctx) || 'site-alpha',
      sessionOccurrenceId: typeof values.sessionOccurrenceId === 'string' ? values.sessionOccurrenceId : '',
      status: typeof values.status === 'string' ? values.status : 'present',
      recordedBy: ctx.uid,
      notes: typeof values.notes === 'string' ? values.notes : '',
      updatedAt: nowIso(),
    });
    break;
  }
  case '/site/provisioning': {
    const parentId = typeof values.parentId === 'string' ? values.parentId : '';
    const learnerId = typeof values.learnerId === 'string' ? values.learnerId : '';
    const parent = getUserById(parentId, state);
    const learner = getUserById(learnerId, state);
    state.guardianLinks.push({
      id: nextId('guardian-link'),
      parentId,
      parentName: parent?.displayName || parentId,
      learnerId,
      learnerName: learner?.displayName || learnerId,
      siteId: activeSiteIdFromContext(ctx) || 'site-alpha',
      relationship: typeof values.relationship === 'string' ? values.relationship : 'guardian',
      status: 'active',
      isPrimary: values.isPrimary === true,
      updatedAt: nowIso(),
    });
    break;
  }
  case '/site/clever':
    break;
  case '/partner/listings':
    state.marketplaceListings.push({
      id: nextId('listing'),
      partnerId: ctx.uid,
      title: typeof values.title === 'string' ? values.title : 'Untitled listing',
      description: typeof values.description === 'string' ? values.description : '',
      category: typeof values.category === 'string' ? values.category : '',
      status: 'draft',
      updatedAt: nowIso(),
    });
    break;
  case '/hq/sites':
    state.sites.push({
      id: nextId('site'),
      name: typeof values.name === 'string' ? values.name : 'Unnamed site',
      location: typeof values.location === 'string' ? values.location : '',
      status: 'pending',
      updatedAt: nowIso(),
    });
    break;
  default:
    break;
  }

  writeStore(state);
}

export async function updateE2EWorkflowRecord(ctx: WorkflowContext, target: WorkflowMutationTarget): Promise<void> {
  const state = readStore();

  switch (ctx.routePath) {
  case '/learner/missions': {
    const attempt = state.missionAttempts.find((entry) => entry.id === target.id);
    if (attempt) {
      attempt.status = 'submitted';
      attempt.updatedAt = nowIso();
    }
    break;
  }
  case '/partner/listings': {
    const listing = state.marketplaceListings.find((entry) => entry.id === target.id);
    if (listing) {
      listing.status = 'published';
      listing.updatedAt = nowIso();
    }
    break;
  }
  case '/hq/sites': {
    const site = state.sites.find((entry) => entry.id === target.id);
    if (site) {
      site.status = 'active';
      site.updatedAt = nowIso();
    }
    break;
  }
  default:
    break;
  }

  writeStore(state);
}

export async function deleteE2EWorkflowRecord(target: WorkflowMutationTarget): Promise<void> {
  const state = readStore();
  const collections: Record<string, Array<{ id: string }>> = {
    guardianLinks: state.guardianLinks,
    marketplaceListings: state.marketplaceListings,
    attendanceRecords: state.attendanceRecords,
    missionAttempts: state.missionAttempts,
    sites: state.sites,
  };
  const collection = collections[target.collectionName];

  if (!collection) {
    return;
  }

  const next = collection.filter((entry) => entry.id !== target.id);
  collection.splice(0, collection.length, ...next);
  writeStore(state);
}
