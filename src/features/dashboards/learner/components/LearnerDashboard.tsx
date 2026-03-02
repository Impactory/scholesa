import { useEffect, useMemo, useState } from 'react';
import { Card } from '@/src/components/ui/Card';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { doc, getDoc, collection, getDocs, query, where, orderBy, limit } from 'firebase/firestore';
import { firestore } from '@/src/firebase/client-init';

export function LearnerDashboard() {
  const { user, profile } = useAuthContext();
  const siteId = profile?.activeSiteId || profile?.siteIds?.[0] || '';

  const [loading, setLoading] = useState(true);
  const [currentMission, setCurrentMission] = useState('—');
  const [overallProgress, setOverallProgress] = useState(0);
  const [pillarScores, setPillarScores] = useState({
    FUTURE_SKILLS: 0,
    LEADERSHIP_AGENCY: 0,
    IMPACT_INNOVATION: 0,
  });

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
              FUTURE_SKILLS: Number(data.futureSkillsProgress ?? 0),
              LEADERSHIP_AGENCY: Number(data.leadershipProgress ?? 0),
              IMPACT_INNOVATION: Number(data.impactProgress ?? 0),
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
          <h2 className="text-xl font-semibold mb-2">AI Coach</h2>
          <p className="text-gray-600">&quot;Great job on the last quiz! Focus on &apos;Impact &amp; Innovation&apos; next.&quot;</p>
        </Card>
      </div>

      <h2 className="text-2xl font-bold mb-4">My Pillars</h2>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <Card className="p-6">
          <h3 className="font-semibold mb-2">Future Skills</h3>
          <div className="w-full bg-gray-200 rounded-full h-2.5">
            <div className="bg-green-500 h-2.5 rounded-full" style={{ width: `${pillarScores.FUTURE_SKILLS}%` }}></div>
          </div>
          <p className="text-right text-sm mt-1">{pillarScores.FUTURE_SKILLS}%</p>
        </Card>
        <Card className="p-6">
          <h3 className="font-semibold mb-2">Leadership & Agency</h3>
          <div className="w-full bg-gray-200 rounded-full h-2.5">
            <div className="bg-indigo-500 h-2.5 rounded-full" style={{ width: `${pillarScores.LEADERSHIP_AGENCY}%` }}></div>
          </div>
          <p className="text-right text-sm mt-1">{pillarScores.LEADERSHIP_AGENCY}%</p>
        </Card>
        <Card className="p-6">
          <h3 className="font-semibold mb-2">Impact & Innovation</h3>
          <div className="w-full bg-gray-200 rounded-full h-2.5">
            <div className="bg-purple-500 h-2.5 rounded-full" style={{ width: `${pillarScores.IMPACT_INNOVATION}%` }}></div>
          </div>
          <p className="text-right text-sm mt-1">{pillarScores.IMPACT_INNOVATION}%</p>
        </Card>
      </div>
    </div>
  );
}
