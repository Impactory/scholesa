# Secure Context Assembly (scholesa-api)

## Rule
Context is minimal and permissioned. Never assemble broad context automatically.

## Allowed inputs (from client)
- screenId
- missionId/sessionId currently open
- missionAttemptId (current attempt only)
- selectedLearnerId (teacher only, if teacher has permission)

## Server validations
- siteId from auth token only
- role from auth token only
- verify selectedLearnerId belongs to teacher scope
- verify missionAttemptId belongs to requester and siteId

## Prohibited
- Passing entire student work history into AI
- Passing other students’ data into AI
- Including PII in logs
