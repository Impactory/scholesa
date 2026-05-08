'use client';

import { useMemo } from 'react';
import { MonitorIcon, MoonIcon, SunIcon } from 'lucide-react';
import { useI18n } from '@/src/lib/i18n/useI18n';
import { useThemeContext } from './ThemeProvider';
import { useInteractionTracking } from '@/src/hooks/useTelemetry';

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
  const trackInteraction = useInteractionTracking();

  const options = useMemo(
    () =>
      [
        { value: 'system', label: t('navigation.themeSystem'), icon: MonitorIcon },
        { value: 'light', label: t('navigation.themeLight'), icon: SunIcon },
        { value: 'dark', label: t('navigation.themeDark'), icon: MoonIcon },
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
        const Icon = option.icon;
        const pressedProps = isActive
          ? ({ 'aria-pressed': true } as const)
          : ({ 'aria-pressed': false } as const);
        return (
          <button
            key={option.value}
            type="button"
            {...pressedProps}
            aria-label={`${t('navigation.themeLabel')}: ${option.label}`}
            title={option.label}
            onClick={() => {
              trackInteraction('feature_discovered', {
                cta: 'theme_mode_toggle',
                theme: option.value,
                compact,
              });
              setPreference(option.value);
              onPreferenceChange?.(option.value);
            }}
            className={`min-touch-target inline-flex items-center justify-center rounded-md ${
              compact ? 'h-9 w-9' : 'h-10 w-10'
            } transition-colors ${
              isActive
                ? 'bg-app-primary text-app-primary-foreground'
                : 'text-app-foreground hover:bg-app-surface-muted'
            }`}
          >
            <Icon aria-hidden="true" className={compact ? 'h-4 w-4' : 'h-5 w-5'} />
          </button>
        );
      })}
    </div>
  );
}
