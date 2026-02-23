# VIBE Regression Master (Enterprise)

Layers:
1. Static checks (lint/type/secrets)
2. Unit tests
3. Contract tests (OpenAPI + events schemas)
4. Integration tests (Firestore/Auth/Storage)
5. E2E golden flows (student + teacher)
6. Tenant isolation suite
7. Privacy export/delete suite
8. AI guardrail suite
9. Load baseline suite

Outputs required per run:
- run.json
- junit.xml
- coverage
- security scans
- e2e artifacts
- ai guardrails report
