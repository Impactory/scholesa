'use client';

/**
 * Checkpoint Submission Component
 * 
 * Allows learners to submit checkpoint attempts (SDT competence pillar).
 * Tracks checkpoint attempts and passes via telemetry.
 */

import React, { useState } from 'react';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { CompetenceEngine } from '@/src/lib/motivation/motivationEngine';
import { useCompetenceTracking } from '@/src/hooks/useTelemetry';
import { CheckCircleIcon, XIcon, AlertCircleIcon } from 'lucide-react';

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
  const trackCompetence = useCompetenceTracking();
  
  const [answers, setAnswers] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<{ passed: boolean; feedback: string } | null>(null);
  
  const learnerId = profile?.uid || '';
  const siteId = profile?.activeSiteId || profile?.siteIds?.[0] || '';
  
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    // Check all questions answered
    if (Object.keys(answers).length < requiredSkills.length) {
      return;
    }
    
    setLoading(true);
    
    try {
      // Track checkpoint attempt - removed, using only checkpoint_passed event
      
      // Simulate grading (in real app, this would call AI grading or educator review)
      const passed = Math.random() > 0.3; // 70% pass rate for demo
      
      if (passed) {
        // Record checkpoint passed via CompetenceEngine
        await CompetenceEngine.recordCheckpointPassed(
          learnerId,
          siteId,
          5, // grade - K-9 grade level, using 5 as default
          missionId,
          checkpointNumber,
          requiredSkills
        );
        
        // Track checkpoint passed
        trackCompetence('checkpoint_passed', {
          missionId,
          checkpointNumber,
          skillCount: requiredSkills.length,
          attemptDuration: 0 // Would calculate actual duration
        });
        
        setResult({
          passed: true,
          feedback: 'Great work! You have demonstrated mastery of these skills.'
        });
      } else {
        setResult({
          passed: false,
          feedback: 'Not quite there yet. Review the feedback and try again when ready.'
        });
      }
      
      // Notify parent
      if (onSubmitted) onSubmitted(passed);
      
    } catch (err) {
      console.error('Failed to submit checkpoint:', err);
      setResult({
        passed: false,
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
          result.passed ? 'bg-green-50 border border-green-200' : 'bg-amber-50 border border-amber-200'
        }`}>
          {result.passed ? (
            <CheckCircleIcon className="h-16 w-16 text-green-600 mx-auto mb-4" />
          ) : (
            <AlertCircleIcon className="h-16 w-16 text-amber-600 mx-auto mb-4" />
          )}
          
          <h3 className={`text-xl font-bold mb-2 ${
            result.passed ? 'text-green-900' : 'text-amber-900'
          }`}>
            {result.passed ? 'Checkpoint Passed! 🎉' : 'Keep Trying!'}
          </h3>
          
          <p className={`text-sm mb-6 ${
            result.passed ? 'text-green-800' : 'text-amber-800'
          }`}>
            {result.feedback}
          </p>
          
          <button
            onClick={onClose}
            className={`px-6 py-2 rounded-md font-medium ${
              result.passed
                ? 'bg-green-600 text-white hover:bg-green-700'
                : 'bg-amber-600 text-white hover:bg-amber-700'
            }`}
          >
            {result.passed ? 'Continue' : 'Review & Retry'}
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
