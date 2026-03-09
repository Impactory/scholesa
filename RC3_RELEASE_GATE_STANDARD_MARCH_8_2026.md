# RC3 Release Gate Standard

**Date**: March 8, 2026  
**Scope**: Defines the exact standard for treating RC3 as `100% against gate` for live deployment.

---

## Standard

RC3 is considered `100% against gate` only when all of the following are true at the same time:

1. Code gates pass.
2. Data and identity gates pass against the live Firebase project.
3. Launch-critical role workflows pass in automation.
4. Manual production canary passes for all six core roles.
5. Current signoff documentation matches the real system state.

This is a release standard, not a claim that production risk is literally zero.

---

## Mandatory Gates

### A. Live Identity Gates

All of these must pass:

```bash
node scripts/cleanup_identity_artifacts.js --strict
node scripts/reconcile_login_profiles.js --strict
node scripts/reconcile_auth_role_claims.js --strict
node scripts/verify_login_profiles.js --strict
node scripts/firebase_role_e2e_audit.js --strict
```

Required result:
- `0` Firestore-only users
- `0` Auth-only login-capable users
- `0` Auth-only ephemeral users
- `0` missing Auth role claims
- `0` mismatched roles

### B. Full RC3 Gate

This must pass:

```bash
bash ./scripts/rc3_preflight.sh
```

Required result:
- role cross-links pass
- web E2E workflow suite passes
- production Next build passes
- Flutter release build passes
- compliance, COPPA, voice, i18n, and telemetry gates pass

### C. Manual Production Canary

This must be completed:

- `RC3_PRODUCTION_CANARY_CHECKLIST_MARCH_8_2026.md`
- `RC3_OPERATOR_CANARY_SCRIPT_MARCH_8_2026.md`

Required result:
- learner, educator, parent, site, partner, and HQ all pass live canary
- no refresh-time persistence failures
- no redirect loops
- no unauthorized data exposure

---

## Minimum Evidence Package

A release is not `100% against gate` unless the repo contains or references:

1. A current signoff artifact
2. A current canary checklist result
3. Successful gate output for the strict live audit
4. Successful gate output for login verification
5. Successful gate output for RC3 preflight

Current signoff references:
- `RC3_LIVE_E2E_SIGNOFF_MARCH_8_2026.md`
- `RC3_PRODUCTION_READINESS_FINAL_SIGN_OFF.md`
- `RC3_LAUNCH_READINESS_REPORT.md`
- `RC3_OPERATOR_CANARY_SCRIPT_MARCH_8_2026.md`

---

## Failure Policy

Treat release as `NO-GO` if any of the following occur:

1. Any strict identity script reports pending updates or blockers.
2. Any role workflow fails in Playwright or protected-route validation.
3. Any manual canary role cannot complete its primary CTA.
4. Any role sees data outside its allowed scope.
5. Any role lands on the wrong dashboard or enters a redirect loop.
6. Documentation claims a greener state than the live system actually has.

---

## Operational Definition of 100%

For this repo, `100%` means:

- all known launch-critical blockers are closed
- all defined gates are green
- no known live data drift exists in Auth or Firestore
- launch-critical workflows have both automated and manual evidence
- rollback and monitoring remain available if production behavior diverges

It does not mean unknown unknowns are impossible. It means the release meets the full agreed deployment standard.
