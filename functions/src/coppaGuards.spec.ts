import assert from 'node:assert/strict';
import { hasSiteAccess, isCoppaConsentActive } from './coppaGuards';

function runCoppaGuardRegressionSuite(): void {
  const activeConsent = {
    active: true,
    agreementSigned: true,
    educationalUseOnly: true,
    parentNoticeProvided: true,
    noStudentMarketing: true,
  };

  assert.equal(isCoppaConsentActive(activeConsent), true, 'active consent should pass');

  const inactiveConsent = {
    ...activeConsent,
    active: false,
  };
  assert.equal(isCoppaConsentActive(inactiveConsent), false, 'inactive consent should fail');

  const missingFlagConsent = {
    active: true,
    agreementSigned: true,
    educationalUseOnly: true,
    parentNoticeProvided: true,
  };
  assert.equal(isCoppaConsentActive(missingFlagConsent), false, 'missing noStudentMarketing should fail');

  assert.equal(
    hasSiteAccess({ role: 'learner', siteIds: ['site-a', 'site-b'] }, 'site-a'),
    true,
    'learner with matching site should pass',
  );

  assert.equal(
    hasSiteAccess({ role: 'learner', siteIds: ['site-a'] }, 'site-z'),
    false,
    'cross-site learner access should fail',
  );

  assert.equal(
    hasSiteAccess({ role: 'educator', activeSiteId: 'site-c' }, 'site-c'),
    true,
    'activeSiteId should grant scoped access',
  );

  assert.equal(
    hasSiteAccess({ role: 'hq', siteIds: [] }, 'site-any'),
    true,
    'hq role should bypass site restriction',
  );

  assert.equal(
    hasSiteAccess(undefined, 'site-any'),
    false,
    'missing profile should fail site access',
  );
}

runCoppaGuardRegressionSuite();
console.log('COPPA regression suite passed.');
