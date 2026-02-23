# Dataflow Diagram (Text)

Document the core flows:

1) Authenticated request
Firebase Auth token -> API middleware verifies -> resolves siteId/role -> handles request.

2) Learning attempt
Student starts mission -> creates missionAttemptId -> checkpoints -> reflection -> artifact storage -> teacher review.

3) AI interaction
Student prompt -> AI policy + guardrails -> tool calls (scoped) -> response + metadata logged.

4) LMS integration
Coursework push -> store courseworkId -> submissions -> submissionId -> grade push.
