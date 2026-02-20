# CTA Regression Inventory

Generated from first-party source in `app/`, `src/`, and `apps/empire_flutter/app/lib/`.

## Scan Policy

- Actionable CTA coverage includes UI files with direct user-interaction markers and expected telemetry hooks/calls.
- Excluded non-actionable web files are utility/type-only paths listed in `NON_ACTIONABLE_WEB_PATHS`.
- Blocker findings exclude known generated/framework stubs listed in `NON_ACTIONABLE_BLOCKER_PATHS`.
- Route TODO/FIXME blocker scan is restricted to route surfaces (`page.tsx`, `layout.tsx`, `loading.tsx`, `error.tsx`, `not-found.tsx`, `route.ts`).

## Summary

- Web files with CTA markers: **38**
- Flutter files with CTA markers: **50**
- Web CTA marker instances: **198**
- Flutter CTA marker instances: **267**

## Blocker Scan

- Placeholder links (`href="#"`): **0**
- Dead registration path (`/learner-registration`): **0**
- Web TODO/FIXME in routes: **0**
- Flutter unimplemented handlers (`UnimplementedError`/`UnsupportedError`): **0**
- Excluded non-actionable blocker findings: **2**

## CTA Telemetry Coverage

- Web CTA files with direct telemetry hooks/calls: **38/38**
- Flutter CTA files with direct telemetry import/calls: **50/50**

### Web Coverage Matrix

- `app/[locale]/(auth)/login/page.tsx`: **covered**
- `app/[locale]/(auth)/register/page.tsx`: **covered**
- `app/[locale]/(protected)/educator/page.tsx`: **covered**
- `app/[locale]/(protected)/hq/page.tsx`: **covered**
- `app/[locale]/(protected)/parent/page.tsx`: **covered**
- `app/[locale]/(protected)/partner/page.tsx`: **covered**
- `app/[locale]/(protected)/site/page.tsx`: **covered**
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
- `src/components/motivation/EducatorFeedbackForm.tsx`: **covered**
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
- `src/hooks/useTelemetry.ts`: **covered**

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
- L84: `<button`
- L87: `onClick={() => trackInteraction('help_accessed', { cta: 'auth_login_submit' })}`
- L98: `onClick={() => trackInteraction('feature_discovered', { cta: 'auth_login_to_register' })}`

### `app/[locale]/(auth)/register/page.tsx` (3)
- L134: `<button`
- L137: `onClick={() => trackInteraction('help_accessed', { cta: 'auth_register_submit', role })}`
- L148: `onClick={() => trackInteraction('feature_discovered', { cta: 'auth_register_to_login' })}`

### `app/[locale]/(protected)/educator/page.tsx` (3)
- L94: `onClick={() => trackInteraction('feature_discovered', { cta: 'educator_view_details', sessionId: session.id })}`
- L116: `onClick={() => trackInteraction('feature_discovered', { cta: 'educator_take_attendance' })}`
- L123: `onClick={() => trackInteraction('feature_discovered', { cta: 'educator_create_mission' })}`

### `app/[locale]/(protected)/hq/page.tsx` (5)
- L73: `onClick={() => trackInteraction('feature_discovered', { cta: 'hq_view_all_sites' })}`
- L104: `onClick={() => trackInteraction('feature_discovered', { cta: 'hq_manage_site', siteId: site.id })}`
- L148: `onClick={() => trackInteraction('feature_discovered', { cta: 'hq_add_new_site' })}`
- L155: `onClick={() => trackInteraction('feature_discovered', { cta: 'hq_user_management' })}`
- L162: `onClick={() => trackInteraction('feature_discovered', { cta: 'hq_global_settings' })}`

### `app/[locale]/(protected)/parent/page.tsx` (4)
- L78: `onClick={() => trackInteraction('feature_discovered', { cta: 'parent_register_learner' })}`
- L103: `onClick={() => trackInteraction('feature_discovered', { cta: 'parent_view_progress', learnerId: learner.uid })}`
- L125: `onClick={() => trackInteraction('feature_discovered', { cta: 'parent_message_educator' })}`
- L132: `onClick={() => trackInteraction('feature_discovered', { cta: 'parent_view_schedule' })}`

### `app/[locale]/(protected)/partner/page.tsx` (3)
- L99: `onClick={() => trackInteraction('feature_discovered', { cta: 'partner_view_reports', siteId: site.id })}`
- L139: `onClick={() => trackInteraction('feature_discovered', { cta: 'partner_download_impact_report' })}`
- L146: `onClick={() => trackInteraction('feature_discovered', { cta: 'partner_view_guidelines' })}`

### `app/[locale]/(protected)/site/page.tsx` (2)
- L107: `onClick={() => trackInteraction('feature_discovered', { cta: 'site_view_all' })}`
- L139: `onClick={() => trackInteraction('feature_discovered', { cta: 'site_manage_schedule' })}`

### `app/[locale]/page.tsx` (2)
- L25: `onClick={() => trackInteraction('feature_discovered', { cta: 'landing_login' })}`
- L32: `onClick={() => trackInteraction('feature_discovered', { cta: 'landing_register' })}`

### `app/not-found.tsx` (1)
- L16: `onClick={() => trackInteraction('help_accessed', { cta: 'not_found_home' })}`

### `src/components/SignOutButton.tsx` (2)
- L24: `<button`
- L25: `onClick={() => {`

### `src/components/analytics/AIInsightsPanel.tsx` (2)
- L345: `<button`
- L346: `onClick={() => {`

### `src/components/analytics/AnalyticsDashboard.tsx` (6)
- L140: `<button`
- L141: `onClick={() => {`
- L153: `<button`
- L154: `onClick={() => {`
- L168: `<button`
- L169: `onClick={handleExportCSV}`

### `src/components/analytics/HQAnalyticsDashboard.tsx` (4)
- L230: `<button`
- L231: `onClick={exportToCSV}`
- L310: `<button`
- L311: `onClick={() => setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc')}`

### `src/components/analytics/ParentAnalyticsDashboard.tsx` (2)
- L235: `<button`
- L237: `onClick={() => setSelectedChild(child.childId)}`

### `src/components/analytics/StudentAnalyticsDashboard.tsx` (4)
- L217: `<button`
- L218: `onClick={() => setTimeRange('week')}`
- L227: `<button`
- L228: `onClick={() => setTimeRange('month')}`

### `src/components/checkpoints/CheckpointSubmission.tsx` (7)
- L125: `<button`
- L126: `onClick={onClose}`
- L150: `<button`
- L151: `onClick={onClose}`
- L187: `<button`
- L195: `<button`
- L197: `onClick={onClose}`

### `src/components/goals/GoalSettingForm.tsx` (5)
- L98: `<button`
- L99: `onClick={onClose}`
- L159: `<button`
- L167: `<button`
- L169: `onClick={onClose}`

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

### `src/components/motivation/StudentMotivationProfile.tsx` (2)
- L272: `<button`
- L273: `onClick={() => setShowGoalForm(true)}`

### `src/components/recognition/PeerRecognitionForm.tsx` (5)
- L113: `<button`
- L114: `onClick={onClose}`
- L188: `<button`
- L197: `<button`
- L199: `onClick={onClose}`

### `src/components/sdt/AICoachPopup.tsx` (20)
- L314: `<button`
- L315: `onClick={() => setIsMinimized(false)}`
- L339: `<button`
- L340: `onClick={() => setIsMinimized(true)}`
- L402: `<button`
- L404: `onClick={() => setMode(modeKey)}`
- L423: `<button`
- L424: `onClick={reset}`
- L445: `<button`
- L446: `onClick={isListening ? stopListening : startListening}`
- L469: `<button`
- L470: `onClick={handleAsk}`
- L506: `<button`
- L507: `onClick={async () => {`
- L516: `<button`
- L517: `onClick={async () => {`
- L563: `<button`
- L564: `onClick={handleSubmitExplainBack}`
- L573: `<button`
- L574: `onClick={reset}`

### `src/components/sdt/AICoachScreen.tsx` (14)
- L132: `<button`
- L133: `onClick={() => {`
- L146: `<button`
- L147: `onClick={() => {`
- L160: `<button`
- L161: `onClick={() => {`
- L179: `<button`
- L180: `onClick={() => {`
- L210: `<button`
- L211: `onClick={handleSubmitQuestion}`
- L290: `<button`
- L291: `onClick={handleSubmitExplainBack}`
- L302: `<button`
- L303: `onClick={() => {`

### `src/components/sdt/LearningPathMap.tsx` (4)
- L191: `<button`
- L192: `onClick={onToggle}`
- L262: `<button`
- L263: `onClick={(e) => {`

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
- L79: `<Button onClick={handleGoogleSignIn} className='w-full' variant='outline'>`

### `src/features/navigation/components/Navigation.tsx` (1)
- L36: `onClick={() => {`

### `src/hooks/useTelemetry.ts` (3)
- L101: `*     <button onClick={() => trackClick('feature_discovered', { missionId })}>`
- L171: `*   return <button onClick={handleSubmit}>Submit</button>;`
- L204: `*   return <button onClick={handleGiveRecognition}>Give Props</button>;`

## Flutter CTA Files

### `apps/empire_flutter/app/lib/dashboards/role_dashboard.dart` (10)
- L571: `IconButton(`
- L576: `IconButton(`
- L581: `IconButton(`
- L614: `TextButton(`
- L778: `return ListTile(`
- L806: `TextButton(`
- L810: `ElevatedButton(`
- L845: `...appState.siteIds.map((String siteId) => ListTile(`
- L893: `TextButton(`
- L897: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/attendance/attendance_page.dart` (2)
- L124: `child: ListTile(`
- L519: `child: InkWell(`

### `apps/empire_flutter/app/lib/modules/checkin/checkin_page.dart` (10)
- L109: `IconButton(`
- L201: `? IconButton(`
- L422: `TextButton(`
- L534: `child: InkWell(`
- L718: `IconButton(`
- L770: `...summary.authorizedPickups.map((AuthorizedPickup pickup) => ListTile(`
- L805: `? IconButton(`
- L844: `child: InkWell(`
- L1127: `child: ElevatedButton(`
- L1232: `return InkWell(`

### `apps/empire_flutter/app/lib/modules/educator/educator_integrations_page.dart` (1)
- L194: `: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/educator/educator_learner_supports_page.dart` (6)
- L57: `IconButton(`
- L154: `child: InkWell(`
- L375: `child: OutlinedButton(`
- L382: `child: ElevatedButton(`
- L432: `TextButton(`
- L436: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/educator/educator_learners_page.dart` (3)
- L151: `? IconButton(`
- L317: `child: InkWell(`
- L465: `return GestureDetector(`

### `apps/empire_flutter/app/lib/modules/educator/educator_mission_plans_page.dart` (8)
- L83: `IconButton(`
- L110: `child: InkWell(`
- L273: `TextButton(`
- L283: `return ListTile(`
- L332: `child: OutlinedButton(`
- L339: `child: ElevatedButton(`
- L404: `TextButton(`
- L410: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/educator/educator_mission_review_page.dart` (5)
- L270: `child: InkWell(`
- L453: `return GestureDetector(`
- L659: `(int index) => GestureDetector(`
- L699: `child: OutlinedButton(`
- L729: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/educator/educator_sessions_page.dart` (5)
- L371: `TextButton(`
- L375: `ElevatedButton(`
- L403: `child: InkWell(`
- L561: `return GestureDetector(`
- L645: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/educator/educator_today_page.dart` (8)
- L324: `child: ElevatedButton(`
- L404: `TextButton(`
- L425: `TextButton(`
- L429: `ElevatedButton(`
- L531: `child: InkWell(`
- L590: `child: InkWell(`
- L764: `return ListTile(`
- L785: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/habits/habits_page.dart` (7)
- L88: `IconButton(`
- L486: `child: InkWell(`
- L613: `return GestureDetector(`
- L814: `IconButton(`
- L1038: `IconButton(`
- L1059: `return GestureDetector(`
- L1194: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_analytics_page.dart` (4)
- L89: `IconButton(`
- L420: `TextButton(`
- L470: `TextButton(`
- L474: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_approvals_page.dart` (2)
- L190: `child: OutlinedButton(`
- L198: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_audit_page.dart` (5)
- L84: `IconButton(`
- L98: `IconButton(`
- L166: `child: ListTile(`
- L235: `return ListTile(`
- L288: `child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_billing_page.dart` (8)
- L116: `IconButton(`
- L498: `TextButton(`
- L502: `ElevatedButton(`
- L616: `TextButton(`
- L724: `IconButton(`
- L729: `IconButton(`
- L967: `IconButton(`
- L1079: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_curriculum_page.dart` (5)
- L159: `child: InkWell(`
- L268: `Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))),`
- L271: `child: ElevatedButton(`
- L334: `TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),`
- L335: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_feature_flags_page.dart` (1)
- L81: `IconButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_integrations_health_page.dart` (3)
- L19: `IconButton(`
- L159: `return ListTile(`
- L168: `? TextButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_role_switcher_page.dart` (3)
- L47: `IconButton(`
- L186: `IconButton(`
- L360: `child: InkWell(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_safety_page.dart` (4)
- L158: `child: ListTile(`
- L162: `trailing: IconButton(`
- L220: `child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),`
- L224: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_sites_page.dart` (4)
- L158: `? IconButton(`
- L322: `child: InkWell(`
- L523: `return GestureDetector(`
- L667: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/user_admin_page.dart` (10)
- L112: `IconButton(`
- L204: `? IconButton(`
- L532: `child: InkWell(`
- L602: `child: InkWell(`
- L1171: `children: UserRole.values.map((UserRole role) => ListTile(`
- L1209: `TextButton(`
- L1213: `ElevatedButton(`
- L1282: `child: InkWell(`
- L1493: `TextButton(`
- L1497: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/learner/learner_portfolio_page.dart` (5)
- L125: `IconButton(`
- L554: `TextButton(`
- L558: `ElevatedButton(`
- L590: `TextButton(`
- L594: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/learner/learner_today_page.dart` (4)
- L99: `IconButton(`
- L312: `TextButton(`
- L357: `TextButton(`
- L501: `child: InkWell(`

### `apps/empire_flutter/app/lib/modules/messages/messages_page.dart` (5)
- L336: `child: InkWell(`
- L418: `child: InkWell(`
- L567: `child: ListTile(`
- L711: `IconButton(`
- L752: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/messages/notifications_page.dart` (2)
- L82: `TextButton(`
- L148: `child: InkWell(`

### `apps/empire_flutter/app/lib/modules/missions/missions_page.dart` (4)
- L463: `child: InkWell(`
- L534: `child: InkWell(`
- L910: `child: ElevatedButton(`
- L960: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/parent/parent_billing_page.dart` (9)
- L109: `IconButton(`
- L497: `TextButton(`
- L507: `child: OutlinedButton(`
- L577: `TextButton(`
- L581: `ElevatedButton(`
- L611: `TextButton(`
- L615: `ElevatedButton(`
- L770: `child: OutlinedButton(`
- L780: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/parent/parent_portfolio_page.dart` (1)
- L129: `child: InkWell(`

### `apps/empire_flutter/app/lib/modules/parent/parent_schedule_page.dart` (5)
- L178: `return GestureDetector(`
- L271: `TextButton(`
- L353: `TextButton(`
- L357: `ElevatedButton(`
- L517: `return GestureDetector(`

### `apps/empire_flutter/app/lib/modules/parent/parent_summary_page.dart` (3)
- L116: `IconButton(`
- L143: `return GestureDetector(`
- L391: `TextButton(`

### `apps/empire_flutter/app/lib/modules/partner/partner_contracts_page.dart` (3)
- L114: `child: InkWell(`
- L324: `...contract.deliverables.map((PartnerDeliverable d) => ListTile(`
- L336: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/partner/partner_listings_page.dart` (8)
- L35: `IconButton(`
- L151: `child: InkWell(`
- L343: `TextButton(`
- L354: `ElevatedButton(`
- L484: `child: OutlinedButton(`
- L491: `child: ElevatedButton(`
- L542: `TextButton(`
- L546: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/profile/profile_page.dart` (9)
- L55: `IconButton(`
- L68: `IconButton(`
- L308: `TextButton(`
- L312: `TextButton(`
- L373: `TextButton(`
- L377: `ElevatedButton(`
- L415: `TextButton(`
- L419: `ElevatedButton(`
- L460: `child: ListTile(`

### `apps/empire_flutter/app/lib/modules/provisioning/provisioning_page.dart` (24)
- L89: `floatingActionButton: FloatingActionButton(`
- L182: `child: ListTile(`
- L190: `trailing: IconButton(`
- L215: `ListTile(`
- L230: `ListTile(`
- L289: `child: ListTile(`
- L299: `trailing: IconButton(`
- L324: `ListTile(`
- L339: `ListTile(`
- L398: `child: ListTile(`
- L423: `trailing: IconButton(`
- L451: `TextButton(`
- L455: `TextButton(`
- L589: `TextButton(`
- L593: `ElevatedButton(`
- L713: `TextButton(`
- L717: `ElevatedButton(`
- L855: `SwitchListTile(`
- L864: `TextButton(`
- L868: `ElevatedButton(`
- ... 4 more

### `apps/empire_flutter/app/lib/modules/settings/settings_page.dart` (10)
- L379: `return ListTile(`
- L449: `TextButton(`
- L470: `TextButton(`
- L474: `ElevatedButton(`
- L511: `TextButton(`
- L515: `ElevatedButton(`
- L547: `TextButton(`
- L551: `ElevatedButton(`
- L635: `return ListTile(`
- L672: `return ListTile(`

### `apps/empire_flutter/app/lib/modules/site/site_billing_page.dart` (5)
- L114: `OutlinedButton(`
- L227: `TextButton(`
- L262: `return ListTile(`
- L306: `TextButton(`
- L310: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/site/site_dashboard_page.dart` (5)
- L110: `IconButton(`
- L348: `TextButton(`
- L385: `TextButton(`
- L389: `ElevatedButton(`
- L480: `return GestureDetector(`

### `apps/empire_flutter/app/lib/modules/site/site_identity_page.dart` (2)
- L193: `child: OutlinedButton(`
- L203: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/site/site_incidents_page.dart` (6)
- L171: `child: InkWell(`
- L315: `child: OutlinedButton(`
- L322: `child: ElevatedButton(`
- L351: `child: OutlinedButton(`
- L411: `TextButton(`
- L415: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/site/site_integrations_health_page.dart` (7)
- L57: `IconButton(`
- L194: `IconButton(`
- L228: `child: ElevatedButton(`
- L324: `ListTile(`
- L343: `ListTile(`
- L362: `ListTile(`
- L369: `ListTile(`

### `apps/empire_flutter/app/lib/modules/site/site_ops_page.dart` (2)
- L213: `child: InkWell(`
- L285: `return ListTile(`

### `apps/empire_flutter/app/lib/modules/site/site_sessions_page.dart` (6)
- L249: `IconButton(`
- L273: `return GestureDetector(`
- L329: `IconButton(`
- L514: `return GestureDetector(`
- L863: `child: ElevatedButton(`
- L929: `return GestureDetector(`

### `apps/empire_flutter/app/lib/offline/sync_status_widget.dart` (1)
- L76: `TextButton(`

### `apps/empire_flutter/app/lib/router/role_gate.dart` (1)
- L77: `ElevatedButton(`

### `apps/empire_flutter/app/lib/runtime/ai_coach_widget.dart` (2)
- L466: `InkWell(`
- L475: `InkWell(`

### `apps/empire_flutter/app/lib/ui/auth/login_page.dart` (5)
- L207: `TextButton(`
- L211: `ElevatedButton(`
- L486: `suffixIcon: IconButton(`
- L514: `child: TextButton(`
- L525: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/ui/landing/landing_page.dart` (6)
- L200: `TextButton(`
- L369: `TextButton(`
- L373: `ElevatedButton(`
- L393: `TextButton(`
- L830: `ElevatedButton(`
- L896: `return InkWell(`

### `apps/empire_flutter/app/lib/ui/widgets/cards.dart` (5)
- L47: `child: InkWell(`
- L209: `child: InkWell(`
- L375: `child: InkWell(`
- L628: `const ColorfulListTile({`
- L646: `return ListTile(`

### `apps/empire_flutter/app/lib/ui/widgets/learner_widgets.dart` (8)
- L114: `child: InkWell(`
- L261: `ElevatedButton(`
- L324: `const MissionListTile({`
- L366: `return ListTile(`
- L452: `child: InkWell(`
- L508: `IconButton(`
- L672: `child: InkWell(`
- L809: `return ListTile(`

