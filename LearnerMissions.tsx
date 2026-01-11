'use client';

import React, { useState } from 'react';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { useCollection } from 'react-firebase-hooks/firestore';
import { query, where, addDoc, Timestamp } from 'firebase/firestore';
import { enrolmentsCollection, missionsCollection, missionAttemptsCollection } from '@/src/firebase/firestore/collections';
import { Mission, MissionAttempt } from '@/src/types/schema';
import { UserProfile } from '@/src/types/user';

export function LearnerMissions() {
  const { user, profile: authProfile } = useAuthContext();
  const profile = authProfile as UserProfile | null;
  const [selectedMission, setSelectedMission] = useState<Mission | null>(null);
  const [submissionContent, setSubmissionContent] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  // 1. Get Enrollments
  const [enrolmentsSnap] = useCollection(
    user ? query(enrolmentsCollection, where('userId', '==', user.uid), where('status', '==', 'active')) : null
  );

  // 2. Get Missions based on enrolled courses
  // Note: Firestore 'in' query limited to 10. For MVP we assume < 10 active courses.
  const courseIds = enrolmentsSnap?.docs.map(d => d.data().courseId) || [];
  
  const [missionsSnap] = useCollection(
    courseIds.length > 0 
      ? query(missionsCollection, where('courseId', 'in', courseIds)) 
      : null
  );

  // 3. Get Previous Attempts (to show status)
  const [attemptsSnap] = useCollection(
    user ? query(missionAttemptsCollection, where('learnerId', '==', user.uid)) : null
  );

  const getMissionStatus = (missionId: string) => {
    const attempt = attemptsSnap?.docs.find(d => d.data().missionId === missionId);
    return attempt?.data().status || 'todo';
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user || !selectedMission || !profile) return;

    setIsSubmitting(true);
    try {
      const attempt: Omit<MissionAttempt, 'id'> = {
        learnerId: user.uid,
        missionId: selectedMission.id,
        siteId: profile.studioId || 'default',
        status: 'submitted',
        content: submissionContent,
        submittedAt: Timestamp.now(),
      };
      
      await addDoc(missionAttemptsCollection, attempt);
      setSelectedMission(null);
      setSubmissionContent('');
    } catch (err) {
      console.error(err);
      alert('Failed to submit mission');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="grid gap-6 md:grid-cols-2">
      {/* Mission List */}
      <div className="space-y-4">
        <h2 className="text-xl font-bold text-gray-900">Your Missions</h2>
        <div className="grid gap-3">
          {missionsSnap?.docs.map(doc => {
            const m = doc.data();
            const status = getMissionStatus(doc.id);
            return (
              <div 
                key={doc.id}
                onClick={() => setSelectedMission({ ...m, id: doc.id })}
                className={`cursor-pointer rounded-lg border p-4 transition-all ${
                  selectedMission?.id === doc.id 
                    ? 'border-indigo-500 bg-indigo-50 ring-1 ring-indigo-500' 
                    : 'border-gray-200 bg-white hover:border-indigo-300'
                }`}
              >
                <div className="flex justify-between items-start">
                  <div>
                    <h3 className="font-semibold text-gray-900">{m.title}</h3>
                    <div className="flex gap-2 mt-1">
                      <span className="text-xs font-medium text-gray-500">{m.xp} XP</span>
                      {m.pillarCodes.map(p => (
                        <span key={p} className="text-xs rounded-full bg-gray-100 px-2 py-0.5 text-gray-600">
                          {p.split('_')[0]}
                        </span>
                      ))}
                    </div>
                  </div>
                  <StatusBadge status={status} />
                </div>
              </div>
            );
          })}
          {missionsSnap?.empty && <p className="text-gray-500">No missions found.</p>}
        </div>
      </div>

      {/* Mission Detail / Submit */}
      <div className="rounded-lg border border-gray-200 bg-white p-6 h-fit sticky top-6">
        {selectedMission ? (
          <div className="space-y-6">
            <div>
              <h2 className="text-2xl font-bold text-gray-900">{selectedMission.title}</h2>
              <div className="mt-2 prose prose-sm text-gray-600">
                {selectedMission.content}
              </div>
            </div>

            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700">Your Submission</label>
                <textarea
                  required
                  rows={6}
                  value={submissionContent}
                  onChange={(e) => setSubmissionContent(e.target.value)}
                  className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                  placeholder="Type your response or paste a link to your artifact..."
                />
              </div>
              <div className="flex justify-end gap-3">
                <button
                  type="button"
                  onClick={() => setSelectedMission(null)}
                  className="rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSubmitting}
                  className="rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 disabled:opacity-50"
                >
                  {isSubmitting ? 'Submitting...' : 'Submit Mission'}
                </button>
              </div>
            </form>
          </div>
        ) : (
          <div className="flex h-64 items-center justify-center text-gray-400 text-center">
            Select a mission to view details <br/> and submit your work.
          </div>
        )}
      </div>
    </div>
  );
}

function StatusBadge({ status }: { status: string }) {
  const styles = {
    todo: 'bg-gray-100 text-gray-600',
    started: 'bg-blue-100 text-blue-700',
    submitted: 'bg-yellow-100 text-yellow-800',
    completed: 'bg-green-100 text-green-700',
  };
  return (
    <span className={`rounded-full px-2.5 py-0.5 text-xs font-medium capitalize ${styles[status as keyof typeof styles] || styles.todo}`}>
      {status}
    </span>
  );
}