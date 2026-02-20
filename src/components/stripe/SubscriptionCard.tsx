'use client';

import { useState } from 'react';
import { httpsCallable } from 'firebase/functions';
import { functions } from '@/src/firebase/client-init';
import { CreditCard, Calendar, AlertCircle, CheckCircle, XCircle, Loader2 } from 'lucide-react';
import { useInteractionTracking } from '@/src/hooks/useTelemetry';

interface Subscription {
  id: string;
  status: string;
  productId: string;
  priceId: string;
  currentPeriodEnd?: string;
  cancelAtPeriodEnd?: boolean;
  stripeSubscriptionId: string;
}

interface SubscriptionCardProps {
  subscription: Subscription;
  onUpdate?: () => void;
}

const statusConfig: Record<string, { color: string; icon: typeof CheckCircle; label: string }> = {
  active: { color: 'text-green-600 bg-green-50', icon: CheckCircle, label: 'Active' },
  trialing: { color: 'text-blue-600 bg-blue-50', icon: Calendar, label: 'Trial' },
  past_due: { color: 'text-yellow-600 bg-yellow-50', icon: AlertCircle, label: 'Past Due' },
  canceled: { color: 'text-red-600 bg-red-50', icon: XCircle, label: 'Canceled' },
  unpaid: { color: 'text-red-600 bg-red-50', icon: AlertCircle, label: 'Unpaid' },
};

export function SubscriptionCard({ subscription, onUpdate }: SubscriptionCardProps) {
  const [loading, setLoading] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const trackInteraction = useInteractionTracking();

  const status = statusConfig[subscription.status] || statusConfig.active;
  const StatusIcon = status.icon;

  const handleCancel = async () => {
    trackInteraction('help_accessed', { cta: 'subscription_cancel', subscriptionId: subscription.id });
    if (!confirm('Are you sure you want to cancel this subscription? It will remain active until the end of the billing period.')) {
      return;
    }

    setLoading('cancel');
    setError(null);

    try {
      const cancelSubscription = httpsCallable(functions, 'cancelSubscription');
      await cancelSubscription({
        subscriptionId: subscription.id,
        cancelAtPeriodEnd: true,
      });
      onUpdate?.();
    } catch (err: any) {
      setError(err.message || 'Failed to cancel subscription');
    } finally {
      setLoading(null);
    }
  };

  const handleResume = async () => {
    trackInteraction('feature_discovered', { cta: 'subscription_resume', subscriptionId: subscription.id });
    setLoading('resume');
    setError(null);

    try {
      const resumeSubscription = httpsCallable(functions, 'resumeSubscription');
      await resumeSubscription({ subscriptionId: subscription.id });
      onUpdate?.();
    } catch (err: any) {
      setError(err.message || 'Failed to resume subscription');
    } finally {
      setLoading(null);
    }
  };

  const handleManageBilling = async () => {
    trackInteraction('feature_discovered', { cta: 'subscription_manage_billing', subscriptionId: subscription.id });
    setLoading('portal');
    setError(null);

    try {
      const createPortalSession = httpsCallable(functions, 'createStripePortalSession');
      const result = await createPortalSession({});
      const { url } = result.data as { url: string };
      window.location.href = url;
    } catch (err: any) {
      setError(err.message || 'Failed to open billing portal');
      setLoading(null);
    }
  };

  const formatDate = (dateString?: string) => {
    if (!dateString) return 'N/A';
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    });
  };

  return (
    <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
      <div className="flex items-start justify-between">
        <div className="flex items-center gap-3">
          <div className="rounded-full bg-indigo-100 p-2">
            <CreditCard className="h-5 w-5 text-indigo-600" />
          </div>
          <div>
            <h3 className="font-semibold text-gray-900">
              {subscription.productId.replace(/-/g, ' ').replace(/\b\w/g, l => l.toUpperCase())}
            </h3>
            <p className="text-sm text-gray-500">
              {subscription.cancelAtPeriodEnd ? 'Cancels' : 'Renews'} on {formatDate(subscription.currentPeriodEnd)}
            </p>
          </div>
        </div>

        <span className={`inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-sm font-medium ${status.color}`}>
          <StatusIcon className="h-4 w-4" />
          {status.label}
          {subscription.cancelAtPeriodEnd && subscription.status === 'active' && ' (Canceling)'}
        </span>
      </div>

      {error && (
        <div className="mt-4 rounded-md bg-red-50 p-3 text-sm text-red-700">
          {error}
        </div>
      )}

      <div className="mt-6 flex flex-wrap gap-3">
        <button
          onClick={handleManageBilling}
          disabled={loading !== null}
          className="inline-flex items-center gap-2 rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700 disabled:opacity-50"
        >
          {loading === 'portal' && <Loader2 className="h-4 w-4 animate-spin" />}
          Manage Billing
        </button>

        {subscription.status === 'active' && !subscription.cancelAtPeriodEnd && (
          <button
            onClick={handleCancel}
            disabled={loading !== null}
            className="inline-flex items-center gap-2 rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-50"
          >
            {loading === 'cancel' && <Loader2 className="h-4 w-4 animate-spin" />}
            Cancel Subscription
          </button>
        )}

        {subscription.cancelAtPeriodEnd && subscription.status === 'active' && (
          <button
            onClick={handleResume}
            disabled={loading !== null}
            className="inline-flex items-center gap-2 rounded-md border border-green-300 bg-green-50 px-4 py-2 text-sm font-medium text-green-700 hover:bg-green-100 disabled:opacity-50"
          >
            {loading === 'resume' && <Loader2 className="h-4 w-4 animate-spin" />}
            Resume Subscription
          </button>
        )}
      </div>
    </div>
  );
}
