'use client';

import { useI18n } from '@/src/lib/i18n/useI18n';

export type VoiceProfileId = 'warm' | 'playful' | 'peer' | 'direct' | 'professional';

interface VoiceProfilePickerProps {
  value: VoiceProfileId;
  onChange: (profile: VoiceProfileId) => void;
  className?: string;
}

const PROFILES: VoiceProfileId[] = ['warm', 'playful', 'peer', 'direct', 'professional'];

const PROFILE_KEY_MAP: Record<VoiceProfileId, string> = {
  warm: 'aiCoach.voiceSettings.profileWarm',
  playful: 'aiCoach.voiceSettings.profilePlayful',
  peer: 'aiCoach.voiceSettings.profilePeer',
  direct: 'aiCoach.voiceSettings.profileDirect',
  professional: 'aiCoach.voiceSettings.profileProfessional',
};

export function VoiceProfilePicker({ value, onChange, className }: VoiceProfilePickerProps) {
  const { t } = useI18n();

  return (
    <div className={className}>
      <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
        {t('aiCoach.voiceSettings.voiceProfile')}
      </label>
      <div className="flex flex-wrap gap-2">
        {PROFILES.map((profile) => (
          <button
            key={profile}
            type="button"
            onClick={() => onChange(profile)}
            className={`rounded-full px-3 py-1 text-sm transition-colors ${
              value === profile
                ? 'bg-indigo-600 text-white'
                : 'bg-gray-100 text-gray-700 hover:bg-gray-200 dark:bg-gray-800 dark:text-gray-300 dark:hover:bg-gray-700'
            }`}
          >
            {t(PROFILE_KEY_MAP[profile])}
          </button>
        ))}
      </div>
    </div>
  );
}
