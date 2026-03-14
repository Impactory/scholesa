# REQ-110 Proof: Enterprise SSO via SAML and OIDC

## Scope closed

REQ-110 required a canonical enterprise SSO implementation for SAML and OIDC with real login entry points, provider configuration, JIT provisioning, role and site mapping, and auditable session creation.

This repo now contains a concrete implementation path across web login, server session creation, backend config callables, schema, and rules:

- Web provider discovery and enterprise login entry:
  - `app/[locale]/(auth)/login/page.tsx`
  - `app/api/auth/sso/providers/route.ts`
  - `src/firebase/auth/AuthProvider.tsx`
  - `src/firebase/client-init.ts`
- Canonical enterprise SSO normalization and JIT mapping:
  - `src/lib/auth/enterpriseSso.ts`
  - `app/api/auth/session-login/route.ts`
- Provider configuration and audit surface:
  - `functions/src/workflowOps.ts`
  - `functions/src/index.ts`
- Canonical schema and access controls:
  - `schema.ts`
  - `src/types/schema.ts`
  - `src/types/user.ts`
  - `src/firebase/firestore/collections.ts`
  - `firestore.rules`

## What was implemented

1. Enterprise provider discovery
- Added `GET /api/auth/sso/providers` to return enabled `oidc.*` and `saml.*` providers from Firestore.
- Supports optional domain and site filtering.
- Returns only sanitized metadata needed for sign-in buttons.
- Localizes provider button labels from the request locale.

2. Enterprise sign-in on the login surface
- Added enterprise SSO actions to the localized login page.
- Login page now fetches configured providers and filters them by typed email domain when available.
- Enterprise sign-in still uses the existing Firebase popup and session-cookie model.
- Added generic provider support in the auth context for `oidc.*`, `saml.*`, and existing Google sign-in.

3. JIT provisioning and role/site mapping
- Extended `app/api/auth/session-login/route.ts` to inspect Firebase `sign_in_provider`.
- Enterprise providers are resolved against the canonical `enterpriseSsoProviders` collection.
- New or incomplete users are provisioned/merged with:
  - mapped role from token claims when present
  - fallback provider default role
  - mapped site ids from claims when present
  - fallback provider site scope and default site
  - organization and auth-provider metadata
- Unconfigured enterprise providers are rejected with a typed `403`.

4. Auditability and admin configuration
- Enterprise session creation records `auth.sso.login` audit entries.
- Added callable boundaries to list and upsert enterprise SSO providers.
- Provider updates also emit audit log entries.
- Added schema and rules coverage for the new provider catalog.

## Validation run

### Dependency discipline
- `npm outdated`
- Result: drift still exists in the repo baseline, but REQ-110 was implemented without forced installs or peer-dependency bypass flags.

### Focused enterprise SSO tests
- `npm test -- --runInBand src/__tests__/enterprise-sso.test.ts`
- Result: passed
- Coverage:
  - provider discovery returns only matching enabled providers
  - localized button labels are emitted for enterprise providers
  - enterprise session creation JIT provisions role/site/auth metadata
  - unconfigured enterprise providers are rejected

### Functions compile
- `npm --prefix functions run build`
- Result: passed

### Web production build
- `npm run build`
- Result: passed
- Build evidence includes:
  - `ƒ /api/auth/sso/providers`
  - `ƒ /api/auth/session-login`
  - localized login route remained buildable

## Closure statement

REQ-110 is now backed by canonical SAML/OIDC provider discovery, generic enterprise Firebase sign-in, JIT role and site mapping in session creation, admin provider configuration callables, audit logging, and passing focused validation. It is no longer accurate to classify enterprise SSO as “No canonical implementation found.”