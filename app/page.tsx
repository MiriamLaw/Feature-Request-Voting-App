import Link from 'next/link';

export default function HomePage() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center py-12 px-4 sm:px-6 lg:px-8">
      <div className="w-full max-w-md space-y-8">
        <div className="text-center">
          <h1 className="text-4xl font-bold tracking-tight">
            Welcome to Feature Voting
          </h1>
          <p className="mt-4 text-lg text-gray-600">
            Vote on features you'd like to see implemented
          </p>
        </div>

        <div className="flex gap-4 mt-8">
          <Link
            href="/login"
            className="flex-1 flex justify-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
          >
            Sign in
          </Link>
          <Link
            href="/register"
            className="flex-1 flex justify-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-indigo-600 ring-1 ring-inset ring-indigo-600 hover:bg-indigo-50 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
          >
            Register
          </Link>
        </div>
      </div>
    </div>
  );
}

