# 43_EXPORT_RETENTION_BACKUP_SPEC.md
Export, retention, and backup (audit + compliance must-have)

Schools and HQ need basic data portability and retention policy.

---

## 1) Export
### Who can export
- site admin: export site-scoped data
- HQ: export across sites

### Export formats
- CSV for roster/attendance/attempt summaries
- JSON bundle for full structured data
- separate artifact export manifest (Storage paths)

### Export packaging
- generate a signed URL to download (time-limited)
- write AuditLog for every export request and download generation

---

## 2) Retention policy (minimum)
Define policy defaults:
- retain learner artifacts for X years (configurable)
- retain audit logs for Y years
- allow “legal hold” on a site/learner

Deletion requests:
- admin/HQ initiates
- run a soft-delete first
- schedule hard delete after a delay
- log every step

---

## 3) Backup + recovery (operational)
- documented backup procedure for Firestore + Storage
- recovery runbook
- quarterly restore test in staging

---

## 4) Security
- exports must be generated server-side
- deny client direct bulk reads outside role scope
