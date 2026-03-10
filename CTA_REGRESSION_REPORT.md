# CTA Full Inventory & Regression Source

Generated from first-party source in `app/`, `src/`, and `apps/empire_flutter/app/lib/`.

## Scan Policy

- Actionable CTA coverage includes UI files with direct user-interaction markers and expected telemetry hooks/calls.
- Excluded non-actionable web files are utility/type-only paths listed in `NON_ACTIONABLE_WEB_PATHS`.
- Excluded non-actionable Flutter files are localization/utility-only paths listed in `NON_ACTIONABLE_FLUTTER_PATHS`.
- Blocker findings exclude known generated/framework stubs listed in `NON_ACTIONABLE_BLOCKER_PATHS`.
- Route TODO/FIXME blocker scan is restricted to route surfaces (`page.tsx`, `layout.tsx`, `loading.tsx`, `error.tsx`, `not-found.tsx`, `route.ts`).

## Summary

- Web files with CTA markers: **37**
- Flutter files with CTA markers: **53**
- Web CTA marker instances: **206**
- Flutter CTA marker instances: **335**
- Web files with quick-action markers: **0**
- Flutter files with quick-action markers: **6**
- Web quick-action marker instances: **0**
- Flutter quick-action marker instances: **17**

## Blocker Scan

- Placeholder links (`href="#"`): **0**
- Dead registration path (`/learner-registration`): **0**
- Web TODO/FIXME in routes: **0**
- Flutter unimplemented handlers (`UnimplementedError`/`UnsupportedError`): **0**
- Excluded non-actionable blocker findings: **2**

## CTA Telemetry Coverage

- Web CTA files with direct telemetry hooks/calls: **37/37**
- Flutter CTA files with direct telemetry import/calls: **53/53**

## Quick Actions Coverage

- Web quick-action files with direct telemetry hooks/calls: **0/0**
- Flutter quick-action files with direct telemetry import/calls: **6/6**

### Web Quick Actions Coverage Matrix

- _none detected_

### Flutter Quick Actions Coverage Matrix

- `apps/empire_flutter/app/lib/dashboards/role_dashboard.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/educator/educator_today_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/hq_admin/user_admin_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/learner/learner_today_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/site/site_ops_page.dart`: **covered**
- `apps/empire_flutter/app/lib/ui/widgets/cards.dart`: **covered**

### Web Coverage Matrix

- `app/[locale]/(auth)/login/page.tsx`: **covered**
- `app/[locale]/(auth)/register/page.tsx`: **covered**
- `app/[locale]/page.tsx`: **covered**
- `app/not-found.tsx`: **covered**
- `src/components/SignOutButton.tsx`: **covered**
- `src/components/analytics/AIInsightsPanel.tsx`: **covered**
- `src/components/analytics/AnalyticsDashboard.tsx`: **covered**
- `src/components/analytics/HQAnalyticsDashboard.tsx`: **covered**
- `src/components/analytics/ParentAnalyticsDashboard.tsx`: **covered**
- `src/components/analytics/StudentAnalyticsDashboard.tsx`: **covered**
- `src/components/checkpoints/CheckpointSubmission.tsx`: **covered**
- `src/components/goals/GoalSettingForm.tsx`: **covered**
- `src/components/motivation/ClassInsights.tsx`: **covered**
- `src/components/motivation/EducatorFeedbackForm.tsx`: **covered**
- `src/components/motivation/MotivationNudges.tsx`: **covered**
- `src/components/motivation/StudentMotivationProfile.tsx`: **covered**
- `src/components/recognition/PeerRecognitionForm.tsx`: **covered**
- `src/components/sdt/AICoachPopup.tsx`: **covered**
- `src/components/sdt/AICoachScreen.tsx`: **covered**
- `src/components/sdt/LearningPathMap.tsx`: **covered**
- `src/components/sdt/ReflectionJournal.tsx`: **covered**
- `src/components/sdt/StudentDashboard.tsx`: **covered**
- `src/components/showcase/ShowcaseGallery.tsx`: **covered**
- `src/components/showcase/ShowcaseSubmissionForm.tsx`: **covered**
- `src/components/stripe/InvoiceHistory.tsx`: **covered**
- `src/components/stripe/PlanManager.tsx`: **covered**
- `src/components/stripe/PricingPlans.tsx`: **covered**
- `src/components/stripe/RefundManager.tsx`: **covered**
- `src/components/stripe/StripeDashboard.tsx`: **covered**
- `src/components/stripe/SubscriptionCard.tsx`: **covered**
- `src/components/stripe/SubscriptionManager.tsx`: **covered**
- `src/components/stripe/WebhookMonitor.tsx`: **covered**
- `src/features/auth/components/LoginForm.tsx`: **covered**
- `src/features/navigation/components/Navigation.tsx`: **covered**
- `src/features/workflows/WorkflowRoutePage.tsx`: **covered**
- `src/hooks/useTelemetry.ts`: **covered**
- `src/lib/theme/ThemeModeToggle.tsx`: **covered**

### Excluded Web Utility/Type Files

- `src/components/ui/Button.tsx`: **excluded_non_actionable**
- `src/types/FeedbackForm-impactory.tsx`: **excluded_non_actionable**
- `src/types/FeedbackForm.tsx`: **excluded_non_actionable**
- `src/types/SubmissionGrader.tsx`: **excluded_non_actionable**

### Flutter Coverage Matrix

- `apps/empire_flutter/app/lib/dashboards/role_dashboard.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/attendance/attendance_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/checkin/checkin_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/educator/educator_integrations_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/educator/educator_learner_supports_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/educator/educator_learners_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/educator/educator_mission_plans_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/educator/educator_mission_review_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/educator/educator_sessions_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/educator/educator_today_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/habits/habits_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/hq_admin/hq_analytics_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/hq_admin/hq_approvals_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/hq_admin/hq_audit_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/hq_admin/hq_billing_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/hq_admin/hq_curriculum_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/hq_admin/hq_feature_flags_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/hq_admin/hq_integrations_health_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/hq_admin/hq_role_switcher_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/hq_admin/hq_safety_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/hq_admin/hq_sites_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/hq_admin/user_admin_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/learner/learner_portfolio_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/learner/learner_today_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/messages/messages_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/messages/notifications_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/missions/missions_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/parent/parent_billing_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/parent/parent_portfolio_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/parent/parent_schedule_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/parent/parent_summary_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/partner/partner_contracts_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/partner/partner_listings_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/partner/partner_payouts_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/profile/profile_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/provisioning/provisioning_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/settings/settings_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/site/site_billing_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/site/site_dashboard_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/site/site_identity_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/site/site_incidents_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/site/site_integrations_health_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/site/site_ops_page.dart`: **covered**
- `apps/empire_flutter/app/lib/modules/site/site_sessions_page.dart`: **covered**
- `apps/empire_flutter/app/lib/offline/sync_status_widget.dart`: **covered**
- `apps/empire_flutter/app/lib/router/role_gate.dart`: **covered**
- `apps/empire_flutter/app/lib/runtime/ai_coach_widget.dart`: **covered**
- `apps/empire_flutter/app/lib/runtime/ai_context_coach_section.dart`: **covered**
- `apps/empire_flutter/app/lib/runtime/global_ai_assistant_overlay.dart`: **covered**
- `apps/empire_flutter/app/lib/ui/auth/login_page.dart`: **covered**
- `apps/empire_flutter/app/lib/ui/landing/landing_page.dart`: **covered**
- `apps/empire_flutter/app/lib/ui/widgets/cards.dart`: **covered**
- `apps/empire_flutter/app/lib/ui/widgets/learner_widgets.dart`: **covered**

## Excluded Blocker Findings

### Flutter unimplemented handlers (`UnimplementedError`/`UnsupportedError`)

- `apps/empire_flutter/app/lib/firebase_options.dart:L33` `throw UnsupportedError(`
- `apps/empire_flutter/app/lib/firebase_options.dart:L38` `throw UnsupportedError(`

## Web CTA Files

### `app/[locale]/(auth)/login/page.tsx` (3)
- L102: `<button`
- L105: `onClick={() => trackInteraction('help_accessed', { cta: 'auth_login_submit' })}`
- L116: `onClick={() => trackInteraction('feature_discovered', { cta: 'auth_login_to_register' })}`

### `app/[locale]/(auth)/register/page.tsx` (3)
- L153: `<button`
- L156: `onClick={() => trackInteraction('help_accessed', { cta: 'auth_register_submit', role })}`
- L167: `onClick={() => trackInteraction('feature_discovered', { cta: 'auth_register_to_login' })}`

### `app/[locale]/page.tsx` (2)
- L28: `onClick={() => trackInteraction('feature_discovered', { cta: 'landing_login' })}`
- L35: `onClick={() => trackInteraction('feature_discovered', { cta: 'landing_register' })}`

### `app/not-found.tsx` (1)
- L20: `onClick={() => trackInteraction('help_accessed', { cta: 'not_found_home' })}`

### `src/components/SignOutButton.tsx` (2)
- L27: `<button`
- L28: `onClick={() => {`

### `src/components/analytics/AIInsightsPanel.tsx` (2)
- L359: `<button`
- L360: `onClick={() => {`

### `src/components/analytics/AnalyticsDashboard.tsx` (6)
- L147: `<button`
- L148: `onClick={() => {`
- L160: `<button`
- L161: `onClick={() => {`
- L175: `<button`
- L176: `onClick={handleExportCSV}`

### `src/components/analytics/HQAnalyticsDashboard.tsx` (4)
- L222: `<button`
- L223: `onClick={exportToCSV}`
- L302: `<button`
- L303: `onClick={() => setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc')}`

### `src/components/analytics/ParentAnalyticsDashboard.tsx` (2)
- L253: `<button`
- L255: `onClick={() => setSelectedChild(child.childId)}`

### `src/components/analytics/StudentAnalyticsDashboard.tsx` (4)
- L219: `<button`
- L220: `onClick={() => setTimeRange('week')}`
- L229: `<button`
- L230: `onClick={() => setTimeRange('month')}`

### `src/components/checkpoints/CheckpointSubmission.tsx` (7)
- L125: `<button`
- L126: `onClick={onClose}`
- L150: `<button`
- L151: `onClick={onClose}`
- L187: `<button`
- L195: `<button`
- L197: `onClick={onClose}`

### `src/components/goals/GoalSettingForm.tsx` (5)
- L100: `<button`
- L101: `onClick={onClose}`
- L161: `<button`
- L169: `<button`
- L171: `onClick={onClose}`

### `src/components/motivation/ClassInsights.tsx` (4)
- L90: `<button`
- L94: `onClick={() => {`
- L129: `<button`
- L132: `onClick={() => {`

### `src/components/motivation/EducatorFeedbackForm.tsx` (21)
- L163: `<button`
- L165: `onClick={onCancel}`
- L188: `<button`
- L191: `onClick={() => setEngagementLevel(level)}`
- L224: `<button`
- L227: `onClick={() => setParticipationType(p.value)}`
- L248: `<button`
- L251: `onClick={() => toggleMotivationType(m.type)}`
- L280: `<button`
- L282: `onClick={addHighlight}`
- L297: `<button`
- L299: `onClick={() => removeHighlight(i)}`
- L314: `<button`
- L316: `onClick={() => {`
- L360: `<button`
- L363: `onClick={() => addStrategy(type, strategy)}`
- L389: `<button`
- L391: `onClick={() => removeStrategy(i)}`
- L424: `<button`
- L426: `onClick={onCancel}`
- ... 1 more

### `src/components/motivation/MotivationNudges.tsx` (6)
- L95: `<button`
- L98: `onClick={() => {`
- L109: `<button`
- L112: `onClick={() => {`
- L134: `<button`
- L137: `onClick={() => {`

### `src/components/motivation/StudentMotivationProfile.tsx` (2)
- L276: `<button`
- L277: `onClick={() => setShowGoalForm(true)}`

### `src/components/recognition/PeerRecognitionForm.tsx` (5)
- L113: `<button`
- L114: `onClick={onClose}`
- L188: `<button`
- L197: `<button`
- L199: `onClick={onClose}`

### `src/components/sdt/AICoachPopup.tsx` (18)
- L549: `<button`
- L550: `onClick={handleOpenPopup}`
- L571: `<button`
- L572: `onClick={handleMinimizePopup}`
- L634: `<button`
- L636: `onClick={() => setMode(modeKey)}`
- L655: `<button`
- L656: `onClick={reset}`
- L677: `<button`
- L678: `onClick={isListening ? stopListening : startListening}`
- L734: `<button`
- L735: `onClick={async () => {`
- L747: `<button`
- L748: `onClick={async () => {`
- L797: `<button`
- L798: `onClick={handleSubmitExplainBack}`
- L807: `<button`
- L808: `onClick={reset}`

### `src/components/sdt/AICoachScreen.tsx` (14)
- L130: `<button`
- L131: `onClick={() => {`
- L144: `<button`
- L145: `onClick={() => {`
- L158: `<button`
- L159: `onClick={() => {`
- L177: `<button`
- L178: `onClick={() => {`
- L208: `<button`
- L209: `onClick={handleSubmitQuestion}`
- L270: `<button`
- L271: `onClick={handleSubmitExplainBack}`
- L282: `<button`
- L283: `onClick={() => {`

### `src/components/sdt/LearningPathMap.tsx` (4)
- L196: `<button`
- L197: `onClick={onToggle}`
- L267: `<button`
- L268: `onClick={(e) => {`

### `src/components/sdt/ReflectionJournal.tsx` (7)
- L164: `<button`
- L167: `onClick={() => setEffortLevel(level)}`
- L195: `<button`
- L198: `onClick={() => setEnjoymentLevel(level)}`
- L244: `<button`
- L361: `<button`
- L362: `onClick={handleSubmit}`

### `src/components/sdt/StudentDashboard.tsx` (10)
- L120: `<button`
- L121: `onClick={onResumeWork}`
- L128: `<button`
- L129: `onClick={onStartMission}`
- L144: `<button`
- L145: `onClick={onStartMission}`
- L206: `<button`
- L207: `onClick={onViewFeedback}`
- L297: `<button`
- L298: `onClick={() => onNavigate?.('mission')}`

### `src/components/showcase/ShowcaseGallery.tsx` (6)
- L131: `<button`
- L132: `onClick={() => setShowSubmitForm(true)}`
- L145: `<button`
- L147: `onClick={() => setFilterVisibility(vis)}`
- L277: `<button`
- L278: `onClick={onRecognize}`

### `src/components/showcase/ShowcaseSubmissionForm.tsx` (5)
- L115: `<button`
- L116: `onClick={onClose}`
- L242: `<button`
- L250: `<button`
- L252: `onClick={onClose}`

### `src/components/stripe/InvoiceHistory.tsx` (6)
- L99: `<button`
- L100: `onClick={fetchInvoices}`
- L171: `<button`
- L172: `onClick={() => handleRetryPayment(invoice.id)}`
- L189: `onClick={() => trackInteraction('feature_discovered', { cta: 'invoice_view', invoiceId: invoice.id })}`
- L200: `onClick={() => trackInteraction('feature_discovered', { cta: 'invoice_pdf_download', invoiceId: invoice.id })}`

### `src/components/stripe/PlanManager.tsx` (19)
- L337: `<button`
- L338: `onClick={fetchProducts}`
- L345: `<button`
- L346: `onClick={() => setModalType('createProduct')}`
- L362: `<button onClick={() => setError(null)} className="ml-auto" title="Dismiss error" aria-label="Dismiss error">`
- L405: `<button`
- L406: `onClick={() => openEditProduct(product)}`
- L412: `<button`
- L413: `onClick={() => openCreatePrice(product)}`
- L420: `<button`
- L421: `onClick={() => handleArchiveProduct(product)}`
- L473: `<button`
- L474: `onClick={() => handleTogglePriceActive(price.id, price.active)}`
- L509: `<button`
- L510: `onClick={closeModal}`
- L644: `<button`
- L645: `onClick={closeModal}`
- L650: `<button`
- L651: `onClick={() => {`

### `src/components/stripe/PricingPlans.tsx` (3)
- L116: `<button`
- L117: `onClick={() => onSubscribe(plan.id)}`
- L214: `onClick={() => {`

### `src/components/stripe/RefundManager.tsx` (1)
- L203: `<button`

### `src/components/stripe/StripeDashboard.tsx` (2)
- L86: `<button`
- L87: `onClick={fetchMetrics}`

### `src/components/stripe/SubscriptionCard.tsx` (6)
- L135: `<button`
- L136: `onClick={handleManageBilling}`
- L145: `<button`
- L146: `onClick={handleCancel}`
- L156: `<button`
- L157: `onClick={handleResume}`

### `src/components/stripe/SubscriptionManager.tsx` (2)
- L59: `<button`
- L60: `onClick={fetchSubscriptions}`

### `src/components/stripe/WebhookMonitor.tsx` (2)
- L120: `<button`
- L121: `onClick={fetchLogs}`

### `src/features/auth/components/LoginForm.tsx` (1)
- L82: `<Button onClick={handleGoogleSignIn} className='w-full' variant='outline'>`

### `src/features/navigation/components/Navigation.tsx` (3)
- L60: `onClick={() =>`
- L92: `onClick={async () => {`
- L111: `onClick={() =>`

### `src/features/workflows/WorkflowRoutePage.tsx` (13)
- L198: `onClick={() =>`
- L218: `<button`
- L221: `onClick={() => {`
- L233: `<button`
- L236: `onClick={() => setCreateOpen((prev) => !prev)}`
- L356: `<button`
- L360: `onClick={() => {`
- L367: `<button`
- L370: `onClick={() => {`
- L417: `<button`
- L421: `onClick={() => {`
- L430: `<button`
- L434: `onClick={() => {`

### `src/hooks/useTelemetry.ts` (3)
- L145: `*     <button onClick={() => trackClick('feature_discovered', { missionId })}>`
- L215: `*   return <button onClick={handleSubmit}>Submit</button>;`
- L248: `*   return <button onClick={handleGiveRecognition}>Give Props</button>;`

### `src/lib/theme/ThemeModeToggle.tsx` (2)
- L44: `<button`
- L49: `onClick={() => {`

## Flutter CTA Files

### `apps/empire_flutter/app/lib/dashboards/role_dashboard.dart` (10)
- L851: `IconButton(`
- L865: `IconButton(`
- L880: `IconButton(`
- L915: `TextButton(`
- L1172: `return ListTile(`
- L1208: `TextButton(`
- L1221: `ElevatedButton(`
- L1263: `...appState.siteIds.map((String siteId) => ListTile(`
- L1322: `TextButton(`
- L1335: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/attendance/attendance_page.dart` (3)
- L134: `return RefreshIndicator(`
- L157: `child: ListTile(`
- L600: `child: InkWell(`

### `apps/empire_flutter/app/lib/modules/checkin/checkin_page.dart` (11)
- L114: `IconButton(`
- L218: `? IconButton(`
- L532: `TextButton(`
- L662: `child: InkWell(`
- L861: `IconButton(`
- L872: `IconButton(`
- L934: `.map((AuthorizedPickup pickup) => ListTile(`
- L973: `? IconButton(`
- L1020: `child: InkWell(`
- L1322: `child: ElevatedButton(`
- L1440: `return InkWell(`

### `apps/empire_flutter/app/lib/modules/educator/educator_integrations_page.dart` (1)
- L264: `: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/educator/educator_learner_supports_page.dart` (10)
- L52: `IconButton(`
- L206: `child: InkWell(`
- L456: `child: OutlinedButton(`
- L483: `child: ElevatedButton(`
- L574: `TextButton(`
- L596: `ElevatedButton(`
- L666: `TextButton(`
- L679: `TextButton(`
- L683: `TextButton(`
- L687: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/educator/educator_learners_page.dart` (3)
- L357: `? IconButton(`
- L524: `child: InkWell(`
- L672: `return GestureDetector(`

### `apps/empire_flutter/app/lib/modules/educator/educator_mission_plans_page.dart` (9)
- L106: `IconButton(`
- L165: `child: InkWell(`
- L364: `TextButton(`
- L376: `ElevatedButton(`
- L396: `return ListTile(`
- L447: `child: OutlinedButton(`
- L463: `child: ElevatedButton(`
- L557: `TextButton(`
- L569: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/educator/educator_mission_review_page.dart` (5)
- L352: `child: InkWell(`
- L547: `return GestureDetector(`
- L764: `(int index) => GestureDetector(`
- L815: `child: OutlinedButton(`
- L879: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/educator/educator_sessions_page.dart` (5)
- L516: `TextButton(`
- L530: `ElevatedButton(`
- L557: `child: InkWell(`
- L729: `return GestureDetector(`
- L849: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/educator/educator_today_page.dart` (10)
- L457: `child: ElevatedButton(`
- L550: `TextButton(`
- L584: `TextButton(`
- L596: `ElevatedButton(`
- L674: `child: ListTile(`
- L682: `trailing: IconButton(`
- L828: `child: InkWell(`
- L895: `child: InkWell(`
- L1087: `return ListTile(`
- L1110: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/habits/habits_page.dart` (8)
- L95: `IconButton(`
- L512: `child: InkWell(`
- L671: `return GestureDetector(`
- L944: `IconButton(`
- L1200: `IconButton(`
- L1430: `IconButton(`
- L1467: `return GestureDetector(`
- L1630: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_analytics_page.dart` (7)
- L186: `IconButton(`
- L198: `IconButton(`
- L923: `TextButton(`
- L968: `TextButton(`
- L988: `ElevatedButton(`
- L1207: `TextButton(`
- L1220: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_approvals_page.dart` (2)
- L195: `child: OutlinedButton(`
- L204: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_audit_page.dart` (11)
- L105: `IconButton(`
- L112: `IconButton(`
- L119: `IconButton(`
- L132: `body: RefreshIndicator(`
- L292: `child: ListTile(`
- L304: `child: ListTile(`
- L448: `return ListTile(`
- L495: `child: OutlinedButton(`
- L549: `OutlinedButton(`
- L655: `TextButton(`
- L660: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_billing_page.dart` (8)
- L136: `IconButton(`
- L526: `TextButton(`
- L530: `ElevatedButton(`
- L837: `TextButton(`
- L950: `IconButton(`
- L955: `IconButton(`
- L1215: `IconButton(`
- L1333: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_curriculum_page.dart` (12)
- L110: `IconButton(`
- L214: `child: InkWell(`
- L353: `child: OutlinedButton(`
- L375: `child: ElevatedButton(`
- L690: `TextButton(`
- L697: `ElevatedButton(`
- L859: `TextButton(`
- L876: `ElevatedButton(`
- L1145: `TextButton(`
- L1150: `ElevatedButton(`
- L1514: `TextButton(`
- L1521: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_feature_flags_page.dart` (1)
- L59: `IconButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_integrations_health_page.dart` (3)
- L42: `IconButton(`
- L233: `return ListTile(`
- L243: `? TextButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_role_switcher_page.dart` (3)
- L52: `IconButton(`
- L198: `IconButton(`
- L374: `child: InkWell(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_safety_page.dart` (4)
- L204: `child: ListTile(`
- L210: `trailing: IconButton(`
- L291: `child: OutlinedButton(`
- L309: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_sites_page.dart` (4)
- L148: `? IconButton(`
- L550: `child: InkWell(`
- L758: `return GestureDetector(`
- L912: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/user_admin_page.dart` (10)
- L131: `IconButton(`
- L236: `? IconButton(`
- L576: `child: InkWell(`
- L654: `child: InkWell(`
- L1300: `.map((UserRole role) => ListTile(`
- L1358: `TextButton(`
- L1371: `ElevatedButton(`
- L1449: `child: InkWell(`
- L1693: `TextButton(`
- L1705: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/learner/learner_portfolio_page.dart` (7)
- L158: `IconButton(`
- L592: `TextButton(`
- L606: `ElevatedButton(`
- L638: `TextButton(`
- L652: `ElevatedButton(`
- L697: `child: ListTile(`
- L704: `trailing: IconButton(`

### `apps/empire_flutter/app/lib/modules/learner/learner_today_page.dart` (6)
- L119: `IconButton(`
- L413: `TextButton(`
- L491: `TextButton(`
- L545: `child: ListTile(`
- L552: `trailing: IconButton(`
- L755: `child: InkWell(`

### `apps/empire_flutter/app/lib/modules/messages/messages_page.dart` (5)
- L375: `child: InkWell(`
- L456: `child: InkWell(`
- L622: `child: ListTile(`
- L776: `IconButton(`
- L827: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/messages/notifications_page.dart` (2)
- L46: `TextButton(`
- L131: `child: InkWell(`

### `apps/empire_flutter/app/lib/modules/missions/missions_page.dart` (5)
- L513: `child: InkWell(`
- L583: `child: InkWell(`
- L993: `child: ElevatedButton(`
- L1063: `child: ElevatedButton(`
- L1183: `IconButton(`

### `apps/empire_flutter/app/lib/modules/parent/parent_billing_page.dart` (9)
- L153: `IconButton(`
- L609: `TextButton(`
- L619: `child: OutlinedButton(`
- L789: `TextButton(`
- L801: `ElevatedButton(`
- L839: `TextButton(`
- L851: `ElevatedButton(`
- L1025: `child: OutlinedButton(`
- L1044: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/parent/parent_portfolio_page.dart` (4)
- L272: `child: InkWell(`
- L473: `child: ElevatedButton(`
- L600: `child: ListTile(`
- L608: `trailing: IconButton(`

### `apps/empire_flutter/app/lib/modules/parent/parent_schedule_page.dart` (6)
- L160: `IconButton(`
- L341: `return GestureDetector(`
- L469: `TextButton(`
- L562: `TextButton(`
- L574: `ElevatedButton(`
- L940: `return GestureDetector(`

### `apps/empire_flutter/app/lib/modules/parent/parent_summary_page.dart` (3)
- L156: `IconButton(`
- L185: `return GestureDetector(`
- L475: `TextButton(`

### `apps/empire_flutter/app/lib/modules/partner/partner_contracts_page.dart` (9)
- L119: `return RefreshIndicator(`
- L153: `return RefreshIndicator(`
- L219: `child: InkWell(`
- L328: `child: InkWell(`
- L530: `return ListTile(`
- L543: `ElevatedButton(`
- L630: `ElevatedButton(`
- L716: `TextButton(`
- L721: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/partner/partner_listings_page.dart` (9)
- L40: `IconButton(`
- L66: `return RefreshIndicator(`
- L157: `child: InkWell(`
- L352: `TextButton(`
- L363: `ElevatedButton(`
- L498: `child: OutlinedButton(`
- L505: `child: ElevatedButton(`
- L559: `TextButton(`
- L563: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/partner/partner_payouts_page.dart` (1)
- L55: `child: RefreshIndicator(`

### `apps/empire_flutter/app/lib/modules/profile/profile_page.dart` (9)
- L65: `IconButton(`
- L84: `IconButton(`
- L409: `TextButton(`
- L421: `TextButton(`
- L497: `TextButton(`
- L507: `ElevatedButton(`
- L573: `TextButton(`
- L586: `ElevatedButton(`
- L630: `child: ListTile(`

### `apps/empire_flutter/app/lib/modules/provisioning/provisioning_page.dart` (29)
- L148: `floatingActionButton: FloatingActionButton(`
- L273: `return RefreshIndicator(`
- L295: `child: ListTile(`
- L306: `trailing: IconButton(`
- L335: `ListTile(`
- L355: `ListTile(`
- L404: `return RefreshIndicator(`
- L426: `child: ListTile(`
- L438: `trailing: IconButton(`
- L467: `ListTile(`
- L487: `ListTile(`
- L536: `return RefreshIndicator(`
- L558: `child: ListTile(`
- L585: `trailing: IconButton(`
- L616: `TextButton(`
- L630: `TextButton(`
- L685: `return RefreshIndicator(`
- L986: `TextButton(`
- L995: `ElevatedButton(`
- L1132: `TextButton(`
- ... 9 more

### `apps/empire_flutter/app/lib/modules/settings/settings_page.dart` (21)
- L691: `child: OutlinedButton(`
- L698: `child: ElevatedButton(`
- L786: `child: OutlinedButton(`
- L793: `child: ElevatedButton(`
- L870: `child: OutlinedButton(`
- L877: `child: ElevatedButton(`
- L995: `return ListTile(`
- L1045: `return ListTile(`
- L1103: `return ListTile(`
- L1208: `child: OutlinedButton(`
- L1215: `child: ElevatedButton(`
- L1265: `TextButton(`
- L1296: `TextButton(`
- L1300: `ElevatedButton(`
- L1344: `TextButton(`
- L1348: `ElevatedButton(`
- L1396: `TextButton(`
- L1400: `ElevatedButton(`
- L1438: `TextButton(`
- L1569: `return ListTile(`
- ... 1 more

### `apps/empire_flutter/app/lib/modules/site/site_billing_page.dart` (5)
- L160: `OutlinedButton(`
- L283: `TextButton(`
- L337: `return ListTile(`
- L382: `TextButton(`
- L396: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/site/site_dashboard_page.dart` (5)
- L233: `IconButton(`
- L790: `TextButton(`
- L896: `TextButton(`
- L916: `ElevatedButton(`
- L1368: `return GestureDetector(`

### `apps/empire_flutter/app/lib/modules/site/site_identity_page.dart` (2)
- L202: `child: OutlinedButton(`
- L212: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/site/site_incidents_page.dart` (6)
- L191: `child: InkWell(`
- L348: `child: OutlinedButton(`
- L366: `child: ElevatedButton(`
- L396: `child: OutlinedButton(`
- L492: `TextButton(`
- L506: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/site/site_integrations_health_page.dart` (7)
- L48: `IconButton(`
- L219: `IconButton(`
- L259: `child: ElevatedButton(`
- L353: `ListTile(`
- L370: `ListTile(`
- L387: `ListTile(`
- L403: `ListTile(`

### `apps/empire_flutter/app/lib/modules/site/site_ops_page.dart` (2)
- L254: `child: InkWell(`
- L607: `return ListTile(`

### `apps/empire_flutter/app/lib/modules/site/site_sessions_page.dart` (7)
- L291: `IconButton(`
- L316: `return GestureDetector(`
- L374: `IconButton(`
- L874: `return GestureDetector(`
- L1087: `return ListTile(`
- L1375: `child: ElevatedButton(`
- L1591: `return GestureDetector(`

### `apps/empire_flutter/app/lib/offline/sync_status_widget.dart` (1)
- L103: `TextButton(`

### `apps/empire_flutter/app/lib/router/role_gate.dart` (1)
- L104: `ElevatedButton(`

### `apps/empire_flutter/app/lib/runtime/ai_coach_widget.dart` (8)
- L964: `TextButton(`
- L968: `FilledButton(`
- L1389: `TextButton(`
- L1493: `IconButton(`
- L1502: `IconButton(`
- L1579: `TextButton(`
- L1809: `InkWell(`
- L1818: `InkWell(`

### `apps/empire_flutter/app/lib/runtime/ai_context_coach_section.dart` (2)
- L82: `child: ListTile(`
- L86: `trailing: IconButton(`

### `apps/empire_flutter/app/lib/runtime/global_ai_assistant_overlay.dart` (2)
- L134: `child: FloatingActionButton(`
- L601: `IconButton(`

### `apps/empire_flutter/app/lib/ui/auth/login_page.dart` (5)
- L246: `TextButton(`
- L262: `ElevatedButton(`
- L615: `suffixIcon: IconButton(`
- L656: `child: TextButton(`
- L682: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/ui/landing/landing_page.dart` (6)
- L340: `TextButton(`
- L514: `TextButton(`
- L526: `ElevatedButton(`
- L546: `TextButton(`
- L1016: `ElevatedButton(`
- L1082: `return InkWell(`

### `apps/empire_flutter/app/lib/ui/widgets/cards.dart` (4)
- L55: `child: InkWell(`
- L264: `child: InkWell(`
- L445: `child: InkWell(`
- L720: `return ListTile(`

### `apps/empire_flutter/app/lib/ui/widgets/learner_widgets.dart` (7)
- L155: `child: InkWell(`
- L315: `ElevatedButton(`
- L425: `return ListTile(`
- L514: `child: InkWell(`
- L574: `IconButton(`
- L756: `child: InkWell(`
- L903: `return ListTile(`

## Web Quick Actions Files

## Flutter Quick Actions Files

### `apps/empire_flutter/app/lib/dashboards/role_dashboard.dart` (6)
- L98: `'Quick Actions': '快捷操作',`
- L100: `'All Quick Actions': '全部快捷操作',`
- L215: `'Quick Actions': '快捷操作',`
- L217: `'All Quick Actions': '全部快捷操作',`
- L907: `_t(context, 'Quick Actions'),`
- L1160: `_t(sheetContext, 'All Quick Actions'),`

### `apps/empire_flutter/app/lib/modules/educator/educator_today_page.dart` (2)
- L17: `/// Educator Today Page - Daily schedule and quick actions`
- L833: `'cta': 'educator_today_quick_action',`

### `apps/empire_flutter/app/lib/modules/hq_admin/user_admin_page.dart` (2)
- L1145: `// Quick Actions`
- L1147: `_tUserAdmin(context, 'Quick Actions'),`

### `apps/empire_flutter/app/lib/modules/learner/learner_today_page.dart` (2)
- L349: `'cta': 'learner_today_open_messages_quick_action'`
- L760: `'cta': 'learner_today_quick_action',`

### `apps/empire_flutter/app/lib/modules/site/site_ops_page.dart` (3)
- L220: `_tSiteOps(context, 'Quick Actions'),`
- L260: `'cta_id': 'quick_action',`
- L261: `'surface': 'quick_actions',`

### `apps/empire_flutter/app/lib/ui/widgets/cards.dart` (2)
- L425: `/// A quick action button with icon and label`
- L453: `'cta_id': 'tap_quick_action',`

