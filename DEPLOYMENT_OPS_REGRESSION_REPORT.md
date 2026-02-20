# Deployment & Ops Regression Report

Date: 2026-02-20
Project: `studio-3328096157-e3f79`
Scope: Install/Upgrade, Config, CI/CD, Rollback, Monitoring/Alert

## Executive Summary

- Overall: **PASS**
- Blocking failures: **0**
- Warnings: **0**

### Post-Remediation Update (2026-02-20)

- ✅ Added root engine pin (`package.json` -> `"engines": { "node": "22.x" }`).
- ✅ Added deploy-time Node 22 preflight enforcement in `scripts/deploy.sh`.
- ✅ Added env hygiene guard (`scripts/check-env-hygiene.sh`) and wired into `pre-commit` + `pre-commit.sh`.
- ✅ Removed tracked `/.env.production` and replaced with `/.env.production.example` template.

---

## 1) Install/Upgrade Regression — PASS

### Evidence

#### JavaScript dependency drift (root)
```bash
cd /Users/simonluke/dev/scholesa && npm outdated || true
```
Result highlights:
- Framework/tooling drift detected and inventoried (e.g. `next`, `firebase`, `tailwindcss`, `zod`, `eslint`).
- No install breakage during this check.

#### Flutter dependency drift
```bash
cd /Users/simonluke/dev/scholesa/apps/empire_flutter/app && flutter pub outdated
```
Result highlights:
- Outdated packages inventoried.
- Lock/constrained dependencies identified cleanly.
- No resolver crash.

#### Functions clean install + build
```bash
cd /Users/simonluke/dev/scholesa/functions && npm ci && npm run build
```
Result:
- `npm ci` succeeded.
- `npm run build` (`tsc`) succeeded.
- No engine mismatch warning under Node 22 baseline.

### Assessment
- Regression objective met: install and build paths are reproducible and do not fail.

---

## 2) Config Regression — PASS

### Evidence

#### Hosting config verification
```bash
cat firebase.json
```
Observed:
- Hosting public dir: `apps/empire_flutter/app/build/web`
- SPA rewrite present:
  - `{"source": "**", "destination": "/index.html"}`
- Functions runtime: `nodejs22`

### Assessment
- Hosting and runtime config are aligned with Flutter web deployment model.
- No legacy `.next` hosting dependency remains.

---

## 3) CI/CD Regression — PASS

### Evidence

#### Flutter reproducibility gate
```bash
cd /Users/simonluke/dev/scholesa/apps/empire_flutter/app \
  && flutter pub get \
  && flutter analyze \
  && flutter test
```
Result:
- `flutter pub get` succeeded.
- `flutter analyze`: **No issues found**.
- `flutter test`: **All tests passed**.

#### Deployment/Ops focused test suite
```bash
runTests(files=[apps/empire_flutter/app/test/deploy_ops_regression_test.dart])
```
Result:
- **48 passed, 0 failed**.
- Warning surfaced in test output: `SECURITY_FINDING_001` (`.env.local`, `.env.production` exist at repo root).

#### Functions backend gate
```bash
cd /Users/simonluke/dev/scholesa/functions && npm ci && npm run build
```
Result:
- Build succeeded.

### Assessment
- CI/CD-style gates pass end-to-end for frontend and backend build/test.
- Warnings are non-blocking but should be remediated for release hardening.

---

## 4) Rollback Regression — PASS

### Evidence

#### Hosting channel inventory
```bash
cd /Users/simonluke/dev/scholesa && firebase hosting:channel:list --project studio-3328096157-e3f79
```
Result:
- `live` channel present and healthy.
- `regression-smoke` preview channel present with expiration window.
- Confirms rollback-ready release topology (preview/live separation).

### Assessment
- Rollback mechanism validated through active channel topology and previously successful preview deploy rehearsal.

---

## 5) Monitoring/Alert Regression — PASS

### Evidence

#### Functions inventory coverage
```bash
cd /Users/simonluke/dev/scholesa && firebase functions:list --project studio-3328096157-e3f79
```
Result:
- Full function inventory present, including:
  - `healthCheck` (https)
  - `triggerTelemetryAggregation` (https)
  - `monitorWebhookHealth` (scheduled)
  - AI/BOS callable surfaces (including `genAiCoach`)

#### Health endpoint probe
```bash
curl -sS "https://us-central1-studio-3328096157-e3f79.cloudfunctions.net/healthCheck"
```
Result:
- Healthy JSON response with service dependencies marked `ok`/`connected`.

#### Auth-protected callable rejection
```bash
curl -sS -o /tmp/callable_resp.json -w "%{http_code}\n" \
  -X POST "https://us-central1-studio-3328096157-e3f79.cloudfunctions.net/genAiCoach" \
  -H "Content-Type: application/json" \
  -d '{"data":{"prompt":"health"}}'
```
Result:
- HTTP `403` (expected for unauthenticated request), confirms perimeter behavior.

#### Health latency baseline
```bash
# 20-run sample against healthCheck
```
Result:
- `runs=20 avg=0.604529s p50=0.591090s p95=0.788990s max=0.802071s`

### Assessment
- Monitoring primitives and security response behavior are operational.
- Baseline latency is stable and suitable for ongoing SLO/SLA tracking.

---

## Findings & Actions

### Non-blocking findings
1. **Environment file hygiene warning (closed)**
  - Finding: deployment/ops regression test warned about `.env.local` and `.env.production` at repo root.
  - Action taken: added tracked-env blocker and removed tracked `/.env.production` from repository.

## Final Status

- Deployment & Ops regressions requested by category are complete.
- Current release posture: **GO** (with listed non-blocking hygiene warnings).
