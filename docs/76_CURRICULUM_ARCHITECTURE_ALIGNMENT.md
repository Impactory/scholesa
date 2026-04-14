# 76_CURRICULUM_ARCHITECTURE_ALIGNMENT.md

## Purpose

This repo alignment note translates `Scholesa_Curriculum_Architecture_Master_v1.pdf` into live repository contracts and compatibility boundaries.

Canonical repo source of truth:

- TypeScript contract: `src/lib/curriculum/architecture.ts`
- Stage-aware AI gate: `src/lib/policies/aiPolicyTierGate.ts`
- Grade-band product policy: `src/lib/policies/gradeBandPolicy.ts`
- Shared display source: `config/curriculum_display.json`
- Regeneration command: `npm run generate:curriculum-display`

## Canonical curriculum model

- Scholesa is a K-12 future-readiness operating system, not a K-9 coding program.
- The learner journey is staged as `Discoverers` (grades 1-3), `Builders` (grades 4-6), `Explorers` (grades 7-9), and `Innovators` (grades 10-12).
- The graduate profile is built on six durable strands: `Think`, `Make`, `Communicate`, `Lead`, `Navigate AI`, and `Build for the World`.
- The annual rhythm is `Understand -> Design -> Test -> Showcase`.
- Every lesson follows the same move set: `Hook -> Micro-skill -> Build sprint -> Checkpoint -> Share-out -> Reflection`.
- Every meaningful task carries five proof layers: `Process`, `Product`, `Thinking`, `Improvement`, and `Integrity`.
- Portfolio is not an end-of-year add-on. Every learner needs `Timeline`, `Capability`, and `Best-work showcase` views.

## Legacy compatibility boundary

The repository still contains a large installed base of `pillarCode` fields, dashboards, analytics buckets, and Flutter/UI wording from the earlier three-pillar model. Those legacy buckets now have to be interpreted as compatibility aggregates rather than the canonical curriculum:

- `FUTURE_SKILLS` -> `Think`, `Make`, `Navigate AI`
- `LEADERSHIP_AGENCY` -> `Communicate`, `Lead`
- `IMPACT_INNOVATION` -> `Build for the World`

This mapping is encoded in `LEGACY_PILLAR_ALIGNMENT` inside `src/lib/curriculum/architecture.ts`.

## Repo expectations after alignment

- New curriculum logic must start from stages and strands, not from the legacy three-pillar vocabulary.
- New product copy must say `K-12`, not `K-9`.
- AI usage rules must match the four-stage governance model from the curriculum master document.
- Legacy pillar-coded data can remain in storage and analytics until a dedicated migration lands, but it must be presented as a compatibility layer instead of the canonical curriculum.
