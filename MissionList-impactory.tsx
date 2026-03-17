'use client';

import React from 'react';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { useCollection } from 'react-firebase-hooks/firestore';
import { query, where, orderBy, addDoc, doc, updateDoc, Timestamp } from 'firebase/firestore';
import { enrolmentsCollection, missionsCollection, missionAttemptsCollection } from '@/src/firebase/firestore/collections';
import { Mission, MissionAttempt } from '@/src/types/schema';
import { ReflectionForm } from '@/ReflectionForm';

export function MissionList() {
  const { user, profile } = useAuthContext();
  const siteId = profile?.activeSiteId?.trim() || profile?.studioId?.trim() || profile?.siteIds?.[0]?.trim() || '';

  // 1. Get Enrollments
  const [enrolmentsSnap, loadingEnrolments] = useCollection(
    user ? query(enrolmentsCollection, where('userId', '==', user.uid), where('status', '==', 'active')) : null
  );

  // 2. Get All Attempts for this user (to check status)
  const [attemptsSnap] = useCollection(
    user ? query(missionAttemptsCollection, where('learnerId', '==', user.uid)) : null
  );

  if (loadingEnrolments) return <div className="animate-pulse h-20 bg-gray-100 rounded-md" />;
  if (!enrolmentsSnap || enrolmentsSnap.empty) return <div className="text-gray-500">You are not enrolled in any courses yet.</div>;

  return (
    <div className="space-y-8">
      {enrolmentsSnap.docs.map(enrolDoc => {
        const enrol = enrolDoc.data();
        return (
          <CourseMissions 
            key={enrol.id} 
            courseId={enrol.courseId} 
            userId={user!.uid}
            siteId={siteId}
            attempts={attemptsSnap?.docs.map(d => d.data()) || []}
          />
        );
      })}
    </div>
  );
}

function CourseMissions({ courseId, userId, siteId, attempts }: { courseId: string, userId: string, siteId: string, attempts: MissionAttempt[] }) {
  // Fetch missions for this course
  const [missionsSnap, loading] = useCollection(
    query(missionsCollection, where('courseId', '==', courseId), orderBy('order', 'asc'))
  );

  if (loading) return <div className="py-4">Loading missions...</div>;
  if (!missionsSnap || missionsSnap.empty) return null;

  return (
    <div className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
      <h3 className="mb-4 text-lg font-semibold text-gray-900">Course: {courseId}</h3>
      <div className="space-y-4">
        {missionsSnap.docs.map(mDoc => {
          const mission = mDoc.data();
          // Find latest attempt for this mission
          const attempt = attempts.find(a => a.missionId === mDoc.id);
          
          return (
            <MissionItem 
              key={mDoc.id} 
              mission={{ ...mission, id: mDoc.id } as Mission} 
              attempt={attempt}
              userId={userId}
              siteId={siteId}
            />
          );
        })}
      </div>
    </div>
  );
}

function MissionItem({ mission, attempt, userId, siteId }: { mission: Mission, attempt?: MissionAttempt, userId: string, siteId: string }) {
  const [isSubmitting, setIsSubmitting] = React.useState(false);
  const [isReflecting, setIsReflecting] = React.useState(false);
  const [startError, setStartError] = React.useState<string | null>(null);
  const canStartMission = siteId.length > 0;

  const handleStart = async () => {
    if (!canStartMission) {
      setStartError('Mission start is unavailable until your learner profile has an active site assignment.');
      return;
    }

    setIsSubmitting(true);
    setStartError(null);
    try {
      await addDoc(missionAttemptsCollection, {
        learnerId: userId,
        missionId: mission.id,
        siteId,
        status: 'started',
        submittedAt: Timestamp.now(),
      } as any); // Cast for addDoc compatibility with typed collection
    } catch (e) {
      console.error(e);
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleReflectionSuccess = async () => {
    await handleSubmit();
    setIsReflecting(false);
  };

  const handleSubmit = async () => {
    if (!attempt) return;
    setIsSubmitting(true);
    try {
      await updateDoc(doc(missionAttemptsCollection, attempt.id), {
        status: 'submitted',
        submittedAt: Timestamp.now(),
      });
    } catch (e) {
      console.error(e);
    } finally {
      setIsSubmitting(false);
    }
  };

  const status = attempt?.status || 'not-started';

  return (
    <div className="rounded-lg border border-gray-100 bg-gray-50 p-4 transition-all hover:border-indigo-100 hover:bg-indigo-50/30">
      {startError ? (
        <p className="mb-3 rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
          {startError}
        </p>
      ) : null}
      <div className="flex items-center justify-between">
      <div>
        <h4 className="font-medium text-gray-900">{mission.title}</h4>
        <div className="mt-1 flex gap-2">
          <span className="inline-flex items-center rounded-full bg-blue-100 px-2 py-0.5 text-xs font-medium text-blue-800">
            {mission.xp} XP
          </span>
          {mission.pillarCodes.map(p => (
            <span key={p} className="inline-flex items-center rounded-full bg-purple-100 px-2 py-0.5 text-xs font-medium text-purple-800">
              {p.split('_')[0]}
            </span>
          ))}
        </div>
      </div>
      
      <div>
        {status === 'not-started' && (
          <button onClick={handleStart} disabled={isSubmitting || !canStartMission} className="rounded-md bg-indigo-600 px-3 py-1.5 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50">Start</button>
        )}
        {status === 'started' && (
          <button onClick={() => setIsReflecting(true)} disabled={isSubmitting || isReflecting} className="rounded-md bg-white px-3 py-1.5 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50">Submit</button>
        )}
        {status === 'submitted' && <span className="text-sm font-medium text-green-600">Submitted</span>}
        {status === 'completed' && <span className="text-sm font-medium text-green-600">Completed ✅</span>}
      </div>
      </div>
      
      {isReflecting && (
        <ReflectionForm 
          userId={userId} 
          missionId={mission.id} 
          onSuccess={handleReflectionSuccess} 
          onCancel={() => setIsReflecting(false)} 
        />
      )}
    </div>
  );
}