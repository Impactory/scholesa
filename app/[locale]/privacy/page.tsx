import type { Metadata } from 'next';
import Link from 'next/link';

export const metadata: Metadata = {
  title: 'Privacy Policy | Scholesa',
  description: 'Privacy commitments for Scholesa web and mobile learning experiences.',
};

export default async function PrivacyPolicyPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;

  return (
    <main className="min-h-screen bg-app-canvas px-4 py-10 text-app-foreground sm:px-6 lg:px-8">
      <article className="mx-auto max-w-4xl">
        <Link
          href={`/${locale}`}
          className="inline-flex min-touch-target items-center rounded-md border border-app bg-app-surface px-4 py-2 text-sm font-semibold text-app-foreground hover:bg-app-surface-muted focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-app-ring"
        >
          Scholesa
        </Link>

        <header className="mt-8 border-b border-app pb-6">
          <p className="text-sm font-bold uppercase text-cyan-700 dark:text-cyan-300">
            Privacy Policy
          </p>
          <h1 className="mt-3 text-3xl font-bold text-slate-950 sm:text-4xl dark:text-white">
            Scholesa Privacy Policy
          </h1>
          <p className="mt-4 text-sm leading-6 text-slate-600 dark:text-slate-300">
            Last updated: May 13, 2026
          </p>
        </header>

        <div className="prose prose-slate mt-8 max-w-none dark:prose-invert prose-a:text-cyan-700 dark:prose-a:text-cyan-300">
          <p>
            Scholesa is a capability-first evidence platform for schools and learning
            studios. This policy explains how Scholesa handles information in the web
            app and mobile app, including classroom evidence, learner reflections, and
            optional voice input used by the AI coach experience.
          </p>

          <h2>Information Scholesa Processes</h2>
          <p>
            Scholesa may process account profile information, school and site membership,
            session participation, learner artifacts, reflections, educator observations,
            proof-of-learning records, rubric judgments, capability growth records,
            portfolio outputs, support messages, device and diagnostic data, and audit
            records needed to keep evidence trustworthy.
          </p>

          <h2>Voice And Microphone Use</h2>
          <p>
            The mobile app may request microphone access when a learner or educator uses
            voice input in the AI coach or related learning workflow. Audio is used to
            turn speech into text for the requested learning action. Scholesa does not
            use microphone access in the background. Users can deny or revoke microphone
            permission in device settings and continue using typed input.
          </p>

          <h2>How Information Is Used</h2>
          <p>
            Information is used to run learning sessions, capture and verify evidence,
            support educator feedback, update capability growth over time, communicate
            progress to authorized users, maintain safety and reliability, and meet school
            operational and compliance requirements.
          </p>

          <h2>AI Assistance And Authenticity</h2>
          <p>
            Where AI assistance is available, Scholesa treats AI as support rather than a
            substitute for learner understanding. The platform may keep records of AI-use
            disclosures, prompts, responses, learner changes, verification intent, and
            proof-of-learning so educators can evaluate authenticity.
          </p>

          <h2>Sharing And Access</h2>
          <p>
            Access is role-based. Learners, educators, guardians, school leaders, partners,
            and platform operators can only access information appropriate to their role,
            site, and permissions. Scholesa does not sell learner personal information.
          </p>

          <h2>Storage, Security, And Retention</h2>
          <p>
            Scholesa uses tenant-scoped persistence, security rules, audit trails, and
            operational controls to protect evidence and account data. Schools and platform
            administrators determine retention and deletion requirements according to their
            agreements, legal obligations, and learning records policies.
          </p>

          <h2>Contact</h2>
          <p>
            For privacy questions or school data requests, contact the Scholesa operator or
            the school organization responsible for the learner account.
          </p>
        </div>
      </article>
    </main>
  );
}