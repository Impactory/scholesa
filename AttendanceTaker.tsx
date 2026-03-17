'use client';

import React, { useState } from 'react';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { useCollection, useDocument } from 'react-firebase-hooks/firestore';
import { query, where, doc, setDoc, Timestamp, getDoc } from 'firebase/firestore';
import { sessionOccurrencesCollection, enrolmentsCollection, attendanceCollection, usersCollection, sessionsCollection } from '@/src/firebase/firestore/collections';
import { Attendance, Enrolment } from '@/src/types/schema';

export function AttendanceTaker() {
  const { user } = useAuthContext();
  const [selectedOccurrenceId, setSelectedOccurrenceId] = useState<string>('');
  const [programIdForEnrolment, setProgramIdForEnrolment] = useState<string>('');
  const [selectedSiteId, setSelectedSiteId] = useState<string>('');
  const [attendanceError, setAttendanceError] = useState<string>('');

  // 1. Fetch Occurrences for this educator
  const [occurrencesSnap] = useCollection(
    user ? query(sessionOccurrencesCollection, where('educatorId', '==', user.uid)) : null
  );

  // 2. Fetch Enrollments for selected occurrence parent session program
  const [enrolmentsSnap] = useCollection(
    programIdForEnrolment 
      ? query(enrolmentsCollection, where('programId', '==', programIdForEnrolment))
      : null
  );

  const handleOccurrenceSelect = async (occId: string) => {
    setSelectedOccurrenceId(occId);

    try {
      const occurrenceDoc = occurrencesSnap?.docs.find((entry) => entry.id === occId);
      const occurrence = occurrenceDoc?.data();
      if (!occurrence?.sessionId) {
        setProgramIdForEnrolment('');
        setSelectedSiteId(occurrence?.siteId || '');
        return;
      }

      const sessionSnap = await getDoc(doc(sessionsCollection, occurrence.sessionId));
      if (!sessionSnap.exists()) {
        setProgramIdForEnrolment('');
        setSelectedSiteId(occurrence?.siteId || '');
        return;
      }

      const sessionData = sessionSnap.data();
      setProgramIdForEnrolment(sessionData.programId || '');
      setSelectedSiteId(occurrence?.siteId || sessionData.siteId || '');
    } catch (err) {
      console.error('Failed to resolve occurrence session context', err);
      setProgramIdForEnrolment('');
      setSelectedSiteId('');
    }
  };

  const markAttendance = async (learnerId: string, status: 'present' | 'absent' | 'late') => {
    if (!user || !selectedOccurrenceId) return;
    if (!selectedSiteId) {
      setAttendanceError('Attendance is unavailable until the selected class has a site assignment.');
      return;
    }

    const attendanceId = `${selectedOccurrenceId}_${learnerId}`;
    const record: Attendance = {
      id: attendanceId,
      userId: learnerId,
      learnerId: learnerId,
      sessionOccurrenceId: selectedOccurrenceId,
      studioId: selectedSiteId,
      date: Timestamp.now(),
      status,
      recordedBy: user.uid,
    };

    try {
      setAttendanceError('');
      await setDoc(doc(attendanceCollection, attendanceId), record);
    } catch (err) {
      console.error('Error marking attendance:', err);
      setAttendanceError('Failed to record attendance.');
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
                onClick={() => {
                  void handleOccurrenceSelect(doc.id);
                }}
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
        {attendanceError ? (
          <p className="mb-4 rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
            {attendanceError}
          </p>
        ) : null}
        {selectedOccurrenceId && !selectedSiteId ? (
          <p className="mb-4 rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-900">
            Attendance is disabled because this class does not have a site assignment.
          </p>
        ) : null}
        
        {!selectedOccurrenceId ? (
          <div className="flex h-32 items-center justify-center text-gray-400">
            Select a class to take attendance
          </div>
        ) : (
          <div className="space-y-2">
            {enrolmentsSnap?.docs.map((doc) => {
              const enrol = doc.data();
              return <LearnerRow key={doc.id} enrolment={enrol} onMark={markAttendance} disabled={!selectedSiteId} />;
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
  onMark,
  disabled,
}: { 
  enrolment: Enrolment; 
  onMark: (id: string, status: 'present' | 'absent' | 'late') => void;
  disabled: boolean;
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
            disabled={disabled}
            className={`rounded px-3 py-1 text-xs font-medium capitalize ring-1 ring-inset ${
              status === 'present' ? 'bg-green-50 text-green-700 ring-green-600/20 hover:bg-green-100' :
              status === 'late' ? 'bg-yellow-50 text-yellow-700 ring-yellow-600/20 hover:bg-yellow-100' :
              'bg-red-50 text-red-700 ring-red-600/20 hover:bg-red-100'
            } disabled:cursor-not-allowed disabled:opacity-50`}
          >
            {status}
          </button>
        ))}
      </div>
    </div>
  );
}