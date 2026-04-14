# Scholesa Platform – AI Coding Agent Instructions

**Scholesa** is a capability-first evidence platform for K-12 schools and learning studios, built on Next.js + Firebase with role-based features. Students are evaluated by what they can do, explain, improve, and demonstrate over time.

## Stack & Architecture

- **Frontend**: Next.js 16 (App Router) + React 18 + TypeScript
- **Backend**: Firebase (Firestore, Auth, Storage, Cloud Functions v2)
- **Styling**: TailwindCSS + Lucide icons + Headless UI
- **Deployment**: Google Cloud Run (web + Flutter WASM), Firebase Functions
- **PWA**: Service worker in `public/sw.js`, configured via `next-pwa`
- **i18n**: JSON translation files in `locales/`, server-side caching in `lib/i18n.ts`

## Critical Architecture Patterns

### Data Schema (Role-Based Model)
The schema in [schema.ts](../schema.ts) defines the core domain:
- **Users** have roles (`learner`, `educator`, `parent`, `hq`) and belong to multiple sites
- **Sessions** (courses) are tied to sites and educators; **SessionOccurrences** are individual class instances
- **Enrollments** track learner participation; **AttendanceRecords** log per-occurrence attendance
- **Pillars** (Future Skills, Leadership, Impact) and **Skills** structure learning outcomes
- **Missions** and **SkillAssessments** enable mastery tracking

**Key insight**: Users and content are site-scoped. Always include `siteId` in queries and writes.

### Authentication & Authorization
- **Client-side**: [AuthProvider.tsx](../src/firebase/auth/AuthProvider.tsx) uses Firebase Auth state + Firestore user profile sync
- **Server-side**: Use `getUserRoleServer()` in Server Components/Actions to check role without extra reads
- **Firestore rules** ([firestore.rules](../firestore.rules)): Role-based access with helper functions (`isEducator()`, `isHQ()`, etc.)
  - Note: `getUserData()` incurs 1 read per check; cache role lookups in auth context when possible

**Pattern**: Always import `useAuthContext()` in client components to access `user`, `profile`, and `loading` state.

### Routing Conventions
- **Locale-first structure**: All routes are under `app/[locale]/` (middleware enforces default `en`)
- **Route groups**: Use `(auth)` for login/register, `(protected)` for authenticated dashboards
- **No duplicate endpoints**: Each URL should resolve to exactly one `page.tsx`
- **API routes**: Place in `app/api/` and leverage Firebase Admin SDK for server-only operations

### Firestore Collections & Patterns
- **Client queries**: Use [firestore/collections.ts](../src/firebase/firestore/collections.ts) exports (typed collection references)
- **Batch operations**: Use `writeBatch()` for multi-document writes (e.g., creating sessions + occurrences in [scheduler.ts](../scheduler.ts))
- **Real-time listeners**: `useCollection()` / `useDocument()` (from `react-firebase-hooks`) handle subscription cleanup
- **Timestamps**: Use Firestore `Timestamp` for all date fields; convert to JS `Date` in UI as needed

**Example**: Creating sessions with weekly occurrences uses `addDoc()` + `writeBatch()` to atomically create parent + children.

## Developer Workflows

### Setup & Development
```bash
npm install                    # Root + client deps
cd functions && npm install    # Firebase Functions deps
npm run dev                    # Start Next.js dev server (localhost:3000)
firebase emulators:start       # (Optional) Run Firestore/Auth emulators locally
```

### Building & Deployment
```bash
npm run build                  # Build Next.js app
npm run lint                   # ESLint (Google style + TypeScript + Next.js rules)
firebase deploy                # Deploy Firestore rules + Functions + Hosting
firebase deploy --only functions  # Deploy only Cloud Functions
```

### Environment Variables
- **Required client vars** (prefixed `NEXT_PUBLIC_`): `FIREBASE_API_KEY`, `FIREBASE_PROJECT_ID`, `FIREBASE_AUTH_DOMAIN`, `FIREBASE_APP_ID`, `FIREBASE_STORAGE_BUCKET`, `FIREBASE_MESSAGING_SENDER_ID`
- **Server vars**: Set `FIREBASE_SERVICE_ACCOUNT` (JSON or base64) or `GOOGLE_APPLICATION_CREDENTIALS`
- **PWA**: `NEXT_PUBLIC_ENABLE_SW=true` enables service worker in dev; defaults to production-only
- Use `.env` locally (template: `.env.example`); never commit secrets

### Testing & Debugging
- **ESLint config** ([.eslintrc.cjs](../.eslintrc.cjs)): Google style, strict TypeScript, relaxed on line-ending/max-length
- **TypeScript**: `strict: true` in [tsconfig.json](../tsconfig.json); use path aliases (`@/*` → root)
- **Firebase emulators**: Test auth, Firestore rules locally before deploying
- **Build logs**: Check `build.log` for detailed compilation errors

## Code Patterns & Conventions

### Component Organization
- **Client components**: Mark with `'use client'` at the top; use React hooks freely
- **Server components**: Default for layouts, page roots, and data-fetching parents
- **Auth context**: Import `useAuthContext()` only in client components; check `loading` state before rendering protected UI
- **Example component path**: `src/components/features/{feature-name}/{ComponentName}.tsx`

### Typing & Data Validation
- **Schema**: Import from [src/types/schema.ts](../src/types/schema.ts) for domain types
- **Validation**: Use Zod ([package.json](../package.json) has `zod: ^3.23.8`) for API request/response validation
- **User types**: [src/types/user.ts](../src/types/user.ts) defines `UserProfile` and `UserRole`

### Firebase Best Practices
1. **Always scope by site**: Include `siteId` in queries (`where('siteId', '==', siteId)`)
2. **Use batch writes** for multi-doc atomicity; avoid writing documents sequentially
3. **Leverage Firestore indexes**: Composite queries (e.g., `siteId + status + date`) need indexes in production
4. **Real-time sync**: Use `useCollection()` / `useDocument()` hooks for auto-subscription cleanup; manually call `unsubscribe()` if using raw `onSnapshot()`
5. **Timestamp consistency**: Store all dates as Firestore `Timestamp`; parse to `Date` on client

### Styling
- **Tailwind CSS**: Leverage utility-first classes; see `globals.css` for global resets
- **Icon library**: Use `lucide-react` for icons (e.g., `<CheckIcon className="w-5 h-5" />`)
- **Component UI kit**: Headless UI provides unstyled, accessible primitives (Listbox, Popover, etc.)
- **Class merging**: Use `clsx()` and `tailwind-merge` to safely combine Tailwind classes

### Internationalization (i18n)
- **Translation files**: `locales/{locale}.json` (e.g., `locales/en.json`)
- **Server-side retrieval**: `getTranslations(locale, namespace)` in [lib/i18n.ts](../lib/i18n.ts); cached per locale
- **Dynamic namespace switching**: Pass namespace as parameter; no client-side loading
- **Fallback handling**: Dot-notation keys (e.g., `dashboard.welcome`) return `undefined` if missing; handle gracefully

## Common Gotchas & Solutions

| Issue | Solution |
|-------|----------|
| **Role check in Client Component** | Use `useAuthContext().profile?.role` after `loading === false` |
| **Firestore rule fails silently** | Enable debug logging in Firebase Console; check `getUserData()` costs |
| **Batch write exceeds 500 docs** | Split into multiple batch operations |
| **Type mismatch between Firestore + local** | Ensure `Timestamp` fields match in schema; convert on read |
| **Service worker caches stale assets** | Clear public/sw.js or set `NEXT_PUBLIC_ENABLE_SW=false` to bypass |
| **Locale not prepending to URL** | Middleware redirects missing locales to `/en`; verify not in skip list |
| **Missing env vars at build time** | Vercel/Cloud Run needs `NEXT_PUBLIC_*` in project config; non-public vars in secrets |

## Key Files & Their Purposes

| File | Purpose |
|------|---------|
| [schema.ts](../schema.ts) | Core domain types (User, Session, Enrollment, etc.) |
| [proxy.ts](../proxy.ts) | Locale routing enforcement |
| [src/firebase/client-init.ts](../src/firebase/client-init.ts) | Firebase client SDK initialization |
| [src/firebase/admin-init.ts](../src/firebase/admin-init.ts) | Firebase Admin SDK setup (server-side) |
| [firestore.rules](../firestore.rules) | Firestore security rules |
| [src/firebase/auth/AuthProvider.tsx](../src/firebase/auth/AuthProvider.tsx) | Global auth state provider |
| [scheduler.ts](../scheduler.ts) | Session + occurrence batch creation pattern |
| [tailwind.config.js](../tailwind.config.js) | TailwindCSS customization |
| [next.config.mjs](../next.config.mjs) | Next.js config + PWA setup |

## Evolving the Platform

### Feature Specification Gate

When building or changing any feature, do not treat the work as sufficiently specified until these questions are answered explicitly in the implementation plan, code path, or release notes:

1. **Which capability nodes does this touch?**
2. **What evidence is created here?**
3. **Who can submit or observe that evidence?**
4. **How is authenticity verified?**
5. **How does this update learner growth over time?**
6. **How does it appear in the portfolio?**
7. **How does it affect the Passport/report output?**
8. **What is the fallback if no evidence exists yet?**
9. **What does the teacher do in under 10 seconds during live class?**
10. **What happens on mobile in the classroom?**

If these questions are unanswered, the feature is underspecified and should not be treated as done.

Additional product guardrails:
- Do not present assignment completion, mission completion, XP, level, averages, or attendance as capability mastery.
- Do not ship dashboards or reports that make learner claims without evidence provenance.
- Do not ship rubric flows unless rubric outcomes can connect to capability updates or clearly remain pending.
- Do not ship portfolio surfaces that cannot explain which evidence or artifact belongs there.
- Do not ship AI assistance features without disclosure, verification intent, and an auditable trail.
- Prefer live teacher workflows that minimize taps during studio time over admin-heavy workflows that require later cleanup.

### Gold-Ready Release Gate

Do not describe Scholesa as gold-ready, production-ready for capability-first release, or equivalent unless all of these workflows are verified end-to-end with real data:

1. Curriculum admin can define capabilities and map them to units/checkpoints.
2. Teacher can run a session and quickly log capability observations during build time.
3. Student can submit artifacts, reflections, and checkpoint evidence.
4. Teacher can apply a 4-level rubric tied to capabilities and process domains.
5. Proof-of-learning can be captured and reviewed.
6. Capability growth updates over time from evidence.
7. Student portfolio shows real artifacts and reflections.
8. Ideation Passport/report can be generated from actual evidence.
9. AI-use is disclosed and visible where relevant.
10. Family/student/teacher views are understandable and trustworthy.

If any one of these workflows is unverified, stubbed, disconnected, workflow-only, or dependent on manual cleanup outside the product, the platform is not gold-ready.

When adding new features:
1. **Define schema** in [schema.ts](../schema.ts) first
2. **Add Firestore rules** for the new collection (follow existing patterns)
3. **Create Server/Client components** in `src/components/` respecting auth & locale contexts
4. **Use Zod** for API validation
5. **Test with Firebase emulators** before deploying to production
6. **Document role-based flows** if access is restricted

---

**Last updated**: December 23, 2025  
For questions on architecture or patterns, refer to `SCHOLESA_SUPREME_MASTER_VIBE.md` for platform vision.
