# SCHOLESA_SUPREME_MASTER_VIBE.md  
## Build ▸ Schema ▸ Auth ▸ Audit ▸ Evolve

> You are the expert coder working on the **Scholesa** platform.  
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
   - flutter
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

Use this structure and akways use the repo root as the base if not stated

```plaintext
/tree.md file for full structure reference
/SCHOLESA_SUPREME_MASTER_VIBE.md for guidelines
/TRACEABILITY_MATRIX.md for requirements tracking
```
## DEPENDENCY & COMPONENT VERSION GOVERNANCE

> Goal: All core framework and UI component versions stay **current, compatible, and consistent** across the platform, without random drift or version conflicts.

You must treat **dependencies and shared components** as first-class citizens, not an afterthought.

### 1. Single Source of Truth for Versions

1. Create and maintain a doc at the repo root:

   - `DEPENDENCY_BASELINE_SCHOLESA.md`

   It must list the **minimum and target versions** for all core libraries, for example (examples only):

   - flutter files
   - React / ReactDOM
   - TypeScript
   - Firebase SDKs (`firebase`, `firebase-admin`)
   - TailwindCSS
   - Testing libs (Jest / Vitest / Playwright / Cypress, etc.)
   - PWA / SW helpers (e.g. `next-pwa` if used)
   - Any internal design system / UI library packages

2. For each key package, specify:

   - **Current locked version** in `package.json` (e.g. `next: 15.0.5`).
   - **Supported range** if applicable (e.g. “15.x only; do not jump to 16.x without a migration plan”).

3. This doc is the **authority**.  
   Whenever you change versions in `package.json`, you must update this doc.

---

### 2. Version Rules for Core Dependencies

You must obey these rules:

1. **No mixed majors** for core frameworks:

   - Never have multiple major versions of flutter, Firebase, or the main UI library in the same repo.
   - If you upgrade flutter or Firebase major version:
     - Upgrade all dependent packages that require a specific peer version.
     - Update the baseline doc.

2. **Stay on latest stable within the chosen major:**

   - For each core lib, you should target the **latest stable** version within your chosen major that is supported by:
     - flutter ecosystem,
     - Firebase tooling / hosting,
     - Your app and platform setup.

3. **Respect peer dependencies:**

   - Before installing or updating a package, inspect its `peerDependencies`.
   - Do **not** create peer conflicts and then “fix” them with `--force` or `--legacy-peer-deps`.
   - Instead, adjust the root dependencies to a compatible set or choose another version of the package that fits.

---

### 3. Component Library & Design System Versions

If you use a component library (e.g., internal `@scholesa/ui` or external `@shadcn/ui` etc.):

1. Maintain a section in `DEPENDENCY_BASELINE_SCHOLESA.md` for **UI components**:

   - Library name.
   - Version.
   - Notes (e.g., “v1 tokens, do not mix with v0”).

2. You must **never mix** components from different major versions of the same design system.

3. When upgrading the component library:

   - Plan the migration (breaking changes, tokens, themes).
   - Update all affected imports.
   - Update baseline doc and run the full build + tests.

---

### 4. “Before You Start Work” Version Check

For any substantial platform task (not just one-line fixes), you must:

1. Run:

   ```bash
   npm outdated

2. use `TRACEABILITY_MATRIX.md` to check if it exists and is up to date. use it to guide your work.