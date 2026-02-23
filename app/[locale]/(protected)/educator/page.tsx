'use client';

import { useEffect, useState } from 'react';
import { query, where, getDocs } from 'firebase/firestore';
import Link from 'next/link';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { useInteractionTracking } from '@/src/hooks/useTelemetry';
import { sessionsCollection } from '@/src/lib/firestore/collections';
import type { Session } from '@/schema';
import { useI18n } from '@/src/lib/i18n/useI18n';

export default function EducatorDashboard() {
  const { user, profile, loading: authLoading } = useAuthContext();
  const { locale, t } = useI18n();
  const trackInteraction = useInteractionTracking();
  const [sessions, setSessions] = useState<Session[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchEducatorData() {
      if (!user) return;

      try {
        // Fetch sessions where this user is an educator
        const qSessions = query(
          sessionsCollection,
          where('educatorIds', 'array-contains', user.uid)
        );
        const sessionsSnap = await getDocs(qSessions);
        setSessions(sessionsSnap.docs.map(doc => doc.data()));
      } catch (error) {
        console.error('Error fetching educator sessions:', error);
      } finally {
        setLoading(false);
      }
    }

    if (!authLoading) {
      fetchEducatorData();
    }
  }, [user, authLoading]);

  if (authLoading || loading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <div className="text-lg text-gray-600">{t('role.educator.loading')}</div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 p-4 sm:p-8">
      <div className="mx-auto max-w-7xl">
        <header className="mb-8 border-b border-gray-200 pb-4">
          <h1 className="text-3xl font-bold tracking-tight text-gray-900">
            {t('role.educator.hello', { name: profile?.displayName || t('role.educator.defaultName') })}
          </h1>
          <p className="mt-2 text-sm text-gray-500">
            {t('role.educator.subtitle')}
          </p>
        </header>

        <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
          {/* Main Content */}
          <div className="lg:col-span-2 space-y-6">
            <section>
              <h2 className="text-lg font-medium leading-6 text-gray-900 mb-4">{t('role.educator.assignedSessions')}</h2>
              {sessions.length === 0 ? (
                <div className="overflow-hidden rounded-lg bg-white shadow p-6 text-center text-gray-500">
                  {t('role.educator.noSessions')}
                </div>
              ) : (
                <div className="grid gap-4 sm:grid-cols-2">
                  {sessions.map((session) => (
                    <div key={session.id} className="overflow-hidden rounded-lg bg-white shadow hover:shadow-md transition-shadow">
                      <div className="p-5">
                        <h3 className="text-lg font-medium text-gray-900">{session.title}</h3>
                        <p className="mt-1 text-sm text-gray-500 line-clamp-2">{session.description}</p>
                        <div className="mt-4 flex items-center justify-between">
                          <span className="inline-flex items-center rounded-full bg-indigo-50 px-2 py-1 text-xs font-medium text-indigo-700">
                            {session.pillarCodes?.[0] || t('common.general')}
                          </span>
                          <span className="text-xs text-gray-500">
                            {new Date(session.startDate).toLocaleDateString()}
                          </span>
                        </div>
                      </div>
                      <div className="bg-gray-50 px-5 py-3">
                        <div className="text-sm">
                          <Link
                            href={`/${locale}/educator`}
                            className="font-medium text-indigo-700 hover:text-indigo-900"
                            onClick={() => trackInteraction('feature_discovered', { cta: 'educator_view_details', sessionId: session.id })}
                          >
                            {t('role.educator.viewDetails')}
                          </Link>
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
                <h3 className="text-base font-semibold leading-6 text-gray-900">{t('role.educator.quickActions')}</h3>
                <div className="mt-4 space-y-4">
                  <Link
                    href={`/${locale}/educator`}
                    className="block w-full rounded-md bg-indigo-600 px-3 py-2 text-center text-sm font-semibold text-white shadow-sm hover:bg-indigo-500"
                    onClick={() => trackInteraction('feature_discovered', { cta: 'educator_take_attendance' })}
                  >
                    {t('role.educator.takeAttendance')}
                  </Link>
                  <Link
                    href={`/${locale}/educator`}
                    className="block w-full rounded-md bg-white px-3 py-2 text-center text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
                    onClick={() => trackInteraction('feature_discovered', { cta: 'educator_create_mission' })}
                  >
                    {t('role.educator.createMission')}
                  </Link>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
