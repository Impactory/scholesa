'use client';

import React, { useState } from 'react';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { useCollection } from 'react-firebase-hooks/firestore';
import { query, where, Timestamp } from 'firebase/firestore';
import { sessionsCollection } from '@/src/firebase/firestore/collections';
import { createSessionWithOccurrences } from '@/scheduler';
import { Session } from '@/src/types/schema';

export function SessionManager() {
  const { user, profile } = useAuthContext();
  const [isCreating, setIsCreating] = useState(false);

  // Fetch sessions for this educator
  const [sessionsSnap, loading, error] = useCollection(
    user ? query(sessionsCollection, where('educatorId', '==', user.uid)) : null
  );

  const handleCreate = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    if (!user || !profile) return;

    const formData = new FormData(e.currentTarget);
    const programId = formData.get('programId') as string;
    const siteId = profile.studioId || 'default-site'; // Fallback or select from UI
    
    // Parse date/time (simplified for demo)
    const startStr = formData.get('startTime') as string;
    const startTime = Timestamp.fromDate(new Date(startStr));
    const endTime = Timestamp.fromDate(new Date(new Date(startStr).getTime() + 60 * 60 * 1000)); // +1 hour

    const newSession: Omit<Session, 'id'> = {
      siteId,
      programId,
      educatorId: user.uid,
      roomId: 'room-1', // Hardcoded for MVP
      startTime,
      endTime,
      dayOfWeek: new Date(startStr).getDay(),
    };

    setIsCreating(true);
    try {
      await createSessionWithOccurrences(newSession);
      (e.target as HTMLFormElement).reset();
    } catch (err) {
      console.error(err);
      alert('Failed to create session');
    } finally {
      setIsCreating(false);
    }
  };

  if (loading) return <div>Loading sessions...</div>;
  if (error) return <div>Error loading sessions.</div>;

  return (
    <div className="space-y-8">
      {/* Create Session Form */}
      <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
        <h2 className="mb-4 text-lg font-semibold">Schedule New Session</h2>
        <form onSubmit={handleCreate} className="flex flex-col gap-4 md:flex-row md:items-end">
          <div className="flex-1">
            <label className="block text-sm font-medium text-gray-700">Program ID</label>
            <input 
              name="programId" 
              required 
              placeholder="e.g. prog_math_101"
              className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            />
          </div>
          <div className="flex-1">
            <label className="block text-sm font-medium text-gray-700">Start Time</label>
            <input 
              type="datetime-local" 
              name="startTime" 
              required 
              className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            />
          </div>
          <button
            type="submit"
            disabled={isCreating}
            className="rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700 disabled:opacity-50"
          >
            {isCreating ? 'Scheduling...' : 'Create Session'}
          </button>
        </form>
      </div>

      {/* Session List */}
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {sessionsSnap?.docs.map((doc) => {
          const s = doc.data();
          return (
            <div key={doc.id} className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
              <h3 className="font-medium text-gray-900">Program: {s.programId}</h3>
              <p className="text-sm text-gray-500">
                {s.startTime.toDate().toLocaleDateString()} at {s.startTime.toDate().toLocaleTimeString()}
              </p>
              <p className="text-xs text-gray-400 mt-2">ID: {doc.id}</p>
            </div>
          );
        })}
      </div>
    </div>
  );
}