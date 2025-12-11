import Link from 'next/link';
import { Button } from '@/src/components/ui/Button';

type HomePageProps = {
  params: { locale: string };
  searchParams: { [key: string]: string | string[] | undefined };
};

export default function Home({ params }: HomePageProps) {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center bg-gray-50 p-4">
      <div className="text-center max-w-2xl">
        <h1 className="text-4xl font-bold tracking-tight text-gray-900 sm:text-6xl mb-6">
          Scholesa – Future Skills Academy
        </h1>
        <p className="text-lg leading-8 text-gray-600 mb-10">
          The operating system for K–9 learning studios and schools.
        </p>
        
        <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
          <Link href={`/${params.locale}/login`}>
            <Button className="w-full sm:w-auto">Login as Learner</Button>
          </Link>
          <Link href={`/${params.locale}/login`}>
            <Button className="w-full sm:w-auto" variant="outline">Login as Educator</Button>
          </Link>
          <Link href={`/${params.locale}/login`}>
            <Button className="w-full sm:w-auto" variant="secondary">Login as Parent</Button>
          </Link>
          <Link href={`/${params.locale}/login`}>
            <Button className="w-full sm:w-auto" variant="ghost">Login as Admin</Button>
          </Link>
        </div>
        
        <div className="mt-10">
           <Link href={`/${params.locale}/register`} className="text-sm font-semibold leading-6 text-indigo-600 hover:text-indigo-500">
            Don&apos;t have an account? Register <span aria-hidden="true">→</span>
          </Link>
        </div>
      </div>
    </main>
  );
}
