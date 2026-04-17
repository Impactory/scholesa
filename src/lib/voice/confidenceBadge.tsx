'use client';

import { useI18n } from '@/src/lib/i18n/useI18n';

interface ConfidenceBadgeProps {
  confidence: number;
  className?: string;
}

export function ConfidenceBadge({ confidence, className }: ConfidenceBadgeProps) {
  const { t } = useI18n();

  const level = confidence >= 0.8 ? 'high' : confidence >= 0.5 ? 'medium' : 'low';
  const colorClass =
    level === 'high'
      ? 'bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-300'
      : level === 'medium'
        ? 'bg-amber-100 text-amber-800 dark:bg-amber-900/30 dark:text-amber-300'
        : 'bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-300';

  return (
    <span
      className={`inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs font-medium ${colorClass} ${className ?? ''}`}
      title={t('aiCoach.sttConfidence.tooltip')}
      aria-label={`${t('aiCoach.sttConfidence.label')}: ${Math.round(confidence * 100)}%`}
    >
      <span className="sr-only">{t('aiCoach.sttConfidence.label')}:</span>
      {Math.round(confidence * 100)}%
    </span>
  );
}
