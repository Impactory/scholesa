# Release Gate (Enterprise)

Block release if:
- Any golden flow fails
- Tenant isolation suite not run on same SHA
- AI guardrail suite not run on same SHA
- Critical/high vulnerability unresolved (or no documented risk acceptance)
- Backup restore not verified within 30 days (prod)
- IAM export not updated within 90 days (prod)
