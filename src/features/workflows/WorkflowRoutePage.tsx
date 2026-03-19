'use client';

import Link from 'next/link';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { Spinner } from '@/src/components/ui/Spinner';
import { RoleRouteGuard } from '@/src/components/auth/RoleRouteGuard';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { useInteractionTracking, usePageViewTracking } from '@/src/hooks/useTelemetry';
import { normalizeUserRole } from '@/src/lib/auth/roleAliases';
import {
  getRoleNavigationPaths,
  getWorkflowRoute,
  type WorkflowPath,
} from '@/src/lib/routing/workflowRoutes';
import { useI18n } from '@/src/lib/i18n/useI18n';
import {
  createWorkflowRecord,
  deleteWorkflowRecord,
  loadWorkflowRecords,
  updateWorkflowRecord,
  type WorkflowCreateInput,
  type WorkflowFieldDefinition,
  type WorkflowLoadResult,
} from './workflowData';

interface WorkflowRoutePageProps {
  routePath: WorkflowPath;
}

function buildInitialFormValues(fields: WorkflowFieldDefinition[] = []): Record<string, string | boolean> {
  return fields.reduce<Record<string, string | boolean>>((acc, field) => {
    if (typeof field.defaultValue !== 'undefined') {
      acc[field.name] = field.defaultValue;
      return acc;
    }
    acc[field.name] = field.type === 'checkbox' ? false : '';
    return acc;
  }, {});
}

export function WorkflowRoutePage({ routePath }: WorkflowRoutePageProps) {
  const route = getWorkflowRoute(routePath);
  const { user, profile, loading: authLoading } = useAuthContext();
  const { locale } = useI18n();
  const trackInteraction = useInteractionTracking();
  const normalizedRole = normalizeUserRole(profile?.role);

  usePageViewTracking(`workflow${routePath.replace(/\//g, '_')}`, {
    routePath,
    ...(normalizedRole ? { role: normalizedRole } : {}),
  });

  const [data, setData] = useState<WorkflowLoadResult>({
    records: [],
    canCreate: false,
    canRefresh: true,
    createLabel: 'Create',
    createConfig: null,
  });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [createOpen, setCreateOpen] = useState(false);
  const [createInput, setCreateInput] = useState<WorkflowCreateInput>({
    values: {},
  });
  const [mutatingId, setMutatingId] = useState<string | null>(null);

  const formatMetadataLabel = (key: string) =>
    key
      .replace(/([a-z0-9])([A-Z])/g, '$1 $2')
      .replace(/_/g, ' ')
      .replace(/\b\w/g, (match) => match.toUpperCase());

  const ctx = useMemo(() => {
    if (!user || !normalizedRole) return null;
    return {
      routePath,
      locale,
      uid: user.uid,
      role: normalizedRole,
      profile: profile || null,
    };
  }, [locale, normalizedRole, profile, routePath, user]);

  const refresh = useCallback(async () => {
    if (!ctx) {
      setLoading(false);
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const next = await loadWorkflowRecords(ctx);
      setData(next);
    } catch (loadError) {
      console.error('Failed to load workflow data', { routePath, loadError });
      setError(loadError instanceof Error ? loadError.message : 'Failed to load workflow data.');
      setData((prev) => ({ ...prev, records: [] }));
    } finally {
      setLoading(false);
    }
  }, [ctx, routePath]);

  useEffect(() => {
    if (authLoading) return;
    void refresh();
  }, [authLoading, refresh]);

  useEffect(() => {
    setCreateInput({
      values: buildInitialFormValues(data.createConfig?.fields),
    });
  }, [data.createConfig]);

  if (!route) {
    return (
      <div className="rounded-lg border border-app bg-app-surface p-6 text-app-muted">
        Workflow route is not configured.
      </div>
    );
  }

  const navigationTargets = normalizedRole ? getRoleNavigationPaths(normalizedRole) : [];

  const submitCreate = async () => {
    if (!ctx) return;

    setMutatingId('create');
    try {
      await createWorkflowRecord(ctx, createInput);
      trackInteraction('feature_discovered', {
        cta: 'workflow_create',
        routePath,
      });
      setCreateOpen(false);
      setCreateInput({
        values: buildInitialFormValues(data.createConfig?.fields),
      });
      await refresh();
    } catch (createError) {
      console.error('Failed to create workflow record', { routePath, createError });
      setError(createError instanceof Error ? createError.message : 'Failed to create record.');
    } finally {
      setMutatingId(null);
    }
  };

  const triggerUpdate = async (recordId: string, collectionName: string) => {
    if (!ctx) return;
    setMutatingId(recordId);
    try {
      await updateWorkflowRecord(ctx, {
        routePath,
        id: recordId,
        collectionName,
      });
      trackInteraction('feature_discovered', {
        cta: 'workflow_update',
        routePath,
        recordId,
      });
      await refresh();
    } catch (updateError) {
      console.error('Failed to update workflow record', { routePath, updateError });
      setError(updateError instanceof Error ? updateError.message : 'Failed to update record.');
    } finally {
      setMutatingId(null);
    }
  };

  const triggerDelete = async (recordId: string, collectionName: string) => {
    setMutatingId(recordId);
    try {
      await deleteWorkflowRecord({
        routePath,
        id: recordId,
        collectionName,
      });
      trackInteraction('help_accessed', {
        cta: 'workflow_delete',
        routePath,
        recordId,
      });
      await refresh();
    } catch (deleteError) {
      console.error('Failed to delete workflow record', { routePath, deleteError });
      setError(deleteError instanceof Error ? deleteError.message : 'Failed to delete record.');
    } finally {
      setMutatingId(null);
    }
  };

  return (
    <RoleRouteGuard allowedRoles={route.allowedRoles}>
      <section className="space-y-6" data-testid="workflow-route-page">
        <header className="rounded-xl border border-app bg-app-surface-raised p-6" data-testid="workflow-route-header">
          <h1 className="text-2xl font-bold text-app-foreground">{route.title}</h1>
          <p className="mt-2 text-sm text-app-muted">{route.description}</p>
          <div className="mt-4 flex flex-wrap gap-2">
            {navigationTargets.map((target) => (
              <Link
                key={target}
                href={`/${locale}${target}`}
                onClick={() =>
                  trackInteraction('feature_discovered', {
                    cta: 'workflow_nav_link',
                    from: routePath,
                    to: target,
                  })
                }
                className={`rounded-md px-3 py-1.5 text-xs font-medium ${
                  target === routePath
                    ? 'bg-primary text-primary-foreground'
                    : 'bg-app-canvas text-app-muted hover:text-app-foreground'
                }`}
              >
                {target}
              </Link>
            ))}
          </div>
        </header>

        <div className="flex flex-wrap items-center gap-3">
          <button
            type="button"
            data-testid="workflow-refresh"
            onClick={() => {
              trackInteraction('help_accessed', {
                cta: 'workflow_refresh',
                routePath,
              });
              void refresh();
            }}
            className="rounded-md border border-app px-3 py-2 text-sm font-medium text-app-foreground hover:bg-app-canvas"
          >
            Refresh
          </button>
          {data.canCreate && (
            <button
              type="button"
              data-testid="workflow-create-toggle"
              onClick={() => setCreateOpen((prev) => !prev)}
              className="rounded-md bg-primary px-3 py-2 text-sm font-semibold text-primary-foreground hover:bg-primary/90"
            >
              {data.createLabel}
            </button>
          )}
        </div>

        {createOpen && data.canCreate && (
          <div className="rounded-xl border border-app bg-app-surface p-4" data-testid="workflow-create-form">
            <h2 className="text-base font-semibold text-app-foreground">
              {data.createConfig?.title || 'Workflow action'}
            </h2>
            <div className="mt-3 grid gap-3 md:grid-cols-2">
              {(data.createConfig?.fields || []).map((field) => {
                const rawValue = createInput.values[field.name];
                const stringValue = typeof rawValue === 'string' ? rawValue : '';
                const sharedClassName = 'rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground';

                if (field.type === 'textarea') {
                  return (
                    <label key={field.name} className="space-y-1 md:col-span-2">
                      <span className="text-xs font-medium text-app-muted">{field.label}</span>
                      <textarea
                        data-testid={`workflow-field-${field.name}`}
                        value={stringValue}
                        required={field.required}
                        placeholder={field.placeholder}
                        onChange={(event) =>
                          setCreateInput((prev) => ({
                            values: {
                              ...prev.values,
                              [field.name]: event.target.value,
                            },
                          }))
                        }
                        className={`${sharedClassName} min-h-28`}
                      />
                      {field.helperText ? <span className="text-xs text-app-muted">{field.helperText}</span> : null}
                    </label>
                  );
                }

                if (field.type === 'select') {
                  return (
                    <label key={field.name} className="space-y-1">
                      <span className="text-xs font-medium text-app-muted">{field.label}</span>
                      <select
                        data-testid={`workflow-field-${field.name}`}
                        value={stringValue}
                        required={field.required}
                        onChange={(event) =>
                          setCreateInput((prev) => ({
                            values: {
                              ...prev.values,
                              [field.name]: event.target.value,
                            },
                          }))
                        }
                        className={sharedClassName}
                      >
                        <option value="">{field.placeholder || `Select ${field.label}`}</option>
                        {(field.options || []).map((option) => (
                          <option key={option.value} value={option.value}>
                            {option.label}
                          </option>
                        ))}
                      </select>
                      {field.helperText ? <span className="text-xs text-app-muted">{field.helperText}</span> : null}
                    </label>
                  );
                }

                if (field.type === 'checkbox') {
                  const checked = typeof rawValue === 'boolean' ? rawValue : false;
                  return (
                    <label key={field.name} className="flex items-center gap-3 rounded-md border border-app bg-app-canvas px-3 py-2">
                      <input
                        data-testid={`workflow-field-${field.name}`}
                        type="checkbox"
                        checked={checked}
                        onChange={(event) =>
                          setCreateInput((prev) => ({
                            values: {
                              ...prev.values,
                              [field.name]: event.target.checked,
                            },
                          }))
                        }
                      />
                      <span className="text-sm text-app-foreground">{field.label}</span>
                    </label>
                  );
                }

                return (
                  <label key={field.name} className="space-y-1">
                    <span className="text-xs font-medium text-app-muted">{field.label}</span>
                    <input
                      data-testid={`workflow-field-${field.name}`}
                      type={field.type}
                      value={stringValue}
                      required={field.required}
                      placeholder={field.placeholder}
                      onChange={(event) =>
                        setCreateInput((prev) => ({
                          values: {
                            ...prev.values,
                            [field.name]: event.target.value,
                          },
                        }))
                      }
                      className={sharedClassName}
                    />
                    {field.helperText ? <span className="text-xs text-app-muted">{field.helperText}</span> : null}
                  </label>
                );
              })}
            </div>
            <div className="mt-3 flex gap-2">
              <button
                type="button"
                data-testid="workflow-create-submit"
                disabled={mutatingId === 'create'}
                onClick={() => {
                  void submitCreate();
                }}
                className="rounded-md bg-primary px-3 py-2 text-sm font-semibold text-primary-foreground disabled:opacity-50"
              >
                {mutatingId === 'create' ? 'Saving...' : data.createConfig?.submitLabel || 'Submit'}
              </button>
              <button
                type="button"
                data-testid="workflow-create-cancel"
                onClick={() => {
                  setCreateOpen(false);
                  setCreateInput({
                    values: buildInitialFormValues(data.createConfig?.fields),
                  });
                }}
                className="rounded-md border border-app px-3 py-2 text-sm text-app-foreground"
              >
                Cancel
              </button>
            </div>
          </div>
        )}

        {loading || authLoading ? (
          <div className="flex min-h-[240px] items-center justify-center rounded-xl border border-app bg-app-surface">
            <div className="flex items-center gap-2 text-app-muted">
              <Spinner />
              <span>Loading workflow data...</span>
            </div>
          </div>
        ) : error ? (
          <div className="rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700" data-testid="workflow-error">{error}</div>
        ) : data.records.length === 0 ? (
          <div className="rounded-xl border border-app bg-app-surface p-8 text-center text-app-muted" data-testid="workflow-empty">
            No records found yet for this workflow.
          </div>
        ) : (
          <ul className="grid gap-3" data-testid="workflow-record-list">
            {data.records.map((record) => (
              <li
                key={record.id}
                data-testid={`workflow-record-${record.id}`}
                className="rounded-xl border border-app bg-app-surface-raised p-4"
              >
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div className="space-y-1">
                    <h3 className="text-base font-semibold text-app-foreground">{record.title}</h3>
                    <p className="text-sm text-app-muted">{record.subtitle}</p>
                    <div className="flex flex-wrap gap-3 text-xs text-app-muted">
                      <span>Status: {record.status}</span>
                      <span>Updated: {new Date(record.updatedAt).toLocaleString()}</span>
                      {record.siteId ? <span>Site: {record.siteId}</span> : null}
                    </div>
                    {Object.keys(record.metadata).length > 0 ? (
                      <dl className="mt-2 grid gap-1 text-xs text-app-muted sm:grid-cols-2">
                        {Object.entries(record.metadata).map(([key, value]) => (
                          <div key={key} className="flex gap-1">
                            <dt className="font-medium text-app-foreground">{formatMetadataLabel(key)}:</dt>
                            <dd>{value}</dd>
                          </div>
                        ))}
                      </dl>
                    ) : null}
                  </div>
                  <div className="flex flex-wrap gap-2">
                    {record.canEdit && (
                      <button
                        type="button"
                        data-testid={`workflow-record-${record.id}-primary`}
                        disabled={mutatingId === record.id}
                        onClick={() => {
                          void triggerUpdate(record.id, record.collectionName);
                        }}
                        className="rounded-md border border-app px-3 py-1.5 text-xs font-medium text-app-foreground disabled:opacity-50"
                      >
                        {mutatingId === record.id ? 'Updating...' : record.primaryActionLabel || 'Update'}
                      </button>
                    )}
                    {record.canDelete && (
                      <button
                        type="button"
                        data-testid={`workflow-record-${record.id}-delete`}
                        disabled={mutatingId === record.id}
                        onClick={() => {
                          void triggerDelete(record.id, record.collectionName);
                        }}
                        className="rounded-md border border-red-200 px-3 py-1.5 text-xs font-medium text-red-700 disabled:opacity-50"
                      >
                        {mutatingId === record.id ? 'Removing...' : record.deleteActionLabel || 'Delete'}
                      </button>
                    )}
                  </div>
                </div>
              </li>
            ))}
          </ul>
        )}
      </section>
    </RoleRouteGuard>
  );
}
