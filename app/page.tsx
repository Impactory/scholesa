import Link from 'next/link';

export default function HomePage() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center bg-gray-50">
      <div className="text-center">
        <h1 className="text-5xl font-bold text-gray-900">
          Scholesa – Future Skills Academy
        </h1>
        <p className="mt-4 text-lg text-gray-600">
          The future of learning starts here.
        </p>
        <div className="mt-8 space-x-4">
          <Link href="/login" className="rounded-md bg-blue-600 px-6 py-3 text-lg font-semibold text-white shadow-sm hover:bg-blue-700">
            Login
          </Link>
          <Link href="/register" className="rounded-md bg-white px-6 py-3 text-lg font-semibold text-blue-600 shadow-sm ring-1 ring-inset ring-blue-600 hover:bg-blue-50">
            Register
          </Link>
        </div>
      </div>
    </main>
  );
}
