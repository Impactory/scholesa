export type UserRole = 'learner' | 'parent' | 'educator' | 'hq';

export interface UserProfile {
  uid: string;
  email: string;
  displayName: string;
  role: UserRole;
  studioId?: string;
  createdAt: Date;
  updatedAt: Date;
}
