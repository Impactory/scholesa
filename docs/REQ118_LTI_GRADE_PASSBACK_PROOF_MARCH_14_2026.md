# REQ-118 Proof: LTI 1.3 and Grade Passback

## Scope closed

REQ-118 required a canonical implementation for LTI 1.3 launch handling plus retry-safe grade passback.

This repo now contains a real implementation path across web, backend, and Flutter integration surfaces:

- Web LTI launch verification and redirect handoff:
  - `app/api/lti/launch/route.ts`
  - `src/lib/lti/launch.ts`
- Backend LTI platform/resource registration and grade-passback queueing:
  - `functions/src/workflowOps.ts`
  - `functions/src/ltiIntegration.ts`
- Canonical schema and typed collection support:
  - `schema.ts`
  - `src/types/schema.ts`
  - `src/firebase/firestore/collections.ts`
- Flutter integration visibility and persistence:
  - `apps/empire_flutter/app/lib/domain/models.dart`
  - `apps/empire_flutter/app/lib/domain/repositories.dart`
  - `apps/empire_flutter/app/lib/modules/educator/educator_integrations_page.dart`
  - `apps/empire_flutter/app/lib/modules/site/site_integrations_health_page.dart`
  - `apps/empire_flutter/app/lib/modules/hq_admin/hq_integrations_health_page.dart`

## What was implemented

1. LTI 1.3 launch verification
- Accepts standards-aligned `id_token` POSTs.
- Resolves platform registration by issuer, audience, and deployment id.
- Fetches JWKS, verifies RS256 signatures, validates core LTI claims, and rejects expired launches.
- Resolves resource-link mapping and redirects into the localized Scholesa app with launch context.
- Records an audit log entry for accepted launches.

2. Grade passback queueing
- Added site-scoped `queueLtiGradePassback` callable.
- Validates actor access and mission-attempt site ownership.
- Derives or accepts line-item identity.
- Generates a deterministic idempotency key.
- Deduplicates previously queued passback jobs.
- Emits an audit log entry without adding learner PII beyond ids.

3. LTI admin primitives
- Added `upsertLtiPlatformRegistration` callable.
- Added `upsertLtiResourceLink` callable.
- Mirrors active LTI registrations into existing integration health surfaces via `integrationConnections`.

4. Client/integration surfaces
- Added canonical LTI platform, resource-link, and grade-passback models and repositories in Flutter.
- Added LTI provider handling to educator, site, and HQ integration surfaces.
- Added LTI provider option to the workflow sync trigger configs.

## Validation run

### Dependency discipline
- `npm outdated`
- Result: drift exists on several packages, but no forced upgrade was used and no dependency hack flags were introduced for REQ-118.

### Web launch tests
- `npm test -- --runTestsByPath src/__tests__/lti-launch.test.ts`
- Result: passed
- Coverage:
  - valid signed LTI launch redirects with context
  - expired launch token returns a typed 401 error

### Functions helper tests
- `cd functions && npm test -- --runTestsByPath src/ltiIntegration.test.ts`
- Result: passed
- Coverage:
  - provider alias normalization
  - deterministic idempotency keys
  - queued grade-passback job construction
  - invalid score rejection
  - audit log payload shape

### Functions compile
- `cd functions && npm run build`
- Result: passed

### Flutter integration tests
- `cd apps/empire_flutter/app && flutter test test/lti_integration_test.dart test/google_classroom_integration_test.dart`
- Result: passed (`4` tests total in that focused run)
- Coverage:
  - educator integration surface renders LTI provider and queues sync
  - LTI platform/resource/passback repositories persist records
  - pre-existing Google Classroom integration surface remained green in the same focused run

### Web production build
- `npm run build`
- Result: passed
- Route table includes `ƒ /api/lti/launch`

## Closure statement

REQ-118 is now backed by canonical implementation, focused tests, backend compile proof, Flutter integration proof, and a passing web production build. It is no longer accurate to classify LTI 1.3 and grade passback as “No canonical implementation found.”