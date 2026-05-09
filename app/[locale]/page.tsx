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
  LockKeyhole,
  Network,
  School,
  ShieldCheck,
  Smartphone,
  Sparkles,
  Users,
} from 'lucide-react';
import Image from 'next/image';
import Link from 'next/link';
import { useI18n } from '@/src/lib/i18n/useI18n';
import { ThemeModeToggle } from '@/src/lib/theme/ThemeModeToggle';

const evidenceChain = [
  { label: 'HQ framework', detail: 'capabilities, rubrics, checkpoints', icon: Network },
  { label: 'Live session', detail: 'teacher capture during studio time', icon: ClipboardCheck },
  { label: 'Learner proof', detail: 'artifact, reflection, explain-back', icon: BookOpenCheck },
  { label: 'Growth update', detail: 'rubric-linked capability history', icon: LineChart },
  { label: 'Portfolio output', detail: 'best evidence with provenance', icon: FileCheck2 },
];

const roleSurfaces = [
  { role: 'Learner', path: '/learner/today', proof: 'missions, proof prompts, portfolio evidence', icon: GraduationCap },
  { role: 'Educator', path: '/educator/today', proof: 'quick capture, proof review, verification queue', icon: ClipboardCheck },
  { role: 'Guardian', path: '/parent/summary', proof: 'capability progress with evidence links', icon: Users },
  { role: 'School', path: '/site/evidence-health', proof: 'implementation health and evidence coverage', icon: School },
  { role: 'HQ', path: '/hq/capability-frameworks', proof: 'framework governance and rubric structure', icon: ShieldCheck },
  { role: 'Partner', path: '/partner/deliverables', proof: 'evidence-facing deliverables and contracts', icon: BriefcaseBusiness },
];

const goldSignals = [
  'Six-role web cutover proven on the rehearsal tag',
  'Proof review and verification routes render without queue/index errors',
  'Partner evidence URL deliverable persisted and read back from Firestore',
  'Traffic-pinning accepted as the final web release control',
];

const nativeSignals = [
  { label: 'macOS local build', status: 'Proven', detail: 'release app built locally' },
  { label: 'iOS local build', status: 'Proven', detail: 'no-codesign release app built' },
  { label: 'Android local build', status: 'Proven', detail: 'AAB and APK built locally' },
  { label: 'Store distribution', status: 'Blocked', detail: 'awaiting Apple and Google signing assets' },
];

export default function LandingPage() {
  const { locale, t } = useI18n();

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
        <section className="border-b border-app bg-app-surface">
          <div className="mx-auto grid min-h-[calc(100vh-72px)] max-w-7xl content-center gap-9 px-4 py-12 sm:px-6 sm:py-14 lg:px-8">
            <div className="max-w-4xl">
              <div className="inline-flex items-center gap-2 rounded-md border border-app bg-app-surface px-3 py-2 text-sm font-semibold text-app-primary shadow-sm">
                <Sparkles className="h-4 w-4" aria-hidden="true" />
                Current Gold web packet: GO
              </div>
              <h1 className="mt-6 max-w-4xl text-4xl font-bold leading-tight text-app-foreground sm:text-5xl sm:leading-tight lg:text-6xl">
                Capability growth, backed by evidence people can inspect.
              </h1>
              <p className="mt-6 max-w-3xl text-base leading-8 text-app-muted sm:text-lg">
                Scholesa connects classroom observations, learner artifacts, proof-of-learning,
                rubric judgments, growth history, portfolios, reports, and partner outputs into one
                traceable operating surface.
              </p>
              <div className="mt-8 flex flex-col gap-3 sm:flex-row">
                <Link
                  href={`/${locale}/login`}
                  className="min-touch-target inline-flex items-center justify-center gap-2 rounded-md bg-app-primary px-5 py-3 text-sm font-semibold text-app-primary-foreground shadow-sm hover:bg-app-primary-emphasis focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-app-ring"
                >
                  Enter Scholesa
                  <ArrowRight className="h-4 w-4" aria-hidden="true" />
                </Link>
                <Link
                  href={`/${locale}/register`}
                  className="min-touch-target inline-flex items-center justify-center rounded-md border border-app bg-app-surface px-5 py-3 text-sm font-semibold text-app-foreground hover:bg-app-surface-muted focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-app-ring"
                >
                  {t('landing.register')}
                </Link>
              </div>
            </div>

            <div className="grid gap-3 md:grid-cols-5" aria-label="Evidence chain">
              {evidenceChain.map((step, index) => {
                const Icon = step.icon;
                return (
                  <div key={step.label} className="rounded-md border border-app bg-app-surface/90 p-4 shadow-sm">
                    <div className="flex items-center justify-between gap-3">
                      <Icon className="h-5 w-5 text-app-primary" aria-hidden="true" />
                      <span className="text-xs font-bold text-app-muted">{index + 1}</span>
                    </div>
                    <h2 className="mt-4 text-base font-bold text-app-foreground">{step.label}</h2>
                    <p className="mt-2 text-sm leading-6 text-app-muted">{step.detail}</p>
                  </div>
                );
              })}
            </div>
          </div>
        </section>

        <section className="border-b border-app bg-app-canvas px-4 py-14 sm:px-6 lg:px-8">
          <div className="mx-auto max-w-7xl">
            <div className="grid gap-8 lg:grid-cols-[0.8fr_1.2fr] lg:items-start">
              <div>
                <p className="text-sm font-bold uppercase text-app-primary">Role surfaces</p>
                <h2 className="mt-3 text-3xl font-bold text-app-foreground sm:text-4xl">
                  One evidence chain, six accountable views.
                </h2>
                <p className="mt-4 text-base leading-7 text-app-muted">
                  The current Gold packet proves learner, educator, guardian, site, HQ, and partner
                  web access against the rehearsed Cloud Run surface.
                </p>
              </div>
              <div className="grid gap-3 sm:grid-cols-2">
                {roleSurfaces.map((surface) => {
                  const Icon = surface.icon;
                  return (
                    <Link
                      key={surface.role}
                      href={`/${locale}${surface.path}`}
                      className="group rounded-md border border-app bg-app-surface p-4 shadow-sm transition hover:-translate-y-0.5 hover:bg-app-surface-muted focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-app-ring"
                    >
                      <div className="flex items-start justify-between gap-4">
                        <Icon className="h-5 w-5 text-app-primary" aria-hidden="true" />
                        <ArrowRight className="h-4 w-4 text-app-muted transition group-hover:translate-x-0.5" aria-hidden="true" />
                      </div>
                      <h3 className="mt-4 text-lg font-bold text-app-foreground">{surface.role}</h3>
                      <p className="mt-2 text-sm leading-6 text-app-muted">{surface.proof}</p>
                    </Link>
                  );
                })}
              </div>
            </div>
          </div>
        </section>

        <section className="border-b border-app bg-app-surface px-4 py-14 sm:px-6 lg:px-8">
          <div className="mx-auto grid max-w-7xl gap-8 lg:grid-cols-2">
            <div className="rounded-md border border-app bg-app-canvas p-5 shadow-sm">
              <div className="flex items-center gap-2 text-sm font-bold uppercase text-app-primary">
                <CheckCircle2 className="h-5 w-5" aria-hidden="true" />
                Web Gold evidence
              </div>
              <ul className="mt-5 space-y-3">
                {goldSignals.map((signal) => (
                  <li key={signal} className="flex gap-3 text-sm leading-6 text-app-muted">
                    <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0 text-app-primary" aria-hidden="true" />
                    <span>{signal}</span>
                  </li>
                ))}
              </ul>
            </div>
            <div className="rounded-md border border-app bg-app-canvas p-5 shadow-sm">
              <div className="flex items-center gap-2 text-sm font-bold uppercase text-app-primary">
                <Smartphone className="h-5 w-5" aria-hidden="true" />
                Native channel boundary
              </div>
              <div className="mt-5 grid gap-3 sm:grid-cols-2">
                {nativeSignals.map((signal) => (
                  <div key={signal.label} className="rounded-md border border-app bg-app-surface p-4">
                    <div className="flex items-center justify-between gap-3">
                      <p className="text-sm font-bold text-app-foreground">{signal.label}</p>
                      <span className={`rounded-md px-2 py-1 text-xs font-bold ${signal.status === 'Proven' ? 'bg-emerald-100 text-emerald-800' : 'bg-amber-100 text-amber-900'}`}>
                        {signal.status}
                      </span>
                    </div>
                    <p className="mt-2 text-sm leading-6 text-app-muted">{signal.detail}</p>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </section>

        <section className="bg-app-canvas px-4 py-12 sm:px-6 lg:px-8">
          <div className="mx-auto flex max-w-7xl flex-col gap-4 rounded-md border border-app bg-app-surface p-5 shadow-sm md:flex-row md:items-center md:justify-between">
            <div className="flex items-start gap-3">
              <LockKeyhole className="mt-1 h-5 w-5 text-app-primary" aria-hidden="true" />
              <div>
                <h2 className="text-lg font-bold text-app-foreground">Evidence before confidence.</h2>
                <p className="mt-1 text-sm leading-6 text-app-muted">
                  Native app-store Gold waits for live TestFlight, Play internal, and macOS
                  notarization proof. The web evidence packet is ready now.
                </p>
              </div>
            </div>
            <Link
              href={`/${locale}/login`}
              className="min-touch-target inline-flex shrink-0 items-center justify-center gap-2 rounded-md bg-app-primary px-5 py-3 text-sm font-semibold text-app-primary-foreground hover:bg-app-primary-emphasis focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-app-ring"
            >
              Sign in
              <ArrowRight className="h-4 w-4" aria-hidden="true" />
            </Link>
          </div>
        </section>
      </main>
    </div>
  );
}
