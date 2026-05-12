# Gold Workflow Bug Coverage Matrix - 2026-05-10

Status: Coverage plan and execution matrix. Not a gold certification.

This file defines how every active workflow must be covered before gold. A workflow is not covered because its route renders. It is covered only when route access, persistence, site scoping, evidence provenance, mobile usability, accessibility, loading/empty/error states, telemetry, and downstream evidence-chain effects are verified.

## Bug Classes

Every workflow row below must be tested against these bug classes.

| Code | Bug class | Gold failure mode |
| --- | --- | --- |
| RENDER | Route render and resilience | Page crashes, error boundary appears, stale section remains broken, or public/protected route resolves incorrectly. |
| AUTHZ | Role and site authorization | Wrong role or wrong site can read/write data, or allowed role is blocked. |
| CONSENT | Consent and data-sharing boundary | Parent, partner, media, report, or Passport share exposes data without explicit consent/provenance or fails to honor revocation. |
| PERSIST | Real persistence | UI action does not create/update the canonical Firestore/Storage/Callable record. |
| PROVENANCE | Evidence provenance | Record lacks learner, site, session occurrence, capability, proof, rubric, growth, portfolio, or audit linkage. |
| SAFETY | Capability-first safety | Completion, attendance, XP, averages, AI support, or engagement is presented as mastery. |
| AI-MODALITY | MiloOS typed/spoken modeling | Typed prompts, spoken transcripts, Web Speech, uploads, telemetry, backend policy, explain-back, or proof records lose source/modality provenance. |
| EMPTY | Loading, empty, stale, and error state | Workflow hides failures, shows fake data, or cannot recover from network/auth/backend errors. |
| THEME | Role UI and theme consistency | Shared or role-local states use ad hoc colors/copy/layouts, break dark theme, or make recovery/status language feel inconsistent across roles. |
| MOBILE | Mobile and native classroom usability | Controls overlap, taps are too slow, offline queue breaks, or media/mic permissions fail. |
| A11Y-I18N | Accessibility and localization | Keyboard, screen reader, contrast, locale copy, or text fitting breaks. |
| TELEMETRY | Audit and observability | Critical action has no audit event, redaction, trace ID, site ID, or failure signal. |

## Workflow Coverage By Role

### Public, Auth, And Common Surfaces

| Surface | Routes | Required bug coverage | Required proof |
| --- | --- | --- | --- |
| Public entry | `/welcome`, `/login`, public Cloud Run origin, `scholesa.com` | RENDER, AUTHZ, EMPTY, THEME, MOBILE, A11Y-I18N | Public route smoke, no protected data, login providers, cache headers, proof-flow video, theme-safe empty/error/loading states. |
| Session/account | `/profile`, `/settings` | RENDER, AUTHZ, PERSIST, EMPTY, THEME, MOBILE, TELEMETRY | Sign-out clears Firebase Auth, app state, recent-login state, and protected navigation. |
| Messaging/notifications | `/messages`, `/notifications` | AUTHZ, PERSIST, PROVENANCE, EMPTY, TELEMETRY | Same-site participant checks, rate-limit feedback, notification request persistence, no cross-site leaks. |

### Learner Workflows

| Workflow | Routes | Required bug coverage | Required proof |
| --- | --- | --- | --- |
| Daily learner evidence loop | `/learner/today` | RENDER, AUTHZ, PROVENANCE, SAFETY, EMPTY, MOBILE | Learner sees current build focus, capability focus, next proof action, and no false mastery claim. |
| Missions and artifacts | `/learner/missions` | PERSIST, PROVENANCE, SAFETY, EMPTY, MOBILE, TELEMETRY | Mission attempt, artifact, reflection, AI disclosure, and proof bundle persist with site and learner scope. |
| Portfolio | `/learner/portfolio` | PERSIST, PROVENANCE, SAFETY, EMPTY, A11Y-I18N | Reviewed artifacts show proof, rubric, growth, evidence IDs, and missing-evidence fallback. |
| Timeline | `/learner/timeline` | PROVENANCE, SAFETY, EMPTY | Timeline includes evidence, reflections, proof bundles, and growth backlinks without duplicate or fake claims. |
| Checkpoints | `/learner/checkpoints` | PERSIST, PROVENANCE, SAFETY, EMPTY | Submitted checkpoints remain reviewable until proof and growth are resolved. |
| Peer feedback | `/learner/peer-feedback` | AUTHZ, PERSIST, PROVENANCE, SAFETY | Peer feedback is same-site, consent-safe, and never becomes mastery without educator review. |
| Proof assembly | `/learner/proof-assembly` | PERSIST, PROVENANCE, SAFETY, MOBILE | Explain-back, oral check, mini-rebuild, and evidence bundle status persist. |
| Reflections | `/learner/reflections` | PERSIST, PROVENANCE, EMPTY | Reflection links to learner, site, capability or mission context, and portfolio/report eligibility. |
| Habits | `/learner/habits` | SAFETY, EMPTY, TELEMETRY | Habit completion remains separate from capability mastery. |
| MiloOS support | `/learner/miloos` | AUTHZ, PROVENANCE, SAFETY, AI-MODALITY, MOBILE, A11Y-I18N, TELEMETRY | AI help is disclosed, explain-back is captured, typed/spoken source is preserved, spoken experience is humanlike, and global FAB does not overlap the page. |

### Educator Workflows

| Workflow | Routes | Required bug coverage | Required proof |
| --- | --- | --- | --- |
| Daily live class | `/educator/today` | RENDER, AUTHZ, PERSIST, PROVENANCE, MOBILE | Educator can complete live evidence action in under 10 seconds on classroom width. |
| Attendance | `/educator/attendance` | AUTHZ, PERSIST, SAFETY, EMPTY | Attendance persists but never becomes capability mastery. |
| Sessions | `/educator/sessions` | AUTHZ, PERSIST, EMPTY | Active session occurrence exists before observations and attendance writes. |
| Learners | `/educator/learners` | AUTHZ, PROVENANCE, EMPTY | Same-site roster and learner detail only; stale data is explicit. |
| Mission review | `/educator/missions/review` | PERSIST, PROVENANCE, SAFETY, TELEMETRY | Review preserves portfolio item/proof linkage and forwards into rubric application. |
| Mission plans | `/educator/mission-plans` | PERSIST, PROVENANCE, EMPTY | Plans are capability-mapped or clearly pending. |
| Learner supports | `/educator/learner-supports` | AUTHZ, PERSIST, SAFETY, TELEMETRY | Support interventions are not exposed as parent-visible mastery. |
| Live evidence capture | `/educator/evidence`, `/educator/observations` | PERSIST, PROVENANCE, SAFETY, MOBILE | Observation includes site, learner, session occurrence, capability, timestamp, and portfolio candidate status. |
| Proof review | `/educator/proof-review`, `/educator/verification` | PERSIST, PROVENANCE, SAFETY, TELEMETRY | Proof verification is an authenticity boundary only and hands off to rubric/growth. |
| Rubric application | `/educator/rubrics/apply` | PERSIST, PROVENANCE, SAFETY, TELEMETRY | 4-level rubric writes growth only through reviewed evidence and canonical portfolio linkage. |
| Educator integrations | `/educator/integrations` | AUTHZ, PERSIST, EMPTY, TELEMETRY | Connected-classroom actions are same-site and audited. |

### Parent And Guardian Workflows

| Workflow | Routes | Required bug coverage | Required proof |
| --- | --- | --- | --- |
| Parent summary | `/parent/summary` | AUTHZ, PROVENANCE, SAFETY, EMPTY | Answers what the learner can do, what evidence proves it, how they are growing, and next step. |
| Billing and schedule | `/parent/billing`, `/parent/schedule` | AUTHZ, PERSIST, EMPTY | Billing and schedule data is household-scoped and fails safely. |
| Portfolio | `/parent/portfolio` | AUTHZ, PROVENANCE, SAFETY, CONSENT | Parent only sees consent-safe artifacts and proof/AI provenance. |
| Growth timeline | `/parent/growth-timeline` | AUTHZ, PROVENANCE, SAFETY | Growth claims link to evidence and rubric/growth events. |
| Passport | `/parent/passport` | AUTHZ, PROVENANCE, SAFETY, CONSENT, TELEMETRY | Export/share claims are evidence-backed, parent-safe, and explain missing evidence. |

### Site And Admin-School Workflows

| Workflow | Routes | Required bug coverage | Required proof |
| --- | --- | --- | --- |
| Check-in/out | `/site/checkin` | AUTHZ, PERSIST, EMPTY, MOBILE, TELEMETRY | Arrival/departure, pickup authorization, and stale failure states are correct. |
| Provisioning | `/site/provisioning`, `/site/identity` | AUTHZ, PERSIST, THEME, TELEMETRY | Users, families, claims, and site membership are reconciled and audited; identity resolution success/warning/error feedback uses semantic theme tokens. |
| Site dashboard and ops | `/site/dashboard`, `/site/ops` | RENDER, PROVENANCE, EMPTY, THEME, TELEMETRY | Dashboard shows implementation health and evidence readiness, not just totals; stale-data and status states use semantic theme tokens. |
| Sessions | `/site/sessions` | AUTHZ, PERSIST, EMPTY | Session creation produces occurrences and educator/site scoping. |
| Incidents | `/site/incidents` | AUTHZ, PERSIST, TELEMETRY | Incident lifecycle is audited and permission-safe. |
| Integrations | `/site/clever`, `/site/integrations-health` | AUTHZ, PERSIST, EMPTY, TELEMETRY | Sync state and failures are explicit; no silent roster corruption. |
| Billing | `/site/billing` | AUTHZ, PERSIST, EMPTY | Site billing is not visible to unrelated roles/sites. |
| Evidence health | `/site/evidence-health` | PROVENANCE, SAFETY, EMPTY | Evidence coverage shows provenance health and capture readiness, not vanity totals. |

### Partner Workflows

| Workflow | Routes | Required bug coverage | Required proof |
| --- | --- | --- | --- |
| Listings | `/partner/listings` | AUTHZ, PERSIST, EMPTY | Listing management is partner/HQ-scoped and audited. |
| Contracts | `/partner/contracts` | AUTHZ, PERSIST, TELEMETRY | Contract approval path is permission-safe. |
| Deliverables | `/partner/deliverables` | AUTHZ, PERSIST, PROVENANCE | Deliverables do not expose learner data unless consent and evidence provenance allow it. |
| Integrations | `/partner/integrations` | AUTHZ, PERSIST, EMPTY | Partner integrations cannot mutate school evidence directly. |
| Payouts | `/partner/payouts` | AUTHZ, PERSIST, TELEMETRY | Payout data is partner/HQ-scoped. |

### Admin-HQ Workflows

| Workflow | Routes | Required bug coverage | Required proof |
| --- | --- | --- | --- |
| User and role admin | `/hq/user-admin`, `/hq/role-switcher` | AUTHZ, PERSIST, TELEMETRY | Role simulation and claims edits are HQ-only and audited. |
| Sites | `/hq/sites` | AUTHZ, PERSIST, EMPTY | Site creation and edits do not break site scoping. |
| Analytics | `/hq/analytics` | PROVENANCE, SAFETY, THEME, TELEMETRY | Analytics distinguish evidence health from mastery claims; stale-data/status UI uses Scholesa semantic tokens. |
| Billing and approvals | `/hq/billing`, `/hq/approvals` | AUTHZ, PERSIST, TELEMETRY | HQ-only financial and approval workflows are audited. |
| Audit and safety | `/hq/audit`, `/hq/safety` | AUTHZ, EMPTY, TELEMETRY | Audit views are read-only and scoped; safety queues fail closed. |
| Integrations health | `/hq/integrations-health` | AUTHZ, EMPTY, THEME, TELEMETRY | Integration health is global only for HQ, does not expose secrets, and uses semantic status/recovery tokens. |
| Curriculum and capabilities | `/hq/curriculum`, `/hq/capabilities`, `/hq/capability-frameworks` | PERSIST, PROVENANCE, SAFETY | Capabilities, descriptors, checkpoints, units, and rubrics are structurally connected. |
| Rubric builder | `/hq/rubric-builder` | PERSIST, PROVENANCE, SAFETY | Rubric templates map to capabilities or remain explicitly pending. |
| Feature flags | `/hq/feature-flags` | AUTHZ, PERSIST, TELEMETRY | Flags are audited, environment-scoped, and never bypass evidence/security gates. |

## Open Bug Coverage Requirements

Before gold, every P0/P1 bug must have all of these fields in the tracker or release notes:

- Affected route or channel.
- Primary role.
- Evidence-chain step.
- Bug class from this matrix.
- Reproduction data shape.
- Emulator or E2E test that fails before the fix.
- Persistence or rule boundary touched.
- Mobile/native impact.
- Security/privacy impact.
- Fix owner and rollback path.

## Current High-Risk Bugs Or Gaps To Cover

| Gap | Role/channel | Bug class | Required next proof |
| --- | --- | --- | --- |
| Live role canary must verify the newly deployed logout and MiloOS voice revision beyond HTTP probes. | Flutter web/native | RENDER, MOBILE, A11Y-I18N | `empire-web-00088-ln2` serves 100 percent traffic and HTTP probes pass; browser/mobile role smoke is still required before broader live claim. |
| Native distribution proof missing. | iOS, Android, macOS | MOBILE, AUTHZ, PERSIST | TestFlight, Google Play internal, macOS notarization proof; native proof bundle write shape plus callable verification/revision alignment now have focused local Flutter proof. |
| Firestore site-scope hardening still needs a final parity sweep after core provenance, server-owned mastery/growth, AI audit logs, proof self-verification denial, native proof site-scope/review callable alignment, report audit spoofing denial, mission/checkpoint evidence scope, skill/reflection/calibration scope, habits scope, learner goal/profile scope, skill mastery scope, showcase submission scope, learner/guardian profile boundary scope, learner support/assessment boundary scope, mission/portfolio/rubric boundary scope, billing boundary scope, and mission assignment/skill assessment boundary scope. | All roles | AUTHZ | Run a final broad collection/auth parity audit plus live role canary; this pass no longer has a known unpatched collection holdout from the original list. |
| Broader collection/auth parity still needs a full sweep after learner-media, report-share media consent access, report-delivery audit hardening, active report-share provenance consistency, explicit-consent revocation cascade, mission/checkpoint site-scope hardening, skill/reflection/calibration site-scope hardening, habits site-scope hardening, learner goal/profile site-scope hardening, skill mastery site-scope hardening, showcase submission site-scope hardening, learner/guardian profile boundary hardening, learner support/assessment boundary hardening, and mission/portfolio/rubric boundary hardening. | Learner, parent, educator, partner | AUTHZ, CONSENT | Keep Storage emulator owner/guardian/same-site/report-share lifecycle coverage and add live role canary plus final collection parity proof. |
| MiloOS typed/spoken modeling must remain request-modality correct across role and native canaries. | Learner, educator, parent, site | AI-MODALITY, SAFETY, TELEMETRY | Keep typed prompts on the typed intelligence path, spoken/Web Speech/upload transcripts on the strict spoken guardrail path, and prove source/modality in telemetry and explain-back records. |
| Passport/report remains route-specific and partially unified. | Learner, parent, partner | PROVENANCE, SAFETY | Proof self-verification, report audit spoofing, contradictory active share provenance, stale linked shares after consent revocation, and stale report-share media access are denied; next prove live operator fallback. |
| AI disclosure not uniformly attached across every artifact path. | Learner, educator, parent | PROVENANCE, SAFETY, TELEMETRY | AI audit logs are site-scoped; artifact creation paths still must persist prompt, suggestion, learner change, explain-back, and proof linkage where AI materially helped. |
| Cloud Run target identity can be confused by project number mismatch. | Ops | RENDER, TELEMETRY | Explicit project/service checks before deploy and live probe after deploy. |

## Coverage Exit Rule

No workflow can be marked covered until its row has passing proof for every required bug class and a documented fallback for no evidence, unavailable services, and mobile classroom use.