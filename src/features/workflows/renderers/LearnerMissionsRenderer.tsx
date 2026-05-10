'use client';

import { useCallback, useEffect, useState } from 'react';
import { LearnerEvidenceSubmission } from '@/src/components/evidence/LearnerEvidenceSubmission';
import type { CustomRouteRendererProps } from '../customRouteRenderers';
import {
  createWorkflowRecord,
  loadWorkflowRecords,
  updateWorkflowRecord,
  type WorkflowCreateInput,
  type WorkflowLoadResult,
  type WorkflowRecord,
} from '../workflowData';

function buildInitialValues(data: WorkflowLoadResult): WorkflowCreateInput {
  const values = (data.createConfig?.fields || []).reduce<Record<string, string | boolean>>(
    (acc, field) => {
      if (typeof field.defaultValue !== 'undefined') {
        acc[field.name] = field.defaultValue;
        return acc;
      }
      acc[field.name] = field.type === 'checkbox' ? false : '';
      return acc;
    },
    {}
  );
  return { values };
}

function MissionRecord({ record, onSubmit }: {
  record: WorkflowRecord;
  onSubmit: (record: WorkflowRecord) => Promise<void>;
}) {
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSubmit = async () => {
    setIsSubmitting(true);
    try {
      await onSubmit(record);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <li className="rounded-md border border-cyan-100 bg-white p-4 shadow-sm dark:border-slate-700 dark:bg-slate-900">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
        <div>
          <h3 className="text-sm font-semibold text-app-foreground">{record.title}</h3>
          {record.subtitle ? (
            <p className="mt-1 text-sm text-app-muted">{record.subtitle}</p>
          ) : null}
          <p className="mt-2 text-xs font-semibold uppercase text-cyan-700 dark:text-cyan-300">
            Status: {record.status}
          </p>
        </div>
        {record.primaryActionLabel ? (
          <button
            type="button"
            onClick={handleSubmit}
            disabled={isSubmitting}
            className="rounded-md bg-cyan-700 px-3 py-2 text-sm font-semibold text-white hover:bg-cyan-800 disabled:cursor-not-allowed disabled:opacity-60 dark:bg-cyan-300 dark:text-slate-950 dark:hover:bg-cyan-200"
          >
            {isSubmitting ? 'Saving...' : record.primaryActionLabel}
          </button>
        ) : null}
      </div>
    </li>
  );
}

export default function LearnerMissionsRenderer({ ctx }: CustomRouteRendererProps) {
  const [data, setData] = useState<WorkflowLoadResult>({
    records: [],
    canCreate: false,
    canRefresh: true,
    createLabel: 'Start mission attempt',
    guidanceText: null,
    createConfig: null,
  });
  const [formOpen, setFormOpen] = useState(false);
  const [input, setInput] = useState<WorkflowCreateInput>({ values: {} });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);

  const refresh = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const nextData = await loadWorkflowRecords(ctx);
      setData(nextData);
      setInput(buildInitialValues(nextData));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unable to load mission attempts.');
    } finally {
      setLoading(false);
    }
  }, [ctx]);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  const submitCreate = async () => {
    setCreating(true);
    setError(null);
    try {
      await createWorkflowRecord(ctx, input);
      setFormOpen(false);
      await refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unable to start mission attempt.');
    } finally {
      setCreating(false);
    }
  };

  const submitAttempt = async (record: WorkflowRecord) => {
    setError(null);
    await updateWorkflowRecord(ctx, {
      routePath: record.routePath,
      collectionName: record.collectionName,
      id: record.id,
    });
    await refresh();
  };

  return (
    <div className="space-y-6">
      <section className="rounded-md border border-cyan-200 bg-white p-5 shadow-sm dark:border-slate-700 dark:bg-slate-900">
        <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <p className="text-sm font-bold uppercase text-cyan-700 dark:text-cyan-300">
              Mission evidence workflow
            </p>
            <h1 className="mt-2 text-xl font-bold text-app-foreground">Learner Missions</h1>
            <p className="mt-2 text-sm leading-6 text-app-muted">
              Start a mission attempt, submit it for review, then attach artifact,
              reflection, or checkpoint proof below.
            </p>
          </div>
          {data.canCreate ? (
            <button
              type="button"
              data-testid="workflow-create-toggle"
              onClick={() => setFormOpen((open) => !open)}
              className="rounded-md bg-cyan-700 px-3 py-2 text-sm font-semibold text-white hover:bg-cyan-800 dark:bg-cyan-300 dark:text-slate-950 dark:hover:bg-cyan-200"
            >
              {data.createLabel}
            </button>
          ) : null}
        </div>

        {error ? (
          <div className="mt-4 rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-700">
            {error}
          </div>
        ) : null}

        {formOpen && data.createConfig ? (
          <div
            className="mt-4 rounded-md border border-cyan-200 bg-cyan-50 p-4 dark:border-slate-700 dark:bg-slate-950"
            data-testid="workflow-create-form"
          >
            <h2 className="text-base font-semibold text-app-foreground">
              {data.createConfig.title}
            </h2>
            <div className="mt-3 grid gap-3 md:grid-cols-2">
              {data.createConfig.fields.map((field) => {
                const value = input.values[field.name];
                const stringValue = typeof value === 'string' ? value : '';
                const sharedClassName = 'rounded-md border border-cyan-200 bg-white px-3 py-2 text-sm text-slate-950 dark:border-slate-700 dark:bg-slate-900 dark:text-white';

                if (field.type === 'select') {
                  return (
                    <label key={field.name} className="space-y-1">
                      <span className="text-xs font-medium text-app-muted">{field.label}</span>
                      <select
                        data-testid={`workflow-field-${field.name}`}
                        value={stringValue}
                        required={field.required}
                        onChange={(event) =>
                          setInput((prev) => ({
                            values: { ...prev.values, [field.name]: event.target.value },
                          }))
                        }
                        className={sharedClassName}
                      >
                        <option value="">Choose...</option>
                        {(field.options || []).map((option) => (
                          <option key={option.value} value={option.value}>
                            {option.label}
                          </option>
                        ))}
                      </select>
                    </label>
                  );
                }

                return (
                  <label key={field.name} className="space-y-1 md:col-span-2">
                    <span className="text-xs font-medium text-app-muted">{field.label}</span>
                    <textarea
                      data-testid={`workflow-field-${field.name}`}
                      value={stringValue}
                      required={field.required}
                      placeholder={field.placeholder}
                      onChange={(event) =>
                        setInput((prev) => ({
                          values: { ...prev.values, [field.name]: event.target.value },
                        }))
                      }
                      className={`${sharedClassName} min-h-24`}
                    />
                  </label>
                );
              })}
            </div>
            <button
              type="button"
              data-testid="workflow-create-submit"
              onClick={submitCreate}
              disabled={creating}
              className="mt-4 rounded-md bg-cyan-700 px-3 py-2 text-sm font-semibold text-white hover:bg-cyan-800 disabled:cursor-not-allowed disabled:opacity-60 dark:bg-cyan-300 dark:text-slate-950 dark:hover:bg-cyan-200"
            >
              {creating ? 'Saving...' : data.createConfig.submitLabel}
            </button>
          </div>
        ) : null}

        <div className="mt-4">
          {loading ? (
            <p className="text-sm text-app-muted">Loading mission attempts...</p>
          ) : data.records.length > 0 ? (
            <ul className="grid gap-3" data-testid="workflow-record-list">
              {data.records.map((record) => (
                <MissionRecord key={record.id} record={record} onSubmit={submitAttempt} />
              ))}
            </ul>
          ) : (
            <p className="text-sm text-app-muted">
              No mission attempts yet. Start one to connect your work to proof.
            </p>
          )}
        </div>
      </section>

      <LearnerEvidenceSubmission />
    </div>
  );
}
