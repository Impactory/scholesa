# 10_TRACEABILITY_MATRIX_TEMPLATE.md

Copy to docs/TRACEABILITY_MATRIX.md and maintain continuously.

Rules:
- Every requirement must map to files + verification steps.
- No ✅ without evidence.

| Req ID | Requirement | Spec Ref | Implementation Files | Verification | Status |
|---|---|---|---|---|---|
| REQ-001 | Flutter web boots + design system | 01 | apps/... | flutter build web | 🔴 |
| REQ-010 | Admin provisioning (profiles + guardianLinks) | 01/06 | apps/... | Manual ADMIN-01 | 🔴 |
| REQ-020 | Attendance offline sync (Isar) | 05 | apps/... | Manual OFF-EDU-01 | 🔴 |
| REQ-030 | Billing webhook → entitlement grant | 13 | api/... | Test BILL-03 | 🔴 |
| REQ-040 | Marketplace order → fulfillment | 15 | api/... | Manual MKT-02 | 🔴 |
| REQ-050 | Partner contract → deliverable → payout | 16 | api/... | Manual CNT-03 | 🔴 |
| REQ-060 | Messaging send pipeline | 17 | api/... | Manual MSG-02 | 🔴 |
| REQ-070 | Analytics event registry + capture | 18 | app/api | Manual ANA-01 | 🔴 |
