# K–12 Content Modularity (Subject Packs)

## Objective
Scale to full K–12 breadth by making content portable and engine subject-agnostic.

## Folder layout (recommended)
/content/subjects/{subjectId}/
  manifest.yaml
  grades/{gradeBand}/
    scope_sequence.yaml
    units/{unitId}/
      unit.yaml
      missions/{missionId}.yaml
      rubrics/{rubricId}.yaml
      vocab/{vocabId}.yaml
      misconceptions/{misconId}.yaml
      teacher_guides/{guideId}.md

/standards/{frameworkId}/
  manifest.yaml
  mappings/{subjectId}.yaml

/prompts/{subjectId}/
  core.system.md
  student/
    k5.hints.md
    ms.hints.md
    hs.hints.md
  teacher/
    feedback_rubric.md
    differentiate.md

## Installation concept
- content packs are validated and loaded by `scholesa-content`
- packs are versioned (e.g., 2026.1)
- tenants can pin pack versions or upgrade

## AI prompt modularity
- prompts are assembled server-side in `scholesa-ai`
- prompt modules chosen by subjectId + gradeBand + role + taskType

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `infrastructure/blueprints/hybrid-cloudrun-gke-gpu/07-k12/01-content-modularity.md`
<!-- TELEMETRY_WIRING:END -->
