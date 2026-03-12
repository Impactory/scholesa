# RC3.2 Release Roadmap
## Post-Launch Enhancement Cycle (April–May 2026)

> Historical planning snapshot only. This roadmap reflects the March 3 RC3.2 planning state and is not a current release-control artifact.
> Current launch control is defined by `RC3_RELEASE_GATE_STANDARD_MARCH_8_2026.md`, `RC3_BIG_BANG_OPERATOR_SCRIPT_MARCH_12_2026.md`, and `RC3_BIG_BANG_CUTOVER_CHECKLIST_MARCH_12_2026.md`.

**Created**: March 3, 2026  
**Planning Lead**: Engineering Team  
**Status**: Draft (Awaiting approval)

---

## Executive Summary

RC3.2 is a focused enhancement cycle following the RC3 production launch. This release focuses on:

1. **Educator Page i18n Consolidation** (~2 hours)
2. **Localization Expansion** (Traditional Chinese, Thai)
3. **Testing Expansion** (Widget tests, integration tests)
4. **Code Quality Improvements**

**Timeline**: April 1 – May 15, 2026 (6 weeks)  
**Team Size**: 4 FTE  
**Expected Outcome**: Improved i18n architecture, expanded testing, better code maintainability

---

## Timeline & Milestones

### Phase 1: Educator Pages Migration (Week 1-2, April 1-14)

| Task | Effort | Owner | Deadline | Status |
|------|--------|-------|----------|--------|
| Migrate 6 educator pages to BosCoachingI18n | 2h | Mobile | Apr 7 | Not Started |
| Code review and QA | 1h | Team Lead | Apr 10 | Blocked |
| Merge to RC3.1-staging | 0.5h | DevOps | Apr 14 | Not Started |

**Subtasks**:
```
- educator_sessions_page.dart (30 min)
- educator_today_page.dart (30 min)
- educator_learner_supports_page.dart (20 min)
- educator_mission_review_page.dart (20 min)
- educator_mission_plans_page.dart (20 min) [Already partially done]
- educator_integrations_page.dart (20 min)
```

**Expected Outcome**: All educator pages using centralized BosCoachingI18n

### Phase 2: Localization Expansion (Week 2-3, April 7-21)

| Task | Effort | Owner | Deadline | Status |
|------|--------|-------|----------|--------|
| Add Traditional Chinese (zh-TW) support | 3h | Localization | Apr 14 | Not Started |
| Add Thai (th) support | 3h | Localization | Apr 21 | Not Started |
| Update i18n config and locale files | 2h | Backend | Apr 21 | Not Started |
| QA locale switching | 1h | QA | Apr 21 | Not Started |

**Files to Update**:
```
- src/lib/i18n/config.ts (add 'zh-TW', 'th' to SUPPORTED_LOCALES)
- src/lib/i18n/messages.ts (import zh-TW.json, th.json)
- src/lib/ai/modelAdapter.ts (add locale entries)
- src/lib/ai/multilingualGuardrails.ts (add locale entries)
- locales/zh-TW.json (create)
- locales/th.json (create)
```

**Expected Outcome**: Full i18n system supporting en, es, zh, zh-TW, th

### Phase 3: Testing Expansion (Week 3-5, April 14-28)

| Task | Effort | Owner | Deadline | Status |
|------|--------|-------|----------|--------|
| Create Flutter widget unit tests | 5h | Mobile | Apr 21 | Not Started |
| Create Next.js integration tests | 4h | Backend | Apr 28 | Not Started |
| Create Firestore rule tests | 3h | Backend | Apr 28 | Not Started |
| Increase code coverage to 80%+ | 2h | QA | Apr 28 | Not Started |

**Test Scope**:
```
Widget Tests (Flutter):
- BosCoachingI18n localization
- educator_learners_page components
- educator_sessions_page screens
- Error boundary handling

Integration Tests (Next.js):
- Auth flow (login → dashboard)
- Session creation → enrollment
- Mission assignment → review
- i18n key fallback behavior

Feature Tests (Firestore):
- Role-based access control
- Session scope validation
- Cross-site data isolation
```

**Expected Outcome**: 80%+ code coverage, automated testing gates

### Phase 4: Code Quality & Review (Week 5-6, May 1-15)

| Task | Effort | Owner | Deadline | Status |
|------|--------|-------|----------|--------|
| Deprecate inline i18n across all pages | 3h | Mobile | May 8 | Not Started |
| Refactor error handling patterns | 2h | Backend | May 8 | Not Started |
| Update architecture documentation | 1.5h | Tech Lead | May 15 | Not Started |
| Launch code quality metrics dashboard | 1h | DevOps | May 15 | Not Started |

**Expected Outcome**: Improved codebase maintainability, clear deprecation path

---

## Detailed Feature Breakdown

### Feature 1: Educator Pages i18n Consolidation

**Purpose**: Reduce code duplication, ensure consistency

**Scope**:
- Migrate all educator page translation maps to use BosCoachingI18n
- Remove page-local overrides where centralized version exists
- Update function signatures for consistency

**Success Criteria**:
- All 7 educator pages use centralized i18n
- No duplicate translation strings across pages
- Spanish translations verified by native speaker
- Build passes without warnings

**Risks**:
- Translations may differ slightly from centralized version
- **Mitigation**: QA review all pages with native Spanish speaker

---

### Feature 2: Traditional Chinese & Thai Localization

**Purpose**: Expand platform accessibility to APAC markets

**Scope**:
- Create zh-TW.json with all centralized translation strings
- Create th.json with all centralized translation strings
- Update i18n config to recognize new locales
- Test locale switching in all surfaces

**Success Criteria**:
- All UI strings translated to zh-TW and th
- Locale auto-detection working
- No missing translation keys
- RTL text rendering correct (Thai)

**Risks**:
- Translation quality if not reviewed by native speakers
- **Mitigation**: Hire native translators, budget $2-5K

**Locale Support Matrix** (Post-RC3.2):
```
| Locale | Landing | Login | Dashboard | Educator | Learner | Parent | HQ |
|--------|---------|-------|-----------|----------|---------|--------|-----|
| en     | ✓       | ✓     | ✓         | ✓        | ✓       | ✓      | ✓   |
| es     | ✓       | ✓     | ✓         | ✓        | ✓       | ✓      | ✓   |
| zh     | ✓       | ✓     | ✓         | ✓        | ✓       | ✓      | ✓   |
| zh-TW  | ✓       | ✓     | ✓         | ✓        | ✓       | ✓      | ✓   |
| th     | ✓       | ✓     | ✓         | ✓        | ✓       | ✓      | ✓   |
```

---

### Feature 3: Testing Expansion

**Purpose**: Increase code reliability and catch regressions early

**Scope**:
- Widget unit tests (Flutter)
- Integration tests (Next.js/Firestore)
- Feature/API tests
- Coverage reporting

**Success Criteria**:
- 80%+ line coverage (Flutter + TS)
- All critical user flows have integration tests
- CI/CD gates enforce test passing
- Weekly coverage reports

**Risks**:
- Test maintenance overhead
- **Mitigation**: Clear test patterns, documented best practices

---

### Feature 4: Code Quality Improvements

**Purpose**: Set technical foundation for future releases

**Scope**:
- Deprecate inline i18n across learner/parent pages
- Establish patterns for error handling
- Create architecture decision records (ADRs)
- Update design system documentation

**Success Criteria**:
- All deprecated patterns flagged in code
- Clear migration path documented
- Team trained on new patterns
- Code metrics dashboard launched

---

## Resource Allocation

### Team Composition

| Role | FTE | Allocation | Lead | Notes |
|------|-----|-----------|------|-------|
| Mobile Developer | 1.5 | 100% educator pages, testing | TBD | Focus on Flutter |
| Backend Developer | 1.0 | 50% i18n, 50% testing | TBD | Next.js + Firestore |
| QA Engineer | 0.5 | Testing, localization QA | TBD | Language skills if available |
| Tech Lead | 0.5 | Architecture, mentoring | TBD | Code review |
| **Total** | **3.5 FTE** | | | |

### Budget Estimate

| Item | Cost | Notes |
|------|------|-------|
| Developer labor (4 weeks × 3.5 FTE) | $12,000 | @ $85/hr fully loaded |
| Translation services (zh-TW, th) | $3,000 | Professional translators |
| Testing tools/licenses (if needed) | $500 | Playwright, coverage tools |
| Miscellaneous | $500 | Documentation, tools |
| **Total** | **$16,000** | Estimated |

---

## Dependencies & Blockers

### External Dependencies
- [ ] Native speakers for zh-TW and th translation review
- [ ] Firebase quota increases (if locale expansion impacts volume)
- [ ] Translation service vendor availability

### Internal Dependencies
- [ ] RC3 production stability (baseline before starting)
- [ ] BosCoachingI18n finalization (no breaking changes)
- [ ] Test infrastructure readiness

### Potential Blockers
| Blocker | Probability | Mitigation |
|---------|-------------|-----------|
| Production issue in RC3 | Medium | Keep 1 dev on-call |
| Translator unavailable | Low | Use in-house resources as backup |
| Test infrastructure delay | Low | Write tests manually if needed |

---

## Success Metrics

### Technical Metrics
- [ ] i18n coverage: 100% of strings centralized
- [ ] Test coverage: 80%+ (Flutter + TS)
- [ ] Locale support: 5 languages live
- [ ] Code duplication: < 5% (DRY principle)

### Experience Metrics
- [ ] Page load time: < 2.5s (p95) for all locales
- [ ] Locale switch latency: < 100ms
- [ ] Translation miss rate: < 0.1%
- [ ] User satisfaction: > 4.5/5 (if surveyed)

### Delivery Metrics
- [ ] On-time delivery (all milestones hit)
- [ ] Zero production bugs on release
- [ ] Code review: 2 approvals per PR
- [ ] Documentation: 100% updated

---

## Risk Mitigation

### Risk 1: Educator Page Migration Takes Longer

**Probability**: Low  
**Impact**: 2-3 day delay  

**Mitigation**:
- Break into smaller PRs
- Pair programming if stuck
- Pre-migration code reviews

---

### Risk 2: Translation Quality Issues

**Probability**: Medium  
**Impact**: 1 week delay for fixes

**Mitigation**:
- Hire professional translators early
- QA testing with native speakers
- Automated key coverage checks

---

### Risk 3: Test Infrastructure Not Ready

**Probability**: Low  
**Impact**: 1-2 weeks delay

**Mitigation**:
- Set up test environment in RC3 time
- Use existing test patterns where possible
- Manual testing as fallback

---

### Risk 4: Production Issue Requires Rollback

**Probability**: Medium  
**Impact**: Reduce velocity to 30%

**Mitigation**:
- Keep running build/test automation
- Assign developer to on-call rotation
- Maintain production stability as priority

---

## Approval & Sign-Off

### Stakeholders

| Stakeholder | Role | Status | Date |
|-------------|------|--------|------|
| VP Engineering | Approver | Pending | — |
| Tech Lead | Sponsor | Pending | — |
| Product Manager | Stakeholder | Pending | — |

**Approval Checklist**:
- [ ] Budget approved
- [ ] Team assigned
- [ ] Timeline accepted
- [ ] Success metrics agreed

---

## Post-RC3.2 Planning (RC3.3+)

Once RC3.2 launches, plan for:

1. **Parent/HQ Page i18n Consolidation** (Weeks 1-2, June)
2. **API Layer Internationalization** (Weeks 2-4, June)
3. **Mobile App Localization** (Weeks 1-4, July)
4. **Market Testing** (Weeks 5-8, July-August)

---

## Document Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-03-03 | Eng Team | Initial draft for RC3.2 |

**Next Review**: March 17, 2026 (approval meeting)  
**Target Launch**: May 15, 2026
