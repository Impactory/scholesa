# Legacy Runtime TS Quarantine

This directory holds the older TypeScript BOS, voice, safety, and telemetry runtime subtree that is no longer part of the active Scholesa release path.

Why it was quarantined:
- It was self-contained and no longer referenced by the web app, functions, or RC3 preflight runtime.
- Leaving it under `src/` caused avoidable audit ambiguity and maintenance confusion.
- The active learner/runtime implementation now lives in the current web, Firebase Functions, and Flutter paths.

Quarantine rules:
- Do not import these files back into active application code.
- If any logic here is needed again, port it intentionally into the live runtime surface instead of restoring direct dependencies.