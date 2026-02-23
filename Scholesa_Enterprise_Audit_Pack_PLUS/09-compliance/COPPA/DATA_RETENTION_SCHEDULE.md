# Data Retention Schedule (Default + Override)

Default retention is “as long as necessary for educational purposes,” with concrete defaults below.
Districts may require shorter schedules; Scholesa supports tenant-specific overrides where technically feasible.

## Defaults
- Active student records: retained during enrollment
- Inactive accounts: delete after 24 months inactivity
- AI interaction logs: retain 12 months (security + quality), shorter if district requires
- Operational logs: retain per security needs; redact/minimize
- Backups: rolling 30–90 days (configurable)

## Deletion verification
- Confirm Firestore docs removed
- Confirm artifact objects removed
- Record deletion completion report
