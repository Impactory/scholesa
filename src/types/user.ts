import { Timestamp } from 'firebase/firestore';

export type UserRole = 'learner' | 'parent' | 'educator' | 'site' | 'partner' | 'hq';

export interface UserProfile {
  uid: string;
  email: string;
  displayName: string;
  role: UserRole;
  studioId?: string;
  siteIds?: string[];
  activeSiteId?: string;
  organizationId?: string;
  authProviderId?: string;
  authProviderType?: 'oidc' | 'saml' | 'google' | 'password' | 'custom';
  authMethods?: string[];
  jitProvisioned?: boolean;
  isActive?: boolean;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
