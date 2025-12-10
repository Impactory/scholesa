import { Skeleton } from '@/components/ui/Skeleton';
import { Card } from '@/components/ui/Card';

export default function EducatorDashboard() {
  // Replace with actual data fetching
  const isLoading = true;

  return (
    <div className="min-h-screen bg-gray-100 p-8">
      <h1 className="text-4xl font-bold text-gray-900">Educator Dashboard</h1>
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
              <h2 className="text-xl font-semibold">Today's Classes</h2>
              <p className="mt-2">Robotics, Coding</p>
            </Card>
            <Card>
              <h2 className="text-xl font-semibold">Attendance</h2>
              <p className="mt-2">18/20</p>
            </Card>
            <Card>
              <h2 className="text-xl font-semibold">Submissions</h2>
              <p className="mt-2">5 new</p>
            </Card>
          </>
        )}
      </div>
    </div>
  );
}
