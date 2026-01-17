import { Metadata } from 'next';
import { AnalyticsDashboard } from '@/src/components/analytics/AnalyticsDashboard';

export const metadata: Metadata = {
  title: 'Analytics Dashboard | Scholesa',
  description: 'Student engagement and motivation analytics for educators'
};

export default function AnalyticsPage() {
  return (
    <div className="container mx-auto px-4 py-8">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-900">Analytics Dashboard</h1>
        <p className="mt-2 text-gray-600">Track student engagement, SDT metrics, and learning progress</p>
      </div>
      
      <AnalyticsDashboard />
    </div>
  );
}
