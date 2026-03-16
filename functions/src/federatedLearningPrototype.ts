import { createHash } from 'crypto';

export type FederatedLearningRuntimeTarget = 'flutter_mobile' | 'web_pwa' | 'hybrid';
export type FederatedLearningExperimentStatus = 'draft' | 'pilot_ready' | 'active' | 'paused' | 'disabled';
export type FederatedLearningBatteryState = 'low' | 'ok' | 'charging' | 'unknown';
export type FederatedLearningNetworkType = 'wifi' | 'cellular' | 'offline' | 'unknown';
export type FederatedLearningAggregationRunStatus = 'materialized';
export type FederatedLearningMergeArtifactStatus = 'generated';
export type FederatedLearningCandidateModelPackageStatus = 'staged';
export type FederatedLearningCandidateModelPackageRolloutStatus =
  'not_distributed' | 'distributed' | 'retired';
export type FederatedLearningCandidatePromotionStatus = 'approved_for_eval' | 'hold';
export type FederatedLearningCandidatePromotionTarget = 'sandbox_eval';
export type FederatedLearningExperimentReviewStatus = 'pending' | 'approved' | 'blocked';
export type FederatedLearningPilotEvidenceStatus = 'pending' | 'ready_for_pilot' | 'blocked';
export type FederatedLearningPilotApprovalStatus = 'pending' | 'approved' | 'blocked';
export type FederatedLearningPilotExecutionStatus = 'planned' | 'launched' | 'observed' | 'completed';
export type FederatedLearningRuntimeDeliveryStatus = 'prepared' | 'assigned' | 'active' | 'superseded' | 'revoked';
export type FederatedLearningRuntimeActivationStatus = 'resolved' | 'staged' | 'fallback';
export type FederatedLearningRuntimeRolloutControlMode = 'monitor' | 'restricted' | 'paused';
export type FederatedLearningMergeStrategy =
  'norm_capped_weighted_runtime_vector_average_v2' |
  'norm_capped_summary_balanced_runtime_vector_average_v1';

export const FEDERATED_LEARNING_MERGE_STRATEGY =
  'norm_capped_weighted_runtime_vector_average_v2';
export const FEDERATED_LEARNING_SUMMARY_BALANCED_MERGE_STRATEGY =
  'norm_capped_summary_balanced_runtime_vector_average_v1';

export interface FederatedLearningExperimentConfig {
  name: string;
  description: string;
  runtimeTarget: FederatedLearningRuntimeTarget;
  status: FederatedLearningExperimentStatus;
  mergeStrategy: FederatedLearningMergeStrategy;
  allowedSiteIds: string[];
  aggregateThreshold: number;
  rawUpdateMaxBytes: number;
  enablePrototypeUploads: boolean;
}

export interface FederatedLearningUpdateSummary {
  siteId: string;
  traceId: string;
  schemaVersion: string;
  sampleCount: number;
  vectorLength: number;
  vectorSketch: number[];
  payloadBytes: number;
  updateNorm: number;
  payloadDigest: string;
  optimizerStrategy?: string;
  localEpochCount?: number;
  localStepCount?: number;
  trainingWindowSeconds?: number;
  warmStartPackageId?: string;
  warmStartDeliveryRecordId?: string;
  warmStartModelVersion?: string;
  batteryState: FederatedLearningBatteryState;
  networkType: FederatedLearningNetworkType;
}

export interface FederatedLearningAggregationCandidate {
  id: string;
  siteId: string;
  sampleCount: number;
  vectorLength: number;
  vectorSketch: number[];
  payloadBytes: number;
  updateNorm: number;
  schemaVersion: string;
  runtimeTarget?: string | null;
  optimizerStrategy?: string | null;
  warmStartPackageId?: string | null;
  warmStartModelVersion?: string | null;
  traceId?: string | null;
  payloadDigest?: string | null;
}

export interface FederatedLearningContributionDetail {
  summaryId: string;
  siteId: string;
  sampleCount: number;
  payloadBytes: number;
  vectorLength: number;
  updateNorm: number;
  schemaVersion: string;
  runtimeTarget?: string;
  traceId?: string;
  payloadDigest?: string;
  rawWeight: number;
  normScale: number;
  effectiveWeight: number;
}

export interface FederatedLearningSiteContributionSummary {
  siteId: string;
  summaryCount: number;
  totalSampleCount: number;
  totalPayloadBytes: number;
  rawWeight: number;
  effectiveWeight: number;
  dampedSummaryCount: number;
  minUpdateNorm: number;
  maxUpdateNorm: number;
}

export interface FederatedLearningAggregationSelection {
  summaryIds: string[];
  summaryCount: number;
  distinctSiteCount: number;
  contributingSiteIds: string[];
  totalSampleCount: number;
  maxVectorLength: number;
  totalPayloadBytes: number;
  averageUpdateNorm: number;
  schemaVersions: string[];
  runtimeTargets: string[];
  optimizerStrategies: string[];
  compatibilityKey: string;
  warmStartPackageId?: string;
  warmStartModelVersion?: string;
}

export interface FederatedLearningMergeWeightSummary {
  normCap: number;
  effectiveTotalWeight: number;
  rawTotalWeight: number;
  dampedSummaryCount: number;
  minUpdateNorm: number;
  maxUpdateNorm: number;
}

export interface FederatedLearningMergeArtifactSummary {
  mergeStrategy: string;
  normCap: number;
  effectiveTotalWeight: number;
  rawTotalWeight: number;
  dampedSummaryCount: number;
  minUpdateNorm: number;
  maxUpdateNorm: number;
  triggerSummaryId: string;
  summaryIds: string[];
  payloadFormat: 'runtime_vector_v1';
  modelVersion: string;
  sampleCount: number;
  summaryCount: number;
  distinctSiteCount: number;
  contributingSiteIds: string[];
  schemaVersions: string[];
  runtimeTargets: string[];
  optimizerStrategies: string[];
  compatibilityKey: string;
  warmStartPackageId?: string;
  warmStartModelVersion?: string;
  maxVectorLength: number;
  runtimeVectorLength: number;
  runtimeVector: number[];
  runtimeVectorDigest: string;
  totalPayloadBytes: number;
  averageUpdateNorm: number;
  boundedDigest: string;
  contributionDetails: FederatedLearningContributionDetail[];
  siteContributionSummaries: FederatedLearningSiteContributionSummary[];
}

export interface FederatedLearningCandidateModelPackageSummary {
  mergeStrategy: string;
  normCap: number;
  effectiveTotalWeight: number;
  rawTotalWeight: number;
  dampedSummaryCount: number;
  minUpdateNorm: number;
  maxUpdateNorm: number;
  triggerSummaryId: string;
  summaryIds: string[];
  packageFormat: 'runtime_vector_v1';
  rolloutStatus: FederatedLearningCandidateModelPackageRolloutStatus;
  modelVersion: string;
  packageDigest: string;
  boundedDigest: string;
  runtimeVectorLength: number;
  runtimeVector: number[];
  runtimeVectorDigest: string;
  sampleCount: number;
  summaryCount: number;
  distinctSiteCount: number;
  contributingSiteIds: string[];
  schemaVersions: string[];
  runtimeTargets: string[];
  optimizerStrategies: string[];
  compatibilityKey: string;
  warmStartPackageId?: string;
  warmStartModelVersion?: string;
  maxVectorLength: number;
  totalPayloadBytes: number;
  averageUpdateNorm: number;
  contributionDetails: FederatedLearningContributionDetail[];
  siteContributionSummaries: FederatedLearningSiteContributionSummary[];
}

function asTrimmedString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function asFiniteNumber(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string' && value.trim().length > 0) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function normalizedCompatibilityValue(value: string | null | undefined): string {
  const trimmed = typeof value === 'string' ? value.trim() : '';
  return trimmed.length > 0 ? trimmed : '__none__';
}

export function normalizeFederatedLearningMergeStrategy(
  value: unknown,
): FederatedLearningMergeStrategy | null {
  const normalized = asTrimmedString(value).toLowerCase();
  if (
    normalized === FEDERATED_LEARNING_MERGE_STRATEGY ||
    normalized === 'norm_capped_weighted_average' ||
    normalized === 'weighted_average' ||
    normalized === 'sample_weighted'
  ) {
    return FEDERATED_LEARNING_MERGE_STRATEGY;
  }
  if (
    normalized === FEDERATED_LEARNING_SUMMARY_BALANCED_MERGE_STRATEGY ||
    normalized === 'summary_balanced' ||
    normalized === 'summary_balanced_average'
  ) {
    return FEDERATED_LEARNING_SUMMARY_BALANCED_MERGE_STRATEGY;
  }
  return null;
}

function resolveFederatedLearningBaseWeight(
  candidate: Pick<FederatedLearningAggregationCandidate, 'sampleCount'>,
  mergeStrategy: FederatedLearningMergeStrategy,
): number {
  if (mergeStrategy === FEDERATED_LEARNING_SUMMARY_BALANCED_MERGE_STRATEGY) {
    return candidate.sampleCount > 0 ? 1 : 0;
  }
  return Math.max(0, candidate.sampleCount);
}

function buildFederatedLearningAggregationCompatibilityKey(
  candidate: Pick<
    FederatedLearningAggregationCandidate,
    | 'schemaVersion'
    | 'runtimeTarget'
    | 'optimizerStrategy'
    | 'warmStartPackageId'
    | 'warmStartModelVersion'
    | 'vectorLength'
  >,
): string {
  return [
    normalizedCompatibilityValue(candidate.schemaVersion),
    normalizedCompatibilityValue(candidate.runtimeTarget),
    normalizedCompatibilityValue(candidate.optimizerStrategy),
    normalizedCompatibilityValue(candidate.warmStartPackageId),
    normalizedCompatibilityValue(candidate.warmStartModelVersion),
    String(candidate.vectorLength),
  ].join('|');
}

function asIntegerInRange(
  value: unknown,
  fieldName: string,
  min: number,
  max: number,
  fallback: number,
): number {
  const parsed = value === undefined ? fallback : asFiniteNumber(value);
  const candidate = parsed === null ? Number.NaN : parsed;
  if (!Number.isInteger(candidate) || candidate < min || candidate > max) {
    throw new Error(`${fieldName} must be an integer between ${min} and ${max}.`);
  }
  return candidate;
}

function normalizeFederatedLearningVectorSketch(
  value: unknown,
  fieldName: string,
  maxLength = 24,
): number[] {
  if (!Array.isArray(value)) {
    throw new Error(`${fieldName} must be an array.`);
  }
  if (value.length === 0 || value.length > maxLength) {
    throw new Error(`${fieldName} must contain between 1 and ${maxLength} values.`);
  }
  return value.map((entry, index) => {
    const parsed = asFiniteNumber(entry);
    if (parsed === null || parsed < -1000 || parsed > 1000) {
      throw new Error(`${fieldName}[${index}] must be a finite number between -1000 and 1000.`);
    }
    return Number(parsed.toFixed(6));
  });
}

export function normalizeFederatedLearningRuntimeTarget(
  value: unknown,
): FederatedLearningRuntimeTarget | null {
  const normalized = asTrimmedString(value).toLowerCase();
  if (['flutter_mobile', 'flutter-mobile', 'flutter'].includes(normalized)) {
    return 'flutter_mobile';
  }
  if (['web_pwa', 'web-pwa', 'web'].includes(normalized)) {
    return 'web_pwa';
  }
  if (normalized === 'hybrid') {
    return 'hybrid';
  }
  return null;
}

export function normalizeFederatedLearningExperimentStatus(
  value: unknown,
): FederatedLearningExperimentStatus | null {
  const normalized = asTrimmedString(value).toLowerCase();
  if (['draft', 'pilot_ready', 'pilot-ready', 'active', 'paused', 'disabled'].includes(normalized)) {
    if (normalized === 'pilot-ready') return 'pilot_ready';
    return normalized as FederatedLearningExperimentStatus;
  }
  return null;
}

export function normalizeFederatedLearningBatteryState(
  value: unknown,
): FederatedLearningBatteryState {
  const normalized = asTrimmedString(value).toLowerCase();
  if (normalized === 'low' || normalized === 'ok' || normalized === 'charging') {
    return normalized;
  }
  return 'unknown';
}

export function normalizeFederatedLearningNetworkType(
  value: unknown,
): FederatedLearningNetworkType {
  const normalized = asTrimmedString(value).toLowerCase();
  if (normalized === 'wifi' || normalized === 'cellular' || normalized === 'offline') {
    return normalized;
  }
  return 'unknown';
}

export function normalizeFederatedLearningSiteIds(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return Array.from(new Set(value
    .map((entry) => asTrimmedString(entry))
    .filter((entry) => entry.length > 0)));
}

export function buildFederatedLearningExperimentDocId(nameOrId: string): string {
  const normalized = nameOrId.trim().toLowerCase().replace(/[^a-z0-9_-]+/g, '_').replace(/^_+|_+$/g, '');
  const suffix = normalized.length > 0 ? normalized.slice(0, 72) : 'prototype';
  return `fl_exp_${suffix}`;
}

export function buildFederatedLearningFeatureFlagId(experimentId: string): string {
  return `feature_${experimentId.trim().replace(/[^a-zA-Z0-9_-]/g, '_')}`;
}

export function buildFederatedLearningExperimentReviewRecordDocId(experimentId: string): string {
  return `fl_review_${experimentId.replace(/^fl_exp_/, '')}`;
}

export function buildFederatedLearningAggregationRunDocId(
  experimentId: string,
  summaryIds: string[],
): string {
  const digest = createHash('sha256')
    .update(`${experimentId}|${summaryIds.join('|')}`)
    .digest('hex')
    .slice(0, 24);
  return `fl_agg_${digest}`;
}

export function buildFederatedLearningMergeArtifactDocId(runId: string): string {
  return `fl_merge_${runId.replace(/^fl_agg_/, '')}`;
}

export function buildFederatedLearningCandidateModelPackageDocId(runId: string): string {
  return `fl_pkg_${runId.replace(/^fl_agg_/, '')}`;
}

export function buildFederatedLearningCandidatePromotionRecordDocId(packageId: string): string {
  return `fl_prom_${packageId.replace(/^fl_pkg_/, '')}`;
}

export function buildFederatedLearningCandidatePromotionRevocationRecordDocId(packageId: string): string {
  return `fl_prom_revoke_${packageId.replace(/^fl_pkg_/, '')}`;
}

export function buildFederatedLearningPilotEvidenceRecordDocId(packageId: string): string {
  return `fl_pilot_${packageId.replace(/^fl_pkg_/, '')}`;
}

export function buildFederatedLearningPilotApprovalRecordDocId(packageId: string): string {
  return `fl_pilot_approval_${packageId.replace(/^fl_pkg_/, '')}`;
}

export function buildFederatedLearningPilotExecutionRecordDocId(packageId: string): string {
  return `fl_pilot_execution_${packageId.replace(/^fl_pkg_/, '')}`;
}

export function buildFederatedLearningRuntimeDeliveryRecordDocId(packageId: string): string {
  return `fl_delivery_${packageId.replace(/^fl_pkg_/, '')}`;
}

export function buildFederatedLearningRuntimeActivationRecordDocId(deliveryId: string, siteId: string): string {
  const digest = createHash('sha256')
    .update(`${deliveryId}|${siteId.trim()}`)
    .digest('hex')
    .slice(0, 24);
  return `fl_activation_${digest}`;
}

export function buildFederatedLearningRuntimeRolloutAlertRecordDocId(deliveryId: string): string {
  return `fl_rollout_alert_${deliveryId.replace(/^fl_delivery_/, '')}`;
}

export function buildFederatedLearningRuntimeRolloutEscalationRecordDocId(deliveryId: string): string {
  return `fl_rollout_escalation_${deliveryId.replace(/^fl_delivery_/, '')}`;
}

export function buildFederatedLearningRuntimeRolloutControlRecordDocId(deliveryId: string): string {
  return `fl_rollout_control_${deliveryId.replace(/^fl_delivery_/, '')}`;
}

export function buildFederatedLearningRuntimeDeliveryManifestDigest(
  packageDigest: string,
  targetSiteIds: string[],
  status: FederatedLearningRuntimeDeliveryStatus,
  runtimeTarget: FederatedLearningRuntimeTarget,
  expiresAt?: number,
): string {
  const lifecycleSuffix = expiresAt == null ? '' : `|${expiresAt}`;
  const digest = createHash('sha256')
    .update(`${packageDigest}|${runtimeTarget}|${status}|${targetSiteIds.join('|')}${lifecycleSuffix}`)
    .digest('hex')
    .slice(0, 24);
  return `sha256:${digest}`;
}

export function normalizeFederatedLearningExperimentReviewStatus(
  value: unknown,
): FederatedLearningExperimentReviewStatus | null {
  const normalized = asTrimmedString(value).toLowerCase();
  if (normalized === 'pending') return 'pending';
  if (normalized === 'approved') return 'approved';
  if (normalized === 'blocked') return 'blocked';
  return null;
}

export function normalizeFederatedLearningCandidatePromotionStatus(
  value: unknown,
): FederatedLearningCandidatePromotionStatus | null {
  const normalized = asTrimmedString(value).toLowerCase();
  if (normalized === 'approved_for_eval' || normalized === 'approved-for-eval') {
    return 'approved_for_eval';
  }
  if (normalized === 'hold') {
    return 'hold';
  }
  return null;
}

export function normalizeFederatedLearningCandidatePromotionTarget(
  value: unknown,
): FederatedLearningCandidatePromotionTarget | null {
  const normalized = asTrimmedString(value).toLowerCase();
  if (normalized === 'sandbox_eval' || normalized === 'sandbox-eval') {
    return 'sandbox_eval';
  }
  return null;
}

export function normalizeFederatedLearningPilotEvidenceStatus(
  value: unknown,
): FederatedLearningPilotEvidenceStatus | null {
  const normalized = asTrimmedString(value).toLowerCase();
  if (normalized === 'pending') return 'pending';
  if (normalized === 'ready_for_pilot' || normalized === 'ready-for-pilot') {
    return 'ready_for_pilot';
  }
  if (normalized === 'blocked') return 'blocked';
  return null;
}

export function normalizeFederatedLearningPilotApprovalStatus(
  value: unknown,
): FederatedLearningPilotApprovalStatus | null {
  const normalized = asTrimmedString(value).toLowerCase();
  if (normalized === 'pending') return 'pending';
  if (normalized === 'approved') return 'approved';
  if (normalized === 'blocked') return 'blocked';
  return null;
}

export function normalizeFederatedLearningPilotExecutionStatus(
  value: unknown,
): FederatedLearningPilotExecutionStatus | null {
  const normalized = asTrimmedString(value).toLowerCase();
  if (normalized === 'planned') return 'planned';
  if (normalized === 'launched') return 'launched';
  if (normalized === 'observed') return 'observed';
  if (normalized === 'completed') return 'completed';
  return null;
}

export function normalizeFederatedLearningRuntimeDeliveryStatus(
  value: unknown,
): FederatedLearningRuntimeDeliveryStatus | null {
  const normalized = asTrimmedString(value).toLowerCase();
  if (normalized === 'prepared') return 'prepared';
  if (normalized === 'assigned') return 'assigned';
  if (normalized === 'active') return 'active';
  if (normalized === 'superseded' || normalized === 'supersede') return 'superseded';
  if (normalized === 'revoked') return 'revoked';
  return null;
}

export function normalizeFederatedLearningRuntimeActivationStatus(
  value: unknown,
): FederatedLearningRuntimeActivationStatus | null {
  const normalized = asTrimmedString(value).toLowerCase();
  if (normalized === 'resolved') return 'resolved';
  if (normalized === 'staged') return 'staged';
  if (normalized === 'fallback') return 'fallback';
  return null;
}

export function normalizeFederatedLearningRuntimeRolloutAlertStatus(
  value: unknown,
): 'active' | 'acknowledged' | null {
  const normalized = asTrimmedString(value).toLowerCase();
  if (normalized === 'active') return 'active';
  if (normalized === 'acknowledged' || normalized === 'acknowledge') {
    return 'acknowledged';
  }
  return null;
}

export function normalizeFederatedLearningRuntimeRolloutEscalationStatus(
  value: unknown,
): 'open' | 'investigating' | 'resolved' | null {
  const normalized = asTrimmedString(value).toLowerCase();
  if (normalized === 'open') return 'open';
  if (normalized === 'investigating' || normalized === 'in_progress') {
    return 'investigating';
  }
  if (normalized === 'resolved' || normalized === 'closed') {
    return 'resolved';
  }
  return null;
}

export function normalizeFederatedLearningRuntimeRolloutControlMode(
  value: unknown,
): FederatedLearningRuntimeRolloutControlMode | null {
  const normalized = asTrimmedString(value).toLowerCase();
  if (normalized === 'monitor') return 'monitor';
  if (normalized === 'restricted' || normalized === 'restrict') {
    return 'restricted';
  }
  if (normalized === 'paused' || normalized === 'pause') {
    return 'paused';
  }
  return null;
}

export function federatedLearningAuditAction(action: string): string {
  return `federated_learning.${action.trim().replace(/\s+/g, '_')}`;
}

export function sanitizeFederatedLearningExperimentConfig(
  input: Record<string, unknown>,
): FederatedLearningExperimentConfig {
  const name = asTrimmedString(input.name);
  if (!name) {
    throw new Error('name is required.');
  }

  const runtimeTarget = normalizeFederatedLearningRuntimeTarget(input.runtimeTarget);
  if (!runtimeTarget) {
    throw new Error('runtimeTarget must be flutter_mobile, web_pwa, or hybrid.');
  }

  const status = normalizeFederatedLearningExperimentStatus(input.status) ?? 'draft';
  const mergeStrategy = normalizeFederatedLearningMergeStrategy(input.mergeStrategy) ??
    FEDERATED_LEARNING_MERGE_STRATEGY;
  const allowedSiteIds = normalizeFederatedLearningSiteIds(input.allowedSiteIds);
  const aggregateThreshold = asIntegerInRange(input.aggregateThreshold, 'aggregateThreshold', 5, 10000, 25);
  const rawUpdateMaxBytes = asIntegerInRange(input.rawUpdateMaxBytes, 'rawUpdateMaxBytes', 256, 262144, 16384);
  const enablePrototypeUploads = input.enablePrototypeUploads === true;

  if ((status === 'pilot_ready' || status === 'active') && allowedSiteIds.length === 0) {
    throw new Error('allowedSiteIds are required when status is pilot_ready or active.');
  }

  return {
    name,
    description: asTrimmedString(input.description),
    runtimeTarget,
    status,
    mergeStrategy,
    allowedSiteIds,
    aggregateThreshold,
    rawUpdateMaxBytes,
    enablePrototypeUploads,
  };
}

export function buildFederatedLearningFeatureFlagPayload(
  experimentId: string,
  config: FederatedLearningExperimentConfig,
): Record<string, unknown> {
  return {
    name: `Federated Learning Prototype: ${config.name}`,
    description: config.description || `Prototype gate for ${config.name}`,
    enabled: config.enablePrototypeUploads && (config.status === 'pilot_ready' || config.status === 'active'),
    status: config.enablePrototypeUploads && (config.status === 'pilot_ready' || config.status === 'active')
      ? 'enabled'
      : 'disabled',
    scope: 'site',
    enabledSites: config.allowedSiteIds,
    experimentId,
  };
}

export function sanitizeFederatedLearningUpdateSummary(
  input: Record<string, unknown>,
  rawUpdateMaxBytes: number,
): FederatedLearningUpdateSummary {
  const forbiddenFields = ['prompt', 'transcript', 'messageBody', 'artifactBody', 'rawUpdate', 'gradientValues'];
  for (const field of forbiddenFields) {
    if (field in input) {
      throw new Error(`${field} is not allowed in prototype update summaries.`);
    }
  }

  const siteId = asTrimmedString(input.siteId);
  const traceId = asTrimmedString(input.traceId);
  const schemaVersion = asTrimmedString(input.schemaVersion);
  const payloadDigest = asTrimmedString(input.payloadDigest);
  if (!siteId) throw new Error('siteId is required.');
  if (!traceId) throw new Error('traceId is required.');
  if (!schemaVersion) throw new Error('schemaVersion is required.');
  if (!payloadDigest) throw new Error('payloadDigest is required.');

  const sampleCount = asIntegerInRange(input.sampleCount, 'sampleCount', 1, 10000, 1);
  const vectorLength = asIntegerInRange(input.vectorLength, 'vectorLength', 1, 100000, 1);
  const vectorSketch = normalizeFederatedLearningVectorSketch(input.vectorSketch, 'vectorSketch');
  if (vectorSketch.length !== vectorLength) {
    throw new Error('vectorLength must match vectorSketch length.');
  }
  const payloadBytes = asIntegerInRange(input.payloadBytes, 'payloadBytes', 1, rawUpdateMaxBytes, 1);
  const updateNorm = asFiniteNumber(input.updateNorm);
  if (updateNorm === null || updateNorm < 0 || updateNorm > 1000000) {
    throw new Error('updateNorm must be a finite number between 0 and 1000000.');
  }
  const optimizerStrategy = asTrimmedString(input.optimizerStrategy);
  const localEpochCount = input.localEpochCount == null
    ? undefined
    : asIntegerInRange(input.localEpochCount, 'localEpochCount', 0, 1000, 0);
  const localStepCount = input.localStepCount == null
    ? undefined
    : asIntegerInRange(input.localStepCount, 'localStepCount', 0, 100000, 0);
  const trainingWindowSeconds = input.trainingWindowSeconds == null
    ? undefined
    : asIntegerInRange(input.trainingWindowSeconds, 'trainingWindowSeconds', 0, 86400, 0);
  const warmStartPackageId = asTrimmedString(input.warmStartPackageId);
  const warmStartDeliveryRecordId = asTrimmedString(input.warmStartDeliveryRecordId);
  const warmStartModelVersion = asTrimmedString(input.warmStartModelVersion);

  return {
    siteId,
    traceId,
    schemaVersion,
    sampleCount,
    vectorLength,
    vectorSketch,
    payloadBytes,
    updateNorm,
    payloadDigest,
    optimizerStrategy: optimizerStrategy.length == 0 ? undefined : optimizerStrategy,
    localEpochCount,
    localStepCount,
    trainingWindowSeconds,
    warmStartPackageId:
      warmStartPackageId.length == 0 ? undefined : warmStartPackageId,
    warmStartDeliveryRecordId: warmStartDeliveryRecordId.length == 0
      ? undefined
      : warmStartDeliveryRecordId,
    warmStartModelVersion:
      warmStartModelVersion.length == 0 ? undefined : warmStartModelVersion,
    batteryState: normalizeFederatedLearningBatteryState(input.batteryState),
    networkType: normalizeFederatedLearningNetworkType(input.networkType),
  };
}

export function selectFederatedLearningAggregationBatch(
  candidates: FederatedLearningAggregationCandidate[],
  aggregateThreshold: number,
): FederatedLearningAggregationSelection | null {
  const threshold = asIntegerInRange(
    aggregateThreshold,
    'aggregateThreshold',
    1,
    1000000,
    1,
  );
  const selected: FederatedLearningAggregationCandidate[] = [];
  let totalSampleCount = 0;
  let compatibilityKey = '';
  for (const candidate of candidates) {
    if (candidate.sampleCount <= 0) continue;
    const candidateCompatibilityKey = buildFederatedLearningAggregationCompatibilityKey(candidate);
    if (!compatibilityKey) {
      compatibilityKey = candidateCompatibilityKey;
    }
    if (candidateCompatibilityKey !== compatibilityKey) {
      continue;
    }
    selected.push(candidate);
    totalSampleCount += candidate.sampleCount;
    if (totalSampleCount >= threshold) {
      break;
    }
  }
  if (totalSampleCount < threshold || selected.length === 0) {
    return null;
  }

  const siteIds = new Set<string>();
  const schemaVersions = new Set<string>();
  const runtimeTargets = new Set<string>();
  const optimizerStrategies = new Set<string>();
  let totalPayloadBytes = 0;
  let maxVectorLength = 0;
  let updateNormTotal = 0;

  for (const candidate of selected) {
    siteIds.add(candidate.siteId);
    schemaVersions.add(candidate.schemaVersion);
    if (typeof candidate.runtimeTarget === 'string' && candidate.runtimeTarget.trim().length > 0) {
      runtimeTargets.add(candidate.runtimeTarget.trim());
    }
    if (typeof candidate.optimizerStrategy === 'string' && candidate.optimizerStrategy.trim().length > 0) {
      optimizerStrategies.add(candidate.optimizerStrategy.trim());
    }
    totalPayloadBytes += candidate.payloadBytes;
    maxVectorLength = Math.max(maxVectorLength, candidate.vectorLength);
    updateNormTotal += candidate.updateNorm;
  }

  const firstSelected = selected[0];
  const warmStartPackageId = typeof firstSelected?.warmStartPackageId === 'string' &&
    firstSelected.warmStartPackageId.trim().length > 0
    ? firstSelected.warmStartPackageId.trim()
    : undefined;
  const warmStartModelVersion = typeof firstSelected?.warmStartModelVersion === 'string' &&
    firstSelected.warmStartModelVersion.trim().length > 0
    ? firstSelected.warmStartModelVersion.trim()
    : undefined;

  return {
    summaryIds: selected.map((candidate) => candidate.id),
    summaryCount: selected.length,
    distinctSiteCount: siteIds.size,
    contributingSiteIds: Array.from(siteIds).sort(),
    totalSampleCount,
    maxVectorLength,
    totalPayloadBytes,
    averageUpdateNorm: selected.length > 0 ? Number((updateNormTotal / selected.length).toFixed(6)) : 0,
    schemaVersions: Array.from(schemaVersions).sort(),
    runtimeTargets: Array.from(runtimeTargets).sort(),
    optimizerStrategies: Array.from(optimizerStrategies).sort(),
    compatibilityKey,
    warmStartPackageId,
    warmStartModelVersion,
  };
}

export function buildFederatedLearningMergedRuntimeVector(
  candidates: Array<
    Pick<
      FederatedLearningAggregationCandidate,
      'sampleCount' | 'vectorSketch' | 'updateNorm'
    >
  >,
  vectorLength: number,
  mergeStrategy: FederatedLearningMergeStrategy = FEDERATED_LEARNING_MERGE_STRATEGY,
): number[] {
  const boundedLength = asIntegerInRange(vectorLength, 'vectorLength', 1, 100000, 1);
  const merged = Array.from({ length: boundedLength }, () => 0);
  let totalWeight = 0;
  const mergeWeights = buildFederatedLearningMergeWeightSummary(candidates, mergeStrategy);

  for (const candidate of candidates) {
    const baseWeight = resolveFederatedLearningBaseWeight(candidate, mergeStrategy);
    const normScale = candidate.updateNorm > 0
      ? Math.min(1, mergeWeights.normCap / candidate.updateNorm)
      : 1;
    const weight = Number((baseWeight * normScale).toFixed(6));
    if (weight <= 0) continue;
    totalWeight += weight;
    for (let index = 0; index < boundedLength; index += 1) {
      merged[index] += (candidate.vectorSketch[index] ?? 0) * weight;
    }
  }

  if (totalWeight <= 0) {
    return merged;
  }

  return merged.map((value) => Number((value / totalWeight).toFixed(6)));
}

export function buildFederatedLearningMergeWeightSummary(
  candidates: Array<Pick<FederatedLearningAggregationCandidate, 'sampleCount' | 'updateNorm'>>,
  mergeStrategy: FederatedLearningMergeStrategy = FEDERATED_LEARNING_MERGE_STRATEGY,
): FederatedLearningMergeWeightSummary {
  const positiveNorms = candidates
    .map((candidate) => candidate.updateNorm)
    .filter((value): value is number => Number.isFinite(value) && value > 0);
  const normReference = positiveNorms.length === 0
    ? 1
    : Math.exp(
      positiveNorms.reduce((sum, value) => sum + Math.log(value), 0) /
        positiveNorms.length,
    );
  const normCap = Math.max(1, Number((normReference * 2).toFixed(6)));
  const finiteNorms = candidates
    .map((candidate) => candidate.updateNorm)
    .filter((value): value is number => Number.isFinite(value) && value >= 0);
  let rawTotalWeight = 0;
  let effectiveWeightAccumulator = 0;
  let dampedSummaryCount = 0;

  for (const candidate of candidates) {
    const baseWeight = resolveFederatedLearningBaseWeight(candidate, mergeStrategy);
    const normScale = candidate.updateNorm > 0
      ? Math.min(1, normCap / candidate.updateNorm)
      : 1;
    rawTotalWeight += baseWeight;
    effectiveWeightAccumulator += baseWeight * normScale;
    if (baseWeight > 0 && normScale < 0.999999) {
      dampedSummaryCount += 1;
    }
  }

  const effectiveTotalWeight = Number(effectiveWeightAccumulator.toFixed(6));
  return {
    normCap,
    effectiveTotalWeight,
    rawTotalWeight: Number(rawTotalWeight.toFixed(6)),
    dampedSummaryCount,
    minUpdateNorm: finiteNorms.length > 0 ? Number(Math.min(...finiteNorms).toFixed(6)) : 0,
    maxUpdateNorm: finiteNorms.length > 0 ? Number(Math.max(...finiteNorms).toFixed(6)) : 0,
  };
}

export function buildFederatedLearningContributionDetails(
  candidates: Array<
    Pick<
      FederatedLearningAggregationCandidate,
      | 'id'
      | 'siteId'
      | 'sampleCount'
      | 'payloadBytes'
      | 'vectorLength'
      | 'updateNorm'
      | 'schemaVersion'
      | 'runtimeTarget'
      | 'traceId'
      | 'payloadDigest'
    >
  >,
  normCap: number,
  mergeStrategy: FederatedLearningMergeStrategy = FEDERATED_LEARNING_MERGE_STRATEGY,
): FederatedLearningContributionDetail[] {
  return candidates.map((candidate) => {
    const rawWeight = Number(resolveFederatedLearningBaseWeight(candidate, mergeStrategy).toFixed(6));
    const normScale = candidate.updateNorm > 0
      ? Number(Math.min(1, normCap / candidate.updateNorm).toFixed(6))
      : 1;
    const effectiveWeight = Number((rawWeight * normScale).toFixed(6));
    return {
      summaryId: candidate.id,
      siteId: candidate.siteId,
      sampleCount: candidate.sampleCount,
      payloadBytes: candidate.payloadBytes,
      vectorLength: candidate.vectorLength,
      updateNorm: Number(candidate.updateNorm.toFixed(6)),
      schemaVersion: candidate.schemaVersion,
      runtimeTarget: candidate.runtimeTarget ?? undefined,
      traceId: candidate.traceId ?? undefined,
      payloadDigest: candidate.payloadDigest ?? undefined,
      rawWeight,
      normScale,
      effectiveWeight,
    };
  });
}

export function buildFederatedLearningSiteContributionSummaries(
  details: FederatedLearningContributionDetail[],
): FederatedLearningSiteContributionSummary[] {
  const perSite = new Map<string, FederatedLearningSiteContributionSummary>();
  for (const detail of details) {
    const existing = perSite.get(detail.siteId);
    if (existing) {
      existing.summaryCount += 1;
      existing.totalSampleCount += detail.sampleCount;
      existing.totalPayloadBytes += detail.payloadBytes;
      existing.rawWeight = Number((existing.rawWeight + detail.rawWeight).toFixed(6));
      existing.effectiveWeight = Number((existing.effectiveWeight + detail.effectiveWeight).toFixed(6));
      existing.dampedSummaryCount += detail.normScale < 0.999999 ? 1 : 0;
      existing.minUpdateNorm = Number(Math.min(existing.minUpdateNorm, detail.updateNorm).toFixed(6));
      existing.maxUpdateNorm = Number(Math.max(existing.maxUpdateNorm, detail.updateNorm).toFixed(6));
      continue;
    }

    perSite.set(detail.siteId, {
      siteId: detail.siteId,
      summaryCount: 1,
      totalSampleCount: detail.sampleCount,
      totalPayloadBytes: detail.payloadBytes,
      rawWeight: detail.rawWeight,
      effectiveWeight: detail.effectiveWeight,
      dampedSummaryCount: detail.normScale < 0.999999 ? 1 : 0,
      minUpdateNorm: detail.updateNorm,
      maxUpdateNorm: detail.updateNorm,
    });
  }

  return Array.from(perSite.values()).sort((left, right) => {
    if (right.effectiveWeight !== left.effectiveWeight) {
      return right.effectiveWeight - left.effectiveWeight;
    }
    return left.siteId.localeCompare(right.siteId);
  });
}

export function buildFederatedLearningMergeArtifactSummary(
  triggerSummaryId: string,
  selection: FederatedLearningAggregationSelection,
  runtimeVector: number[],
  mergeWeights: FederatedLearningMergeWeightSummary,
  contributionDetails: FederatedLearningContributionDetail[],
  mergeStrategy: FederatedLearningMergeStrategy = FEDERATED_LEARNING_MERGE_STRATEGY,
): FederatedLearningMergeArtifactSummary {
  const siteContributionSummaries =
    buildFederatedLearningSiteContributionSummaries(contributionDetails);
  const payloadFormat = 'runtime_vector_v1';
  const modelVersion = 'fl_runtime_model_v1';
  const normalizedRuntimeVector = runtimeVector.map((value) => Number(value.toFixed(6)));
  const runtimeVectorDigest = createHash('sha256')
    .update(JSON.stringify({
      payloadFormat,
      modelVersion,
      runtimeVector: normalizedRuntimeVector,
    }))
    .digest('hex');
  const boundedDigest = createHash('sha256')
    .update(JSON.stringify({
      triggerSummaryId,
      summaryIds: selection.summaryIds,
      mergeStrategy,
      normCap: mergeWeights.normCap,
      effectiveTotalWeight: mergeWeights.effectiveTotalWeight,
      rawTotalWeight: mergeWeights.rawTotalWeight,
      dampedSummaryCount: mergeWeights.dampedSummaryCount,
      minUpdateNorm: mergeWeights.minUpdateNorm,
      maxUpdateNorm: mergeWeights.maxUpdateNorm,
      totalSampleCount: selection.totalSampleCount,
      summaryCount: selection.summaryCount,
      distinctSiteCount: selection.distinctSiteCount,
      contributingSiteIds: selection.contributingSiteIds,
      maxVectorLength: selection.maxVectorLength,
      payloadFormat,
      modelVersion,
      compatibilityKey: selection.compatibilityKey,
      optimizerStrategies: selection.optimizerStrategies,
      warmStartPackageId: selection.warmStartPackageId,
      warmStartModelVersion: selection.warmStartModelVersion,
      runtimeVector: normalizedRuntimeVector,
      runtimeVectorDigest: `sha256:${runtimeVectorDigest}`,
      totalPayloadBytes: selection.totalPayloadBytes,
      averageUpdateNorm: selection.averageUpdateNorm,
      schemaVersions: selection.schemaVersions,
      runtimeTargets: selection.runtimeTargets,
      contributionDetails,
      siteContributionSummaries,
    }))
    .digest('hex');

  return {
    mergeStrategy,
    normCap: mergeWeights.normCap,
    effectiveTotalWeight: mergeWeights.effectiveTotalWeight,
    rawTotalWeight: mergeWeights.rawTotalWeight,
    dampedSummaryCount: mergeWeights.dampedSummaryCount,
    minUpdateNorm: mergeWeights.minUpdateNorm,
    maxUpdateNorm: mergeWeights.maxUpdateNorm,
    triggerSummaryId,
    summaryIds: selection.summaryIds,
    payloadFormat,
    modelVersion,
    sampleCount: selection.totalSampleCount,
    summaryCount: selection.summaryCount,
    distinctSiteCount: selection.distinctSiteCount,
    contributingSiteIds: selection.contributingSiteIds,
    schemaVersions: selection.schemaVersions,
    runtimeTargets: selection.runtimeTargets,
    optimizerStrategies: selection.optimizerStrategies,
    compatibilityKey: selection.compatibilityKey,
    warmStartPackageId: selection.warmStartPackageId,
    warmStartModelVersion: selection.warmStartModelVersion,
    maxVectorLength: selection.maxVectorLength,
    runtimeVectorLength: normalizedRuntimeVector.length,
    runtimeVector: normalizedRuntimeVector,
    runtimeVectorDigest: `sha256:${runtimeVectorDigest}`,
    totalPayloadBytes: selection.totalPayloadBytes,
    averageUpdateNorm: selection.averageUpdateNorm,
    boundedDigest: `sha256:${boundedDigest}`,
    contributionDetails,
    siteContributionSummaries,
  };
}

export function buildFederatedLearningCandidateModelPackageSummary(
  runId: string,
  artifactId: string,
  artifactSummary: FederatedLearningMergeArtifactSummary,
): FederatedLearningCandidateModelPackageSummary {
  const packageFormat = artifactSummary.payloadFormat;
  const rolloutStatus = 'not_distributed';
  const packageDigest = createHash('sha256')
    .update(JSON.stringify({
      runId,
      artifactId,
      mergeStrategy: artifactSummary.mergeStrategy,
      normCap: artifactSummary.normCap,
      effectiveTotalWeight: artifactSummary.effectiveTotalWeight,
      rawTotalWeight: artifactSummary.rawTotalWeight,
      dampedSummaryCount: artifactSummary.dampedSummaryCount,
      minUpdateNorm: artifactSummary.minUpdateNorm,
      maxUpdateNorm: artifactSummary.maxUpdateNorm,
      triggerSummaryId: artifactSummary.triggerSummaryId,
      summaryIds: artifactSummary.summaryIds,
      packageFormat,
      rolloutStatus,
      modelVersion: artifactSummary.modelVersion,
      boundedDigest: artifactSummary.boundedDigest,
      runtimeVectorLength: artifactSummary.runtimeVectorLength,
      runtimeVector: artifactSummary.runtimeVector,
      runtimeVectorDigest: artifactSummary.runtimeVectorDigest,
      sampleCount: artifactSummary.sampleCount,
      summaryCount: artifactSummary.summaryCount,
      distinctSiteCount: artifactSummary.distinctSiteCount,
      contributingSiteIds: artifactSummary.contributingSiteIds,
      schemaVersions: artifactSummary.schemaVersions,
      runtimeTargets: artifactSummary.runtimeTargets,
      optimizerStrategies: artifactSummary.optimizerStrategies,
      compatibilityKey: artifactSummary.compatibilityKey,
      warmStartPackageId: artifactSummary.warmStartPackageId,
      warmStartModelVersion: artifactSummary.warmStartModelVersion,
      maxVectorLength: artifactSummary.maxVectorLength,
      totalPayloadBytes: artifactSummary.totalPayloadBytes,
      averageUpdateNorm: artifactSummary.averageUpdateNorm,
      contributionDetails: artifactSummary.contributionDetails,
      siteContributionSummaries: artifactSummary.siteContributionSummaries,
    }))
    .digest('hex');

  return {
    mergeStrategy: artifactSummary.mergeStrategy,
    normCap: artifactSummary.normCap,
    effectiveTotalWeight: artifactSummary.effectiveTotalWeight,
    rawTotalWeight: artifactSummary.rawTotalWeight,
    dampedSummaryCount: artifactSummary.dampedSummaryCount,
    minUpdateNorm: artifactSummary.minUpdateNorm,
    maxUpdateNorm: artifactSummary.maxUpdateNorm,
    triggerSummaryId: artifactSummary.triggerSummaryId,
    summaryIds: artifactSummary.summaryIds,
    packageFormat,
    rolloutStatus,
    modelVersion: artifactSummary.modelVersion,
    packageDigest: `sha256:${packageDigest}`,
    boundedDigest: artifactSummary.boundedDigest,
    runtimeVectorLength: artifactSummary.runtimeVectorLength,
    runtimeVector: artifactSummary.runtimeVector,
    runtimeVectorDigest: artifactSummary.runtimeVectorDigest,
    sampleCount: artifactSummary.sampleCount,
    summaryCount: artifactSummary.summaryCount,
    distinctSiteCount: artifactSummary.distinctSiteCount,
    contributingSiteIds: artifactSummary.contributingSiteIds,
    schemaVersions: artifactSummary.schemaVersions,
    runtimeTargets: artifactSummary.runtimeTargets,
    optimizerStrategies: artifactSummary.optimizerStrategies,
    compatibilityKey: artifactSummary.compatibilityKey,
    warmStartPackageId: artifactSummary.warmStartPackageId,
    warmStartModelVersion: artifactSummary.warmStartModelVersion,
    maxVectorLength: artifactSummary.maxVectorLength,
    totalPayloadBytes: artifactSummary.totalPayloadBytes,
    averageUpdateNorm: artifactSummary.averageUpdateNorm,
    contributionDetails: artifactSummary.contributionDetails,
    siteContributionSummaries: artifactSummary.siteContributionSummaries,
  };
}