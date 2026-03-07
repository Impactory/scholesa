# CTA Full Inventory & Regression Source

Generated from first-party source in `app/`, `src/`, and `apps/empire_flutter/app/lib/`.

## Scan Policy

- Actionable CTA coverage includes UI files with direct user-interaction markers and expected telemetry hooks/calls.
- Excluded non-actionable web files are utility/type-only paths listed in `NON_ACTIONABLE_WEB_PATHS`.
- Blocker findings exclude known generated/framework stubs listed in `NON_ACTIONABLE_BLOCKER_PATHS`.
- Route TODO/FIXME blocker scan is restricted to route surfaces (`page.tsx`, `layout.tsx`, `loading.tsx`, `error.tsx`, `not-found.tsx`, `route.ts`).

## Summary

- Web files with CTA markers: **37**
- Flutter files with CTA markers: **53**
- Web CTA marker instances: **206**
- Flutter CTA marker instances: **317**
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
- L511: `<button`
- L512: `onClick={handleOpenPopup}`
- L533: `<button`
- L534: `onClick={handleMinimizePopup}`
- L596: `<button`
- L598: `onClick={() => setMode(modeKey)}`
- L617: `<button`
- L618: `onClick={reset}`
- L639: `<button`
- L640: `onClick={isListening ? stopListening : startListening}`
- L696: `<button`
- L697: `onClick={async () => {`
- L709: `<button`
- L710: `onClick={async () => {`
- L759: `<button`
- L760: `onClick={handleSubmitExplainBack}`
- L769: `<button`
- L770: `onClick={reset}`

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
- L183: `onClick={() =>`
- L203: `<button`
- L205: `onClick={() => {`
- L217: `<button`
- L219: `onClick={() => setCreateOpen((prev) => !prev)}`
- L245: `<button`
- L248: `onClick={() => {`
- L255: `<button`
- L257: `onClick={() => setCreateOpen(false)}`
- L295: `<button`
- L298: `onClick={() => {`
- L307: `<button`
- L310: `onClick={() => {`

### `src/hooks/useTelemetry.ts` (3)
- L145: `*     <button onClick={() => trackClick('feature_discovered', { missionId })}>`
- L215: `*   return <button onClick={handleSubmit}>Submit</button>;`
- L248: `*   return <button onClick={handleGiveRecognition}>Give Props</button>;`

### `src/lib/theme/ThemeModeToggle.tsx` (2)
- L44: `<button`
- L49: `onClick={() => {`

## Flutter CTA Files

### `apps/empire_flutter/app/lib/dashboards/role_dashboard.dart` (10)
- L727: `IconButton(`
- L741: `IconButton(`
- L756: `IconButton(`
- L791: `TextButton(`
- L1107: `return ListTile(`
- L1142: `TextButton(`
- L1155: `ElevatedButton(`
- L1197: `...appState.siteIds.map((String siteId) => ListTile(`
- L1256: `TextButton(`
- L1269: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/attendance/attendance_page.dart` (3)
- L163: `return RefreshIndicator(`
- L186: `child: ListTile(`
- L629: `child: InkWell(`

### `apps/empire_flutter/app/lib/modules/checkin/checkin_page.dart` (11)
- L162: `IconButton(`
- L266: `? IconButton(`
- L580: `TextButton(`
- L710: `child: InkWell(`
- L909: `IconButton(`
- L920: `IconButton(`
- L982: `.map((AuthorizedPickup pickup) => ListTile(`
- L1021: `? IconButton(`
- L1068: `child: InkWell(`
- L1370: `child: ElevatedButton(`
- L1488: `return InkWell(`

### `apps/empire_flutter/app/lib/modules/educator/educator_integrations_page.dart` (1)
- L290: `: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/educator/educator_learner_supports_page.dart` (10)
- L106: `IconButton(`
- L263: `child: InkWell(`
- L513: `child: OutlinedButton(`
- L540: `child: ElevatedButton(`
- L631: `TextButton(`
- L653: `ElevatedButton(`
- L723: `TextButton(`
- L736: `TextButton(`
- L740: `TextButton(`
- L744: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/educator/educator_learners_page.dart` (3)
- L378: `? IconButton(`
- L545: `child: InkWell(`
- L693: `return GestureDetector(`

### `apps/empire_flutter/app/lib/modules/educator/educator_mission_plans_page.dart` (9)
- L136: `IconButton(`
- L197: `child: InkWell(`
- L398: `TextButton(`
- L410: `ElevatedButton(`
- L430: `return ListTile(`
- L481: `child: OutlinedButton(`
- L497: `child: ElevatedButton(`
- L588: `TextButton(`
- L600: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/educator/educator_mission_review_page.dart` (5)
- L388: `child: InkWell(`
- L583: `return GestureDetector(`
- L800: `(int index) => GestureDetector(`
- L851: `child: OutlinedButton(`
- L915: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/educator/educator_sessions_page.dart` (5)
- L546: `TextButton(`
- L560: `ElevatedButton(`
- L587: `child: InkWell(`
- L759: `return GestureDetector(`
- L879: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/educator/educator_today_page.dart` (10)
- L510: `child: ElevatedButton(`
- L603: `TextButton(`
- L636: `TextButton(`
- L648: `ElevatedButton(`
- L724: `child: ListTile(`
- L731: `trailing: IconButton(`
- L877: `child: InkWell(`
- L944: `child: InkWell(`
- L1134: `return ListTile(`
- L1157: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/habits/habits_page.dart` (8)
- L142: `IconButton(`
- L559: `child: InkWell(`
- L718: `return GestureDetector(`
- L991: `IconButton(`
- L1247: `IconButton(`
- L1477: `IconButton(`
- L1514: `return GestureDetector(`
- L1677: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_analytics_page.dart` (7)
- L255: `IconButton(`
- L266: `IconButton(`
- L946: `TextButton(`
- L991: `TextButton(`
- L1011: `ElevatedButton(`
- L1180: `TextButton(`
- L1193: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_approvals_page.dart` (2)
- L229: `child: OutlinedButton(`
- L238: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_audit_page.dart` (5)
- L104: `IconButton(`
- L118: `IconButton(`
- L240: `child: ListTile(`
- L315: `return ListTile(`
- L395: `child: OutlinedButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_billing_page.dart` (8)
- L196: `IconButton(`
- L586: `TextButton(`
- L590: `ElevatedButton(`
- L1058: `TextButton(`
- L1171: `IconButton(`
- L1176: `IconButton(`
- L1436: `IconButton(`
- L1554: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_curriculum_page.dart` (9)
- L233: `child: InkWell(`
- L368: `child: OutlinedButton(`
- L390: `child: ElevatedButton(`
- L700: `TextButton(`
- L707: `ElevatedButton(`
- L864: `TextButton(`
- L881: `ElevatedButton(`
- L1196: `TextButton(`
- L1203: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_feature_flags_page.dart` (1)
- L89: `IconButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_integrations_health_page.dart` (3)
- L70: `IconButton(`
- L260: `return ListTile(`
- L270: `? TextButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_role_switcher_page.dart` (3)
- L98: `IconButton(`
- L244: `IconButton(`
- L420: `child: InkWell(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_safety_page.dart` (4)
- L241: `child: ListTile(`
- L247: `trailing: IconButton(`
- L328: `child: OutlinedButton(`
- L346: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_sites_page.dart` (4)
- L174: `? IconButton(`
- L576: `child: InkWell(`
- L784: `return GestureDetector(`
- L938: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/user_admin_page.dart` (10)
- L185: `IconButton(`
- L290: `? IconButton(`
- L630: `child: InkWell(`
- L708: `child: InkWell(`
- L1356: `.map((UserRole role) => ListTile(`
- L1414: `TextButton(`
- L1427: `ElevatedButton(`
- L1505: `child: InkWell(`
- L1749: `TextButton(`
- L1761: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/learner/learner_portfolio_page.dart` (7)
- L221: `IconButton(`
- L655: `TextButton(`
- L669: `ElevatedButton(`
- L701: `TextButton(`
- L715: `ElevatedButton(`
- L760: `child: ListTile(`
- L767: `trailing: IconButton(`

### `apps/empire_flutter/app/lib/modules/learner/learner_today_page.dart` (6)
- L154: `IconButton(`
- L448: `TextButton(`
- L526: `TextButton(`
- L580: `child: ListTile(`
- L587: `trailing: IconButton(`
- L795: `child: InkWell(`

### `apps/empire_flutter/app/lib/modules/messages/messages_page.dart` (5)
- L414: `child: InkWell(`
- L495: `child: InkWell(`
- L661: `child: ListTile(`
- L815: `IconButton(`
- L866: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/messages/notifications_page.dart` (2)
- L73: `TextButton(`
- L158: `child: InkWell(`

### `apps/empire_flutter/app/lib/modules/missions/missions_page.dart` (5)
- L553: `child: InkWell(`
- L623: `child: InkWell(`
- L1033: `child: ElevatedButton(`
- L1103: `child: ElevatedButton(`
- L1223: `IconButton(`

### `apps/empire_flutter/app/lib/modules/parent/parent_billing_page.dart` (9)
- L213: `IconButton(`
- L669: `TextButton(`
- L679: `child: OutlinedButton(`
- L849: `TextButton(`
- L861: `ElevatedButton(`
- L899: `TextButton(`
- L911: `ElevatedButton(`
- L1085: `child: OutlinedButton(`
- L1104: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/parent/parent_portfolio_page.dart` (3)
- L156: `child: InkWell(`
- L457: `child: ListTile(`
- L464: `trailing: IconButton(`

### `apps/empire_flutter/app/lib/modules/parent/parent_schedule_page.dart` (6)
- L214: `IconButton(`
- L391: `return GestureDetector(`
- L519: `TextButton(`
- L612: `TextButton(`
- L624: `ElevatedButton(`
- L990: `return GestureDetector(`

### `apps/empire_flutter/app/lib/modules/parent/parent_summary_page.dart` (3)
- L197: `IconButton(`
- L226: `return GestureDetector(`
- L516: `TextButton(`

### `apps/empire_flutter/app/lib/modules/partner/partner_contracts_page.dart` (4)
- L72: `return RefreshIndicator(`
- L141: `child: InkWell(`
- L357: `...contract.deliverables.map((PartnerDeliverable d) => ListTile(`
- L371: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/partner/partner_listings_page.dart` (9)
- L74: `IconButton(`
- L100: `return RefreshIndicator(`
- L191: `child: InkWell(`
- L386: `TextButton(`
- L397: `ElevatedButton(`
- L532: `child: OutlinedButton(`
- L539: `child: ElevatedButton(`
- L593: `TextButton(`
- L597: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/partner/partner_payouts_page.dart` (1)
- L70: `child: RefreshIndicator(`

### `apps/empire_flutter/app/lib/modules/profile/profile_page.dart` (9)
- L116: `IconButton(`
- L135: `IconButton(`
- L460: `TextButton(`
- L472: `TextButton(`
- L548: `TextButton(`
- L558: `ElevatedButton(`
- L596: `TextButton(`
- L609: `ElevatedButton(`
- L653: `child: ListTile(`

### `apps/empire_flutter/app/lib/modules/provisioning/provisioning_page.dart` (26)
- L184: `floatingActionButton: FloatingActionButton(`
- L289: `return RefreshIndicator(`
- L311: `child: ListTile(`
- L322: `trailing: IconButton(`
- L351: `ListTile(`
- L371: `ListTile(`
- L420: `return RefreshIndicator(`
- L442: `child: ListTile(`
- L454: `trailing: IconButton(`
- L483: `ListTile(`
- L503: `ListTile(`
- L552: `return RefreshIndicator(`
- L574: `child: ListTile(`
- L601: `trailing: IconButton(`
- L636: `TextButton(`
- L650: `TextButton(`
- L805: `TextButton(`
- L814: `ElevatedButton(`
- L947: `TextButton(`
- L956: `ElevatedButton(`
- ... 6 more

### `apps/empire_flutter/app/lib/modules/settings/settings_page.dart` (21)
- L549: `child: OutlinedButton(`
- L556: `child: ElevatedButton(`
- L644: `child: OutlinedButton(`
- L651: `child: ElevatedButton(`
- L727: `child: OutlinedButton(`
- L734: `child: ElevatedButton(`
- L845: `return ListTile(`
- L895: `return ListTile(`
- L952: `return ListTile(`
- L1054: `child: OutlinedButton(`
- L1061: `child: ElevatedButton(`
- L1111: `TextButton(`
- L1142: `TextButton(`
- L1146: `ElevatedButton(`
- L1190: `TextButton(`
- L1194: `ElevatedButton(`
- L1242: `TextButton(`
- L1246: `ElevatedButton(`
- L1284: `TextButton(`
- L1391: `return ListTile(`
- ... 1 more

### `apps/empire_flutter/app/lib/modules/site/site_billing_page.dart` (5)
- L186: `OutlinedButton(`
- L309: `TextButton(`
- L362: `return ListTile(`
- L406: `TextButton(`
- L420: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/site/site_dashboard_page.dart` (5)
- L218: `IconButton(`
- L651: `TextButton(`
- L722: `TextButton(`
- L742: `ElevatedButton(`
- L1134: `return GestureDetector(`

### `apps/empire_flutter/app/lib/modules/site/site_identity_page.dart` (2)
- L224: `child: OutlinedButton(`
- L234: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/site/site_incidents_page.dart` (6)
- L224: `child: InkWell(`
- L381: `child: OutlinedButton(`
- L399: `child: ElevatedButton(`
- L429: `child: OutlinedButton(`
- L525: `TextButton(`
- L539: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/site/site_integrations_health_page.dart` (7)
- L81: `IconButton(`
- L252: `IconButton(`
- L292: `child: ElevatedButton(`
- L386: `ListTile(`
- L403: `ListTile(`
- L420: `ListTile(`
- L436: `ListTile(`

### `apps/empire_flutter/app/lib/modules/site/site_ops_page.dart` (2)
- L286: `child: InkWell(`
- L641: `return ListTile(`

### `apps/empire_flutter/app/lib/modules/site/site_sessions_page.dart` (7)
- L345: `IconButton(`
- L370: `return GestureDetector(`
- L428: `IconButton(`
- L917: `return GestureDetector(`
- L1130: `return ListTile(`
- L1418: `child: ElevatedButton(`
- L1627: `return GestureDetector(`

### `apps/empire_flutter/app/lib/offline/sync_status_widget.dart` (1)
- L91: `TextButton(`

### `apps/empire_flutter/app/lib/router/role_gate.dart` (1)
- L93: `ElevatedButton(`

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
- L235: `TextButton(`
- L251: `ElevatedButton(`
- L604: `suffixIcon: IconButton(`
- L645: `child: TextButton(`
- L671: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/ui/landing/landing_page.dart` (6)
- L281: `TextButton(`
- L455: `TextButton(`
- L467: `ElevatedButton(`
- L487: `TextButton(`
- L957: `ElevatedButton(`
- L1023: `return InkWell(`

### `apps/empire_flutter/app/lib/ui/widgets/cards.dart` (4)
- L55: `child: InkWell(`
- L264: `child: InkWell(`
- L445: `child: InkWell(`
- L720: `return ListTile(`

### `apps/empire_flutter/app/lib/ui/widgets/learner_widgets.dart` (7)
- L129: `child: InkWell(`
- L289: `ElevatedButton(`
- L399: `return ListTile(`
- L488: `child: InkWell(`
- L548: `IconButton(`
- L730: `child: InkWell(`
- L877: `return ListTile(`

## Web Quick Actions Files

## Flutter Quick Actions Files

### `apps/empire_flutter/app/lib/dashboards/role_dashboard.dart` (4)
- L97: `'Quick Actions': 'Acciones rápidas',`
- L99: `'All Quick Actions': 'Todas las acciones rápidas',`
- L783: `_t(context, 'Quick Actions'),`
- L1095: `_t(sheetContext, 'All Quick Actions'),`

### `apps/empire_flutter/app/lib/modules/educator/educator_today_page.dart` (2)
- L71: `/// Educator Today Page - Daily schedule and quick actions`
- L882: `'cta': 'educator_today_quick_action',`

### `apps/empire_flutter/app/lib/modules/hq_admin/user_admin_page.dart` (3)
- L46: `'Quick Actions': 'Acciones rápidas',`
- L1201: `// Quick Actions`
- L1203: `_tUserAdmin(context, 'Quick Actions'),`

### `apps/empire_flutter/app/lib/modules/learner/learner_today_page.dart` (2)
- L384: `'cta': 'learner_today_open_messages_quick_action'`
- L800: `'cta': 'learner_today_quick_action',`

### `apps/empire_flutter/app/lib/modules/site/site_ops_page.dart` (4)
- L21: `'Quick Actions': 'Acciones rápidas',`
- L252: `_tSiteOps(context, 'Quick Actions'),`
- L292: `'cta_id': 'quick_action',`
- L293: `'surface': 'quick_actions',`

### `apps/empire_flutter/app/lib/ui/widgets/cards.dart` (2)
- L425: `/// A quick action button with icon and label`
- L453: `'cta_id': 'tap_quick_action',`

