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
