import type { Metadata } from 'next';
import Image from 'next/image';
import Link from 'next/link';
import { getTranslations } from '@/lib/i18n';
import {
  ArrowRight,
  CalendarDays,
  CheckCircle2,
  Hammer,
  Lightbulb,
  Mail,
  Map,
  Megaphone,
  Phone,
  Search,
  ShieldCheck,
  Sprout,
  Users,
} from 'lucide-react';

export const metadata: Metadata = {
  title: 'Young Innovators Summer Camp 2026 | Scholesa',
  description:
    'Scholesa Young Innovators Summer Camp 2026 for grades 1-6: hands-on invention, future city building, portfolio artifacts, and family showcases.',
};

const stats = [
  { value: '10', key: 'stats.sessions' },
  { value: '2', key: 'stats.weeks' },
  { value: '5', key: 'stats.capabilityStrands' },
  { value: '5+', key: 'stats.portfolioArtifacts' },
  { value: '1', key: 'stats.familyShowcase' },
];

const capabilities = [
  {
    labelKey: 'capabilities.think.label',
    detailKey: 'capabilities.think.detail',
    icon: Search,
    tone: 'border-cyan-200 bg-cyan-50 text-cyan-800 dark:border-cyan-800 dark:bg-cyan-950/30 dark:text-cyan-100',
  },
  {
    labelKey: 'capabilities.make.label',
    detailKey: 'capabilities.make.detail',
    icon: Hammer,
    tone: 'border-emerald-200 bg-emerald-50 text-emerald-800 dark:border-emerald-800 dark:bg-emerald-950/30 dark:text-emerald-100',
  },
  {
    labelKey: 'capabilities.communicate.label',
    detailKey: 'capabilities.communicate.detail',
    icon: Megaphone,
    tone: 'border-blue-200 bg-blue-50 text-blue-800 dark:border-blue-800 dark:bg-blue-950/30 dark:text-blue-100',
  },
  {
    labelKey: 'capabilities.lead.label',
    detailKey: 'capabilities.lead.detail',
    icon: Users,
    tone: 'border-rose-200 bg-rose-50 text-rose-800 dark:border-rose-800 dark:bg-rose-950/30 dark:text-rose-100',
  },
  {
    labelKey: 'capabilities.world.label',
    detailKey: 'capabilities.world.detail',
    icon: Sprout,
    tone: 'border-amber-200 bg-amber-50 text-amber-900 dark:border-amber-800 dark:bg-amber-950/30 dark:text-amber-100',
  },
];

const weeks = [
  {
    labelKey: 'weeks.week1.label',
    titleKey: 'weeks.week1.title',
    dateKey: 'weeks.week1.date',
    descriptionKey: 'weeks.week1.description',
    tone: 'border-emerald-200 bg-emerald-50 dark:border-emerald-800 dark:bg-emerald-950/20',
    headerTone: 'bg-emerald-700 text-white dark:bg-emerald-800',
    sessions: [
      {
        dayKey: 'days.mon',
        nameKey: 'weeks.week1.sessions.problem.name',
        themeKey: 'weeks.week1.sessions.problem.theme',
        tagKeys: ['tags.think', 'tags.observe'],
      },
      {
        dayKey: 'days.tue',
        nameKey: 'weeks.week1.sessions.sketch.name',
        themeKey: 'weeks.week1.sessions.sketch.theme',
        tagKeys: ['tags.make', 'tags.think'],
      },
      {
        dayKey: 'days.wed',
        nameKey: 'weeks.week1.sessions.build.name',
        themeKey: 'weeks.week1.sessions.build.theme',
        tagKeys: ['tags.make', 'tags.lead'],
      },
      {
        dayKey: 'days.thu',
        nameKey: 'weeks.week1.sessions.improve.name',
        themeKey: 'weeks.week1.sessions.improve.theme',
        tagKeys: ['tags.make', 'tags.think', 'tags.communicate'],
      },
      {
        dayKey: 'days.fri',
        nameKey: 'weeks.week1.sessions.showcase.name',
        themeKey: 'weeks.week1.sessions.showcase.theme',
        tagKeys: ['tags.communicate', 'tags.lead'],
        showcase: true,
      },
    ],
  },
  {
    labelKey: 'weeks.week2.label',
    titleKey: 'weeks.week2.title',
    dateKey: 'weeks.week2.date',
    descriptionKey: 'weeks.week2.description',
    tone: 'border-indigo-200 bg-indigo-50 dark:border-indigo-800 dark:bg-indigo-950/20',
    headerTone: 'bg-indigo-700 text-white dark:bg-indigo-800',
    sessions: [
      {
        dayKey: 'days.mon',
        nameKey: 'weeks.week2.sessions.need.name',
        themeKey: 'weeks.week2.sessions.need.theme',
        tagKeys: ['tags.think', 'tags.buildForWorld'],
      },
      {
        dayKey: 'days.tue',
        nameKey: 'weeks.week2.sessions.system.name',
        themeKey: 'weeks.week2.sessions.system.theme',
        tagKeys: ['tags.make', 'tags.buildForWorld'],
      },
      {
        dayKey: 'days.wed',
        nameKey: 'weeks.week2.sessions.city.name',
        themeKey: 'weeks.week2.sessions.city.theme',
        tagKeys: ['tags.make', 'tags.lead', 'tags.communicate'],
      },
      {
        dayKey: 'days.thu',
        nameKey: 'weeks.week2.sessions.pitch.name',
        themeKey: 'weeks.week2.sessions.pitch.theme',
        tagKeys: ['tags.communicate', 'tags.lead'],
      },
      {
        dayKey: 'days.fri',
        nameKey: 'weeks.week2.sessions.showcase.name',
        themeKey: 'weeks.week2.sessions.showcase.theme',
        tagKeys: ['tags.communicate', 'tags.buildForWorld'],
        showcase: true,
      },
    ],
  },
];

const differentiators = [
  {
    titleKey: 'differentiators.handsOn.title',
    detailKey: 'differentiators.handsOn.detail',
    icon: Hammer,
  },
  {
    titleKey: 'differentiators.screenTime.title',
    detailKey: 'differentiators.screenTime.detail',
    icon: ShieldCheck,
  },
  {
    titleKey: 'differentiators.portfolio.title',
    detailKey: 'differentiators.portfolio.detail',
    icon: CheckCircle2,
  },
  {
    titleKey: 'differentiators.impact.title',
    detailKey: 'differentiators.impact.detail',
    icon: Lightbulb,
  },
];

export default async function SummerCampPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  const { t } = await getTranslations(locale, 'summerCamp');
  const tx = (key: string): string => t(key) ?? key;

  return (
    <div className="public-site min-h-screen">
      <header className="public-header border-b">
        <div className="mx-auto flex max-w-7xl items-center justify-between gap-4 px-4 py-3 sm:px-6 lg:px-8">
          <Link
            href={`/${locale}`}
            className="flex min-w-0 items-center gap-3 rounded-md focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-app-ring"
            aria-label={tx('homeAria')}
          >
            <Image
              src="/logo/scholesa-logo-192.png"
              alt=""
              aria-hidden="true"
              width={44}
              height={44}
              priority
              className="h-11 w-11 shrink-0"
            />
            <div className="min-w-0">
              <p className="text-lg font-bold leading-5 text-slate-950 dark:text-white">Scholesa</p>
              <p className="text-xs font-medium uppercase tracking-[0.18em] text-slate-500 dark:text-slate-400">{tx('brandSubtitle')}</p>
            </div>
          </Link>
          <nav className="flex items-center gap-2" aria-label={tx('navAria')}>
            <Link
              href={`/${locale}/privacy`}
              className="hidden min-touch-target items-center rounded-md px-3 py-2 text-sm font-semibold text-app-muted hover:text-app-foreground focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-app-ring sm:inline-flex"
            >
              {tx('privacy')}
            </Link>
            <a
              href="mailto:info@scholesa.com?subject=Scholesa%20Young%20Innovators%20Summer%20Camp%202026"
              className="public-button-primary min-touch-target inline-flex items-center justify-center gap-2 rounded-full px-4 py-2 text-sm font-bold transition focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-app-ring"
            >
              <Mail className="h-4 w-4" aria-hidden="true" />
              {tx('reserve')}
            </a>
          </nav>
        </div>
      </header>

      <main>
        <section className="public-hero border-b border-transparent">
          <div className="mx-auto grid max-w-7xl gap-8 px-4 py-10 sm:px-6 sm:py-14 lg:min-h-[calc(100vh-72px)] lg:grid-cols-[1fr_0.9fr] lg:items-center lg:px-8">
            <div>
              <div className="public-chip px-4 py-2">
                <CalendarDays className="h-4 w-4" aria-hidden="true" />
                {tx('eyebrow')}
              </div>
              <p className="public-kicker mt-5 text-teal-200">
                {tx('ages')}
              </p>
              <h1 className="public-display-title mt-4 max-w-4xl text-5xl leading-[0.95] text-white sm:text-6xl lg:text-7xl">
                {tx('heroTitleBefore')} <span className="italic text-amber-400">{tx('heroTitleHighlight')}</span> {tx('heroTitleAfter')}
              </h1>
              <p className="mt-5 max-w-2xl text-base leading-7 text-slate-300 sm:text-lg sm:leading-8">
                {tx('heroBody')}
              </p>
              <div className="mt-7 flex flex-col gap-3 sm:flex-row">
                <a
                  href="mailto:info@scholesa.com?subject=Scholesa%20Young%20Innovators%20Summer%20Camp%202026"
                  className="public-button-primary min-touch-target inline-flex items-center justify-center gap-2 rounded-full px-5 py-3 text-sm font-bold transition focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-app-ring"
                >
                  {tx('primaryCta')}
                  <ArrowRight className="h-4 w-4" aria-hidden="true" />
                </a>
                <a
                  href="tel:6047577797"
                  className="public-button-secondary min-touch-target inline-flex items-center justify-center gap-2 rounded-full px-5 py-3 text-sm font-semibold transition hover:bg-white/10 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-app-ring"
                >
                  <Phone className="h-4 w-4" aria-hidden="true" />
                  604-757-7797
                </a>
              </div>
            </div>

            <div className="grid gap-4" aria-label={tx('weeksAria')}>
              {weeks.map((week) => (
                <section key={week.titleKey} className="public-panel rounded-md p-5">
                  <p className="text-xs font-bold uppercase tracking-wide text-cyan-200">{tx(week.labelKey)}</p>
                  <h2 className="mt-2 text-2xl font-bold text-white">{tx(week.titleKey)}</h2>
                  <p className="mt-1 text-sm font-semibold text-amber-200">{tx(week.dateKey)}</p>
                  <p className="mt-3 text-sm leading-6 text-slate-300">{tx(week.descriptionKey)}</p>
                </section>
              ))}
            </div>
          </div>
        </section>

        <section className="public-stat-band border-b border-transparent px-4 py-6 sm:px-6 lg:px-8">
          <div className="mx-auto grid max-w-7xl gap-3 sm:grid-cols-5">
            {stats.map((stat) => (
              <div key={stat.key} className="rounded-md border border-white/15 bg-white/10 p-4 text-center shadow-sm shadow-black/10">
                <p className="text-3xl font-bold text-amber-200">{stat.value}</p>
                <p className="mt-1 text-xs font-bold uppercase tracking-wide text-cyan-50">{tx(stat.key)}</p>
              </div>
            ))}
          </div>
        </section>

        <section className="public-section-cream border-b border-app px-4 py-14 sm:px-6 lg:px-8">
          <div className="mx-auto max-w-7xl">
            <div className="max-w-3xl">
              <p className="public-kicker">{tx('capabilitiesKicker')}</p>
              <h2 className="public-display-title mt-3 text-4xl leading-tight text-slate-950 sm:text-5xl dark:text-white">
                {tx('capabilitiesTitle')}
              </h2>
              <p className="mt-4 text-base leading-7 text-slate-700 dark:text-slate-300">
                {tx('capabilitiesBody')}
              </p>
            </div>
            <div className="mt-8 grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
              {capabilities.map((capability) => {
                const Icon = capability.icon;
                return (
                  <article key={capability.labelKey} className={`rounded-md border p-4 shadow-sm ${capability.tone}`}>
                    <Icon className="h-6 w-6" aria-hidden="true" />
                    <h3 className="mt-4 text-base font-bold">{tx(capability.labelKey)}</h3>
                    <p className="mt-2 text-sm leading-6">{tx(capability.detailKey)}</p>
                  </article>
                );
              })}
            </div>
          </div>
        </section>

        <section className="public-section-dark border-b border-transparent px-4 py-14 sm:px-6 lg:px-8">
          <div className="mx-auto max-w-7xl">
            <div className="max-w-3xl">
              <p className="public-kicker text-teal-200">{tx('scheduleKicker')}</p>
              <h2 className="public-display-title mt-3 text-4xl leading-tight sm:text-5xl">
                {tx('scheduleTitle')}
              </h2>
              <p className="mt-4 text-base leading-7 text-slate-300">
                {tx('scheduleBody')}
              </p>
            </div>

            <div className="mt-8 grid gap-5 lg:grid-cols-2">
              {weeks.map((week) => (
                <section key={week.titleKey} className={`overflow-hidden rounded-md border ${week.tone}`}>
                  <div className={`p-5 ${week.headerTone}`}>
                    <p className="text-xs font-bold uppercase tracking-wide opacity-85">{tx(week.labelKey)}</p>
                    <h3 className="mt-2 text-2xl font-bold">{tx(week.titleKey)}</h3>
                    <p className="mt-1 text-sm opacity-85">{tx(week.dateKey)} · {tx('halfDaySessions')}</p>
                  </div>
                  <div className="divide-y divide-slate-200 bg-white dark:divide-slate-800 dark:bg-slate-950">
                    {week.sessions.map((session) => (
                      <div
                        key={`${week.titleKey}-${session.dayKey}`}
                        className={session.showcase ? 'grid grid-cols-[4.5rem_1fr] bg-amber-50 dark:bg-amber-950/20' : 'grid grid-cols-[4.5rem_1fr]'}
                      >
                        <div className="border-r border-slate-200 p-4 text-xs font-bold uppercase text-slate-500 dark:border-slate-800 dark:text-slate-400">
                          {tx(session.dayKey)}
                        </div>
                        <div className="p-4">
                          <h4 className="text-sm font-bold text-slate-950 dark:text-white">{tx(session.nameKey)}</h4>
                          <p className="mt-1 text-sm leading-6 text-slate-600 dark:text-slate-300">{tx(session.themeKey)}</p>
                          <div className="mt-3 flex flex-wrap gap-2">
                            {session.tagKeys.map((tagKey) => (
                              <span
                                key={tagKey}
                                className="rounded-md border border-slate-200 bg-slate-50 px-2 py-1 text-xs font-bold text-slate-700 dark:border-slate-700 dark:bg-slate-900 dark:text-slate-200"
                              >
                                {tx(tagKey)}
                              </span>
                            ))}
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                </section>
              ))}
            </div>
          </div>
        </section>

        <section className="public-section-offwhite border-b border-app px-4 py-14 sm:px-6 lg:px-8">
          <div className="mx-auto max-w-7xl">
            <div className="grid gap-8 lg:grid-cols-[0.8fr_1.2fr] lg:items-start">
              <div>
                <p className="public-kicker">{tx('differentiatorsKicker')}</p>
                <h2 className="public-display-title mt-3 text-4xl leading-tight text-slate-950 sm:text-5xl dark:text-white">
                  {tx('differentiatorsTitle')}
                </h2>
                <p className="mt-4 text-base leading-7 text-slate-700 dark:text-slate-300">
                  {tx('differentiatorsBody')}
                </p>
              </div>
              <div className="grid gap-3 sm:grid-cols-2">
                {differentiators.map((item) => {
                  const Icon = item.icon;
                  return (
                    <article key={item.titleKey} className="public-card rounded-md p-5">
                      <Icon className="h-6 w-6 text-cyan-700 dark:text-cyan-300" aria-hidden="true" />
                      <h3 className="mt-4 text-lg font-bold text-slate-950 dark:text-white">{tx(item.titleKey)}</h3>
                      <p className="mt-2 text-sm leading-6 text-slate-700 dark:text-slate-300">{tx(item.detailKey)}</p>
                    </article>
                  );
                })}
              </div>
            </div>
          </div>
        </section>

        <section className="public-section-cream px-4 py-12 sm:px-6 lg:px-8">
          <div className="mx-auto grid max-w-7xl gap-6 rounded-md border border-teal-200 bg-teal-50 p-5 shadow-sm lg:grid-cols-[1fr_auto] lg:items-center dark:border-teal-800 dark:bg-teal-950/30">
            <div className="flex gap-3">
              <Map className="mt-1 h-5 w-5 shrink-0 text-cyan-700 dark:text-cyan-300" aria-hidden="true" />
              <div>
                <p className="text-sm font-bold uppercase text-cyan-700 dark:text-cyan-300">{tx('limitedKicker')}</p>
                <h2 className="mt-2 text-2xl font-bold text-slate-950 dark:text-white">
                  {tx('limitedTitle')}
                </h2>
                <p className="mt-2 max-w-3xl text-sm leading-6 text-slate-700 dark:text-slate-300">
                  {tx('limitedBody')}
                </p>
              </div>
            </div>
            <div className="flex flex-col gap-3 sm:flex-row lg:flex-col">
              <a
                href="mailto:info@scholesa.com?subject=Scholesa%20Young%20Innovators%20Summer%20Camp%202026"
                className="min-touch-target inline-flex items-center justify-center gap-2 rounded-md bg-cyan-700 px-5 py-3 text-sm font-semibold text-white hover:bg-cyan-800 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-app-ring dark:bg-cyan-300 dark:text-slate-950 dark:hover:bg-cyan-200"
              >
                <Mail className="h-4 w-4" aria-hidden="true" />
                  {tx('email')}
              </a>
              <a
                href="tel:6047577797"
                className="min-touch-target inline-flex items-center justify-center gap-2 rounded-md border border-cyan-300 bg-white px-5 py-3 text-sm font-semibold text-cyan-900 hover:bg-cyan-100 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-app-ring dark:border-cyan-700 dark:bg-slate-950 dark:text-cyan-100 dark:hover:bg-slate-900"
              >
                <Phone className="h-4 w-4" aria-hidden="true" />
                604-757-7797
              </a>
            </div>
          </div>
        </section>
      </main>
    </div>
  );
}