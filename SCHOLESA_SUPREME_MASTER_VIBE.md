# SCHOLESA_SUPREME_MASTER_VIBE.md  
## Build ▸ Schema ▸ Auth ▸ Audit ▸ Evolve

> You are **Google Gemini** working in **Firebase Studio** on the **Scholesa** platform.  
> Scholesa is the **Education 2.0 OS** for:
> - Physical schools / studios (sites)
> - Learners, Educators, Parents, Site Leads, Partners, HQ  
> Built around **3 pillars**:
> 1. **Future Skills** (AI, coding, robotics, research)  
> 2. **Leadership & Agency**  
> 3. **Impact & Innovation**  
>
> Your mission is to:
> 1. **Implement** the platform end-to-end (UI, logic, PWA, database).  
> 2. **Enforce and centralize schema + security rules**.  
> 3. **Fully validate auth, registration, role-based routing, and core create flows**.  
> 4. **Run a full post-implementation audit and fix all gaps**.  
> 5. **Adopt best-practice patterns for rollout, maintenance, and evolution.**

You must follow this master vibe in **five stages**:

1. **Implementation Phase** – Build the system according to the architecture.  
2. **Schema & Security Enforcement** – Make the data model explicit and enforced.  
3. **Auth & Onboarding Deep Dive** – Ensure logins, registration, and create flows are fully baked.  
4. **Global Post-Implementation Audit** – Check and fix everything.  
5. **Post-Audit Next Practices** – Ongoing best practices after the system is working.

Do **not** skip stages. Do **not** use hacks like `--force` or `--legacy-peer-deps` to hide real problems.

---

## GLOBAL NON-NEGOTIABLES (APPLY IN ALL STAGES)

1. **Stack**
   - Next.js **App Router** + React + TypeScript.
   - Firebase: Firestore, Auth, Storage, Cloud Functions (Node 20).
   - TailwindCSS for styling.
   - Use stable, recommended versions.

2. **Dependency Discipline**
   - Never use `--force` or `--legacy-peer-deps`.
   - Fix peer conflicts by aligning versions properly.

3. **Routing Discipline**
   - App Router only (no pages router).
   - Use `[locale]` segment, e.g. `/en`.
   - `(auth)` route group for login/register.
   - `(protected)` route group for dashboards.
   - No duplicate `page.tsx` that resolve to the same URL.

4. **Client vs Admin Separation**
   - **Client**: Firebase Web SDK only.  
   - **Server** (Cloud Functions / server actions / server utilities): `firebase-admin`.  
   - Never import admin code into `"use client"` files.

5. **PWA Baseline**
   - `public/sw.js` exists and is valid.
   - `public/manifest.webmanifest` exists and matches icon files.
   - No 404 for `/sw.js` or `/manifest.webmanifest`.

6. **3 Pillars Everywhere**
   - Pillars are encoded in data (pillar codes on missions, skills, portfolios, etc.).
   - Pillars visible in UI for learners, educators, parents, HQ.
   - AI text uses pillar language; any learner/parent-facing AI output is **human-reviewed**.

---

# STAGE 1 – IMPLEMENTATION PHASE (BUILD THE PLATFORM)

## 1. Project Structure & Routing

### 1.1 Directory Layout

Use this structure:

```plaintext
/
  app/
    [locale]/
      page.tsx                          // Universal landing page
      (auth)/
        login/
          page.tsx
        register/
          page.tsx
      (protected)/
        dashboard/
          layout.tsx
          page.tsx                      // Role-based redirect
        learner/
          layout.tsx
          page.tsx
        educator/
          layout.tsx
          page.tsx
        parent/
          layout.tsx
          page.tsx
        site/
          layout.tsx
          page.tsx
        partner/
          layout.tsx
          page.tsx
        hq/
          layout.tsx
          page.tsx

  src/
    firebase/
      client-init.ts
      admin-init.ts
      auth/
        getCurrentUserServer.ts
        getUserRoleServer.ts
    modules/
      school-ops/
      learning/
      accountability/
      comms/
      hq/
      pillars/
    components/
      ui/
      layout/
      charts/
    lib/
      routing/
      types/
      utils/

  public/
    sw.js
    manifest.webmanifest
    icons/
      icon-192.png
      icon-512.png

  functions/
    src/
      genai/
      cron/
      auth/
      analytics/
```
