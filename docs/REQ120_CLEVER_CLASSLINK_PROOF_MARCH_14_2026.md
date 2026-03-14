# REQ-120 Proof: Clever and ClassLink First-Wave Integration

Date: 2026-03-14
Status: Implemented and validated for governed first-wave roster plus identity workflows

## Scope proved

REQ-120 is satisfied at the first-wave provider layer for Clever and ClassLink with the following shipped behavior:

- shared provider normalization and metadata helpers for Clever and ClassLink
- callable parity for provider auth-url generation, school discovery, section discovery, roster sync queueing, identity resolution, and connection disconnect
- site-facing governed workflow entry for Clever in the protected web route system
- Flutter educator and site admin surfaces that recognize Clever and ClassLink connections and sync health
- Flutter site identity review flow that routes approve and ignore actions through provider-aware Clever and ClassLink resolver paths

This proof does not claim live district rollout or callback-token exchange parity beyond the governed stub flow already present in the backend. The implemented surface is the repo's first-wave roster and identity integration contract.

## Implementation files

- functions/src/districtProviderIntegration.ts
- functions/src/districtProviderIntegration.test.ts
- functions/src/ltiIntegration.ts
- functions/src/workflowOps.ts
- functions/src/index.ts
- src/lib/routing/workflowRoutes.ts
- app/[locale]/(protected)/site/clever/page.tsx
- src/features/workflows/workflowData.ts
- src/testing/e2e/fakeWebBackend.ts
- apps/empire_flutter/app/lib/modules/educator/educator_integrations_page.dart
- apps/empire_flutter/app/lib/modules/site/site_integrations_health_page.dart
- apps/empire_flutter/app/lib/modules/site/site_identity_page.dart
- apps/empire_flutter/app/test/district_provider_integration_test.dart

## Validation

Passed on 2026-03-14:

1. Root typecheck
   - command: `npm run typecheck`
2. Functions build
   - command: `cd functions && npm run build`
3. Focused functions helper test
   - command: `cd functions && npm test -- districtProviderIntegration.test.ts`
   - result: 3 tests passed
4. Focused Flutter provider proof
   - command: `cd /Users/simonluke/dev/scholesa/apps/empire_flutter/app && flutter test test/district_provider_integration_test.dart`
   - result: 3 tests passed

## Evidence summary

- Clever and ClassLink provider aliases normalize to canonical provider keys.
- Shared helper logic now produces stable provider doc IDs, display names, auth bases, audit action names, and roster sync job names.
- Backend callable coverage now exists for both providers instead of Clever-only scaffolding.
- Educator integrations UI renders both district providers and can queue sync work by provider key.
- Site integrations health UI renders both providers with status-aware visuals.
- Site identity review now preserves the raw provider and routes decisions through provider-specific resolution flows.

## Residual guardrails

- Provider rollout is still governed by environment-backed connect configuration and the chartered first-wave scope.
- This proof covers roster and identity workflows only. It does not claim assignment publish, grade passback, or destructive deprovisioning for district providers.