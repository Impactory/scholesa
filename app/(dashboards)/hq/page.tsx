import { Skeleton } from '@/components/ui/Skeleton';
import { Card } from '@/components/ui/Card';

export default function HqDashboard() {
  // Replace with actual data fetching
  const isLoading = true;

  return (
    <div className="min-h-screen bg-gray-100 p-8">
      <h1 className="text-4xl font-bold text-gray-900">HQ Dashboard</h1>
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
              <h2 className="text-xl font-semibold">Studios</h2>
              <p className="mt-2">5 active</p>
            </Card>
            <Card>
              <h2 className="text-xl font-semibold">Enrollment</h2>
              <p className="mt-2">120 learners</p>
            </Card>
            <Card>
              <h2 className="text-xl font-semibold">Alerts</h2>
              <p className="mt-2">No new alerts</p>
            </Card>
          </>
        )}
      </div>
    </div>
  );
}
