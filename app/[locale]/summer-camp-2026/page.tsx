import type { Metadata } from 'next';
import Image from 'next/image';
import Link from 'next/link';
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
  { value: '10', label: 'sessions' },
  { value: '2', label: 'weeks' },
  { value: '5', label: 'capability strands' },
  { value: '5+', label: 'portfolio artifacts' },
  { value: '1', label: 'family showcase' },
];

const capabilities = [
  {
    label: 'Think',
    detail: 'Notice problems, ask better questions, and reason from what you observe.',
    icon: Search,
    tone: 'border-cyan-200 bg-cyan-50 text-cyan-800 dark:border-cyan-800 dark:bg-cyan-950/30 dark:text-cyan-100',
  },
  {
    label: 'Make',
    detail: 'Design, build, test, and improve real things with physical materials.',
    icon: Hammer,
    tone: 'border-emerald-200 bg-emerald-50 text-emerald-800 dark:border-emerald-800 dark:bg-emerald-950/30 dark:text-emerald-100',
  },
  {
    label: 'Communicate',
    detail: 'Explain your ideas clearly to peers, educators, and families.',
    icon: Megaphone,
    tone: 'border-blue-200 bg-blue-50 text-blue-800 dark:border-blue-800 dark:bg-blue-950/30 dark:text-blue-100',
  },
  {
    label: 'Lead',
    detail: 'Take initiative, contribute in team roles, and reflect on your impact.',
    icon: Users,
    tone: 'border-rose-200 bg-rose-50 text-rose-800 dark:border-rose-800 dark:bg-rose-950/30 dark:text-rose-100',
  },
  {
    label: 'Build for the world',
    detail: 'Create ideas that are helpful, fair, and meaningful beyond school.',
    icon: Sprout,
    tone: 'border-amber-200 bg-amber-50 text-amber-900 dark:border-amber-800 dark:bg-amber-950/30 dark:text-amber-100',
  },
];

const weeks = [
  {
    label: 'Week 1',
    title: 'Young Inventors Lab',
    date: 'July 6-10, 2026',
    description: 'Design, build, and prototype inventions that create helpful impact in the real world.',
    tone: 'border-emerald-200 bg-emerald-50 dark:border-emerald-800 dark:bg-emerald-950/20',
    headerTone: 'bg-emerald-700 text-white dark:bg-emerald-800',
    sessions: [
      {
        day: 'Mon',
        name: 'What Problem Can I Solve?',
        theme: 'Noticing needs in the world around us',
        tags: ['Think', 'Observe'],
      },
      {
        day: 'Tue',
        name: 'Sketch It, Name It, Claim It',
        theme: 'From observation to invention concept',
        tags: ['Make', 'Think'],
      },
      {
        day: 'Wed',
        name: 'Build Sprint Day 1',
        theme: 'Materials, making, and first prototype',
        tags: ['Make', 'Lead'],
      },
      {
        day: 'Thu',
        name: 'Test, Break, Improve',
        theme: 'Peer feedback and revision sprint',
        tags: ['Make', 'Think', 'Communicate'],
      },
      {
        day: 'Fri',
        name: 'Innovation Showcase - Week 1',
        theme: 'Present your invention to families',
        tags: ['Communicate', 'Lead'],
        showcase: true,
      },
    ],
  },
  {
    label: 'Week 2',
    title: 'Future City Builders',
    date: 'July 13-17, 2026',
    description:
      'Collaborate to design and build a smart, eco-friendly city of tomorrow through team projects and big ideas.',
    tone: 'border-indigo-200 bg-indigo-50 dark:border-indigo-800 dark:bg-indigo-950/20',
    headerTone: 'bg-indigo-700 text-white dark:bg-indigo-800',
    sessions: [
      {
        day: 'Mon',
        name: 'What Does Our City Need?',
        theme: 'Map your community and choose your city challenge',
        tags: ['Think', 'Build for world'],
      },
      {
        day: 'Tue',
        name: 'Design the Smart System',
        theme: 'Eco-friendly features, people, and planet thinking',
        tags: ['Make', 'Build for world'],
      },
      {
        day: 'Wed',
        name: 'Build the City - Team Sprint',
        theme: 'Roles assigned, building together, decisions made',
        tags: ['Make', 'Lead', 'Communicate'],
      },
      {
        day: 'Thu',
        name: 'Rehearse Your City Pitch',
        theme: 'Explain your design and prepare for showcase',
        tags: ['Communicate', 'Lead'],
      },
      {
        day: 'Fri',
        name: 'City Showcase - Final Day',
        theme: 'Present to families and earn a portfolio badge',
        tags: ['Communicate', 'Build for world'],
        showcase: true,
      },
    ],
  },
];

const differentiators = [
  {
    title: 'Hands-on every day',
    detail: 'Every session has a build sprint. Learners make something real instead of completing worksheets.',
    icon: Hammer,
  },
  {
    title: 'Minimal screen time',
    detail: 'Physical materials, teamwork, and face-to-face problem solving keep the experience grounded.',
    icon: ShieldCheck,
  },
  {
    title: 'Visible portfolio growth',
    detail: 'Every learner leaves with artifacts, reflections, and evidence of capability growth.',
    icon: CheckCircle2,
  },
  {
    title: 'Ideas that help people',
    detail: 'Every project asks who it helps and how. Purpose is built in from day one.',
    icon: Lightbulb,
  },
];

export default async function SummerCampPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;

  return (
    <div className="min-h-screen bg-app-canvas text-app-foreground">
      <header className="border-b border-app bg-app-surface/95 backdrop-blur">
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
              <p className="text-xs font-medium uppercase text-app-muted">Young Innovators</p>
            </div>
          </Link>
          <nav className="flex items-center gap-2" aria-label="Summer camp navigation">
            <Link
              href={`/${locale}/privacy`}
              className="hidden min-touch-target items-center rounded-md px-3 py-2 text-sm font-semibold text-app-muted hover:text-app-foreground focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-app-ring sm:inline-flex"
            >
              Privacy
            </Link>
            <a
              href="mailto:info@scholesa.com?subject=Scholesa%20Young%20Innovators%20Summer%20Camp%202026"
              className="min-touch-target inline-flex items-center justify-center gap-2 rounded-md bg-cyan-700 px-4 py-2 text-sm font-semibold text-white hover:bg-cyan-800 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-app-ring dark:bg-cyan-300 dark:text-slate-950 dark:hover:bg-cyan-200"
            >
              <Mail className="h-4 w-4" aria-hidden="true" />
              Reserve
            </a>
          </nav>
        </div>
      </header>

      <main>
        <section className="border-b border-app bg-slate-950 text-white">
          <div className="mx-auto grid max-w-7xl gap-8 px-4 py-10 sm:px-6 sm:py-14 lg:min-h-[calc(100vh-72px)] lg:grid-cols-[1fr_0.9fr] lg:items-center lg:px-8">
            <div>
              <div className="inline-flex items-center gap-2 rounded-md border border-amber-300/40 bg-amber-300/10 px-3 py-2 text-sm font-bold uppercase tracking-wide text-amber-200">
                <CalendarDays className="h-4 w-4" aria-hidden="true" />
                Summer Camp 2026
              </div>
              <p className="mt-5 text-sm font-bold uppercase tracking-wide text-cyan-200">
                Grades 1-6 · Ages 6-11
              </p>
              <h1 className="mt-4 max-w-4xl text-4xl font-bold leading-tight sm:text-5xl lg:text-6xl">
                Young Innovators build future skills through creativity and invention.
              </h1>
              <p className="mt-5 max-w-2xl text-base leading-7 text-slate-300 sm:text-lg sm:leading-8">
                A creativity-driven camp that helps young minds imagine, design, test, and
                explain ideas with helpful impact. Two weeks. Ten sessions. Real projects
                learners are proud to show.
              </p>
              <div className="mt-7 flex flex-col gap-3 sm:flex-row">
                <a
                  href="mailto:info@scholesa.com?subject=Scholesa%20Young%20Innovators%20Summer%20Camp%202026"
                  className="min-touch-target inline-flex items-center justify-center gap-2 rounded-md bg-amber-300 px-5 py-3 text-sm font-bold text-slate-950 hover:bg-amber-200 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-app-ring"
                >
                  Reserve your spot
                  <ArrowRight className="h-4 w-4" aria-hidden="true" />
                </a>
                <a
                  href="tel:6047577797"
                  className="min-touch-target inline-flex items-center justify-center gap-2 rounded-md border border-slate-600 bg-slate-900 px-5 py-3 text-sm font-semibold text-white hover:bg-slate-800 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-app-ring"
                >
                  <Phone className="h-4 w-4" aria-hidden="true" />
                  604-757-7797
                </a>
              </div>
            </div>

            <div className="grid gap-4" aria-label="Summer camp weeks">
              {weeks.map((week) => (
                <section key={week.label} className="rounded-md border border-white/10 bg-white/5 p-5 shadow-lg shadow-black/20">
                  <p className="text-xs font-bold uppercase tracking-wide text-cyan-200">{week.label}</p>
                  <h2 className="mt-2 text-2xl font-bold text-white">{week.title}</h2>
                  <p className="mt-1 text-sm font-semibold text-amber-200">{week.date}</p>
                  <p className="mt-3 text-sm leading-6 text-slate-300">{week.description}</p>
                </section>
              ))}
            </div>
          </div>
        </section>

        <section className="border-b border-app bg-cyan-700 px-4 py-6 text-white sm:px-6 lg:px-8">
          <div className="mx-auto grid max-w-7xl gap-3 sm:grid-cols-5">
            {stats.map((stat) => (
              <div key={stat.label} className="rounded-md border border-white/15 bg-white/10 p-4 text-center">
                <p className="text-3xl font-bold text-amber-200">{stat.value}</p>
                <p className="mt-1 text-xs font-bold uppercase tracking-wide text-cyan-50">{stat.label}</p>
              </div>
            ))}
          </div>
        </section>

        <section className="border-b border-app bg-white px-4 py-14 sm:px-6 lg:px-8 dark:bg-slate-950">
          <div className="mx-auto max-w-7xl">
            <div className="max-w-3xl">
              <p className="text-sm font-bold uppercase text-cyan-700 dark:text-cyan-300">What learners build</p>
              <h2 className="mt-3 text-3xl font-bold text-slate-950 sm:text-4xl dark:text-white">
                Five durable capabilities, visible through real artifacts.
              </h2>
              <p className="mt-4 text-base leading-7 text-slate-700 dark:text-slate-300">
                Every session is designed around capability growth. Learners leave with
                skills they can show, explain, improve, and use.
              </p>
            </div>
            <div className="mt-8 grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
              {capabilities.map((capability) => {
                const Icon = capability.icon;
                return (
                  <article key={capability.label} className={`rounded-md border p-4 shadow-sm ${capability.tone}`}>
                    <Icon className="h-6 w-6" aria-hidden="true" />
                    <h3 className="mt-4 text-base font-bold">{capability.label}</h3>
                    <p className="mt-2 text-sm leading-6">{capability.detail}</p>
                  </article>
                );
              })}
            </div>
          </div>
        </section>

        <section className="border-b border-app bg-slate-950 px-4 py-14 text-white sm:px-6 lg:px-8">
          <div className="mx-auto max-w-7xl">
            <div className="max-w-3xl">
              <p className="text-sm font-bold uppercase text-cyan-200">Session by session</p>
              <h2 className="mt-3 text-3xl font-bold sm:text-4xl">
                Two weeks. Ten sessions. Every day builds on the last.
              </h2>
              <p className="mt-4 text-base leading-7 text-slate-300">
                Each session follows the Scholesa rhythm: hook, build, checkpoint,
                reflect. Learners always know what they are making and why.
              </p>
            </div>

            <div className="mt-8 grid gap-5 lg:grid-cols-2">
              {weeks.map((week) => (
                <section key={week.title} className={`overflow-hidden rounded-md border ${week.tone}`}>
                  <div className={`p-5 ${week.headerTone}`}>
                    <p className="text-xs font-bold uppercase tracking-wide opacity-85">{week.label}</p>
                    <h3 className="mt-2 text-2xl font-bold">{week.title}</h3>
                    <p className="mt-1 text-sm opacity-85">{week.date} · Half-day sessions</p>
                  </div>
                  <div className="divide-y divide-slate-200 bg-white dark:divide-slate-800 dark:bg-slate-950">
                    {week.sessions.map((session) => (
                      <div
                        key={`${week.title}-${session.day}`}
                        className={session.showcase ? 'grid grid-cols-[4.5rem_1fr] bg-amber-50 dark:bg-amber-950/20' : 'grid grid-cols-[4.5rem_1fr]'}
                      >
                        <div className="border-r border-slate-200 p-4 text-xs font-bold uppercase text-slate-500 dark:border-slate-800 dark:text-slate-400">
                          {session.day}
                        </div>
                        <div className="p-4">
                          <h4 className="text-sm font-bold text-slate-950 dark:text-white">{session.name}</h4>
                          <p className="mt-1 text-sm leading-6 text-slate-600 dark:text-slate-300">{session.theme}</p>
                          <div className="mt-3 flex flex-wrap gap-2">
                            {session.tags.map((tag) => (
                              <span
                                key={tag}
                                className="rounded-md border border-slate-200 bg-slate-50 px-2 py-1 text-xs font-bold text-slate-700 dark:border-slate-700 dark:bg-slate-900 dark:text-slate-200"
                              >
                                {tag}
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

        <section className="border-b border-app bg-slate-50 px-4 py-14 sm:px-6 lg:px-8 dark:bg-slate-900">
          <div className="mx-auto max-w-7xl">
            <div className="grid gap-8 lg:grid-cols-[0.8fr_1.2fr] lg:items-start">
              <div>
                <p className="text-sm font-bold uppercase text-cyan-700 dark:text-cyan-300">A different kind of camp</p>
                <h2 className="mt-3 text-3xl font-bold text-slate-950 sm:text-4xl dark:text-white">
                  Built for evidence, confidence, and real-world creativity.
                </h2>
                <p className="mt-4 text-base leading-7 text-slate-700 dark:text-slate-300">
                  The camp experience stays playful, but the learning record is serious:
                  projects, reflections, feedback, and showcase moments can become evidence
                  learners are proud to revisit.
                </p>
              </div>
              <div className="grid gap-3 sm:grid-cols-2">
                {differentiators.map((item) => {
                  const Icon = item.icon;
                  return (
                    <article key={item.title} className="rounded-md border border-app bg-app-surface p-5 shadow-sm">
                      <Icon className="h-6 w-6 text-cyan-700 dark:text-cyan-300" aria-hidden="true" />
                      <h3 className="mt-4 text-lg font-bold text-slate-950 dark:text-white">{item.title}</h3>
                      <p className="mt-2 text-sm leading-6 text-slate-700 dark:text-slate-300">{item.detail}</p>
                    </article>
                  );
                })}
              </div>
            </div>
          </div>
        </section>

        <section className="bg-white px-4 py-12 sm:px-6 lg:px-8 dark:bg-slate-950">
          <div className="mx-auto grid max-w-7xl gap-6 rounded-md border border-cyan-200 bg-cyan-50 p-5 shadow-sm lg:grid-cols-[1fr_auto] lg:items-center dark:border-cyan-800 dark:bg-cyan-950/30">
            <div className="flex gap-3">
              <Map className="mt-1 h-5 w-5 shrink-0 text-cyan-700 dark:text-cyan-300" aria-hidden="true" />
              <div>
                <p className="text-sm font-bold uppercase text-cyan-700 dark:text-cyan-300">Limited spots available</p>
                <h2 className="mt-2 text-2xl font-bold text-slate-950 dark:text-white">
                  Small groups. Big impact. Register early.
                </h2>
                <p className="mt-2 max-w-3xl text-sm leading-6 text-slate-700 dark:text-slate-300">
                  Cohorts are intentionally small to protect the learning experience.
                  Reach out to hold your child&apos;s place for Scholesa Young Innovators Summer Camp 2026.
                </p>
              </div>
            </div>
            <div className="flex flex-col gap-3 sm:flex-row lg:flex-col">
              <a
                href="mailto:info@scholesa.com?subject=Scholesa%20Young%20Innovators%20Summer%20Camp%202026"
                className="min-touch-target inline-flex items-center justify-center gap-2 rounded-md bg-cyan-700 px-5 py-3 text-sm font-semibold text-white hover:bg-cyan-800 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-app-ring dark:bg-cyan-300 dark:text-slate-950 dark:hover:bg-cyan-200"
              >
                <Mail className="h-4 w-4" aria-hidden="true" />
                info@scholesa.com
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