'use client';

/**
 * Goal Setting Form Component
 * 
 * Allows learners to set personal learning goals aligned with SDT autonomy pillar.
 * Tracks goal setting events via telemetry.
 */

import React, { useState } from 'react';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { AutonomyEngine } from '@/src/lib/motivation/motivationEngine';
import { useAutonomyTracking } from '@/src/hooks/useTelemetry';
import { TargetIcon, XIcon, CalendarIcon } from 'lucide-react';
import { useI18n } from '@/src/lib/i18n/useI18n';

interface GoalSettingFormProps {
  onClose?: () => void;
  onGoalSet?: (goalId: string) => void;
}

export function GoalSettingForm({ onClose, onGoalSet }: GoalSettingFormProps) {
  const { profile } = useAuthContext();
  const { t } = useI18n();
  const trackAutonomy = useAutonomyTracking();
  
  const [description, setDescription] = useState('');
  const [targetDate, setTargetDate] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  
  const learnerId = profile?.uid || '';
  const siteId = profile?.activeSiteId || profile?.siteIds?.[0] || '';
  
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!description.trim()) {
      setError(t('goalForm.error.descriptionRequired'));
      return;
    }
    
    if (!targetDate) {
      setError(t('goalForm.error.dateRequired'));
      return;
    }
    
    setLoading(true);
    setError('');
    
    try {
      // Set goal via AutonomyEngine
      const goalId = await AutonomyEngine.setGoal({
        learnerId,
        siteId,
        goalType: 'skill_mastery', // Valid goal type
        description: description.trim(),
        targetDate: targetDate ? new Date(targetDate) : undefined,
        progress: 0,
        status: 'active'
      });
      
      // Track goal setting event
      trackAutonomy('goal_set', {
        goalId,
        description: description.trim(),
        targetDate,
        daysUntilTarget: Math.ceil((new Date(targetDate).getTime() - Date.now()) / (1000 * 60 * 60 * 24))
      });
      
      // Reset form
      setDescription('');
      setTargetDate('');
      
      // Notify parent
      if (onGoalSet) onGoalSet(goalId);
      if (onClose) onClose();
      
    } catch (err) {
      console.error('Failed to set goal:', err);
      setError(t('goalForm.error.saveFailed'));
    } finally {
      setLoading(false);
    }
  };
  
  // Calculate minimum date (tomorrow)
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  const minDate = tomorrow.toISOString().split('T')[0];
  
  return (
    <div className="bg-white rounded-lg border border-gray-200 shadow-lg p-6">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <TargetIcon className="h-6 w-6 text-indigo-600" />
          <h2 className="text-xl font-bold text-gray-900">{t('goalForm.title')}</h2>
        </div>
        {onClose && (
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600"
            aria-label={t('common.close')}
          >
            <XIcon className="h-5 w-5" />
          </button>
        )}
      </div>
      
      <p className="text-sm text-gray-600 mb-4">
        {t('goalForm.subtitle')}
      </p>
      
      <form onSubmit={handleSubmit} className="space-y-4">
        {/* Goal Description */}
        <div>
          <label htmlFor="description" className="block text-sm font-medium text-gray-700 mb-1">
            {t('goalForm.goalLabel')}
          </label>
          <textarea
            id="description"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder={t('goalForm.goalPlaceholder')}
            rows={3}
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
            maxLength={200}
          />
          <p className="text-xs text-gray-500 mt-1">
            {t('goalForm.characters', { count: description.length })}
          </p>
        </div>
        
        {/* Target Date */}
        <div>
          <label htmlFor="targetDate" className="block text-sm font-medium text-gray-700 mb-1">
            {t('goalForm.targetDateLabel')}
          </label>
          <div className="relative">
            <input
              type="date"
              id="targetDate"
              value={targetDate}
              onChange={(e) => setTargetDate(e.target.value)}
              min={minDate}
              className="w-full px-3 py-2 pl-10 border border-gray-300 rounded-md focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
            />
            <CalendarIcon className="absolute left-3 top-1/2 transform -translate-y-1/2 h-5 w-5 text-gray-400 pointer-events-none" />
          </div>
        </div>
        
        {/* Error Message */}
        {error && (
          <div className="rounded-md bg-red-50 border border-red-200 p-3">
            <p className="text-sm text-red-800">{error}</p>
          </div>
        )}
        
        {/* Actions */}
        <div className="flex gap-3 pt-2">
          <button
            type="submit"
            disabled={loading || !description.trim() || !targetDate}
            className="flex-1 px-4 py-2 bg-indigo-600 text-white rounded-md font-medium hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loading ? t('goalForm.setting') : t('goalForm.submit')}
          </button>
          {onClose && (
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 bg-gray-100 text-gray-700 rounded-md font-medium hover:bg-gray-200"
            >
              {t('common.cancel')}
            </button>
          )}
        </div>
      </form>
    </div>
  );
}
