# CTA Regression Inventory

Generated from first-party source in `app/`, `src/`, and `apps/empire_flutter/app/lib/`.

## Summary

- Web files with CTA markers: **42**
- Flutter files with CTA markers: **50**
- Web CTA marker instances: **209**
- Flutter CTA marker instances: **267**

## Blocker Scan

- Placeholder links (`href="#"`): **0**
- Dead registration path (`/learner-registration`): **0**
- Web TODO/FIXME in routes: **0**
- Flutter unimplemented handlers (`UnimplementedError`/`UnsupportedError`): **2**

## CTA Telemetry Coverage

- Web CTA files with direct telemetry hooks/calls: **20/42**
- Flutter CTA files with direct telemetry import/calls: **2/50**

### Web Coverage Matrix

- `app/[locale]/(auth)/login/page.tsx`: **covered**
- `app/[locale]/(auth)/register/page.tsx`: **covered**
- `app/[locale]/(protected)/educator/page.tsx`: **covered**
- `app/[locale]/(protected)/hq/page.tsx`: **covered**
- `app/[locale]/(protected)/parent/page.tsx`: **covered**
- `app/[locale]/(protected)/partner/page.tsx`: **covered**
- `app/[locale]/(protected)/site/page.tsx`: **covered**
- `app/[locale]/page.tsx`: **missing**
- `app/not-found.tsx`: **missing**
- `src/components/SignOutButton.tsx`: **missing**
- `src/components/analytics/AIInsightsPanel.tsx`: **missing**
- `src/components/analytics/AnalyticsDashboard.tsx`: **missing**
- `src/components/analytics/HQAnalyticsDashboard.tsx`: **covered**
- `src/components/analytics/ParentAnalyticsDashboard.tsx`: **covered**
- `src/components/analytics/StudentAnalyticsDashboard.tsx`: **covered**
- `src/components/checkpoints/CheckpointSubmission.tsx`: **covered**
- `src/components/goals/GoalSettingForm.tsx`: **covered**
- `src/components/motivation/EducatorFeedbackForm.tsx`: **missing**
- `src/components/motivation/StudentMotivationProfile.tsx`: **covered**
- `src/components/recognition/PeerRecognitionForm.tsx`: **covered**
- `src/components/sdt/AICoachPopup.tsx`: **covered**
- `src/components/sdt/AICoachScreen.tsx`: **missing**
- `src/components/sdt/LearningPathMap.tsx`: **missing**
- `src/components/sdt/ReflectionJournal.tsx`: **missing**
- `src/components/sdt/StudentDashboard.tsx`: **covered**
- `src/components/showcase/ShowcaseGallery.tsx`: **covered**
- `src/components/showcase/ShowcaseSubmissionForm.tsx`: **covered**
- `src/components/stripe/InvoiceHistory.tsx`: **missing**
- `src/components/stripe/PlanManager.tsx`: **missing**
- `src/components/stripe/PricingPlans.tsx`: **covered**
- `src/components/stripe/RefundManager.tsx`: **missing**
- `src/components/stripe/StripeDashboard.tsx`: **missing**
- `src/components/stripe/SubscriptionCard.tsx`: **missing**
- `src/components/stripe/SubscriptionManager.tsx`: **missing**
- `src/components/stripe/WebhookMonitor.tsx`: **missing**
- `src/components/ui/Button.tsx`: **missing**
- `src/features/auth/components/LoginForm.tsx`: **missing**
- `src/features/navigation/components/Navigation.tsx`: **missing**
- `src/hooks/useTelemetry.ts`: **covered**
- `src/types/FeedbackForm-impactory.tsx`: **missing**
- `src/types/FeedbackForm.tsx`: **missing**
- `src/types/SubmissionGrader.tsx`: **missing**

### Flutter Coverage Matrix

- `apps/empire_flutter/app/lib/dashboards/role_dashboard.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/attendance/attendance_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/checkin/checkin_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/educator/educator_integrations_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/educator/educator_learner_supports_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/educator/educator_learners_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/educator/educator_mission_plans_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/educator/educator_mission_review_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/educator/educator_sessions_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/educator/educator_today_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/habits/habits_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/hq_admin/hq_analytics_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/hq_admin/hq_approvals_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/hq_admin/hq_audit_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/hq_admin/hq_billing_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/hq_admin/hq_curriculum_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/hq_admin/hq_feature_flags_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/hq_admin/hq_integrations_health_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/hq_admin/hq_role_switcher_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/hq_admin/hq_safety_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/hq_admin/hq_sites_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/hq_admin/user_admin_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/learner/learner_portfolio_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/learner/learner_today_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/messages/messages_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/messages/notifications_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/missions/missions_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/parent/parent_billing_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/parent/parent_portfolio_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/parent/parent_schedule_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/parent/parent_summary_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/partner/partner_contracts_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/partner/partner_listings_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/profile/profile_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/provisioning/provisioning_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/settings/settings_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/site/site_billing_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/site/site_dashboard_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/site/site_identity_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/site/site_incidents_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/site/site_integrations_health_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/site/site_ops_page.dart`: **missing**
- `apps/empire_flutter/app/lib/modules/site/site_sessions_page.dart`: **missing**
- `apps/empire_flutter/app/lib/offline/sync_status_widget.dart`: **missing**
- `apps/empire_flutter/app/lib/router/role_gate.dart`: **missing**
- `apps/empire_flutter/app/lib/runtime/ai_coach_widget.dart`: **missing**
- `apps/empire_flutter/app/lib/ui/auth/login_page.dart`: **covered**
- `apps/empire_flutter/app/lib/ui/landing/landing_page.dart`: **covered**
- `apps/empire_flutter/app/lib/ui/widgets/cards.dart`: **missing**
- `apps/empire_flutter/app/lib/ui/widgets/learner_widgets.dart`: **missing**

## Flutter unimplemented handlers (`UnimplementedError`/`UnsupportedError`) Findings

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

### `app/[locale]/page.tsx` (1)
- L26: `<Link href={`/${locale}/register`} className="text-sm font-semibold leading-6 text-gray-900">`

### `app/not-found.tsx` (1)
- L8: `<Link href="/" className="mt-8 px-4 py-2 text-white bg-indigo-600 rounded-md hover:bg-indigo-700">`

### `src/components/SignOutButton.tsx` (1)
- L22: `<button onClick={handleSignOut} className="text-sm font-medium text-gray-500 hover:text-gray-900">`

### `src/components/analytics/AIInsightsPanel.tsx` (2)
- L343: `<button`
- L344: `onClick={() => setExpanded(!expanded)}`

### `src/components/analytics/AnalyticsDashboard.tsx` (6)
- L137: `<button`
- L138: `onClick={() => setTimeRange('week')}`
- L147: `<button`
- L148: `onClick={() => setTimeRange('month')}`
- L159: `<button`
- L160: `onClick={handleExportCSV}`

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
- L153: `<button`
- L155: `onClick={onCancel}`
- L178: `<button`
- L181: `onClick={() => setEngagementLevel(level)}`
- L214: `<button`
- L217: `onClick={() => setParticipationType(p.value)}`
- L238: `<button`
- L241: `onClick={() => toggleMotivationType(m.type)}`
- L270: `<button`
- L272: `onClick={addHighlight}`
- L287: `<button`
- L289: `onClick={() => removeHighlight(i)}`
- L304: `<button`
- L306: `onClick={() => setShowAdvanced(!showAdvanced)}`
- L345: `<button`
- L348: `onClick={() => addStrategy(type, strategy)}`
- L374: `<button`
- L376: `onClick={() => removeStrategy(i)}`
- L409: `<button`
- L411: `onClick={onCancel}`
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
- L118: `<button`
- L119: `onClick={() => setMode('hint')}`
- L129: `<button`
- L130: `onClick={() => setMode('rubric_check')}`
- L140: `<button`
- L141: `onClick={() => setMode('debug')}`
- L156: `<button`
- L157: `onClick={() => {`
- L186: `<button`
- L187: `onClick={handleSubmitQuestion}`
- L266: `<button`
- L267: `onClick={handleSubmitExplainBack}`
- L278: `<button`
- L279: `onClick={() => {`

### `src/components/sdt/LearningPathMap.tsx` (4)
- L187: `<button`
- L188: `onClick={onToggle}`
- L258: `<button`
- L259: `onClick={(e) => {`

### `src/components/sdt/ReflectionJournal.tsx` (7)
- L155: `<button`
- L158: `onClick={() => setEffortLevel(level)}`
- L186: `<button`
- L189: `onClick={() => setEnjoymentLevel(level)}`
- L235: `<button`
- L349: `<button`
- L350: `onClick={handleSubmit}`

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

### `src/components/stripe/InvoiceHistory.tsx` (4)
- L95: `<button`
- L96: `onClick={fetchInvoices}`
- L167: `<button`
- L168: `onClick={() => handleRetryPayment(invoice.id)}`

### `src/components/stripe/PlanManager.tsx` (19)
- L329: `<button`
- L330: `onClick={fetchProducts}`
- L337: `<button`
- L338: `onClick={() => setModalType('createProduct')}`
- L354: `<button onClick={() => setError(null)} className="ml-auto" title="Dismiss error" aria-label="Dismiss error">`
- L397: `<button`
- L398: `onClick={() => openEditProduct(product)}`
- L404: `<button`
- L405: `onClick={() => openCreatePrice(product)}`
- L412: `<button`
- L413: `onClick={() => handleArchiveProduct(product)}`
- L465: `<button`
- L466: `onClick={() => handleTogglePriceActive(price.id, price.active)}`
- L501: `<button`
- L502: `onClick={closeModal}`
- L636: `<button`
- L637: `onClick={closeModal}`
- L642: `<button`
- L643: `onClick={() => {`

### `src/components/stripe/PricingPlans.tsx` (3)
- L116: `<button`
- L117: `onClick={() => onSubscribe(plan.id)}`
- L214: `onClick={() => {`

### `src/components/stripe/RefundManager.tsx` (1)
- L196: `<button`

### `src/components/stripe/StripeDashboard.tsx` (2)
- L83: `<button`
- L84: `onClick={fetchMetrics}`

### `src/components/stripe/SubscriptionCard.tsx` (6)
- L130: `<button`
- L131: `onClick={handleManageBilling}`
- L140: `<button`
- L141: `onClick={handleCancel}`
- L151: `<button`
- L152: `onClick={handleResume}`

### `src/components/stripe/SubscriptionManager.tsx` (2)
- L56: `<button`
- L57: `onClick={fetchSubscriptions}`

### `src/components/stripe/WebhookMonitor.tsx` (2)
- L117: `<button`
- L118: `onClick={fetchLogs}`

### `src/components/ui/Button.tsx` (1)
- L35: `<button`

### `src/features/auth/components/LoginForm.tsx` (1)
- L75: `<Button onClick={handleGoogleSignIn} className='w-full' variant='outline'>`

### `src/features/navigation/components/Navigation.tsx` (1)
- L33: `<Button onClick={handleSignOut} variant="ghost" size="sm">`

### `src/hooks/useTelemetry.ts` (3)
- L101: `*     <button onClick={() => trackClick('feature_discovered', { missionId })}>`
- L171: `*   return <button onClick={handleSubmit}>Submit</button>;`
- L204: `*   return <button onClick={handleGiveRecognition}>Give Props</button>;`

### `src/types/FeedbackForm-impactory.tsx` (6)
- L49: `<button`
- L50: `onClick={onCancel}`
- L56: `<button`
- L57: `onClick={() => handleGrade('started')}`
- L63: `<button`
- L64: `onClick={() => handleGrade('completed')}`

### `src/types/FeedbackForm.tsx` (6)
- L49: `<button`
- L50: `onClick={onCancel}`
- L56: `<button`
- L57: `onClick={() => handleGrade('started')}`
- L63: `<button`
- L64: `onClick={() => handleGrade('completed')}`

### `src/types/SubmissionGrader.tsx` (2)
- L55: `<button`
- L56: `onClick={() => setIsGrading(true)}`

## Flutter CTA Files

### `apps/empire_flutter/app/lib/dashboards/role_dashboard.dart` (10)
- L570: `IconButton(`
- L575: `IconButton(`
- L580: `IconButton(`
- L613: `TextButton(`
- L764: `return ListTile(`
- L792: `TextButton(`
- L796: `ElevatedButton(`
- L831: `...appState.siteIds.map((String siteId) => ListTile(`
- L875: `TextButton(`
- L879: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/attendance/attendance_page.dart` (2)
- L123: `child: ListTile(`
- L495: `child: InkWell(`

### `apps/empire_flutter/app/lib/modules/checkin/checkin_page.dart` (10)
- L108: `IconButton(`
- L194: `? IconButton(`
- L397: `TextButton(`
- L509: `child: InkWell(`
- L693: `IconButton(`
- L745: `...summary.authorizedPickups.map((AuthorizedPickup pickup) => ListTile(`
- L780: `? IconButton(`
- L819: `child: InkWell(`
- L1102: `child: ElevatedButton(`
- L1198: `return InkWell(`

### `apps/empire_flutter/app/lib/modules/educator/educator_integrations_page.dart` (1)
- L183: `: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/educator/educator_learner_supports_page.dart` (6)
- L56: `IconButton(`
- L153: `child: InkWell(`
- L364: `child: OutlinedButton(`
- L371: `child: ElevatedButton(`
- L404: `TextButton(`
- L408: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/educator/educator_learners_page.dart` (3)
- L148: `? IconButton(`
- L275: `child: InkWell(`
- L423: `return GestureDetector(`

### `apps/empire_flutter/app/lib/modules/educator/educator_mission_plans_page.dart` (8)
- L82: `IconButton(`
- L109: `child: InkWell(`
- L268: `TextButton(`
- L278: `return ListTile(`
- L323: `child: OutlinedButton(`
- L330: `child: ElevatedButton(`
- L391: `TextButton(`
- L397: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/educator/educator_mission_review_page.dart` (5)
- L265: `child: InkWell(`
- L448: `return GestureDetector(`
- L654: `(int index) => GestureDetector(`
- L694: `child: OutlinedButton(`
- L717: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/educator/educator_sessions_page.dart` (5)
- L354: `TextButton(`
- L358: `ElevatedButton(`
- L386: `child: InkWell(`
- L544: `return GestureDetector(`
- L628: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/educator/educator_today_page.dart` (8)
- L311: `child: ElevatedButton(`
- L383: `TextButton(`
- L400: `TextButton(`
- L404: `ElevatedButton(`
- L502: `child: InkWell(`
- L561: `child: InkWell(`
- L735: `return ListTile(`
- L756: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/habits/habits_page.dart` (7)
- L87: `IconButton(`
- L485: `child: InkWell(`
- L612: `return GestureDetector(`
- L799: `IconButton(`
- L1023: `IconButton(`
- L1044: `return GestureDetector(`
- L1179: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_analytics_page.dart` (4)
- L88: `IconButton(`
- L407: `TextButton(`
- L449: `TextButton(`
- L453: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_approvals_page.dart` (2)
- L189: `child: OutlinedButton(`
- L197: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_audit_page.dart` (5)
- L83: `IconButton(`
- L87: `IconButton(`
- L147: `child: ListTile(`
- L216: `return ListTile(`
- L259: `child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_billing_page.dart` (8)
- L115: `IconButton(`
- L459: `TextButton(`
- L463: `ElevatedButton(`
- L560: `TextButton(`
- L659: `IconButton(`
- L664: `IconButton(`
- L902: `IconButton(`
- L1014: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_curriculum_page.dart` (5)
- L148: `child: InkWell(`
- L247: `Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))),`
- L250: `child: ElevatedButton(`
- L304: `TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),`
- L305: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_feature_flags_page.dart` (1)
- L80: `IconButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_integrations_health_page.dart` (3)
- L18: `IconButton(`
- L150: `return ListTile(`
- L159: `? TextButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_role_switcher_page.dart` (3)
- L46: `IconButton(`
- L175: `IconButton(`
- L339: `child: InkWell(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_safety_page.dart` (4)
- L157: `child: ListTile(`
- L161: `trailing: IconButton(`
- L209: `child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),`
- L213: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/hq_sites_page.dart` (4)
- L157: `? IconButton(`
- L313: `child: InkWell(`
- L514: `return GestureDetector(`
- L658: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/hq_admin/user_admin_page.dart` (10)
- L111: `IconButton(`
- L197: `? IconButton(`
- L517: `child: InkWell(`
- L587: `child: InkWell(`
- L1156: `children: UserRole.values.map((UserRole role) => ListTile(`
- L1194: `TextButton(`
- L1198: `ElevatedButton(`
- L1267: `child: InkWell(`
- L1478: `TextButton(`
- L1482: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/learner/learner_portfolio_page.dart` (5)
- L114: `IconButton(`
- L533: `TextButton(`
- L537: `ElevatedButton(`
- L561: `TextButton(`
- L565: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/learner/learner_today_page.dart` (4)
- L98: `IconButton(`
- L305: `TextButton(`
- L344: `TextButton(`
- L482: `child: InkWell(`

### `apps/empire_flutter/app/lib/modules/messages/messages_page.dart` (5)
- L321: `child: InkWell(`
- L403: `child: InkWell(`
- L552: `child: ListTile(`
- L696: `IconButton(`
- L737: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/messages/notifications_page.dart` (2)
- L81: `TextButton(`
- L147: `child: InkWell(`

### `apps/empire_flutter/app/lib/modules/missions/missions_page.dart` (4)
- L454: `child: InkWell(`
- L525: `child: InkWell(`
- L901: `child: ElevatedButton(`
- L944: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/parent/parent_billing_page.dart` (9)
- L108: `IconButton(`
- L496: `TextButton(`
- L506: `child: OutlinedButton(`
- L560: `TextButton(`
- L564: `ElevatedButton(`
- L590: `TextButton(`
- L594: `ElevatedButton(`
- L749: `child: OutlinedButton(`
- L759: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/parent/parent_portfolio_page.dart` (1)
- L128: `child: InkWell(`

### `apps/empire_flutter/app/lib/modules/parent/parent_schedule_page.dart` (5)
- L171: `return GestureDetector(`
- L264: `TextButton(`
- L338: `TextButton(`
- L342: `ElevatedButton(`
- L502: `return GestureDetector(`

### `apps/empire_flutter/app/lib/modules/parent/parent_summary_page.dart` (3)
- L115: `IconButton(`
- L136: `return GestureDetector(`
- L375: `TextButton(`

### `apps/empire_flutter/app/lib/modules/partner/partner_contracts_page.dart` (3)
- L103: `child: InkWell(`
- L303: `...contract.deliverables.map((PartnerDeliverable d) => ListTile(`
- L315: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/partner/partner_listings_page.dart` (8)
- L34: `IconButton(`
- L120: `child: InkWell(`
- L304: `TextButton(`
- L315: `ElevatedButton(`
- L425: `child: OutlinedButton(`
- L432: `child: ElevatedButton(`
- L474: `TextButton(`
- L478: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/profile/profile_page.dart` (9)
- L54: `IconButton(`
- L67: `IconButton(`
- L307: `TextButton(`
- L311: `TextButton(`
- L368: `TextButton(`
- L372: `ElevatedButton(`
- L403: `TextButton(`
- L407: `ElevatedButton(`
- L444: `child: ListTile(`

### `apps/empire_flutter/app/lib/modules/provisioning/provisioning_page.dart` (24)
- L77: `floatingActionButton: FloatingActionButton(`
- L156: `child: ListTile(`
- L164: `trailing: IconButton(`
- L183: `ListTile(`
- L194: `ListTile(`
- L248: `child: ListTile(`
- L258: `trailing: IconButton(`
- L277: `ListTile(`
- L288: `ListTile(`
- L342: `child: ListTile(`
- L367: `trailing: IconButton(`
- L389: `TextButton(`
- L393: `TextButton(`
- L523: `TextButton(`
- L527: `ElevatedButton(`
- L647: `TextButton(`
- L651: `ElevatedButton(`
- L789: `SwitchListTile(`
- L798: `TextButton(`
- L802: `ElevatedButton(`
- ... 4 more

### `apps/empire_flutter/app/lib/modules/settings/settings_page.dart` (10)
- L366: `return ListTile(`
- L425: `TextButton(`
- L442: `TextButton(`
- L446: `ElevatedButton(`
- L475: `TextButton(`
- L479: `ElevatedButton(`
- L507: `TextButton(`
- L511: `ElevatedButton(`
- L595: `return ListTile(`
- L632: `return ListTile(`

### `apps/empire_flutter/app/lib/modules/site/site_billing_page.dart` (5)
- L113: `OutlinedButton(`
- L216: `TextButton(`
- L241: `return ListTile(`
- L285: `TextButton(`
- L289: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/site/site_dashboard_page.dart` (5)
- L109: `IconButton(`
- L347: `TextButton(`
- L377: `TextButton(`
- L381: `ElevatedButton(`
- L461: `return GestureDetector(`

### `apps/empire_flutter/app/lib/modules/site/site_identity_page.dart` (2)
- L192: `child: OutlinedButton(`
- L202: `child: ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/site/site_incidents_page.dart` (6)
- L160: `child: InkWell(`
- L294: `child: OutlinedButton(`
- L301: `child: ElevatedButton(`
- L319: `child: OutlinedButton(`
- L379: `TextButton(`
- L383: `ElevatedButton(`

### `apps/empire_flutter/app/lib/modules/site/site_integrations_health_page.dart` (7)
- L56: `IconButton(`
- L185: `IconButton(`
- L208: `child: ElevatedButton(`
- L295: `ListTile(`
- L305: `ListTile(`
- L315: `ListTile(`
- L322: `ListTile(`

### `apps/empire_flutter/app/lib/modules/site/site_ops_page.dart` (2)
- L203: `child: InkWell(`
- L265: `return ListTile(`

### `apps/empire_flutter/app/lib/modules/site/site_sessions_page.dart` (6)
- L215: `IconButton(`
- L231: `return GestureDetector(`
- L276: `IconButton(`
- L415: `return GestureDetector(`
- L764: `child: ElevatedButton(`
- L830: `return GestureDetector(`

### `apps/empire_flutter/app/lib/offline/sync_status_widget.dart` (1)
- L75: `TextButton(`

### `apps/empire_flutter/app/lib/router/role_gate.dart` (1)
- L76: `ElevatedButton(`

### `apps/empire_flutter/app/lib/runtime/ai_coach_widget.dart` (2)
- L434: `InkWell(`
- L443: `InkWell(`

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
- L35: `child: InkWell(`
- L189: `child: InkWell(`
- L347: `child: InkWell(`
- L592: `const ColorfulListTile({`
- L610: `return ListTile(`

### `apps/empire_flutter/app/lib/ui/widgets/learner_widgets.dart` (8)
- L102: `child: InkWell(`
- L241: `ElevatedButton(`
- L293: `const MissionListTile({`
- L335: `return ListTile(`
- L413: `child: InkWell(`
- L461: `IconButton(`
- L617: `child: InkWell(`
- L746: `return ListTile(`

