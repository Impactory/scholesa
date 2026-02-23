# AI Data Minimization

Principles:
- Send only necessary context to AI
- Redact direct identifiers where possible
- Avoid sending raw student PII to model providers unless required and disclosed
- Log boundaries: keep sensitive inputs in protected logs or hashed references

Evidence:
- AI prompt assembly spec
- Redaction rules + tests
