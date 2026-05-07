import fs from 'fs';
import path from 'path';

type FirestoreIndexField = {
  fieldPath?: string;
  order?: string;
  arrayConfig?: string;
};

type FirestoreIndex = {
  collectionGroup?: string;
  fields?: FirestoreIndexField[];
};

const firestoreIndexes = JSON.parse(
  fs.readFileSync(path.join(process.cwd(), 'firestore.indexes.json'), 'utf8')
) as { indexes?: FirestoreIndex[] };

function hasCompositeIndex(collectionGroup: string, fields: FirestoreIndexField[]): boolean {
  return firestoreIndexes.indexes?.some((index) => {
    if (index.collectionGroup !== collectionGroup) return false;
    const indexFields = index.fields ?? [];
    if (indexFields.length !== fields.length) return false;
    return fields.every((field, indexPosition) => {
      const indexField = indexFields[indexPosition];
      return indexField?.fieldPath === field.fieldPath &&
        indexField?.order === field.order &&
        indexField?.arrayConfig === field.arrayConfig;
    });
  }) === true;
}

describe('Firestore composite index coverage', () => {
  it.each([
    ['activities', [{ fieldPath: 'learnerId', order: 'ASCENDING' }, { fieldPath: 'timestamp', order: 'DESCENDING' }]],
    ['auditLogs', [{ fieldPath: 'action', order: 'ASCENDING' }, { fieldPath: 'timestamp', order: 'DESCENDING' }]],
    ['badgeAchievements', [{ fieldPath: 'learnerId', order: 'ASCENDING' }, { fieldPath: 'siteId', order: 'ASCENDING' }]],
    ['capabilityMastery', [{ fieldPath: 'learnerId', order: 'ASCENDING' }, { fieldPath: 'capabilityId', order: 'ASCENDING' }]],
    ['checkins', [{ fieldPath: 'siteId', order: 'ASCENDING' }, { fieldPath: 'type', order: 'ASCENDING' }, { fieldPath: 'timestamp', order: 'ASCENDING' }]],
    ['checkpointHistory', [{ fieldPath: 'learnerId', order: 'ASCENDING' }, { fieldPath: 'createdAt', order: 'DESCENDING' }]],
    ['checkpointHistory', [{ fieldPath: 'learnerId', order: 'ASCENDING' }, { fieldPath: 'isCorrect', order: 'ASCENDING' }]],
    ['cohortLaunches', [{ fieldPath: 'siteId', order: 'ASCENDING' }, { fieldPath: 'updatedAt', order: 'DESCENDING' }]],
    ['educatorLearnerLinks', [{ fieldPath: 'educatorId', order: 'ASCENDING' }, { fieldPath: 'siteId', order: 'ASCENDING' }]],
    ['enrollments', [{ fieldPath: 'learnerId', order: 'ASCENDING' }, { fieldPath: 'status', order: 'ASCENDING' }]],
    ['events', [{ fieldPath: 'learnerId', order: 'ASCENDING' }, { fieldPath: 'dateTime', order: 'ASCENDING' }]],
    ['federatedLearningRuntimeActivationRecords', [{ fieldPath: 'siteId', order: 'ASCENDING' }, { fieldPath: 'updatedAt', order: 'DESCENDING' }]],
    ['federatedLearningRuntimeDeliveryRecords', [{ fieldPath: 'experimentId', order: 'ASCENDING' }, { fieldPath: 'runtimeTarget', order: 'ASCENDING' }]],
    ['federatedLearningUpdateSummaries', [{ fieldPath: 'experimentId', order: 'ASCENDING' }, { fieldPath: 'status', order: 'ASCENDING' }, { fieldPath: 'createdAt', order: 'ASCENDING' }]],
    ['guardianLinks', [{ fieldPath: 'parentId', order: 'ASCENDING' }, { fieldPath: 'siteId', order: 'ASCENDING' }]],
    ['incidents', [{ fieldPath: 'siteId', order: 'ASCENDING' }, { fieldPath: 'status', order: 'ASCENDING' }]],
    ['interactionEvents', [{ fieldPath: 'siteId', order: 'ASCENDING' }, { fieldPath: 'actorId', order: 'ASCENDING' }]],
    ['interactionEvents', [{ fieldPath: 'actorId', order: 'ASCENDING' }, { fieldPath: 'sessionOccurrenceId', order: 'ASCENDING' }, { fieldPath: 'timestamp', order: 'DESCENDING' }]],
    ['interactionEvents', [{ fieldPath: 'eventType', order: 'ASCENDING' }, { fieldPath: 'siteId', order: 'ASCENDING' }, { fieldPath: 'actorId', order: 'ASCENDING' }, { fieldPath: 'traceId', order: 'ASCENDING' }]],
    ['interactionEvents', [{ fieldPath: 'actorId', order: 'ASCENDING' }, { fieldPath: 'siteId', order: 'ASCENDING' }, { fieldPath: 'createdAt', order: 'DESCENDING' }]],
    ['learnerReflections', [{ fieldPath: 'learnerId', order: 'ASCENDING' }, { fieldPath: 'createdAt', order: 'DESCENDING' }]],
    ['ltiPlatformRegistrations', [{ fieldPath: 'issuer', order: 'ASCENDING' }, { fieldPath: 'deploymentId', order: 'ASCENDING' }]],
    ['ltiResourceLinks', [{ fieldPath: 'registrationId', order: 'ASCENDING' }, { fieldPath: 'resourceLinkId', order: 'ASCENDING' }]],
    ['ltiResourceLinks', [{ fieldPath: 'resourceLinkId', order: 'ASCENDING' }, { fieldPath: 'siteId', order: 'ASCENDING' }]],
    ['messages', [{ fieldPath: 'recipientId', order: 'ASCENDING' }, { fieldPath: 'isRead', order: 'ASCENDING' }]],
    ['missionAttempts', [{ fieldPath: 'learnerId', order: 'ASCENDING' }, { fieldPath: 'createdAt', order: 'DESCENDING' }]],
    ['missions', [{ fieldPath: 'siteId', order: 'ASCENDING' }, { fieldPath: 'status', order: 'ASCENDING' }]],
    ['mvlEpisodes', [{ fieldPath: 'siteId', order: 'ASCENDING' }, { fieldPath: 'resolution', order: 'ASCENDING' }]],
    ['mvlEpisodes', [{ fieldPath: 'learnerId', order: 'ASCENDING' }, { fieldPath: 'sessionOccurrenceId', order: 'ASCENDING' }, { fieldPath: 'resolution', order: 'ASCENDING' }]],
    ['mvlEpisodes', [{ fieldPath: 'sessionOccurrenceId', order: 'ASCENDING' }, { fieldPath: 'siteId', order: 'ASCENDING' }, { fieldPath: 'resolution', order: 'ASCENDING' }]],
    ['orchestrationStates', [{ fieldPath: 'sessionOccurrenceId', order: 'ASCENDING' }, { fieldPath: 'siteId', order: 'ASCENDING' }]],
    ['portfolioItems', [{ fieldPath: 'learnerId', order: 'ASCENDING' }, { fieldPath: 'verificationStatus', order: 'ASCENDING' }]],
    ['sessionOccurrences', [{ fieldPath: 'date', order: 'ASCENDING' }, { fieldPath: 'startTime', order: 'ASCENDING' }]],
    ['skillEvidence', [{ fieldPath: 'learnerId', order: 'ASCENDING' }, { fieldPath: 'siteId', order: 'ASCENDING' }]],
    ['skillEvidence', [{ fieldPath: 'learnerId', order: 'ASCENDING' }, { fieldPath: 'microSkillId', order: 'ASCENDING' }]],
    ['syncJobs', [{ fieldPath: 'provider', order: 'ASCENDING' }, { fieldPath: 'idempotencyKey', order: 'ASCENDING' }]],
    ['telemetryEvents', [{ fieldPath: 'siteId', order: 'ASCENDING' }, { fieldPath: 'timestamp', order: 'ASCENDING' }]],
    ['telemetryEvents', [{ fieldPath: 'siteId', order: 'ASCENDING' }, { fieldPath: 'userId', order: 'ASCENDING' }, { fieldPath: 'timestamp', order: 'ASCENDING' }]],
  ] satisfies Array<[string, FirestoreIndexField[]]>)('%s has index %#', (collectionGroup, fields) => {
    expect(hasCompositeIndex(collectionGroup, fields)).toBe(true);
  });
});