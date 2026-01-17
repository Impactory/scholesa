/**
 * Stripe Client-Side Utilities
 * 
 * This module provides utilities for integrating Stripe on the client side.
 * It handles loading the Stripe.js library and provides helper functions
 * for common payment operations.
 */

import { loadStripe, Stripe } from '@stripe/stripe-js';
import { getFunctions, httpsCallable } from 'firebase/functions';
import { getApp } from 'firebase/app';

// Lazy-loaded Stripe promise
let stripePromise: Promise<Stripe | null> | null = null;

/**
 * Get the Stripe.js instance (lazy loaded)
 */
export function getStripeJs(): Promise<Stripe | null> {
  if (!stripePromise) {
    const publishableKey = process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY;
    if (!publishableKey) {
      console.warn('Stripe publishable key not configured');
      return Promise.resolve(null);
    }
    stripePromise = loadStripe(publishableKey);
  }
  return stripePromise!;
}

/**
 * Create a checkout session for a one-time purchase
 */
export async function createCheckoutSession(options: {
  siteId: string;
  userId: string;
  productId: string;
  successUrl: string;
  cancelUrl: string;
}): Promise<{ sessionId: string; sessionUrl: string } | null> {
  try {
    const functions = getFunctions(getApp());
    const createSession = httpsCallable(functions, 'createStripeCheckoutSession');
    const result = await createSession(options);
    return result.data as { sessionId: string; sessionUrl: string };
  } catch (error) {
    console.error('Failed to create checkout session:', error);
    throw error;
  }
}

/**
 * Create a subscription checkout session
 */
export async function createSubscriptionSession(options: {
  siteId: string;
  productId: string;
  successUrl: string;
  cancelUrl: string;
}): Promise<{ sessionId: string; sessionUrl: string; subscriptionId: string } | null> {
  try {
    const functions = getFunctions(getApp());
    const createSession = httpsCallable(functions, 'createStripeSubscription');
    const result = await createSession(options);
    return result.data as { sessionId: string; sessionUrl: string; subscriptionId: string };
  } catch (error) {
    console.error('Failed to create subscription session:', error);
    throw error;
  }
}

/**
 * Redirect to Stripe Checkout
 * @deprecated Use the session URL directly from createCheckoutSession/createSubscriptionSession
 */
export async function redirectToCheckout(sessionId: string): Promise<void> {
  const stripe = await getStripeJs();
  if (!stripe) {
    throw new Error('Stripe not loaded');
  }
  
  // The new Stripe.js API requires using the session URL directly
  // This is kept for backward compatibility
  const result = await (stripe as any).redirectToCheckout({ sessionId });
  if (result?.error) {
    throw result.error;
  }
}

/**
 * Open Stripe Customer Portal
 */
export async function openCustomerPortal(returnUrl: string): Promise<void> {
  try {
    const functions = getFunctions(getApp());
    const createPortalSession = httpsCallable(functions, 'createStripePortalSession');
    const result = await createPortalSession({ returnUrl });
    const data = result.data as { url: string };
    
    if (data.url) {
      window.location.href = data.url;
    }
  } catch (error) {
    console.error('Failed to open customer portal:', error);
    throw error;
  }
}

/**
 * Cancel a subscription
 */
export async function cancelSubscription(
  subscriptionId: string,
  cancelAtPeriodEnd = true
): Promise<{ success: boolean; cancelAtPeriodEnd: boolean }> {
  try {
    const functions = getFunctions(getApp());
    const cancel = httpsCallable(functions, 'cancelSubscription');
    const result = await cancel({ subscriptionId, cancelAtPeriodEnd });
    return result.data as { success: boolean; cancelAtPeriodEnd: boolean };
  } catch (error) {
    console.error('Failed to cancel subscription:', error);
    throw error;
  }
}

/**
 * Resume a subscription that was scheduled for cancellation
 */
export async function resumeSubscription(
  subscriptionId: string
): Promise<{ success: boolean }> {
  try {
    const functions = getFunctions(getApp());
    const resume = httpsCallable(functions, 'resumeSubscription');
    const result = await resume({ subscriptionId });
    return result.data as { success: boolean };
  } catch (error) {
    console.error('Failed to resume subscription:', error);
    throw error;
  }
}

/**
 * Get user's subscriptions
 */
export async function getUserSubscriptions(userId?: string): Promise<{
  subscriptions: Array<{
    id: string;
    productId: string;
    status: string;
    currentPeriodEnd?: string;
    cancelAtPeriodEnd?: boolean;
  }>;
}> {
  try {
    const functions = getFunctions(getApp());
    const getSubs = httpsCallable(functions, 'getUserSubscriptions');
    const result = await getSubs({ userId });
    return result.data as { subscriptions: any[] };
  } catch (error) {
    console.error('Failed to get subscriptions:', error);
    throw error;
  }
}

/**
 * Get user's entitlements
 */
export async function getUserEntitlements(userId?: string): Promise<{
  entitlements: Array<{
    id: string;
    productId: string;
    isActive: boolean;
    expiresAt?: string;
  }>;
}> {
  try {
    const functions = getFunctions(getApp());
    const getEnts = httpsCallable(functions, 'getUserEntitlements');
    const result = await getEnts({ userId });
    return result.data as { entitlements: any[] };
  } catch (error) {
    console.error('Failed to get entitlements:', error);
    throw error;
  }
}

/**
 * Get invoice history
 */
export async function getInvoiceHistory(userId?: string): Promise<{
  invoices: Array<{
    id: string;
    number: string;
    status: string;
    amount: number;
    currency: string;
    created: string;
    hostedInvoiceUrl: string;
    invoicePdf: string;
  }>;
}> {
  try {
    const functions = getFunctions(getApp());
    const getInvoices = httpsCallable(functions, 'getInvoiceHistory');
    const result = await getInvoices({ userId });
    return result.data as { invoices: any[] };
  } catch (error) {
    console.error('Failed to get invoice history:', error);
    throw error;
  }
}

/**
 * Retry a failed invoice payment
 */
export async function retryInvoicePayment(invoiceId: string): Promise<{
  success: boolean;
  status: string;
  amountPaid: number;
}> {
  try {
    const functions = getFunctions(getApp());
    const retry = httpsCallable(functions, 'retryInvoicePayment');
    const result = await retry({ invoiceId });
    return result.data as { success: boolean; status: string; amountPaid: number };
  } catch (error) {
    console.error('Failed to retry payment:', error);
    throw error;
  }
}

// ==================== HQ Admin Functions ====================

/**
 * Get Stripe metrics (HQ only)
 */
export async function getStripeMetrics(): Promise<{
  totalSubscriptions: number;
  activeSubscriptions: number;
  trialingSubscriptions: number;
  canceledSubscriptions: number;
  pendingCancellations: number;
  byProduct: Record<string, number>;
  last30DaysRevenue: number;
  last30DaysRevenueFormatted: string;
}> {
  try {
    const functions = getFunctions(getApp());
    const getMetrics = httpsCallable(functions, 'getStripeMetrics');
    const result = await getMetrics({});
    return result.data as any;
  } catch (error) {
    console.error('Failed to get Stripe metrics:', error);
    throw error;
  }
}

/**
 * Get webhook logs (HQ only)
 */
export async function getWebhookLogs(options?: {
  limit?: number;
  status?: string;
  eventType?: string;
}): Promise<{ logs: Array<any> }> {
  try {
    const functions = getFunctions(getApp());
    const getLogs = httpsCallable(functions, 'getWebhookLogs');
    const result = await getLogs(options || {});
    return result.data as { logs: any[] };
  } catch (error) {
    console.error('Failed to get webhook logs:', error);
    throw error;
  }
}

/**
 * Process a refund (HQ only)
 */
export async function processRefund(options: {
  paymentIntentId: string;
  amount?: number;
  reason?: string;
}): Promise<{
  success: boolean;
  refundId: string;
  status: string;
  amount: number;
}> {
  try {
    const functions = getFunctions(getApp());
    const refund = httpsCallable(functions, 'processRefund');
    const result = await refund(options);
    return result.data as any;
  } catch (error) {
    console.error('Failed to process refund:', error);
    throw error;
  }
}

/**
 * Get all Stripe products (HQ only)
 */
export async function getStripeProducts(): Promise<{
  products: Array<{
    id: string;
    name: string;
    description: string;
    active: boolean;
    prices: Array<{
      id: string;
      active: boolean;
      currency: string;
      unitAmount: number;
      unitAmountFormatted: string;
      recurring?: {
        interval: string;
        intervalCount: number;
      };
    }>;
  }>;
}> {
  try {
    const functions = getFunctions(getApp());
    const getProducts = httpsCallable(functions, 'getStripeProducts');
    const result = await getProducts({});
    return result.data as any;
  } catch (error) {
    console.error('Failed to get Stripe products:', error);
    throw error;
  }
}

/**
 * Create a Stripe product (HQ only)
 */
export async function createStripeProduct(options: {
  name: string;
  description?: string;
  metadata?: Record<string, string>;
}): Promise<{
  success: boolean;
  product: {
    id: string;
    name: string;
    description: string;
    active: boolean;
  };
}> {
  try {
    const functions = getFunctions(getApp());
    const create = httpsCallable(functions, 'createStripeProduct');
    const result = await create(options);
    return result.data as any;
  } catch (error) {
    console.error('Failed to create product:', error);
    throw error;
  }
}

/**
 * Update a Stripe product (HQ only)
 */
export async function updateStripeProduct(options: {
  productId: string;
  name?: string;
  description?: string;
  active?: boolean;
  metadata?: Record<string, string>;
}): Promise<{
  success: boolean;
  product: {
    id: string;
    name: string;
    description: string;
    active: boolean;
  };
}> {
  try {
    const functions = getFunctions(getApp());
    const update = httpsCallable(functions, 'updateStripeProduct');
    const result = await update(options);
    return result.data as any;
  } catch (error) {
    console.error('Failed to update product:', error);
    throw error;
  }
}

/**
 * Create a price for a product (HQ only)
 */
export async function createStripePrice(options: {
  productId: string;
  unitAmount: number;
  currency?: string;
  recurring?: {
    interval: 'day' | 'week' | 'month' | 'year';
    intervalCount?: number;
  };
  nickname?: string;
  metadata?: Record<string, string>;
}): Promise<{
  success: boolean;
  price: {
    id: string;
    active: boolean;
    unitAmount: number;
    currency: string;
    recurring?: any;
    nickname: string;
  };
}> {
  try {
    const functions = getFunctions(getApp());
    const create = httpsCallable(functions, 'createStripePrice');
    const result = await create(options);
    return result.data as any;
  } catch (error) {
    console.error('Failed to create price:', error);
    throw error;
  }
}

/**
 * Update a price (HQ only)
 */
export async function updateStripePrice(options: {
  priceId: string;
  active?: boolean;
  nickname?: string;
  metadata?: Record<string, string>;
}): Promise<{
  success: boolean;
  price: {
    id: string;
    active: boolean;
    unitAmount: number;
    currency: string;
    nickname: string;
  };
}> {
  try {
    const functions = getFunctions(getApp());
    const update = httpsCallable(functions, 'updateStripePrice');
    const result = await update(options);
    return result.data as any;
  } catch (error) {
    console.error('Failed to update price:', error);
    throw error;
  }
}

/**
 * Archive a product (HQ only)
 */
export async function archiveStripeProduct(productId: string): Promise<{
  success: boolean;
  product: {
    id: string;
    name: string;
    active: boolean;
  };
  pricesArchived: number;
}> {
  try {
    const functions = getFunctions(getApp());
    const archive = httpsCallable(functions, 'archiveStripeProduct');
    const result = await archive({ productId });
    return result.data as any;
  } catch (error) {
    console.error('Failed to archive product:', error);
    throw error;
  }
}
