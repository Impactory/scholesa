# Stripe Integration Setup Guide

This guide explains how to configure Stripe API keys and webhooks for the Scholesa platform.

## ✅ Current Status

| Component | Status |
|-----------|--------|
| Stripe SDK | v20.2.0 (API v2025-12-15.clover) |
| Secret Key | ✅ Configured in Firebase Secrets |
| Webhook Secret | ✅ Configured in Firebase Secrets |
| Health Check | ✅ Connected |
| Webhook URL | `https://stripewebhook-gu5vyrn2tq-uc.a.run.app` |

## Overview

Scholesa uses Stripe for:
- Subscription management (monthly billing)
- One-time payments (checkout sessions)
- Customer portal (self-service billing management)
- Webhook handling for real-time event processing
- Product and pricing management (admin dashboard)
- Refund processing

## Prerequisites

1. A Stripe account ([Create one here](https://dashboard.stripe.com/register))
2. Firebase project with Cloud Functions enabled
3. Access to Firebase Console and GCP Cloud Run

---

## Step 1: Get Your Stripe API Keys

### From Stripe Dashboard:

1. Go to [Stripe Dashboard](https://dashboard.stripe.com/)
2. Click **Developers** → **API keys**
3. Copy your keys:
   - **Publishable key** (starts with `pk_test_` or `pk_live_`)
   - **Secret key** (starts with `sk_test_` or `sk_live_`)

> ⚠️ **Important**: Use **test keys** for development and **live keys** for production. Never commit secret keys to version control.

---

## Step 2: Configure Firebase Functions Secrets

Firebase Functions use Google Cloud Secret Manager for sensitive keys.

### Set Stripe Secret Key:

```bash
# Set the secret (you'll be prompted to enter the value)
firebase functions:secrets:set STRIPE_SECRET_KEY

# Or set directly (not recommended for security)
firebase functions:secrets:set STRIPE_SECRET_KEY --data-file=- <<< "sk_live_your_secret_key"
```

### Verify secrets are set:

```bash
firebase functions:secrets:get STRIPE_SECRET_KEY
```

---

## Step 3: Configure Stripe Webhook

### Create Webhook Endpoint in Stripe Dashboard:

1. Go to [Stripe Dashboard → Developers → Webhooks](https://dashboard.stripe.com/webhooks)
2. Click **Add endpoint**
3. Enter the webhook URL:
   ```
   https://stripewebhook-gu5vyrn2tq-uc.a.run.app
   ```
4. Select events to listen for (see list below)
5. Click **Add endpoint**
6. Copy the **Signing secret** (starts with `whsec_`)

### Set Webhook Secret in Firebase:

```bash
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
# Enter: whsec_your_webhook_signing_secret
```

### Required Webhook Events:

Select these events in the Stripe webhook configuration:

**Checkout Events:**
- `checkout.session.completed`
- `checkout.session.expired`

**Subscription Events:**
- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.deleted`
- `customer.subscription.trial_will_end`
- `customer.subscription.pending_update_applied`
- `customer.subscription.pending_update_expired`
- `customer.subscription.paused`
- `customer.subscription.resumed`

**Invoice Events:**
- `invoice.paid`
- `invoice.payment_failed`
- `invoice.payment_action_required`
- `invoice.finalized`
- `invoice.upcoming`

**Payment Events:**
- `payment_intent.succeeded`
- `payment_intent.payment_failed`
- `payment_intent.canceled`

**Customer Events:**
- `customer.created`
- `customer.updated`
- `customer.deleted`

---

## Step 4: Set Environment Variables for Next.js

### Create/update `.env.production`:

```env
# Stripe (only publishable key needed client-side)
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_live_your_publishable_key
```

### For Cloud Run (optional - if calling Stripe directly from Next.js API routes):

```bash
gcloud run services update scholesa \
  --set-env-vars="STRIPE_SECRET_KEY=sk_live_your_secret_key" \
  --region=us-central1
```

> **Note**: For security, Stripe API calls should go through Firebase Functions, not directly from Next.js.

---

## Step 5: Create Stripe Products and Prices

### Via Stripe Dashboard:

1. Go to [Products](https://dashboard.stripe.com/products)
2. Click **Add product**
3. Create products for each plan:

| Product Name | Price | Billing |
|-------------|-------|---------|
| Learner Plan | $29/month | Recurring |
| Educator Plan | $49/month | Recurring |
| Site License | $299/month | Recurring |

4. Copy the **Price IDs** (e.g., `price_1ABC...`)

### Update PricingPlans Component:

Edit `src/components/stripe/PricingPlans.tsx` with your actual price IDs:

```typescript
const plans = [
  {
    name: 'Learner',
    priceId: 'price_YOUR_LEARNER_PRICE_ID', // Replace
    // ...
  },
  // ...
];
```

---

## Step 6: Deploy Updated Functions

After setting all secrets:

```bash
cd functions
npm run build
firebase deploy --only functions
```

---

## Step 7: Test the Integration

### Test Webhook:

1. Go to Stripe Dashboard → Webhooks → Your endpoint
2. Click **Send test webhook**
3. Select an event (e.g., `checkout.session.completed`)
4. Click **Send test webhook**
5. Check Firebase Functions logs:
   ```bash
   firebase functions:log --only stripeWebhook
   ```

### Test Checkout Flow:

1. Use [Stripe test cards](https://stripe.com/docs/testing#cards):
   - **Success**: `4242 4242 4242 4242`
   - **Decline**: `4000 0000 0000 0002`
   - **Requires auth**: `4000 0025 0000 3155`

2. Complete a test checkout
3. Verify subscription created in Firestore `subscriptions` collection

---

## Environment Summary

| Variable | Location | Example Value |
|----------|----------|---------------|
| `STRIPE_SECRET_KEY` | Firebase Secrets | `sk_live_...` |
| `STRIPE_WEBHOOK_SECRET` | Firebase Secrets | `whsec_...` |
| `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` | `.env.production` | `pk_live_...` |

---

## Function URLs Reference

| Function | URL |
|----------|-----|
| Stripe Webhook | `https://stripewebhook-gu5vyrn2tq-uc.a.run.app` |
| Health Check | `https://healthcheck-gu5vyrn2tq-uc.a.run.app` |
| Checkout Webhook | `https://completecheckoutwebhook-gu5vyrn2tq-uc.a.run.app` |

---

## Troubleshooting

### "Stripe is not configured" error:
- Ensure `STRIPE_SECRET_KEY` is set: `firebase functions:secrets:get STRIPE_SECRET_KEY`
- Redeploy functions after setting secrets

### Webhook signature verification failed:
- Ensure `STRIPE_WEBHOOK_SECRET` matches the signing secret from Stripe Dashboard
- Check if using the correct endpoint (test vs live)

### Subscription not updating:
- Check Firestore `stripeWebhookLogs` collection for errors
- Verify webhook events are correctly selected
- Check function logs: `firebase functions:log --only stripeWebhook`

### Customer portal not working:
- Ensure [Customer Portal is configured](https://dashboard.stripe.com/settings/billing/portal) in Stripe Dashboard
- Enable features: cancel subscription, update payment method, view invoices

---

## Security Best Practices

1. **Never commit secret keys** to version control
2. **Use test keys** for development, live keys for production only
3. **Rotate keys** periodically and if compromised
4. **Restrict API key** permissions in Stripe Dashboard if needed
5. **Monitor webhook failures** via the `getWebhookLogs` function
6. **Use the customer portal** instead of building custom payment forms

---

## Available Stripe UI Components

The platform includes pre-built components in `src/components/stripe/`:

| Component | Purpose |
|-----------|---------|
| `PricingPlans` | Display pricing cards with checkout integration |
| `SubscriptionManager` | List and manage user subscriptions |
| `SubscriptionCard` | Individual subscription display/actions |
| `InvoiceHistory` | View and retry invoices |
| `StripeDashboard` | Admin metrics and revenue overview (HQ only) |
| `WebhookMonitor` | Monitor webhook events and failures (HQ only) |
| `RefundManager` | Process refunds for payments (HQ only) |
| `PlanManager` | Create/edit products and pricing (HQ only) |

### Usage Example:

```tsx
import { 
  PricingPlans, 
  SubscriptionManager, 
  InvoiceHistory 
} from '@/src/components/stripe';

// In a page or component
export default function BillingPage() {
  return (
    <div>
      <SubscriptionManager />
      <InvoiceHistory />
    </div>
  );
}
```

---

## Support

- [Stripe Documentation](https://stripe.com/docs)
- [Firebase Functions with Secrets](https://firebase.google.com/docs/functions/config-env#secret-manager)
- [Stripe Webhook Testing](https://stripe.com/docs/webhooks/test)

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `STRIPE_SETUP_GUIDE.md`
<!-- TELEMETRY_WIRING:END -->
