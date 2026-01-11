# 21_PILLAR_HABIT_ENGINE_POPUPS_SPEC.md

Popups are micro-coaching that makes the accountability cycle stick.

## Purpose
Popups reinforce pillar habits without nagging:
- reinforce weekly commitments
- enforce evidence capture
- encourage reflection
- close the loop after reviews

## Surfaces
- modal (rare, blocking)
- bottom sheet (primary guided action)
- snackbar (light reminder)

## Catalog (required)

### Learner
- POP-LRN-PLAN: weekly commitment chooser
- POP-LRN-EVIDENCE: capture proof before leaving class
- POP-LRN-REFLECT: 60 sec reflection after evidence/submission
- POP-LRN-IMPROVE: next step after educator review

### Educator
- POP-EDU-PLAN: mission plan prompt (pillar focus + evidence expectation)
- POP-EDU-REVIEW: review queue reminder

### Parent
- POP-PAR-SUMMARY: weekly summary + acknowledge + 1 support action

### Admin
- POP-ADM-PROVISION: blocking if provisioning incomplete

## Anti-annoyance
- caps + cooldowns
- do-not-interrupt contexts (attendance, checkout, uploading)
- snooze options

## Configuration
Firestore: `configs/popupRules` (HQ tunable)

## State
- local Isar + remote `users/{uid}/nudgeState/{popupId}`

## Telemetry
- popup.shown / dismissed / completed / nudge.snoozed
