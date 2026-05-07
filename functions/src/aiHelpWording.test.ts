import fs from 'node:fs';
import path from 'node:path';

const functionsRoot = __dirname;

function readFunctionsFile(...relativePath: string[]): string {
  return fs.readFileSync(path.join(functionsRoot, ...relativePath), 'utf8');
}

describe('functions MiloOS wording', () => {
  function expectInteractionEventWriteHasCreatedAt(source: string, anchor: string) {
    const anchorIndex = source.indexOf(anchor);
    expect(anchorIndex).toBeGreaterThanOrEqual(0);
    const blockEnd = source.indexOf('});', anchorIndex);
    const writeBlock = source.slice(anchorIndex, blockEnd > anchorIndex ? blockEnd : anchorIndex + 1200);

    expect(writeBlock).toContain('timestamp: FieldValue.serverTimestamp()');
    expect(writeBlock).toContain('createdAt: FieldValue.serverTimestamp()');
  }

  it('keeps learner-facing callable errors on MiloOS wording', () => {
    const indexSource = readFunctionsFile('index.ts');

    expect(indexSource).toContain("'Learner role required for MiloOS.'");
    expect(indexSource).toContain("'MiloOS session not found.'");
    expect(indexSource).toContain("'interactionId must reference a MiloOS session.'");
    expect(indexSource).toContain("'MiloOS session ownership mismatch.'");
    expect(indexSource).not.toContain('Learner role required for AI coach.');
  });

  it('keeps MiloOS learner callables site-scoped before audit writes', () => {
    const indexSource = readFunctionsFile('index.ts');
    const siteAccessGuards = indexSource.match(/if \(!hasSiteAccess\(profile, siteId\)\)/g) ?? [];

    expect(siteAccessGuards.length).toBeGreaterThanOrEqual(2);
    expect(indexSource).toContain("throw new HttpsError('permission-denied', 'Site access denied.');");
  });

  it('keeps MiloOS interaction events readable by learner-loop snapshots', () => {
    const indexSource = readFunctionsFile('index.ts');
    const bosSource = readFunctionsFile('bosRuntime.ts');
    const firestoreIndexes = JSON.parse(readFunctionsFile('..', '..', 'firestore.indexes.json')) as {
      indexes?: Array<{
        collectionGroup?: string;
        fields?: Array<{ fieldPath?: string; order?: string }>;
      }>;
    };
    const hasInteractionEventIndex = (timeField: 'createdAt' | 'timestamp') =>
      firestoreIndexes.indexes?.some((index) => {
        const fields = index.fields ?? [];
        return index.collectionGroup === 'interactionEvents'
          && fields[0]?.fieldPath === 'siteId'
          && fields[1]?.fieldPath === 'actorId'
          && fields[2]?.fieldPath === timeField
          && fields[2]?.order === 'DESCENDING';
      }) === true;

    for (const eventType of [
      "eventType: 'mvl_gate_triggered'",
      "eventType: 'ai_help_opened'",
      "eventType: 'ai_help_used'",
      "eventType: 'ai_coach_response'",
    ]) {
      expectInteractionEventWriteHasCreatedAt(indexSource, eventType);
    }

    expectInteractionEventWriteHasCreatedAt(indexSource, '...explainBackEvent');
    expect(bosSource).toContain('loadLearnerLoopInteractionEvents(siteId, learnerId, since, 500)');
    expect(bosSource).toContain("'timestamp'");
    expect(bosSource).toContain("'ai_help_opened'");
    expect(bosSource).toContain('explain_it_back_submitted: 0');
    expect(bosSource).toContain('pendingExplainBack');
    expect(hasInteractionEventIndex('createdAt')).toBe(true);
    expect(hasInteractionEventIndex('timestamp')).toBe(true);
  });

  it('exposes MiloOS support provenance in parent summaries without mastery claims', () => {
    const indexSource = readFunctionsFile('index.ts');
    const summaryStart = indexSource.indexOf('async function buildParentLearnerSummary');
    const summaryEnd = indexSource.indexOf('async function loadParentUpcomingEvents', summaryStart);
    const summarySource = indexSource.slice(summaryStart, summaryEnd);

    expect(summarySource).toContain('miloosSupportSummary');
    expect(summarySource).toContain("'ai_help_opened'");
    expect(summarySource).toContain("'ai_help_used'");
    expect(summarySource).toContain("'explain_it_back_submitted'");
    expect(summarySource).toContain('pendingExplainBack: miloosPendingExplainBack');
    expect(summarySource).toContain('isMasteryEvidence: false');
    expect(summarySource).not.toContain('miloosCapabilityMastery');
    expect(summarySource).not.toContain('miloosMasteryLevel');
  });
});