# SCHOLESA_AUDIT_FIX_AND_REMEDIATION_VIBE.md  
## One Canonical Script for Auditing **and** Fixing the Scholesa Platform

> You are **Google Gemini** working on the **Scholesa** Education 2.0 platform in Firebase Studio.  
> Scholesa is a Next.js + Firebase **PWA** used by:
> - Learners
> - Educators
> - Parents
> - Site Leads
> - Partners
> - HQ  
>
> Your job with this document is twofold:
>
> 1. **Audit Mode** – Inspect the entire app (code, config, schema, security, PWA, logic).
> 2. **Remediation Mode** – Use **the same sections** as a checklist to implement fixes from the Audit Report until the platform is stable, secure, and coherent.

You must always treat this file as the **single source of truth** for what “done” means in an audit + fix cycle.

---

## 0. HOW TO USE THIS DOC

### 0.1 Modes

You operate in two modes:

1. **Audit Mode (Pass 1)**  
   - You *do not* add new features.  
   - You inspect, diagnose, and describe issues section-by-section.  
   - You produce an **Audit Report** (Section 13).

2. **Remediation Mode (Pass 2+)**  
   - You pick items from the Audit Report (especially 🟡 and 🔴).  
   - You use the **same sections** in this vibe (2–12) as your “to-fix” checklist.  
   - For each item, you:
     - Plan the fix.
     - Implement the fix (conceptually / via code changes).
     - Re-run relevant checks.
     - Update the Audit Report status.

You can go through multiple Remediation cycles until all important sections are ✅.

### 0.2 Global Constraints

These rules apply in **both** modes:

1. **No hacks**  
   - Do **not** use `--force` or `--legacy-peer-deps`.  
   - Fix root causes (versions, imports, config, schema).

2. **No net-new features** in Audit/Remediation  
   - You may:
     - Finish incomplete features.
     - Replace broken implementations with clean ones.
     - Remove/merge duplicates.
   - You may **not** invent new feature areas here.

3. **Single source of truth**  
   - One canonical:
     - Firebase client init.
     - Firebase admin init.
     - Service worker registration.
     - Route per URL.
     - Schema per collection.
     - Role → dashboard mapping.

4. **End-state requirement (after Remediation)**  
   - `npm run build` passes with **0 errors**.
   - All core roles can log in and reach the correct dashboard.
   - No unhandled errors in main flows in dev/staging.
   - No SW registration errors (no “unsupported protocol” errors).

5. **Continuous Verification**
   - After any major implementation work using this spec, you must run the full SCHOLESA_AUDIT_FIX_AND_REMEDIATION_VIBE.md process and update the Audit Report.

---

# PART A – AUDIT MODE (Pass 1)

Follow Sections 1–12 to perform a **deep, structured audit**.

---

## 1. Preparation: High-Level Inventory

**Audit:**

1. Inspect repo contents:
   - `package.json`
   - `next.config.*`
   - `firebase.json`, `.firebaserc`
   - `app/` tree (App Router)
   - `src/firebase/` structure
   - `functions/` (if present)

2. Note any red flags:
   - Mixed `app/` + `pages/` usage.
   - Multiple login or root pages for same route.
   - Multiple service worker registration snippets.
   - Direct `firebase-admin` imports in `"use client"` files.

**Record in Audit Report:**

- Summarize any suspicious patterns (e.g. “Found duplicate login pages in app/[locale]/login and app/[locale]/(auth)/login”).

---

## 2. Routing & Structure Audit

**Audit:**

1. Check **root & auth routes**:
   - There must be exactly one landing page per locale:
     - `app/[locale]/page.tsx`
   - Auth routes live under `(auth)`:
     - `app/[locale]/(auth)/login/page.tsx`
     - `app/[locale]/(auth)/register/page.tsx` (if used)
   - No `app/[locale]/login/page.tsx` or `register` duplicates.

2. Check **protected routes**:
   - `app/[locale]/(protected)/dashboard/page.tsx` – role-based redirect.
   - Role dashboards:
     - `app/[locale]/(protected)/learner/page.tsx`
     - `app/[locale]/(protected)/educator/page.tsx`
     - `app/[locale]/(protected)/parent/page.tsx`
     - `app/[locale]/(protected)/site/page.tsx`
     - `app/[locale]/(protected)/partner/page.tsx`
     - `app/[locale]/(protected)/hq/page.tsx`

3. Look for:
   - Duplicated pages mapping to same route paths.
   - Legacy routes not reachable via current navigation.

**Record in Audit Report:**

- Where conflicts exist (e.g. “Duplicate login pages found”).
- Where role dashboards are missing or incomplete.

---

## 3. Service Worker & PWA Audit

**Audit:**

1. Search codebase for:
   - `navigator.serviceWorker.register`
   - `"sw.js"`
   - PWA plugins in `next.config.*` (e.g., `next-pwa`).

2. Check:
   - `public/sw.js` exists and is valid JS.
   - `public/manifest.webmanifest` exists and references **existing** icons.
   - Any logs or errors in console:
     - “Failed to register a ServiceWorker: The URL protocol of the script (':') is not supported.”
     - 404s on `/sw.js` or `/manifest.webmanifest`.

**Record in Audit Report:**

- All locations where SW is registered.
- Any SW-related runtime errors you see in dev/studio.

---

## 4. Dependency & Version Audit

**Audit:**

1. Inspect `package.json`:
   - Versions of:
     - Next.js, React, React-DOM
     - TypeScript
     - `firebase`, `firebase-admin`
     - PWA or AI plugins (e.g., `next-pwa`, `@genkit-ai/next`).
2. Look for:
   - Incompatible peer dependencies.
   - Old versions that conflict with platform expectations.
3. Note any `postinstall`/scripts that hint at hacks.

**Record in Audit Report:**

- Any version mismatches (e.g., plugin requires Next 15, app is on Next 14).
- Any warnings from `npm install` or known from logs.

---

## 5. Firebase Init & Admin Boundaries

**Audit:**

1. Client init:
   - `src/firebase/client-init.ts` (or similar):
     - Uses Web SDK.
     - Exports `app`, `auth`, `firestore`, `storage`.

2. Admin init:
   - `src/firebase/admin-init.ts`:
     - Uses `firebase-admin`.
     - `if (!admin.apps.length) admin.initializeApp(...)`.
     - Export `admin`.

3. Search for `firebase-admin` imports in:
   - `.tsx` files marked `"use client"`.
   - Client-only contexts.

**Record in Audit Report:**

- Whether there is exactly one client init & one admin init.
- Any instances where admin is imported on client.

---

## 6. Schema & Data Model Audit

**Audit:**

1. Check for central schema types:
   - e.g. `src/lib/types/schema.ts`.
   - Interfaces for:
     - `User`, `Site`, `Session`, `SessionOccurrence`, `Enrollment`, `AttendanceRecord`
     - `Pillar`, `Skill`, `SkillMastery`
     - `Mission`, `MissionPlan`, `MissionAttempt`
     - `Portfolio`, `PortfolioItem`, `Credential`
     - `AccountabilityCycle`, `AccountabilityKPI`, `AccountabilityCommitment`, `AccountabilityReview`, `AuditLog`

2. Check Firestore helpers:
   - e.g. `src/lib/firestore/collections.ts`.
   - Are typed helpers used, or many raw `collection('...')` calls?

3. Spot-check code usage:
   - Are fields used (`siteId`, `pillarCodes`, etc.) consistent with schema?

**Record in Audit Report:**

- Missing or inconsistent schema types.
- Collections used with ad-hoc shapes or inconsistent fields.

---

## 7. Auth, User & Role Logic Audit

**Audit:**

1. Login/registration pages:
   - Confirm existence & correct routes as in Section 2.
   - Check for duplicate login handling.

2. User creation:
   - Locate signup flow.
   - Verify:
     - After Auth user creation, `users/{uid}` doc is created.
     - `role` is set.
     - `siteIds`, `organizationId`, and `createdAt` are set or at least handled.

3. Role resolving:
   - Locate `getUserRoleServer` or equivalent.
   - Determine:
     - Is role read from `users` or custom claims?
     - Is there a mismatch?

4. Role-based redirect:
   - Check `/[locale]/(protected)/dashboard/page.tsx` or equivalent.
   - Confirm mapping from role → dashboard route.

**Record in Audit Report:**

- Any missing `users` doc creation.
- Any inconsistent or missing role logic.
- Any misrouted roles (e.g. parent sent to learner dashboard).

---

## 8. PWA Offline & Resilience Audit (Functional)

**Audit:**

1. Educator experience:
   - Does the educator dashboard handle offline gracefully?
   - Does it crash when network is lost?

2. Learner experience:
   - Does the learner dashboard show cached views when offline?
   - Any unhandled promise rejections when offline?

3. Queueing:
   - If there is an offline write queue, inspect:
     - Where it lives.
     - Whether it properly retries.

**Record in Audit Report:**

- Any offline or PWA-related runtime errors.
- Flows that break when offline is simulated.

---

## 9. Logic & Business Invariants Audit

**Audit:**

Look for **logic correctness**, not just “no TypeScript errors”.

1. Sessions & attendance:
   - Check code that creates:
     - `sessions`, `sessionOccurrences`, `enrollments`, `attendanceRecords`.
   - Invariants:
     - `sessionOccurrences.sessionId` refers to existing `sessions` doc.
     - `attendanceRecords.sessionOccurrenceId` refers to existing `sessionOccurrences` doc.
     - `enrollments` align with sessions and learners.

2. Missions & pillars:
   - Check mission creation & usage:
     - Every `mission` should have at least one `pillarCode`.
   - Check missionAttempt creation:
     - `missionAttempts` should reference valid `missionId`, `learnerId`, `sessionOccurrenceId`, `siteId`.

3. Accountability:
   - For `accountabilityCycles`, `KPIs`, `commitments`, `reviews`:
     - Start/end dates make sense.
     - cycleId/foreign keys reference valid docs.

**Record in Audit Report:**

- Any places where invariants are not enforced or obviously broken.

---

## 10. Security Rules & Access Control Audit

**Audit:**

1. Inspect Firestore security rules:
   - Are there rules like `allow read, write: if true`?
   - Are rules using:
     - `request.auth.token.role`
     - `request.auth.uid`
     - `resource.data.siteId` and similar?

2. Test mentally:
   - Can learners read each others’ data?
   - Can parents see unlinked learners?
   - Can educators/site leads read/write only within their site?

**Record in Audit Report:**

- Any overly permissive or obviously wrong rules.
- Areas where rules are missing or incomplete.

---

## 11. AI / GenAI Usage Audit (If Present)

**Audit:**

1. Locate all AI usage:
   - GenAI/Genkit files.
   - Functions calling models.
2. Confirm:
   - Calls are **server-side only**.
   - Learner/parent-facing messages are **drafts** requiring human review.
3. Check for:
   - Any direct AI usage in client components.

**Record in Audit Report:**

- Any client-side AI calls.
- Any auto-sending of AI responses to learners/parents.

---

## 12. Build & Manual Smoke Test Audit

**Audit:**

1. Run:
   - `npm run lint`
   - `npm run build`
2. Record:
   - Any build errors or warnings (especially SW, routing, module-not-found).
3. Run dev or preview:
   - As test users:
     - learner, educator, parent, siteLead, partner, hq.
   - Attempt to reach their dashboards.
   - Note runtime errors.

**Record in Audit Report:**

- Build errors.
- Runtime errors in primary flows.

---

## 13. AUDIT REPORT (OUTPUT AT END OF AUDIT MODE)

At the end of Audit Mode, you must produce a **Scholesa Audit Report** with:

1. **Summary (1–3 paragraphs)**
   - Overall health.
   - Biggest issues (e.g., routing conflicts, SW failures, schema drift).

2. **Section-by-Section Status**

For each section (2–12), mark:

- ✅ Fully compliant  
- 🟡 Partially compliant (explain gaps)  
- 🔴 Non-compliant (major issues)

Example:

- Section 2 (Routing & Structure): 🟡 – Duplicate login pages exist; root routing mostly OK.
- Section 3 (SW & PWA): 🔴 – Multiple SW registration calls; unsupported protocol errors in Studio.

3. **Issue List**

A table or list of issues, e.g.:

- `A-01` – Duplicate login routes  
  - Section: 2  
  - Severity: High  
  - Summary: ...  
  - Proposed Fix: Merge into (auth)/login, delete legacy file

Each issue must note the **section** it belongs to.

4. **Suggested Remediation Order**

Recommend an order for fixes, typically:

1. Routing & SW (Sections 2–3)  
2. Dependencies & Firebase init (4–5)  
3. Schema & auth/roles (6–7)  
4. PWA offline & logic invariants (8–9)  
5. Security & AI (10–11)  
6. Build & smoke tests (12)

---

# PART B – REMEDIATION MODE (Pass 2+)

Once the Audit Report is done, you switch to **Remediation Mode**.  
You use **the same sections** (2–12) as your “fix tasks” checklist.

---

## 14. Remediation Workflow

For each remediation iteration:

1. **Pick issues to fix**  
   - Start with the highest severity 🟥/🔴 items.
   - Group by section (2–12).

2. **Plan fixes (per section)**  
   - For each selected issue, restate:
     - Which section it belongs to.
     - What files are involved.
   - Outline concrete code/config changes.

3. **Implement fixes**  
   - Conceptually perform refactors:
     - E.g. “Delete app/[locale]/login/page.tsx; move all login logic into app/[locale]/(auth)/login/page.tsx.”
   - Align changes with the expectations in that section of this doc.

4. **Re-run checks**  
   - For routing/PWA: run dev/preview to confirm errors gone.
   - For schema: type-check relevant modules.
   - For security: reason through or test with sample queries.
   - Always run:
     - `npm run lint`
     - `npm run build` after major changes.

5. **Update Audit Report**  
   - Change status for updated sections:
     - 🔴 → 🟡 or ✅
     - 🟡 → ✅ when fully fixed.
   - Mark specific issues as resolved (A-01 resolved in PR/commit X).

---

## 15. Section-Specific Fix Guidance (Reusing Sections 2–12)

**Important:**  
When fixing issues from Audit Report, always refer back to the **original section** that detected them.  
Below is how to interpret each section in **Remediation Mode**.

---

### 15.1 Fixes for Section 2 (Routing & Structure)

- Remove duplicate or conflicting routes.
- Normalize paths:
  - Single landing page per locale: `app/[locale]/page.tsx`.
  - Single login/register path inside `(auth)`.
  - Single role-dashboard path for each role inside `(protected)`.

After fixes:

- Check routes manually in dev/preview.
- Ensure `next build` no longer reports route conflicts (e.g., “You cannot have two parallel pages that resolve to the same path”).

---

### 15.2 Fixes for Section 3 (Service Worker & PWA)

- Implement **one SW registration** helper (e.g. `registerServiceWorker.ts`).
- Add a single `ServiceWorkerLoader` client component in the root layout.
- Remove any other manual `navigator.serviceWorker.register` calls.
- Ensure `sw.js` and `manifest.webmanifest` are in `public/` and valid.
- Add guards to skip SW registration in unsupported environments (e.g. blob:/Studio preview).

After fixes:

- Build again.
- In dev/preview, verify:
  - SW-related errors (like unsupported URL protocol) are gone.

---

### 15.3 Fixes for Section 4 (Dependencies & Versions)

- Resolve version conflicts by aligning:
  - Next.js, React, TS, Firebase, plugins.
- Update `package.json` and any version baseline docs if applicable.
- Remove reliance on `--force`/`--legacy-peer-deps`.

After fixes:

- Run `npm install` normally.
- Run `npm run build` to ensure no peer dependency breakage.

---

### 15.4 Fixes for Section 5 (Firebase Init & Admin Boundaries)

- Ensure exactly one `client-init.ts` (Web SDK) and one `admin-init.ts` (Admin SDK).
- Replace any duplicate client/admin init with imports from these files.
- Remove `firebase-admin` from all client contexts.

After fixes:

- Confirm no admin code appears in client bundles.
- Run build and check for related errors.

---

### 15.5 Fixes for Section 6 (Schema & Data Model)

- Implement or update `schema.ts` with all core interfaces.
- Replace ad-hoc Firestore access with typed helpers where feasible.
- Align field names and usage in code with these types (e.g. `siteId`, `pillarCodes`, etc.).

After fixes:

- Type-check the code.
- Spot-check documents written to Firestore match the schema.

---

### 15.6 Fixes for Section 7 (Auth, Users & Roles)

- Implement robust user creation:
  - Auth user → `users/{uid}` doc with `role`, `siteIds`, etc.
- Ensure `getUserRoleServer` uses consistent logic.
- Fix role-based redirects in `/[locale]/(protected)/dashboard/page.tsx`.

After fixes:

- Manually test login for each role and confirm correct dashboard routing.
- Verify `users` docs are created with proper fields.

---

### 15.7 Fixes for Section 8 (PWA Offline & Resilience)

- Add offline guards around network calls.
- Implement or correct offline queues if appropriate.
- Display user-friendly offline indicators.

After fixes:

- Simulate offline in dev tools.
- Confirm there are no crashes, and key screens still render.

---

### 15.8 Fixes for Section 9 (Logic & Invariants)

- Add validation in write paths to enforce:
  - Valid references (IDs point to existing docs).
  - Mandatory fields (like `siteId`, `missionId`, `pillarCodes`).
- Optionally add small utility checks to scan for broken references.

After fixes:

- Test common flows (session creation, enrollment, attendance, missions) to ensure data is consistent.

---

### 15.9 Fixes for Section 10 (Security & Access Control)

- Tighten any permissive rules.
- Align rules with intended role/site boundaries.
- Add field checks where necessary.

After fixes:

- Try role-based access scenarios mentally or via test clients.
- Ensure learners/parents/educators cannot see out-of-scope data.

---

### 15.10 Fixes for Section 11 (AI / GenAI Usage)

- Move AI calls to server-only functions if any are client-side.
- Wrap AI output in a “draft → human approval → send” pipeline.
- Mark AI text clearly as draft in the UI.

After fixes:

- Check flows that use AI to ensure:
  - No direct AI-to-child/parent messages without human in the loop.

---

### 15.11 Fixes for Section 12 (Build & Smoke Tests)

- Adjust code/config to resolve build errors.
- Address runtime errors found in QA.

After fixes:

- Re-run:
  - `npm run lint`
  - `npm run build`
- Manually test each role’s login + dashboard.

---

## 16. Rolling Audit & Remediation Cycles

You may need **more than one** Remediation cycle. For each cycle:

1. Read the **current Audit Report**.
2. Choose remaining 🟡/🔴 sections to work on.
3. Apply fixes using this document.
4. Re-run the checks.
5. Update the Audit Report statuses.

You can stop when:

- All critical sections are ✅.
- Any remaining 🟡 are clearly minor and documented.

---

## 17. Final Compliance Confirmation

At the end of the final Remediation cycle, you must:

1. Produce an updated **Audit Report** with:
   - Most sections ✅.
   - Remaining 🟡 items documented with rationale & planned timing.
   - No 🔴 items for critical sections (routing, SW, auth, security, build).

2. Confirm:
   - `npm run build` passes with 0 errors.
   - Each role can log in and reach their dashboard.
   - No critical errors in console for main flows.
   - No SW “unsupported protocol” errors (especially in Firebase Studio/preview).
   - Security and role scoping behave as intended.

Only then may you consider the Scholesa platform **audit-complete and remediated** for this cycle.

---

**This document is your canonical “Audit + Fix + Remediation” vibe.  
In Audit Mode, you generate the report.  
In Remediation Mode, you use these same sections to drive and verify fixes until the report is clean.**
