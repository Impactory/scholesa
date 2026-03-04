# Production Monitoring & Alerting Setup
## Scholesa RC3 Live Monitoring Infrastructure

**Created**: March 3, 2026  
**Status**: Active  
**Environment**: Production (Firebase + Next.js + Flutter)

---

## Overview

This document establishes monitoring practices, alert thresholds, and incident response procedures for the Scholesa platform in production.

---

## 1. Key Metrics to Monitor

### 1.1 Application Health

| Metric | Alert Threshold | Check Interval | Owner |
|--------|-----------------|-----------------|-------|
| **Build Success Rate** | < 95% | Every 6 hours | DevOps |
| **TypeScript Compilation** | Any errors | On each push | CI/CD |
| **Flutter APK Build** | Any critical errors | Daily | Mobile Team |
| **Next.js Runtime` | Page response > 5s | Continuous | Backend |

### 1.2 Firestore Performance

| Metric | Alert Threshold | Check Interval | Owner |
|--------|-----------------|-----------------|-------|
| **Read Latency** | > 500ms (p95) | Real-time | Database |
| **Write Latency** | > 1000ms (p95) | Real-time | Database |
| **Query Errors** | Any rule violations | Real-time | Database |
| **Index Usage** | Unused indexes > 7 days | Weekly | Database |
| **Storage Usage** | > 80% quota | Daily | Database |

### 1.3 Firebase Authentication

| Metric | Alert Threshold | Check Interval | Owner |
|--------|-----------------|-----------------|-------|
| **Login Failures** | > 5% error rate | Real-time | Auth Team |
| **Token Refresh Failures** | Any spike > baseline | Real-time | Auth Team |
| **Session Timeout Rate** | > 10% unexpired | Daily | Auth Team |
| **COPPA Violations** | Any detected | Real-time | Compliance |

### 1.4 API Performance

| Metric | Alert Threshold | Check Interval | Owner |
|--------|-----------------|-----------------|-------|
| **Cloud Functions Execution Time** | > 3s (p95) | Real-time | Backend |
| **Cloud Functions Error Rate** | > 1% | Real-time | Backend |
| **API Timeout Rate** | > 0.5% | Real-time | Backend |
| **Webhook Delivery Failures** | Any failures | Real-time | Integration |

### 1.5 i18n System

| Metric | Alert Threshold | Check Interval | Owner |
|--------|-----------------|-----------------|-------|
| **Missing i18n Keys** | Any new misses | Daily | Localization |
| **Translation Coverage** | < 90% per locale | Weekly | Localization |
| **Locale Support** | Unsupported requests | Real-time | Localization |

### 1.6 User Experience

| Metric | Alert Threshold | Check Interval | Owner |
|--------|-----------------|-----------------|-------|
| **Page Load Time** | > 3s (p95) | Real-time | Frontend |
| **CLS (Layout Shift)** | > 0.1 | Real-time | Frontend |
| **FCP (First Contentful Paint)** | > 1.8s | Real-time | Frontend |
| **Error Boundary Triggers** | Any unhandled errors | Real-time | Frontend |
| **Service Worker Failures** | Sw.js not available | Real-time | PWA |

---

## 2. Alert Channels & Escalation

### 2.1 Alert Routing

| Severity | Channel | Escalation | Response SLA |
|----------|---------|-----------|--------------|
| **CRITICAL** | PagerDuty + Slack #prod-critical | VP Engineering | 5 minutes |
| **HIGH** | Slack #prod-bugs + email | Tech Lead | 15 minutes |
| **MEDIUM** | Slack #prod-monitoring | Team | 1 hour |
| **LOW** | Daily digest | Team | 24 hours |

### 2.2 Slack Channels

```
#prod-critical      — Real-time alerts (critical only)
#prod-bugs          — API errors, 5xx failures
#prod-monitoring    — Performance degradation, warnings
#prod-deployments   — Build & deployment status
#i18n-analytics     — Translation metrics
#learner-feedback   — User-reported issues
```

### 2.3 On-Call Rotation

- **Primary**: Assigned daily at 00:00 UTC
- **Escalation**: After 15 min alert without acknowledgment
- **Handoff**: Every 24 hours (overlapping 1 hour)
- **On-call window**: Continuous (24/7 coverage)

---

## 3. Logging Strategy

### 3.1 Structured Logging Format

All logs should follow this JSON schema:

```json
{
  "timestamp": "2026-03-03T18:45:30.123Z",
  "service": "educator.sessions",
  "level": "error|warn|info|debug",
  "userId": "user-12345",
  "siteId": "site-98765",
  "message": "Action description",
  "context": {
    "module": "educator_sessions_page",
    "surface": "create_session_modal",
    "errorCode": "FIRESTORE_RULE_VIOLATION"
  },
  "metadata": {
    "latencyMs": 1234,
    "retries": 2,
    "policyVersion": "v1.0"
  },
  "error": {
    "name": "PermissionError",
    "stack": "..."
  }
}
```

### 3.2 Log Aggregation

- **Destination**: Google Cloud Logging
- **Retention**: 90 days (all logs)
- **Sampling**: 100% for errors, 10% for info
- **Query Frequency**: Real-time alerting on specific patterns

### 3.3 Key Log Patterns to Monitor

| Pattern | Severity | Action |
|---------|----------|--------|
| `"errorCode": "FIRESTORE_RULE_VIOLATION"` | HIGH | Investigate security rule |
| `"errorCode": "COPPA_VIOLATION"` | CRITICAL | Immediate escalation |
| `"latencyMs" > 5000` | MEDIUM | Performance review |
| `"retries" > 3` | MEDIUM | Circuit breaker evaluation |
| `"policyVersion" mismatch` | MEDIUM | Policy update check |

---

## 4. Dashboard Setup

### 4.1 Main Monitoring Dashboard (Firebase Console)

1. **Firestore**
   - Real-time read/write volume
   - Query latency distribution
   - Rule violation graph
   - Index efficiency

2. **Authentication**
   - Daily active users
   - Login failure rate
   - Token refresh latency
   - Session duration histogram

3. **Cloud Functions**
   - Execution count by name
   - Average execution time
   - Error rate and breakdown
   - Memory usage

4. **Realtime Database Events** (if applicable)
   - Connection count
   - Message throughput
   - Disconnect rate

### 4.2 Application Performance Dashboard (Google Cloud)

1. **Next.js Metrics** (via Web Vitals)
   - Page load times (p50, p95, p99)
   - First Contentful Paint (FCP)
   - Cumulative Layout Shift (CLS)
   - Time to Interactive (TTI)

2. **Flutter Metrics** (via Firebase Analytics)
   - App startup time
   - Screen load latency
   - Crash rate
   - ANR (Application Not Responding) events

3. **API Health**
   - Request throughput
   - Error rate by endpoint
   - Latency percentiles
   - Failed request breakdown

### 4.3 Custom Dashboards

**Dashboard 1: i18n Health**
```
- Missing key misses (count)
- Translation coverage by locale (%)
- Locale support requests (breakdown)
- Performance impact of i18n lookups (ms)
```

**Dashboard 2: User Experience**
```
- Error boundary triggers
- Unhandled exceptions
- Service worker failures
- Offline mode activation rate
```

---

## 5. Incident Response Procedures

### 5.1 Incident Classification

**CRITICAL** (Response: < 5 min)
- Platform completely down
- COPPA violation detected
- Firestore security breach
- User data loss confirmed

**HIGH** (Response: < 15 min)
- Feature broken for > 10% users
- Authentication failures > 5%
- API response time > 10 seconds
- Deploy rollback required

**MEDIUM** (Response: < 1 hour)
- Feature degraded for < 10% users
- Performance degradation
- Warning-level rule violations
- Minor security concern

**LOW** (Response: < 24 hours)
- Single user complaint
- Non-critical feature issue
- Documentation error
- Code quality issue

### 5.2 Incident Response Workflow

```
1. DETECT (Automated alert)
   ↓
2. ACKNOWLEDGE (Engineer within SLA)
   ↓
3. ASSESS (Severity + Root Cause)
   ↓
4. MITIGATE (Stop bleeding / circuit break)
   ↓
5. CONTAIN (Isolate issue)
   ↓
6. RESOLVE (Fix or rollback)
   ↓
7. VERIFY (System stability check)
   ↓
8. POST-MORTEM (Within 48 hours)
   ↓
9. PREVENT (Update runbooks)
```

### 5.3 Common Runbooks

**Runbook 1: Firestore Rule Violation Spike**
```
1. Check CF logs for rule violations
2. Verify policy version matches client
3. Check for schema mismatch
4. Rollback if needed; or fix rule
5. Monitor violation count to zero
6. Post-mortem: Update test coverage
```

**Runbook 2: Login Failures**
```
1. Check Firebase Auth status
2. Verify COPPA consent prompts working
3. Check token expiration logic
4. Verify JWKS endpoint health
5. Check client-side auth provider
6. If systemic: fallback to cached session
```

**Runbook 3: High Latency**
```
1. Check Firestore read/write latency
2. Verify index utilization
3. Check Cloud Functions memory
4. Review query complexity
5. Scale up Cloud Functions if needed
6. Check network latency
```

**Runbook 4: i18n Missing Keys**
```
1. Log the missing key + locale
2. Check if key is in BosCoachingI18n
3. Check if page has local override
4. Add key to appropriate centralized system
5. Verify telemetry captured the miss
6. Update locale files if new key
```

---

## 6. Monitoring Tools & Configuration

### 6.1 Firebase Console

**Setup Required**:
```
1. Enable Cloud Logging for Firestore
2. Set up Cloud Monitoring for Functions
3. Configure Storage Alarms (80% threshold)
4. Enable Web Analytics events
```

**Relevant Links**:
- Firestore Metrics: https://console.firebase.google.com/project/{PROJECT_ID}/firestore/monitoring
- Functions: https://console.firebase.google.com/project/{PROJECT_ID}/functions
- Auth: https://console.firebase.google.com/project/{PROJECT_ID}/authentication

### 6.2 Google Cloud Console

**Setup Required**:
```
1. Create monitoring alerts
2. Configure log-based metrics
3. Set up dashboard (see section 4)
4. Configure incident notifications
```

**Monitoring Policy Creation**:
```bash
# Example: Alert on 5xx errors
gcloud alpha monitoring policies create \
  --notification-channels=CHANNEL_ID \
  --display-name="Scholesa 5xx Errors" \
  --condition-display-name="5xx error rate" \
  --condition-threshold-value=1
```

### 6.3 PagerDuty Integration

**Setup**:
1. Create PagerDuty service for Scholesa
2. Link Google Cloud to PagerDuty
3. Configure escalation policy (15-min intervals)
4. Set up on-call rotation

**Webhook** (for manual incidents):
```bash
curl -X POST https://events.pagerduty.com/v2/enqueue \
  -H "Content-Type: application/json" \
  -d '{
    "routing_key": "YOUR_INTEGRATION_KEY",
    "event_action": "trigger",
    "dedup_key": "scholesa/critical/firestore-down",
    "payload": {
      "summary": "Firestore is down",
      "severity": "critical",
      "source": "CI/CD Pipeline"
    }
  }'
```

### 6.4 Slack Integration

**Firebase**:
- Slack App: Google Firebase
- Channel: #prod-deployments

**Google Cloud**:
- Notification Channel Type: Slack
- Channel: #prod-monitoring, #prod-critical

---

## 7. Performance Baselines

### 7.1 Established Baselines (as of March 3, 2026)

| Metric | Baseline | Acceptable Range | Alert Threshold |
|--------|----------|------------------|-----------------|
| Page Load (p95) | 1.8s | 1.5s - 2.5s | > 3s |
| Firestore Read Latency (p95) | 150ms | 100ms - 300ms | > 500ms |
| Firestore Write Latency (p95) | 250ms | 200ms - 500ms | > 1000ms |
| Cloud Function Execution (p95) | 800ms | 500ms - 1500ms | > 3s |
| Login Success Rate | 99.5% | > 95% | < 95% |
| i18n Key Miss Rate | < 0.1% | < 1% | > 1% |

### 7.2 Baseline Collection

- Capture metrics during normal operations
- Establish p50, p95, p99 percentiles
- Review baseline monthly
- Update thresholds based on seasonality

---

## 8. Monthly Review Checklist

**First Monday of each month, 10:00 UTC**:

- [ ] Review all alert firing patterns
- [ ] Update thresholds if needed
- [ ] Analyze post-mortems from incidents
- [ ] Check log storage usage
- [ ] Verify on-call rotation coverage
- [ ] Test incident response runbooks
- [ ] Review baseline metrics
- [ ] Audit security logs
- [ ] Update this document

---

## 9. Emergency Contact Protocol

**CRITICAL EMERGENCY** (Platform Down):

1. **Declare SEV-1 incident** in #prod-critical
2. **Page on-call engineer** via PagerDuty
3. **Notify VP Engineering** (email + Slack)
4. **Stand up incident bridge** (Zoom)
5. **Update status page** every 15 minutes
6. **Post-mortem meeting** within 24 hours

**Escalation Tree** (if on-call unresponsive):
```
Attempt 1: Page on-call (5 min)
Attempt 2: Page backup (5 min)
Attempt 3: Page tech lead (5 min)
Attempt 4: Page VP Engineering (immediate)
```

---

## 10. Success Metrics

Monitor these KPIs monthly:

| KPI | Target | Current |
|-----|--------|---------|
| **Uptime** | 99.9% | — |
| **MTTR** (Mean Time To Resolve) | < 30 min | — |
| **MTTD** (Mean Time To Detect) | < 2 min | — |
| **Incident Count** | < 5/month | — |
| **False Positive Rate** | < 5% | — |
| **Runbook Accuracy** | > 95% | — |

---

## Document Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-03-03 | Initial setup for RC3 production |

**Next Review**: April 3, 2026
