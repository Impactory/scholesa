# 37_GITHUB_WEBHOOKS_EVENTS_AND_SYNC.md
GitHub webhooks: what to subscribe to, how to verify, how Scholesa uses them

GitHub webhooks send HTTP POST payloads when events occur. You must have admin access to configure them, and you can create them via REST API. citeturn1search6turn1search3

---

## 1) Webhook endpoint
`POST /api/integrations/github/webhooks`

### Security
- Verify signature for every delivery.
- Reject unknown repos/installations.
- Log delivery id + event type for idempotency.

GitHub provides webhook best practices and troubleshooting guidance. citeturn1search9

---

## 2) Minimal event set (recommended)
Subscribe to:
- `push` (activity signal)
- `pull_request` (PR opened/updated/merged)
- `issues` (if you use issue-based checklists)
- `check_suite` / `check_run` (CI results, optional)

---

## 3) How Scholesa uses webhook signals
Webhook events should not “grade automatically”.
They drive:
- student nudges (“Nice! You pushed code—add a reflection screenshot.”)
- teacher insights (“Learner stuck: no pushes in 7 days”)
- portfolio prompts (“Your PR merged—capture what you learned.”)

All nudges feed the pillars habit engine, but remain aligned with your accountability cycle.

---

## 4) Storage mapping
Store:
- repo ↔ learner/session link (ExternalRepoLink)
- last delivery id / last seen SHA to avoid duplicate processing
- summarized progress metrics, not full code content
