import type { UserRole } from '@/src/types/user';

const ROLE_ALIAS_MAP: Record<string, UserRole> = {
  learner: 'learner',
  student: 'learner',
  educator: 'educator',
  teacher: 'educator',
  parent: 'parent',
  guardian: 'parent',
  site: 'site',
  sitelead: 'site',
  site_lead: 'site',
  partner: 'partner',
  hq: 'hq',
  admin: 'hq'
};

export function normalizeUserRole(rawRole: unknown): UserRole | null {
  if (typeof rawRole !== 'string') return null;
  const normalized = rawRole.trim().toLowerCase();
  return ROLE_ALIAS_MAP[normalized] || null;
}

export function roleIsAllowed(rawRole: unknown, allowedRoles: UserRole[]): boolean {
  const normalized = normalizeUserRole(rawRole);
  return Boolean(normalized && allowedRoles.includes(normalized));
}
