# Logging Hygiene (No Raw Content)

## Allowed in logs
- traceId
- siteId (tenant)
- role, gradeBand, locale
- endpoint name, status code
- latencyMs
- safetyOutcome codes (no content)

## Prohibited in logs
- raw transcript text
- raw prompt content
- audio bytes
- names/emails/addresses

## Implementation
- Use structured logger with redaction middleware
- Add tests that scan logs for prohibited patterns during integration runs

## Evidence
`audit-pack/reports/logging-no-raw-content.json`
