'use client';

import React from 'react';
import { SessionManager } from '@/src/features/educator/components/SessionManager';
import { AttendanceTaker } from '@/src/features/educator/components/AttendanceTaker';
import { SubmissionGrader } from '@/src/features/educator/components/SubmissionGrader';

export default function EducatorDashboard() {
  return (
    <div className="container mx-auto max-w-6xl p-6 space-y-10">
      <header>
        <h1 className="text-3xl font-bold text-gray-900">Educator Dashboard</h1>
        <p className="text-gray-500 mt-1">Manage your sessions and track learner attendance.</p>
      </header>
      
      <section className="space-y-4">
        <SessionManager />
      </section>

      <section className="space-y-4 pt-6 border-t border-gray-200">
        <AttendanceTaker />
      </section>

      <section className="space-y-4 pt-6 border-t border-gray-200">
        <h2 className="text-xl font-semibold text-gray-900">Mission Submissions</h2>
        <SubmissionGrader />
      </section>
    </div>
  );
}