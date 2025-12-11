import Link from 'next/link';
import { Button } from '@/src/components/ui/Button';
import { getTranslations } from '@/lib/i18n';
import { Globe, Zap, Users, School, Briefcase, Building } from 'lucide-react';

export default async function Home({ params }: { params: { locale: string } }) {
  const { t } = await getTranslations(params.locale, 'landing');

  const pillars = [
    { name: t('pillars.future_skills'), icon: <Zap className="h-8 w-8 text-white" /> },
    { name: t('pillars.leadership_agency'), icon: <Users className="h-8 w-8 text-white" /> },
    { name: t('pillars.impact_innovation'), icon: <Globe className="h-8 w-8 text-white" /> },
  ];

  const stakeholders = [
    { name: t('stakeholders.learners'), icon: <Users className="h-10 w-10 mx-auto mb-4 text-indigo-500" /> },
    { name: t('stakeholders.educators'), icon: <School className="h-10 w-10 mx-auto mb-4 text-indigo-500" /> },
    { name: t('stakeholders.parents'), icon: <Users className="h-10 w-10 mx-auto mb-4 text-indigo-500" /> },
    { name: t('stakeholders.site_leads'), icon: <Briefcase className="h-10 w-10 mx-auto mb-4 text-indigo-500" /> },
    { name: t('stakeholders.partners'), icon: <Building className="h-10 w-10 mx-auto mb-4 text-indigo-500" /> },
    { name: t('stakeholders.hq'), icon: <Globe className="h-10 w-10 mx-auto mb-4 text-indigo-500" /> },
  ];

  return (
    <div className="bg-white dark:bg-gray-900 text-gray-800 dark:text-gray-200">
      {/* Hero Section */}
      <main className="relative isolate px-6 pt-14 lg:px-8">
        <div className="mx-auto max-w-3xl py-32 sm:py-48 lg:py-56">
          <div className="text-center">
            <h1 className="text-4xl font-bold tracking-tight sm:text-6xl">
              {t('title')}
            </h1>
            <p className="mt-6 text-lg leading-8 text-gray-600 dark:text-gray-300">
              {t('subtitle')}
            </p>
            <div className="mt-10 flex items-center justify-center gap-x-6">
              <Link href={`/${params.locale}/login`}>
                <Button>{t('login')}</Button>
              </Link>
              <Link href={`/${params.locale}/register`} className="text-sm font-semibold leading-6">
                {t('register')} <span aria-hidden="true">→</span>
              </Link>
            </div>
          </div>
        </div>
      </main>

      {/* 3 Pillars Section */}
      <section className="bg-indigo-600 dark:bg-indigo-800 py-24 sm:py-32">
        <div className="mx-auto max-w-7xl px-6 lg:px-8">
          <div className="mx-auto max-w-2xl lg:text-center">
            <h2 className="text-base font-semibold leading-7 text-indigo-200">{t('pillars.title')}</h2>
            <p className="mt-2 text-3xl font-bold tracking-tight text-white sm:text-4xl">
              A new model for education
            </p>
          </div>
          <div className="mx-auto mt-16 max-w-2xl sm:mt-20 lg:mt-24 lg:max-w-none">
            <dl className="grid max-w-xl grid-cols-1 gap-x-8 gap-y-16 lg:max-w-none lg:grid-cols-3">
              {pillars.map((pillar) => (
                <div key={pillar.name} className="flex flex-col items-center text-center">
                  <dt className="flex items-center justify-center h-16 w-16 rounded-lg bg-indigo-500 dark:bg-indigo-700">
                    {pillar.icon}
                  </dt>
                  <dd className="mt-4 text-xl font-semibold leading-7 text-white">
                    {pillar.name}
                  </dd>
                </div>
              ))}
            </dl>
          </div>
        </div>
      </section>

      {/* Stakeholders Section */}
      <section className="py-24 sm:py-32">
        <div className="mx-auto max-w-7xl px-6 lg:px-8">
          <div className="mx-auto max-w-2xl lg:text-center">
            <h2 className="text-base font-semibold leading-7 text-indigo-600 dark:text-indigo-400">{t('stakeholders.title')}</h2>
            <p className="mt-2 text-3xl font-bold tracking-tight sm:text-4xl">
              Built for everyone
            </p>
          </div>
          <div className="mx-auto mt-16 grid max-w-2xl grid-cols-2 gap-8 sm:grid-cols-3 lg:mx-0 lg:max-w-none lg:grid-cols-6">
            {stakeholders.map((stakeholder) => (
              <div key={stakeholder.name} className="rounded-lg bg-gray-100 dark:bg-gray-800 p-6 text-center shadow-lg">
                {stakeholder.icon}
                <h3 className="text-lg font-semibold">{stakeholder.name}</h3>
              </div>
            ))}
          </div>
        </div>
      </section>
    </div>
  );
}
