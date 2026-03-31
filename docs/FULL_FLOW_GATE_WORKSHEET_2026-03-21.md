# Full-Flow Gate Worksheet

Last updated: 2026-03-21
Purpose: record route and workflow reviews using the explicit output format from `docs/FULL_FLOW_CERTIFICATION_GATE_2026-03-21.md`.

## Route: `/hq/feature-flags`

Classification: `Full-flow verified`

Proven gates:

1. Gate A `State Truth`
   - direct proof exists for empty, unavailable, stale-after-success, and failed-save states on feature flags and experiments
2. Gate B `Real Mutation`
   - direct proof exists for feature-flag toggle persistence and failed-save handling
   - direct proof now exists for rollout-alert triage successful save behavior and explicit backend-failure handling
   - direct proof now exists for rollout-control validation, successful save behavior, and explicit backend-failure handling
   - direct proof now exists for rollout-escalation validation, successful save behavior, and explicit backend-failure handling
3. Gate C `Authoritative Reload`
   - direct proof now exists that rollout-alert triage save triggers authoritative experiment reload
   - direct proof now exists that rollout-control save triggers authoritative experiment reload
   - direct proof now exists that rollout-escalation save triggers authoritative experiment reload
4. Gate D `Recovery`
   - app-bar refresh exists and stale states preserve last successful data with visible failure detail
5. Gate E `Scope And Permission Correctness`
   - direct route proof now exists that `/hq/feature-flags` is RoleGate-bound to HQ users
   - direct dialog proof now exists that rollout alert, escalation, and control actions surface HQ-bounded delivery context before save
6. Gate F `Accessibility And Discoverability`
   - stale warnings are assistive-tech visible and app-bar controls are labeled
7. Gate G `Telemetry And Auditability`
   - refresh and history app-bar actions emit telemetry; rollout governance surfaces expose audit and history dialogs in implementation
   - direct proof now exists that the alert-history surface reflects saved rollout-triage, rollout-control, and rollout-escalation state
   - direct proof now exists that the rollout-audit dialog renders saved alert, control, and escalation audit events for the targeted delivery scope
8. Gate H `Educational Truth`
   - direct route proof now exists that rollout status is explicitly separated from learner growth, capability mastery, portfolio evidence, and Passport claims
9. Gate I `AI Transparency`
   - direct route proof now exists that rollout status is explicitly separated from AI-use disclosure and points operators back to evidence-bearing surfaces

Missing gates:

1. None at the focused route level under the current certification gate.
   - Wider federated-learning governance still needs workflow-level certification outside this single route before any gold-ready claim.

Blocking risk:

- The route now directly proves HQ-only access, HQ-bounded delivery context, rollout-alert triage, rollout-control, and rollout-escalation mutation behavior across success, validation, reload, and backend-failure paths, and it explicitly separates rollout state from learner-evidence and AI-disclosure claims. Remaining risk is now outside this single route: wider federated-learning governance workflow coupling and gold-ready evidence requirements.

Next proof task:

1. Keep `/hq/feature-flags` marked `Full-flow verified` at the route level and move the next audit pass to cross-route federated-learning workflow coupling.
2. Prove that upstream and downstream governance surfaces consuming this state preserve the same educational-truth and AI-transparency boundary.
3. Do not upgrade to `Gold-ready` until the wider federated-learning workflow is verified end to end with real evidence provenance.

## Route: `/site/sessions`

Classification: `Full-flow verified`

Last updated: 2026-03-31

Proven gates:

1. Gate A `State Truth`
   - direct proof exists for first-load failure, date-based reload, and stale-after-success schedule refresh behavior
2. Gate B `Real Mutation`
   - direct route proof now exists that the primary create action persists a new session record for the active site
3. Gate C `Authoritative Reload`
   - direct route proof now exists that the page re-reads source-of-truth schedule data after create instead of relying only on optimistic local reflection
4. Gate D `Recovery`
   - refresh and retry controls are directly proven for load failure and stale-after-success states
5. Gate E `Scope And Permission Correctness`
   - direct route proof now exists that `/site/sessions` only allows `site` and `hq` roles and that the `/site/scheduling` alias redirects back to the canonical route
6. Gate F `Accessibility And Discoverability`
   - refresh and retry controls are labeled and failure copy is explicit in the route UI
7. Gate G `Telemetry And Auditability`
   - direct route proof now exists that the primary session create action emits a `cta.clicked` audit trace with `cta_id: 'submit_create_session'`
8. Gate H `Educational Truth`
   - direct route proof now exists that the capability coverage banner is session-planning scope only (HQ mapping requests) and that the route shows no learner capability mastery, growth level, Passport, or portfolio evidence claims
9. Gate I `AI Transparency`
   - direct route proof now exists that the sessions schedule surface presents no AI-generated output as verified learner proof; the route is a planning tool with no AI assistance

Missing gates:

None at the focused route level.

Blocking risk:

- `/site/sessions` now directly proves all 9 gates. Remaining risk is downstream coupling between the persisted session state and attendance, evidence-bearing session, and other site workflows, not whether the sessions route itself is honest.

Next proof task:

1. Audit `/site/provisioning` to the same full-flow depth.
2. Verify downstream attendance or session-linked evidence workflows consume the persisted session state without introducing fake completion.

## Route: `/site/provisioning`

Classification: `Full-flow verified`

Last updated: 2026-03-31

Proven gates:

1. Gate A `State Truth`
   - direct proof exists for learner-tab first-load failure and stale-after-success visibility
2. Gate B `Real Mutation`
   - direct route proof now exists for learner creation, parent creation, guardian-link creation, active-site guardian-link deletion, cohort-launch creation, learner edit persistence, parent edit persistence, and explicit create/edit/delete mutation failure handling
3. Gate C `Authoritative Reload`
   - direct route proof now exists that learner create, parent edit, and guardian-link delete flows re-read authoritative route data before success UI settles, rather than trusting only local mutation state
4. Gate D `Recovery`
   - retry and refresh controls are directly proven for learner-tab failure and stale-after-success states
5. Gate E `Scope And Permission Correctness`
   - direct route proof now exists that `/site/provisioning` only allows `site` and `hq` roles
6. Gate F `Accessibility And Discoverability`
   - the route keeps explicit load-failure copy and labeled retry controls visible in the focused proof
7. Gate G `Telemetry And Auditability`
   - direct route proof now exists for learner create, parent edit, and guardian-link delete CTA telemetry traces
8. Gate H `Educational Truth`
   - direct route proof now exists that the provisioning surface is an administrative roster tool and shows no learner capability mastery, growth level, Passport, or portfolio evidence claims alongside administrative records
9. Gate I `AI Transparency`
   - direct route proof now exists that the provisioning surface presents no AI-generated output as verified learner proof; provisioning is a purely administrative tool with no AI assistance

Missing gates:

None at the focused route level.

Blocking risk:

- `/site/provisioning` now directly proves all 9 gates. Remaining risk is downstream coupling between provisioned roster state and attendance, family access, and other evidence-bearing workflows, not whether the provisioning route’s own actions are honest.

Next proof task:

1. Verify downstream attendance, family access, and other site workflows consume the persisted provisioning state without fake completion.

## Route: `/educator/attendance`

Classification: `Full-flow verified`

Last updated: 2026-03-31

Proven gates:

1. Gate A `State Truth`
   - direct proof exists for first-load failure and stale-after-success visibility on the attendance list and roster
2. Gate B `Real Mutation`
   - direct route proof now exists that attendance save persists records to Firestore on the live path, fails with explicit route copy on backend failure, and queues truthfully when offline instead of faking a live save
3. Gate C `Authoritative Reload`
   - direct route proof now exists that reopening the roster re-reads saved attendance from Firestore rather than trusting only local widget state
4. Gate D `Recovery`
   - refresh and retry controls are directly proven for first-load failure and stale-after-success states, and offline save behavior degrades truthfully into queueing rather than silent loss
5. Gate E `Scope And Permission Correctness`
   - direct route proof now exists that `/educator/attendance` only allows `educator`, `site`, and `hq` roles
6. Gate F `Accessibility And Discoverability`
   - recovery controls are labeled and stale-state messaging is assistive-tech visible in the audited attendance surfaces
7. Gate G `Telemetry And Auditability`
   - direct route proof now exists that the primary attendance save emits the `attendance_save` CTA trace, that live saves emit `attendance.recorded`, and that offline saves emit `attendance.record_queued`
8. Gate H `Educational Truth`
   - direct route proof now exists that the attendance surface records presence only and shows no learner capability mastery, growth level, Passport, or portfolio evidence claims alongside attendance data
9. Gate I `AI Transparency`
   - direct route proof now exists that the attendance surface presents no AI-generated output as verified learner proof; attendance is purely manual educator input with no AI assistance

Missing gates:

None at the focused route level.

Blocking risk:

- `/educator/attendance` now directly proves all 9 gates. Remaining risk is downstream coupling between attendance truth and subsequent evidence-bearing session or learner-growth workflows, not whether the attendance route itself is honest.

Next proof task:

1. Certify that downstream session-linked evidence workflows consume persisted attendance state without introducing false completion or misleading learner-growth claims.

## Template

Route or workflow:

Classification: `Misleading or unsafe` | `Operationally honest` | `Full-flow partial` | `Full-flow verified` | `Gold-ready`

Proven gates:

1. ...

Missing gates:

1. ...

Blocking risk:

- ...

Next proof task:

1. ...