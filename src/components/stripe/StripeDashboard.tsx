'use client';

import { useState, useEffect } from 'react';
import { httpsCallable } from 'firebase/functions';
import { functions } from '../../firebase/client-init';
import { useInteractionTracking } from '@/src/hooks/useTelemetry';
import { 
  DollarSign, 
  Users, 
  TrendingUp, 
  Clock,
  RefreshCw,
  AlertTriangle,
  CheckCircle2,
  XCircle
} from 'lucide-react';

interface StripeMetrics {
  totalSubscriptions: number;
  activeSubscriptions: number;
  trialingSubscriptions: number;
  canceledSubscriptions: number;
  pendingCancellations: number;
  byProduct: Record<string, number>;
  last30DaysRevenue: number;
  last30DaysRevenueFormatted: string;
}

export function StripeDashboard() {
  const [metrics, setMetrics] = useState<StripeMetrics | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshing, setRefreshing] = useState(false);
  const trackInteraction = useInteractionTracking();

  const fetchMetrics = async () => {
    trackInteraction('help_accessed', { cta: 'stripe_dashboard_refresh' });
    try {
      setRefreshing(true);
      const getStripeMetrics = httpsCallable<void, StripeMetrics>(functions, 'getStripeMetrics');
      const result = await getStripeMetrics();
      setMetrics(result.data);
      setError(null);
    } catch (err: unknown) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to fetch metrics';
      setError(errorMessage);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  useEffect(() => {
    fetchMetrics();
  }, []);

  if (loading) {
    return (
      <div className="bg-white rounded-lg shadow-md p-6">
        <div className="animate-pulse space-y-6">
          <div className="h-8 bg-gray-200 rounded w-1/4"></div>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {[1, 2, 3, 4].map((i) => (
              <div key={i} className="h-24 bg-gray-100 rounded-lg"></div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="bg-white rounded-lg shadow-md p-6">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-indigo-100 rounded-lg">
              <DollarSign className="w-6 h-6 text-indigo-600" />
            </div>
            <div>
              <h2 className="text-xl font-semibold text-gray-900">Stripe Dashboard</h2>
              <p className="text-sm text-gray-500">Subscription & revenue metrics</p>
            </div>
          </div>
          <button
            onClick={fetchMetrics}
            disabled={refreshing}
            className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-indigo-600 rounded-lg hover:bg-indigo-700 disabled:opacity-50 transition-colors"
          >
            <RefreshCw className={`w-4 h-4 ${refreshing ? 'animate-spin' : ''}`} />
            Refresh
          </button>
        </div>

        {error && (
          <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg">
            <div className="flex items-center gap-2 text-red-700">
              <AlertTriangle className="w-5 h-5" />
              <span>{error}</span>
            </div>
          </div>
        )}

        {metrics && (
          <>
            {/* Revenue Card */}
            <div className="mb-6 p-6 bg-gradient-to-r from-green-500 to-emerald-600 rounded-xl text-white">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-green-100 text-sm font-medium">Last 30 Days Revenue</p>
                  <p className="text-3xl font-bold mt-1">{metrics.last30DaysRevenueFormatted}</p>
                </div>
                <TrendingUp className="w-12 h-12 text-green-200" />
              </div>
            </div>

            {/* Subscription Stats Grid */}
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              <StatCard
                icon={<Users className="w-5 h-5 text-blue-600" />}
                label="Total Subscriptions"
                value={metrics.totalSubscriptions}
                bgColor="bg-blue-50"
              />
              <StatCard
                icon={<CheckCircle2 className="w-5 h-5 text-green-600" />}
                label="Active"
                value={metrics.activeSubscriptions}
                bgColor="bg-green-50"
              />
              <StatCard
                icon={<Clock className="w-5 h-5 text-yellow-600" />}
                label="Trialing"
                value={metrics.trialingSubscriptions}
                bgColor="bg-yellow-50"
              />
              <StatCard
                icon={<XCircle className="w-5 h-5 text-red-600" />}
                label="Canceled"
                value={metrics.canceledSubscriptions}
                bgColor="bg-red-50"
              />
            </div>

            {/* Pending Cancellations Warning */}
            {metrics.pendingCancellations > 0 && (
              <div className="mt-4 p-4 bg-amber-50 border border-amber-200 rounded-lg">
                <div className="flex items-center gap-2 text-amber-700">
                  <AlertTriangle className="w-5 h-5" />
                  <span className="font-medium">
                    {metrics.pendingCancellations} subscription{metrics.pendingCancellations > 1 ? 's' : ''} pending cancellation
                  </span>
                </div>
              </div>
            )}

            {/* By Product Breakdown */}
            {Object.keys(metrics.byProduct).length > 0 && (
              <div className="mt-6">
                <h3 className="text-sm font-medium text-gray-700 mb-3">Subscriptions by Product</h3>
                <div className="space-y-2">
                  {Object.entries(metrics.byProduct).map(([product, count]) => (
                    <div key={product} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                      <span className="text-sm font-medium text-gray-700 capitalize">
                        {product.replace(/_/g, ' ')}
                      </span>
                      <span className="text-sm font-bold text-gray-900">{count}</span>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}

interface StatCardProps {
  icon: React.ReactNode;
  label: string;
  value: number;
  bgColor: string;
}

function StatCard({ icon, label, value, bgColor }: StatCardProps) {
  return (
    <div className={`${bgColor} rounded-lg p-4`}>
      <div className="flex items-center gap-2 mb-2">
        {icon}
        <span className="text-xs font-medium text-gray-600">{label}</span>
      </div>
      <p className="text-2xl font-bold text-gray-900">{value}</p>
    </div>
  );
}
