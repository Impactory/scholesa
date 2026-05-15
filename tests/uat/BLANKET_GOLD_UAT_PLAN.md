# Blanket Gold UAT Plan

Scholesa UAT is not a generic QA checklist. It exists to prove that real Learners can do meaningful future-ready work, Educators can coach and assess growth, Families can understand progress, Admins can trust the system, optional Mentors can support Showcase readiness, MiloOS Coach is safe and auditable, and Evidence becomes Portfolio-worthy proof of Capability.

## Automated Blanket-Gold Gate

Run the full automated gate with:

```bash
npm run test:uat:blanket-gold
```

The same gate is available in GitHub Actions as **Blanket Gold UAT**. Use the manual workflow dispatch before any live blanket-gold claim, and review the uploaded audit artifacts when present.

Kubernetes has two gates:

```bash
npm run qa:k8s:manifests
npm run qa:k8s:live
```

`qa:k8s:manifests` is part of the automated blanket-gold command and verifies the committed Kubernetes platform manifests render with the expected Deployments, HPAs, PodDisruptionBudgets, and NetworkPolicies. `qa:k8s:live` requires authenticated cluster access and must pass before publishing a Kubernetes-backed live release.

This command runs:

- lint and TypeScript checks
- Kubernetes manifest rendering and structural checks
- deterministic UAT suites
- Playwright public CTA, accessibility, and UAT smoke checks
- Firestore and Storage rules emulator tests
- Evidence Chain emulator integration
- analytics emulator integration
- secret scan
- internal-only AI dependency, import, domain, and egress guards
- COPPA guard suite
- full Jest regression suite
- production build

## Required UAT Gates

The UAT suite is not complete unless these gates pass:

- `uat-completeness-gate.test.ts`: role, stage, learning-chain, AI-policy, permission, tenant, audit, accessibility, autosave, launch-blocker, and terminology coverage.
- `product-promise-gate.test.ts`: Learner work, Educator coaching, Family trust, optional Mentor readiness, Admin trust, MiloOS safety, Portfolio proof, and product-review flagging.
- `gold-workflow-gate.test.ts`: release workflow coverage from Capability definition through Growth Report and Ideation Passport-style export.
- `blanket-gold-live-readiness-gate.test.ts`: live deployed role-account evidence required before Scholesa can be called blanket gold for real programs.

## Live Blanket-Gold Evidence Required

Automated UAT can be blanket-gold covered, but live blanket gold requires deployed verification with real role accounts and real data:

1. Admin creates or edits Capabilities and maps them to Missions and checkpoints.
2. Educator runs a live Session and records Capability observations during build time.
3. Learner submits artifacts, reflections, and checkpoint Evidence through deployed storage.
4. Educator applies a four-level Capability Review tied to Capabilities and process domains.
5. Proof-of-learning is captured, opened, and reviewed with authenticity/provenance intact.
6. Capability growth updates over time from multiple reviewed Evidence records.
7. Portfolio shows real artifacts, reflections, feedback, share modes, and Evidence provenance.
8. Ideation Passport and Growth Report exports are generated only from selected reviewed Evidence.
9. MiloOS Coach AI-use is age-appropriate, disclosed, linked to Evidence, and auditable.
10. Family, Educator, and Admin views are understandable, tenant-scoped, and trustworthy.

## Product Review Rule

Flag a feature for product review if it does not strengthen at least one of these:

- Capability growth
- Evidence quality
- Learner safety
- Educator usability
- Family trust
- Admin trust
- MiloOS Coach auditability
- Portfolio visibility

Do not treat Mission completion, XP, attendance, averages, or generic progress as Capability mastery unless reviewed Evidence proves the claim.
