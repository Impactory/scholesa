'use client';

import React, { useState } from 'react';
import { addDoc, Timestamp } from 'firebase/firestore';
import { reflectionsCollection } from '@/src/firebase/firestore/collections';
import { Reflection } from '@/src/types/schema';

interface Props {
  userId: string;
  missionId: string;
  onSuccess: () => void;
  onCancel: () => void;
}

export function ReflectionForm({ userId, missionId, onSuccess, onCancel }: Props) {
  const [content, setContent] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!content.trim()) return;

    setIsSubmitting(true);
    try {
      const reflection: Omit<Reflection, 'id'> = {
        userId,
        missionId,
        content,
        createdAt: Timestamp.now(),
      };
      // Cast to any to bypass strict ID requirement on creation
      await addDoc(reflectionsCollection, reflection as any);
      onSuccess();
    } catch (error) {
      console.error("Error saving reflection:", error);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="mt-4 rounded-md border border-gray-200 bg-white p-4 shadow-sm">
      <label className="block text-sm font-medium text-gray-700 mb-2">
        Reflection: What did you learn from this mission?
      </label>
      <textarea
        className="w-full rounded-md border border-gray-300 p-2 text-sm focus:border-indigo-500 focus:ring-indigo-500"
        rows={4}
        value={content}
        onChange={(e) => setContent(e.target.value)}
        placeholder="Share your thoughts..."
        required
      />
      <div className="mt-3 flex justify-end gap-2">
        <button type="button" onClick={onCancel} disabled={isSubmitting} className="rounded-md px-3 py-1.5 text-sm font-medium text-gray-700 hover:bg-gray-50">
          Cancel
        </button>
        <button type="submit" disabled={isSubmitting} className="rounded-md bg-indigo-600 px-3 py-1.5 text-sm font-medium text-white hover:bg-indigo-700 disabled:opacity-50">
          {isSubmitting ? 'Saving...' : 'Submit Reflection'}
        </button>
      </div>
    </form>
  );
}