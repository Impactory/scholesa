type UnknownRecord = Record<string, unknown>;

const DEFAULT_EXPLAIN_BACK_FEEDBACK = 'Explain-back recorded for review.';
const EXPLAIN_BACK_TOO_SHORT_FEEDBACK = 'Your explanation is too short. Try to explain the concept in your own words with more detail.';
const EXPLAIN_BACK_COPIED_FEEDBACK = 'It looks like your explanation is very similar to the original AI response. Try rephrasing in your own words.';
const EXPLAIN_BACK_APPROVED_FEEDBACK = 'Great explanation! Your understanding has been recorded.';
const EXPLAIN_BACK_NEEDS_DETAIL_FEEDBACK = 'Good start! Can you add a bit more about what you learned and why it matters?';

const MIN_EXPLAIN_BACK_LENGTH = 20;
const MIN_EXPLAIN_BACK_WORDS = 5;
const COPY_SIMILARITY_THRESHOLD = 0.75;

function asTrimmedString(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

/**
 * Compute a simple word-overlap (Jaccard) similarity between two texts.
 * Returns a value between 0 (no overlap) and 1 (identical word sets).
 */
function wordOverlapSimilarity(textA: string, textB: string): number {
  const normalize = (t: string) =>
    t.toLowerCase().replace(/[^a-z0-9\s]/g, '').split(/\s+/).filter(w => w.length > 2);
  const wordsA = new Set(normalize(textA));
  const wordsB = new Set(normalize(textB));
  if (wordsA.size === 0 || wordsB.size === 0) return 0;
  let intersection = 0;
  for (const w of wordsA) {
    if (wordsB.has(w)) intersection++;
  }
  return intersection / Math.max(wordsA.size, wordsB.size);
}

export interface ExplainBackOpenedEvent {
  siteId: string;
  gradeBand?: unknown;
  sessionOccurrenceId?: unknown;
  missionId?: unknown;
  checkpointId?: unknown;
  payload?: UnknownRecord;
}

export interface ExplainBackSubmittedEvent {
  eventType: 'explain_it_back_submitted';
  siteId: string;
  actorId: string;
  actorRole: 'learner';
  gradeBand: string | null;
  sessionOccurrenceId: string | null;
  missionId: string | null;
  checkpointId: string | null;
  payload: {
    aiHelpOpenedEventId: string;
    explainBackLength: number;
    approved: boolean;
    feedback: string;
    mode: string | null;
    rejectionReason?: string;
    wordOverlapWithAiResponse?: number;
  };
}

export interface ExplainBackVerificationResult {
  approved: boolean;
  feedback: string;
  rejectionReason?: string;
  wordOverlapWithAiResponse?: number;
}

/**
 * Verify an explain-back submission using heuristic checks.
 * Returns approval status and pedagogically helpful feedback.
 *
 * Checks performed:
 * 1. Minimum length/word count (is the explanation substantive?)
 * 2. Copy detection (is it too similar to the AI response?)
 * 3. Minimum effort threshold (does it show genuine thought?)
 */
export function verifyExplainBack(
  explainBack: string,
  aiResponseText?: string,
): ExplainBackVerificationResult {
  const trimmed = explainBack.trim();
  const words = trimmed.split(/\s+/).filter(w => w.length > 0);

  // Check 1: Minimum length
  if (trimmed.length < MIN_EXPLAIN_BACK_LENGTH || words.length < MIN_EXPLAIN_BACK_WORDS) {
    return {
      approved: false,
      feedback: EXPLAIN_BACK_TOO_SHORT_FEEDBACK,
      rejectionReason: 'too_short',
    };
  }

  // Check 2: Copy detection against AI response
  if (aiResponseText && aiResponseText.trim().length > 0) {
    const similarity = wordOverlapSimilarity(trimmed, aiResponseText);
    if (similarity >= COPY_SIMILARITY_THRESHOLD) {
      return {
        approved: false,
        feedback: EXPLAIN_BACK_COPIED_FEEDBACK,
        rejectionReason: 'copied_ai_response',
        wordOverlapWithAiResponse: Math.round(similarity * 100) / 100,
      };
    }

    // Check 3: Moderate effort — needs some substance but not a copy
    if (words.length < 10 && similarity < 0.2) {
      return {
        approved: false,
        feedback: EXPLAIN_BACK_NEEDS_DETAIL_FEEDBACK,
        rejectionReason: 'insufficient_detail',
        wordOverlapWithAiResponse: Math.round(similarity * 100) / 100,
      };
    }

    return {
      approved: true,
      feedback: EXPLAIN_BACK_APPROVED_FEEDBACK,
      wordOverlapWithAiResponse: Math.round(similarity * 100) / 100,
    };
  }

  // No AI response available for comparison — check effort only
  if (words.length < 10) {
    return {
      approved: false,
      feedback: EXPLAIN_BACK_NEEDS_DETAIL_FEEDBACK,
      rejectionReason: 'insufficient_detail',
    };
  }

  return {
    approved: true,
    feedback: EXPLAIN_BACK_APPROVED_FEEDBACK,
  };
}

export function buildExplainBackSubmittedEvent(params: {
  actorId: string;
  aiHelpOpenedEventId: string;
  explainBack: string;
  openedEvent: ExplainBackOpenedEvent;
  verification?: ExplainBackVerificationResult;
}): ExplainBackSubmittedEvent {
  const { actorId, aiHelpOpenedEventId, explainBack, openedEvent, verification } = params;

  const result = verification ?? { approved: true, feedback: DEFAULT_EXPLAIN_BACK_FEEDBACK };

  return {
    eventType: 'explain_it_back_submitted',
    siteId: openedEvent.siteId,
    actorId,
    actorRole: 'learner',
    gradeBand: asTrimmedString(openedEvent.gradeBand),
    sessionOccurrenceId: asTrimmedString(openedEvent.sessionOccurrenceId),
    missionId: asTrimmedString(openedEvent.missionId),
    checkpointId: asTrimmedString(openedEvent.checkpointId),
    payload: {
      aiHelpOpenedEventId,
      explainBackLength: explainBack.trim().length,
      approved: result.approved,
      feedback: result.feedback,
      mode: asTrimmedString(openedEvent.payload?.mode),
      ...(result.rejectionReason && { rejectionReason: result.rejectionReason }),
      ...(result.wordOverlapWithAiResponse !== undefined && {
        wordOverlapWithAiResponse: result.wordOverlapWithAiResponse,
      }),
    },
  };
}

export const explainBackRecordedFeedback = DEFAULT_EXPLAIN_BACK_FEEDBACK;
