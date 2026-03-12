'use client';

import React, { useState } from 'react';
import { useCollection, useDocument } from 'react-firebase-hooks/firestore';
import { query, where, doc } from 'firebase/firestore';
import { missionAttemptsCollection, usersCollection, missionsCollection } from '@/src/firebase/firestore/collections';
import { MissionAttempt } from '@/src/types/schema';
import { useInteractionTracking, usePageViewTracking } from '@/src/hooks/useTelemetry';
import { FeedbackForm } from './FeedbackForm';

export function SubmissionGrader() {
  usePageViewTracking('submission_grader_queue');

  // Fetch all submitted attempts
  const [attemptsSnap, loading] = useCollection(
    query(missionAttemptsCollection, where('status', '==', 'submitted'))
  );

  if (loading) return <div>Loading submissions...</div>;
  if (!attemptsSnap || attemptsSnap.empty) return <div className="text-gray-500">No pending submissions.</div>;

  return (
    <div className="space-y-4">
      <div className="grid gap-4">
        {attemptsSnap.docs.map(d => (
          <SubmissionItem key={d.id} attempt={{ ...d.data(), id: d.id } as MissionAttempt} />
        ))}
      </div>
    </div>
  );
}

function SubmissionItem({ attempt }: { attempt: MissionAttempt }) {
  const [isGrading, setIsGrading] = useState(false);
  const trackInteraction = useInteractionTracking();
  
  // Fetch Learner Name
  const [learnerSnap] = useDocument(doc(usersCollection, attempt.learnerId));
  const learnerName = learnerSnap?.data()?.displayName || 'Unknown Learner';

  // Fetch Mission Title
  const [missionSnap] = useDocument(doc(missionsCollection, attempt.missionId));
  const missionTitle = missionSnap?.data()?.title || 'Unknown Mission';

  return (
    <div className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
      <div className="flex items-start justify-between">
        <div>
          <h3 className="font-medium text-gray-900">{missionTitle}</h3>
          <p className="text-sm text-gray-500">by {learnerName}</p>
          <p className="mt-2 text-sm text-gray-700 bg-gray-50 p-2 rounded">
            {attempt.content || '(No content provided)'}
          </p>
          <p className="mt-1 text-xs text-gray-400">
            Submitted: {attempt.submittedAt?.toDate().toLocaleString()}
          </p>
        </div>
        {!isGrading && (
          <button 
            onClick={() => {
              trackInteraction('help_accessed', {
                cta: 'mission_attempt_grade_open',
                attemptId: attempt.id,
                missionId: attempt.missionId,
                learnerId: attempt.learnerId,
              });
              setIsGrading(true);
            }}
            className="rounded-md bg-indigo-50 px-3 py-1.5 text-sm font-medium text-indigo-700 hover:bg-indigo-100"
          >
            Grade
          </button>
        )}
      </div>

      {isGrading && (
        <FeedbackForm 
          attemptId={attempt.id} 
          onSuccess={() => setIsGrading(false)} 
          onCancel={() => setIsGrading(false)} 
        />
      )}
    </div>
  );
}