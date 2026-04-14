import { useEffect, useMemo, useState } from 'react';
import { Card } from '@/src/components/ui/Card';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { doc, getDoc, collection, getDocs, query, where, orderBy, limit } from 'firebase/firestore';
import { firestore } from '@/src/firebase/client-init';
import { LEGACY_PILLAR_ORDER, getLegacyPillarFamilyLabel } from '@/src/lib/curriculum/architecture';

type PillarScores = {
  FUTURE_SKILLS: number | null;
  LEADERSHIP_AGENCY: number | null;
  IMPACT_INNOVATION: number | null;
};

const EMPTY_PILLAR_SCORES: PillarScores = {
  FUTURE_SKILLS: null,
  LEADERSHIP_AGENCY: null,
  IMPACT_INNOVATION: null,
};

const LEGACY_FAMILY_BAR_COLORS: Record<keyof PillarScores, string> = {
  FUTURE_SKILLS: 'bg-green-500',
  LEADERSHIP_AGENCY: 'bg-indigo-500',
  IMPACT_INNOVATION: 'bg-purple-500',
};

function normalizeProgressMetric(value: unknown): number | null {
  const numeric = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(numeric)) {
    return null;
  }
  return Math.max(0, Math.min(100, Math.round(numeric)));
}

export function LearnerDashboard() {
  const { user, profile } = useAuthContext();
  const siteId = profile?.activeSiteId || profile?.siteIds?.[0] || '';

  const [loading, setLoading] = useState(true);
  const [currentMission, setCurrentMission] = useState('—');
  const [overallProgress, setOverallProgress] = useState(0);
  const [pillarScores, setPillarScores] = useState<PillarScores>(EMPTY_PILLAR_SCORES);
  const [learningSignals, setLearningSignals] = useState<{
    cognition: number | null;
    engagement: number | null;
    integrity: number | null;
  } | null>(null);

  useEffect(() => {
    let isMounted = true;

    const load = async () => {
      if (!user?.uid) {
        if (isMounted) setLoading(false);
        return;
      }

      setLoading(true);
      try {
        const progressRef = doc(firestore, 'learnerProgress', user.uid);
        const progressSnap = await getDoc(progressRef);
        if (progressSnap.exists()) {
          const data = progressSnap.data() as Record<string, unknown>;
          if (isMounted) {
            setPillarScores({
              FUTURE_SKILLS: normalizeProgressMetric(data.futureSkillsProgress),
              LEADERSHIP_AGENCY: normalizeProgressMetric(data.leadershipProgress),
              IMPACT_INNOVATION: normalizeProgressMetric(data.impactProgress),
            });
            setOverallProgress(Number(data.overallProgress ?? data.totalProgress ?? 0));
          }
        }

        const enrollmentQuery = query(
          collection(firestore, 'missionEnrollments'),
          where('learnerId', '==', user.uid),
          ...(siteId ? [where('siteId', '==', siteId)] : []),
          orderBy('updatedAt', 'desc'),
          limit(1),
        );

        const enrollmentSnap = await getDocs(enrollmentQuery);
        if (!enrollmentSnap.empty) {
          const enrollment = enrollmentSnap.docs[0].data() as Record<string, unknown>;
          const missionId = typeof enrollment.missionId === 'string' ? enrollment.missionId : null;
          const missionProgress = Number(enrollment.progress ?? 0);
          if (isMounted && Number.isFinite(missionProgress) && missionProgress > 0) {
            setOverallProgress(missionProgress);
          }

          if (missionId) {
            const missionSnap = await getDoc(doc(firestore, 'missions', missionId));
            if (missionSnap.exists() && isMounted) {
              const missionData = missionSnap.data() as Record<string, unknown>;
              setCurrentMission(typeof missionData.title === 'string' ? missionData.title : missionId);
            }
          }
        }

        // Fetch latest MiloOS learning signals
        const orchQuery = query(
          collection(firestore, 'orchestrationStates'),
          where('learnerId', '==', user.uid),
          ...(siteId ? [where('siteId', '==', siteId)] : []),
          orderBy('lastUpdatedAt', 'desc'),
          limit(1),
        );
        const orchSnap = await getDocs(orchQuery);
        if (!orchSnap.empty && isMounted) {
          const orchData = orchSnap.docs[0].data() as Record<string, unknown>;
          const xHat = orchData.x_hat && typeof orchData.x_hat === 'object'
            ? orchData.x_hat as Record<string, unknown>
            : null;
          if (xHat) {
            setLearningSignals({
              cognition: typeof xHat.cognition === 'number' ? Math.round(xHat.cognition * 100) : null,
              engagement: typeof xHat.engagement === 'number' ? Math.round(xHat.engagement * 100) : null,
              integrity: typeof xHat.integrity === 'number' ? Math.round(xHat.integrity * 100) : null,
            });
          }
        }
      } catch (error) {
        console.error('Failed to load learner dashboard data', error);
      } finally {
        if (isMounted) setLoading(false);
      }
    };

    void load();
    return () => {
      isMounted = false;
    };
  }, [user?.uid, siteId]);

  const progressPct = useMemo(() => {
    if (!Number.isFinite(overallProgress)) return 0;
    return Math.max(0, Math.min(100, Math.round(overallProgress)));
  }, [overallProgress]);

  if (loading) {
    return (
      <div className="p-8">
        <h1 className="text-3xl font-bold mb-6">Learner Dashboard</h1>
        <div className="text-sm text-gray-500">Loading dashboard…</div>
      </div>
    );
  }

  return (
    <div className="p-8">
      <h1 className="text-3xl font-bold mb-6">Learner Dashboard</h1>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <Card className="p-6">
          <h2 className="text-xl font-semibold mb-2">Current Mission</h2>
          <p className="text-gray-600">{currentMission}</p>
        </Card>
        <Card className="p-6">
          <h2 className="text-xl font-semibold mb-2">Overall Progress</h2>
          <div className="w-full bg-gray-200 rounded-full h-2.5 dark:bg-gray-700">
            <div className="bg-blue-600 h-2.5 rounded-full" style={{ width: `${progressPct}%` }}></div>
          </div>
          <p className="text-sm text-gray-500 mt-2">{progressPct}% Complete</p>
        </Card>
        <Card className="p-6">
          <h2 className="text-xl font-semibold mb-2">MiloOS</h2>
          {learningSignals ? (
            <div className="space-y-2">
              <div className="flex justify-between text-sm">
                <span className="text-gray-500">Cognition</span>
                <span className="font-medium">{learningSignals.cognition != null ? `${learningSignals.cognition}%` : '—'}</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-gray-500">Engagement</span>
                <span className="font-medium">{learningSignals.engagement != null ? `${learningSignals.engagement}%` : '—'}</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-gray-500">Integrity</span>
                <span className="font-medium">{learningSignals.integrity != null ? `${learningSignals.integrity}%` : '—'}</span>
              </div>
              <p className="text-xs text-gray-400 mt-2">Learning signals from your latest session</p>
            </div>
          ) : (
            <p className="text-gray-500 text-sm">No learning signals yet. Start a session to see your MiloOS support snapshot.</p>
          )}
        </Card>
      </div>

      <h2 className="text-2xl font-bold mb-2">Legacy Curriculum Families</h2>
      <p className="mb-4 text-sm text-gray-500">
        These compatibility roll-ups group evidence from the live six-strand curriculum.
      </p>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {LEGACY_PILLAR_ORDER.map((familyCode) => (
          <Card key={familyCode} className="p-6">
            <h3 className="font-semibold mb-2">{getLegacyPillarFamilyLabel(familyCode)}</h3>
            <div className="w-full bg-gray-200 rounded-full h-2.5">
              <div
                className={`${LEGACY_FAMILY_BAR_COLORS[familyCode]} h-2.5 rounded-full`}
                style={{ width: `${pillarScores[familyCode] ?? 0}%` }}
              ></div>
            </div>
            <p className="text-right text-sm mt-1">
              {pillarScores[familyCode] != null ? `${pillarScores[familyCode]}%` : 'No evidence yet'}
            </p>
          </Card>
        ))}
      </div>
    </div>
  );
}
