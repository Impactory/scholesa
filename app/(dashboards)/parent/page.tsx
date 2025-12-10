import { Skeleton } from '@/components/ui/Skeleton';
import { Card } from '@/components/ui/Card';

export default function ParentDashboard() {
  // Replace with actual data fetching
  const isLoading = true;

  return (
    <div className="min-h-screen bg-gray-100 p-8">
      <h1 className="text-4xl font-bold text-gray-900">Parent Dashboard</h1>
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
              <h2 className="text-xl font-semibold">Learner Progress</h2>
              <p className="mt-2">On track</p>
            </Card>
            <Card>
              <h2 className="text-xl font-semibold">Strengths</h2>
              <p className="mt-2">Creativity</p>
            </Card>
            <Card>
              <h2 className="text-xl font-semibold">Notifications</h2>
              <p className="mt-2">Upcoming event</p>
            </Card>
          </>
        )}
      </div>
    </div>
  );
}
