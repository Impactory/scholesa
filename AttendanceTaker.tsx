'use client';

import React, { useState } from 'react';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { useCollection, useDocument } from 'react-firebase-hooks/firestore';
import { query, where, doc, setDoc, Timestamp } from 'firebase/firestore';
import { sessionOccurrencesCollection, enrolmentsCollection, attendanceCollection, usersCollection } from '@/src/firebase/firestore/collections';
import { Attendance, Enrolment } from '@/src/types/schema';

export function AttendanceTaker() {
  const { user } = useAuthContext();
  const [selectedOccurrenceId, setSelectedOccurrenceId] = useState<string>('');
  const [programIdForEnrolment, setProgramIdForEnrolment] = useState<string>('');

  // 1. Fetch Occurrences for this educator
  const [occurrencesSnap] = useCollection(
    user ? query(sessionOccurrencesCollection, where('educatorId', '==', user.uid)) : null
  );

  // 2. Fetch Enrollments when an occurrence is selected
  // Note: In a real app, we'd fetch the Session first to get the programId. 
  // For this MVP, we assume we passed programId or fetch it. 
  // To keep it simple, let's assume we just query enrollments for the site or we'd need to join data.
  // IMPROVEMENT: Store programId on SessionOccurrence to avoid double-fetch.
  // For now, let's just list occurrences and placeholder logic for enrollments.
  
  // Mocking enrollment fetch based on a hypothetical program ID from the selected occurrence context
  // In production, you would fetch the parent Session of the Occurrence to get the programId.
  const [enrolmentsSnap] = useCollection(
    programIdForEnrolment 
      ? query(enrolmentsCollection, where('programId', '==', programIdForEnrolment))
      : null
  );

  const handleOccurrenceSelect = (occId: string, /* progId: string */) => {
    setSelectedOccurrenceId(occId);
    // In a real implementation, we'd look up the session's programId here.
    // For demo purposes, we'll set a dummy or require the user to pick.
    setProgramIdForEnrolment('prog_math_101'); // Hardcoded for MVP flow
  };

  const markAttendance = async (learnerId: string, status: 'present' | 'absent' | 'late') => {
    if (!user || !selectedOccurrenceId) return;

    const attendanceId = `${selectedOccurrenceId}_${learnerId}`;
    const record: Attendance = {
      id: attendanceId,
      userId: learnerId,
      learnerId: learnerId,
      sessionOccurrenceId: selectedOccurrenceId,
      studioId: 'default-site', // Should come from context
      date: Timestamp.now(),
      status,
      recordedBy: user.uid,
    };

    try {
      await setDoc(doc(attendanceCollection, attendanceId), record);
    } catch (err) {
      console.error('Error marking attendance:', err);
    }
  };

  return (
    <div className="grid gap-6 md:grid-cols-3">
      {/* Left Col: List Occurrences */}
      <div className="col-span-1 space-y-2 rounded-lg border border-gray-200 bg-white p-4">
        <h3 className="font-semibold text-gray-900">Your Classes</h3>
        <div className="flex flex-col gap-2">
          {occurrencesSnap?.docs.map((doc) => {
            const occ = doc.data();
            const isSelected = doc.id === selectedOccurrenceId;
            return (
              <button
                key={doc.id}
                onClick={() => handleOccurrenceSelect(doc.id)}
                className={`rounded px-3 py-2 text-left text-sm transition-colors ${
                  isSelected ? 'bg-indigo-50 text-indigo-700' : 'hover:bg-gray-50'
                }`}
              >
                {occ.date.toDate().toLocaleDateString()}
              </button>
            );
          })}
          {occurrencesSnap?.empty && <p className="text-sm text-gray-500">No classes found.</p>}
        </div>
      </div>

      {/* Right Col: Student List */}
      <div className="col-span-2 rounded-lg border border-gray-200 bg-white p-4">
        <h3 className="mb-4 font-semibold text-gray-900">
          Attendance {selectedOccurrenceId ? '' : '(Select a class)'}
        </h3>
        
        {!selectedOccurrenceId ? (
          <div className="flex h-32 items-center justify-center text-gray-400">
            Select a class to take attendance
          </div>
        ) : (
          <div className="space-y-2">
            {enrolmentsSnap?.docs.map((doc) => {
              const enrol = doc.data();
              return <LearnerRow key={doc.id} enrolment={enrol} onMark={markAttendance} />;
            })}
            {enrolmentsSnap?.empty && <p className="text-sm text-gray-500">No students enrolled in this program.</p>}
          </div>
        )}
      </div>
    </div>
  );
}

function LearnerRow({ 
  enrolment, 
  onMark 
}: { 
  enrolment: Enrolment; 
  onMark: (id: string, status: 'present' | 'absent' | 'late') => void 
}) {
  const [userSnap, loading] = useDocument(doc(usersCollection, enrolment.userId));
  const profile = userSnap?.data();
  const displayName = loading ? 'Loading...' : (profile?.displayName || 'Unknown Learner');

  return (
    <div className="flex items-center justify-between rounded-md border border-gray-100 p-3 hover:bg-gray-50">
      <div className="flex items-center gap-3">
        <div className="h-8 w-8 rounded-full bg-indigo-100 flex items-center justify-center text-indigo-700 text-xs font-bold">
          {displayName.slice(0, 2).toUpperCase()}
        </div>
        <div>
          <p className="text-sm font-medium text-gray-900">{displayName}</p>
          <p className="text-xs text-gray-500">Status: {enrolment.status}</p>
        </div>
      </div>
      <div className="flex gap-2">
        {(['present', 'late', 'absent'] as const).map((status) => (
          <button
            key={status}
            onClick={() => onMark(enrolment.userId, status)}
            className={`rounded px-3 py-1 text-xs font-medium capitalize ring-1 ring-inset ${
              status === 'present' ? 'bg-green-50 text-green-700 ring-green-600/20 hover:bg-green-100' :
              status === 'late' ? 'bg-yellow-50 text-yellow-700 ring-yellow-600/20 hover:bg-yellow-100' :
              'bg-red-50 text-red-700 ring-red-600/20 hover:bg-red-100'
            }`}
          >
            {status}
          </button>
        ))}
      </div>
    </div>
  );
}