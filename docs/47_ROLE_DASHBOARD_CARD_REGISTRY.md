# 47_ROLE_DASHBOARD_CARD_REGISTRY.md
Role Dashboard Card Registry (single source of truth)

Purpose: give Codex/Gemini a **concrete, non-ambiguous** list of dashboard widgets (“cards”) per role, including:
- card id
- title/subtitle intent
- primary collections/data used (read/write)
- primary actions (routes and mutations)
- doc sources (which specs justify the card)
- compile-safety constraints (no new deps in `role_dashboards.dart`)

**Design language lock:** dashboards must use the current Scholesa design language (Material Cards/ListTiles, existing tokens). No reskin.

---

## 0) Implementation rule
### Dashboards are configuration, not bespoke screens
- `role_dashboards.dart` should only render:
  - a list of card definitions filtered by role
  - navigation to feature modules (routes)
  - “not wired yet” snackbars when routes are not enabled
- No Firestore queries in the dashboard widget itself.

This prevents build failures while features are implemented incrementally.

---

## 1) Card registry (canonical)

### Shared (all roles)
| Card ID | Title | Primary data | Primary actions | Source docs |
|---|---|---|---|---|
| messages | Messages | `MessageThread`, `Message`, `Notification` | open thread, reply, report | `17_MESSAGING_NOTIFICATIONS_SPEC.md`, `02A_SCHEMA_V3.ts` (Messaging) |
| notifications | Notifications | `Notification` | mark read, deep link | `17_MESSAGING_NOTIFICATIONS_SPEC.md`, `02A_SCHEMA_V3.ts` (Notifications) |

---

## 2) Learner dashboard
| Card ID | Title | Primary data | Primary actions | Source docs |
|---|---|---|---|---|
| learner_today | Today | `SessionOccurrence`, `Enrollment` | open today schedule | `44_SCHEDULING_CALENDAR_ROOMS_SPEC.md`, `02A_SCHEMA_V3.ts` (sessions/occurrences) |
| learner_missions | My Missions | `MissionPlan`, `MissionAttempt`, `MissionSnapshot` | start/continue/submit attempt | `01_SUPREME_SPEC_EMPIRE_PLATFORM.md`, `45_CURRICULUM_VERSIONING_RUBRICS_SPEC.md`, `02A_SCHEMA_V3.ts` |
| learner_habits | Habit Coach | habit engine entities + `TelemetryEvent` | do-now, snooze, reflect | `21_PILLAR_HABIT_ENGINE_POPUPS_SPEC.md`, `22_LEARNER_INTELLIGENCE_PERSONALIZATION_SPEC.md` |
| learner_portfolio | Portfolio | `PortfolioItem`, `Credential` | add highlight, share parent-safe | `01_SUPREME_SPEC_EMPIRE_PLATFORM.md`, `02A_SCHEMA_V3.ts` |

---

## 3) Educator dashboard
| Card ID | Title | Primary data | Primary actions | Source docs |
|---|---|---|---|---|
| educator_today_classes | Today’s Classes | `SessionOccurrence`, `Room` | open roster/plan | `44_SCHEDULING_CALENDAR_ROOMS_SPEC.md`, `02A_SCHEMA_V3.ts` |
| educator_attendance | Take Attendance | `Enrollment`, `AttendanceRecord` | mark present/late/absent + note | `02A_SCHEMA_V3.ts` (attendance) |
| educator_plan | Plan Missions | `Mission`, `MissionPlan`, `MissionSnapshot` | create/edit plan, duplicate | `01_SUPREME_SPEC_EMPIRE_PLATFORM.md`, `45_CURRICULUM_VERSIONING_RUBRICS_SPEC.md` |
| educator_review_queue | Review Queue | `MissionAttempt`, `Rubric`, `RubricApplication` | review, rubric apply, mark reviewed | `45_CURRICULUM_VERSIONING_RUBRICS_SPEC.md`, `23_TEACHER_SUPPORT_INSIGHTS_SPEC.md` |
| educator_supports | Learner Supports | teacher-only insights entities | add supports-to-try, what-worked | `22_LEARNER_INTELLIGENCE_PERSONALIZATION_SPEC.md`, `23_TEACHER_SUPPORT_INSIGHTS_SPEC.md` |
| educator_integrations | Integrations | `IntegrationConnection`, `ExternalCourseLink`, `SyncJob`, `GitHubConnection` | connect, link course, sync roster, attach mission, push grade summary | `33_CLASSROOM_ADDON_PRODUCT_SPEC.md`, `36_INTEGRATIONS_INTERNAL_API_CONTRACT.md`, `39_OAUTH_SCOPES_BUNDLES_CLASSROOM_ADDON.md`, `40_GITHUB_APP_PERMISSIONS_MATRIX_AND_OAUTH_FALLBACK.md`, `02A_SCHEMA_V3.ts` |

---

## 4) Parent dashboard (parent-safe boundary)
| Card ID | Title | Primary data | Primary actions | Source docs |
|---|---|---|---|---|
| parent_child_summary | Child Summary | parent-safe summary view derived from attempts/attendance (no teacher-only insights) | view weekly summary | `24_DATA_PRIVACY_SAFETY_FOR_LEARNER_INTELLIGENCE.md`, `41_SAFETY_CONSENT_INCIDENTS_SPEC.md` |
| parent_schedule | Schedule | `SessionOccurrence` (read-only) | view upcoming | `44_SCHEDULING_CALENDAR_ROOMS_SPEC.md` |
| parent_portfolio | Portfolio Highlights | parent-visible `PortfolioItem` subset + consent gates | open artifact | `41_SAFETY_CONSENT_INCIDENTS_SPEC.md`, `02A_SCHEMA_V3.ts` |
| parent_billing | Billing | `Order`, `Invoice` | view receipts, payment status | `13_PAYMENTS_BILLING_SPEC.md`, `02A_SCHEMA_V3.ts` |

Non-negotiable:
- Never show teacher-only intelligence collections to parents.
- GuardianLink creation remains admin-only.

---

## 5) Site dashboard (physical operations hub)
| Card ID | Title | Primary data | Primary actions | Source docs |
|---|---|---|---|---|
| site_ops_today | Today Operations | occurrences today + ops status | open/close day | `42_PHYSICAL_SITE_CHECKIN_CHECKOUT_SPEC.md`, `44_SCHEDULING_CALENDAR_ROOMS_SPEC.md` |
| site_checkin_checkout | Check-in / Check-out | `SiteCheckInOut`, `PickupAuthorization`, `MediaConsent` | scan QR, check-in/out, validate pickup | `42_PHYSICAL_SITE_CHECKIN_CHECKOUT_SPEC.md`, `41_SAFETY_CONSENT_INCIDENTS_SPEC.md` |
| site_provisioning | Provisioning | `User`, `LearnerProfile`, `ParentProfile`, `GuardianLink` | create users, link parent↔learner, admin-only fields | `06_SECURITY_ACCESS_ADMIN_PROVISIONING.md`, `02A_SCHEMA_V3.ts` |
| site_incidents | Safety & Incidents | `IncidentReport` | review/close/escalate | `41_SAFETY_CONSENT_INCIDENTS_SPEC.md` |
| site_identity_resolution | Identity Resolution | `ExternalIdentityLink` + provider links | approve match, ignore, request merge | `46_IDENTITY_MATCHING_RESOLUTION_SPEC.md`, `02A_SCHEMA_V3.ts` |
| site_integrations_health | Integrations Health | `SyncJob`, `IntegrationConnection`, `GitHubWebhookDelivery` | retry, reconnect | `31_GOOGLE_CLASSROOM_SYNC_JOBS.md`, `37_GITHUB_WEBHOOKS_EVENTS_AND_SYNC.md` |
| site_billing | Site Billing | `Subscription`, `Invoice`, `EntitlementGrant` | view status, plan changes via billing flow | `13_PAYMENTS_BILLING_SPEC.md` |

---

## 6) Partner dashboard
| Card ID | Title | Primary data | Primary actions | Source docs |
|---|---|---|---|---|
| partner_listings | Listings | `MarketplaceListing` | create/edit/submit | `15_LMS_MARKETPLACE_SPEC.md` |
| partner_contracts | Contracts | `PartnerContract`, `PartnerDeliverable` | submit deliverable, respond to review | `16_PARTNER_CONTRACTING_WORKFLOWS_SPEC.md` |
| partner_payouts | Payouts | `Payout` | view status/history | `16_PARTNER_CONTRACTING_WORKFLOWS_SPEC.md` |

---

## 7) HQ dashboard
| Card ID | Title | Primary data | Primary actions | Source docs |
|---|---|---|---|---|
| hq_user_admin | User Administration | `User`, `Site`, `AuditLog` | role updates, suspend/reactivate | `06_SECURITY_ACCESS_ADMIN_PROVISIONING.md`, `02A_SCHEMA_V3.ts` |
| hq_approvals | Approvals Queue | `MarketplaceListing`, `PartnerContract`, `Payout` | approve/reject | `15_LMS_MARKETPLACE_SPEC.md`, `16_PARTNER_CONTRACTING_WORKFLOWS_SPEC.md` |
| hq_audit_logs | Audit & Logs | `AuditLog`, export records | review exports, compliance | `43_EXPORT_RETENTION_BACKUP_SPEC.md`, `02A_SCHEMA_V3.ts` |
| hq_safety_oversight | Safety Oversight | `IncidentReport` (major/critical) | escalate, export | `41_SAFETY_CONSENT_INCIDENTS_SPEC.md`, `43_EXPORT_RETENTION_BACKUP_SPEC.md` |
| hq_billing_admin | Billing Admin | `BillingAccount`, `Subscription`, `EntitlementGrant` | suspend entitlements, delinquency ops | `13_PAYMENTS_BILLING_SPEC.md` |
| hq_integrations_health | Integrations Health | `SyncJob` failures across sites | throttle/retry/disable provider | `31_GOOGLE_CLASSROOM_SYNC_JOBS.md` |

---

## 8) Route wiring contract (compile safety)
In `role_dashboards.dart`:
- Maintain a `kKnownRoutes` map.
- A card may list a route, but dashboard must not crash if route is not registered yet.
- Only flip to enabled when the screen exists.

Example:
- `'/hq/user-admin'` enabled
- all others start disabled until implemented

---

## 9) Dashboard testing checklist
- For each role:
  - shows only role-allowed cards
  - tapping an unwired card shows a SnackBar and does not throw
  - logout clears role and returns to login
- Regression: no theme/token changes

---

## 10) Implementation sequence (recommended)
1) Wire shared messaging + notifications (if already implemented)
2) Educator: today classes + attendance + review queue
3) Site: provisioning + check-in/out + incidents
4) Learner: missions + habit coach + portfolio
5) Integrations: Classroom add-on and GitHub link-based
6) HQ: approvals + audit + billing admin
