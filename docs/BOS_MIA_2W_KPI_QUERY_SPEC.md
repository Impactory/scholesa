# BOS-MIA 2-Week KPI Query Spec

## Purpose
Provide ready-to-run query patterns for the KPI checklist in [docs/BOS_MIA_2W_USEFULNESS_KPI_CHECKLIST.md](docs/BOS_MIA_2W_USEFULNESS_KPI_CHECKLIST.md).

## Source of Truth
- Firestore collection: `telemetryEvents`
- Core fields used:
  - `eventType` (fallback: `event`)
  - `siteId`
  - `userId`
  - `timestamp`
  - `role` / `actorRole`
  - `metadata` (contains `cta`, `trigger`, `surface`, etc.)

## BigQuery Assumptions
- Firestore export table: `project_id.analytics.telemetryEvents_raw`
- `metadata` is available as JSON string or RECORD.
- If `metadata` is RECORD, replace `JSON_VALUE(metadata, '$.x')` with `metadata.x`.

---

## 0) Base CTE (14-day learner scope)
```sql
WITH base AS (
  SELECT
    COALESCE(eventType, event) AS event_type,
    siteId AS site_id,
    userId AS user_id,
    timestamp AS ts,
    CAST(metadata AS STRING) AS metadata_json
  FROM `project_id.analytics.telemetryEvents_raw`
  WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)
    AND siteId IS NOT NULL
    AND userId IS NOT NULL
)
```

## 1) BOS Proactive Activation Rate
```sql
WITH base AS (...),
sessions AS (
  SELECT site_id, user_id,
    COUNTIF(event_type = 'session_joined') AS learner_sessions
  FROM base
  GROUP BY 1,2
),
bos_open AS (
  SELECT site_id, user_id,
    COUNTIF(
      event_type = 'cta.clicked'
      AND JSON_VALUE(metadata_json, '$.cta') = 'global_ai_assistant_open'
      AND JSON_VALUE(metadata_json, '$.trigger') = 'bos_auto_popup'
    ) AS bos_auto_popup_open_count
  FROM base
  GROUP BY 1,2
)
SELECT
  s.site_id,
  SAFE_DIVIDE(SUM(b.bos_auto_popup_open_count), NULLIF(SUM(s.learner_sessions), 0)) AS bos_proactive_activation_rate
FROM sessions s
JOIN bos_open b USING (site_id, user_id)
GROUP BY 1;
```

## 2) Proactive Completion Parity (open vs close)
```sql
WITH base AS (...)
SELECT
  site_id,
  SAFE_DIVIDE(
    COUNTIF(event_type = 'cta.clicked'
      AND JSON_VALUE(metadata_json, '$.cta') = 'global_ai_assistant_close'
      AND JSON_VALUE(metadata_json, '$.trigger') = 'bos_auto_popup'
    ),
    NULLIF(COUNTIF(event_type = 'cta.clicked'
      AND JSON_VALUE(metadata_json, '$.cta') = 'global_ai_assistant_open'
      AND JSON_VALUE(metadata_json, '$.trigger') = 'bos_auto_popup'
    ), 0)
  ) AS proactive_completion_parity
FROM base
GROUP BY 1;
```

## 3) Hesitation Recovery Rate (within 120s)
```sql
WITH base AS (...),
idle_events AS (
  SELECT site_id, user_id, ts AS idle_ts
  FROM base
  WHERE event_type = 'idle_detected'
),
recovery AS (
  SELECT i.site_id, i.user_id, i.idle_ts,
    MIN(b.ts) AS first_focus_restored_ts
  FROM idle_events i
  LEFT JOIN base b
    ON b.site_id = i.site_id
   AND b.user_id = i.user_id
   AND b.event_type = 'focus_restored'
   AND b.ts >= i.idle_ts
   AND b.ts <= TIMESTAMP_ADD(i.idle_ts, INTERVAL 120 SECOND)
  GROUP BY 1,2,3
)
SELECT
  site_id,
  SAFE_DIVIDE(
    COUNTIF(first_focus_restored_ts IS NOT NULL),
    NULLIF(COUNT(*), 0)
  ) AS hesitation_recovery_rate
FROM recovery
GROUP BY 1;
```

## 4) Help Conversion Rate
```sql
WITH base AS (...)
SELECT
  site_id,
  SAFE_DIVIDE(
    COUNTIF(event_type = 'ai_help_used'),
    NULLIF(COUNTIF(event_type = 'ai_help_opened'), 0)
  ) AS help_conversion_rate
FROM base
GROUP BY 1;
```

## 5) Voice-First Completion Rate
```sql
WITH base AS (...)
SELECT
  site_id,
  SAFE_DIVIDE(
    COUNTIF(event_type = 'voice.message'),
    NULLIF(COUNTIF(event_type = 'voice.transcribe'), 0)
  ) AS voice_first_completion_rate
FROM base
GROUP BY 1;
```

## 6) AI Response Coverage
```sql
WITH base AS (...)
SELECT
  site_id,
  SAFE_DIVIDE(
    COUNTIF(event_type = 'ai_coach_response'),
    NULLIF(COUNTIF(event_type = 'ai_help_used'), 0)
  ) AS ai_response_coverage
FROM base
GROUP BY 1;
```

## 7) Positive Feedback Ratio
```sql
WITH base AS (...)
SELECT
  site_id,
  SAFE_DIVIDE(
    COUNTIF(
      event_type = 'ai_coach_feedback'
      AND LOWER(JSON_VALUE(metadata_json, '$.helpful')) IN ('true', '1', 'yes')
    ),
    NULLIF(COUNTIF(event_type = 'ai_coach_feedback'), 0)
  ) AS positive_feedback_ratio
FROM base
GROUP BY 1;
```

---

## Guardrail Queries

### A) BOS spam guardrail (>2 bos popups per learner per 10 minutes)
```sql
WITH base AS (...),
opens AS (
  SELECT
    site_id,
    user_id,
    TIMESTAMP_TRUNC(ts, MINUTE) AS minute_bucket
  FROM base
  WHERE event_type = 'cta.clicked'
    AND JSON_VALUE(metadata_json, '$.cta') = 'global_ai_assistant_open'
    AND JSON_VALUE(metadata_json, '$.trigger') = 'bos_auto_popup'
),
rolling AS (
  SELECT
    site_id,
    user_id,
    minute_bucket,
    COUNT(*) OVER (
      PARTITION BY site_id, user_id
      ORDER BY minute_bucket
      RANGE BETWEEN INTERVAL 9 MINUTE PRECEDING AND CURRENT ROW
    ) AS opens_in_10m
  FROM opens
)
SELECT
  site_id,
  SAFE_DIVIDE(COUNTIF(opens_in_10m > 2), NULLIF(COUNT(*), 0)) AS pct_windows_over_limit
FROM rolling
GROUP BY 1;
```

### B) Voice failure guardrail
```sql
WITH base AS (...)
SELECT
  site_id,
  SAFE_DIVIDE(
    COUNTIF(event_type = 'voice.transcribe') - COUNTIF(event_type = 'voice.message'),
    NULLIF(COUNTIF(event_type = 'voice.transcribe'), 0)
  ) AS voice_drop_ratio
FROM base
GROUP BY 1;
```

### C) Silent failure guardrail
```sql
WITH base AS (...)
SELECT
  site_id,
  SAFE_DIVIDE(
    COUNTIF(event_type = 'ai_help_used') - COUNTIF(event_type = 'ai_coach_response'),
    NULLIF(COUNTIF(event_type = 'ai_help_used'), 0)
  ) AS silent_failure_ratio
FROM base
GROUP BY 1;
```

---

## Firestore-Only Fallback (No BigQuery)
- Use `telemetryAggregates` for rough trend snapshots only (daily/weekly).
- For exact KPI parity and time-window joins (`idle_detected` -> `focus_restored`), use BigQuery export.

## Implementation Notes
- Keep role filter to learner traffic if your export includes mixed role events.
- Treat `eventType` as canonical; only fallback to `event` if needed.
- Validate metadata keys (`cta`, `trigger`, `helpful`) in one sample day before dashboarding.
