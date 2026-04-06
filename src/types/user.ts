import { Timestamp } from 'firebase/firestore';
import type { StageId } from './schema';

export type UserRole = 'learner' | 'parent' | 'educator' | 'site' | 'partner' | 'hq';

export type AgeBand = 'under13' | '13-17' | '18+';

export interface RegistrationConsent {
  consentAccepted: boolean;
  tosAccepted: boolean;
  ageBand: AgeBand;
  parentConsentConfirmed: boolean;
  consentTimestamp: Timestamp;
  pipedaCrossBorderAcknowledged: boolean;
}

export interface UserProfile {
  uid: string;
  email: string;
  displayName: string;
  role: UserRole;
  studioId?: string;
  stageId?: StageId;
  siteIds?: string[];
  activeSiteId?: string;
  organizationId?: string;
  authProviderId?: string;
  authProviderType?: 'oidc' | 'saml' | 'google' | 'password' | 'custom';
  authMethods?: string[];
  jitProvisioned?: boolean;
  isActive?: boolean;
  registrationConsent?: RegistrationConsent;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
