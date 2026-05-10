'use client';

import {
  ArrowRight,
  BookOpenCheck,
  BriefcaseBusiness,
  CheckCircle2,
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
  { label: 'HQ framework', detail: 'capabilities, rubrics, checkpoints', icon: Network, tone: 'text-cyan-700 bg-cyan-50 border-cyan-200 dark:text-cyan-200 dark:bg-cyan-950/30 dark:border-cyan-800' },
  { label: 'Live session', detail: 'teacher capture during studio time', icon: ClipboardCheck, tone: 'text-emerald-700 bg-emerald-50 border-emerald-200 dark:text-emerald-200 dark:bg-emerald-950/30 dark:border-emerald-800' },
  { label: 'Learner proof', detail: 'artifact, reflection, explain-back', icon: BookOpenCheck, tone: 'text-blue-700 bg-blue-50 border-blue-200 dark:text-blue-200 dark:bg-blue-950/30 dark:border-blue-800' },
  { label: 'Growth update', detail: 'rubric-linked capability history', icon: LineChart, tone: 'text-rose-700 bg-rose-50 border-rose-200 dark:text-rose-200 dark:bg-rose-950/30 dark:border-rose-800' },
  { label: 'Portfolio output', detail: 'best evidence with provenance', icon: FileCheck2, tone: 'text-amber-800 bg-amber-50 border-amber-200 dark:text-amber-200 dark:bg-amber-950/30 dark:border-amber-800' },
];

const roleSurfaces = [
  { role: 'Learner', path: '/learner/today', proof: 'missions, proof prompts, portfolio evidence', icon: GraduationCap, tone: 'border-cyan-200 bg-cyan-50/80 text-cyan-700 dark:border-cyan-800 dark:bg-cyan-950/25 dark:text-cyan-200' },
  { role: 'Educator', path: '/educator/today', proof: 'quick capture, proof review, verification queue', icon: ClipboardCheck, tone: 'border-emerald-200 bg-emerald-50/80 text-emerald-700 dark:border-emerald-800 dark:bg-emerald-950/25 dark:text-emerald-200' },
  { role: 'Guardian', path: '/parent/summary', proof: 'capability progress with evidence links', icon: Users, tone: 'border-blue-200 bg-blue-50/80 text-blue-700 dark:border-blue-800 dark:bg-blue-950/25 dark:text-blue-200' },
  { role: 'School', path: '/site/evidence-health', proof: 'implementation health and evidence coverage', icon: School, tone: 'border-amber-200 bg-amber-50/80 text-amber-800 dark:border-amber-800 dark:bg-amber-950/25 dark:text-amber-200' },
  { role: 'HQ', path: '/hq/capability-frameworks', proof: 'framework governance and rubric structure', icon: ShieldCheck, tone: 'border-rose-200 bg-rose-50/80 text-rose-700 dark:border-rose-800 dark:bg-rose-950/25 dark:text-rose-200' },
  { role: 'Partner', path: '/partner/deliverables', proof: 'evidence-facing deliverables and contracts', icon: BriefcaseBusiness, tone: 'border-indigo-200 bg-indigo-50/80 text-indigo-700 dark:border-indigo-800 dark:bg-indigo-950/25 dark:text-indigo-200' },
];

const proofLanes = [
  { label: 'Capture', value: 'live observations', tone: 'bg-cyan-500' },
  { label: 'Verify', value: 'proof review', tone: 'bg-emerald-500' },
  { label: 'Interpret', value: 'growth events', tone: 'bg-rose-500' },
  { label: 'Communicate', value: 'portfolio + Passport', tone: 'bg-amber-500' },
];

const trustSignals = [
  'Every learner claim can point back to evidence, context, and reviewer judgment',
  'Educators can capture meaningful observations during the live flow of class',
  'Families see capability progress without reducing growth to marks or averages',
  'School and HQ teams can trace implementation health through evidence coverage',
];

const trustOutcomes = [
  { label: 'Learners', detail: 'know what they are creating, what they can explain, and what belongs in their portfolio' },
  { label: 'Educators', detail: 'see the next evidence action without losing the rhythm of studio time' },
  { label: 'Families', detail: 'understand growth through real work, not vague summaries or unexplained scores' },
  { label: 'Leaders', detail: 'spot evidence gaps, support teachers, and protect the integrity of every claim' },
];

export default function LandingPage() {
  const { locale, t } = useI18n();
  const [proofFlowOpen, setProofFlowOpen] = useState(false);

  return (
    <div className="min-h-screen bg-app-canvas text-app-foreground">
      <header className="sticky top-0 z-30 border-b border-app bg-app-surface/95 backdrop-blur">
        <div className="mx-auto flex max-w-7xl items-center justify-between gap-4 px-4 py-3 sm:px-6 lg:px-8">
          <Link
            href={`/${locale}`}
            className="flex min-w-0 items-center gap-3 rounded-md focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-app-ring"
            aria-label="Scholesa home"
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
              <p className="text-lg font-bold leading-5 text-app-foreground">Scholesa</p>
              <p className="text-xs font-medium uppercase text-app-muted">Evidence OS</p>
            </div>
          </Link>
          <nav className="flex items-center gap-2" aria-label="Public navigation">
            <ThemeModeToggle compact />
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
        <section className="border-b border-app bg-cyan-50 dark:bg-slate-950">
          <div className="mx-auto grid max-w-7xl content-center gap-6 px-4 py-8 sm:px-6 sm:py-12 lg:min-h-[calc(100vh-72px)] lg:grid-cols-[1fr_0.86fr] lg:items-center lg:gap-9 lg:px-8 lg:py-14">
            <div className="max-w-4xl">
              <div className="inline-flex items-center gap-2 rounded-md border border-emerald-200 bg-emerald-50 px-3 py-2 text-sm font-semibold text-emerald-800 shadow-sm dark:border-emerald-800 dark:bg-emerald-950/40 dark:text-emerald-200">
                <Sparkles className="h-4 w-4" aria-hidden="true" />
                Capability learning, made visible
              </div>
              <h1 className="mt-5 max-w-4xl text-3xl font-bold leading-tight text-slate-950 sm:text-4xl sm:leading-tight lg:text-5xl dark:text-white">
                The proof engine for real capability growth.
              </h1>
              <p className="mt-5 max-w-3xl text-base leading-7 text-slate-700 sm:text-lg sm:leading-8 dark:text-slate-300">
                Scholesa turns classroom moments into inspectable proof: observations, learner
                artifacts, explain-backs, rubric judgments, growth history, portfolios, reports,
                and partner deliverables all tied to the evidence that earned the claim.
              </p>
              <div className="mt-6 flex flex-col gap-3 sm:flex-row lg:mt-8">
                <Link
                  href={`/${locale}/login`}
                  className="min-touch-target inline-flex items-center justify-center gap-2 rounded-md bg-cyan-700 px-5 py-3 text-sm font-semibold text-white shadow-sm hover:bg-cyan-800 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-app-ring dark:bg-cyan-400 dark:text-slate-950 dark:hover:bg-cyan-300"
                >
                  Enter the evidence engine
                  <ArrowRight className="h-4 w-4" aria-hidden="true" />
                </Link>
                <button
                  type="button"
                  onClick={() => setProofFlowOpen(true)}
                  className="min-touch-target inline-flex items-center justify-center gap-2 rounded-md border border-cyan-300 bg-white px-5 py-3 text-sm font-semibold text-cyan-800 shadow-sm hover:bg-cyan-50 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-app-ring dark:border-cyan-700 dark:bg-slate-900 dark:text-cyan-200 dark:hover:bg-slate-800"
                  aria-haspopup="dialog"
                >
                  <PlayCircle className="h-4 w-4" aria-hidden="true" />
                  See the Proof Flow
                </button>
                <Link
                  href={`/${locale}/register`}
                  className="min-touch-target inline-flex items-center justify-center rounded-md border border-cyan-200 bg-white px-5 py-3 text-sm font-semibold text-slate-950 hover:bg-cyan-100 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-app-ring dark:border-slate-700 dark:bg-slate-900 dark:text-white dark:hover:bg-slate-800"
                >
                  {t('landing.register')}
                </Link>
              </div>
            </div>

            <div className="rounded-md border border-cyan-200 bg-white p-4 shadow-xl shadow-cyan-900/10 dark:border-slate-700 dark:bg-slate-900 dark:shadow-black/30" aria-label="Evidence command center">
              <div className="flex items-center justify-between gap-3 border-b border-cyan-100 pb-3 dark:border-slate-700">
                <div>
                  <p className="text-sm font-bold text-slate-950 dark:text-white">Evidence command center</p>
                  <p className="mt-1 text-xs text-slate-600 dark:text-slate-400">Capture, verify, interpret, and communicate growth.</p>
                </div>
                <span className="rounded-md bg-emerald-100 px-2 py-1 text-xs font-bold text-emerald-800 dark:bg-emerald-950 dark:text-emerald-200">
                  Trusted
                </span>
              </div>
              <div className="mt-4 grid gap-3">
                {proofLanes.map((lane) => (
                  <div key={lane.label} className="grid grid-cols-[0.35fr_1fr] items-center gap-3 rounded-md border border-slate-100 bg-slate-50 p-3 dark:border-slate-700 dark:bg-slate-800/70">
                    <p className="text-xs font-bold uppercase text-slate-500 dark:text-slate-400">{lane.label}</p>
                    <div>
                      <div className="h-2 overflow-hidden rounded-full bg-slate-200 dark:bg-slate-700">
                        <div className={`h-full rounded-full ${lane.tone}`} />
                      </div>
                      <p className="mt-2 text-sm font-semibold text-slate-900 dark:text-slate-100">{lane.value}</p>
                    </div>
                  </div>
                ))}
              </div>
              <div className="mt-4 rounded-md border border-cyan-200 bg-cyan-50 p-3 text-sm leading-6 text-cyan-950 dark:border-cyan-800 dark:bg-cyan-950/30 dark:text-cyan-100">
                Every view is designed to answer the same question: what can this learner do, and
                what evidence makes that claim trustworthy?
              </div>
            </div>

            <div className="grid gap-3 md:grid-cols-5" aria-label="Evidence chain">
              {evidenceChain.map((step, index) => {
                const Icon = step.icon;
                return (
                  <div key={step.label} className={`rounded-md border p-4 shadow-sm ${step.tone}`}>
                    <div className="flex items-center justify-between gap-3">
                      <Icon className="h-5 w-5" aria-hidden="true" />
                      <span className="text-xs font-bold opacity-70">{index + 1}</span>
                    </div>
                    <h2 className="mt-4 text-base font-bold">{step.label}</h2>
                    <p className="mt-2 text-sm font-medium leading-6">{step.detail}</p>
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
                <p className="text-sm font-bold uppercase text-cyan-700 dark:text-cyan-300">Role surfaces</p>
                <h2 className="mt-3 text-3xl font-bold text-slate-950 sm:text-4xl dark:text-white">
                  Six roles. One chain of truth.
                </h2>
                <p className="mt-4 text-base leading-7 text-slate-700 dark:text-slate-300">
                  Learners see what they are creating. Educators capture proof in the moment.
                  Families, schools, HQ, and partners see the evidence behind every claim.
                </p>
              </div>
              <div className="grid gap-3 sm:grid-cols-2">
                {roleSurfaces.map((surface) => {
                  const Icon = surface.icon;
                  return (
                    <Link
                      key={surface.role}
                      href={`/${locale}${surface.path}`}
                      className={`group rounded-md border p-4 shadow-sm transition hover:-translate-y-0.5 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-app-ring ${surface.tone}`}
                    >
                      <div className="flex items-start justify-between gap-4">
                        <Icon className="h-5 w-5" aria-hidden="true" />
                        <ArrowRight className="h-4 w-4 opacity-70 transition group-hover:translate-x-0.5" aria-hidden="true" />
                      </div>
                      <h3 className="mt-4 text-lg font-bold">{surface.role}</h3>
                      <p className="mt-2 text-sm font-medium leading-6">{surface.proof}</p>
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
                Trust you can inspect
              </div>
              <ul className="mt-5 space-y-3">
                {trustSignals.map((signal) => (
                  <li key={signal} className="flex gap-3 text-sm leading-6 text-slate-700 dark:text-slate-300">
                    <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0 text-emerald-600 dark:text-emerald-300" aria-hidden="true" />
                    <span>{signal}</span>
                  </li>
                ))}
              </ul>
            </div>
            <div className="rounded-md border border-blue-200 bg-white p-5 shadow-sm dark:border-blue-800 dark:bg-slate-950">
              <div className="flex items-center gap-2 text-sm font-bold uppercase text-blue-700 dark:text-blue-300">
                <Users className="h-5 w-5" aria-hidden="true" />
                Built for accountable growth
              </div>
              <div className="mt-5 grid gap-3 sm:grid-cols-2">
                {trustOutcomes.map((outcome) => (
                  <div key={outcome.label} className="rounded-md border border-slate-200 bg-slate-50 p-4 dark:border-slate-700 dark:bg-slate-900">
                    <p className="text-sm font-bold text-slate-950 dark:text-white">{outcome.label}</p>
                    <p className="mt-2 text-sm leading-6 text-slate-600 dark:text-slate-400">{outcome.detail}</p>
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
                <h2 className="text-lg font-bold text-slate-950 dark:text-white">Make growth impossible to miss.</h2>
                <p className="mt-1 text-sm leading-6 text-slate-700 dark:text-slate-300">
                  Bring proof, reflection, feedback, and portfolio-worthy work into one clear flow.
                </p>
              </div>
            </div>
            <Link
              href={`/${locale}/login`}
              className="min-touch-target inline-flex shrink-0 items-center justify-center gap-2 rounded-md bg-cyan-700 px-5 py-3 text-sm font-semibold text-white hover:bg-cyan-800 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-app-ring dark:bg-cyan-300 dark:text-slate-950 dark:hover:bg-cyan-200"
            >
              Sign in
              <ArrowRight className="h-4 w-4" aria-hidden="true" />
            </Link>
          </div>
        </section>
      </main>

      <ProofFlowModal open={proofFlowOpen} onClose={() => setProofFlowOpen(false)} />
    </div>
  );
}
