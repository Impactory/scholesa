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

Classification: `Full-flow partial`

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
5. Gate F `Accessibility And Discoverability`
   - refresh and retry controls are labeled and failure copy is explicit in the route UI

Missing gates:

1. Gate G `Telemetry And Auditability`
   - telemetry exists in the implementation, but direct proof of schedule-create auditability is still missing
2. Gate H `Educational Truth`
   - this operational route does not make capability claims itself, but its downstream relationship to attendance and evidence-bearing session workflows is not yet certified
3. Gate I `AI Transparency`
   - no AI claim is made on the route, but wider workflow coupling is still outside this focused route proof

Blocking risk:

- `/site/sessions` now directly proves honest loading, stale recovery, create persistence, authoritative reload, create failure, and route-level role gating. Remaining risk is no longer the page's create path or route gate itself; it is wider site workflow coupling with provisioning, attendance, and other downstream evidence-bearing surfaces.

Next proof task:

1. Audit `/site/provisioning` to the same mutation-and-reload depth.
2. Verify downstream attendance or session-linked evidence workflows consume the persisted session state without introducing fake completion.
3. Add direct auditability proof for schedule-create telemetry or operator trace where the product depends on that record.

## Route: `/site/provisioning`

Classification: `Full-flow partial`

Proven gates:

1. Gate A `State Truth`
   - direct proof exists for learner-tab first-load failure and stale-after-success visibility
2. Gate B `Real Mutation`
   - direct route proof now exists for learner creation, parent creation, guardian-link creation, active-site guardian-link deletion, cohort-launch creation, learner edit persistence, and parent edit persistence
3. Gate D `Recovery`
   - retry and refresh controls are directly proven for learner-tab failure and stale-after-success states
4. Gate E `Scope And Permission Correctness`
   - direct route proof now exists that `/site/provisioning` only allows `site` and `hq` roles
5. Gate F `Accessibility And Discoverability`
   - the route keeps explicit load-failure copy and labeled retry controls visible in the focused proof

Missing gates:

1. Gate C `Authoritative Reload`
   - cohort creation reloads through the bridge, but the wider route does not yet have direct focused proof that all create and edit paths re-query the authoritative source instead of relying only on in-memory mutation
2. Gate G `Telemetry And Auditability`
   - telemetry exists in implementation, but direct proof of provisioning auditability is still missing
3. Gate H `Educational Truth`
   - this administrative route does not itself claim mastery or growth, but downstream evidence-bearing workflows that depend on provisioning are not yet certified here
4. Gate I `AI Transparency`
   - no AI claim is made on the route, but wider downstream workflow coupling remains outside the focused proof

Blocking risk:

- `/site/provisioning` now directly proves honest learner-tab loading, stale recovery, core create mutations across all four tabs, active-site guardian-link deletion, and route-level access control. Remaining risk is edit/failure/auditability depth and downstream coupling, not whether the route’s primary provisioning actions exist.

Next proof task:

1. Add focused failure-path proof for learner, parent, guardian-link, and cohort mutations.
2. Add direct auditability proof where provisioning writes are expected to leave operator traces.
3. Verify downstream attendance, family access, and other site workflows consume the persisted provisioning state without fake completion.

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