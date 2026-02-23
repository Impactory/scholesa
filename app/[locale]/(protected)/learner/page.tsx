'use client';

import { useEffect, useState } from 'react';
import { query, where, getDocs, documentId } from 'firebase/firestore';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { enrollmentsCollection, sessionsCollection } from '@/src/lib/firestore/collections';
import type { Session } from '@/schema';
import { useI18n } from '@/src/lib/i18n/useI18n';

export default function LearnerDashboard() {
  const { user, profile, loading: authLoading } = useAuthContext();
  const { t } = useI18n();
  const [sessions, setSessions] = useState<Session[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchLearnerData() {
      if (!user) return;

      try {
        // 1. Fetch Enrollments for this learner
        const qEnrollments = query(
          enrollmentsCollection, 
          where('learnerId', '==', user.uid),
          where('status', '==', 'active')
        );
        const enrollmentsSnap = await getDocs(qEnrollments);
        
        if (enrollmentsSnap.empty) {
          setLoading(false);
          return;
        }

        // 2. Extract Session IDs
        const sessionIds = enrollmentsSnap.docs.map(doc => doc.data().sessionId);
        
        // 3. Fetch Session Details
        // Note: Firestore 'in' query is limited to 10 items. 
        // For a real app, you'd chunk this or fetch individually if > 10.
        if (sessionIds.length > 0) {
          const safeSessionIds = sessionIds.slice(0, 10);
          const qSessions = query(
            sessionsCollection, 
            where(documentId(), 'in', safeSessionIds)
          );
          const sessionsSnap = await getDocs(qSessions);
          setSessions(sessionsSnap.docs.map(doc => doc.data()));
        }
      } catch (error) {
        console.error('Error fetching learner data:', error);
      } finally {
        setLoading(false);
      }
    }

    if (!authLoading) {
      fetchLearnerData();
    }
  }, [user, authLoading]);

  if (authLoading || loading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <div className="text-lg text-gray-600">{t('role.learner.loading')}</div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 p-4 sm:p-8">
      <div className="mx-auto max-w-7xl">
        <header className="mb-8 border-b border-gray-200 pb-4">
          <h1 className="text-3xl font-bold tracking-tight text-gray-900">
            {t('role.learner.welcome', { name: profile?.displayName || t('role.learner.defaultName') })}
          </h1>
          <p className="mt-2 text-sm text-gray-500">
            {t('role.learner.subtitle')}
          </p>
        </header>

        <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
          {/* Main Content Area */}
          <div className="lg:col-span-2 space-y-6">
            <section>
              <h2 className="text-lg font-medium leading-6 text-gray-900 mb-4">{t('role.learner.activeSessions')}</h2>
              {sessions.length === 0 ? (
                <div className="overflow-hidden rounded-lg bg-white shadow p-6 text-center text-gray-500">
                  {t('role.learner.noSessions')}
                </div>
              ) : (
                <div className="grid gap-4 sm:grid-cols-2">
                  {sessions.map((session) => (
                    <div key={session.id} className="overflow-hidden rounded-lg bg-white shadow hover:shadow-md transition-shadow">
                      <div className="p-5">
                        <h3 className="text-lg font-medium text-gray-900">{session.title}</h3>
                        <p className="mt-1 text-sm text-gray-500 line-clamp-2">{session.description}</p>
                        <div className="mt-4 flex items-center text-xs text-gray-400">
                          <span className="bg-indigo-50 text-indigo-700 px-2 py-1 rounded-full font-medium">
                            {session.pillarCodes?.[0] || t('common.general')}
                          </span>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </section>

            <section>
              <h2 className="text-lg font-medium leading-6 text-gray-900 mb-4">{t('role.learner.recentMissions')}</h2>
              <div className="overflow-hidden rounded-lg bg-white shadow">
                <div className="p-6 text-center text-gray-500">
                  {t('role.learner.noRecentMissions')}
                </div>
              </div>
            </section>
          </div>

          {/* Sidebar */}
          <div className="space-y-6">
            <div className="overflow-hidden rounded-lg bg-white shadow">
              <div className="p-5">
                <h3 className="text-base font-semibold leading-6 text-gray-900">{t('role.learner.myStats')}</h3>
                <div className="mt-4 border-t border-gray-100 pt-4">
                  <dl className="divide-y divide-gray-100">
                    <div className="flex justify-between py-2 text-sm">
                      <dt className="text-gray-500">{t('role.learner.sessionsAttended')}</dt>
                      <dd className="font-medium text-gray-900">0</dd>
                    </div>
                    <div className="flex justify-between py-2 text-sm">
                      <dt className="text-gray-500">{t('role.learner.skillsMastered')}</dt>
                      <dd className="font-medium text-gray-900">0</dd>
                    </div>
                  </dl>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
