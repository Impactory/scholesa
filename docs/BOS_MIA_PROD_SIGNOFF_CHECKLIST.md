# BOS+MIA Production Sign-off Checklist

Latest execution evidence: `docs/BOS_MIA_RELEASE_CERTIFICATE_2026-03-03.md`

## 1) Release Preconditions
- [ ] `npm run qa:bos:mia:complete` passes at repo root.
- [ ] `npm run rc3:preflight` passes.
- [ ] `npm run compliance:gate` passes.
- [ ] No open BOS/COPPA blockers in release notes.

## 2) Required Environment & Secrets

### Web / Next.js
- [ ] `NEXT_PUBLIC_FIREBASE_API_KEY`
- [ ] `NEXT_PUBLIC_FIREBASE_PROJECT_ID`
- [ ] `NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN`
- [ ] `NEXT_PUBLIC_FIREBASE_APP_ID`
- [ ] `NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET`
- [ ] `NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID`

### Functions / Server
- [ ] `FIREBASE_SERVICE_ACCOUNT` (or workload identity)
- [ ] `VIBE_ENV=prod`
- [ ] Internal inference auth configured for BOS/LLM/STT/TTS (if required in prod)
- [ ] Stripe and notification secrets present where used

## 3) Data & Policy Preconditions (COPPA + BOS)
- [ ] `coppaSchoolConsents/{siteId}` exists for all target production sites.
- [ ] Consent record booleans true: `active`, `agreementSigned`, `educationalUseOnly`, `parentNoticeProvided`, `noStudentMarketing`.
- [ ] Site-scoped user profile links (`siteIds` / `activeSiteId`) verified for educators and learners.
- [ ] Firestore rules deployed and validated for BOS collections.

## 4) Deployment Order
1. [ ] Deploy Functions first (BOS runtime + voice handlers + COPPA guards).
2. [ ] Deploy web app (Next.js).
3. [ ] Deploy/update Flutter web/mobile artifact as applicable.
4. [ ] Run post-deploy smoke checks (below) before opening traffic.

## 5) Post-Deploy Smoke Checks (Critical)

### BOS Runtime
- [ ] Ingest event path writes `interactionEvents` with server timestamp.
- [ ] `bosGetIntervention` returns intervention + risk + trace metadata.
- [ ] MVL episode creation occurs only when sensor fusion corroboration is met.
- [ ] `bosWeeklyFairnessAudit` appears in scheduler list and writes `fairnessAudits` weekly.

### Spoken AI
- [ ] `/copilot/message` returns text + TTS metadata where enabled.
- [ ] `/voice/transcribe` and `/tts/speak` succeed for valid authorized requests.
- [ ] Redaction/safety metadata present in telemetry for voice flows.

### COPPA Enforcement
- [ ] Request with inactive/missing school consent fails with precondition error.
- [ ] Cross-site request fails with permission error.
- [ ] `npm run qa:coppa:guards` passes in prod-like environment.

## 6) Telemetry & Traceability Validation
- [ ] AI events present: `ai_help_opened`, `ai_help_used`, `ai_coach_response`.
- [ ] MVL events present: `mvl_gate_triggered`, `mvl_evidence_attached`, `mvl_passed|mvl_failed`.
- [ ] Event envelope includes `siteId`, `sessionOccurrenceId`, `gradeBand`, `actorId`.
- [ ] Correlate `traceId`/`requestId` across runtime and telemetry records.

## 7) Rollback Plan
- [ ] Keep previous function revision ready for immediate rollback.
- [ ] Keep previous web deployment alias for instant switchback.
- [ ] If COPPA guard failures spike unexpectedly, rollback and inspect consent/site scoping data before retry.

## 8) Final Sign-off Record
- [ ] Release owner:
- [ ] Date/time (UTC):
- [ ] Commit SHA:
- [ ] Environment:
- [ ] QA gate evidence links:
- [ ] Compliance approval:
- [ ] Go-live decision: APPROVED / HOLD
