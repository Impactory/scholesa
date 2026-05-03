/**
 * Evidence Chain Component & Callable Tests
 *
 * Validates that the new evidence chain components correctly implement
 * the capability-first evidence workflow:
 *   - EducatorEvidenceCapture links evidence to session occurrences
 *   - LearnerEvidenceSubmission captures artifacts, reflections, AI disclosure
 *   - CapabilityGuidancePanel interprets capability bands for guardians
 *   - verifyProofOfLearning callable exists and preserves the proof→rubric boundary
 */

import fs from 'fs';
import path from 'path';

const srcDir = path.join(process.cwd(), 'src');
const functionsDir = path.join(process.cwd(), 'functions', 'src');

function readSrcFile(...segments: string[]): string {
  return fs.readFileSync(path.join(srcDir, ...segments), 'utf8');
}

/* ───── EducatorEvidenceCapture session context ───── */

describe('EducatorEvidenceCapture session context linking', () => {
  const source = readSrcFile('components', 'evidence', 'EducatorEvidenceCapture.tsx');

  it('resolves site context through the shared active-site helper', () => {
    expect(source).toContain('resolveActiveSiteId');
    expect(source).not.toContain('const siteId = profile?.studioId ?? null;');
  });

  it('imports sessionOccurrencesCollection', () => {
    expect(source).toContain('sessionOccurrencesCollection');
  });

  it('imports sessionsCollection for time labels', () => {
    expect(source).toContain('sessionsCollection');
  });

  it('has selectedSessionOccurrenceId form state', () => {
    expect(source).toContain('selectedSessionOccurrenceId');
    expect(source).toContain('setSelectedSessionOccurrenceId');
  });

  it('includes sessionOccurrenceId in the addDoc call', () => {
    // The addDoc block should write sessionOccurrenceId
    const addDocBlock = source.slice(
      source.indexOf('await addDoc(evidenceRecordsCollection'),
      source.indexOf(
        '} as Omit<EvidenceRecord',
        source.indexOf('await addDoc(evidenceRecordsCollection')
      )
    );
    expect(addDocBlock).toContain('sessionOccurrenceId');
  });

  it('queries today session occurrences by siteId and date range', () => {
    expect(source).toContain("where('siteId', '==', siteId)");
    expect(source).toContain("where('educatorId', '==', user.uid)");
    expect(source).toContain('Timestamp.fromDate(todayStart)');
    expect(source).toContain('Timestamp.fromDate(todayEnd)');
  });

  it('builds the live learner roster from attendance first and active enrollments second', () => {
    expect(source).toContain("where('siteIds', 'array-contains', siteId)");
    expect(source).toContain("collection(firestore, 'enrollments')");
    expect(source).toContain("collection(firestore, 'attendanceRecords')");
    expect(source).toContain("where('sessionOccurrenceId', 'in', ids)");
    expect(source).toContain("where('status', '==', 'active')");
  });

  it('renders a live session selector and roster provenance banner in the form', () => {
    expect(source).toContain('data-testid="evidence-session"');
    expect(source).toContain('data-testid="evidence-roster-source"');
    expect(source).toContain(
      'Showing present learners from attendance for this session occurrence.'
    );
  });

  it('keeps session selection sticky across logs', () => {
    // resetForm should NOT clear selectedSessionOccurrenceId
    const resetBlock = source.slice(
      source.indexOf('const resetForm'),
      source.indexOf('};', source.indexOf('const resetForm')) + 2
    );
    expect(resetBlock).not.toContain('setSelectedSessionOccurrenceId');
  });

  it('does not offer a manual no-session option when a live session exists', () => {
    expect(source).not.toContain('(not linked to a session)');
  });

  it('requires capability linkage before creating a portfolio-backed educator observation', () => {
    expect(source).toContain(
      'Select a capability before flagging this observation as portfolio evidence.'
    );
    expect(source).toContain('portfolioItemsCollection');
    expect(source).toContain("where('evidenceRecordIds', 'array-contains-any', evidenceIds)");
    expect(source).toContain('portfolioItemId={reviewingEvidence.portfolioItemId}');
    expect(source).toContain('evidenceRecordIds: [evidenceRef.id]');
    expect(source).toContain("proofOfLearningStatus: 'missing'");
    expect(source).toContain("source: 'educator_observation'");
    expect(source).toContain('portfolioItemId = portfolioRef.id');
    expect(source).not.toContain('evidenceRecordId: evidenceRef.id');
  });

  it('shows an explicit no-site blocked state', () => {
    expect(source).toContain('data-testid="evidence-capture-site-required"');
    expect(source).toContain('Select an active site before capturing evidence');
  });
});

/* ───── ProofOfLearningVerification site context ───── */

describe('ProofOfLearningVerification site context', () => {
  const source = readSrcFile('components', 'evidence', 'ProofOfLearningVerification.tsx');

  it('resolves site context through the shared active-site helper', () => {
    expect(source).toContain('resolveActiveSiteId');
    expect(source).not.toContain('const siteId = profile?.studioId ?? null;');
  });

  it('shows an explicit no-site blocked state', () => {
    expect(source).toContain('data-testid="proof-verification-site-required"');
    expect(source).toContain('Select an active site before reviewing proof-of-learning evidence.');
  });

  it('keeps verification success messaging honest when no linked capabilities are processed', () => {
    expect(source).toContain('capabilitiesReadyForRubric');
    expect(source).toContain('Verified — proof confirmed. Ready for rubric application.');
    expect(source).toContain('Open Rubric Application');
    expect(source).toContain('?portfolioItemId=${encodeURIComponent(item.id)}');
  });

  it('prefills educator proof review from the saved portfolio proof fields', () => {
    expect(source).toContain('item.proofHasExplainItBack === true');
    expect(source).toContain('item.proofExplainItBackExcerpt');
    expect(source).toContain('item.verificationNotes');
  });
});

/* ───── LearnerProofAssemblyRenderer site context ───── */

describe('LearnerProofAssemblyRenderer site context', () => {
  const source = readSrcFile(
    'features',
    'workflows',
    'renderers',
    'LearnerProofAssemblyRenderer.tsx'
  );

  it('resolves site context through the shared active-site helper', () => {
    expect(source).toContain('resolveActiveSiteId');
  });

  it('shows an explicit no-site blocked state', () => {
    expect(source).toContain('data-testid="learner-proof-assembly-site-required"');
    expect(source).toContain('Select an active site before assembling proof-of-learning.');
  });
});

describe('Rubric proof gate honesty', () => {
  const reviewSource = readSrcFile(
    'features',
    'workflows',
    'renderers',
    'EducatorEvidenceReviewRenderer.tsx'
  );
  const panelSource = readSrcFile('components', 'evidence', 'RubricReviewPanel.tsx');

  it('requires verified proof before educator rubric review can update growth', () => {
    expect(reviewSource).toContain("attempt.proofOfLearningStatus !== 'verified'");
    expect(reviewSource).toContain(
      'Verify proof-of-learning before applying a rubric that updates capability growth.'
    );
    expect(reviewSource).toContain('portfolioItemId: attempt.portfolioItemId ?? undefined');
    expect(reviewSource).not.toContain('rubric-proof-verified-');
  });

  it('keeps the shared rubric review panel blocked until proof is verified', () => {
    expect(panelSource).toContain('proofVerified = false');
    expect(panelSource).toContain('data-testid="rubric-review-proof-gate"');
    expect(panelSource).toContain(
      'Verify proof-of-learning before applying a rubric that updates capability growth.'
    );
  });
});

describe('Checkpoint proof chain honesty', () => {
  const learnerCheckpointSource = readSrcFile(
    'features',
    'workflows',
    'renderers',
    'LearnerCheckpointRenderer.tsx'
  );
  const educatorReviewSource = readSrcFile(
    'features',
    'workflows',
    'renderers',
    'EducatorEvidenceReviewRenderer.tsx'
  );

  it('links learner checkpoints into portfolio evidence for proof review', () => {
    expect(learnerCheckpointSource).toContain('portfolioItemsCollection');
    expect(learnerCheckpointSource).toContain('checkpointsCollection');
    expect(learnerCheckpointSource).toContain("source: 'checkpoint_submission'");
    expect(learnerCheckpointSource).toContain('proofOfLearningStatus');
    expect(learnerCheckpointSource).toContain('portfolioItemId: portfolioRef.id');
    expect(learnerCheckpointSource).toContain('checkpointDefinitionId');
    expect(learnerCheckpointSource).toContain(
      'Select an assigned checkpoint before submitting checkpoint evidence.'
    );
    expect(learnerCheckpointSource).toContain(
      'No HQ-authored checkpoints are available for this site yet.'
    );
  });

  it('keeps educator checkpoint review truthful about proof before growth', () => {
    expect(educatorReviewSource).toContain('cp.portfolioItemId');
    expect(educatorReviewSource).toContain("where('status', 'in', ['submitted', 'pending_proof'])");
    expect(educatorReviewSource).toContain(
      'Checkpoint correctness saved. Verify the linked proof-of-learning, then record capability growth from this review surface.'
    );
    expect(educatorReviewSource).toContain(
      'Linked proof is verified. Confirm this checkpoint again to record capability growth.'
    );
    expect(educatorReviewSource).toContain('Record growth');
  });
});

/* ───── LearnerPortfolioCurationRenderer site context ───── */

describe('LearnerPortfolioCurationRenderer site context', () => {
  const source = readSrcFile(
    'features',
    'workflows',
    'renderers',
    'LearnerPortfolioCurationRenderer.tsx'
  );

  it('resolves site context through the shared active-site helper', () => {
    expect(source).toContain('resolveActiveSiteId');
    expect(source).not.toContain('const siteId = ctx.profile?.siteIds?.[0] ?? null;');
  });

  it('shows an explicit no-site blocked state', () => {
    expect(source).toContain('data-testid="learner-portfolio-site-required"');
    expect(source).toContain('Select an active site before curating portfolio evidence.');
  });

  it('writes canonical portfolio fields for learner-created artifacts', () => {
    const addDocBlock = source.slice(
      source.indexOf('const portfolioDoc = await addDoc(portfolioItemsCollection'),
      source.indexOf("} as unknown as Omit<PortfolioItemRecord, 'id'>);") +
        "} as unknown as Omit<PortfolioItemRecord, 'id'>);".length
    );
    expect(addDocBlock).toContain('portfolioItemsCollection');
    expect(addDocBlock).toContain('pillarCodes');
    expect(addDocBlock).toContain('artifacts');
    expect(addDocBlock).toContain("proofOfLearningStatus: 'not-available'");
    expect(addDocBlock).toContain('aiDisclosureStatus');
    expect(addDocBlock).not.toContain('artifactUrl: newArtifactUrl.trim()');
    expect(addDocBlock).not.toContain('aiDisclosure: newAiDisclosure');
    expect(addDocBlock).not.toContain('proofOfLearning: false');
  });

  it('back-links optional reflections through learnerReflectionsCollection', () => {
    const handler = source.slice(
      source.indexOf('const handleAddItem'),
      source.indexOf('const handleMarkAsShowcase')
    );
    expect(handler).toContain('learnerReflectionsCollection');
    expect(handler).toContain('content: newReflection.trim()');
    expect(handler).toContain('reflectionIds: [reflectionDoc.id]');
  });
});

/* ───── EducatorEvidenceReviewRenderer site context ───── */

describe('EducatorEvidenceReviewRenderer site context', () => {
  const source = readSrcFile(
    'features',
    'workflows',
    'renderers',
    'EducatorEvidenceReviewRenderer.tsx'
  );

  it('resolves site context through the shared active-site helper', () => {
    expect(source).toContain('resolveActiveSiteId');
    expect(source).not.toContain(
      "const educatorSiteId = ctx.profile?.studioId || ctx.profile?.siteIds?.[0] || '';"
    );
  });

  it('uses the resolved active site for rubric lookup and apply fallbacks', () => {
    expect(source).toContain('const siteId = mission?.siteId || educatorSiteId;');
    expect(source).not.toContain("ctx.profile?.siteIds?.[0] || ''");
  });

  it('shows an explicit no-site blocked state', () => {
    expect(source).toContain('data-testid="educator-review-site-required"');
    expect(source).toContain(
      'Select an active site before reviewing learner evidence and applying rubric decisions.'
    );
  });
});

/* ───── EducatorTodayRenderer site context ───── */

describe('EducatorTodayRenderer site context', () => {
  const source = readSrcFile('features', 'workflows', 'renderers', 'EducatorTodayRenderer.tsx');

  it('resolves site context through the shared active-site helper', () => {
    expect(source).toContain('resolveActiveSiteId');
    expect(source).not.toContain('const siteId = ctx.profile?.siteIds?.[0] ?? null;');
    expect(source).not.toContain("const educatorSiteId = ctx.profile?.studioId || siteId || '';");
  });

  it('site-scopes today sessions, learner roster, and review queue counts', () => {
    expect(source).toContain("where('siteId', '==', educatorSiteId)");
    expect(source).toContain("where('siteIds', 'array-contains', educatorSiteId)");
    expect(source).toContain("where('educatorId', '==', ctx.uid)");
    expect(source).toContain("where('status', 'in', ['submitted', 'pending_review'])");
  });

  it('passes the resolved site into quick evidence capture writes', () => {
    expect(source).toContain('siteId={educatorSiteId}');
  });

  it('uses session occurrences, enrollments, and attendance records to build the live roster', () => {
    expect(source).toContain("collection(firestore, 'sessionOccurrences')");
    expect(source).toContain("collection(firestore, 'enrollments')");
    expect(source).toContain("collection(firestore, 'attendanceRecords')");
    expect(source).toContain("where('sessionOccurrenceId', 'in', ids)");
    expect(source).toContain("where('status', '==', 'active')");
  });

  it('requires capability linkage before creating portfolio-backed live evidence', () => {
    expect(source).toContain(
      'Select a capability before flagging this observation as portfolio evidence.'
    );
    expect(source).toContain('capabilityId: selectedCapabilityId || undefined');
    expect(source).toContain('evidenceRecordIds: [evidenceRef.id]');
    expect(source).not.toContain('evidenceRecordId: evidenceRef.id');
  });

  it('writes quick observations against sessionOccurrenceId instead of legacy sessionId', () => {
    const addDocBlock = source.slice(
      source.indexOf("await addDoc(collection(firestore, 'evidenceRecords')"),
      source.indexOf(
        '});',
        source.indexOf("await addDoc(collection(firestore, 'evidenceRecords')")
      ) + 3
    );
    expect(addDocBlock).toContain('sessionOccurrenceId: sessionOccurrenceId || undefined');
    expect(addDocBlock).not.toContain('sessionId: sessionId || null');
  });

  it('renders a live session selector and roster source banner for quick capture', () => {
    expect(source).toContain('data-testid="quick-observation-session"');
    expect(source).toContain('data-testid="quick-observation-roster-source"');
    expect(source).toContain(
      'Showing present learners from attendance for this session occurrence.'
    );
  });

  it('shows an explicit no-site blocked state', () => {
    expect(source).toContain('data-testid="educator-today-site-required"');
    expect(source).toContain('Select an active site before capturing live classroom observations.');
  });
});

/* ───── LearnerProgressReportRenderer site context ───── */

describe('LearnerProgressReportRenderer site context', () => {
  const source = readSrcFile(
    'features',
    'workflows',
    'renderers',
    'LearnerProgressReportRenderer.tsx'
  );

  it('resolves site context through the shared active-site helper', () => {
    expect(source).toContain('resolveActiveSiteId');
    expect(source).not.toContain("const siteId = ctx.profile?.siteIds?.[0] || '';");
  });

  it('passes the resolved site into learner passport export and MiloOS coach', () => {
    expect(source).toContain('<LearnerPassportExport siteId={siteId} />');
    expect(source).toContain('<AICoachScreen learnerId={ctx.uid} siteId={siteId} />');
  });

  it('site-scopes learner revision alert reads', () => {
    const revisionsBlock = source.slice(
      source.indexOf('const checkRevisions'),
      source.indexOf('useEffect(() => {')
    );
    expect(revisionsBlock).toContain('!ctx.uid || !siteId');
    expect(revisionsBlock).toContain("where('siteId', '==', siteId)");
    expect(revisionsBlock).toContain('[ctx.uid, siteId]');
  });

  it('shows an explicit no-site blocked state', () => {
    expect(source).toContain('data-testid="learner-progress-site-required"');
    expect(source).toContain(
      'Select an active site before viewing your progress report and MiloOS coach.'
    );
  });
});

/* ───── LearnerPassportExport learner contract ───── */

describe('LearnerPassportExport learner contract', () => {
  const source = readSrcFile('components', 'passport', 'LearnerPassportExport.tsx');

  it('uses shared active-site resolution', () => {
    expect(source).toContain('resolveActiveSiteId');
  });

  it('uses a learner-safe passport callable instead of the parent bundle', () => {
    expect(source).toContain('getLearnerPassportBundle');
    expect(source).not.toContain('getParentDashboardBundle');
  });

  it('shows an explicit no-site blocked state', () => {
    expect(source).toContain('data-testid="learner-passport-site-required"');
    expect(source).toContain('Select an active site before viewing your evidence-backed passport.');
  });

  it('uses learner-specific empty-state wording', () => {
    expect(source).toContain('No passport evidence is available yet.');
    expect(source).not.toContain('No linked learners found.');
  });

  it('retains provenance-rich claim and growth fields from the learner passport bundle', () => {
    expect(source).toContain('evidenceRecordIds');
    expect(source).toContain('portfolioItemIds');
    expect(source).toContain('missionAttemptIds');
    expect(source).toContain('linkedEvidenceRecordIds');
    expect(source).toContain('linkedPortfolioItemIds');
    expect(source).toContain('processDomainSnapshot');
    expect(source).toContain('processDomainGrowthTimeline');
    expect(source).toContain('proofCheckpointCount');
    expect(source).toContain('reviewedAt');
    expect(source).toContain('verificationPrompt');
    expect(source).toContain('aiAssistanceDetails');
  });

  it('exports a shareable passport with portfolio and growth provenance, not claims alone', () => {
    expect(source).toContain('function escapeHtml');
    expect(source).toContain('const portfolioHtml =');
    expect(source).toContain('const growthHtml =');
    expect(source).toContain('const reportBasisHtml =');
    expect(source).toContain('buildPassportTextLines');
    expect(source).toContain('buildFamilyShareSummary');
    expect(source).toContain("await import('jspdf')");
    expect(source).toContain('shareTextWithFallback');
    expect(source).toContain('downloadTextReport');
    expect(source).toContain('familySummaryProvenanceSignals');
    expect(source).toContain('passportReportProvenanceSignals');
    expect(source).toContain('reportProvenanceMetadata');
    expect(source).toContain('onReportProvenance');
    expect(source).toContain('enforceProvenanceContract: true');
    expect(source).toContain('familyReportSharePolicy');
    expect(source).toContain('learnerPrivateReportSharePolicy');
    expect(source).toContain('recordReportDeliveryLifecycle');
    expect(source).toContain('ReportShareRequestManager');
    expect(source).toContain('viewer="learner"');
    expect(source).toContain("reportAction: 'export_html'");
    expect(source).toContain('report_delivery');
    expect(source).toContain('const processDomainSnapshotHtml =');
    expect(source).toContain('const processDomainGrowthHtml =');
    expect(source).toContain('<h2>Portfolio Artifacts</h2>');
    expect(source).toContain('<h2>Process Domain Progress</h2>');
    expect(source).toContain('<h2>Recent Process Domain Growth</h2>');
    expect(source).toContain('<h2>Growth Timeline</h2>');
    expect(source).toContain('Pending verification prompts:');
    expect(source).toContain('compatibility roll-up of the current curriculum strands');
    expect(source).toContain('Featured AI disclosure:');
    expect(source).toContain('Recent growth provenance:');
    expect(source).toContain('Featured portfolio evidence:');
    expect(source).toContain('formatFamilyShareClaimLine');
    expect(source).toContain('formatFamilyShareGrowthLine');
    expect(source).toContain('formatFamilySharePortfolioLine');
    expect(source).toContain('proof ${proofLabel(claim.proofOfLearningStatus)}');
    expect(source).toContain('AI ${aiLabel(claim.aiDisclosureStatus)}');
    expect(source).toContain('rubric ${claim.rubricRawScore}/${claim.rubricMaxScore}');
    expect(source).toContain('reviewed by ${claim.reviewingEducatorName}');
    expect(source).toContain('${entry.linkedEvidenceRecordIds.length} evidence links');
    expect(source).toContain('${entry.linkedPortfolioItemIds.length} portfolio links');
    expect(source).toContain('── Portfolio Artifacts ──');
    expect(source).toContain('── Process Domain Progress ──');
    expect(source).toContain('── Recent Process Domain Growth ──');
    expect(source).toContain('── Growth Timeline ──');
    expect(source).toContain('── Report Basis ──');
    expect(source).toContain('Share Family Summary');
    expect(source).toContain('Export PDF');
  });
});

/* ───── GuardianCapabilityViewRenderer site provenance ───── */

describe('GuardianCapabilityViewRenderer site provenance', () => {
  const source = readSrcFile(
    'features',
    'workflows',
    'renderers',
    'GuardianCapabilityViewRenderer.tsx'
  );

  it('uses shared active-site resolution', () => {
    expect(source).toContain('resolveActiveSiteId');
  });

  it('passes the resolved site into the guardian dashboard callable', () => {
    expect(source).toContain('getParentDashboardBundle');
    expect(source).toContain('siteId');
    expect(source).toContain('callable({ parentId: ctx.uid, siteId })');
  });

  it('shows an explicit no-site blocked state', () => {
    expect(source).toContain('data-testid="guardian-view-site-required"');
    expect(source).toContain('Select an active site before viewing your family evidence summary.');
  });

  it('retains bundle provenance on growth timeline, portfolio highlights, and passport claims', () => {
    expect(source).toContain('linkedEvidenceRecordIds');
    expect(source).toContain('linkedPortfolioItemIds');
    expect(source).toContain('processDomainSnapshot');
    expect(source).toContain('processDomainGrowthTimeline');
    expect(source).toContain('proofCheckpointCount');
    expect(source).toContain('verifiedArtifactCount');
    expect(source).toContain('progressionDescriptor');
    expect(source).toContain('guardian-ideation-passport');
  });

  it('surfaces MiloOS support provenance for guardians without calling it mastery', () => {
    expect(source).toContain('miloosSupportSummary');
    expect(source).toContain('MiloOS support provenance');
    expect(source).toContain(
      'These are support signals and explain-back verification gaps, not capability'
    );
    expect(source).toContain('mastery.');
    expect(source).toContain('data-testid={`guardian-miloos-support-${learner.learnerId}`}');
    expect(source).toContain('data-testid="guardian-miloos-support-opened"');
    expect(source).toContain('data-testid="guardian-miloos-support-used"');
    expect(source).toContain('data-testid="guardian-miloos-explain-backs"');
    expect(source).toContain('data-testid="guardian-miloos-pending-checks"');
    expect(source).toContain('isMasteryEvidence: false');
    expect(source).toContain('MiloOS Support Provenance');
  });

  it('adds family-safe share and PDF export actions on the parent passport route', () => {
    expect(source).toContain("const isPassportRoute = ctx.routePath === '/parent/passport'");
    expect(source).toContain('buildGuardianPassportTextLines');
    expect(source).toContain('buildGuardianFamilyShareSummary');
    expect(source).toContain("await import('jspdf')");
    expect(source).toContain('shareTextWithFallback');
    expect(source).toContain('downloadTextReport');
    expect(source).toContain('familySummaryProvenanceSignals');
    expect(source).toContain('passportReportProvenanceSignals');
    expect(source).toContain('reportProvenanceMetadata');
    expect(source).toContain('onReportProvenance');
    expect(source).toContain('enforceProvenanceContract: true');
    expect(source).toContain('familyReportSharePolicy');
    expect(source).toContain('recordReportDeliveryLifecycle');
    expect(source).toContain('ReportShareRequestManager');
    expect(source).toContain('viewer="guardian"');
    expect(source).toContain('report_delivery');
    expect(source).toContain('Share family summary');
    expect(source).toContain('Export PDF');
  });

  it('also exposes the same family-safe share and export actions on the parent summary route', () => {
    expect(source).toContain("const isSummaryRoute = ctx.routePath === '/parent/summary'");
    expect(source).toContain('const showGuardianShareActions = isPassportRoute || isSummaryRoute');
    expect(source).toContain('Export or share a family-safe summary of reviewed evidence, linked');
    expect(source).toContain('artifacts, and recorded growth for {learner.name}.');
    expect(source).toContain('Featured AI disclosure:');
    expect(source).toContain('Recent growth provenance:');
    expect(source).toContain('Recent process-domain growth:');
    expect(source).toContain('Featured portfolio evidence:');
    expect(source).toContain('formatGuardianFamilyShareClaimLine');
    expect(source).toContain('formatGuardianFamilyShareGrowthLine');
    expect(source).toContain('formatGuardianFamilyShareProcessGrowthLine');
    expect(source).toContain('formatGuardianFamilySharePortfolioLine');
    expect(source).toContain('proof ${PROOF_STATUS_CONFIG[claim.proofStatus]?.label');
    expect(source).toContain('AI ${AI_DISCLOSURE_CONFIG[claim.aiDisclosureStatus]?.label');
    expect(source).toContain('rubric ${claim.rubricScore.raw}/${claim.rubricScore.max}');
    expect(source).toContain('${evidenceLinkCount} evidence link(s)');
    expect(source).toContain('${portfolioLinkCount} portfolio link(s)');
    expect(source).toContain('${item.evidenceCount ?? 0} evidence, ${item.missionAttemptId ?');
    expect(source).toContain(
      'Rubric Score:    ${item.rubricScore.raw}/${item.rubricScore.max} (${item.rubricScore.level})'
    );
    expect(source).toContain('Reviewed by:     ${event.educatorName}');
    expect(source).toContain('Rubric Score:    ${event.rubricScore.raw}/${event.rubricScore.max}');
  });

  it('surfaces titled process-domain progress in the family passport and on-screen view', () => {
    expect(source).toContain('normalizeProcessDomainSnapshot');
    expect(source).toContain('normalizeProcessDomainGrowthTimeline');
    expect(source).toContain('── Process Domains ──');
    expect(source).toContain('── Recent Process Domain Growth ──');
    expect(source).toContain('Process domains');
    expect(source).toContain('Recent process domain growth');
  });
});

/* ───── LearnerEvidenceSubmission ───── */

describe('LearnerEvidenceSubmission component', () => {
  const source = readSrcFile('components', 'evidence', 'LearnerEvidenceSubmission.tsx');

  it('exists and is non-trivial', () => {
    expect(source.length).toBeGreaterThan(200);
  });

  it('resolves site context through the shared active-site helper', () => {
    expect(source).toContain('resolveActiveSiteId');
    expect(source).not.toContain('const siteId = profile?.studioId ?? null;');
  });

  it('supports artifact submission', () => {
    expect(source).toContain('artifact');
  });

  it('supports reflection submission', () => {
    expect(source).toContain('reflection');
  });

  it('supports checkpoint evidence submission', () => {
    expect(source).toContain("'checkpoint'");
    expect(source).toContain('handleSubmitCheckpoint');
    expect(source).toContain('data-testid="checkpoint-form"');
  });

  it('imports missionAttemptsCollection for checkpoint writes', () => {
    expect(source).toContain('missionAttemptsCollection');
  });

  it('loads missions for checkpoint selector', () => {
    expect(source).toContain('missionsCollection');
    expect(source).toContain('setMissions');
  });

  it('has mission selector in checkpoint form', () => {
    expect(source).toContain('data-testid="checkpoint-mission-select"');
    expect(source).toContain('checkpointMissionId');
  });

  it('writes checkpoint to missionAttempts with submitted status', () => {
    const handler = source.slice(
      source.indexOf('const handleSubmitCheckpoint'),
      source.indexOf('};', source.indexOf("setSuccessMessage('Checkpoint evidence submitted!')")) +
        2
    );
    expect(handler).toContain('missionAttemptsCollection');
    expect(handler).toContain("status: 'submitted'");
  });

  it('also writes checkpoint to portfolio for visibility', () => {
    const handler = source.slice(
      source.indexOf('const handleSubmitCheckpoint'),
      source.indexOf('};', source.indexOf("setSuccessMessage('Checkpoint evidence submitted!')")) +
        2
    );
    expect(handler).toContain('portfolioItemsCollection');
    expect(handler).toContain("source: 'checkpoint_submission'");
  });

  it('includes AI disclosure on checkpoint form', () => {
    expect(source).toContain('data-testid="checkpoint-ai-details"');
    expect(source).toContain('checkpointAiUsed');
  });

  it('captures AI disclosure', () => {
    expect(source).toContain('aiAssistanceUsed');
  });

  it('persists AI explanation details across artifact, reflection, and checkpoint writes', () => {
    const artifactHandler = source.slice(
      source.indexOf('const handleSubmitArtifact'),
      source.indexOf('const handleSubmitReflection')
    );
    const reflectionHandler = source.slice(
      source.indexOf('const handleSubmitReflection'),
      source.indexOf('const handleSubmitCheckpoint')
    );
    const checkpointHandler = source.slice(
      source.indexOf('const handleSubmitCheckpoint'),
      source.indexOf('// Auto-clear success message')
    );

    expect(artifactHandler).toContain('aiAssistanceDetails: aiUsed ? aiDetails.trim() : undefined');
    expect(reflectionHandler).toContain(
      'aiAssistanceDetails: reflectionAiUsed ? reflectionAiDetails.trim() : undefined'
    );
    expect(checkpointHandler).toContain(
      'aiAssistanceDetails: checkpointAiUsed ? checkpointAiDetails.trim() : undefined'
    );
  });

  it('back-links reflection submissions onto the canonical portfolio item', () => {
    const reflectionHandler = source.slice(
      source.indexOf('const handleSubmitReflection'),
      source.indexOf('const handleSubmitCheckpoint')
    );

    expect(reflectionHandler).toContain('reflectionIds: [] as string[]');
    expect(reflectionHandler).toContain(
      'const reflectionDoc = await addDoc(learnerReflectionsCollection'
    );
    expect(reflectionHandler).toContain('portfolioItemId: portfolioRef.id');
    expect(reflectionHandler).toContain('await updateDoc(portfolioRef, {');
    expect(reflectionHandler).toContain('reflectionIds: [reflectionDoc.id]');
  });

  it('links to capabilities', () => {
    expect(source).toContain('capabilityId');
  });

  it('requires capability linkage for learner-created proof items', () => {
    expect(source).toContain(
      'Select at least one capability before submitting portfolio evidence.'
    );
    expect(source).toContain(
      'Select at least one capability before saving a reflection to your evidence portfolio.'
    );
    expect(source).toContain('This checkpoint is not linked to a capability yet.');
    expect(source).toContain("where('siteId', '==', siteId)");
  });

  it('writes to portfolioItemsCollection', () => {
    expect(source).toContain('portfolioItemsCollection');
  });

  it('writes to learnerReflectionsCollection', () => {
    expect(source).toContain('learnerReflectionsCollection');
  });

  it('site-scopes learner portfolio reads', () => {
    expect(source).toContain("where('siteId', '==', siteId)");
  });

  it('site-scopes revision reads', () => {
    const revisionsBlock = source.slice(
      source.indexOf('const loadRevisions'),
      source.indexOf('const handleResubmit')
    );
    expect(revisionsBlock).toContain("where('siteId', '==', siteId)");
  });

  it('shows an explicit no-site blocked state', () => {
    expect(source).toContain('data-testid="learner-evidence-site-required"');
    expect(source).toContain('Select an active site before submitting learner evidence');
  });

  it('uses RoleRouteGuard for access control', () => {
    expect(source).toContain('RoleRouteGuard');
  });

  it('has three tab buttons (artifact, reflection, checkpoint)', () => {
    expect(source).toContain('Submit Artifact');
    expect(source).toContain('Write Reflection');
    expect(source).toContain('Checkpoint Evidence');
  });
});

/* ───── LearnerPortfolioBrowser ───── */

describe('LearnerPortfolioBrowser component', () => {
  const source = readSrcFile('components', 'evidence', 'LearnerPortfolioBrowser.tsx');

  it('resolves site context through the shared active-site helper', () => {
    expect(source).toContain('resolveActiveSiteId');
    expect(source).not.toContain('const siteId = profile?.studioId ?? null;');
  });

  it('site-scopes learner portfolio reads', () => {
    expect(source).toContain("where('siteId', '==', siteId)");
  });

  it('shows an explicit no-site blocked state', () => {
    expect(source).toContain('data-testid="portfolio-browser-site-required"');
    expect(source).toContain('Select an active site before browsing your portfolio evidence.');
  });
});

/* ───── CapabilityGuidancePanel ───── */

describe('CapabilityGuidancePanel guardian interpretation', () => {
  const source = readSrcFile('components', 'analytics', 'CapabilityGuidancePanel.tsx');

  it('exists and is non-trivial', () => {
    expect(source.length).toBeGreaterThan(150);
  });

  it('interprets capability bands', () => {
    // Should reference the mastery bands
    expect(source).toMatch(/strong|proficient|developing|emerging|beginning/i);
  });

  it('groups by pillar', () => {
    expect(source).toContain('pillar');
  });

  it('shows evidence counts', () => {
    expect(source).toContain('evidence');
  });

  it('provides parent-friendly explanations', () => {
    // Should not just show raw data
    expect(source).toMatch(/can do|able to|growth|progress/i);
  });
});

/* ───── ParentAnalyticsDashboard guardian honesty ───── */

describe('ParentAnalyticsDashboard guardian honesty', () => {
  const source = readSrcFile('components', 'analytics', 'ParentAnalyticsDashboard.tsx');

  it('uses shared active-site resolution', () => {
    expect(source).toContain('resolveActiveSiteId');
  });

  it('shows an explicit no-site blocked state', () => {
    expect(source).toContain('data-testid="parent-analytics-site-required"');
    expect(source).toContain(
      'Select an active site before viewing supplemental engagement signals.'
    );
  });

  it('frames engagement as secondary to evidence-backed capability judgments', () => {
    expect(source).toContain('These signals describe participation and motivation patterns.');
    expect(source).toContain('They do not replace');
    expect(source).toContain('evidence-backed capability, proof, or growth judgments.');
  });

  it('does not embed CapabilityGuidancePanel inside the engagement panel', () => {
    expect(source).not.toContain('CapabilityGuidancePanel');
  });
});

/* ───── verifyProofOfLearning callable ───── */

describe('verifyProofOfLearning callable', () => {
  const functionsSource = fs.readFileSync(path.join(functionsDir, 'index.ts'), 'utf8');
  const verifyStart = functionsSource.indexOf('export const verifyProofOfLearning');
  const verifyEnd = functionsSource.indexOf(
    '// ---------------------------------------------------------------------------\n// S3-2',
    verifyStart
  );
  const verifySection = functionsSource.slice(
    verifyStart,
    verifyEnd > verifyStart ? verifyEnd : verifyStart + 8000
  );

  it('exports verifyProofOfLearning as onCall', () => {
    expect(functionsSource).toContain('export const verifyProofOfLearning');
  });

  it('keeps proof verification separate from capability growth writes', () => {
    expect(verifySection).toContain('batch');
    expect(verifySection).not.toContain('capabilityGrowthEvents');
  });

  it('does not upsert capability mastery directly', () => {
    expect(verifySection).not.toContain('capabilityMastery');
  });

  it('validates educator role', () => {
    expect(verifySection).toContain('educator');
  });

  it('syncs the linked proof bundle alongside portfolio proof fields', () => {
    expect(verifySection).toContain("collection('proofOfLearningBundles')");
    expect(verifySection).toContain('proofExplainItBackExcerpt');
    expect(verifySection).toContain('verificationPromptSource');
  });

  it('refuses verified proof when capability linkage is missing', () => {
    expect(verifySection).toContain("'failed-precondition'");
    expect(verifySection).toContain(
      'Link at least one capability to this evidence before verifying proof-of-learning so the evidence can move into rubric interpretation.'
    );
    expect(verifySection).toContain('evidenceRecordIds');
  });
});

describe('getLearnerPassportBundle callable', () => {
  const functionsSource = fs.readFileSync(path.join(functionsDir, 'index.ts'), 'utf8');

  it('exports a learner-safe passport callable', () => {
    expect(functionsSource).toContain('export const getLearnerPassportBundle');
    expect(functionsSource).toContain("requireRoleAndSite(authUid, ['learner'], requestedSiteId)");
  });

  it('reuses the existing evidence-backed learner summary builder', () => {
    const section = functionsSource.slice(
      functionsSource.indexOf('export const getLearnerPassportBundle'),
      functionsSource.indexOf(
        'async function computeRoleDashboardStats',
        functionsSource.indexOf('export const getLearnerPassportBundle')
      )
    );
    expect(section).toContain('buildParentLearnerSummary');
    expect(section).toContain('learners: [learnerSummary]');
  });
});

describe('recordReportDeliveryAudit callable', () => {
  const functionsSource = fs.readFileSync(path.join(functionsDir, 'index.ts'), 'utf8');
  const auditStart = functionsSource.indexOf('export const recordReportDeliveryAudit');
  const auditEnd = functionsSource.indexOf('export const processNotificationRequests', auditStart);
  const auditSection = functionsSource.slice(
    auditStart,
    auditEnd > auditStart ? auditEnd : auditStart + 8000
  );

  it('exports a server-side report delivery audit callable', () => {
    expect(functionsSource).toContain('export const recordReportDeliveryAudit');
    expect(functionsSource).toContain('persistReportDeliveryAuditRecord');
    expect(functionsSource).toContain('linkReportShareRequestDeliveryAuditRecord');
  });

  it('requires learner/site authorization before writing audit logs', () => {
    expect(auditSection).toContain("['learner', 'parent', 'educator', 'site', 'hq']");
    expect(auditSection).toContain('collectParentLinkedLearnerIds');
    expect(auditSection).toContain('Learners can only audit their own report delivery.');
    expect(auditSection).toContain('Learner is not linked to this site.');
  });

  it('refuses successful delivery audits that do not meet the report delivery contract', () => {
    expect(auditSection).toContain("reportDelivery !== 'contract-failed'");
    expect(auditSection).toContain('Delivered reports must meet the delivery contract.');
    expect(auditSection).toContain('report_share_policy_declared');
    expect(auditSection).toContain('report_meets_delivery_contract');
  });

  it('links successful delivery audits back to active share request records', () => {
    expect(auditSection).toContain('shareRequestId');
    expect(auditSection).toContain('Report share request does not match this delivery audit.');
    expect(auditSection).toContain(
      'Only active report share requests can be linked to delivery audit.'
    );
    expect(auditSection).toContain('deliveryAuditId: id');
  });
});

describe('report share request lifecycle', () => {
  const functionsSource = fs.readFileSync(path.join(functionsDir, 'index.ts'), 'utf8');
  const schemaSource = readSrcFile('types', 'schema.ts');
  const rulesSource = fs.readFileSync(path.join(process.cwd(), 'firestore.rules'), 'utf8');

  it('defines a first-class report share request schema and collection', () => {
    expect(schemaSource).toContain('export interface ReportShareRequest');
    expect(schemaSource).toContain('status: ReportShareRequestStatus');
    expect(schemaSource).toContain('expiresAt: Timestamp');
    expect(schemaSource).toContain('revokedAt?: Timestamp');
  });

  it('keeps report share request writes server-owned in Firestore rules', () => {
    expect(rulesSource).toContain('match /reportShareRequests/{id}');
    expect(rulesSource).toContain('allow create, update, delete: if false');
    expect(rulesSource).toContain('isParentLinkedToLearner(resource.data.learnerId)');
  });

  it('exports create and revoke callables with delivery contract and external-share gates', () => {
    expect(functionsSource).toContain('export const createReportShareRequest');
    expect(functionsSource).toContain('export const revokeReportShareRequest');
    expect(functionsSource).toContain('Report share requests require a passing delivery contract.');
    expect(functionsSource).toContain(
      'External and partner report sharing requires explicit consent workflow support.'
    );
    expect(functionsSource).toContain('SUPPORTED_REPORT_SHARE_REQUEST_AUDIENCES');
    expect(functionsSource).toContain('SUPPORTED_REPORT_SHARE_REQUEST_VISIBILITIES');
    expect(functionsSource).toContain('metadata.report_share_family_safe === true');
    expect(functionsSource).toContain(
      'Report share requests are limited to learner/private and guardian/family policies until explicit consent workflow support exists.'
    );
    expect(functionsSource).toContain(
      'Only completed report deliveries can create active share requests.'
    );
    expect(functionsSource).toContain('report.share_request_revoked');
  });

  it('exposes web active-share management with server-owned revocation', () => {
    const managerSource = readSrcFile('components', 'reports', 'ReportShareRequestManager.tsx');

    expect(managerSource).toContain("'use client'");
    expect(managerSource).toContain('reportShareRequestsCollection');
    expect(managerSource).toContain("where('siteId', '==', siteId)");
    expect(managerSource).toContain("where('learnerId', '==', learnerId)");
    expect(managerSource).toContain("where('status', '==', 'active')");
    expect(managerSource).toContain('revokeReportShareRequest');
    expect(managerSource).toContain('reason: `${viewer}_revoked_report_share`');
    expect(managerSource).toContain('Share revocation failed. The active share is still listed.');
    expect(managerSource).toContain(
      'External/public sharing remains blocked until explicit consent workflow support exists.'
    );
    expect(managerSource).toContain('request.provenance.meetsDeliveryContract');
    expect(managerSource).toContain('formatSignalList(request.provenance.expectedSignals)');
    expect(managerSource).toContain('formatSignalList(request.provenance.missingSignals)');
    expect(managerSource).toContain('request.sharePolicy.requiresEvidenceProvenance');
    expect(managerSource).toContain('request.sharePolicy.requiresGuardianContext');
    expect(managerSource).toContain('request.sharePolicy.allowsExternalSharing');
    expect(managerSource).toContain('data-testid={`report-share-request-manager-${learnerId}`}');
    expect(managerSource).toContain(
      "request.visibility === 'family' || request.visibility === 'private'"
    );
  });
});

/* ───── EvidenceRecord schema sessionOccurrenceId ───── */

describe('EvidenceRecord schema supports session linking', () => {
  const schemaSource = readSrcFile('types', 'schema.ts');

  it('EvidenceRecord has sessionOccurrenceId field', () => {
    const erBlock = schemaSource.match(/export interface EvidenceRecord \{[\s\S]*?\n\}/)?.[0] ?? '';
    expect(erBlock).toContain('sessionOccurrenceId');
  });

  it('SessionOccurrence type exists with required fields', () => {
    const soBlock =
      schemaSource.match(/export interface SessionOccurrence \{[\s\S]*?\n\}/)?.[0] ?? '';
    expect(soBlock).toContain('sessionId');
    expect(soBlock).toContain('date');
    expect(soBlock).toContain('siteId');
    expect(soBlock).toContain('educatorId');
  });
});

/* ───── HQ capability framework site context ───── */

describe('HQ capability framework site context', () => {
  const editorSource = readSrcFile('components', 'capabilities', 'CapabilityFrameworkEditor.tsx');
  const hqRendererSource = readSrcFile(
    'features',
    'workflows',
    'renderers',
    'HqCapabilityFrameworkRenderer.tsx'
  );
  const rubricRendererSource = readSrcFile(
    'features',
    'workflows',
    'renderers',
    'HqRubricBuilderRenderer.tsx'
  );

  it('resolves site context through the shared active-site helper', () => {
    expect(editorSource).toContain('resolveActiveSiteId');
    expect(editorSource).not.toContain('const siteId = profile?.studioId ?? null;');
  });

  it('shows an explicit blocked state when no site is selected', () => {
    expect(editorSource).toContain('data-testid="hq-framework-site-required"');
    expect(editorSource).toContain('Select an active site before editing capabilities');
  });

  it('passes route site context into the HQ framework renderer', () => {
    expect(hqRendererSource).toContain('siteId={resolveActiveSiteId(ctx.profile)}');
  });

  it('passes route site context into the HQ rubric renderer', () => {
    expect(rubricRendererSource).toContain('siteId={resolveActiveSiteId(ctx.profile)}');
  });
});

/* ───── SiteEvidenceHealthDashboard ───── */

describe('SiteEvidenceHealthDashboard school health view', () => {
  const source = readSrcFile('components', 'analytics', 'SiteEvidenceHealthDashboard.tsx');

  it('exists and is non-trivial', () => {
    expect(source.length).toBeGreaterThan(200);
  });

  it('resolves site context through the shared active-site helper', () => {
    expect(source).toContain('resolveActiveSiteId');
    expect(source).not.toContain(
      'const siteId = profile?.activeSiteId ?? profile?.studioId ?? null;'
    );
  });

  it('queries evidence records by site and period', () => {
    expect(source).toContain('evidenceRecordsCollection');
    expect(source).toContain("where('siteId', '==', siteId)");
  });

  it('queries learners and educators by canonical site membership', () => {
    expect(source).toContain("where('siteIds', 'array-contains', siteId)");
  });

  it('calculates learner coverage', () => {
    expect(source).toContain('learnersWithEvidence');
  });

  it('shows per-educator breakdown', () => {
    expect(source).toContain('educatorMetrics');
    expect(source).toContain('data-testid="evidence-health-educators"');
  });

  it('tracks capability mapping rate', () => {
    expect(source).toContain('capabilityMappedRate');
  });

  it('tracks rubric application rate', () => {
    expect(source).toContain('rubricAppliedRate');
  });

  it('alerts on low coverage', () => {
    expect(source).toContain('data-testid="evidence-health-alert"');
  });

  it('shows an explicit no-site blocked state', () => {
    expect(source).toContain('data-testid="evidence-health-site-required"');
    expect(source).toContain('Select an active site before reviewing school evidence health.');
  });

  it('uses RoleRouteGuard for site/hq access', () => {
    expect(source).toContain('RoleRouteGuard');
    expect(source).toContain("'site'");
    expect(source).toContain("'hq'");
  });
});

/* ───── Collections exports for evidence chain ───── */

describe('Evidence chain collection exports completeness', () => {
  const collectionsSource = readSrcFile('firebase', 'firestore', 'collections.ts');

  const evidenceCollections = [
    'sessionOccurrencesCollection',
    'sessionsCollection',
    'evidenceRecordsCollection',
    'checkpointsCollection',
    'portfolioItemsCollection',
    'learnerReflectionsCollection',
    'capabilityGrowthEventsCollection',
    'capabilityMasteryCollection',
    'rubricApplicationsCollection',
    'rubricTemplatesCollection',
    'showcaseSubmissionsCollection',
    'peerFeedbackCollection',
    'learnerProfilesCollection',
    'recognitionBadgesCollection',
  ];

  for (const name of evidenceCollections) {
    it(`exports ${name}`, () => {
      expect(collectionsSource).toContain(`export const ${name}`);
    });
  }
});

describe('P1-F typed collection reconciliation', () => {
  const workflowDataSource = readSrcFile('features', 'workflows', 'workflowData.ts');
  const showcaseRendererSource = readSrcFile(
    'features',
    'workflows',
    'renderers',
    'LearnerShowcasePeerReviewRenderer.tsx'
  );
  const showcaseFormSource = readSrcFile('components', 'showcase', 'ShowcaseSubmissionForm.tsx');
  const showcaseGallerySource = readSrcFile('components', 'showcase', 'ShowcaseGallery.tsx');
  const motivationSource = readSrcFile('lib', 'motivation', 'motivationEngine.ts');

  it('keeps learner profile and peer feedback writes on typed refs', () => {
    expect(workflowDataSource).toContain('learnerProfilesCollection');
    expect(workflowDataSource).toContain('peerFeedbackCollection');
    expect(workflowDataSource).not.toContain("collection(firestore, 'learnerProfiles')");
    expect(workflowDataSource).not.toContain("collection(firestore, 'peerFeedback')");
  });

  it('keeps showcase and peer-review surfaces on typed refs', () => {
    const combinedShowcaseSource = [
      showcaseRendererSource,
      showcaseFormSource,
      showcaseGallerySource,
    ].join('\n');
    expect(combinedShowcaseSource).toContain('showcaseSubmissionsCollection');
    expect(showcaseRendererSource).toContain('peerFeedbackCollection');
    expect(combinedShowcaseSource).not.toContain("collection(firestore, 'showcaseSubmissions')");
    expect(combinedShowcaseSource).not.toContain("collection(db, 'showcaseSubmissions')");
    expect(showcaseRendererSource).not.toContain("collection(firestore, 'peerFeedback')");
  });

  it('keeps motivation belonging writes on typed refs', () => {
    expect(motivationSource).toContain('showcaseSubmissionsCollection');
    expect(motivationSource).toContain('peerFeedbackCollection');
    expect(motivationSource).toContain('recognitionBadgesCollection');
    expect(motivationSource).not.toContain("collection(db, 'showcaseSubmissions')");
    expect(motivationSource).not.toContain("collection(db, 'peerFeedback')");
    expect(motivationSource).not.toContain("collection(db, 'recognitionBadges')");
  });
});

/* ───── CapabilityFrameworkEditor unit/checkpoint mapping ───── */

describe('CapabilityFrameworkEditor unit mapping', () => {
  const source = readSrcFile('components', 'capabilities', 'CapabilityFrameworkEditor.tsx');

  it('includes unitMappings in capability form data', () => {
    expect(source).toContain('unitMappings');
  });

  it('imports missionsCollection for unit selector', () => {
    expect(source).toContain('missionsCollection');
  });

  it('loads missions data', () => {
    expect(source).toContain('setMissions');
    expect(source).toMatch(/useState<Mission\[\]>/);
  });

  it('renders mission checkboxes for mapping', () => {
    expect(source).toContain('missions.map');
  });

  it('saves unitMappings in the shared capability payload', () => {
    const payloadBlock = source.slice(
      source.indexOf('const capabilityPayload = {'),
      source.indexOf('if (editingCapabilityId)', source.indexOf('const capabilityPayload = {'))
    );
    expect(payloadBlock).toContain('unitMappings');
    expect(payloadBlock).toContain('checkpointMappings: syncedCheckpointMappings');
  });

  it('populates unitMappings when editing existing capability', () => {
    expect(source).toContain('unitMappings: cap.unitMappings');
  });

  it('imports canonical checkpoint definitions', () => {
    expect(source).toContain('checkpointsCollection');
    expect(source).toContain('useState<Checkpoint[]>');
  });

  it('syncs authored checkpoint mappings into checkpoint docs', () => {
    expect(source).toContain('writeBatch(firestore)');
    expect(source).toContain('capabilityTitle: title');
    expect(source).toContain('checkpointMappings: syncedCheckpointMappings');
    expect(source).toContain("status: 'active'");
  });

  it('requires mission and checkpoint number instead of pasted checkpoint ids', () => {
    expect(source).toContain('Select a mission for checkpoint');
    expect(source).toContain('Add a checkpoint number');
    expect(source).not.toContain('Checkpoint ID (paste from checkpoint doc, optional)');
  });
});
