'use client';

/**
 * Checkpoint Submission Component
 * 
 * Allows learners to submit checkpoint attempts (SDT competence pillar).
 * Tracks checkpoint attempts and passes via telemetry.
 */

import React, { useState } from 'react';
import { Timestamp, addDoc, getDocs, query, serverTimestamp, where } from 'firebase/firestore';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { trackUnifiedEvent } from '@/src/lib/analytics';
import { CheckCircleIcon, XIcon, AlertCircleIcon } from 'lucide-react';
import { missionAttemptsCollection, skillEvidenceCollection } from '@/src/firebase/firestore/collections';
import type { SkillEvidence } from '@/src/types/schema';

interface CheckpointSubmissionProps {
  missionId: string;
  checkpointNumber: number;
  requiredSkills: string[];
  onClose?: () => void;
  onSubmitted?: (passed: boolean) => void;
}

export function CheckpointSubmission({ 
  missionId,
  checkpointNumber,
  requiredSkills,
  onClose,
  onSubmitted
}: CheckpointSubmissionProps) {
  const { profile } = useAuthContext();
  
  const [answers, setAnswers] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<{ status: 'submitted' | 'error'; feedback: string } | null>(null);
  
  const learnerId = profile?.uid || '';
  const siteId = profile?.activeSiteId || profile?.siteIds?.[0] || '';
  const rawGrade = (profile as unknown as { grade?: unknown } | null)?.grade;
  const resolvedGrade = typeof rawGrade === 'number' ? rawGrade : null;
  const resolvedGradeBand = resolvedGrade == null
    ? null
    : resolvedGrade <= 3
    ? 'grades_1_3'
    : resolvedGrade <= 6
    ? 'grades_4_6'
    : resolvedGrade <= 9
    ? 'grades_7_9'
    : 'grades_10_12';
  
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    // Check all questions answered
    if (Object.keys(answers).length < requiredSkills.length) {
      return;
    }

    if (!learnerId || !siteId) {
      setResult({
        status: 'error',
        feedback: 'Your account is missing learner or site context. Refresh and try again.',
      });
      return;
    }
    
    setLoading(true);
    
    try {
      const attemptsQuery = query(
        missionAttemptsCollection,
        where('learnerId', '==', learnerId),
        where('missionId', '==', missionId),
      );
      const attemptsSnapshot = await getDocs(attemptsQuery);
      const attemptNumber = attemptsSnapshot.size + 1;
      const checkpointId = `${missionId}:checkpoint:${checkpointNumber}`;
      const content = requiredSkills
        .map((skill) => `Skill: ${skill}\nResponse: ${answers[skill]?.trim() || ''}`)
        .join('\n\n');

      await addDoc(missionAttemptsCollection, {
        learnerId,
        missionId,
        siteId,
        status: 'submitted',
        content,
        submittedAt: serverTimestamp(),
      });

      // S2-2: Auto-create SkillEvidence records for each assessed skill
      await Promise.all(
        requiredSkills.map((skill) =>
          addDoc(skillEvidenceCollection, {
            learnerId,
            siteId,
            microSkillId: skill,
            evidenceType: 'quiz',
            description: `Checkpoint ${checkpointNumber} response for "${skill}" on mission ${missionId}`,
            selfScore: 'developing',
            status: 'submitted',
            submittedAt: serverTimestamp(),
            updatedAt: serverTimestamp(),
          } as unknown as Omit<SkillEvidence, 'id'>)
        )
      );

      await trackUnifiedEvent({
        userId: learnerId,
        userRole: 'learner',
        siteId,
        telemetryEvent: 'checkpoint_attempted',
        analyticsEvent: resolvedGradeBand
          ? {
              event_name: 'checkpoint_submitted',
              event_id: `cp_${Date.now()}`,
              event_time: Timestamp.now(),
              class_id: siteId,
              student_id: learnerId,
              grade_band_id: resolvedGradeBand,
              app_version: '1.0.0',
              device_type: 'web',
              source_screen: 'checkpoint',
              checkpoint_id: checkpointId,
              mission_id: missionId,
              skill_id: requiredSkills[0] || checkpointId,
              attempt_no: attemptNumber,
              passed: false,
            }
          : undefined,
        grade: resolvedGrade ?? undefined,
        metadata: {
          missionId,
          checkpointNumber,
          checkpointId,
          requiredSkills,
          attemptNumber,
          analyticsRecorded: Boolean(resolvedGradeBand),
          submissionStatus: 'submitted_for_review',
        },
      });

      setResult({
        status: 'submitted',
        feedback: 'Checkpoint submitted for review. An educator or approved workflow can now assess it end to end.',
      });

      if (onSubmitted) onSubmitted(false);
      
    } catch (err) {
      console.error('Failed to submit checkpoint:', err);
      setResult({
        status: 'error',
        feedback: 'Failed to submit. Please try again.'
      });
    } finally {
      setLoading(false);
    }
  };
  
  if (result) {
    return (
      <div className="bg-white rounded-lg border border-gray-200 shadow-lg p-6">
        <div className={`rounded-lg p-6 text-center ${
          result.status === 'submitted' ? 'bg-blue-50 border border-blue-200' : 'bg-amber-50 border border-amber-200'
        }`}>
          {result.status === 'submitted' ? (
            <CheckCircleIcon className="h-16 w-16 text-blue-600 mx-auto mb-4" />
          ) : (
            <AlertCircleIcon className="h-16 w-16 text-amber-600 mx-auto mb-4" />
          )}
          
          <h3 className={`text-xl font-bold mb-2 ${
            result.status === 'submitted' ? 'text-blue-900' : 'text-amber-900'
          }`}>
            {result.status === 'submitted' ? 'Checkpoint Submitted' : 'Submission Failed'}
          </h3>
          
          <p className={`text-sm mb-6 ${
            result.status === 'submitted' ? 'text-blue-800' : 'text-amber-800'
          }`}>
            {result.feedback}
          </p>
          
          <button
            onClick={onClose}
            className={`px-6 py-2 rounded-md font-medium ${
              result.status === 'submitted'
                ? 'bg-blue-600 text-white hover:bg-blue-700'
                : 'bg-amber-600 text-white hover:bg-amber-700'
            }`}
          >
            {result.status === 'submitted' ? 'Continue' : 'Close'}
          </button>
        </div>
      </div>
    );
  }
  
  return (
    <div className="bg-white rounded-lg border border-gray-200 shadow-lg p-6">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <CheckCircleIcon className="h-6 w-6 text-blue-600" />
          <h2 className="text-xl font-bold text-gray-900">
            Checkpoint {checkpointNumber}
          </h2>
        </div>
        {onClose && (
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600"
            aria-label="Close"
          >
            <XIcon className="h-5 w-5" />
          </button>
        )}
      </div>
      
      <div className="mb-4 p-3 bg-blue-50 border border-blue-200 rounded-md">
        <p className="text-sm text-blue-800">
          Skills being assessed: <span className="font-semibold">{requiredSkills.join(', ')}</span>
        </p>
      </div>
      
      <form onSubmit={handleSubmit} className="space-y-4">
        {/* Questions generated from required skills */}
        {requiredSkills.map((skill, index) => (
          <div key={skill}>
            <label htmlFor={`q${index}`} className="block text-sm font-medium text-gray-700 mb-1">
              Question {index + 1}: Demonstrate "{skill}"
            </label>
            <textarea
              id={`q${index}`}
              value={answers[skill] || ''}
              onChange={(e) => setAnswers({ ...answers, [skill]: e.target.value })}
              placeholder="Your answer..."
              rows={3}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              required
            />
          </div>
        ))}
        
        {/* Actions */}
        <div className="flex gap-3 pt-2">
          <button
            type="submit"
            disabled={loading || Object.keys(answers).length < requiredSkills.length}
            className="flex-1 px-4 py-2 bg-blue-600 text-white rounded-md font-medium hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loading ? 'Submitting...' : 'Submit Checkpoint'}
          </button>
          {onClose && (
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 bg-gray-100 text-gray-700 rounded-md font-medium hover:bg-gray-200"
            >
              Cancel
            </button>
          )}
        </div>
      </form>
    </div>
  );
}
