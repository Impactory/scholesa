import * as admin from 'firebase-admin';
import { FieldValue } from 'firebase-admin/firestore';

export type LogoutAuditRole =
  | 'learner'
  | 'educator'
  | 'parent'
  | 'site'
  | 'siteLead'
  | 'partner'
  | 'hq'
  | 'admin';

export interface LogoutAuditWriteParams {
  actorId: string;
  actorRole: LogoutAuditRole;
  source: string;
  siteId?: string;
  impersonatingRole?: string;
  collectionName?: string;
}

export function buildLogoutAuditRecord(params: LogoutAuditWriteParams) {
  return {
    actorId: params.actorId,
    actorRole: params.actorRole,
    action: 'auth.logout',
    entityType: 'session',
    entityId: params.actorId,
    siteId: params.siteId,
    details: {
      source: params.source,
      ...(params.impersonatingRole
        ? { impersonatingRole: params.impersonatingRole }
        : {}),
    },
    createdAt: FieldValue.serverTimestamp(),
  };
}

export async function persistLogoutAuditRecord(
  params: LogoutAuditWriteParams,
) {
  const collectionName = params.collectionName ?? 'auditLogs';
  const auditRef = admin.firestore().collection(collectionName).doc();
  await auditRef.set(buildLogoutAuditRecord(params));
  return auditRef.id;
}