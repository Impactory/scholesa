'use client';

import { useState, useEffect } from 'react';
import { httpsCallable } from 'firebase/functions';
import { functions } from '@/src/firebase/client-init';
import { SubscriptionCard } from './SubscriptionCard';
import { Loader2, Package } from 'lucide-react';

interface Subscription {
  id: string;
  status: string;
  productId: string;
  priceId: string;
  currentPeriodEnd?: string;
  cancelAtPeriodEnd?: boolean;
  stripeSubscriptionId: string;
}

export function SubscriptionManager() {
  const [subscriptions, setSubscriptions] = useState<Subscription[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchSubscriptions = async () => {
    setLoading(true);
    setError(null);

    try {
      const getUserSubscriptions = httpsCallable(functions, 'getUserSubscriptions');
      const result = await getUserSubscriptions({});
      const data = result.data as { subscriptions: Subscription[] };
      setSubscriptions(data.subscriptions || []);
    } catch (err: any) {
      setError(err.message || 'Failed to load subscriptions');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchSubscriptions();
  }, []);

  if (loading) {
    return (
      <div className="flex items-center justify-center py-12">
        <Loader2 className="h-8 w-8 animate-spin text-indigo-600" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="rounded-lg bg-red-50 p-6 text-center">
        <p className="text-red-700">{error}</p>
        <button
          onClick={fetchSubscriptions}
          className="mt-4 text-sm font-medium text-red-600 hover:text-red-500"
        >
          Try again
        </button>
      </div>
    );
  }

  if (subscriptions.length === 0) {
    return (
      <div className="rounded-lg border-2 border-dashed border-gray-200 p-12 text-center">
        <Package className="mx-auto h-12 w-12 text-gray-400" />
        <h3 className="mt-4 text-lg font-medium text-gray-900">No active subscriptions</h3>
        <p className="mt-2 text-sm text-gray-500">
          You don&apos;t have any active subscriptions yet.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {subscriptions.map((subscription) => (
        <SubscriptionCard
          key={subscription.id}
          subscription={subscription}
          onUpdate={fetchSubscriptions}
        />
      ))}
    </div>
  );
}
