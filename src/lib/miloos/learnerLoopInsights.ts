import { getFunctions, httpsCallable } from 'firebase/functions';

const functions = getFunctions();

export interface MiloOSLearnerLoopInsights {
  siteId: string;
  learnerId: string;
  lookbackDays: number;
  state: {
    cognition: number | null;
    engagement: number | null;
    integrity: number | null;
  } | null;
  trend: {
    cognitionDelta: number | null;
    engagementDelta: number | null;
    integrityDelta: number | null;
    improvementScore: number | null;
  } | null;
  stateAvailability: {
    validSamples: number;
    hasCurrentState: boolean;
    hasTrendBaseline: boolean;
  };
  eventCounts: Record<string, number>;
  verification: {
    aiHelpOpened: number;
    aiHelpUsed: number;
    explainBackSubmitted: number;
    pendingExplainBack: number;
  };
  mvl: {
    active: number;
    passed: number;
    failed: number;
  };
  activeGoals: string[];
  generatedAt: string;
  error?: string;
}

export async function getMiloOSLearnerLoopInsights(params: {
  learnerId: string;
  siteId: string;
  lookbackDays?: number;
}): Promise<MiloOSLearnerLoopInsights> {
  const callable = httpsCallable<
    { learnerId: string; siteId: string; lookbackDays?: number },
    MiloOSLearnerLoopInsights
  >(functions, 'bosGetLearnerLoopInsights');
  const result = await callable(params);
  return result.data;
}
