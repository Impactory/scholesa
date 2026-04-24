'use client';

import React, { useCallback, useEffect, useMemo, useState } from 'react';
import {
  addDoc,
  collection,
  doc,
  getDocs,
  limit,
  query,
  serverTimestamp,
  writeBatch,
  where,
} from 'firebase/firestore';
import {
  CheckCircleIcon,
  Clock3Icon,
  FlameIcon,
  PlusIcon,
  RefreshCwIcon,
} from 'lucide-react';
import { firestore } from '@/src/firebase/client-init';
import { resolveActiveSiteId } from '@/src/lib/auth/activeSite';
import { Spinner } from '@/src/components/ui/Spinner';
import type { CustomRouteRendererProps } from '../customRouteRenderers';

type HabitCategory =
  | 'learning'
  | 'health'
  | 'mindfulness'
  | 'social'
  | 'creativity'
  | 'productivity'
  | string;

type HabitFrequency = 'daily' | 'weekdays' | 'weekends' | 'weekly' | 'custom' | string;
type HabitTimePreference = 'morning' | 'afternoon' | 'evening' | 'anytime' | string;

interface HabitRecord {
  id: string;
  learnerId: string;
  siteId?: string;
  title: string;
  description?: string;
  emoji: string;
  category: HabitCategory;
  frequency: HabitFrequency;
  preferredTime: HabitTimePreference;
  targetMinutes: number;
  currentStreak: number;
  longestStreak: number;
  totalCompletions: number;
  createdAt: Date | null;
  lastCompletedAt: Date | null;
  isActive: boolean;
}

interface HabitLogRecord {
  id: string;
  habitId: string;
  learnerId: string;
  siteId?: string;
  completedAt: Date | null;
  durationMinutes: number;
}

const CATEGORY_OPTIONS: Array<{ value: HabitCategory; label: string }> = [
  { value: 'learning', label: 'Learning' },
  { value: 'health', label: 'Health' },
  { value: 'mindfulness', label: 'Mindfulness' },
  { value: 'social', label: 'Social' },
  { value: 'creativity', label: 'Creativity' },
  { value: 'productivity', label: 'Productivity' },
];

const FREQUENCY_OPTIONS: Array<{ value: HabitFrequency; label: string }> = [
  { value: 'daily', label: 'Every day' },
  { value: 'weekdays', label: 'Weekdays' },
  { value: 'weekends', label: 'Weekends' },
  { value: 'weekly', label: 'Weekly' },
  { value: 'custom', label: 'Custom' },
];

const TIME_OPTIONS: Array<{ value: HabitTimePreference; label: string }> = [
  { value: 'morning', label: 'Morning' },
  { value: 'afternoon', label: 'Afternoon' },
  { value: 'evening', label: 'Evening' },
  { value: 'anytime', label: 'Anytime' },
];

function toDate(value: unknown): Date | null {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value === 'object' && 'toDate' in (value as Record<string, unknown>)) {
    return ((value as { toDate: () => Date }).toDate());
  }
  if (typeof value === 'string' || typeof value === 'number') {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
}

function normalizePositiveInt(value: unknown, fallback: number): number {
  const parsed = typeof value === 'number' ? value : Number.parseInt(String(value), 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function isSameDay(left: Date | null, right: Date): boolean {
  if (!left) return false;
  return (
    left.getFullYear() === right.getFullYear() &&
    left.getMonth() === right.getMonth() &&
    left.getDate() === right.getDate()
  );
}

function matchesSite(siteId: string, recordSiteId: unknown): boolean {
  return typeof recordSiteId !== 'string' || recordSiteId.trim().length === 0 || recordSiteId === siteId;
}

function isHabitActive(data: Record<string, unknown>): boolean {
  if (typeof data.isActive === 'boolean') return data.isActive;
  if (typeof data.status === 'string') {
    return data.status !== 'inactive' && data.status !== 'archived';
  }
  return true;
}

function computeNextStreak(lastCompletedAt: Date | null, currentStreak: number, referenceDate: Date): number {
  if (!lastCompletedAt) return 1;

  const today = new Date(referenceDate.getFullYear(), referenceDate.getMonth(), referenceDate.getDate());
  const lastDay = new Date(
    lastCompletedAt.getFullYear(),
    lastCompletedAt.getMonth(),
    lastCompletedAt.getDate()
  );
  const diffDays = Math.round((today.getTime() - lastDay.getTime()) / 86400000);

  if (diffDays <= 0) return Math.max(currentStreak, 1);
  if (diffDays === 1) return Math.max(currentStreak + 1, 1);
  return 1;
}

function formatDate(value: Date | null): string {
  return value ? value.toLocaleDateString() : 'Not completed yet';
}

export default function LearnerHabitsRenderer({ ctx }: CustomRouteRendererProps) {
  const learnerId = ctx.uid;
  const siteId = resolveActiveSiteId(ctx.profile);

  const [habits, setHabits] = useState<HabitRecord[]>([]);
  const [logs, setLogs] = useState<HabitLogRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [creating, setCreating] = useState(false);
  const [completingHabitId, setCompletingHabitId] = useState<string | null>(null);

  const [newTitle, setNewTitle] = useState('');
  const [newDescription, setNewDescription] = useState('');
  const [newEmoji, setNewEmoji] = useState('*');
  const [newCategory, setNewCategory] = useState<HabitCategory>('learning');
  const [newFrequency, setNewFrequency] = useState<HabitFrequency>('daily');
  const [newPreferredTime, setNewPreferredTime] = useState<HabitTimePreference>('anytime');
  const [newTargetMinutes, setNewTargetMinutes] = useState('10');

  const loadHabits = useCallback(async () => {
    if (!learnerId || !siteId) {
      setHabits([]);
      setLogs([]);
      setLoading(false);
      setError(null);
      return;
    }

    setLoading(true);
    setError(null);
    try {
      const [habitSnap, logSnap] = await Promise.all([
        getDocs(query(collection(firestore, 'habits'), where('learnerId', '==', learnerId), limit(60))),
        getDocs(query(collection(firestore, 'habitLogs'), where('learnerId', '==', learnerId), limit(200))),
      ]);

      const nextHabits = habitSnap.docs
        .map((habitDoc) => {
          const data = habitDoc.data();
          return {
            id: habitDoc.id,
            learnerId,
            siteId: typeof data.siteId === 'string' ? data.siteId : undefined,
            title: typeof data.title === 'string' && data.title.trim().length > 0 ? data.title.trim() : 'Habit',
            description: typeof data.description === 'string' ? data.description.trim() : undefined,
            emoji: typeof data.emoji === 'string' && data.emoji.trim().length > 0 ? data.emoji : '*',
            category: typeof data.category === 'string' ? data.category : 'learning',
            frequency: typeof data.frequency === 'string' ? data.frequency : 'daily',
            preferredTime: typeof data.preferredTime === 'string' ? data.preferredTime : 'anytime',
            targetMinutes: normalizePositiveInt(data.targetMinutes, 10),
            currentStreak: normalizePositiveInt(data.currentStreak, 0),
            longestStreak: normalizePositiveInt(data.longestStreak, 0),
            totalCompletions: normalizePositiveInt(data.totalCompletions, 0),
            createdAt: toDate(data.createdAt),
            lastCompletedAt: toDate(data.lastCompletedAt),
            isActive: isHabitActive(data),
          } satisfies HabitRecord;
        })
        .filter((habit) => habit.isActive && matchesSite(siteId, habit.siteId))
        .sort((left, right) => {
          return (right.createdAt?.getTime() ?? 0) - (left.createdAt?.getTime() ?? 0);
        });

      const nextLogs = logSnap.docs
        .map((logDoc) => {
          const data = logDoc.data();
          return {
            id: logDoc.id,
            habitId: typeof data.habitId === 'string' ? data.habitId : '',
            learnerId,
            siteId: typeof data.siteId === 'string' ? data.siteId : undefined,
            completedAt: toDate(data.completedAt),
            durationMinutes: normalizePositiveInt(data.durationMinutes, 0),
          } satisfies HabitLogRecord;
        })
        .filter((log) => log.habitId.length > 0 && matchesSite(siteId, log.siteId))
        .sort((left, right) => {
          return (right.completedAt?.getTime() ?? 0) - (left.completedAt?.getTime() ?? 0);
        });

      setHabits(nextHabits);
      setLogs(nextLogs);
    } catch (loadErr) {
      console.error('Failed to load habits:', loadErr);
      setError('Failed to load habits. Please try again.');
    } finally {
      setLoading(false);
    }
  }, [learnerId, siteId]);

  useEffect(() => {
    void loadHabits();
  }, [loadHabits]);

  const completedTodayCount = useMemo(() => {
    const today = new Date();
    return habits.filter((habit) => isSameDay(habit.lastCompletedAt, today)).length;
  }, [habits]);

  const weeklyCompletions = useMemo(() => {
    const weekAgo = Date.now() - 7 * 86400000;
    return logs.filter((log) => (log.completedAt?.getTime() ?? 0) >= weekAgo).length;
  }, [logs]);

  const longestActiveStreak = useMemo(() => {
    return habits.reduce((longest, habit) => Math.max(longest, habit.currentStreak), 0);
  }, [habits]);

  const recentLogs = useMemo(() => logs.slice(0, 5), [logs]);

  const resetCreateForm = () => {
    setNewTitle('');
    setNewDescription('');
    setNewEmoji('*');
    setNewCategory('learning');
    setNewFrequency('daily');
    setNewPreferredTime('anytime');
    setNewTargetMinutes('10');
  };

  const handleCreateHabit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!learnerId || !siteId) return;

    setCreating(true);
    setError(null);
    setStatusMessage(null);
    try {
      await addDoc(collection(firestore, 'habits'), {
        learnerId,
        siteId,
        title: newTitle.trim(),
        description: newDescription.trim(),
        emoji: newEmoji.trim() || '*',
        category: newCategory,
        frequency: newFrequency,
        preferredTime: newPreferredTime,
        targetMinutes: normalizePositiveInt(newTargetMinutes, 10),
        currentStreak: 0,
        longestStreak: 0,
        totalCompletions: 0,
        isActive: true,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
        buildingPhaseStartDate: serverTimestamp(),
      });

      resetCreateForm();
      setShowCreateForm(false);
      setStatusMessage('Habit created.');
      await loadHabits();
    } catch (createErr) {
      console.error('Failed to create habit:', createErr);
      setError('Failed to create habit. Please try again.');
    } finally {
      setCreating(false);
    }
  };

  const handleCompleteHabit = async (habit: HabitRecord) => {
    if (!learnerId || !siteId) return;
    const now = new Date();
    if (isSameDay(habit.lastCompletedAt, now)) return;

    setCompletingHabitId(habit.id);
    setError(null);
    setStatusMessage(null);
    try {
      const nextStreak = computeNextStreak(habit.lastCompletedAt, habit.currentStreak, now);
      const nextLongestStreak = Math.max(habit.longestStreak, nextStreak);
      const logRef = doc(collection(firestore, 'habitLogs'));
      const batch = writeBatch(firestore);

      batch.set(logRef, {
        learnerId,
        siteId,
        habitId: habit.id,
        durationMinutes: habit.targetMinutes,
        completedAt: serverTimestamp(),
        createdAt: serverTimestamp(),
      });
      batch.update(doc(firestore, 'habits', habit.id), {
        siteId,
        currentStreak: nextStreak,
        longestStreak: nextLongestStreak,
        totalCompletions: habit.totalCompletions + 1,
        lastCompletedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });

      await batch.commit();
      setStatusMessage(`${habit.title} completed.`);
      await loadHabits();
    } catch (completeErr) {
      console.error('Failed to complete habit:', completeErr);
      setError('Failed to record habit completion. Please try again.');
    } finally {
      setCompletingHabitId(null);
    }
  };

  if (!siteId) {
    return (
      <div
        className="rounded-lg border border-amber-200 bg-amber-50 p-4 text-sm text-amber-800"
        data-testid="learner-habits-site-required"
      >
        Select an active site before tracking learning habits.
      </div>
    );
  }

  if (loading) {
    return (
      <div className="flex min-h-[240px] items-center justify-center">
        <div className="flex items-center gap-2 text-app-muted">
          <Spinner />
          <span>Loading habits...</span>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6" data-testid="learner-habits-renderer">
      <header className="rounded-xl border border-app bg-app-surface-raised p-4">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h1 className="text-2xl font-bold text-app-foreground">Learning Habits</h1>
            <p className="mt-1 text-sm text-app-muted">
              Build routines that support your evidence journey. Habits help your learning rhythm, but they do not count as capability mastery on their own.
            </p>
          </div>
          <div className="flex gap-2">
            <button
              type="button"
              onClick={() => void loadHabits()}
              className="inline-flex items-center gap-2 rounded-md border border-app px-3 py-2 text-sm font-medium text-app-foreground hover:bg-app-surface"
            >
              <RefreshCwIcon className="h-4 w-4" />
              Refresh
            </button>
            <button
              type="button"
              onClick={() => setShowCreateForm((current) => !current)}
              className="inline-flex items-center gap-2 rounded-md bg-app-primary px-3 py-2 text-sm font-medium text-white hover:opacity-90"
            >
              <PlusIcon className="h-4 w-4" />
              {showCreateForm ? 'Close form' : 'New habit'}
            </button>
          </div>
        </div>
      </header>

      {error && (
        <div className="rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-800">
          {error}
        </div>
      )}

      {statusMessage && (
        <div className="rounded-lg border border-emerald-200 bg-emerald-50 p-4 text-sm text-emerald-800">
          {statusMessage}
        </div>
      )}

      <section className="grid gap-3 sm:grid-cols-3">
        <div className="rounded-lg border border-app bg-app-surface-raised p-4">
          <div className="text-sm text-app-muted">Active habits</div>
          <div className="mt-2 text-2xl font-semibold text-app-foreground">{habits.length}</div>
        </div>
        <div className="rounded-lg border border-app bg-app-surface-raised p-4">
          <div className="text-sm text-app-muted">Completed today</div>
          <div className="mt-2 text-2xl font-semibold text-app-foreground">{completedTodayCount}</div>
        </div>
        <div className="rounded-lg border border-app bg-app-surface-raised p-4">
          <div className="text-sm text-app-muted">Longest active streak</div>
          <div className="mt-2 text-2xl font-semibold text-app-foreground">{longestActiveStreak}</div>
        </div>
      </section>

      {showCreateForm && (
        <form onSubmit={handleCreateHabit} className="rounded-xl border border-app bg-app-surface-raised p-4 space-y-4">
          <div>
            <h2 className="text-lg font-semibold text-app-foreground">Create habit</h2>
            <p className="mt-1 text-sm text-app-muted">Start a routine you can actually sustain in studio time or at home.</p>
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <label className="space-y-1 text-sm">
              <span className="font-medium text-app-foreground">Habit name</span>
              <input
                value={newTitle}
                onChange={(event) => setNewTitle(event.target.value)}
                className="w-full rounded-md border border-app bg-app-surface px-3 py-2 text-app-foreground"
                placeholder="Read for 10 minutes"
                required
              />
            </label>
            <label className="space-y-1 text-sm">
              <span className="font-medium text-app-foreground">Icon or marker</span>
              <input
                value={newEmoji}
                onChange={(event) => setNewEmoji(event.target.value)}
                className="w-full rounded-md border border-app bg-app-surface px-3 py-2 text-app-foreground"
                placeholder="*"
                maxLength={4}
              />
            </label>
            <label className="space-y-1 text-sm sm:col-span-2">
              <span className="font-medium text-app-foreground">Why this habit matters</span>
              <textarea
                value={newDescription}
                onChange={(event) => setNewDescription(event.target.value)}
                className="min-h-[88px] w-full rounded-md border border-app bg-app-surface px-3 py-2 text-app-foreground"
                placeholder="What routine are you building and why does it support your learning?"
              />
            </label>
            <label className="space-y-1 text-sm">
              <span className="font-medium text-app-foreground">Category</span>
              <select
                value={newCategory}
                onChange={(event) => setNewCategory(event.target.value)}
                className="w-full rounded-md border border-app bg-app-surface px-3 py-2 text-app-foreground"
              >
                {CATEGORY_OPTIONS.map((option) => (
                  <option key={option.value} value={option.value}>
                    {option.label}
                  </option>
                ))}
              </select>
            </label>
            <label className="space-y-1 text-sm">
              <span className="font-medium text-app-foreground">Target minutes</span>
              <input
                type="number"
                min={1}
                value={newTargetMinutes}
                onChange={(event) => setNewTargetMinutes(event.target.value)}
                className="w-full rounded-md border border-app bg-app-surface px-3 py-2 text-app-foreground"
              />
            </label>
            <label className="space-y-1 text-sm">
              <span className="font-medium text-app-foreground">Frequency</span>
              <select
                value={newFrequency}
                onChange={(event) => setNewFrequency(event.target.value)}
                className="w-full rounded-md border border-app bg-app-surface px-3 py-2 text-app-foreground"
              >
                {FREQUENCY_OPTIONS.map((option) => (
                  <option key={option.value} value={option.value}>
                    {option.label}
                  </option>
                ))}
              </select>
            </label>
            <label className="space-y-1 text-sm">
              <span className="font-medium text-app-foreground">Preferred time</span>
              <select
                value={newPreferredTime}
                onChange={(event) => setNewPreferredTime(event.target.value)}
                className="w-full rounded-md border border-app bg-app-surface px-3 py-2 text-app-foreground"
              >
                {TIME_OPTIONS.map((option) => (
                  <option key={option.value} value={option.value}>
                    {option.label}
                  </option>
                ))}
              </select>
            </label>
          </div>

          <div className="flex justify-end gap-2">
            <button
              type="button"
              onClick={() => {
                resetCreateForm();
                setShowCreateForm(false);
              }}
              className="rounded-md border border-app px-3 py-2 text-sm font-medium text-app-foreground hover:bg-app-surface"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={creating || newTitle.trim().length === 0}
              className="rounded-md bg-app-primary px-3 py-2 text-sm font-medium text-white disabled:cursor-not-allowed disabled:opacity-60"
            >
              {creating ? 'Creating...' : 'Create habit'}
            </button>
          </div>
        </form>
      )}

      <section className="grid gap-6 lg:grid-cols-[minmax(0,2fr)_minmax(0,1fr)]">
        <div className="space-y-4">
          {habits.length === 0 ? (
            <div className="rounded-lg border border-dashed border-app bg-app-surface p-8 text-center text-sm text-app-muted">
              <p>No habits yet.</p>
              <p className="mt-1">Create a learner habit to build a steady routine around reflection, practice, or wellbeing.</p>
            </div>
          ) : (
            habits.map((habit) => {
              const completedToday = isSameDay(habit.lastCompletedAt, new Date());
              return (
                <article
                  key={habit.id}
                  className="rounded-xl border border-app bg-app-surface-raised p-4 space-y-3"
                  data-testid={`habit-card-${habit.id}`}
                >
                  <div className="flex flex-wrap items-start justify-between gap-3">
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="text-lg font-semibold text-app-foreground">{habit.emoji}</span>
                        <h2 className="text-lg font-semibold text-app-foreground">{habit.title}</h2>
                      </div>
                      {habit.description && (
                        <p className="mt-1 text-sm text-app-muted">{habit.description}</p>
                      )}
                    </div>
                    <span className="rounded-full bg-slate-100 px-2 py-1 text-xs font-medium text-slate-700">
                      {CATEGORY_OPTIONS.find((option) => option.value === habit.category)?.label ?? habit.category}
                    </span>
                  </div>

                  <div className="flex flex-wrap gap-2 text-xs text-app-muted">
                    <span className="inline-flex items-center gap-1 rounded-full bg-app-surface px-2 py-1">
                      <Clock3Icon className="h-3.5 w-3.5" />
                      {habit.targetMinutes} min
                    </span>
                    <span className="rounded-full bg-app-surface px-2 py-1">
                      {FREQUENCY_OPTIONS.find((option) => option.value === habit.frequency)?.label ?? habit.frequency}
                    </span>
                    <span className="rounded-full bg-app-surface px-2 py-1">
                      {TIME_OPTIONS.find((option) => option.value === habit.preferredTime)?.label ?? habit.preferredTime}
                    </span>
                  </div>

                  <div className="grid gap-3 sm:grid-cols-3">
                    <div className="rounded-lg bg-app-surface p-3">
                      <div className="text-xs text-app-muted">Current streak</div>
                      <div className="mt-1 flex items-center gap-2 text-lg font-semibold text-app-foreground">
                        <FlameIcon className="h-4 w-4" />
                        {habit.currentStreak}
                      </div>
                    </div>
                    <div className="rounded-lg bg-app-surface p-3">
                      <div className="text-xs text-app-muted">Total completions</div>
                      <div className="mt-1 text-lg font-semibold text-app-foreground">{habit.totalCompletions}</div>
                    </div>
                    <div className="rounded-lg bg-app-surface p-3">
                      <div className="text-xs text-app-muted">Last completed</div>
                      <div className="mt-1 text-sm font-medium text-app-foreground">{formatDate(habit.lastCompletedAt)}</div>
                    </div>
                  </div>

                  <div className="flex flex-wrap items-center justify-between gap-3">
                    <div className="text-xs text-app-muted">
                      Created {formatDate(habit.createdAt)}
                    </div>
                    <button
                      type="button"
                      onClick={() => void handleCompleteHabit(habit)}
                      disabled={completedToday || completingHabitId === habit.id}
                      className="inline-flex items-center gap-2 rounded-md bg-emerald-600 px-3 py-2 text-sm font-medium text-white disabled:cursor-not-allowed disabled:bg-emerald-200 disabled:text-emerald-800"
                      data-testid={`habit-complete-${habit.id}`}
                    >
                      <CheckCircleIcon className="h-4 w-4" />
                      {completedToday
                        ? 'Completed today'
                        : completingHabitId === habit.id
                          ? 'Saving...'
                          : 'Complete habit'}
                    </button>
                  </div>
                </article>
              );
            })
          )}
        </div>

        <aside className="space-y-4">
          <section className="rounded-xl border border-app bg-app-surface-raised p-4">
            <h2 className="text-lg font-semibold text-app-foreground">This week</h2>
            <p className="mt-1 text-sm text-app-muted">Weekly completions drawn from your persisted habit logs.</p>
            <div className="mt-4 text-3xl font-semibold text-app-foreground">{weeklyCompletions}</div>
          </section>

          <section className="rounded-xl border border-app bg-app-surface-raised p-4">
            <h2 className="text-lg font-semibold text-app-foreground">Recent completions</h2>
            {recentLogs.length === 0 ? (
              <p className="mt-2 text-sm text-app-muted">No habit logs yet. Complete a habit to start your activity record.</p>
            ) : (
              <ul className="mt-3 space-y-2 text-sm text-app-muted">
                {recentLogs.map((log) => {
                  const habitTitle = habits.find((habit) => habit.id === log.habitId)?.title ?? 'Habit';
                  return (
                    <li key={log.id} className="rounded-lg bg-app-surface p-3">
                      <div className="font-medium text-app-foreground">{habitTitle}</div>
                      <div className="mt-1 text-xs">
                        {formatDate(log.completedAt)}
                        {log.durationMinutes > 0 ? ` · ${log.durationMinutes} min` : ''}
                      </div>
                    </li>
                  );
                })}
              </ul>
            )}
          </section>
        </aside>
      </section>
    </div>
  );
}