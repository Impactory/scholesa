# PII Redaction Rules (Voice)

## When to apply
- Before speaking any content that may contain identifiers
- Always for K–5 unless teacher explicitly requests read-aloud of student submission and policy allows

## Redact patterns
- Names (if available via roster lists) -> [NAME]
- Emails -> [EMAIL]
- Phone numbers -> [PHONE]
- Addresses -> [ADDRESS]
- Internal IDs (siteId, learnerId, submissionId) -> [ID]

## Logging
Never store redacted text or original text in logs.
Store only:
- redactionApplied: boolean
- redactionCount: number
- lengths
