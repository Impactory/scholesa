'use client';

import Link from 'next/link';
import { Button } from '@/src/components/ui/Button';

export default function Error() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center bg-gray-50 p-4">
      <div className="text-center max-w-2xl">
        <h1 className="text-4xl font-bold tracking-tight text-gray-900 sm:text-6xl mb-6">
          404 - Page Not Found
        </h1>
        <p className="text-lg leading-8 text-gray-600 mb-10">
          The page you are looking for does not exist.
        </p>
        
        <div className="flex items-center justify-center gap-4">
          <Link href="/">
            <Button>Go to Homepage</Button>
          </Link>
        </div>
      </div>
    </main>
  );
}
