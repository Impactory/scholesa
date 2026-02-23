# AI System Specification

## Components
- Policy engine (allow/deny)
- Prompt templates (versioned)
- Tool registry (scoped)
- Safety classifier/moderation layer
- Evaluations suite (regression)

## Required metadata on every response
- modelVersion
- policyVersion
- promptTemplateId
- safetyOutcome
- toolCallIds
- traceId
- siteId, learnerId (internal logs)
- missionAttemptId (learning context)

## Logging
Append-only or tamper-evident approach recommended for investigations.
