# CTA Full Regression Report

## Scope
- Workspace: scholesa
- Source scanned: apps/empire_flutter/app/lib/**/*.dart
- Total CTA handlers found: 383
- Cancel/close CTAs found: 99
- No-op handler blockers: 0

## Flow Type Summary
- callback/action: 312
- cancel/close: 57
- navigate: 14

## Top Files by CTA Count
- apps/empire_flutter/app/lib/modules/settings/settings_page.dart: 25
- apps/empire_flutter/app/lib/modules/provisioning/provisioning_page.dart: 20
- apps/empire_flutter/app/lib/modules/hq_admin/user_admin_page.dart: 19
- apps/empire_flutter/app/lib/modules/profile/profile_page.dart: 19
- apps/empire_flutter/app/lib/modules/checkin/checkin_page.dart: 19
- apps/empire_flutter/app/lib/modules/site/site_sessions_page.dart: 14
- apps/empire_flutter/app/lib/modules/hq_admin/hq_sites_page.dart: 13
- apps/empire_flutter/app/lib/modules/educator/educator_today_page.dart: 12
- apps/empire_flutter/app/lib/dashboards/role_dashboard.dart: 11
- apps/empire_flutter/app/lib/modules/educator/educator_sessions_page.dart: 11
- apps/empire_flutter/app/lib/ui/landing/landing_page.dart: 11
- apps/empire_flutter/app/lib/modules/attendance/attendance_page.dart: 10
- apps/empire_flutter/app/lib/modules/educator/educator_mission_review_page.dart: 10
- apps/empire_flutter/app/lib/modules/hq_admin/hq_billing_page.dart: 9
- apps/empire_flutter/app/lib/modules/partner/partner_listings_page.dart: 9
- apps/empire_flutter/app/lib/modules/parent/parent_billing_page.dart: 9
- apps/empire_flutter/app/lib/modules/site/site_dashboard_page.dart: 9
- apps/empire_flutter/app/lib/modules/messages/messages_page.dart: 8
- apps/empire_flutter/app/lib/modules/habits/habits_page.dart: 8
- apps/empire_flutter/app/lib/modules/educator/educator_learners_page.dart: 8
- apps/empire_flutter/app/lib/modules/educator/educator_mission_plans_page.dart: 8
- apps/empire_flutter/app/lib/modules/parent/parent_schedule_page.dart: 8
- apps/empire_flutter/app/lib/modules/missions/missions_page.dart: 7
- apps/empire_flutter/app/lib/modules/learner/learner_today_page.dart: 7
- apps/empire_flutter/app/lib/modules/site/site_incidents_page.dart: 7

## Blocker Scan
- No no-op CTA blockers detected (`onPressed/onTap: () {}` = 0).
- Placeholder CTA text scan is reported by dedicated grep step.

## Exhaustive CTA Inventory
All CTAs (including cancel/close/back actions) are listed in:
- reports/CTA_FULL_INVENTORY.csv

### Sample (first 100 CTAs)
| ID | File | Line | Event | Label | Flow | Cancel | Blocker |
|---:|---|---:|---|---|---|---|---|
| 1 | apps/empire_flutter/app/lib/main.dart | 284 | onPressed | Retry | callback/action | no | none |
| 2 | apps/empire_flutter/app/lib/runtime/ai_coach_widget.dart | 245 | onPressed |  | callback/action | no | none |
| 3 | apps/empire_flutter/app/lib/runtime/ai_coach_widget.dart | 435 | onTap |  | callback/action | no | none |
| 4 | apps/empire_flutter/app/lib/runtime/ai_coach_widget.dart | 444 | onTap |  | callback/action | no | none |
| 5 | apps/empire_flutter/app/lib/runtime/mvl_gate_widget.dart | 294 | onPressed |  | callback/action | no | none |
| 6 | apps/empire_flutter/app/lib/runtime/mvl_gate_widget.dart | 311 | onPressed |  | callback/action | no | none |
| 7 | apps/empire_flutter/app/lib/dashboards/role_dashboard.dart | 573 | onPressed | Switch site | callback/action | no | none |
| 8 | apps/empire_flutter/app/lib/dashboards/role_dashboard.dart | 578 | onPressed | Switch site | navigate | no | none |
| 9 | apps/empire_flutter/app/lib/dashboards/role_dashboard.dart | 583 | onPressed | Settings | callback/action | no | none |
| 10 | apps/empire_flutter/app/lib/dashboards/role_dashboard.dart | 614 | onPressed | View All | callback/action | no | none |
| 11 | apps/empire_flutter/app/lib/dashboards/role_dashboard.dart | 638 | onTap |  | callback/action | no | none |
| 12 | apps/empire_flutter/app/lib/dashboards/role_dashboard.dart | 772 | onTap |  | callback/action | no | none |
| 13 | apps/empire_flutter/app/lib/dashboards/role_dashboard.dart | 793 | onPressed | Close | cancel/close | yes | none |
| 14 | apps/empire_flutter/app/lib/dashboards/role_dashboard.dart | 797 | onPressed | Close | callback/action | yes | none |
| 15 | apps/empire_flutter/app/lib/dashboards/role_dashboard.dart | 849 | onTap |  | callback/action | no | none |
| 16 | apps/empire_flutter/app/lib/dashboards/role_dashboard.dart | 876 | onPressed | Cancel | cancel/close | yes | none |
| 17 | apps/empire_flutter/app/lib/dashboards/role_dashboard.dart | 880 | onPressed | Cancel | callback/action | yes | none |
| 18 | apps/empire_flutter/app/lib/offline/sync_status_widget.dart | 76 | onPressed |  | callback/action | no | none |
| 19 | apps/empire_flutter/app/lib/router/role_gate.dart | 77 | onPressed | Go Back | callback/action | yes | none |
| 20 | apps/empire_flutter/app/lib/modules/attendance/attendance_page.dart | 102 | onPressed | Refresh | callback/action | no | none |
| 21 | apps/empire_flutter/app/lib/modules/attendance/attendance_page.dart | 133 | onTap | ${occ.learnerCount ?? occ.roster.length} students | callback/action | no | none |
| 22 | apps/empire_flutter/app/lib/modules/attendance/attendance_page.dart | 261 | onPressed | All Present | callback/action | no | none |
| 23 | apps/empire_flutter/app/lib/modules/attendance/attendance_page.dart | 269 | onPressed | All Absent | callback/action | no | none |
| 24 | apps/empire_flutter/app/lib/modules/attendance/attendance_page.dart | 316 | onPressed | Save Attendance (${_attendance.length}/${roster.length}) | callback/action | no | none |
| 25 | apps/empire_flutter/app/lib/modules/attendance/attendance_page.dart | 429 | onTap |  | callback/action | no | none |
| 26 | apps/empire_flutter/app/lib/modules/attendance/attendance_page.dart | 437 | onTap |  | callback/action | no | none |
| 27 | apps/empire_flutter/app/lib/modules/attendance/attendance_page.dart | 445 | onTap |  | callback/action | no | none |
| 28 | apps/empire_flutter/app/lib/modules/attendance/attendance_page.dart | 453 | onTap |  | callback/action | no | none |
| 29 | apps/empire_flutter/app/lib/modules/attendance/attendance_page.dart | 496 | onTap |  | callback/action | no | none |
| 30 | apps/empire_flutter/app/lib/modules/hq_admin/hq_billing_page.dart | 65 | onPressed | New Invoice | callback/action | no | none |
| 31 | apps/empire_flutter/app/lib/modules/hq_admin/hq_billing_page.dart | 116 | onPressed |  | callback/action | no | none |
| 32 | apps/empire_flutter/app/lib/modules/hq_admin/hq_billing_page.dart | 460 | onPressed | Cancel | cancel/close | yes | none |
| 33 | apps/empire_flutter/app/lib/modules/hq_admin/hq_billing_page.dart | 464 | onPressed | Cancel | callback/action | yes | none |
| 34 | apps/empire_flutter/app/lib/modules/hq_admin/hq_billing_page.dart | 561 | onPressed | Close | cancel/close | yes | none |
| 35 | apps/empire_flutter/app/lib/modules/hq_admin/hq_billing_page.dart | 660 | onPressed |  | callback/action | no | none |
| 36 | apps/empire_flutter/app/lib/modules/hq_admin/hq_billing_page.dart | 665 | onPressed |  | callback/action | no | none |
| 37 | apps/empire_flutter/app/lib/modules/hq_admin/hq_billing_page.dart | 903 | onPressed |  | cancel/close | yes | none |
| 38 | apps/empire_flutter/app/lib/modules/hq_admin/hq_billing_page.dart | 1015 | onPressed |  | callback/action | no | none |
| 39 | apps/empire_flutter/app/lib/modules/hq_admin/hq_curriculum_page.dart | 104 | onPressed | New Curriculum | callback/action | no | none |
| 40 | apps/empire_flutter/app/lib/modules/hq_admin/hq_curriculum_page.dart | 149 | onTap |  | callback/action | no | none |
| 41 | apps/empire_flutter/app/lib/modules/hq_admin/hq_curriculum_page.dart | 247 | onPressed | Close | cancel/close | yes | none |
| 42 | apps/empire_flutter/app/lib/modules/hq_admin/hq_curriculum_page.dart | 251 | onPressed | Close | callback/action | yes | none |
| 43 | apps/empire_flutter/app/lib/modules/hq_admin/hq_curriculum_page.dart | 304 | onPressed | Cancel | cancel/close | yes | none |
| 44 | apps/empire_flutter/app/lib/modules/hq_admin/hq_curriculum_page.dart | 306 | onPressed | Cancel | callback/action | yes | none |
| 45 | apps/empire_flutter/app/lib/modules/hq_admin/hq_safety_page.dart | 163 | onPressed | ${incident.site} • ${_formatTime(incident.reportedAt)} | callback/action | no | none |
| 46 | apps/empire_flutter/app/lib/modules/hq_admin/hq_safety_page.dart | 165 | onTap | ${incident.site} • ${_formatTime(incident.reportedAt)} | callback/action | no | none |
| 47 | apps/empire_flutter/app/lib/modules/hq_admin/hq_safety_page.dart | 209 | onPressed | Close | cancel/close | yes | none |
| 48 | apps/empire_flutter/app/lib/modules/hq_admin/hq_safety_page.dart | 214 | onPressed | Close | callback/action | yes | none |
| 49 | apps/empire_flutter/app/lib/modules/hq_admin/hq_feature_flags_page.dart | 82 | onPressed | Feature Flags | callback/action | no | none |
| 50 | apps/empire_flutter/app/lib/modules/hq_admin/hq_analytics_page.dart | 89 | onPressed |  | callback/action | no | none |
| 51 | apps/empire_flutter/app/lib/modules/hq_admin/hq_analytics_page.dart | 408 | onPressed | View All | callback/action | no | none |
| 52 | apps/empire_flutter/app/lib/modules/hq_admin/hq_analytics_page.dart | 450 | onPressed | Cancel | cancel/close | yes | none |
| 53 | apps/empire_flutter/app/lib/modules/hq_admin/hq_analytics_page.dart | 454 | onPressed | Cancel | callback/action | yes | none |
| 54 | apps/empire_flutter/app/lib/modules/hq_admin/hq_approvals_page.dart | 190 | onPressed | Reject | callback/action | no | none |
| 55 | apps/empire_flutter/app/lib/modules/hq_admin/hq_approvals_page.dart | 198 | onPressed | Reject | callback/action | no | none |
| 56 | apps/empire_flutter/app/lib/modules/hq_admin/hq_role_switcher_page.dart | 48 | onPressed |  | navigate | no | none |
| 57 | apps/empire_flutter/app/lib/modules/hq_admin/hq_role_switcher_page.dart | 177 | onPressed | Exit impersonation | callback/action | no | none |
| 58 | apps/empire_flutter/app/lib/modules/hq_admin/hq_role_switcher_page.dart | 341 | onTap |  | callback/action | no | none |
| 59 | apps/empire_flutter/app/lib/modules/hq_admin/hq_audit_page.dart | 85 | onPressed | Audit Logs | callback/action | no | none |
| 60 | apps/empire_flutter/app/lib/modules/hq_admin/hq_audit_page.dart | 89 | onPressed |  | callback/action | no | none |
| 61 | apps/empire_flutter/app/lib/modules/hq_admin/hq_audit_page.dart | 162 | onTap |  | callback/action | no | none |
| 62 | apps/empire_flutter/app/lib/modules/hq_admin/hq_audit_page.dart | 228 | onTap |  | callback/action | no | none |
| 63 | apps/empire_flutter/app/lib/modules/hq_admin/hq_audit_page.dart | 259 | onPressed | Close | cancel/close | yes | none |
| 64 | apps/empire_flutter/app/lib/modules/hq_admin/hq_sites_page.dart | 55 | onTap |  | callback/action | no | none |
| 65 | apps/empire_flutter/app/lib/modules/hq_admin/hq_sites_page.dart | 64 | onTap |  | callback/action | no | none |
| 66 | apps/empire_flutter/app/lib/modules/hq_admin/hq_sites_page.dart | 73 | onTap |  | callback/action | no | none |
| 67 | apps/empire_flutter/app/lib/modules/hq_admin/hq_sites_page.dart | 82 | onTap |  | callback/action | no | none |
| 68 | apps/empire_flutter/app/lib/modules/hq_admin/hq_sites_page.dart | 92 | onPressed | Add Site | callback/action | no | none |
| 69 | apps/empire_flutter/app/lib/modules/hq_admin/hq_sites_page.dart | 159 | onPressed |  | callback/action | no | none |
| 70 | apps/empire_flutter/app/lib/modules/hq_admin/hq_sites_page.dart | 190 | onTap |  | callback/action | no | none |
| 71 | apps/empire_flutter/app/lib/modules/hq_admin/hq_sites_page.dart | 197 | onTap |  | callback/action | no | none |
| 72 | apps/empire_flutter/app/lib/modules/hq_admin/hq_sites_page.dart | 204 | onTap |  | callback/action | no | none |
| 73 | apps/empire_flutter/app/lib/modules/hq_admin/hq_sites_page.dart | 211 | onTap |  | callback/action | no | none |
| 74 | apps/empire_flutter/app/lib/modules/hq_admin/hq_sites_page.dart | 314 | onTap |  | callback/action | no | none |
| 75 | apps/empire_flutter/app/lib/modules/hq_admin/hq_sites_page.dart | 515 | onTap |  | callback/action | no | none |
| 76 | apps/empire_flutter/app/lib/modules/hq_admin/hq_sites_page.dart | 659 | onPressed |  | callback/action | no | none |
| 77 | apps/empire_flutter/app/lib/modules/hq_admin/user_admin_page.dart | 112 | onPressed | Refresh | callback/action | no | none |
| 78 | apps/empire_flutter/app/lib/modules/hq_admin/user_admin_page.dart | 199 | onPressed |  | callback/action | no | none |
| 79 | apps/empire_flutter/app/lib/modules/hq_admin/user_admin_page.dart | 219 | onTap |  | callback/action | no | none |
| 80 | apps/empire_flutter/app/lib/modules/hq_admin/user_admin_page.dart | 224 | onTap |  | callback/action | no | none |
| 81 | apps/empire_flutter/app/lib/modules/hq_admin/user_admin_page.dart | 233 | onTap |  | callback/action | no | none |
| 82 | apps/empire_flutter/app/lib/modules/hq_admin/user_admin_page.dart | 238 | onTap |  | callback/action | no | none |
| 83 | apps/empire_flutter/app/lib/modules/hq_admin/user_admin_page.dart | 311 | onTap |  | callback/action | no | none |
| 84 | apps/empire_flutter/app/lib/modules/hq_admin/user_admin_page.dart | 395 | onPressed | Add User | callback/action | no | none |
| 85 | apps/empire_flutter/app/lib/modules/hq_admin/user_admin_page.dart | 518 | onTap |  | callback/action | no | none |
| 86 | apps/empire_flutter/app/lib/modules/hq_admin/user_admin_page.dart | 588 | onTap |  | callback/action | no | none |
| 87 | apps/empire_flutter/app/lib/modules/hq_admin/user_admin_page.dart | 1051 | onTap |  | callback/action | no | none |
| 88 | apps/empire_flutter/app/lib/modules/hq_admin/user_admin_page.dart | 1058 | onTap |  | callback/action | no | none |
| 89 | apps/empire_flutter/app/lib/modules/hq_admin/user_admin_page.dart | 1065 | onTap |  | callback/action | no | none |
| 90 | apps/empire_flutter/app/lib/modules/hq_admin/user_admin_page.dart | 1163 | onTap |  | callback/action | no | none |
| 91 | apps/empire_flutter/app/lib/modules/hq_admin/user_admin_page.dart | 1195 | onPressed | Cancel | cancel/close | yes | none |
| 92 | apps/empire_flutter/app/lib/modules/hq_admin/user_admin_page.dart | 1199 | onPressed | Cancel | callback/action | yes | none |
| 93 | apps/empire_flutter/app/lib/modules/hq_admin/user_admin_page.dart | 1268 | onTap |  | callback/action | no | none |
| 94 | apps/empire_flutter/app/lib/modules/hq_admin/user_admin_page.dart | 1479 | onPressed | Cancel | cancel/close | yes | none |
| 95 | apps/empire_flutter/app/lib/modules/hq_admin/user_admin_page.dart | 1483 | onPressed | Cancel | callback/action | yes | none |
| 96 | apps/empire_flutter/app/lib/modules/hq_admin/hq_integrations_health_page.dart | 20 | onPressed | Integrations Health | callback/action | no | none |
| 97 | apps/empire_flutter/app/lib/modules/hq_admin/hq_integrations_health_page.dart | 160 | onPressed | Retry | callback/action | no | none |
| 98 | apps/empire_flutter/app/lib/modules/settings/settings_page.dart | 107 | onTap |  | callback/action | no | none |
| 99 | apps/empire_flutter/app/lib/modules/settings/settings_page.dart | 113 | onTap |  | callback/action | no | none |
| 100 | apps/empire_flutter/app/lib/modules/settings/settings_page.dart | 119 | onTap |  | callback/action | no | none |