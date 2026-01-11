'use client';

import Link from 'next/link';
import { useParams } from 'next/navigation';

export default function LandingPage() {
  const params = useParams();
  const locale = (params?.locale as string) || 'en';

  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-white p-4">
      <div className="text-center">
        <h1 className="text-4xl font-bold tracking-tight text-gray-900 sm:text-6xl">
          Scholesa
        </h1>
        <p className="mt-6 text-lg leading-8 text-gray-600">
          Future Skills Academy. Empowering learners, educators, and communities.
        </p>
        <div className="mt-10 flex items-center justify-center gap-x-6">
          <Link
            href={`/${locale}/login`}
            className="rounded-md bg-indigo-600 px-3.5 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
          >
            Log in
          </Link>
          <Link href={`/${locale}/register`} className="text-sm font-semibold leading-6 text-gray-900">
            Register <span aria-hidden="true">→</span>
          </Link>
        </div>
      </div>
    </div>
  );
}