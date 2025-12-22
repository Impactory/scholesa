'use client';

import React, { useState } from 'react';
import { doc, updateDoc } from 'firebase/firestore';
import { missionAttemptsCollection } from '@/src/firebase/firestore/collections';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';

interface Props {
  attemptId: string;
  onSuccess: () => void;
  onCancel: () => void;
}

export function FeedbackForm({ attemptId, onSuccess, onCancel }: Props) {
  const { user } = useAuthContext();
  const [feedback, setFeedback] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleGrade = async (status: 'completed' | 'started') => {
    if (!user) return;
    setIsSubmitting(true);
    try {
      await updateDoc(doc(missionAttemptsCollection, attemptId), {
        status,
        feedback,
        gradedBy: user.uid,
      });
      onSuccess();
    } catch (error) {
      console.error('Error grading submission:', error);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="mt-4 rounded-md border border-gray-200 bg-gray-50 p-4">
      <label className="block text-sm font-medium text-gray-700 mb-2">
        Educator Feedback
      </label>
      <textarea
        className="w-full rounded-md border border-gray-300 p-2 text-sm focus:border-indigo-500 focus:ring-indigo-500"
        rows={3}
        value={feedback}
        onChange={(e) => setFeedback(e.target.value)}
        placeholder='Great job! / Please add more details...'
      />
      <div className="mt-3 flex justify-end gap-2">
        <button 
          onClick={onCancel} 
          disabled={isSubmitting} 
          className="rounded-md px-3 py-1.5 text-sm font-medium text-gray-700 hover:bg-gray-100"
        >
          Cancel
        </button>
        <button 
          onClick={() => handleGrade('started')} 
          disabled={isSubmitting} 
          className="rounded-md bg-yellow-100 px-3 py-1.5 text-sm font-medium text-yellow-800 hover:bg-yellow-200"
        >
          Request Changes
        </button>
        <button 
          onClick={() => handleGrade('completed')} 
          disabled={isSubmitting} 
          className="rounded-md bg-green-600 px-3 py-1.5 text-sm font-medium text-white hover:bg-green-700"
        >
          Approve & Complete
        </button>
      </div>
    </div>
  );
}