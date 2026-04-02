'use client';

import { httpsCallable } from 'firebase/functions';
import {
  addDoc,
  arrayRemove,
  arrayUnion,
  collection,
  deleteDoc,
  doc,
  documentId,
  getDoc,
  getDocs,
  increment,
  limit,
  orderBy,
  query,
  setDoc,
  serverTimestamp,
  updateDoc,
  where,
  type QueryConstraint,
} from 'firebase/firestore';
import { firestore, functions } from '@/src/firebase/client-init';
import type { UserProfile, UserRole } from '@/src/types/user';
import type { WorkflowPath } from '@/src/lib/routing/workflowRoutes';
import { loadCapabilitiesForSite, resolveCapabilityTitles } from '@/src/lib/capabilities/useCapabilities';

async function loadE2EWorkflowBackend() {
  return import('@/src/testing/e2e/fakeWebBackend');
}

export interface WorkflowContext {
  routePath: WorkflowPath;
  locale: string;
  uid: string;
  role: UserRole;
  profile: UserProfile | null;
}

export interface WorkflowRecord {
  id: string;
  title: string;
  subtitle: string;
  status: string;
  updatedAt: string | null;
  siteId: string | null;
  collectionName: string;
  routePath: WorkflowPath;
  canEdit: boolean;
  canDelete: boolean;
  primaryActionLabel?: string;
  deleteActionLabel?: string;
  metadata: Record<string, string>;
}

export interface WorkflowFieldOption {
  value: string;
  label: string;
}

export interface WorkflowFieldDefinition {
  name: string;
  label: string;
  type: 'text' | 'textarea' | 'select' | 'datetime-local' | 'checkbox' | 'email' | 'tel' | 'number';
  required?: boolean;
  placeholder?: string;
  helperText?: string;
  defaultValue?: string | boolean;
  options?: WorkflowFieldOption[];
}

export interface WorkflowFormDefinition {
  title: string;
  submitLabel: string;
  fields: WorkflowFieldDefinition[];
}

export interface WorkflowLoadResult {
  records: WorkflowRecord[];
  canCreate: boolean;
  canRefresh: boolean;
  createLabel: string;
  guidanceText?: string | null;
  createConfig?: WorkflowFormDefinition | null;
}

export interface WorkflowCreateInput {
  values: Record<string, string | boolean>;
}

export interface WorkflowMutationTarget {
  routePath: WorkflowPath;
  collectionName: string;
  id: string;
}

function toIsoDate(value: unknown): string | null {
  if (value && typeof value === 'object' && 'toDate' in value && typeof (value as { toDate: () => Date }).toDate === 'function') {
    return (value as { toDate: () => Date }).toDate().toISOString();
  }
  if (typeof value === 'number') return new Date(value).toISOString();
  if (typeof value === 'string') {
    const asMs = Date.parse(value);
    if (!Number.isNaN(asMs)) return new Date(asMs).toISOString();
  }
  return null;
}

function sortableTimestamp(value: string | null): number {
  if (!value) return Number.NEGATIVE_INFINITY;
  const parsed = Date.parse(value);
  return Number.isNaN(parsed) ? Number.NEGATIVE_INFINITY : parsed;
}

function asString(value: unknown, fallback: string): string {
  return typeof value === 'string' && value.trim().length > 0 ? value : fallback;
}

function asFiniteNumber(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === 'string' && value.trim().length > 0) {
    const numeric = Number(value);
    return Number.isFinite(numeric) ? numeric : null;
  }
  return null;
}

function asAvailabilityLabel(value: unknown): string | null {
  const numeric = asFiniteNumber(value);
  return numeric != null ? String(numeric) : null;
}

function asPercentLabelFromUnit(value: unknown): string | null {
  const numeric = asFiniteNumber(value);
  return numeric != null ? `${Math.round(numeric * 100)}%` : null;
}

function joinAvailableParts(parts: Array<string | null | undefined>): string {
  return parts.filter((part): part is string => typeof part === 'string' && part.trim().length > 0).join(' • ');
}

function metadataWithAvailableValues(values: Record<string, string | null | undefined>): Record<string, string> {
  return Object.fromEntries(
    Object.entries(values).filter((entry): entry is [string, string] => typeof entry[1] === 'string' && entry[1].trim().length > 0),
  );
}

function asBoolean(value: unknown, fallback = false): boolean {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    if (['true', '1', 'yes', 'on'].includes(normalized)) return true;
    if (['false', '0', 'no', 'off'].includes(normalized)) return false;
  }
  return fallback;
}

function canonicalizeFeatureFlagName(value: unknown): string | null {
  if (typeof value !== 'string' || value.trim().length === 0) {
    return null;
  }
  const normalized = value.trim();
  return normalized === 'miloos_loop' ? 'ai_help_loop' : normalized;
}

function canonicalizeFeatureFlagRow(row: Record<string, unknown>): Record<string, unknown> {
  const canonicalName = canonicalizeFeatureFlagName(row.name);
  if (!canonicalName) {
    return row;
  }
  return {
    ...row,
    name: canonicalName,
  };
}

function activeSiteId(profile: UserProfile | null): string | null {
  return profile?.activeSiteId || profile?.siteIds?.[0] || null;
}

function requireActiveSiteWorkflowContext(ctx: WorkflowContext): string {
  const siteId = activeSiteId(ctx.profile);
  if (!siteId) {
    throw new Error('Active site context is required for site workflows.');
  }
  return siteId;
}

function chunkValues<T>(values: T[], size: number): T[][] {
  const chunks: T[][] = [];
  for (let index = 0; index < values.length; index += size) {
    chunks.push(values.slice(index, index + size));
  }
  return chunks;
}

function toDateInputValue(value: Date): string {
  const year = value.getFullYear();
  const month = String(value.getMonth() + 1).padStart(2, '0');
  const day = String(value.getDate()).padStart(2, '0');
  const hours = String(value.getHours()).padStart(2, '0');
  const minutes = String(value.getMinutes()).padStart(2, '0');
  return `${year}-${month}-${day}T${hours}:${minutes}`;
}

function parseDateInputValue(value: unknown): Date | null {
  if (typeof value !== 'string' || value.trim().length === 0) return null;
  const parsed = Date.parse(value);
  return Number.isNaN(parsed) ? null : new Date(parsed);
}

function optionLabelFromRecord(data: Record<string, unknown>, fallbackId: string): string {
  const displayName = asString(data.displayName, '');
  if (displayName) return displayName;
  const title = asString(data.title, '');
  if (title) return title;
  const name = asString(data.name, '');
  if (name) return name;
  const email = asString(data.email, '');
  if (email) return email;
  return fallbackId;
}

/**
 * Enriches workflow records that have capabilityIds metadata with resolved capability titles.
 * Adds a `capabilities` metadata field with comma-separated capability titles.
 */
async function enrichRecordsWithCapabilityTitles(
  records: WorkflowRecord[],
  siteId: string | null
): Promise<void> {
  if (!siteId || records.length === 0) return;
  const hasCapabilities = records.some(
    (r) => r.metadata.capabilityIds && r.metadata.capabilityIds.length > 0
  );
  if (!hasCapabilities) return;

  try {
    const capMap = await loadCapabilitiesForSite(siteId);
    for (const record of records) {
      const raw = record.metadata.capabilityIds;
      if (!raw) continue;
      // capabilityIds is stored as comma-separated string in metadata (Firestore array → string coercion)
      const ids = raw.split(',').map((s) => s.trim()).filter(Boolean);
      if (ids.length === 0) continue;
      const titles = resolveCapabilityTitles(ids, capMap);
      record.metadata.capabilities = titles.join(', ');
    }
  } catch {
    // Capability resolution is best-effort; don't break the mission list
  }
}

function userLabelFromRecord(data: Record<string, unknown>, fallbackLabel = 'User name unavailable'): string {
  const displayName = asString(data.displayName, '');
  if (displayName) return displayName;
  const name = asString(data.name, '');
  if (name) return name;
  const email = asString(data.email, '');
  if (email) return email;
  return fallbackLabel;
}

async function loadMissionOptions(): Promise<WorkflowFieldOption[]> {
  const snap = await getDocs(
    query(
      collection(firestore, 'missions'),
      orderBy('title', 'asc'),
      limit(120),
    ),
  );

  return snap.docs.map((missionDoc) => {
    const data = (missionDoc.data() || {}) as Record<string, unknown>;
    return {
      value: missionDoc.id,
      label: optionLabelFromRecord(data, missionDoc.id),
    };
  });
}

async function loadSiteUserOptions(params: {
  siteId: string | null;
  roles?: UserRole[];
  limitSize?: number;
}): Promise<WorkflowFieldOption[]> {
  const constraints: QueryConstraint[] = [orderBy('displayName', 'asc')];
  if (params.siteId) {
    constraints.unshift(where('siteIds', 'array-contains', params.siteId));
  }
  if (params.limitSize) {
    constraints.push(limit(params.limitSize));
  }

  const snap = await getDocs(query(collection(firestore, 'users'), ...constraints));
  const allowedRoles = new Set((params.roles || []).map((role) => role.toLowerCase()));

  return snap.docs
    .filter((userDoc) => {
      if (allowedRoles.size === 0) return true;
      const role = asString((userDoc.data() || {}).role, '').toLowerCase();
      return allowedRoles.has(role === 'student' ? 'learner' : role);
    })
    .map((userDoc) => {
      const data = (userDoc.data() || {}) as Record<string, unknown>;
      const label = userLabelFromRecord(data);
      const role = asString(data.role, '').toLowerCase();
      return {
        value: userDoc.id,
        label: role ? `${label} (${role})` : label,
      };
    });
}

async function loadSiteSelectorOptions(limitSize = 200): Promise<WorkflowFieldOption[]> {
  const snap = await getDocs(
    query(
      collection(firestore, 'sites'),
      orderBy('name', 'asc'),
      limit(limitSize),
    ),
  ).catch(() => null);

  if (!snap) return [];
  return snap.docs.map((siteDoc) => {
    const data = (siteDoc.data() || {}) as Record<string, unknown>;
    return {
      value: siteDoc.id,
      label: optionLabelFromRecord(data, siteDoc.id),
    };
  });
}

async function loadPartnerContractOptionsForActor(ctx: WorkflowContext): Promise<WorkflowFieldOption[]> {
  const constraints: QueryConstraint[] = ctx.role === 'hq'
    ? [orderBy('updatedAt', 'desc'), limit(120)]
    : [where('partnerId', '==', ctx.uid), orderBy('updatedAt', 'desc'), limit(120)];

  const snap = await getDocs(query(collection(firestore, 'partnerContracts'), ...constraints));
  return snap.docs.map((contractDoc) => {
    const data = (contractDoc.data() || {}) as Record<string, unknown>;
    const baseLabel = optionLabelFromRecord(data, contractDoc.id);
    const siteId = asString(data.siteId, '');
    return {
      value: contractDoc.id,
      label: siteId ? `${baseLabel} (${siteId})` : baseLabel,
    };
  });
}

async function loadKpiPackOptions(limitSize = 80): Promise<WorkflowFieldOption[]> {
  const snap = await getDocs(
    query(
      collection(firestore, 'kpiPacks'),
      orderBy('updatedAt', 'desc'),
      limit(limitSize),
    ),
  ).catch(() => null);

  if (!snap) return [];
  return snap.docs.map((packDoc) => {
    const data = (packDoc.data() || {}) as Record<string, unknown>;
    const siteId = asString(data.siteId, '');
    const period = asString(data.period, 'month');
    return {
      value: packDoc.id,
      label: `${optionLabelFromRecord(data, packDoc.id)}${siteId ? ` • ${siteId}` : ''} • ${period}`,
    };
  });
}

async function loadLearnerOptionsForActor(ctx: WorkflowContext, siteId: string | null): Promise<WorkflowFieldOption[]> {
  if (ctx.role === 'educator') {
    const linksSnap = await getDocs(
      query(
        collection(firestore, 'educatorLearnerLinks'),
        where('educatorId', '==', ctx.uid),
        limit(100),
      ),
    );
    const learnerIds = Array.from(
      new Set(
        linksSnap.docs
          .map((linkDoc) => asString((linkDoc.data() || {}).learnerId, ''))
          .filter((value) => value.length > 0),
      ),
    );

    if (learnerIds.length > 0) {
      const options: WorkflowFieldOption[] = [];
      for (const ids of chunkValues(learnerIds, 10)) {
        const learnersSnap = await getDocs(
          query(
            collection(firestore, 'users'),
            where(documentId(), 'in', ids),
          ),
        );
        learnersSnap.docs.forEach((learnerDoc) => {
          const data = (learnerDoc.data() || {}) as Record<string, unknown>;
          options.push({
            value: learnerDoc.id,
            label: userLabelFromRecord(data, 'Learner name unavailable'),
          });
        });
      }
      return options.sort((left, right) => left.label.localeCompare(right.label));
    }
  }

  return loadSiteUserOptions({
    siteId,
    roles: ['learner'],
    limitSize: 160,
  });
}

async function loadSessionOptionsForActor(ctx: WorkflowContext, siteId: string | null): Promise<WorkflowFieldOption[]> {
  const constraints: QueryConstraint[] = [orderBy('startDate', 'asc'), limit(120)];
  if (ctx.role === 'educator') {
    constraints.unshift(where('educatorIds', 'array-contains', ctx.uid));
  }
  if (siteId) {
    constraints.unshift(where('siteId', '==', siteId));
  }

  const snap = await getDocs(query(collection(firestore, 'sessions'), ...constraints));
  return snap.docs.map((sessionDoc) => {
    const data = (sessionDoc.data() || {}) as Record<string, unknown>;
    const title = optionLabelFromRecord(data, sessionDoc.id);
    const startDate = toIsoDate(data.startDate || data.createdAt);
    return {
      value: sessionDoc.id,
      label: `${title} • ${startDate ? new Date(startDate).toLocaleString() : ''}`,
    };
  });
}

async function loadParentLinkRecords(ctx: WorkflowContext): Promise<Array<{ learnerId: string; learnerName: string }>> {
  const learnerIds = new Set<string>();
  const names = new Map<string, string>();

  const guardianLinksSnap = await getDocs(
    query(
      collection(firestore, 'guardianLinks'),
      where('parentId', '==', ctx.uid),
      limit(120),
    ),
  ).catch(() => null);

  guardianLinksSnap?.docs.forEach((linkDoc) => {
    const data = (linkDoc.data() || {}) as Record<string, unknown>;
    const learnerId = asString(data.learnerId, '');
    if (!learnerId) return;
    learnerIds.add(learnerId);
    const learnerName = asString(data.learnerName, '');
    if (learnerName) {
      names.set(learnerId, learnerName);
    }
  });

  const parentDoc = await getDoc(doc(collection(firestore, 'users'), ctx.uid)).catch(() => null);
  const explicitLearnerIds = Array.isArray(parentDoc?.data()?.learnerIds)
    ? (parentDoc?.data()?.learnerIds as unknown[]).filter((entry): entry is string => typeof entry === 'string' && entry.trim().length > 0)
    : [];
  explicitLearnerIds.forEach((learnerId) => learnerIds.add(learnerId));

  const unresolvedLearnerIds = Array.from(learnerIds.values()).filter((learnerId) => !names.has(learnerId));
  await Promise.all(unresolvedLearnerIds.map(async (learnerId) => {
    const userSnap = await getDoc(doc(collection(firestore, 'users'), learnerId)).catch(() => null);
    if (!userSnap?.exists()) return;
    const label = optionLabelFromRecord((userSnap.data() || {}) as Record<string, unknown>, '');
    if (label) {
      names.set(learnerId, label);
    }
  }));

  return Array.from(learnerIds.values()).map((learnerId) => ({
    learnerId,
    learnerName: names.get(learnerId) || 'Learner name unavailable',
  }));
}

async function loadPortfolioRecordsForLearners(params: {
  routePath: WorkflowPath;
  learnerIds: string[];
}): Promise<WorkflowRecord[]> {
  const records: WorkflowRecord[] = [];
  for (const learnerId of params.learnerIds) {
    const snap = await getDocs(
      query(
        collection(firestore, 'portfolioItems'),
        where('learnerId', '==', learnerId),
        orderBy('createdAt', 'desc'),
        limit(40),
      ),
    );
    snap.docs.forEach((snapDoc) => {
      records.push(
        buildRecord({
          routePath: params.routePath,
          collectionName: 'portfolioItems',
          id: snapDoc.id,
          raw: (snapDoc.data() || {}) as Record<string, unknown>,
          titleKeys: ['title', 'name'],
          subtitleKeys: ['description', 'mediaType'],
          statusKeys: ['status'],
          editable: false,
          deletable: false,
        }),
      );
    });
  }

  return records.sort((left, right) => sortableTimestamp(right.updatedAt) - sortableTimestamp(left.updatedAt));
}

async function loadParentSchedule(ctx: WorkflowContext): Promise<WorkflowRecord[]> {
  const linkRecords = await loadParentLinkRecords(ctx);
  const learnerIds = linkRecords.map((record) => record.learnerId);
  if (learnerIds.length === 0) return [];

  const sessionIds = new Set<string>();
  for (const ids of chunkValues(learnerIds, 10)) {
    const enrollmentsSnap = await getDocs(
      query(
        collection(firestore, 'enrollments'),
        where('learnerId', 'in', ids),
        where('status', '==', 'active'),
        limit(120),
      ),
    );
    enrollmentsSnap.docs.forEach((enrollmentDoc) => {
      const sessionId = asString((enrollmentDoc.data() || {}).sessionId, '');
      if (sessionId) {
        sessionIds.add(sessionId);
      }
    });
  }

  if (sessionIds.size === 0) return [];

  const records: WorkflowRecord[] = [];
  for (const ids of chunkValues(Array.from(sessionIds.values()), 10)) {
    const sessionsSnap = await getDocs(
      query(
        collection(firestore, 'sessions'),
        where(documentId(), 'in', ids),
      ),
    );
    sessionsSnap.docs.forEach((sessionDoc) => {
      records.push(
        buildRecord({
          routePath: '/parent/schedule',
          collectionName: 'sessions',
          id: sessionDoc.id,
          raw: (sessionDoc.data() || {}) as Record<string, unknown>,
          titleKeys: ['title', 'name'],
          subtitleKeys: ['description', 'siteId'],
          statusKeys: ['status'],
          editable: false,
          deletable: false,
        }),
      );
    });
  }

  return records.sort((left, right) => sortableTimestamp(left.updatedAt) - sortableTimestamp(right.updatedAt));
}

function sortWorkflowRecords(records: WorkflowRecord[]): WorkflowRecord[] {
  return [...records].sort((left, right) => sortableTimestamp(right.updatedAt) - sortableTimestamp(left.updatedAt));
}

async function loadParentDashboardBundlePayload(ctx: WorkflowContext): Promise<Record<string, unknown>> {
  const callable = httpsCallable(functions, 'getParentDashboardBundle');
  const payload = await callable({
    siteId: activeSiteId(ctx.profile) || undefined,
    locale: ctx.locale,
    range: 'week',
  });
  return (payload.data || {}) as Record<string, unknown>;
}

async function loadParentPortfolioWorkflowRecords(ctx: WorkflowContext): Promise<WorkflowRecord[]> {
  const payload = await loadParentDashboardBundlePayload(ctx);
  const learners = Array.isArray(payload.learners) ? payload.learners : [];
  const learnerIds: string[] = [];
  const summaryRecords: WorkflowRecord[] = [];

  for (const rawLearner of learners) {
    if (!rawLearner || typeof rawLearner !== 'object' || Array.isArray(rawLearner)) continue;
    const learner = rawLearner as Record<string, unknown>;
    const learnerId = asString(learner.learnerId, '');
    const learnerName = asString(learner.learnerName, '') || 'Learner name unavailable';
    if (!learnerId) continue;
    learnerIds.push(learnerId);

    const capability = learner.capabilitySnapshot as Record<string, unknown> | undefined;
    const portfolio = learner.portfolioSnapshot as Record<string, unknown> | undefined;
    const ideation = learner.ideationPassport as Record<string, unknown> | undefined;
    const futureSkills = capability ? asPercentLabelFromUnit(capability.futureSkills) : null;
    const leadership = capability ? asPercentLabelFromUnit(capability.leadership) : null;
    const impact = capability ? asPercentLabelFromUnit(capability.impact) : null;
    const capabilityBand = capability && typeof capability.band === 'string' && capability.band.trim().length > 0
      ? capability.band.trim()
      : null;
    const artifactCount = portfolio ? asAvailabilityLabel(portfolio.artifactCount) : null;
    const publishedArtifactCount = portfolio ? asAvailabilityLabel(portfolio.publishedArtifactCount) : null;
    const badgeCount = portfolio ? asAvailabilityLabel(portfolio.badgeCount) : null;
    const projectCount = portfolio ? asAvailabilityLabel(portfolio.projectCount) : null;
    const missionAttempts = ideation ? asAvailabilityLabel(ideation.missionAttempts) : null;
    const completedMissions = ideation ? asAvailabilityLabel(ideation.completedMissions) : null;
    const reflectionsSubmitted = ideation ? asAvailabilityLabel(ideation.reflectionsSubmitted) : null;
    const voiceInteractions = ideation ? asAvailabilityLabel(ideation.voiceInteractions) : null;
    const collaborationSignals = ideation ? asAvailabilityLabel(ideation.collaborationSignals) : null;

    summaryRecords.push(
      buildRecord({
        routePath: '/parent/portfolio',
        collectionName: 'parentCapabilitySnapshots',
        id: `capability:${learnerId}`,
        raw: {
          title: `${learnerName} growth snapshot`,
          summary: joinAvailableParts([
            futureSkills ? `Future Skills ${futureSkills}` : null,
            leadership ? `Leadership ${leadership}` : null,
            impact ? `Impact & Innovation ${impact}` : null,
          ]) || 'No verified growth evidence yet',
          status: capabilityBand || 'Evidence building',
          updatedAt: portfolio?.latestArtifactAt || learner.updatedAt || new Date().toISOString(),
          siteId: activeSiteId(ctx.profile),
          ...metadataWithAvailableValues({
            futureSkills: capability ? asAvailabilityLabel(capability.futureSkills) : null,
            leadership: capability ? asAvailabilityLabel(capability.leadership) : null,
            impact: capability ? asAvailabilityLabel(capability.impact) : null,
            overall: capability ? asAvailabilityLabel(capability.overall) : null,
          }),
        },
        titleKeys: ['title'],
        subtitleKeys: ['summary'],
        statusKeys: ['status'],
        editable: false,
        deletable: false,
      }),
    );

    summaryRecords.push(
      buildRecord({
        routePath: '/parent/portfolio',
        collectionName: 'parentPortfolioSnapshots',
        id: `portfolio:${learnerId}`,
        raw: {
          title: `${learnerName} portfolio highlights`,
          summary: joinAvailableParts([
            artifactCount ? `Artifacts ${artifactCount}` : null,
            publishedArtifactCount ? `Shared ${publishedArtifactCount}` : null,
            badgeCount ? `Badges ${badgeCount}` : null,
          ]) || 'No verified portfolio evidence yet',
          status: 'active',
          updatedAt: portfolio?.latestArtifactAt || learner.updatedAt || new Date().toISOString(),
          siteId: activeSiteId(ctx.profile),
          ...metadataWithAvailableValues({
            artifactCount,
            publishedArtifactCount,
            badgeCount,
            projectCount,
          }),
        },
        titleKeys: ['title'],
        subtitleKeys: ['summary'],
        statusKeys: ['status'],
        editable: false,
        deletable: false,
      }),
    );

    summaryRecords.push(
      buildRecord({
        routePath: '/parent/portfolio',
        collectionName: 'parentIdeationPassports',
        id: `passport:${learnerId}`,
        raw: {
          title: `${learnerName} learning story`,
          summary: joinAvailableParts([
            completedMissions ? `Completed missions ${completedMissions}` : null,
            reflectionsSubmitted ? `Reflections ${reflectionsSubmitted}` : null,
            voiceInteractions ? `Voice check-ins ${voiceInteractions}` : null,
          ]) || 'No verified ideation evidence yet',
          status: 'active',
          updatedAt: ideation?.lastReflectionAt || portfolio?.latestArtifactAt || new Date().toISOString(),
          siteId: activeSiteId(ctx.profile),
          ...metadataWithAvailableValues({
            missionAttempts,
            completedMissions,
            reflectionsSubmitted,
            voiceInteractions,
            collaborationSignals,
          }),
        },
        titleKeys: ['title'],
        subtitleKeys: ['summary'],
        statusKeys: ['status'],
        editable: false,
        deletable: false,
      }),
    );
  }

  const portfolioRecords = await loadPortfolioRecordsForLearners({
    routePath: ctx.routePath,
    learnerIds,
  });
  const parentSiteId = activeSiteId(ctx.profile);
  await enrichRecordsWithCapabilityTitles(portfolioRecords, parentSiteId);
  return sortWorkflowRecords([...summaryRecords, ...portfolioRecords]);
}

async function loadWorkflowContacts(ctx: WorkflowContext): Promise<WorkflowFieldOption[]> {
  const callable = httpsCallable(functions, 'listWorkflowContacts');
  const response = await callable({
    siteId: activeSiteId(ctx.profile) || undefined,
    limit: 80,
  });
  const payload = (response.data || {}) as Record<string, unknown>;
  const contacts = Array.isArray(payload.contacts) ? payload.contacts : [];
  return contacts
    .filter((entry): entry is Record<string, unknown> => !!entry && typeof entry === 'object' && !Array.isArray(entry))
    .map((entry) => {
      const id = asString(entry.id, '');
      const displayName = asString(entry.displayName, asString(entry.email, 'User name unavailable'));
      const role = asString(entry.role, '');
      return {
        value: id,
        label: role ? `${displayName} (${role})` : displayName,
      };
    })
    .filter((entry) => entry.value.length > 0);
}

function buildCreateConfig(title: string, submitLabel: string, fields: WorkflowFieldDefinition[]): WorkflowFormDefinition {
  return {
    title,
    submitLabel,
    fields,
  };
}

function applyRouteActionLabels(records: WorkflowRecord[], routePath: WorkflowPath): WorkflowRecord[] {
  return records.map((record) => {
    let primaryActionLabel: string | undefined;
    let deleteActionLabel: string | undefined;

    if (routePath === '/hq/approvals') {
      primaryActionLabel = 'Approve';
    } else if (routePath === '/hq/feature-flags') {
      primaryActionLabel = record.status === 'enabled' ? 'Disable flag' : 'Enable flag';
    } else {
      switch (routePath) {
      case '/learner/missions':
        primaryActionLabel = record.status === 'submitted' ? 'Reopen attempt' : 'Submit attempt';
        break;
      case '/learner/portfolio':
        primaryActionLabel = record.status === 'published' ? 'Refresh item' : 'Publish item';
        deleteActionLabel = 'Delete item';
        break;
      case '/educator/attendance':
        primaryActionLabel = 'Verify record';
        break;
      case '/educator/sessions':
      case '/site/sessions':
        primaryActionLabel = record.status === 'in_progress' ? 'Complete session' : 'Start session';
        break;
      case '/educator/missions/review':
        primaryActionLabel = 'Mark reviewed';
        break;
      case '/educator/mission-plans':
        primaryActionLabel = record.status === 'active' ? 'Archive plan' : 'Activate plan';
        break;
      case '/site/provisioning':
        if (record.collectionName === 'cohortLaunches') {
          primaryActionLabel = record.status === 'active' ? 'Pause cohort' : 'Start cohort';
        } else {
          primaryActionLabel = record.status === 'active' ? 'Suspend link' : 'Activate link';
          deleteActionLabel = 'Remove link';
        }
        break;
      case '/site/clever':
        if (record.collectionName === 'integrationConnections') {
          primaryActionLabel = record.status === 'active' || record.status === 'pending'
            ? 'Disconnect Clever'
            : 'Reconnect Clever';
        }
        break;
      case '/site/ops':
        primaryActionLabel = record.status === 'resolved' ? 'Reopen event' : 'Resolve event';
        break;
      case '/site/identity':
        primaryActionLabel = 'Resolve link';
        break;
      case '/site/incidents':
        primaryActionLabel = 'Resolve incident';
        break;
      case '/partner/listings':
        primaryActionLabel = record.status === 'published' ? 'Archive listing' : 'Publish listing';
        break;
      case '/partner/contracts':
        if (record.collectionName === 'partnerLaunches') {
          primaryActionLabel = record.status === 'active' ? 'Pause launch' : 'Start launch';
        } else {
          primaryActionLabel = record.status === 'submitted' ? 'Return to draft' : 'Submit contract';
        }
        break;
      case '/partner/deliverables':
        primaryActionLabel = record.status === 'accepted' ? 'Mark submitted' : 'Accept deliverable';
        break;
      case '/hq/curriculum':
        if (record.collectionName === 'trainingCycles') {
          primaryActionLabel = record.status === 'completed' ? 'Reopen cycle' : 'Complete cycle';
        } else {
          primaryActionLabel = record.status === 'published'
            ? 'Refresh published unit'
            : record.status === 'in_review'
            ? 'Publish unit'
            : 'Submit for review';
        }
        break;
      case '/hq/sites':
        primaryActionLabel = record.status === 'active' ? 'Pause site' : 'Activate site';
        break;
      case '/hq/user-admin':
        primaryActionLabel = record.metadata.isActive === 'false' ? 'Activate user' : 'Deactivate user';
        break;
      case '/hq/safety':
        primaryActionLabel = 'Resolve incident';
        break;
      case '/messages':
        primaryActionLabel = record.status === 'archived' ? 'Reopen thread' : 'Archive thread';
        break;
      case '/notifications':
        primaryActionLabel = record.metadata.isRead === 'true' ? 'Mark unread' : 'Mark read';
        break;
      default:
        primaryActionLabel = record.canEdit ? 'Update' : undefined;
        deleteActionLabel = record.canDelete ? 'Delete' : undefined;
        break;
      }
    }

    return {
      ...record,
      primaryActionLabel,
      deleteActionLabel,
    };
  });
}

function buildRecord(params: {
  routePath: WorkflowPath;
  collectionName: string;
  id: string;
  raw: Record<string, unknown>;
  titleKeys: string[];
  subtitleKeys: string[];
  statusKeys: string[];
  siteKeys?: string[];
  metadataOverride?: Record<string, string>;
  excludedMetadataKeys?: string[];
  editable?: boolean;
  deletable?: boolean;
}): WorkflowRecord {
  const pick = (keys: string[], fallback: string) => {
    for (const key of keys) {
      const value = params.raw[key];
      if (typeof value === 'string' && value.trim().length > 0) {
        return value;
      }
    }
    return fallback;
  };

  const siteKeys = params.siteKeys || ['siteId'];
  let siteId: string | null = null;
  for (const key of siteKeys) {
    const value = params.raw[key];
    if (typeof value === 'string' && value.trim().length > 0) {
      siteId = value;
      break;
    }
  }

  const excludedMetadataKeys = new Set(params.excludedMetadataKeys || []);
  const metadata: Record<string, string> = params.metadataOverride ? { ...params.metadataOverride } : {};
  Object.entries(params.raw).forEach(([key, value]) => {
    if (key in metadata) return;
    if (excludedMetadataKeys.has(key)) return;
    if (['title', 'name', 'displayName', 'description', 'status'].includes(key)) return;
    if (value === null || value === undefined) return;
    if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') {
      metadata[key] = String(value);
    }
  });

  return {
    id: params.id,
    title: pick(params.titleKeys, params.id),
    subtitle: pick(params.subtitleKeys, 'No details available yet.'),
    status: pick(params.statusKeys, 'active'),
    updatedAt: toIsoDate(params.raw.updatedAt || params.raw.createdAt || params.raw.timestamp),
    siteId,
    collectionName: params.collectionName,
    routePath: params.routePath,
    canEdit: Boolean(params.editable),
    canDelete: Boolean(params.deletable),
    primaryActionLabel: undefined,
    deleteActionLabel: undefined,
    metadata,
  };
}

async function queryCollectionRecords(params: {
  routePath: WorkflowPath;
  collectionName: string;
  constraints?: QueryConstraint[];
  titleKeys: string[];
  subtitleKeys: string[];
  statusKeys: string[];
  editable?: boolean;
  deletable?: boolean;
  limitSize?: number;
}): Promise<WorkflowRecord[]> {
  const constraints = [...(params.constraints || [])];
  if (params.limitSize) {
    constraints.push(limit(params.limitSize));
  }
  const ref = collection(firestore, params.collectionName);
  const snap = await getDocs(constraints.length > 0 ? query(ref, ...constraints) : ref);
  return snap.docs.map((snapDoc) =>
    buildRecord({
      routePath: params.routePath,
      collectionName: params.collectionName,
      id: snapDoc.id,
      raw: (snapDoc.data() || {}) as Record<string, unknown>,
      titleKeys: params.titleKeys,
      subtitleKeys: params.subtitleKeys,
      statusKeys: params.statusKeys,
      editable: params.editable,
      deletable: params.deletable,
    }),
  );
}

async function loadLearnerToday(ctx: WorkflowContext): Promise<WorkflowRecord[]> {
  const enrollmentsSnap = await getDocs(
    query(
      collection(firestore, 'enrollments'),
      where('learnerId', '==', ctx.uid),
      where('status', '==', 'active'),
      limit(25),
    ),
  );

  const sessionIds = enrollmentsSnap.docs
    .map((snapDoc) => snapDoc.data().sessionId)
    .filter((value): value is string => typeof value === 'string' && value.trim().length > 0)
    .slice(0, 10);

  if (sessionIds.length === 0) return [];

  const sessionsSnap = await getDocs(
    query(collection(firestore, 'sessions'), where(documentId(), 'in', sessionIds)),
  );

  return sessionsSnap.docs.map((snapDoc) =>
    buildRecord({
      routePath: '/learner/today',
      collectionName: 'sessions',
      id: snapDoc.id,
      raw: (snapDoc.data() || {}) as Record<string, unknown>,
      titleKeys: ['title', 'name'],
      subtitleKeys: ['description', 'siteId'],
      statusKeys: ['status'],
      editable: false,
      deletable: false,
    }),
  );
}

async function loadParentSummary(ctx: WorkflowContext): Promise<WorkflowRecord[]> {
  const data = await loadParentDashboardBundlePayload(ctx);
  const learners = Array.isArray(data.learners) ? data.learners : [];
  return learners
    .filter((item): item is Record<string, unknown> => !!item && typeof item === 'object' && !Array.isArray(item))
    .map((learner) => {
      const learnerId = asString(learner.learnerId, '');
      if (!learnerId) return null;
      const missionsCompleted = asFiniteNumber(learner.missionsCompleted);
      const currentStreak = asFiniteNumber(learner.currentStreak);
      const attendanceRate = asFiniteNumber(learner.attendanceRate);
      const capabilityBand = typeof (learner.capabilitySnapshot as Record<string, unknown> | undefined)?.band === 'string'
        ? ((learner.capabilitySnapshot as Record<string, unknown>).band as string)
        : null;
      const artifactCount = asFiniteNumber((learner.portfolioSnapshot as Record<string, unknown> | undefined)?.artifactCount);
      const reflectionsSubmitted = asFiniteNumber((learner.ideationPassport as Record<string, unknown> | undefined)?.reflectionsSubmitted);
      const learnerName = asString(learner.learnerName, '') || 'Learner name unavailable';
      const subtitle = joinAvailableParts([
        artifactCount != null ? `Artifacts ${artifactCount}` : null,
        reflectionsSubmitted != null ? `Reflections ${reflectionsSubmitted}` : null,
        missionsCompleted != null ? `Completed missions ${missionsCompleted}` : null,
      ]) || 'No verified portfolio or reflection evidence yet';

      return {
        id: learnerId,
        title: learnerName,
        subtitle,
        status: 'active',
        updatedAt: toIsoDate(learner.updatedAt || learner.lastActivityAt),
        siteId: activeSiteId(ctx.profile),
        collectionName: 'parentDashboardBundle',
        routePath: '/parent/summary',
        canEdit: false,
        canDelete: false,
        metadata: metadataWithAvailableValues({
          missionsCompleted: missionsCompleted != null ? String(missionsCompleted) : null,
          currentStreak: currentStreak != null ? String(currentStreak) : null,
          attendanceRate: attendanceRate != null ? String(attendanceRate) : null,
          capabilityBand: capabilityBand && capabilityBand.trim().length > 0 ? capabilityBand : null,
          artifactCount: artifactCount != null ? String(artifactCount) : null,
          reflectionsSubmitted: reflectionsSubmitted != null ? String(reflectionsSubmitted) : null,
        }),
      } as WorkflowRecord;
    })
    .filter((row): row is WorkflowRecord => Boolean(row));
}

async function loadParentBillingRecords(ctx: WorkflowContext): Promise<WorkflowRecord[]> {
  const callable = httpsCallable(functions, 'getParentBillingSummary');
  const response = await callable({ parentId: ctx.uid });
  const payload = (response.data || {}) as Record<string, unknown>;
  const summary = payload.summary && typeof payload.summary === 'object' && !Array.isArray(payload.summary)
    ? payload.summary as Record<string, unknown>
    : null;
  const recentPayments = Array.isArray(summary?.recentPayments) ? summary.recentPayments : [];

  let summaryRecord: WorkflowRecord | null = null;
  if (summary != null) {
    const subscriptionPlan = asString(summary.subscriptionPlan, '');
    const nextPaymentDate = asString(summary.nextPaymentDate, '');
    const hasUpcomingCharge = nextPaymentDate.length > 0 || summary.nextPaymentAmount != null;
    const currentBalance = asAvailabilityLabel(summary.currentBalance);
    const nextPaymentAmount = asAvailabilityLabel(summary.nextPaymentAmount);
    const subtitle = hasUpcomingCharge
      ? joinAvailableParts([
          currentBalance ? `Current balance ${currentBalance}` : null,
          nextPaymentAmount ? `Next ${nextPaymentAmount}` : null,
        ])
      : recentPayments.length > 0
        ? `${recentPayments.length} recent payments`
        : joinAvailableParts([
            currentBalance ? `Current balance ${currentBalance}` : null,
          ]);

    summaryRecord = {
      id: asString(summary.parentId, ctx.uid),
      title: subscriptionPlan || 'Billing Summary',
      subtitle: subtitle || 'No verified billing evidence yet',
      status: 'active',
      updatedAt: toIsoDate(summary.nextPaymentDate),
      siteId: activeSiteId(ctx.profile),
      collectionName: 'parentBillingSummary',
      routePath: '/parent/billing',
      canEdit: false,
      canDelete: false,
      metadata: metadataWithAvailableValues({
        nextPaymentDate,
        parentId: asString(summary.parentId, ctx.uid),
      }),
    };
  }

  const paymentRecords: WorkflowRecord[] = recentPayments
    .filter((entry): entry is Record<string, unknown> => !!entry && typeof entry === 'object' && !Array.isArray(entry))
    .map((entry) => {
      const id = asString(entry.id, '');
      if (!id) return null;
      const amountLabel = asAvailabilityLabel(entry.amount);
      const statusLabel = typeof entry.status === 'string' && entry.status.trim().length > 0 ? entry.status : null;
      return {
        id,
        title: asString(entry.description, 'Payment'),
        subtitle: joinAvailableParts([
          amountLabel ? `Amount ${amountLabel}` : null,
          statusLabel,
        ]) || 'Payment details unavailable',
        status: statusLabel || 'No status yet',
        updatedAt: toIsoDate(entry.date),
        siteId: activeSiteId(ctx.profile),
        collectionName: 'payments',
        routePath: '/parent/billing',
        canEdit: false,
        canDelete: false,
        metadata: {},
      };
    })
    .filter((record): record is WorkflowRecord => Boolean(record));

  return summaryRecord == null ? paymentRecords : [summaryRecord, ...paymentRecords];
}

async function loadSiteBillingRecords(ctx: WorkflowContext): Promise<WorkflowRecord[]> {
  const callable = httpsCallable(functions, 'getSiteBillingSnapshot');
  const response = await callable({ siteId: activeSiteId(ctx.profile) || undefined });
  const payload = (response.data || {}) as Record<string, unknown>;
  const summary = (payload.summary && typeof payload.summary === 'object' && !Array.isArray(payload.summary))
    ? (payload.summary as Record<string, unknown>)
    : null;
  const invoices = Array.isArray(payload.invoices) ? payload.invoices : [];

  const recordSiteId = asString(payload.siteId, asString(summary?.siteId, activeSiteId(ctx.profile) || ''));
  const monthlyAmount = summary ? asAvailabilityLabel(summary.monthlyAmount) : null;
  const currency = summary && typeof summary.currency === 'string' && summary.currency.trim().length > 0 ? summary.currency : null;
  const planStatus = summary && typeof summary.planStatus === 'string' && summary.planStatus.trim().length > 0 ? summary.planStatus : null;
  const siteSummary: WorkflowRecord | null = summary == null ? null : {
    id: recordSiteId,
    title: asString(summary.planName, 'Site Billing'),
    subtitle: joinAvailableParts([
      currency && monthlyAmount ? `${currency} ${monthlyAmount} / month` : null,
      currency && !monthlyAmount ? currency : null,
      !currency && monthlyAmount ? monthlyAmount : null,
    ]) || 'No verified site billing evidence yet',
    status: planStatus || 'No plan status yet',
    updatedAt: toIsoDate(summary.nextBillingDate),
    siteId: recordSiteId || null,
    collectionName: 'siteBillingSummary',
    routePath: '/site/billing',
    canEdit: false,
    canDelete: false,
    metadata: metadataWithAvailableValues({
      activeLearnersUsed: asAvailabilityLabel(summary.activeLearnersUsed),
      activeLearnersTotal: asAvailabilityLabel(summary.activeLearnersTotal),
      educatorsUsed: asAvailabilityLabel(summary.educatorsUsed),
      educatorsTotal: asAvailabilityLabel(summary.educatorsTotal),
      storageUsedGb: asAvailabilityLabel(summary.storageUsedGb),
      storageTotalGb: asAvailabilityLabel(summary.storageTotalGb),
    }),
  };

  const invoiceRecords: WorkflowRecord[] = invoices
    .filter((entry): entry is Record<string, unknown> => !!entry && typeof entry === 'object' && !Array.isArray(entry))
    .map((entry): WorkflowRecord | null => {
      const id = asString(entry.id, '');
      if (!id) return null;
      const currencyLabel = typeof entry.currency === 'string' && entry.currency.trim().length > 0 ? entry.currency.toUpperCase() : null;
      const amountLabel = asAvailabilityLabel(entry.amount);
      const statusLabel = typeof entry.status === 'string' && entry.status.trim().length > 0 ? entry.status : null;
      return {
        id,
        title: `Invoice ${id}`,
        subtitle: joinAvailableParts([
          currencyLabel && amountLabel ? `${currencyLabel} ${amountLabel}` : null,
          currencyLabel && !amountLabel ? currencyLabel : null,
          !currencyLabel && amountLabel ? amountLabel : null,
        ]) || 'Invoice amount unavailable',
        status: statusLabel || 'No status yet',
        updatedAt: toIsoDate(entry.date),
        siteId: recordSiteId || null,
        collectionName: 'siteInvoices',
        routePath: '/site/billing',
        canEdit: false,
        canDelete: false,
        metadata: {},
      };
    })
    .filter((record): record is WorkflowRecord => Boolean(record));

  return siteSummary == null ? invoiceRecords : [siteSummary, ...invoiceRecords];
}

async function loadHqBillingRecords(): Promise<WorkflowRecord[]> {
  const billingCallable = httpsCallable(functions, 'listHqBillingRecords');
  const response = await billingCallable({ period: 'month', limit: 500 });
  const payload = (response.data || {}) as Record<string, unknown>;
  const invoices = Array.isArray(payload.invoices) ? payload.invoices : [];

  const invoiceRecords: WorkflowRecord[] = [];
  for (const rawEntry of invoices) {
    if (!rawEntry || typeof rawEntry !== 'object' || Array.isArray(rawEntry)) {
      continue;
    }
    const entry = rawEntry as Record<string, unknown>;
    const id = asString(entry.id, '');
    if (!id) continue;
    const siteLabel = typeof entry.site === 'string' && entry.site.trim().length > 0 ? entry.site : null;
    const amountLabel = asAvailabilityLabel(entry.amount);
    const statusLabel = typeof entry.status === 'string' && entry.status.trim().length > 0 ? entry.status : null;
    invoiceRecords.push({
      id,
      title: `Invoice ${id}`,
      subtitle: joinAvailableParts([
        siteLabel,
        amountLabel,
      ]) || 'Invoice details unavailable',
      status: statusLabel || 'No status yet',
      updatedAt: toIsoDate(entry.date),
      siteId: null,
      collectionName: 'hqInvoices',
      routePath: '/hq/billing',
      canEdit: false,
      canDelete: false,
      metadata: metadataWithAvailableValues({
        parent: typeof entry.parent === 'string' ? entry.parent : null,
        learner: typeof entry.learner === 'string' ? entry.learner : null,
      }),
    });
  }

  return invoiceRecords;
}

async function loadHqAnalyticsRecords(ctx: WorkflowContext): Promise<WorkflowRecord[]> {
  const callable = httpsCallable(functions, 'getTelemetryDashboardMetrics');
  const [response, kpiPackRecords, backfillAuditRecords] = await Promise.all([
    callable({
      siteId: activeSiteId(ctx.profile) || undefined,
      period: 'month',
    }),
    loadCallableRows({
      routePath: ctx.routePath,
      callableName: 'listKpiPacks',
      args: { limit: 40 },
      rowArrayField: 'packs',
      collectionName: 'kpiPacks',
      titleKeys: ['title', 'siteId', 'id'],
      subtitleKeys: ['recommendation', 'period'],
      statusKeys: ['status', 'portfolioQualityGrade'],
      metadataBuilder: buildKpiPackMetadata,
      editable: false,
      deletable: false,
    }).catch(() => []),
    loadAnalyticsBackfillAuditRecords(ctx),
  ]);
  const payload = (response.data || {}) as Record<string, unknown>;
  const metrics = ((payload.metrics || {}) as Record<string, unknown>);
  const attendanceTrend = Array.isArray(metrics.attendanceTrend) ? metrics.attendanceTrend : [];

  const trendRecords: WorkflowRecord[] = [];
  for (const rawEntry of attendanceTrend) {
    if (!rawEntry || typeof rawEntry !== 'object' || Array.isArray(rawEntry)) {
      continue;
    }
    const entry = rawEntry as Record<string, unknown>;
    const dateId = asString(entry.date, '');
    if (!dateId) continue;
    const recordsLabel = asAvailabilityLabel(entry.records);
    const presentRate = asFiniteNumber(entry.presentRate);
    trendRecords.push({
      id: dateId,
      title: `Attendance ${dateId}`,
      subtitle: joinAvailableParts([
        recordsLabel ? `Records ${recordsLabel}` : null,
        presentRate != null ? `Present ${presentRate}%` : null,
      ]) || 'No verified attendance evidence yet',
      status: 'active',
      updatedAt: toIsoDate(entry.date),
      siteId: activeSiteId(ctx.profile),
      collectionName: 'analyticsAttendanceTrend',
      routePath: '/hq/analytics',
      canEdit: false,
      canDelete: false,
      metadata: metadataWithAvailableValues({
        events: asAvailabilityLabel(entry.events),
        weeklyAccountabilityAdherenceRate: asAvailabilityLabel(metrics.weeklyAccountabilityAdherenceRate),
        educatorReviewWithinSlaRate: asAvailabilityLabel(metrics.educatorReviewWithinSlaRate),
        interventionHelpedRate: asAvailabilityLabel(metrics.interventionHelpedRate),
      }),
    });
  }

  return sortWorkflowRecords([...trendRecords, ...kpiPackRecords, ...backfillAuditRecords]);
}

async function loadHqRoleSwitcherRecords(): Promise<WorkflowRecord[]> {
  const callable = httpsCallable(functions, 'listUsers');
  const response = await callable({ limit: 250 });
  const users = (((response.data || {}) as Record<string, unknown>).users || []) as unknown[];
  const roleTargets: UserRole[] = ['learner', 'educator', 'parent', 'site', 'partner'];
  const rows: WorkflowRecord[] = [];

  for (const targetRole of roleTargets) {
    const match = users.find((entry) => {
      if (!entry || typeof entry !== 'object' || Array.isArray(entry)) return false;
      const role = asString((entry as Record<string, unknown>).role, '').toLowerCase();
      return role === targetRole;
    }) as Record<string, unknown> | undefined;

    if (!match) continue;
    const userId = asString(match.id, '');
    if (!userId) continue;
    rows.push({
      id: userId,
      title: `Impersonate ${targetRole}`,
      subtitle: asString(match.displayName, asString(match.email, userId)),
      status: 'ready',
      updatedAt: toIsoDate(match.updatedAt || match.createdAt),
      siteId: asString(match.activeSiteId, '') || null,
      collectionName: 'roleSwitcher',
      routePath: '/hq/role-switcher',
      canEdit: false,
      canDelete: false,
      metadata: {
        targetRole,
        targetUid: userId,
        targetEmail: asString(match.email, ''),
      },
    });
  }

  return rows;
}

async function loadCallableRows(params: {
  routePath: WorkflowPath;
  callableName: string;
  args: Record<string, unknown>;
  rowArrayField: string;
  collectionName: string;
  titleKeys: string[];
  subtitleKeys: string[];
  statusKeys: string[];
  metadataBuilder?: (row: Record<string, unknown>) => Record<string, string>;
  rowTransformer?: (row: Record<string, unknown>) => Record<string, unknown>;
  excludedMetadataKeys?: string[];
  editable?: boolean;
  deletable?: boolean;
}): Promise<WorkflowRecord[]> {
  const callable = httpsCallable(functions, params.callableName);
  const response = await callable(params.args);
  const payload = (response.data || {}) as Record<string, unknown>;
  const rows = payload[params.rowArrayField];
  if (!Array.isArray(rows)) return [];

  return rows
    .filter((row): row is Record<string, unknown> => !!row && typeof row === 'object' && !Array.isArray(row))
    .map((row) => {
      const normalizedRow = params.rowTransformer ? params.rowTransformer(row) : row;
      const id = asString(normalizedRow.id, '');
      if (!id) return null;
      return buildRecord({
        routePath: params.routePath,
        collectionName: params.collectionName,
        id,
        raw: normalizedRow,
        titleKeys: params.titleKeys,
        subtitleKeys: params.subtitleKeys,
        statusKeys: params.statusKeys,
        metadataOverride: params.metadataBuilder?.(normalizedRow),
        excludedMetadataKeys: params.excludedMetadataKeys,
        editable: params.editable,
        deletable: params.deletable,
      });
    })
    .filter((record): record is WorkflowRecord => Boolean(record));
}

function buildKpiPackMetadata(row: Record<string, unknown>): Record<string, string> {
  const voiceReliability = row.voiceReliability && typeof row.voiceReliability === 'object' && !Array.isArray(row.voiceReliability)
    ? row.voiceReliability as Record<string, unknown>
    : null;

  return metadataWithAvailableValues({
    fidelityScore: asAvailabilityLabel(row.fidelityScore),
    voiceCaptureSuccessRate: asPercentLabelFromUnit(voiceReliability?.captureSuccessRate),
    voiceCaptureFailures: asAvailabilityLabel(voiceReliability?.captureFailureCount),
    voiceEscalations: asAvailabilityLabel(voiceReliability?.escalationCount),
    voiceBlocks: asAvailabilityLabel(voiceReliability?.blockedCount),
  });
}

async function loadAnalyticsBackfillAuditRecords(ctx: WorkflowContext): Promise<WorkflowRecord[]> {
  const records = await loadCallableRows({
    routePath: ctx.routePath,
    callableName: 'listAnalyticsRepairRuns',
    args: { limit: 120 },
    rowArrayField: 'runs',
    collectionName: 'analyticsRepairRuns',
    titleKeys: ['title', 'id'],
    subtitleKeys: ['subtitle', 'siteId'],
    statusKeys: ['status'],
    metadataBuilder: (row) => row.metadata && typeof row.metadata === 'object' && !Array.isArray(row.metadata)
      ? Object.fromEntries(
          Object.entries(row.metadata as Record<string, unknown>)
            .filter((entry) => entry[1] !== null && entry[1] !== undefined)
            .flatMap((entry) => {
              const value = entry[1];
              if (typeof value === 'string') {
                return value.trim().length > 0 ? [[entry[0], value]] : [];
              }
              if (typeof value === 'number' || typeof value === 'boolean') {
                return [[entry[0], String(value)]];
              }
              return [];
            }),
        )
      : {},
    excludedMetadataKeys: ['id', 'title', 'subtitle', 'status', 'updatedAt', 'actorRole'],
    editable: false,
    deletable: false,
  }).catch(() => []);

  return records.filter((record) => record.title === 'Telemetry aggregate backfill' || record.title === 'KPI voice backfill');
}

async function loadPartnerDeliverableRecords(ctx: WorkflowContext): Promise<WorkflowRecord[]> {
  const contractConstraints: QueryConstraint[] = ctx.role === 'hq'
    ? [orderBy('updatedAt', 'desc'), limit(100)]
    : [where('partnerId', '==', ctx.uid), orderBy('updatedAt', 'desc'), limit(100)];
  const contractSnap = await getDocs(query(collection(firestore, 'partnerContracts'), ...contractConstraints));
  const contractsById = new Map<string, Record<string, unknown>>();

  for (const contractDoc of contractSnap.docs) {
    contractsById.set(contractDoc.id, (contractDoc.data() || {}) as Record<string, unknown>);
  }

  if (contractsById.size === 0) {
    return [];
  }

  const deliverableDocs: Array<{ id: string; data: Record<string, unknown> }> = [];
  if (ctx.role === 'hq') {
    const deliverableSnap = await getDocs(
      query(
        collection(firestore, 'partnerDeliverables'),
        orderBy('submittedAt', 'desc'),
        limit(120),
      ),
    );
    for (const deliverableDoc of deliverableSnap.docs) {
      const data = (deliverableDoc.data() || {}) as Record<string, unknown>;
      if (!contractsById.has(asString(data.contractId, ''))) {
        continue;
      }
      deliverableDocs.push({ id: deliverableDoc.id, data });
    }
  } else {
    const contractIds = Array.from(contractsById.keys());
    for (const chunk of chunkValues(contractIds, 10)) {
      const deliverableSnap = await getDocs(
        query(
          collection(firestore, 'partnerDeliverables'),
          where('contractId', 'in', chunk),
          limit(50),
        ),
      );
      for (const deliverableDoc of deliverableSnap.docs) {
        deliverableDocs.push({
          id: deliverableDoc.id,
          data: (deliverableDoc.data() || {}) as Record<string, unknown>,
        });
      }
    }
  }

  const records = deliverableDocs.map(({ id, data }) => {
    const contractId = asString(data.contractId, '');
    const contract = contractsById.get(contractId) || {};
    return buildRecord({
      routePath: '/partner/deliverables',
      collectionName: 'partnerDeliverables',
      id,
      raw: {
        ...data,
        contractTitle: optionLabelFromRecord(contract, contractId),
        siteId: asString(contract.siteId, asString(data.siteId, '')),
        partnerId: asString(contract.partnerId, ''),
      },
      titleKeys: ['title', 'contractTitle'],
      subtitleKeys: ['contractTitle', 'description', 'evidenceUrl'],
      statusKeys: ['status'],
      editable: ctx.role === 'hq',
      deletable: false,
    });
  });

  return sortWorkflowRecords(records);
}

async function loadCleverSchoolOptions(siteId: string | null): Promise<WorkflowFieldOption[]> {
  if (!siteId) return [];

  const callable = httpsCallable(functions, 'listCleverSchools');
  const response = await callable({ siteId });
  const payload = (response.data || {}) as Record<string, unknown>;
  const schools = Array.isArray(payload.schools) ? payload.schools : [];

  return schools
    .filter((entry): entry is Record<string, unknown> => !!entry && typeof entry === 'object' && !Array.isArray(entry))
    .map((entry) => {
      const id = asString(entry.id, '');
      if (!id) return null;
      const label = asString(entry.name, '')
        || asString(entry.schoolName, '')
        || asString(entry.displayName, '')
        || id;
      return { value: id, label };
    })
    .filter((entry): entry is WorkflowFieldOption => Boolean(entry));
}

async function loadCleverWorkflowRecords(ctx: WorkflowContext, siteId: string | null): Promise<WorkflowRecord[]> {
  if (!siteId) return [];

  const healthCallable = httpsCallable(functions, 'getIntegrationsHealth');
  const [healthResponse, identityRecords] = await Promise.all([
    healthCallable({ siteId, scope: 'site' }),
    loadCallableRows({
      routePath: ctx.routePath,
      callableName: 'listExternalIdentityLinks',
      args: { siteId },
      rowArrayField: 'links',
      collectionName: 'externalIdentityLinks',
      titleKeys: ['providerUserId', 'uid'],
      subtitleKeys: ['status', 'siteId'],
      statusKeys: ['status'],
      editable: false,
      deletable: false,
    }).catch(() => []),
  ]);

  const payload = (healthResponse.data || {}) as Record<string, unknown>;
  const connections = Array.isArray(payload.connections) ? payload.connections : [];
  const syncJobs = Array.isArray(payload.syncJobs) ? payload.syncJobs : [];

  const connectionRecords = connections
    .filter((entry): entry is Record<string, unknown> => !!entry && typeof entry === 'object' && !Array.isArray(entry))
    .filter((entry) => asString(entry.provider, '').toLowerCase() === 'clever')
    .map((entry) => {
      const id = asString(entry.id, '');
      if (!id) return null;
      return buildRecord({
        routePath: ctx.routePath,
        collectionName: 'integrationConnections',
        id,
        raw: entry,
        titleKeys: ['name', 'provider', 'id'],
        subtitleKeys: ['status', 'siteName', 'lastError'],
        statusKeys: ['status'],
        editable: true,
        deletable: false,
      });
    })
    .filter((entry): entry is WorkflowRecord => Boolean(entry));

  const syncJobRecords = syncJobs
    .filter((entry): entry is Record<string, unknown> => !!entry && typeof entry === 'object' && !Array.isArray(entry))
    .filter((entry) => asString(entry.provider, '').toLowerCase() === 'clever')
    .map((entry) => {
      const id = asString(entry.id, '');
      if (!id) return null;
      return buildRecord({
        routePath: ctx.routePath,
        collectionName: 'syncJobs',
        id,
        raw: entry,
        titleKeys: ['jobType', 'provider', 'id'],
        subtitleKeys: ['schoolId', 'siteName', 'siteId'],
        statusKeys: ['status'],
        editable: false,
        deletable: false,
      });
    })
    .filter((entry): entry is WorkflowRecord => Boolean(entry));

  const cleverIdentityRecords = identityRecords.filter((record) => record.metadata.provider?.toLowerCase() === 'clever');

  return sortWorkflowRecords([
    ...connectionRecords,
    ...syncJobRecords,
    ...cleverIdentityRecords,
  ]);
}

function ensureLiveWorkflowResult(payload: Record<string, unknown>, actionLabel: string) {
  if (payload.stub === true) {
    throw new Error(`${actionLabel} is not live in this environment yet.`);
  }
}

export async function loadWorkflowRecords(ctx: WorkflowContext): Promise<WorkflowLoadResult> {
  if (process.env.NEXT_PUBLIC_E2E_TEST_MODE === '1') {
    const { loadE2EWorkflowRecords } = await loadE2EWorkflowBackend();
    return loadE2EWorkflowRecords(ctx);
  }

  const siteId = ctx.routePath.startsWith('/site/')
    ? requireActiveSiteWorkflowContext(ctx)
    : activeSiteId(ctx.profile);

  switch (ctx.routePath) {
    case '/learner/today': {
      const records = await loadLearnerToday(ctx);
      return { records, canCreate: false, canRefresh: true, createLabel: 'Create', createConfig: null };
    }
    case '/learner/missions': {
      const missionOptions = await loadMissionOptions();
      const siteId2 = activeSiteId(ctx.profile);
      const records = applyRouteActionLabels(await queryCollectionRecords({
        routePath: ctx.routePath,
        collectionName: 'missionAttempts',
        constraints: [
          where('learnerId', '==', ctx.uid),
          orderBy('startedAt', 'desc'),
        ],
        titleKeys: ['missionTitle', 'missionId'],
        subtitleKeys: ['feedback', 'submissionUrl'],
        statusKeys: ['status'],
        editable: true,
        deletable: false,
        limitSize: 40,
      }), ctx.routePath);
      await enrichRecordsWithCapabilityTitles(records, siteId2);
      return {
        records,
        canCreate: true,
        canRefresh: true,
        createLabel: 'Start mission attempt',
        createConfig: buildCreateConfig('Start mission attempt', 'Start attempt', [
          {
            name: 'missionId',
            label: 'Mission',
            type: 'select',
            required: true,
            options: missionOptions,
          },
          {
            name: 'notes',
            label: 'Attempt notes',
            type: 'textarea',
            placeholder: 'What are you trying to accomplish in this attempt?',
          },
        ]),
      };
    }
    case '/learner/portfolio':
      return {
        records: applyRouteActionLabels(await queryCollectionRecords({
          routePath: ctx.routePath,
          collectionName: 'portfolioItems',
          constraints: [where('learnerId', '==', ctx.uid), orderBy('createdAt', 'desc')],
          titleKeys: ['title', 'name'],
          subtitleKeys: ['description', 'mediaType'],
          statusKeys: ['status'],
          editable: true,
          deletable: true,
          limitSize: 60,
        }), ctx.routePath),
        canCreate: true,
        canRefresh: true,
        createLabel: 'Add portfolio item',
        createConfig: buildCreateConfig('Add portfolio item', 'Add item', [
          {
            name: 'title',
            label: 'Title',
            type: 'text',
            required: true,
            placeholder: 'Robotics demo video',
          },
          {
            name: 'description',
            label: 'Description',
            type: 'textarea',
            placeholder: 'Describe the artifact and why it matters.',
          },
          {
            name: 'mediaType',
            label: 'Media type',
            type: 'select',
            required: true,
            defaultValue: 'link',
            options: [
              { value: 'link', label: 'Link' },
              { value: 'image', label: 'Image' },
              { value: 'document', label: 'Document' },
              { value: 'video', label: 'Video' },
            ],
          },
          {
            name: 'mediaUrl',
            label: 'Media URL',
            type: 'text',
            placeholder: 'https://...',
          },
        ]),
      };
    case '/educator/today':
      return {
        records: await queryCollectionRecords({
          routePath: ctx.routePath,
          collectionName: 'sessions',
          constraints: [where('educatorIds', 'array-contains', ctx.uid), orderBy('startDate', 'asc')],
          titleKeys: ['title', 'name'],
          subtitleKeys: ['description', 'siteId'],
          statusKeys: ['status'],
          editable: false,
          deletable: false,
          limitSize: 40,
        }),
        canCreate: false,
        canRefresh: true,
        createLabel: 'Create',
        createConfig: null,
      };
    case '/educator/attendance': {
      const [learnerOptions, sessionOptions] = await Promise.all([
        loadLearnerOptionsForActor(ctx, siteId),
        loadSessionOptionsForActor(ctx, siteId),
      ]);
      return {
        records: applyRouteActionLabels(await queryCollectionRecords({
          routePath: ctx.routePath,
          collectionName: 'attendanceRecords',
          constraints: siteId ? [where('siteId', '==', siteId), orderBy('timestamp', 'desc')] : [orderBy('timestamp', 'desc')],
          titleKeys: ['learnerName', 'learnerId'],
          subtitleKeys: ['notes', 'sessionOccurrenceId'],
          statusKeys: ['status'],
          editable: true,
          deletable: false,
          limitSize: 100,
        }), ctx.routePath),
        canCreate: true,
        canRefresh: true,
        createLabel: 'Record attendance',
        createConfig: buildCreateConfig('Record attendance', 'Save attendance', [
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
            label: 'Attendance status',
            type: 'select',
            required: true,
            defaultValue: 'present',
            options: [
              { value: 'present', label: 'Present' },
              { value: 'late', label: 'Late' },
              { value: 'absent', label: 'Absent' },
              { value: 'excused', label: 'Excused' },
            ],
          },
          {
            name: 'notes',
            label: 'Notes',
            type: 'textarea',
            placeholder: 'Optional context for this attendance update.',
          },
        ]),
      };
    }
    case '/educator/sessions':
      return {
        records: applyRouteActionLabels(await queryCollectionRecords({
          routePath: ctx.routePath,
          collectionName: 'sessions',
          constraints: siteId ? [where('siteId', '==', siteId), orderBy('startDate', 'asc')] : [orderBy('startDate', 'asc')],
          titleKeys: ['title', 'name'],
          subtitleKeys: ['description', 'roomId'],
          statusKeys: ['status'],
          editable: true,
          deletable: false,
          limitSize: 60,
        }), ctx.routePath),
        canCreate: true,
        canRefresh: true,
        createLabel: 'Create session',
        createConfig: buildCreateConfig('Create educator session', 'Create session', [
          {
            name: 'title',
            label: 'Session title',
            type: 'text',
            required: true,
          },
          {
            name: 'description',
            label: 'Description',
            type: 'textarea',
          },
          {
            name: 'startDate',
            label: 'Start time',
            type: 'datetime-local',
            required: true,
            defaultValue: toDateInputValue(new Date()),
          },
          {
            name: 'endDate',
            label: 'End time',
            type: 'datetime-local',
            required: true,
            defaultValue: toDateInputValue(new Date(Date.now() + 60 * 60 * 1000)),
          },
        ]),
      };
    case '/educator/learners':
      return {
        records: await queryCollectionRecords({
          routePath: ctx.routePath,
          collectionName: 'users',
          constraints: siteId ? [where('siteIds', 'array-contains', siteId), orderBy('displayName', 'asc')] : [orderBy('displayName', 'asc')],
          titleKeys: ['displayName', 'email', 'uid'],
          subtitleKeys: ['email', 'activeSiteId'],
          statusKeys: ['role', 'isActive'],
          editable: false,
          deletable: false,
          limitSize: 100,
        }).then((rows) => rows.filter((row) => row.status === 'learner' || row.metadata.role === 'learner')),
        canCreate: false,
        canRefresh: true,
        createLabel: 'Create',
      };
    case '/educator/missions/review': {
      const reviewRecords = applyRouteActionLabels(await queryCollectionRecords({
        routePath: ctx.routePath,
        collectionName: 'missionAttempts',
        constraints: siteId
          ? [where('siteId', '==', siteId), where('status', 'in', ['submitted', 'pending_review']), orderBy('submittedAt', 'desc')]
          : [where('status', 'in', ['submitted', 'pending_review']), orderBy('submittedAt', 'desc')],
        titleKeys: ['missionTitle', 'missionId'],
        subtitleKeys: ['learnerId', 'feedback'],
        statusKeys: ['status'],
        editable: true,
        deletable: false,
        limitSize: 100,
      }), ctx.routePath);
      await enrichRecordsWithCapabilityTitles(reviewRecords, siteId);
      return {
        records: reviewRecords,
        canCreate: false,
        canRefresh: true,
        createLabel: 'Create',
        createConfig: null,
      };
    }
    case '/educator/mission-plans':
      return {
        records: applyRouteActionLabels(await queryCollectionRecords({
          routePath: ctx.routePath,
          collectionName: 'missionPlans',
          constraints: siteId ? [where('siteId', '==', siteId), orderBy('updatedAt', 'desc')] : [orderBy('updatedAt', 'desc')],
          titleKeys: ['title', 'name', 'sessionOccurrenceId'],
          subtitleKeys: ['description', 'educatorId'],
          statusKeys: ['status'],
          editable: true,
          deletable: false,
          limitSize: 80,
        }), ctx.routePath),
        canCreate: true,
        canRefresh: true,
        createLabel: 'Create mission plan',
        createConfig: buildCreateConfig('Create mission plan', 'Create plan', [
          {
            name: 'title',
            label: 'Plan title',
            type: 'text',
            required: true,
          },
          {
            name: 'description',
            label: 'Description',
            type: 'textarea',
          },
        ]),
      };
    case '/educator/learner-supports': {
      const learnerOptions = await loadLearnerOptionsForActor(ctx, siteId);
      return {
        records: await queryCollectionRecords({
          routePath: ctx.routePath,
          collectionName: 'supportInterventions',
          constraints: siteId ? [where('siteId', '==', siteId), orderBy('createdAt', 'desc')] : [orderBy('createdAt', 'desc')],
          titleKeys: ['strategyDescription', 'learnerId'],
          subtitleKeys: ['notes', 'context'],
          statusKeys: ['outcome'],
          editable: false,
          deletable: false,
          limitSize: 80,
        }),
        canCreate: true,
        canRefresh: true,
        createLabel: 'Log support intervention',
        createConfig: buildCreateConfig('Log support intervention', 'Log intervention', [
          {
            name: 'learnerId',
            label: 'Learner',
            type: 'select',
            required: true,
            options: learnerOptions,
          },
          {
            name: 'strategyType',
            label: 'Strategy type',
            type: 'select',
            required: true,
            defaultValue: 'autonomy',
            options: [
              { value: 'autonomy', label: 'Autonomy support' },
              { value: 'competence', label: 'Competence support' },
              { value: 'relatedness', label: 'Relatedness support' },
            ],
          },
          {
            name: 'context',
            label: 'Context',
            type: 'select',
            required: true,
            defaultValue: 'individual',
            options: [
              { value: 'individual', label: 'Individual' },
              { value: 'small-group', label: 'Small group' },
              { value: 'whole-class', label: 'Whole class' },
            ],
          },
          {
            name: 'strategyDescription',
            label: 'Intervention',
            type: 'textarea',
            required: true,
            placeholder: 'Describe the support intervention.',
          },
          {
            name: 'notes',
            label: 'Notes',
            type: 'textarea',
          },
        ]),
      };
    }
    case '/educator/evidence':
      return {
        records: applyRouteActionLabels(await queryCollectionRecords({
          routePath: ctx.routePath,
          collectionName: 'evidenceRecords',
          constraints: siteId
            ? [where('siteId', '==', siteId), orderBy('createdAt', 'desc')]
            : [orderBy('createdAt', 'desc')],
          titleKeys: ['capabilityId', 'learnerId'],
          subtitleKeys: ['phaseKey', 'notes'],
          statusKeys: ['status'],
          editable: false,
          deletable: false,
          limitSize: 50,
        }), ctx.routePath),
        canCreate: false,
        canRefresh: true,
        createLabel: 'Create',
        createConfig: null,
      };
    case '/educator/integrations':
      return {
        records: await loadCallableRows({
          routePath: ctx.routePath,
          callableName: 'getIntegrationsHealth',
          args: { siteId: siteId || undefined, scope: 'educator' },
          rowArrayField: 'connections',
          collectionName: 'integrationConnections',
          titleKeys: ['provider', 'name'],
          subtitleKeys: ['status', 'siteId'],
          statusKeys: ['status'],
        }),
        canCreate: false,
        canRefresh: true,
        createLabel: 'Create',
        createConfig: null,
      };
    case '/parent/summary':
      return { records: await loadParentSummary(ctx), canCreate: false, canRefresh: true, createLabel: 'Create', createConfig: null };
    case '/parent/billing':
      return { records: await loadParentBillingRecords(ctx), canCreate: false, canRefresh: true, createLabel: 'Create', createConfig: null };
    case '/site/billing':
      {
        const siteOptions = await loadSiteSelectorOptions();
        return {
          records: await loadSiteBillingRecords(ctx),
          canCreate: true,
          canRefresh: true,
          createLabel: 'Request plan change',
          createConfig: buildCreateConfig('Request billing plan change', 'Submit request', [
            {
              name: 'siteId',
              label: 'Site',
              type: 'select',
              options: siteOptions,
              defaultValue: activeSiteId(ctx.profile) || siteOptions[0]?.value || '',
            },
            {
              name: 'reason',
              label: 'Reason',
              type: 'textarea',
              required: true,
              placeholder: 'Describe the requested billing plan change.',
            },
          ]),
        };
      }
    case '/parent/schedule':
      return {
        records: await loadParentSchedule(ctx),
        canCreate: false,
        canRefresh: true,
        createLabel: 'Create',
        createConfig: null,
      };
    case '/parent/portfolio': {
      return {
        records: await loadParentPortfolioWorkflowRecords(ctx),
        canCreate: false,
        canRefresh: true,
        createLabel: 'Create',
        createConfig: null,
      };
    }
    case '/site/checkin': {
      const learnerOptions = await loadLearnerOptionsForActor(ctx, siteId);
      return {
        records: applyRouteActionLabels(await queryCollectionRecords({
          routePath: ctx.routePath,
          collectionName: 'checkins',
          constraints: siteId ? [where('siteId', '==', siteId), orderBy('timestamp', 'desc')] : [orderBy('timestamp', 'desc')],
          titleKeys: ['learnerName', 'learnerId'],
          subtitleKeys: ['type', 'notes'],
          statusKeys: ['status'],
          editable: false,
          deletable: false,
          limitSize: 100,
        }), ctx.routePath),
        canCreate: true,
        canRefresh: true,
        createLabel: 'Add check-in event',
        createConfig: buildCreateConfig('Add check-in event', 'Save check-in', [
          {
            name: 'learnerId',
            label: 'Learner',
            type: 'select',
            required: true,
            options: learnerOptions,
          },
          {
            name: 'type',
            label: 'Event type',
            type: 'select',
            required: true,
            defaultValue: 'checkin',
            options: [
              { value: 'checkin', label: 'Check-in' },
              { value: 'late', label: 'Late arrival' },
              { value: 'checkout', label: 'Check-out' },
            ],
          },
          {
            name: 'notes',
            label: 'Notes',
            type: 'textarea',
          },
        ]),
      };
    }
    case '/site/provisioning': {
      const [learnerOptions, parentOptions, cohortLaunchRecords] = await Promise.all([
        loadSiteUserOptions({ siteId, roles: ['learner'], limitSize: 160 }),
        loadSiteUserOptions({ siteId, roles: ['parent'], limitSize: 160 }),
        loadCallableRows({
          routePath: ctx.routePath,
          callableName: 'listCohortLaunches',
          args: { siteId: siteId || undefined, limit: 80 },
          rowArrayField: 'launches',
          collectionName: 'cohortLaunches',
          titleKeys: ['cohortName', 'title', 'id'],
          subtitleKeys: ['scheduleLabel', 'curriculumTerm', 'programFormat'],
          statusKeys: ['status', 'rosterStatus'],
          editable: true,
          deletable: false,
        }).catch(() => []),
      ]);
      const guardianLinkRecords = await queryCollectionRecords({
        routePath: ctx.routePath,
        collectionName: 'guardianLinks',
        constraints: siteId ? [where('siteId', '==', siteId), orderBy('createdAt', 'desc')] : [orderBy('createdAt', 'desc')],
        titleKeys: ['parentId', 'learnerId'],
        subtitleKeys: ['relationship', 'status'],
        statusKeys: ['status'],
        editable: true,
        deletable: true,
        limitSize: 100,
      });

      return {
        records: applyRouteActionLabels(sortWorkflowRecords([
          ...guardianLinkRecords,
          ...cohortLaunchRecords,
        ]), ctx.routePath),
        canCreate: true,
        canRefresh: true,
        createLabel: 'Run provisioning action',
        createConfig: buildCreateConfig('Provision learner, parent, or link', 'Run provisioning', [
          {
            name: 'action',
            label: 'Provisioning action',
            type: 'select',
            required: true,
            defaultValue: 'guardianLink',
            options: [
              { value: 'learner', label: 'Create learner' },
              { value: 'parent', label: 'Create parent' },
              { value: 'guardianLink', label: 'Create guardian link' },
              { value: 'cohortLaunch', label: 'Create cohort launch' },
            ],
          },
          {
            name: 'displayName',
            label: 'Display name',
            type: 'text',
            placeholder: 'Required for learner or parent creation',
          },
          {
            name: 'email',
            label: 'Email',
            type: 'email',
            placeholder: 'Required for learner or parent creation',
          },
          {
            name: 'phone',
            label: 'Phone',
            type: 'tel',
            placeholder: 'Optional for parent creation',
          },
          {
            name: 'gradeLevel',
            label: 'Grade level',
            type: 'number',
            placeholder: 'Optional for learner creation',
          },
          {
            name: 'notes',
            label: 'Notes',
            type: 'textarea',
          },
          {
            name: 'parentId',
            label: 'Parent',
            type: 'select',
            options: parentOptions,
          },
          {
            name: 'learnerId',
            label: 'Learner',
            type: 'select',
            options: learnerOptions,
          },
          {
            name: 'relationship',
            label: 'Relationship',
            type: 'select',
            defaultValue: 'guardian',
            options: [
              { value: 'guardian', label: 'Guardian' },
              { value: 'parent', label: 'Parent' },
              { value: 'caregiver', label: 'Caregiver' },
            ],
          },
          {
            name: 'isPrimary',
            label: 'Primary guardian',
            type: 'checkbox',
            defaultValue: false,
          },
          {
            name: 'cohortName',
            label: 'Cohort name',
            type: 'text',
            placeholder: 'Required for cohort launch',
          },
          {
            name: 'ageBand',
            label: 'Age band',
            type: 'text',
            placeholder: 'K-5, middle school, mixed...',
          },
          {
            name: 'scheduleLabel',
            label: 'Schedule label',
            type: 'text',
            placeholder: 'Mon/Wed 4:00 PM',
          },
          {
            name: 'programFormat',
            label: 'Program format',
            type: 'select',
            defaultValue: 'gold',
            options: [
              { value: 'gold', label: 'Gold' },
              { value: 'silver', label: 'Silver' },
              { value: 'pilot', label: 'Pilot' },
            ],
          },
          {
            name: 'curriculumTerm',
            label: 'Curriculum term',
            type: 'text',
            placeholder: 'Term 1',
          },
          {
            name: 'rosterStatus',
            label: 'Roster status',
            type: 'select',
            defaultValue: 'draft',
            options: [
              { value: 'draft', label: 'Draft' },
              { value: 'ready', label: 'Ready' },
              { value: 'active', label: 'Active' },
            ],
          },
          {
            name: 'parentCommunicationStatus',
            label: 'Parent comms',
            type: 'select',
            defaultValue: 'pending',
            options: [
              { value: 'pending', label: 'Pending' },
              { value: 'sent', label: 'Sent' },
              { value: 'confirmed', label: 'Confirmed' },
            ],
          },
          {
            name: 'baselineSurveyStatus',
            label: 'Baseline survey',
            type: 'select',
            defaultValue: 'pending',
            options: [
              { value: 'pending', label: 'Pending' },
              { value: 'ready', label: 'Ready' },
              { value: 'completed', label: 'Completed' },
            ],
          },
          {
            name: 'kickoffStatus',
            label: 'Kickoff status',
            type: 'select',
            defaultValue: 'pending',
            options: [
              { value: 'pending', label: 'Pending' },
              { value: 'scheduled', label: 'Scheduled' },
              { value: 'completed', label: 'Completed' },
            ],
          },
          {
            name: 'learnerCount',
            label: 'Learner count',
            type: 'number',
            placeholder: 'Optional cohort size',
          },
        ]),
      };
    }
    case '/site/dashboard':
      {
        const [siteRecords, kpiPackRecords] = await Promise.all([
          queryCollectionRecords({
            routePath: ctx.routePath,
            collectionName: 'sites',
            constraints: siteId ? [where(documentId(), '==', siteId)] : [],
            titleKeys: ['name'],
            subtitleKeys: ['location'],
            statusKeys: ['status'],
            editable: false,
            deletable: false,
            limitSize: 1,
          }),
          loadCallableRows({
            routePath: ctx.routePath,
            callableName: 'listKpiPacks',
            args: { siteId: siteId || undefined, limit: 20 },
            rowArrayField: 'packs',
            collectionName: 'kpiPacks',
            titleKeys: ['title', 'siteId', 'id'],
            subtitleKeys: ['recommendation', 'period'],
            statusKeys: ['status', 'portfolioQualityGrade'],
            metadataBuilder: buildKpiPackMetadata,
            editable: false,
            deletable: false,
          }).catch(() => []),
        ]);
        return {
          records: sortWorkflowRecords([...siteRecords, ...kpiPackRecords]),
          canCreate: true,
          canRefresh: true,
          createLabel: 'Generate KPI pack',
          guidanceText: null,
          createConfig: buildCreateConfig('Generate KPI pack', 'Generate pack', [
            {
              name: 'period',
              label: 'Period',
              type: 'select',
              required: true,
              defaultValue: 'month',
              options: [
                { value: 'month', label: 'Month' },
                { value: 'quarter', label: 'Quarter' },
                { value: 'year', label: 'Year' },
              ],
            },
          ]),
        };
      }
    case '/site/sessions':
      return {
        records: applyRouteActionLabels(await queryCollectionRecords({
          routePath: ctx.routePath,
          collectionName: 'sessions',
          constraints: siteId ? [where('siteId', '==', siteId), orderBy('startDate', 'asc')] : [orderBy('startDate', 'asc')],
          titleKeys: ['title'],
          subtitleKeys: ['description', 'roomId'],
          statusKeys: ['status'],
          editable: true,
          deletable: false,
          limitSize: 80,
        }), ctx.routePath),
        canCreate: true,
        canRefresh: true,
        createLabel: 'Create site session',
        createConfig: buildCreateConfig('Create site session', 'Create session', [
          {
            name: 'title',
            label: 'Session title',
            type: 'text',
            required: true,
          },
          {
            name: 'description',
            label: 'Description',
            type: 'textarea',
          },
          {
            name: 'startDate',
            label: 'Start time',
            type: 'datetime-local',
            required: true,
            defaultValue: toDateInputValue(new Date()),
          },
          {
            name: 'endDate',
            label: 'End time',
            type: 'datetime-local',
            required: true,
            defaultValue: toDateInputValue(new Date(Date.now() + 60 * 60 * 1000)),
          },
        ]),
      };
    case '/site/ops':
      return {
        records: applyRouteActionLabels(await queryCollectionRecords({
          routePath: ctx.routePath,
          collectionName: 'siteOpsEvents',
          constraints: siteId ? [where('siteId', '==', siteId), orderBy('createdAt', 'desc')] : [orderBy('createdAt', 'desc')],
          titleKeys: ['title', 'eventType'],
          subtitleKeys: ['details', 'description'],
          statusKeys: ['status'],
          editable: true,
          deletable: false,
          limitSize: 100,
        }), ctx.routePath),
        canCreate: true,
        canRefresh: true,
        createLabel: 'Log ops event',
        createConfig: buildCreateConfig('Log ops event', 'Create event', [
          {
            name: 'eventType',
            label: 'Event type',
            type: 'text',
            required: true,
            placeholder: 'staffing-gap',
          },
          {
            name: 'details',
            label: 'Details',
            type: 'textarea',
            required: true,
          },
        ]),
      };
    case '/site/incidents':
      return {
        records: applyRouteActionLabels(await loadCallableRows({
          routePath: ctx.routePath,
          callableName: 'listSafetyIncidents',
          args: { siteId: siteId || undefined },
          rowArrayField: 'incidents',
          collectionName: 'incidents',
          titleKeys: ['title', 'type'],
          subtitleKeys: ['summary', 'location', 'siteId'],
          statusKeys: ['status', 'severity', 'investigationStatus'],
          editable: true,
        }), ctx.routePath),
        canCreate: true,
        canRefresh: true,
        createLabel: 'Report incident',
        createConfig: buildCreateConfig('Report incident', 'Create incident', [
          {
            name: 'title',
            label: 'Incident title',
            type: 'text',
            required: true,
          },
          {
            name: 'summary',
            label: 'Summary',
            type: 'textarea',
            required: true,
          },
          {
            name: 'incidentType',
            label: 'Incident type',
            type: 'text',
            placeholder: 'safeguarding, medical, behavior...',
          },
          {
            name: 'severity',
            label: 'Severity',
            type: 'select',
            defaultValue: 'medium',
            options: [
              { value: 'low', label: 'Low' },
              { value: 'medium', label: 'Medium' },
              { value: 'high', label: 'High' },
              { value: 'critical', label: 'Critical' },
            ],
          },
          {
            name: 'happenedAt',
            label: 'Date and time',
            type: 'datetime-local',
            defaultValue: toDateInputValue(new Date()),
          },
          {
            name: 'location',
            label: 'Location',
            type: 'text',
          },
          {
            name: 'involvedNames',
            label: 'People involved',
            type: 'text',
            placeholder: 'Use staff-safe identifiers only',
          },
          {
            name: 'immediateAction',
            label: 'Immediate action',
            type: 'textarea',
          },
          {
            name: 'correctiveAction',
            label: 'Corrective action',
            type: 'textarea',
          },
        ]),
      };
    case '/site/identity':
      {
        const records = await loadCallableRows({
          routePath: ctx.routePath,
          callableName: 'listExternalIdentityLinks',
          args: { siteId: siteId || undefined },
          rowArrayField: 'links',
          collectionName: 'externalIdentityLinks',
          titleKeys: ['providerUserId', 'uid'],
          subtitleKeys: ['provider', 'siteId'],
          statusKeys: ['status'],
          editable: true,
        });
        return {
          records: applyRouteActionLabels(
            records.map((record) => ({
              ...record,
              canEdit: record.status !== 'resolved',
            })),
            ctx.routePath,
          ),
          canCreate: false,
          canRefresh: true,
          createLabel: 'Create',
          createConfig: null,
        };
      }
    case '/site/clever': {
      const cleverRecords = await loadCleverWorkflowRecords(ctx, siteId);
      const connectionRecord = cleverRecords.find((record) => record.collectionName === 'integrationConnections');
      const schoolOptions = connectionRecord && connectionRecord.status === 'active'
        ? await loadCleverSchoolOptions(siteId).catch(() => [])
        : [];
      const canQueueSync = connectionRecord?.status === 'active' && schoolOptions.length > 0;

      return {
        records: applyRouteActionLabels(cleverRecords, ctx.routePath),
        canCreate: true,
        canRefresh: true,
        createLabel: canQueueSync ? 'Queue Clever sync' : 'Connect Clever',
        createConfig: canQueueSync
          ? buildCreateConfig('Queue Clever roster sync', 'Queue sync', [
              {
                name: 'schoolId',
                label: 'School',
                type: 'select',
                required: true,
                defaultValue: schoolOptions[0]?.value || '',
                options: schoolOptions,
              },
              {
                name: 'mode',
                label: 'Mode',
                type: 'select',
                required: true,
                defaultValue: 'preview',
                options: [
                  { value: 'preview', label: 'Preview sync' },
                  { value: 'apply', label: 'Apply sync' },
                ],
              },
            ])
          : buildCreateConfig('Connect Clever', 'Start Clever connect', []),
      };
    }
    case '/site/integrations-health':
      return {
        records: await loadCallableRows({
          routePath: ctx.routePath,
          callableName: 'getIntegrationsHealth',
          args: { siteId: siteId || undefined, scope: 'site' },
          rowArrayField: 'syncJobs',
          collectionName: 'syncJobs',
          titleKeys: ['jobType', 'provider', 'id'],
          subtitleKeys: ['status', 'siteId'],
          statusKeys: ['status'],
        }),
        canCreate: true,
        canRefresh: true,
        createLabel: 'Trigger sync',
        createConfig: buildCreateConfig('Trigger integration sync', 'Queue sync', [
          {
            name: 'provider',
            label: 'Provider',
            type: 'select',
            required: true,
            defaultValue: 'google-classroom',
            options: [
              { value: 'google-classroom', label: 'Google Classroom' },
              { value: 'lti_1p3', label: 'LTI 1.3 / Grade Passback' },
              { value: 'google-workspace', label: 'Google Workspace' },
              { value: 'canvas', label: 'Canvas' },
            ],
          },
        ]),
      };
    case '/partner/listings':
      {
        const listingConstraints = ctx.role === 'hq'
          ? [orderBy('updatedAt', 'desc')]
          : [where('partnerId', '==', ctx.uid), orderBy('updatedAt', 'desc')];
        const [records, partnerOptions] = await Promise.all([
          queryCollectionRecords({
            routePath: ctx.routePath,
            collectionName: 'marketplaceListings',
            constraints: listingConstraints,
            titleKeys: ['title', 'name'],
            subtitleKeys: ['description', 'category'],
            statusKeys: ['status'],
            editable: true,
            deletable: false,
            limitSize: 100,
          }),
          ctx.role === 'hq'
            ? loadSiteUserOptions({ siteId: null, roles: ['partner'], limitSize: 160 })
            : Promise.resolve([]),
        ]);
        return {
        records: applyRouteActionLabels(records, ctx.routePath),
        canCreate: true,
        canRefresh: true,
        createLabel: 'Create listing',
        createConfig: buildCreateConfig('Create listing', 'Create listing', [
          ...(ctx.role === 'hq'
            ? [{
                name: 'partnerId',
                label: 'Partner',
                type: 'select' as const,
                options: partnerOptions,
                helperText: 'Required when creating listings from HQ.',
              }]
            : []),
          {
            name: 'title',
            label: 'Listing title',
            type: 'text',
            required: true,
          },
          {
            name: 'description',
            label: 'Description',
            type: 'textarea',
            required: true,
          },
          {
            name: 'category',
            label: 'Category',
            type: 'text',
            placeholder: 'STEM, Arts, Leadership...',
          },
        ]),
      };
      }
    case '/partner/contracts':
      {
        const contractConstraints = ctx.role === 'hq'
          ? [orderBy('updatedAt', 'desc')]
          : [where('partnerId', '==', ctx.uid), orderBy('updatedAt', 'desc')];
        const [contractRecords, launchRecords, partnerOptions] = await Promise.all([
          queryCollectionRecords({
            routePath: ctx.routePath,
            collectionName: 'partnerContracts',
            constraints: contractConstraints,
            titleKeys: ['title', 'contractNumber', 'name'],
            subtitleKeys: ['summary', 'siteId'],
            statusKeys: ['status'],
            editable: true,
            deletable: false,
            limitSize: 100,
          }),
          loadCallableRows({
            routePath: ctx.routePath,
            callableName: 'listPartnerLaunches',
            args: { limit: 80 },
            rowArrayField: 'launches',
            collectionName: 'partnerLaunches',
            titleKeys: ['partnerName', 'title', 'id'],
            subtitleKeys: ['region', 'siteId', 'locale'],
            statusKeys: ['status', 'contractStatus'],
            editable: true,
            deletable: false,
          }).catch(() => []),
          ctx.role === 'hq'
            ? loadSiteUserOptions({ siteId: null, roles: ['partner'], limitSize: 160 })
            : Promise.resolve([]),
        ]);
        return {
        records: applyRouteActionLabels(sortWorkflowRecords([
          ...contractRecords,
          ...launchRecords,
        ]), ctx.routePath),
        canCreate: true,
        canRefresh: true,
        createLabel: 'Create workflow',
        createConfig: buildCreateConfig('Create contract or partner launch', 'Save workflow', [
          {
            name: 'action',
            label: 'Workflow',
            type: 'select',
            required: true,
            defaultValue: 'contract',
            options: [
              { value: 'contract', label: 'Contract' },
              { value: 'partnerLaunch', label: 'Partner launch' },
            ],
          },
          ...(ctx.role === 'hq'
            ? [{
                name: 'partnerId',
                label: 'Partner',
                type: 'select' as const,
                options: partnerOptions,
                helperText: 'Required when creating partner workflows from HQ.',
              }]
            : []),
          {
            name: 'title',
            label: 'Contract title',
            type: 'text',
            placeholder: 'Required for contract creation',
          },
          {
            name: 'summary',
            label: 'Summary',
            type: 'textarea',
            placeholder: 'Required for contract creation',
          },
          {
            name: 'siteId',
            label: 'Site ID',
            type: 'text',
            placeholder: 'Optional site reference',
          },
          {
            name: 'partnerName',
            label: 'Partner name',
            type: 'text',
            placeholder: 'Required for partner launch',
          },
          {
            name: 'region',
            label: 'Region',
            type: 'text',
            placeholder: 'Required for partner launch',
          },
          {
            name: 'locale',
            label: 'Locale',
            type: 'select',
            defaultValue: 'en',
            options: [
              { value: 'en', label: 'English' },
              { value: 'zh-CN', label: 'Chinese (Simplified)' },
              { value: 'zh-TW', label: 'Chinese (Traditional)' },
              { value: 'th', label: 'Thai' },
            ],
          },
          {
            name: 'pilotCohortCount',
            label: 'Pilot cohort count',
            type: 'number',
          },
          {
            name: 'dueDiligenceStatus',
            label: 'Due diligence',
            type: 'select',
            defaultValue: 'pending',
            options: [
              { value: 'pending', label: 'Pending' },
              { value: 'in_review', label: 'In review' },
              { value: 'complete', label: 'Complete' },
            ],
          },
          {
            name: 'trainerOfTrainersStatus',
            label: 'Trainer-of-trainers',
            type: 'select',
            defaultValue: 'pending',
            options: [
              { value: 'pending', label: 'Pending' },
              { value: 'scheduled', label: 'Scheduled' },
              { value: 'completed', label: 'Completed' },
            ],
          },
          {
            name: 'review90DayStatus',
            label: '90-day review',
            type: 'select',
            defaultValue: 'pending',
            options: [
              { value: 'pending', label: 'Pending' },
              { value: 'scheduled', label: 'Scheduled' },
              { value: 'completed', label: 'Completed' },
            ],
          },
          {
            name: 'notes',
            label: 'Launch notes',
            type: 'textarea',
          },
        ]),
        };
      }
    case '/partner/deliverables': {
      const contractOptions = ctx.role === 'partner'
        ? await loadPartnerContractOptionsForActor(ctx)
        : [];
      return {
        records: applyRouteActionLabels(await loadPartnerDeliverableRecords(ctx), ctx.routePath),
        canCreate: ctx.role === 'partner' && contractOptions.length > 0,
        canRefresh: true,
        createLabel: 'Submit deliverable',
        createConfig: ctx.role === 'partner' && contractOptions.length > 0
          ? buildCreateConfig('Submit deliverable', 'Submit deliverable', [
              {
                name: 'contractId',
                label: 'Contract',
                type: 'select',
                required: true,
                defaultValue: contractOptions[0]?.value || '',
                options: contractOptions,
              },
              {
                name: 'title',
                label: 'Deliverable title',
                type: 'text',
                required: true,
              },
              {
                name: 'description',
                label: 'Description',
                type: 'textarea',
              },
              {
                name: 'evidenceUrl',
                label: 'Evidence URL',
                type: 'text',
                helperText: 'Optional HTTPS link to the submitted artifact.',
              },
            ])
          : null,
      };
    }
    case '/partner/integrations': {
      const constraints = ctx.role === 'hq'
        ? [orderBy('updatedAt', 'desc')]
        : [where('ownerUserId', '==', ctx.uid), orderBy('createdAt', 'desc')];
      return {
        records: await queryCollectionRecords({
          routePath: ctx.routePath,
          collectionName: 'integrationConnections',
          constraints,
          titleKeys: ['provider', 'id'],
          subtitleKeys: ['lastError', 'tokenRef', 'ownerUserId'],
          statusKeys: ['status'],
          editable: false,
          deletable: false,
          limitSize: 100,
        }),
        canCreate: false,
        canRefresh: true,
        createLabel: 'Create',
        createConfig: null,
      };
    }
    case '/partner/payouts':
      return {
        records: await loadCallableRows({
          routePath: ctx.routePath,
          callableName: 'listPartnerPayouts',
          args: {},
          rowArrayField: 'payouts',
          collectionName: 'payouts',
          titleKeys: ['id', 'periodLabel'],
          subtitleKeys: ['currency', 'partnerId'],
          statusKeys: ['status'],
        }),
        canCreate: false,
        canRefresh: true,
        createLabel: 'Create',
        createConfig: null,
      };
    case '/hq/user-admin':
      return {
        records: applyRouteActionLabels(await loadCallableRows({
          routePath: ctx.routePath,
          callableName: 'listUsers',
          args: { limit: 100 },
          rowArrayField: 'users',
          collectionName: 'users',
          titleKeys: ['displayName', 'email', 'uid'],
          subtitleKeys: ['email', 'activeSiteId'],
          statusKeys: ['role'],
          editable: true,
        }), ctx.routePath),
        canCreate: false,
        canRefresh: true,
        createLabel: 'Create',
        createConfig: null,
      };
    case '/hq/role-switcher':
      return {
        records: await loadHqRoleSwitcherRecords(),
        canCreate: false,
        canRefresh: true,
        createLabel: 'Create',
        createConfig: null,
      };
    case '/hq/sites':
      return {
        records: applyRouteActionLabels(await queryCollectionRecords({
          routePath: ctx.routePath,
          collectionName: 'sites',
          constraints: [orderBy('name', 'asc')],
          titleKeys: ['name'],
          subtitleKeys: ['location', 'id'],
          statusKeys: ['status'],
          editable: true,
          deletable: false,
          limitSize: 200,
        }), ctx.routePath),
        canCreate: true,
        canRefresh: true,
        createLabel: 'Create site',
        createConfig: buildCreateConfig('Create site', 'Create site', [
          {
            name: 'name',
            label: 'Site name',
            type: 'text',
            required: true,
          },
          {
            name: 'location',
            label: 'Location',
            type: 'text',
            required: true,
          },
        ]),
      };
    case '/hq/analytics':
      {
        const siteOptions = await loadSiteSelectorOptions();
        return {
          records: await loadHqAnalyticsRecords(ctx),
          canCreate: true,
          canRefresh: true,
          createLabel: 'Run analytics operation',
          guidanceText: 'Repair runs marked completed changed at least one stored document. Runs marked no-op executed successfully but verified zero document updates for the selected scope or time window.',
          createConfig: buildCreateConfig('Run analytics operation', 'Run operation', [
            {
              name: 'operation',
              label: 'Operation',
              type: 'select',
              required: true,
              defaultValue: 'generateKpiPack',
              helperText: 'Generate a fresh KPI pack or backfill historical analytics documents with the new voice reliability fields.',
              options: [
                { value: 'generateKpiPack', label: 'Generate KPI pack' },
                { value: 'backfillTelemetryAggregates', label: 'Backfill telemetry aggregates' },
                { value: 'backfillKpiPackVoiceReliability', label: 'Backfill KPI voice reliability' },
              ],
            },
            {
              name: 'siteId',
              label: 'Site',
              type: 'select',
              options: siteOptions,
              defaultValue: activeSiteId(ctx.profile) || siteOptions[0]?.value || '',
              helperText: 'Required for KPI generation. Leave empty to run an HQ-wide backfill across multiple sites.',
            },
            {
              name: 'period',
              label: 'Period',
              type: 'select',
              defaultValue: 'month',
              helperText: 'Used for KPI generation and optional KPI backfill filtering.',
              options: [
                { value: 'month', label: 'Month' },
                { value: 'quarter', label: 'Quarter' },
                { value: 'year', label: 'Year' },
              ],
            },
            {
              name: 'aggregationType',
              label: 'Aggregate period',
              type: 'select',
              defaultValue: 'daily',
              helperText: 'Used only when backfilling telemetry aggregate documents.',
              options: [
                { value: 'daily', label: 'Daily' },
                { value: 'weekly', label: 'Weekly' },
              ],
            },
            {
              name: 'startDate',
              label: 'Start date',
              type: 'datetime-local',
              helperText: 'Optional lower bound for the historical backfill window.',
            },
            {
              name: 'endDate',
              label: 'End date',
              type: 'datetime-local',
              helperText: 'Optional upper bound for the historical backfill window.',
            },
            {
              name: 'limit',
              label: 'Batch limit',
              type: 'number',
              defaultValue: '40',
              helperText: 'Maximum documents to process in this run. Keep batches small for controlled rollout.',
            },
            {
              name: 'force',
              label: 'Overwrite existing KPI voice reliability',
              type: 'checkbox',
              defaultValue: false,
              helperText: 'Use only when you intentionally want to recalculate KPI voice reliability even if the field already exists.',
            },
          ]),
        };
      }
    case '/hq/billing':
      {
        const [siteOptions, parentOptions, learnerOptions] = await Promise.all([
          loadSiteSelectorOptions(),
          loadSiteUserOptions({ siteId: null, roles: ['parent'], limitSize: 160 }),
          loadSiteUserOptions({ siteId: null, roles: ['learner'], limitSize: 160 }),
        ]);
        return {
          records: await loadHqBillingRecords(),
          canCreate: true,
          canRefresh: true,
          createLabel: 'Create invoice',
          createConfig: buildCreateConfig('Create HQ invoice', 'Create invoice', [
            {
              name: 'siteId',
              label: 'Site',
              type: 'select',
              options: siteOptions,
            },
            {
              name: 'parentId',
              label: 'Parent',
              type: 'select',
              required: true,
              options: parentOptions,
            },
            {
              name: 'learnerId',
              label: 'Learner',
              type: 'select',
              required: true,
              options: learnerOptions,
            },
            {
              name: 'amount',
              label: 'Amount',
              type: 'number',
              required: true,
              placeholder: '0',
            },
            {
              name: 'currency',
              label: 'Currency',
              type: 'text',
              defaultValue: 'USD',
            },
            {
              name: 'description',
              label: 'Description',
              type: 'textarea',
            },
          ]),
        };
      }
    case '/hq/approvals':
      return {
        records: applyRouteActionLabels(await loadCallableRows({
          routePath: ctx.routePath,
          callableName: 'listWorkflowApprovals',
          args: { limit: 120 },
          rowArrayField: 'approvals',
          collectionName: 'approvals',
          titleKeys: ['title', 'sourceCollection', 'id'],
          subtitleKeys: ['summary', 'siteId'],
          statusKeys: ['status'],
          editable: true,
        }), ctx.routePath),
        canCreate: false,
        canRefresh: true,
        createLabel: 'Create',
        createConfig: null,
      };
    case '/hq/audit':
      {
        const [siteOptions, kpiPackOptions, auditLogRecords, redTeamRecords] = await Promise.all([
          loadSiteSelectorOptions(),
          loadKpiPackOptions(),
          loadCallableRows({
            routePath: ctx.routePath,
            callableName: 'listAuditLogs',
            args: { limit: 120 },
            rowArrayField: 'logs',
            collectionName: 'auditLogs',
            titleKeys: ['action', 'entityType', 'id'],
            subtitleKeys: ['entityId', 'actorId'],
            statusKeys: ['actorRole'],
          }),
          loadCallableRows({
            routePath: ctx.routePath,
            callableName: 'listRedTeamReviews',
            args: { limit: 60 },
            rowArrayField: 'reviews',
            collectionName: 'redTeamReviews',
            titleKeys: ['title', 'siteId', 'id'],
            subtitleKeys: ['recommendations', 'nextAction'],
            statusKeys: ['decision', 'partnerStatus'],
            editable: false,
            deletable: false,
          }).catch(() => []),
        ]);
        return {
          records: sortWorkflowRecords([...auditLogRecords, ...redTeamRecords]),
          canCreate: true,
          canRefresh: true,
          createLabel: 'Create red team review',
          createConfig: buildCreateConfig('Create red team review', 'Save review', [
            {
              name: 'title',
              label: 'Review title',
              type: 'text',
              required: true,
            },
            {
              name: 'siteId',
              label: 'Site',
              type: 'select',
              options: siteOptions,
              defaultValue: activeSiteId(ctx.profile) || siteOptions[0]?.value || '',
            },
            {
              name: 'kpiPackId',
              label: 'KPI pack',
              type: 'select',
              options: kpiPackOptions,
            },
            {
              name: 'period',
              label: 'Period',
              type: 'select',
              defaultValue: 'term',
              options: [
                { value: 'term', label: 'Term' },
                { value: 'quarter', label: 'Quarter' },
                { value: 'year', label: 'Year' },
              ],
            },
            {
              name: 'decision',
              label: 'Decision',
              type: 'select',
              defaultValue: 'continue',
              options: [
                { value: 'continue', label: 'Continue' },
                { value: 'stabilize', label: 'Stabilize' },
                { value: 'intervene', label: 'Intervene' },
              ],
            },
            {
              name: 'partnerStatus',
              label: 'Partner status',
              type: 'select',
              defaultValue: 'active',
              options: [
                { value: 'active', label: 'Active' },
                { value: 'watch', label: 'Watch' },
                { value: 'hold', label: 'Hold' },
              ],
            },
            {
              name: 'recommendations',
              label: 'Recommendations',
              type: 'textarea',
            },
            {
              name: 'nextAction',
              label: 'Next action',
              type: 'textarea',
            },
          ]),
        };
      }
    case '/hq/safety':
      return {
        records: applyRouteActionLabels(await loadCallableRows({
          routePath: ctx.routePath,
          callableName: 'listSafetyIncidents',
          args: { limit: 120 },
          rowArrayField: 'incidents',
          collectionName: 'incidents',
          titleKeys: ['title', 'type'],
          subtitleKeys: ['summary', 'siteId'],
          statusKeys: ['status', 'severity'],
          editable: true,
        }), ctx.routePath),
        canCreate: false,
        canRefresh: true,
        createLabel: 'Create',
        createConfig: null,
      };
    case '/hq/integrations-health':
      return {
        records: await loadCallableRows({
          routePath: ctx.routePath,
          callableName: 'getIntegrationsHealth',
          args: { scope: 'hq' },
          rowArrayField: 'syncJobs',
          collectionName: 'syncJobs',
          titleKeys: ['jobType', 'provider'],
          subtitleKeys: ['siteId', 'details'],
          statusKeys: ['status'],
        }),
        canCreate: true,
        canRefresh: true,
        createLabel: 'Trigger global sync',
        createConfig: buildCreateConfig('Trigger global sync', 'Queue sync', [
          {
            name: 'provider',
            label: 'Provider',
            type: 'select',
            required: true,
            defaultValue: 'google-classroom',
            options: [
              { value: 'google-classroom', label: 'Google Classroom' },
              { value: 'lti_1p3', label: 'LTI 1.3 / Grade Passback' },
              { value: 'google-workspace', label: 'Google Workspace' },
              { value: 'canvas', label: 'Canvas' },
            ],
          },
        ]),
      };
    case '/hq/curriculum':
      {
        const siteOptions = await loadSiteSelectorOptions();
        const [missionRecords, trainingCycleRecords] = await Promise.all([
          queryCollectionRecords({
            routePath: ctx.routePath,
            collectionName: 'missions',
            constraints: [orderBy('title', 'asc')],
            titleKeys: ['title', 'name'],
            subtitleKeys: ['description', 'difficulty'],
            statusKeys: ['status', 'isActive'],
            editable: true,
            deletable: false,
            limitSize: 150,
          }),
          loadCallableRows({
            routePath: ctx.routePath,
            callableName: 'listTrainingCycles',
            args: { limit: 80 },
            rowArrayField: 'cycles',
            collectionName: 'trainingCycles',
            titleKeys: ['title', 'trainingType', 'id'],
            subtitleKeys: ['audience', 'termLabel', 'siteId'],
            statusKeys: ['status'],
            editable: true,
            deletable: false,
          }).catch(() => []),
        ]);
        return {
          records: applyRouteActionLabels(sortWorkflowRecords([
            ...missionRecords,
            ...trainingCycleRecords,
          ]), ctx.routePath),
          canCreate: true,
          canRefresh: true,
          createLabel: 'Create curriculum workflow',
          createConfig: buildCreateConfig('Create curriculum unit or training cycle', 'Save workflow', [
            {
              name: 'action',
              label: 'Workflow',
              type: 'select',
              required: true,
              defaultValue: 'mission',
              options: [
                { value: 'mission', label: 'Mission' },
                { value: 'trainingCycle', label: 'Training cycle' },
              ],
            },
            {
              name: 'title',
              label: 'Mission title',
              type: 'text',
              required: true,
            },
            {
              name: 'description',
              label: 'Description',
              type: 'textarea',
              placeholder: 'Required for mission creation',
            },
            {
              name: 'difficulty',
              label: 'Difficulty',
              type: 'select',
              defaultValue: 'beginner',
              options: [
                { value: 'beginner', label: 'Beginner' },
                { value: 'intermediate', label: 'Intermediate' },
                { value: 'advanced', label: 'Advanced' },
              ],
            },
            {
              name: 'siteId',
              label: 'Site',
              type: 'select',
              options: siteOptions,
              defaultValue: activeSiteId(ctx.profile) || siteOptions[0]?.value || '',
            },
            {
              name: 'trainingType',
              label: 'Training type',
              type: 'select',
              defaultValue: 'term_launch',
              options: [
                { value: 'term_launch', label: 'Term launch' },
                { value: 'mid_term_clinic', label: 'Mid-term clinic' },
                { value: 'trainer_of_trainers', label: 'Trainer of trainers' },
              ],
            },
            {
              name: 'audience',
              label: 'Audience',
              type: 'select',
              defaultValue: 'educators',
              options: [
                { value: 'educators', label: 'Educators' },
                { value: 'parents', label: 'Parents' },
                { value: 'site_leads', label: 'Site leads' },
              ],
            },
            {
              name: 'termLabel',
              label: 'Term label',
              type: 'text',
              placeholder: 'Current term',
            },
            {
              name: 'startsAt',
              label: 'Start time',
              type: 'datetime-local',
              defaultValue: toDateInputValue(new Date()),
            },
            {
              name: 'notes',
              label: 'Notes',
              type: 'textarea',
            },
          ]),
        };
      }
    case '/hq/feature-flags':
      return {
        records: applyRouteActionLabels(await loadCallableRows({
          routePath: ctx.routePath,
          callableName: 'listFeatureFlags',
          args: {},
          rowArrayField: 'flags',
          collectionName: 'featureFlags',
          titleKeys: ['name', 'id'],
          subtitleKeys: ['description', 'scope'],
          statusKeys: ['status', 'enabled'],
          rowTransformer: canonicalizeFeatureFlagRow,
          editable: true,
        }), ctx.routePath),
        canCreate: true,
        canRefresh: true,
        createLabel: 'Create feature flag',
        createConfig: buildCreateConfig('Create feature flag', 'Create flag', [
          {
            name: 'name',
            label: 'Flag name',
            type: 'text',
            required: true,
          },
          {
            name: 'description',
            label: 'Description',
            type: 'textarea',
          },
        ]),
      };
    case '/messages': {
      const contacts = await loadWorkflowContacts(ctx);
      return {
        records: applyRouteActionLabels(await queryCollectionRecords({
          routePath: ctx.routePath,
          collectionName: 'messageThreads',
          constraints: [where('participantIds', 'array-contains', ctx.uid), orderBy('updatedAt', 'desc')],
          titleKeys: ['title', 'subject'],
          subtitleKeys: ['lastMessagePreview', 'siteId'],
          statusKeys: ['status'],
          editable: true,
          deletable: false,
          limitSize: 100,
        }), ctx.routePath),
        canCreate: true,
        canRefresh: true,
        createLabel: 'Start conversation',
        createConfig: buildCreateConfig('Start conversation', 'Start conversation', [
          {
            name: 'recipientId',
            label: 'Recipient',
            type: 'select',
            required: true,
            options: contacts,
          },
          {
            name: 'title',
            label: 'Subject',
            type: 'text',
            required: true,
          },
          {
            name: 'body',
            label: 'Message',
            type: 'textarea',
            required: true,
          },
        ]),
      };
    }
    case '/notifications': {
      const notificationRows = await queryCollectionRecords({
        routePath: ctx.routePath,
        collectionName: 'messages',
        constraints: [where('recipientId', '==', ctx.uid), orderBy('createdAt', 'desc')],
        titleKeys: ['title', 'body'],
        subtitleKeys: ['body', 'senderName'],
        statusKeys: ['status'],
        editable: true,
        deletable: false,
        limitSize: 60,
      });
      return {
        records: applyRouteActionLabels(
          notificationRows.filter((record) => record.metadata.type !== 'direct'),
          ctx.routePath,
        ),
        canCreate: false,
        canRefresh: true,
        createLabel: 'Create',
        createConfig: null,
      };
    }
    case '/profile': {
      const userSnap = await getDoc(doc(collection(firestore, 'users'), ctx.uid));
      if (!userSnap.exists()) return { records: [], canCreate: false, canRefresh: true, createLabel: 'Create', createConfig: null };
      return {
        records: [
          buildRecord({
            routePath: ctx.routePath,
            collectionName: 'users',
            id: userSnap.id,
            raw: (userSnap.data() || {}) as Record<string, unknown>,
            titleKeys: ['displayName', 'email', 'uid'],
            subtitleKeys: ['email', 'role'],
            statusKeys: ['role'],
            editable: false,
            deletable: false,
          }),
        ],
        canCreate: true,
        canRefresh: true,
        createLabel: 'Edit profile',
        createConfig: buildCreateConfig('Edit profile', 'Save profile', [
          {
            name: 'displayName',
            label: 'Display name',
            type: 'text',
            required: true,
            defaultValue: asString((userSnap.data() || {}).displayName, ''),
          },
          {
            name: 'phone',
            label: 'Phone',
            type: 'tel',
            defaultValue: asString((userSnap.data() || {}).phone, ''),
          },
          {
            name: 'photoUrl',
            label: 'Photo URL',
            type: 'text',
            defaultValue: asString((userSnap.data() || {}).photoUrl, ''),
          },
        ]),
      };
    }
    case '/settings': {
      const userSnap = await getDoc(doc(collection(firestore, 'users'), ctx.uid));
      if (!userSnap.exists()) return { records: [], canCreate: false, canRefresh: true, createLabel: 'Create', createConfig: null };
      const data = (userSnap.data() || {}) as Record<string, unknown>;
      const preferences = (data.preferences && typeof data.preferences === 'object' && !Array.isArray(data.preferences))
        ? (data.preferences as Record<string, unknown>)
        : {};
      return {
        records: [
          buildRecord({
            routePath: ctx.routePath,
            collectionName: 'users',
            id: userSnap.id,
            raw: data,
            titleKeys: ['displayName', 'uid'],
            subtitleKeys: ['activeSiteId', 'organizationId'],
            statusKeys: ['isActive'],
            editable: false,
            deletable: false,
          }),
        ],
        canCreate: true,
        canRefresh: true,
        createLabel: 'Update settings',
        createConfig: buildCreateConfig('Update settings', 'Save settings', [
          {
            name: 'locale',
            label: 'Language',
            type: 'select',
            required: true,
            defaultValue: asString(preferences.locale, 'en'),
            options: [
              { value: 'en', label: 'English' },
              { value: 'zh-CN', label: 'Chinese (Simplified)' },
              { value: 'zh-TW', label: 'Chinese (Traditional)' },
              { value: 'th', label: 'Thai' },
            ],
          },
          {
            name: 'timeZone',
            label: 'Time zone',
            type: 'text',
            defaultValue: asString(preferences.timeZone, 'auto'),
          },
          {
            name: 'notificationsEnabled',
            label: 'Enable notifications',
            type: 'checkbox',
            defaultValue: asBoolean(preferences.notificationsEnabled, true),
          },
          {
            name: 'emailNotifications',
            label: 'Email notifications',
            type: 'checkbox',
            defaultValue: asBoolean(preferences.emailNotifications, true),
          },
          {
            name: 'pushNotifications',
            label: 'Push notifications',
            type: 'checkbox',
            defaultValue: asBoolean(preferences.pushNotifications, true),
          },
        ]),
      };
    }
    case '/hq/capabilities':
      return {
        records: applyRouteActionLabels(await queryCollectionRecords({
          routePath: ctx.routePath,
          collectionName: 'capabilities',
          constraints: [orderBy('sortOrder', 'asc')],
          titleKeys: ['title', 'name'],
          subtitleKeys: ['pillarCode', 'status'],
          statusKeys: ['status'],
          editable: true,
          deletable: false,
          limitSize: 200,
        }), ctx.routePath),
        canCreate: true,
        canRefresh: true,
        createLabel: 'Create capability',
        createConfig: null,
      };
    case '/educator/verification':
      return {
        records: applyRouteActionLabels(await queryCollectionRecords({
          routePath: ctx.routePath,
          collectionName: 'portfolioItems',
          constraints: siteId
            ? [where('siteId', '==', siteId), where('verificationStatus', '==', 'pending'), orderBy('createdAt', 'desc')]
            : [where('verificationStatus', '==', 'pending'), orderBy('createdAt', 'desc')],
          titleKeys: ['title'],
          subtitleKeys: ['learnerId', 'pillarCode'],
          statusKeys: ['verificationStatus'],
          editable: true,
          deletable: false,
          limitSize: 50,
        }), ctx.routePath),
        canCreate: false,
        canRefresh: true,
        createLabel: 'Create',
        createConfig: null,
      };
    case '/parent/passport':
      return {
        records: await loadCallableRows({
          routePath: ctx.routePath,
          callableName: 'getParentDashboardBundle',
          args: {},
          rowArrayField: 'portfolioItemsPreview',
          collectionName: 'portfolioItems',
          titleKeys: ['title'],
          subtitleKeys: ['pillar', 'type'],
          statusKeys: ['verificationStatus'],
        }),
        canCreate: false,
        canRefresh: true,
        createLabel: 'Create',
        createConfig: null,
      };
    default:
      return { records: [], canCreate: false, canRefresh: true, createLabel: 'Create', guidanceText: null, createConfig: null };
  }
}

function requireStringValue(input: WorkflowCreateInput, key: string, label: string): string {
  const value = input.values[key];
  const normalized = typeof value === 'string' ? value.trim() : '';
  if (!normalized) {
    throw new Error(`${label} is required.`);
  }
  return normalized;
}

function optionalStringValue(input: WorkflowCreateInput, key: string): string {
  const value = input.values[key];
  return typeof value === 'string' ? value.trim() : '';
}

function booleanValue(input: WorkflowCreateInput, key: string, fallback = false): boolean {
  return asBoolean(input.values[key], fallback);
}

async function loadUserDisplayName(userId: string): Promise<string> {
  const userSnap = await getDoc(doc(collection(firestore, 'users'), userId));
  if (!userSnap.exists()) return 'User name unavailable';
  return userLabelFromRecord((userSnap.data() || {}) as Record<string, unknown>);
}

async function findUserByEmail(email: string): Promise<{ id: string; data: Record<string, unknown> } | null> {
  const normalizedEmail = email.trim().toLowerCase();
  if (!normalizedEmail) return null;
  const snap = await getDocs(
    query(
      collection(firestore, 'users'),
      where('email', '==', normalizedEmail),
      limit(1),
    ),
  );
  const match = snap.docs[0];
  if (!match) return null;
  return {
    id: match.id,
    data: (match.data() || {}) as Record<string, unknown>,
  };
}

async function ensureUserLinkedToSite(userId: string, siteId: string): Promise<void> {
  if (!userId.trim() || !siteId.trim()) return;
  const userRef = doc(collection(firestore, 'users'), userId);
  const existing = await getDoc(userRef);
  if (!existing.exists()) return;
  const data = (existing.data() || {}) as Record<string, unknown>;
  const siteIds = Array.isArray(data.siteIds)
    ? (data.siteIds as unknown[]).filter((entry): entry is string => typeof entry === 'string' && entry.trim().length > 0)
    : [];
  const activeSite = asString(data.activeSiteId, '');
  const updates: Record<string, unknown> = { updatedAt: serverTimestamp() };
  if (!siteIds.includes(siteId)) {
    updates.siteIds = arrayUnion(siteId);
  }
  if (!activeSite) {
    updates.activeSiteId = siteId;
  }
  await setDoc(userRef, updates, { merge: true });
}

async function syncLearnerParentLink(learnerId: string, parentId: string, add: boolean): Promise<void> {
  const learnerRef = doc(collection(firestore, 'users'), learnerId);
  await setDoc(learnerRef, {
    parentIds: add ? arrayUnion(parentId) : arrayRemove(parentId),
    updatedAt: serverTimestamp(),
  }, { merge: true });
}

async function createOrLinkLearnerProfile(params: {
  siteId: string;
  email: string;
  displayName: string;
  gradeLevel?: string;
  notes?: string;
}): Promise<string> {
  const normalizedEmail = params.email.trim().toLowerCase();
  const existingUser = await findUserByEmail(normalizedEmail);

  const learnerId = existingUser?.id || doc(collection(firestore, 'users')).id;
  const userRef = doc(collection(firestore, 'users'), learnerId);
  const baseUserData: Record<string, unknown> = existingUser
    ? {
        displayName: params.displayName.trim(),
        siteIds: arrayUnion(params.siteId),
        activeSiteId: params.siteId,
        updatedAt: serverTimestamp(),
      }
    : {
        uid: learnerId,
        email: normalizedEmail,
        displayName: params.displayName.trim(),
        role: 'learner',
        siteIds: [params.siteId],
        activeSiteId: params.siteId,
        isActive: true,
        status: 'active',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
        parentIds: [],
      };
  await setDoc(userRef, baseUserData, { merge: true });

  const profileRef = doc(collection(firestore, 'learnerProfiles'), learnerId);
  const gradeLevelRaw = params.gradeLevel?.trim();
  const gradeLevel = gradeLevelRaw && gradeLevelRaw.length > 0 ? Number(gradeLevelRaw) : null;
  await setDoc(profileRef, {
    siteId: params.siteId,
    learnerId,
    userId: learnerId,
    displayName: params.displayName.trim(),
    email: normalizedEmail,
    ...(gradeLevel !== null && !Number.isNaN(gradeLevel) ? { gradeLevel } : {}),
    ...(params.notes ? { notes: params.notes.trim() } : {}),
    updatedAt: serverTimestamp(),
    createdAt: serverTimestamp(),
  }, { merge: true });

  return learnerId;
}

async function createOrLinkParentProfile(params: {
  siteId: string;
  email: string;
  displayName: string;
  phone?: string;
}): Promise<string> {
  const normalizedEmail = params.email.trim().toLowerCase();
  const existingUser = await findUserByEmail(normalizedEmail);

  const parentId = existingUser?.id || doc(collection(firestore, 'users')).id;
  const userRef = doc(collection(firestore, 'users'), parentId);
  const baseUserData: Record<string, unknown> = existingUser
    ? {
        displayName: params.displayName.trim(),
        siteIds: arrayUnion(params.siteId),
        activeSiteId: params.siteId,
        updatedAt: serverTimestamp(),
      }
    : {
        uid: parentId,
        email: normalizedEmail,
        displayName: params.displayName.trim(),
        role: 'parent',
        siteIds: [params.siteId],
        activeSiteId: params.siteId,
        isActive: true,
        status: 'active',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      };
  await setDoc(userRef, baseUserData, { merge: true });

  const profileRef = doc(collection(firestore, 'parentProfiles'), parentId);
  await setDoc(profileRef, {
    siteId: params.siteId,
    parentId,
    userId: parentId,
    displayName: params.displayName.trim(),
    email: normalizedEmail,
    ...(params.phone ? { phone: params.phone.trim() } : {}),
    updatedAt: serverTimestamp(),
    createdAt: serverTimestamp(),
  }, { merge: true });

  return parentId;
}

export async function createWorkflowRecord(
  ctx: WorkflowContext,
  input: WorkflowCreateInput,
): Promise<void> {
  if (process.env.NEXT_PUBLIC_E2E_TEST_MODE === '1') {
    const { createE2EWorkflowRecord } = await loadE2EWorkflowBackend();
    await createE2EWorkflowRecord(ctx, input);
    return;
  }

  const siteId = ctx.routePath.startsWith('/site/')
    ? requireActiveSiteWorkflowContext(ctx)
    : activeSiteId(ctx.profile);
  const payloadBase: Record<string, unknown> = {
    updatedAt: serverTimestamp(),
    createdAt: serverTimestamp(),
    siteId: siteId || null,
    createdBy: ctx.uid,
  };

  switch (ctx.routePath) {
    case '/learner/missions': {
      const missionId = requireStringValue(input, 'missionId', 'Mission');
      const missionSnap = await getDoc(doc(collection(firestore, 'missions'), missionId));
      const missionData = (missionSnap.data() || {}) as Record<string, unknown>;
      const capabilityIds = Array.isArray(missionData.capabilityIds) ? missionData.capabilityIds.filter((v: unknown): v is string => typeof v === 'string') : [];
      const pillarCodes = Array.isArray(missionData.pillarCodes) ? missionData.pillarCodes.filter((v: unknown): v is string => typeof v === 'string') : [];
      await addDoc(collection(firestore, 'missionAttempts'), {
        ...payloadBase,
        missionId,
        missionTitle: optionLabelFromRecord(missionData, missionId),
        learnerId: ctx.uid,
        status: 'started',
        startedAt: serverTimestamp(),
        notes: optionalStringValue(input, 'notes') || null,
        ...(capabilityIds.length > 0 ? { capabilityIds } : {}),
        ...(pillarCodes.length > 0 ? { pillarCodes } : {}),
      });
      return;
    }
    case '/learner/portfolio':
      await addDoc(collection(firestore, 'portfolioItems'), {
        ...payloadBase,
        learnerId: ctx.uid,
        title: requireStringValue(input, 'title', 'Title'),
        description: optionalStringValue(input, 'description') || null,
        mediaType: requireStringValue(input, 'mediaType', 'Media type'),
        mediaUrl: optionalStringValue(input, 'mediaUrl') || null,
        status: 'draft',
      });
      return;
    case '/educator/attendance': {
        const learnerId = requireStringValue(input, 'learnerId', 'Learner');
        const sessionOccurrenceId = requireStringValue(input, 'sessionOccurrenceId', 'Session');
        const learnerName = await loadUserDisplayName(learnerId);
        await addDoc(collection(firestore, 'attendanceRecords'), {
          ...payloadBase,
          learnerId,
          learnerName,
          sessionOccurrenceId,
          status: requireStringValue(input, 'status', 'Attendance status'),
          notes: optionalStringValue(input, 'notes') || null,
          timestamp: serverTimestamp(),
          recordedAt: serverTimestamp(),
          userId: learnerId,
          recordedBy: ctx.uid,
        });
      }
      return;
    case '/educator/sessions':
    case '/site/sessions': {
        const title = requireStringValue(input, 'title', 'Session title');
        const startDate = parseDateInputValue(input.values.startDate);
        const endDate = parseDateInputValue(input.values.endDate);
        if (!startDate || !endDate) {
          throw new Error('Start and end times are required.');
        }
        if (endDate <= startDate) {
          throw new Error('End time must be after start time.');
        }
      await addDoc(collection(firestore, 'sessions'), {
        ...payloadBase,
        title,
        description: optionalStringValue(input, 'description') || null,
        educatorIds: [ctx.uid],
        pillarCodes: ['FUTURE_SKILLS'],
        startDate,
        endDate,
        status: 'scheduled',
      });
      }
      return;
    case '/educator/mission-plans':
      await addDoc(collection(firestore, 'missionPlans'), {
        ...payloadBase,
        title: requireStringValue(input, 'title', 'Plan title'),
        description: optionalStringValue(input, 'description') || null,
        educatorId: ctx.uid,
        status: 'draft',
      });
      return;
    case '/educator/learner-supports': {
      const learnerId = requireStringValue(input, 'learnerId', 'Learner');
      const callable = httpsCallable(functions, 'logSupportIntervention');
      await callable({
        learnerId,
        siteId: siteId || '',
        strategyType: requireStringValue(input, 'strategyType', 'Strategy type'),
        strategyDescription: requireStringValue(input, 'strategyDescription', 'Intervention'),
        context: requireStringValue(input, 'context', 'Context'),
        outcome: 'partial',
        notes: optionalStringValue(input, 'notes') || undefined,
        recommendForFuture: true,
      });
      return;
    }
    case '/site/checkin': {
        const learnerId = requireStringValue(input, 'learnerId', 'Learner');
        const learnerName = await loadUserDisplayName(learnerId);
        const type = requireStringValue(input, 'type', 'Event type');
        await addDoc(collection(firestore, 'checkins'), {
          ...payloadBase,
          learnerId,
          learnerName,
          type,
          status: 'completed',
          notes: optionalStringValue(input, 'notes') || null,
          recordedBy: ctx.uid,
          timestamp: serverTimestamp(),
        });
      }
      return;
    case '/site/provisioning': {
      if (!siteId) {
        throw new Error('Active site context is required for provisioning.');
      }
      const action = requireStringValue(input, 'action', 'Provisioning action');
      if (action === 'cohortLaunch') {
        const callable = httpsCallable(functions, 'upsertCohortLaunch');
        await callable({
          siteId,
          cohortName: requireStringValue(input, 'cohortName', 'Cohort name'),
          ageBand: optionalStringValue(input, 'ageBand') || undefined,
          scheduleLabel: optionalStringValue(input, 'scheduleLabel') || undefined,
          programFormat: optionalStringValue(input, 'programFormat') || undefined,
          curriculumTerm: optionalStringValue(input, 'curriculumTerm') || undefined,
          rosterStatus: optionalStringValue(input, 'rosterStatus') || undefined,
          parentCommunicationStatus: optionalStringValue(input, 'parentCommunicationStatus') || undefined,
          baselineSurveyStatus: optionalStringValue(input, 'baselineSurveyStatus') || undefined,
          kickoffStatus: optionalStringValue(input, 'kickoffStatus') || undefined,
          learnerCount: optionalStringValue(input, 'learnerCount') || undefined,
          notes: optionalStringValue(input, 'notes') || undefined,
        });
        return;
      }
      if (action === 'learner') {
        await createOrLinkLearnerProfile({
          siteId,
          email: requireStringValue(input, 'email', 'Email'),
          displayName: requireStringValue(input, 'displayName', 'Display name'),
          gradeLevel: optionalStringValue(input, 'gradeLevel') || undefined,
          notes: optionalStringValue(input, 'notes') || undefined,
        });
        return;
      }
      if (action === 'parent') {
        await createOrLinkParentProfile({
          siteId,
          email: requireStringValue(input, 'email', 'Email'),
          displayName: requireStringValue(input, 'displayName', 'Display name'),
          phone: optionalStringValue(input, 'phone') || undefined,
        });
        return;
      }

      const parentId = requireStringValue(input, 'parentId', 'Parent');
      const learnerId = requireStringValue(input, 'learnerId', 'Learner');
      await Promise.all([
        ensureUserLinkedToSite(parentId, siteId),
        ensureUserLinkedToSite(learnerId, siteId),
        syncLearnerParentLink(learnerId, parentId, true),
      ]);

      await addDoc(collection(firestore, 'guardianLinks'), {
        ...payloadBase,
        siteId,
        parentId,
        parentName: await loadUserDisplayName(parentId),
        learnerId,
        learnerName: await loadUserDisplayName(learnerId),
        status: 'active',
        relationship: optionalStringValue(input, 'relationship') || 'guardian',
        isPrimary: booleanValue(input, 'isPrimary'),
      });
      return;
    }
    case '/site/ops':
      await addDoc(collection(firestore, 'siteOpsEvents'), {
        ...payloadBase,
        eventType: requireStringValue(input, 'eventType', 'Event type'),
        details: requireStringValue(input, 'details', 'Details'),
        status: 'open',
      });
      return;
    case '/site/incidents': {
      const callable = httpsCallable(functions, 'resolveSafetyIncident');
      await callable({
        mode: 'create',
        siteId: siteId || '',
        title: requireStringValue(input, 'title', 'Incident title'),
        summary: requireStringValue(input, 'summary', 'Summary'),
        incidentType: optionalStringValue(input, 'incidentType') || undefined,
        severity: optionalStringValue(input, 'severity') || undefined,
        happenedAt: optionalStringValue(input, 'happenedAt') || undefined,
        location: optionalStringValue(input, 'location') || undefined,
        involvedNames: optionalStringValue(input, 'involvedNames') || undefined,
        immediateAction: optionalStringValue(input, 'immediateAction') || undefined,
        correctiveAction: optionalStringValue(input, 'correctiveAction') || undefined,
      });
      return;
    }
    case '/site/clever': {
      if (!siteId) {
        throw new Error('Active site context is required for Clever workflows.');
      }

      const schoolId = optionalStringValue(input, 'schoolId');
      if (schoolId) {
        const callable = httpsCallable(functions, 'queueCleverRosterSync');
        const response = await callable({
          siteId,
          schoolId,
          mode: optionalStringValue(input, 'mode') || 'preview',
        });
        ensureLiveWorkflowResult((response.data || {}) as Record<string, unknown>, 'Clever roster sync');
        return;
      }

      const callable = httpsCallable(functions, 'createCleverAuthUrl');
      const response = await callable({
        siteId,
        returnUrl: typeof window !== 'undefined' ? window.location.href : `/${ctx.locale}/site/clever`,
      });
      const payload = (response.data || {}) as Record<string, unknown>;
      ensureLiveWorkflowResult(payload, 'Clever connection');
      const url = asString(payload.url, '');
      if (url && typeof window !== 'undefined') {
        window.location.assign(url);
      }
      return;
    }
    case '/site/integrations-health':
    case '/hq/integrations-health': {
      const callable = httpsCallable(functions, 'triggerIntegrationSyncJob');
      await callable({
        siteId: siteId || undefined,
        provider: requireStringValue(input, 'provider', 'Provider'),
        requestedBy: ctx.uid,
      });
      return;
    }
    case '/site/billing': {
      const callable = httpsCallable(functions, 'requestSiteBillingPlanChange');
      await callable({
        siteId: optionalStringValue(input, 'siteId') || siteId || undefined,
        reason: requireStringValue(input, 'reason', 'Reason'),
      });
      return;
    }
    case '/partner/listings':
      {
        const partnerId = ctx.role === 'partner'
          ? ctx.uid
          : requireStringValue(input, 'partnerId', 'Partner');
      await addDoc(collection(firestore, 'marketplaceListings'), {
        ...payloadBase,
        partnerId,
        title: requireStringValue(input, 'title', 'Listing title'),
        description: requireStringValue(input, 'description', 'Description'),
        category: optionalStringValue(input, 'category') || null,
        status: 'draft',
      });
      return;
      }
    case '/partner/contracts':
      if (optionalStringValue(input, 'action') === 'partnerLaunch') {
        const callable = httpsCallable(functions, 'upsertPartnerLaunch');
        await callable({
          partnerId: optionalStringValue(input, 'partnerId') || undefined,
          siteId: optionalStringValue(input, 'siteId') || undefined,
          partnerName: requireStringValue(input, 'partnerName', 'Partner name'),
          region: requireStringValue(input, 'region', 'Region'),
          locale: optionalStringValue(input, 'locale') || 'en',
          pilotCohortCount: optionalStringValue(input, 'pilotCohortCount') || undefined,
          dueDiligenceStatus: optionalStringValue(input, 'dueDiligenceStatus') || undefined,
          trainerOfTrainersStatus: optionalStringValue(input, 'trainerOfTrainersStatus') || undefined,
          review90DayStatus: optionalStringValue(input, 'review90DayStatus') || undefined,
          notes: optionalStringValue(input, 'notes') || undefined,
        });
        return;
      }
      const partnerId = ctx.role === 'partner'
        ? ctx.uid
        : requireStringValue(input, 'partnerId', 'Partner');
      await addDoc(collection(firestore, 'partnerContracts'), {
        ...payloadBase,
        partnerId,
        title: requireStringValue(input, 'title', 'Contract title'),
        summary: requireStringValue(input, 'summary', 'Summary'),
        siteId: optionalStringValue(input, 'siteId') || null,
        status: 'draft',
      });
      return;
    case '/partner/deliverables': {
      const evidenceUrl = optionalStringValue(input, 'evidenceUrl');
      if (evidenceUrl) {
        try {
          const parsed = new URL(evidenceUrl);
          if (!['http:', 'https:'].includes(parsed.protocol)) {
            throw new Error('invalid protocol');
          }
        } catch {
          throw new Error('Evidence URL must be a valid http or https link.');
        }
      }
      await addDoc(collection(firestore, 'partnerDeliverables'), {
        ...payloadBase,
        contractId: requireStringValue(input, 'contractId', 'Contract'),
        title: requireStringValue(input, 'title', 'Deliverable title'),
        description: optionalStringValue(input, 'description') || null,
        evidenceUrl: evidenceUrl || null,
        status: 'submitted',
        submittedBy: ctx.uid,
        submittedAt: serverTimestamp(),
      });
      return;
    }
    case '/hq/sites':
      await addDoc(collection(firestore, 'sites'), {
        ...payloadBase,
        name: requireStringValue(input, 'name', 'Site name'),
        location: requireStringValue(input, 'location', 'Location'),
        siteLeadIds: [],
        status: 'pending',
      });
      return;
    case '/hq/billing': {
      const callable = httpsCallable(functions, 'createHqInvoice');
      await callable({
        siteId: optionalStringValue(input, 'siteId') || undefined,
        parentId: requireStringValue(input, 'parentId', 'Parent'),
        learnerId: requireStringValue(input, 'learnerId', 'Learner'),
        amount: Number(requireStringValue(input, 'amount', 'Amount')),
        currency: optionalStringValue(input, 'currency') || undefined,
        description: optionalStringValue(input, 'description') || undefined,
      });
      return;
    }
    case '/hq/analytics': {
      const operation = optionalStringValue(input, 'operation') || 'generateKpiPack';
      const siteIdValue = optionalStringValue(input, 'siteId');
      const periodValue = optionalStringValue(input, 'period');
      const startDate = optionalStringValue(input, 'startDate');
      const endDate = optionalStringValue(input, 'endDate');
      const limitValue = optionalStringValue(input, 'limit');
      const parsedLimit = limitValue ? Number(limitValue) : undefined;
      if (typeof parsedLimit !== 'undefined' && (!Number.isFinite(parsedLimit) || parsedLimit <= 0)) {
        throw new Error('Batch limit must be a positive number.');
      }

      if (operation === 'backfillTelemetryAggregates') {
        const callable = httpsCallable(functions, 'backfillTelemetryAggregates');
        await callable({
          aggregationType: optionalStringValue(input, 'aggregationType') || 'daily',
          siteId: siteIdValue || undefined,
          startDate: startDate || undefined,
          endDate: endDate || undefined,
          limit: parsedLimit,
        });
        return;
      }

      if (operation === 'backfillKpiPackVoiceReliability') {
        const callable = httpsCallable(functions, 'backfillKpiPackVoiceReliability');
        await callable({
          siteId: siteIdValue || undefined,
          period: periodValue || undefined,
          startDate: startDate || undefined,
          endDate: endDate || undefined,
          limit: parsedLimit,
          force: booleanValue(input, 'force'),
        });
        return;
      }

      const callable = httpsCallable(functions, 'generateKpiPack');
      await callable({
        siteId: requireStringValue(input, 'siteId', 'Site'),
        period: requireStringValue(input, 'period', 'Period'),
      });
      return;
    }
    case '/hq/audit': {
      const callable = httpsCallable(functions, 'upsertRedTeamReview');
      await callable({
        title: requireStringValue(input, 'title', 'Review title'),
        siteId: optionalStringValue(input, 'siteId') || undefined,
        kpiPackId: optionalStringValue(input, 'kpiPackId') || undefined,
        period: optionalStringValue(input, 'period') || 'term',
        decision: optionalStringValue(input, 'decision') || 'continue',
        partnerStatus: optionalStringValue(input, 'partnerStatus') || 'active',
        recommendations: optionalStringValue(input, 'recommendations') || '',
        nextAction: optionalStringValue(input, 'nextAction') || '',
      });
      return;
    }
    case '/site/dashboard': {
      const callable = httpsCallable(functions, 'generateKpiPack');
      await callable({
        siteId: siteId || undefined,
        period: requireStringValue(input, 'period', 'Period'),
      });
      return;
    }
    case '/hq/curriculum':
      if (optionalStringValue(input, 'action') === 'trainingCycle') {
        const callable = httpsCallable(functions, 'upsertTrainingCycle');
        await callable({
          siteId: optionalStringValue(input, 'siteId') || undefined,
          title: requireStringValue(input, 'title', 'Training cycle title'),
          trainingType: optionalStringValue(input, 'trainingType') || 'term_launch',
          audience: optionalStringValue(input, 'audience') || 'educators',
          termLabel: optionalStringValue(input, 'termLabel') || 'Current term',
          startsAt: optionalStringValue(input, 'startsAt') || undefined,
          notes: optionalStringValue(input, 'notes') || undefined,
        });
        return;
      }
      await addDoc(collection(firestore, 'missions'), {
        ...payloadBase,
        title: requireStringValue(input, 'title', 'Mission title'),
        description: requireStringValue(input, 'description', 'Description'),
        pillarCodes: ['FUTURE_SKILLS'],
        difficulty: requireStringValue(input, 'difficulty', 'Difficulty'),
        status: 'draft',
      });
      return;
    case '/hq/feature-flags': {
      const callable = httpsCallable(functions, 'upsertFeatureFlag');
      await callable({
        name: canonicalizeFeatureFlagName(requireStringValue(input, 'name', 'Flag name')),
        description: optionalStringValue(input, 'description'),
        enabled: false,
      });
      return;
    }
    case '/messages': {
      const recipientId = requireStringValue(input, 'recipientId', 'Recipient');
      const subject = requireStringValue(input, 'title', 'Subject');
      const body = requireStringValue(input, 'body', 'Message');
      const contacts = await loadWorkflowContacts(ctx);
      const recipient = contacts.find((entry) => entry.value === recipientId);

      const candidateThreads = await getDocs(
        query(
          collection(firestore, 'messageThreads'),
          where('participantIds', 'array-contains', ctx.uid),
          orderBy('updatedAt', 'desc'),
          limit(40),
        ),
      ).catch(() => null);

      const existingThread = candidateThreads?.docs.find((threadDoc) => {
        const participantIds = Array.isArray(threadDoc.data().participantIds)
          ? (threadDoc.data().participantIds as unknown[]).filter((entry): entry is string => typeof entry === 'string')
          : [];
        return participantIds.includes(recipientId);
      });

      const threadRef = existingThread
        ? doc(collection(firestore, 'messageThreads'), existingThread.id)
        : doc(collection(firestore, 'messageThreads'));

      await setDoc(threadRef, {
        title: subject,
        participantIds: existingThread
          ? existingThread.data().participantIds
          : [ctx.uid, recipientId],
        participantNames: existingThread
          ? existingThread.data().participantNames
          : [ctx.profile?.displayName || 'User name unavailable', recipient?.label || 'User name unavailable'],
        status: 'open',
        lastMessagePreview: body,
        lastMessageSenderId: ctx.uid,
        updatedAt: serverTimestamp(),
        ...(existingThread ? {} : { createdAt: serverTimestamp(), createdBy: ctx.uid, siteId: siteId || null }),
      }, { merge: true });

      await addDoc(collection(firestore, 'messages'), {
        threadId: threadRef.id,
        title: subject,
        body,
        type: 'direct',
        priority: 'normal',
        senderId: ctx.uid,
        senderName: ctx.profile?.displayName || 'User name unavailable',
        recipientId,
        siteId: siteId || null,
        isRead: false,
        status: 'sent',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
      return;
    }
    case '/profile':
      await setDoc(doc(collection(firestore, 'users'), ctx.uid), {
        displayName: requireStringValue(input, 'displayName', 'Display name'),
        phone: optionalStringValue(input, 'phone') || null,
        photoUrl: optionalStringValue(input, 'photoUrl') || null,
        profileUpdatedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }, { merge: true });
      return;
    case '/settings':
      await setDoc(doc(collection(firestore, 'users'), ctx.uid), {
        preferences: {
          locale: requireStringValue(input, 'locale', 'Language'),
          timeZone: optionalStringValue(input, 'timeZone') || 'auto',
          notificationsEnabled: booleanValue(input, 'notificationsEnabled', true),
          emailNotifications: booleanValue(input, 'emailNotifications', true),
          pushNotifications: booleanValue(input, 'pushNotifications', true),
        },
        settingsUpdatedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }, { merge: true });
      return;
    default:
      return;
  }
}

export async function updateWorkflowRecord(
  ctx: WorkflowContext,
  target: WorkflowMutationTarget,
): Promise<void> {
  if (process.env.NEXT_PUBLIC_E2E_TEST_MODE === '1') {
    const { updateE2EWorkflowRecord } = await loadE2EWorkflowBackend();
    await updateE2EWorkflowRecord(ctx, target);
    return;
  }

  const ref = doc(collection(firestore, target.collectionName), target.id);
  const existing = await getDoc(ref).catch(() => null);
  const data = (existing?.data() || {}) as Record<string, unknown>;
  const siteId = ctx.routePath.startsWith('/site/')
    ? requireActiveSiteWorkflowContext(ctx)
    : activeSiteId(ctx.profile);

  if (target.collectionName === 'approvals') {
    const callable = httpsCallable(functions, 'decideWorkflowApproval');
    await callable({
      id: target.id,
      status: 'approved',
    });
    return;
  }

  if (target.collectionName === 'incidents') {
    const callable = httpsCallable(functions, 'resolveSafetyIncident');
    await callable({
      mode: 'update',
      id: target.id,
      status: 'resolved',
      siteId: siteId || undefined,
    });
    return;
  }

  if (target.collectionName === 'featureFlags') {
    const callable = httpsCallable(functions, 'upsertFeatureFlag');
    await callable({
      id: target.id,
      enabled: asString(data.status, '') !== 'enabled',
    });
    return;
  }

  if (ctx.routePath === '/hq/user-admin' && target.collectionName === 'users') {
    const callable = httpsCallable(functions, 'updateUserRoles');
    await callable({
      uid: target.id,
      isActive: !asBoolean(data.isActive, true),
    });
    return;
  }

  if (target.collectionName === 'externalIdentityLinks') {
    const callable = httpsCallable(functions, 'resolveExternalIdentityLink');
    await callable({
      id: target.id,
      status: 'resolved',
    });
    return;
  }

  if (ctx.routePath === '/site/clever' && target.collectionName === 'integrationConnections') {
    if (!siteId) {
      throw new Error('Active site context is required for Clever workflows.');
    }

    const status = asString(data.status, '').toLowerCase();
    if (status === 'active' || status === 'pending') {
      const callable = httpsCallable(functions, 'disconnectCleverConnection');
      await callable({ siteId });
      return;
    }

    const callable = httpsCallable(functions, 'createCleverAuthUrl');
    const response = await callable({
      siteId,
      returnUrl: typeof window !== 'undefined' ? window.location.href : `/${ctx.locale}/site/clever`,
    });
    const payload = (response.data || {}) as Record<string, unknown>;
    ensureLiveWorkflowResult(payload, 'Clever connection');
    const url = asString(payload.url, '');
    if (url && typeof window !== 'undefined') {
      window.location.assign(url);
    }
    return;
  }

  switch (ctx.routePath) {
    case '/learner/missions':
      await updateDoc(ref, {
        updatedAt: serverTimestamp(),
        status: asString(data.status, '') === 'submitted' ? 'started' : 'submitted',
        submittedAt: serverTimestamp(),
      });
      return;
    case '/learner/portfolio':
      await updateDoc(ref, {
        updatedAt: serverTimestamp(),
        status: asString(data.status, '') === 'published' ? 'published' : 'published',
        publishedAt: serverTimestamp(),
      });
      return;
    case '/educator/attendance':
      await updateDoc(ref, {
        updatedAt: serverTimestamp(),
        verifiedAt: serverTimestamp(),
        verifiedBy: ctx.uid,
      });
      return;
    case '/educator/missions/review':
      await updateDoc(ref, {
        updatedAt: serverTimestamp(),
        status: 'reviewed',
        reviewStatus: 'reviewed',
        gradedBy: ctx.uid,
        gradedAt: serverTimestamp(),
        reviewedBy: ctx.uid,
        reviewedAt: serverTimestamp(),
      });
      return;
    case '/educator/sessions':
    case '/site/sessions': {
      const currentStatus = asString(data.status, 'scheduled');
      const nextStatus = currentStatus === 'in_progress' ? 'completed' : 'in_progress';
      await updateDoc(ref, {
        updatedAt: serverTimestamp(),
        status: nextStatus,
        ...(nextStatus === 'in_progress' ? { startedAt: serverTimestamp() } : { completedAt: serverTimestamp() }),
      });
      return;
    }
    case '/educator/mission-plans': {
      const currentStatus = asString(data.status, 'draft');
      const nextStatus = currentStatus === 'active' ? 'archived' : 'active';
      await updateDoc(ref, {
        updatedAt: serverTimestamp(),
        status: nextStatus,
        activatedAt: serverTimestamp(),
      });
      return;
    }
    case '/site/provisioning': {
      if (target.collectionName === 'cohortLaunches') {
        const callable = httpsCallable(functions, 'upsertCohortLaunch');
        const currentStatus = asString(data.status, 'planning');
        await callable({
          id: target.id,
          siteId: siteId || undefined,
          cohortName: asString(data.cohortName, target.id),
          ageBand: asString(data.ageBand, ''),
          scheduleLabel: asString(data.scheduleLabel, ''),
          programFormat: asString(data.programFormat, 'gold'),
          curriculumTerm: asString(data.curriculumTerm, 'Term 1'),
          rosterStatus: asString(data.rosterStatus, 'draft'),
          parentCommunicationStatus: asString(data.parentCommunicationStatus, 'pending'),
          baselineSurveyStatus: asString(data.baselineSurveyStatus, 'pending'),
          kickoffStatus: asString(data.kickoffStatus, 'pending'),
          learnerCount: asString(data.learnerCount, '0'),
          notes: asString(data.notes, ''),
          status: currentStatus === 'active' ? 'planning' : 'active',
        });
        return;
      }
      const currentStatus = asString(data.status, 'active');
      const nextStatus = currentStatus === 'active' ? 'inactive' : 'active';
      await updateDoc(ref, {
        updatedAt: serverTimestamp(),
        status: nextStatus,
      });
      await syncLearnerParentLink(
        asString(data.learnerId, ''),
        asString(data.parentId, ''),
        nextStatus === 'active',
      );
      return;
    }
    case '/site/ops': {
      const currentStatus = asString(data.status, 'open');
      await updateDoc(ref, {
        updatedAt: serverTimestamp(),
        status: currentStatus === 'resolved' ? 'open' : 'resolved',
        resolvedBy: currentStatus === 'resolved' ? null : ctx.uid,
        resolvedAt: currentStatus === 'resolved' ? null : serverTimestamp(),
      });
      return;
    }
    case '/partner/listings': {
      const currentStatus = asString(data.status, 'draft');
      await updateDoc(ref, {
        updatedAt: serverTimestamp(),
        status: currentStatus === 'published' ? 'archived' : 'published',
        publishedAt: currentStatus === 'published' ? data.publishedAt || null : serverTimestamp(),
      });
      return;
    }
    case '/partner/contracts': {
      if (target.collectionName === 'partnerLaunches') {
        const callable = httpsCallable(functions, 'upsertPartnerLaunch');
        const currentStatus = asString(data.status, 'planning');
        const partnerId = asString(data.partnerId, '');
        if (!partnerId) {
          throw new Error('Partner launch is missing a partner assignment.');
        }
        await callable({
          id: target.id,
          partnerId,
          siteId: asString(data.siteId, '') || undefined,
          partnerName: asString(data.partnerName, target.id),
          region: asString(data.region, 'global'),
          locale: asString(data.locale, 'en'),
          pilotCohortCount: asString(data.pilotCohortCount, '0'),
          dueDiligenceStatus: asString(data.dueDiligenceStatus, 'pending'),
          trainerOfTrainersStatus: asString(data.trainerOfTrainersStatus, 'pending'),
          review90DayStatus: asString(data.review90DayStatus, 'pending'),
          notes: asString(data.notes, ''),
          status: currentStatus === 'active' ? 'planning' : 'active',
        });
        return;
      }
      const currentStatus = asString(data.status, 'draft');
      await updateDoc(ref, {
        updatedAt: serverTimestamp(),
        status: currentStatus === 'submitted' ? 'draft' : 'submitted',
        submittedAt: currentStatus === 'submitted' ? null : serverTimestamp(),
      });
      return;
    }
    case '/partner/deliverables': {
      const currentStatus = asString(data.status, 'submitted');
      await updateDoc(ref, {
        updatedAt: serverTimestamp(),
        status: currentStatus === 'accepted' ? 'submitted' : 'accepted',
        acceptedBy: currentStatus === 'accepted' ? null : ctx.uid,
        acceptedAt: currentStatus === 'accepted' ? null : serverTimestamp(),
      });
      return;
    }
    case '/hq/curriculum': {
      if (target.collectionName === 'trainingCycles') {
        const callable = httpsCallable(functions, 'upsertTrainingCycle');
        const currentStatus = asString(data.status, 'scheduled');
        await callable({
          id: target.id,
          siteId: asString(data.siteId, '') || undefined,
          title: asString(data.title, target.id),
          trainingType: asString(data.trainingType, 'term_launch'),
          audience: asString(data.audience, 'educators'),
          termLabel: asString(data.termLabel, 'Current term'),
          startsAt: asString(data.startsAt, '') || undefined,
          completionCount: asString(data.completionCount, '0'),
          notes: asString(data.notes, ''),
          status: currentStatus === 'completed' ? 'scheduled' : 'completed',
        });
        return;
      }

      const currentStatus = asString(data.status, 'draft');
      const nextStatus = currentStatus === 'draft'
        ? 'in_review'
        : currentStatus === 'in_review'
        ? 'published'
        : 'published';
      await updateDoc(ref, {
        updatedAt: serverTimestamp(),
        status: nextStatus,
        ...(nextStatus === 'published'
          ? { publishedAt: serverTimestamp() }
          : { reviewSubmittedAt: serverTimestamp() }),
      });
      return;
    }
    case '/hq/sites': {
      const currentStatus = asString(data.status, 'pending');
      const nextStatus = currentStatus === 'active' ? 'paused' : 'active';
      await updateDoc(ref, {
        updatedAt: serverTimestamp(),
        status: nextStatus,
      });
      return;
    }
    case '/messages': {
      const currentStatus = asString(data.status, 'open');
      await updateDoc(ref, {
        updatedAt: serverTimestamp(),
        status: currentStatus === 'archived' ? 'open' : 'archived',
      });
      return;
    }
    case '/notifications':
      {
        const currentlyRead = asBoolean(data.isRead, false);
      await updateDoc(ref, {
        updatedAt: serverTimestamp(),
        isRead: !currentlyRead,
        readAt: currentlyRead ? null : serverTimestamp(),
      });
      return;
      }
    default:
      return;
  }
}

export async function deleteWorkflowRecord(target: WorkflowMutationTarget): Promise<void> {
  if (process.env.NEXT_PUBLIC_E2E_TEST_MODE === '1') {
    const { deleteE2EWorkflowRecord } = await loadE2EWorkflowBackend();
    await deleteE2EWorkflowRecord(target);
    return;
  }

  const deletableCollections = new Set(['portfolioItems', 'guardianLinks']);
  if (!deletableCollections.has(target.collectionName)) {
    return;
  }

  const ref = doc(collection(firestore, target.collectionName), target.id);
  const existing = await getDoc(ref).catch(() => null);
  const data = (existing?.data() || {}) as Record<string, unknown>;
  await deleteDoc(ref);

  if (target.collectionName === 'guardianLinks') {
    const learnerId = asString(data.learnerId, '');
    const parentId = asString(data.parentId, '');
    if (learnerId && parentId) {
      const remainingLinks = await getDocs(
        query(
          collection(firestore, 'guardianLinks'),
          where('learnerId', '==', learnerId),
          where('parentId', '==', parentId),
          limit(1),
        ),
      ).catch(() => null);

      if (!remainingLinks || remainingLinks.docs.length === 0) {
        await syncLearnerParentLink(learnerId, parentId, false);
      }
    }
  }
}
