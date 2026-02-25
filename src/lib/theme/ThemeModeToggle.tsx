'use client';

import { useMemo } from 'react';
import { useI18n } from '@/src/lib/i18n/useI18n';
import { useThemeContext } from './ThemeProvider';

type ThemePreference = 'system' | 'light' | 'dark';

interface ThemeModeToggleProps {
  compact?: boolean;
  onPreferenceChange?: (nextPreference: ThemePreference) => void;
}

export function ThemeModeToggle({
  compact = false,
  onPreferenceChange,
}: ThemeModeToggleProps) {
  const { t } = useI18n();
  const { preference, setPreference } = useThemeContext();

  const options = useMemo(
    () =>
      [
        { value: 'system', label: t('navigation.themeSystem') },
        { value: 'light', label: t('navigation.themeLight') },
        { value: 'dark', label: t('navigation.themeDark') },
      ] as const,
    [t],
  );

  return (
    <div
      className={`inline-flex items-center rounded-lg border border-app bg-app-surface-raised p-1 ${
        compact ? 'gap-0.5 text-xs' : 'gap-1 text-sm'
      }`}
      role="group"
      aria-label={t('navigation.themeLabel')}
    >
      {options.map((option) => {
        const isActive = preference === option.value;
        return (
          <button
            key={option.value}
            type="button"
            aria-label={`${t('navigation.themeLabel')}: ${option.label}`}
            aria-pressed={isActive}
            onClick={() => {
              setPreference(option.value);
              onPreferenceChange?.(option.value);
            }}
            className={`rounded-md px-2.5 py-1.5 font-medium transition-colors ${
              isActive
                ? 'bg-primary text-primary-foreground'
                : 'text-app-muted hover:bg-app-surface-muted hover:text-app-foreground'
            }`}
          >
            {option.label}
          </button>
        );
      })}
    </div>
  );
}
