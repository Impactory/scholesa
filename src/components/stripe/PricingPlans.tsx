'use client';

import { useState } from 'react';
import { httpsCallable } from 'firebase/functions';
import { functions } from '@/src/firebase/client-init';
import { Loader2, Sparkles, Check } from 'lucide-react';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { TelemetryService } from '@/src/lib/telemetry/telemetryService';
import type { UserRole } from '@/src/types/schema';

interface PricingPlan {
  id: string;
  name: string;
  description: string;
  price: number;
  currency: string;
  interval: 'month' | 'year';
  features: string[];
  popular?: boolean;
}

const plans: PricingPlan[] = [
  {
    id: 'learner-seat',
    name: 'Learner',
    description: 'Perfect for individual students',
    price: 29,
    currency: 'USD',
    interval: 'month',
    features: [
      'Access to all learning missions',
      'Personal progress dashboard',
      'AI coaching support',
      'Portfolio builder',
      'Certificate generation',
    ],
  },
  {
    id: 'educator-seat',
    name: 'Educator',
    description: 'For teachers and instructors',
    price: 49,
    currency: 'USD',
    interval: 'month',
    features: [
      'All Learner features',
      'Session management',
      'Attendance tracking',
      'Submission grading',
      'Analytics dashboard',
      'Parent communication',
    ],
    popular: true,
  },
  {
    id: 'site-license',
    name: 'Site License',
    description: 'For schools and learning studios',
    price: 299,
    currency: 'USD',
    interval: 'month',
    features: [
      'Unlimited educators',
      'Unlimited learners',
      'Custom branding',
      'Advanced analytics',
      'Priority support',
      'API access',
      'SSO integration',
    ],
  },
];

interface PricingCardProps {
  plan: PricingPlan;
  onSubscribe: (planId: string) => Promise<void>;
  loading: boolean;
}

function PricingCard({ plan, onSubscribe, loading }: PricingCardProps) {
  return (
    <div
      className={`relative rounded-2xl border ${
        plan.popular
          ? 'border-indigo-600 shadow-lg'
          : 'border-gray-200'
      } bg-white p-8`}
    >
      {plan.popular && (
        <div className="absolute -top-4 left-1/2 -translate-x-1/2">
          <span className="inline-flex items-center gap-1 rounded-full bg-indigo-600 px-4 py-1 text-sm font-medium text-white">
            <Sparkles className="h-4 w-4" />
            Most Popular
          </span>
        </div>
      )}

      <div className="text-center">
        <h3 className="text-lg font-semibold text-gray-900">{plan.name}</h3>
        <p className="mt-2 text-sm text-gray-500">{plan.description}</p>
        <div className="mt-6">
          <span className="text-4xl font-bold text-gray-900">${plan.price}</span>
          <span className="text-gray-500">/{plan.interval}</span>
        </div>
      </div>

      <ul className="mt-8 space-y-3">
        {plan.features.map((feature, index) => (
          <li key={index} className="flex items-start gap-3">
            <Check className="h-5 w-5 flex-shrink-0 text-green-500" />
            <span className="text-sm text-gray-600">{feature}</span>
          </li>
        ))}
      </ul>

      <button
        onClick={() => onSubscribe(plan.id)}
        disabled={loading}
        className={`mt-8 w-full rounded-lg py-3 text-sm font-semibold transition-colors disabled:opacity-50 ${
          plan.popular
            ? 'bg-indigo-600 text-white hover:bg-indigo-700'
            : 'bg-gray-100 text-gray-900 hover:bg-gray-200'
        }`}
      >
        {loading ? (
          <Loader2 className="mx-auto h-5 w-5 animate-spin" />
        ) : (
          'Get Started'
        )}
      </button>
    </div>
  );
}

export function PricingPlans() {
  const [loading, setLoading] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const { user, profile } = useAuthContext();

  const trackPricingCTA = async (metadata: Record<string, unknown>) => {
    if (!user || !profile) return;
    const siteId = profile.activeSiteId || profile.siteIds?.[0] || 'global';
    await TelemetryService.track({
      event: 'feature_discovered',
      category: 'navigation',
      userId: user.uid,
      userRole: profile.role as UserRole,
      siteId,
      metadata: {
        surface: 'pricing_plans',
        ...metadata,
      },
    });
  };

  const handleSubscribe = async (planId: string) => {
    setLoading(planId);
    setError(null);

    try {
      await trackPricingCTA({
        cta: 'pricing_get_started',
        planId,
      });
      const createCheckoutSession = httpsCallable(functions, 'createStripeCheckoutSession');
      const result = await createCheckoutSession({
        productId: planId,
        successUrl: `${window.location.origin}/en/dashboard?checkout=success`,
        cancelUrl: `${window.location.origin}/en/pricing?checkout=canceled`,
      });

      const { url } = result.data as { url: string };
      window.location.href = url;
    } catch (err: any) {
      setError(err.message || 'Failed to start checkout');
      setLoading(null);
    }
  };

  return (
    <div className="py-12">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="text-center">
          <h2 className="text-3xl font-bold tracking-tight text-gray-900 sm:text-4xl">
            Simple, transparent pricing
          </h2>
          <p className="mx-auto mt-4 max-w-2xl text-lg text-gray-500">
            Choose the plan that&apos;s right for you. All plans include a 14-day free trial.
          </p>
        </div>

        {error && (
          <div className="mx-auto mt-8 max-w-md rounded-lg bg-red-50 p-4 text-center text-red-700">
            {error}
          </div>
        )}

        <div className="mt-16 grid gap-8 lg:grid-cols-3">
          {plans.map((plan) => (
            <PricingCard
              key={plan.id}
              plan={plan}
              onSubscribe={handleSubscribe}
              loading={loading === plan.id}
            />
          ))}
        </div>

        <p className="mt-12 text-center text-sm text-gray-500">
          All prices in USD. Cancel anytime. Need a custom plan?{' '}
          <a
            href="mailto:support@scholesa.com"
            className="text-indigo-600 hover:text-indigo-500"
            onClick={() => {
              trackPricingCTA({ cta: 'pricing_contact_support' }).catch(() => undefined);
            }}
          >
            Contact us
          </a>
        </p>
      </div>
    </div>
  );
}
