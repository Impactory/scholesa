'use client';

import {
  ArrowRight,
  BookOpenCheck,
  BriefcaseBusiness,
  CheckCircle2,
  CalendarDays,
  ClipboardCheck,
  FileCheck2,
  GraduationCap,
  LineChart,
  Network,
  PlayCircle,
  School,
  ShieldCheck,
  Sparkles,
  Users,
} from 'lucide-react';
import Image from 'next/image';
import Link from 'next/link';
import { useState } from 'react';
import { ProofFlowModal } from '@/src/components/landing/ProofFlowModal';
import { useI18n } from '@/src/lib/i18n/useI18n';
import { ThemeModeToggle } from '@/src/lib/theme/ThemeModeToggle';

const evidenceChain = [
  { key: 'hqFramework', icon: Network, tone: 'text-cyan-700 bg-cyan-50 border-cyan-200 dark:text-cyan-200 dark:bg-cyan-950/30 dark:border-cyan-800' },
  { key: 'liveSession', icon: ClipboardCheck, tone: 'text-emerald-700 bg-emerald-50 border-emerald-200 dark:text-emerald-200 dark:bg-emerald-950/30 dark:border-emerald-800' },
  { key: 'learnerProof', icon: BookOpenCheck, tone: 'text-blue-700 bg-blue-50 border-blue-200 dark:text-blue-200 dark:bg-blue-950/30 dark:border-blue-800' },
  { key: 'growthUpdate', icon: LineChart, tone: 'text-rose-700 bg-rose-50 border-rose-200 dark:text-rose-200 dark:bg-rose-950/30 dark:border-rose-800' },
  { key: 'portfolioOutput', icon: FileCheck2, tone: 'text-amber-800 bg-amber-50 border-amber-200 dark:text-amber-200 dark:bg-amber-950/30 dark:border-amber-800' },
];

const roleSurfaces = [
  { key: 'learner', path: '/learner/today', icon: GraduationCap, tone: 'border-cyan-200 bg-cyan-50/80 text-cyan-700 dark:border-cyan-800 dark:bg-cyan-950/25 dark:text-cyan-200' },
  { key: 'educator', path: '/educator/today', icon: ClipboardCheck, tone: 'border-emerald-200 bg-emerald-50/80 text-emerald-700 dark:border-emerald-800 dark:bg-emerald-950/25 dark:text-emerald-200' },
  { key: 'guardian', path: '/parent/summary', icon: Users, tone: 'border-blue-200 bg-blue-50/80 text-blue-700 dark:border-blue-800 dark:bg-blue-950/25 dark:text-blue-200' },
  { key: 'school', path: '/site/evidence-health', icon: School, tone: 'border-amber-200 bg-amber-50/80 text-amber-800 dark:border-amber-800 dark:bg-amber-950/25 dark:text-amber-200' },
  { key: 'hq', path: '/hq/capability-frameworks', icon: ShieldCheck, tone: 'border-rose-200 bg-rose-50/80 text-rose-700 dark:border-rose-800 dark:bg-rose-950/25 dark:text-rose-200' },
  { key: 'partner', path: '/partner/deliverables', icon: BriefcaseBusiness, tone: 'border-indigo-200 bg-indigo-50/80 text-indigo-700 dark:border-indigo-800 dark:bg-indigo-950/25 dark:text-indigo-200' },
];

const proofLanes = [
  { key: 'capture', tone: 'bg-cyan-500' },
  { key: 'verify', tone: 'bg-emerald-500' },
  { key: 'interpret', tone: 'bg-rose-500' },
  { key: 'communicate', tone: 'bg-amber-500' },
];

const trustSignals = [
  'claimEvidence',
  'educatorCapture',
  'familyProgress',
  'leaderCoverage',
];

const trustOutcomes = [
  'learners',
  'educators',
  'families',
  'leaders',
];

export default function LandingPage() {
  const { locale, t } = useI18n();
  const [proofFlowOpen, setProofFlowOpen] = useState(false);

  return (
    <div className="public-site min-h-screen">
      <header className="public-header sticky top-0 z-30 border-b">
        <div className="mx-auto flex max-w-7xl items-center justify-between gap-4 px-4 py-3 sm:px-6 lg:px-8">
          <Link
            href={`/${locale}`}
            className="flex min-w-0 items-center gap-3 rounded-md focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-app-ring"
            aria-label={t('landing.homeAria')}
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
              <p className="text-xs font-medium uppercase tracking-[0.18em] text-slate-500 dark:text-slate-400">{t('landing.brandSubtitle')}</p>
            </div>
          </Link>
          <nav className="flex items-center gap-2" aria-label={t('landing.publicNavigationAria')}>
            <ThemeModeToggle compact />
            <Link
              href={`/${locale}/summer-camp-2026`}
              className="min-touch-target inline-flex items-center gap-2 rounded-full border border-amber-300 bg-amber-100 px-3 py-2 text-sm font-bold text-amber-950 hover:bg-amber-200 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-app-ring dark:border-amber-700 dark:bg-amber-950/40 dark:text-amber-100 dark:hover:bg-amber-950/60 sm:px-4"
            >
              <CalendarDays className="h-4 w-4" aria-hidden="true" />
              <span className="sm:hidden">{t('landing.summerCampShort')}</span>
              <span className="hidden sm:inline">{t('landing.summerCamp')}</span>
            </Link>
            <Link
              href={`/${locale}/login`}
              className="min-touch-target inline-flex items-center rounded-md border border-app bg-app-surface px-4 py-2 text-sm font-semibold text-app-foreground hover:bg-app-surface-muted focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-app-ring"
            >
              {t('landing.loginCta')}
            </Link>
          </nav>
        </div>
      </header>

      <main>
        <section className="public-hero border-b border-transparent">
          <div className="mx-auto grid max-w-7xl content-center gap-6 px-4 py-8 sm:px-6 sm:py-12 lg:min-h-[calc(100vh-72px)] lg:grid-cols-[1fr_0.86fr] lg:items-center lg:gap-9 lg:px-8 lg:py-14">
            <div className="max-w-4xl">
              <div className="public-chip px-4 py-2">
                <Sparkles className="h-4 w-4" aria-hidden="true" />
                {t('landing.heroEyebrow')}
              </div>
              <h1 className="public-display-title mt-5 max-w-4xl text-4xl leading-[0.98] text-white sm:text-5xl lg:text-6xl">
                {t('landing.heroTitle')}
              </h1>
              <p className="mt-5 max-w-3xl text-base leading-7 text-white/75 sm:text-lg sm:leading-8">
                {t('landing.heroBody')}
              </p>
              <div className="mt-6 flex flex-col gap-3 sm:flex-row lg:mt-8">
                <Link
                  href={`/${locale}/login`}
                  className="public-button-primary min-touch-target inline-flex items-center justify-center gap-2 rounded-full px-5 py-3 text-sm font-bold transition focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-app-ring"
                >
                  {t('landing.primaryCta')}
                  <ArrowRight className="h-4 w-4" aria-hidden="true" />
                </Link>
                <button
                  type="button"
                  onClick={() => setProofFlowOpen(true)}
                  className="public-button-secondary min-touch-target inline-flex items-center justify-center gap-2 rounded-full px-5 py-3 text-sm font-semibold transition hover:bg-white/10 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-app-ring"
                  aria-haspopup="dialog"
                >
                  <PlayCircle className="h-4 w-4" aria-hidden="true" />
                  {t('landing.proofFlowCta')}
                </button>
                <Link
                  href={`/${locale}/register`}
                  className="min-touch-target inline-flex items-center justify-center rounded-full border border-white/20 bg-white/10 px-5 py-3 text-sm font-semibold text-white hover:bg-white/15 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-app-ring"
                >
                  {t('landing.registerArrow')}
                </Link>
              </div>
            </div>

            <div className="public-panel rounded-md p-4" aria-label={t('landing.evidenceCommandCenterAria')}>
              <div className="flex items-center justify-between gap-3 border-b border-white/10 pb-3">
                <div>
                  <p className="text-sm font-bold text-white">{t('landing.commandCenterTitle')}</p>
                  <p className="mt-1 text-xs text-white/55">{t('landing.commandCenterSubtitle')}</p>
                </div>
                <span className="rounded-full bg-emerald-300/15 px-3 py-1 text-xs font-bold text-emerald-100 ring-1 ring-emerald-200/25">
                  {t('landing.trustedBadge')}
                </span>
              </div>
              <div className="mt-4 grid gap-3">
                {proofLanes.map((lane) => (
                  <div key={lane.key} className="grid grid-cols-[0.35fr_1fr] items-center gap-3 rounded-md border border-white/10 bg-white/10 p-3">
                    <p className="text-xs font-bold uppercase text-white/50">{t(`landing.proofLanes.${lane.key}.label`)}</p>
                    <div>
                      <div className="h-2 overflow-hidden rounded-full bg-white/15">
                        <div className={`h-full rounded-full ${lane.tone}`} />
                      </div>
                      <p className="mt-2 text-sm font-semibold text-white">{t(`landing.proofLanes.${lane.key}.value`)}</p>
                    </div>
                  </div>
                ))}
              </div>
              <div className="mt-4 rounded-md border border-teal-200/25 bg-teal-300/10 p-3 text-sm leading-6 text-teal-50">
                {t('landing.commandCenterQuestion')}
              </div>
            </div>

            <div className="grid gap-3 md:grid-cols-5" aria-label={t('landing.evidenceChainAria')}>
              {evidenceChain.map((step, index) => {
                const Icon = step.icon;
                return (
                  <div key={step.key} className={`rounded-md border p-4 shadow-sm ${step.tone}`}>
                    <div className="flex items-center justify-between gap-3">
                      <Icon className="h-5 w-5" aria-hidden="true" />
                      <span className="text-xs font-bold opacity-70">{index + 1}</span>
                    </div>
                    <h2 className="mt-4 text-base font-bold">{t(`landing.evidenceChain.${step.key}.label`)}</h2>
                    <p className="mt-2 text-sm font-medium leading-6">{t(`landing.evidenceChain.${step.key}.detail`)}</p>
                  </div>
                );
              })}
            </div>
          </div>
        </section>

        <section className="border-b border-app bg-white px-4 py-14 sm:px-6 lg:px-8 dark:bg-slate-950">
          <div className="mx-auto max-w-7xl">
            <div className="grid gap-8 lg:grid-cols-[0.8fr_1.2fr] lg:items-start">
              <div>
                <p className="text-sm font-bold uppercase text-cyan-700 dark:text-cyan-300">{t('landing.roleSurfacesKicker')}</p>
                <h2 className="mt-3 text-3xl font-bold text-slate-950 sm:text-4xl dark:text-white">
                  {t('landing.roleSurfacesTitle')}
                </h2>
                <p className="mt-4 text-base leading-7 text-slate-700 dark:text-slate-300">
                  {t('landing.roleSurfacesBody')}
                </p>
              </div>
              <div className="grid gap-3 sm:grid-cols-2">
                {roleSurfaces.map((surface) => {
                  const Icon = surface.icon;
                  return (
                    <Link
                      key={surface.key}
                      href={`/${locale}${surface.path}`}
                      className={`group rounded-md border p-4 shadow-sm transition hover:-translate-y-0.5 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-app-ring ${surface.tone}`}
                    >
                      <div className="flex items-start justify-between gap-4">
                        <Icon className="h-5 w-5" aria-hidden="true" />
                        <ArrowRight className="h-4 w-4 opacity-70 transition group-hover:translate-x-0.5" aria-hidden="true" />
                      </div>
                      <h3 className="mt-4 text-lg font-bold">{t(`landing.roles.${surface.key}.label`)}</h3>
                      <p className="mt-2 text-sm font-medium leading-6">{t(`landing.roles.${surface.key}.proof`)}</p>
                    </Link>
                  );
                })}
              </div>
            </div>
          </div>
        </section>

        <section className="border-b border-app bg-slate-50 px-4 py-14 sm:px-6 lg:px-8 dark:bg-slate-900">
          <div className="mx-auto grid max-w-7xl gap-8 lg:grid-cols-2">
            <div className="rounded-md border border-emerald-200 bg-white p-5 shadow-sm dark:border-emerald-800 dark:bg-slate-950">
              <div className="flex items-center gap-2 text-sm font-bold uppercase text-emerald-700 dark:text-emerald-300">
                <CheckCircle2 className="h-5 w-5" aria-hidden="true" />
                {t('landing.trustTitle')}
              </div>
              <ul className="mt-5 space-y-3">
                {trustSignals.map((signal) => (
                  <li key={signal} className="flex gap-3 text-sm leading-6 text-slate-700 dark:text-slate-300">
                    <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0 text-emerald-600 dark:text-emerald-300" aria-hidden="true" />
                    <span>{t(`landing.trustSignals.${signal}`)}</span>
                  </li>
                ))}
              </ul>
            </div>
            <div className="rounded-md border border-blue-200 bg-white p-5 shadow-sm dark:border-blue-800 dark:bg-slate-950">
              <div className="flex items-center gap-2 text-sm font-bold uppercase text-blue-700 dark:text-blue-300">
                <Users className="h-5 w-5" aria-hidden="true" />
                {t('landing.accountableTitle')}
              </div>
              <div className="mt-5 grid gap-3 sm:grid-cols-2">
                {trustOutcomes.map((outcome) => (
                  <div key={outcome} className="rounded-md border border-slate-200 bg-slate-50 p-4 dark:border-slate-700 dark:bg-slate-900">
                    <p className="text-sm font-bold text-slate-950 dark:text-white">{t(`landing.trustOutcomes.${outcome}.label`)}</p>
                    <p className="mt-2 text-sm leading-6 text-slate-600 dark:text-slate-400">{t(`landing.trustOutcomes.${outcome}.detail`)}</p>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </section>

        <section className="bg-white px-4 py-12 sm:px-6 lg:px-8 dark:bg-slate-950">
          <div className="mx-auto flex max-w-7xl flex-col gap-4 rounded-md border border-cyan-200 bg-cyan-50 p-5 shadow-sm md:flex-row md:items-center md:justify-between dark:border-cyan-800 dark:bg-cyan-950/30">
            <div className="flex items-start gap-3">
              <ShieldCheck className="mt-1 h-5 w-5 text-cyan-700 dark:text-cyan-300" aria-hidden="true" />
              <div>
                <h2 className="text-lg font-bold text-slate-950 dark:text-white">{t('landing.finalCtaTitle')}</h2>
                <p className="mt-1 text-sm leading-6 text-slate-700 dark:text-slate-300">
                  {t('landing.finalCtaBody')}
                </p>
              </div>
            </div>
            <Link
              href={`/${locale}/login`}
              className="min-touch-target inline-flex shrink-0 items-center justify-center gap-2 rounded-md bg-cyan-700 px-5 py-3 text-sm font-semibold text-white hover:bg-cyan-800 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-app-ring dark:bg-cyan-300 dark:text-slate-950 dark:hover:bg-cyan-200"
            >
              {t('landing.signInCta')}
              <ArrowRight className="h-4 w-4" aria-hidden="true" />
            </Link>
          </div>
        </section>
      </main>

      <ProofFlowModal open={proofFlowOpen} onClose={() => setProofFlowOpen(false)} />
    </div>
  );
}
