'use client';

import { useEffect, useState } from 'react';
import { query, where, getDocs } from 'firebase/firestore';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { usersCollection } from '@/src/lib/firestore/collections';
import type { User } from '@/schema';
import Link from 'next/link';

export default function ParentDashboard() {
  const { user, profile, loading: authLoading } = useAuthContext();
  const [learners, setLearners] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchChildren() {
      if (!user) return;

      try {
        // Fetch learners linked to this parent
        const qLearners = query(
          usersCollection,
          where('role', '==', 'learner'),
          where('parentIds', 'array-contains', user.uid)
        );
        
        const learnersSnap = await getDocs(qLearners);
        setLearners(learnersSnap.docs.map(doc => doc.data()));
      } catch (error) {
        console.error('Error fetching children:', error);
      } finally {
        setLoading(false);
      }
    }

    if (!authLoading) {
      fetchChildren();
    }
  }, [user, authLoading]);

  if (authLoading || loading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <div className="text-lg text-gray-600">Loading parent dashboard...</div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 p-4 sm:p-8">
      <div className="mx-auto max-w-7xl">
        <header className="mb-8 border-b border-gray-200 pb-4">
          <h1 className="text-3xl font-bold tracking-tight text-gray-900">
            Welcome, {profile?.displayName || 'Parent'}
          </h1>
          <p className="mt-2 text-sm text-gray-500">
            Track your children's progress and upcoming activities.
          </p>
        </header>

        <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
          {/* Main Content */}
          <div className="lg:col-span-2 space-y-6">
            <section>
              <h2 className="text-lg font-medium leading-6 text-gray-900 mb-4">My Children</h2>
              {learners.length === 0 ? (
                <div className="flex flex-col items-center justify-center min-h-screen bg-gray-100 dark:bg-gray-900">
                  <h1 className="text-4xl font-bold text-gray-800 dark:text-gray-200">Welcome Parent</h1>
                  <p className="mt-4 text-lg text-gray-600">You don&apos;t have any learners associated with your account yet.</p>
                  <Link href="/learner-registration" className="mt-8 px-4 py-2 text-white bg-indigo-600 rounded-md hover:bg-indigo-700">
                    Register a Learner
                  </Link>
                </div>
              ) : (
                <div className="grid gap-4 sm:grid-cols-2">
                  {learners.map((learner) => (
                    <div key={learner.uid} className="overflow-hidden rounded-lg bg-white shadow hover:shadow-md transition-shadow">
                      <div className="p-5">
                        <div className="flex items-center space-x-4">
                          <div className="h-10 w-10 rounded-full bg-indigo-100 flex items-center justify-center text-indigo-600 font-bold">
                            {learner.displayName?.charAt(0) || 'L'}
                          </div>
                          <div>
                            <h3 className="text-lg font-medium text-gray-900">{learner.displayName}</h3>
                            <p className="text-sm text-gray-500">{learner.email}</p>
                          </div>
                        </div>
                      </div>
                      <div className="bg-gray-50 px-5 py-3">
                        <div className="text-sm">
                          <a href="#" className="font-medium text-indigo-700 hover:text-indigo-900">
                            View Progress
                          </a>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </section>
          </div>

          {/* Sidebar */}
          <div className="space-y-6">
            <div className="overflow-hidden rounded-lg bg-white shadow">
              <div className="p-5">
                <h3 className="text-base font-semibold leading-6 text-gray-900">Quick Actions</h3>
                <div className="mt-4 space-y-4">
                  <button className="w-full rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500">
                    Message Educator
                  </button>
                  <button className="w-full rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50">
                    View Schedule
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}