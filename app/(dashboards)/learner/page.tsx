import { Skeleton } from '@/components/ui/Skeleton';
import { Card } from '@/components/ui/Card';

export default function LearnerDashboard() {
  // Replace with actual data fetching
  const isLoading = true;

  return (
    <div className="min-h-screen bg-gray-100 p-8">
      <h1 className="text-4xl font-bold text-gray-900">Learner Dashboard</h1>
      <div className="mt-8 grid grid-cols-1 gap-8 md:grid-cols-2 lg:grid-cols-3">
        {isLoading ? (
          <>
            <Card>
              <Skeleton className="h-4 w-1/2" />
              <Skeleton className="mt-4 h-8 w-full" />
            </Card>
            <Card>
              <Skeleton className="h-4 w-1/2" />
              <Skeleton className="mt-4 h-8 w-full" />
            </Card>
            <Card>
              <Skeleton className="h-4 w-1/2" />
              <Skeleton className="mt-4 h-8 w-full" />
            </Card>
          </>
        ) : (
          // Replace with actual components
          <>
            <Card>
              <h2 className="text-xl font-semibold">Current Mission</h2>
              <p className="mt-2">Introduction to Python</p>
            </Card>
            <Card>
              <h2 className="text-xl font-semibold">XP</h2>
              <p className="mt-2">1,250</p>
            </Card>
            <Card>
              <h2 className="text-xl font-semibold">AI Coach</h2>
              <p className="mt-2">Ready to help!</p>
            </Card>
          </>
        )}
      </div>
    </div>
  );
}
