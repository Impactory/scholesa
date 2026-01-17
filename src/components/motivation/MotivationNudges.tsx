'use client';

import React, { useEffect, useState, useCallback } from 'react';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { motivationEngine, MOTIVATION_EMOJI } from '@/src/lib/motivation/motivationEngine';
import type { MotivationNudge, MotivationType } from '@/src/types/schema';
import { 
  Bell, 
  X, 
  Clock, 
  Check, 
  Sparkles,
  ChevronRight,
  Target,
  Trophy,
  Heart,
  Lightbulb
} from 'lucide-react';

interface MotivationNudgesProps {
  siteId: string;
  maxNudges?: number;
  showInline?: boolean;
  onNudgeAction?: (nudgeId: string, action: 'accepted' | 'dismissed' | 'snoozed') => void;
}

const NUDGE_ICONS: Record<MotivationNudge['type'], React.ReactNode> = {
  reminder: <Bell className="w-5 h-5" />,
  celebration: <Trophy className="w-5 h-5" />,
  challenge: <Target className="w-5 h-5" />,
  encouragement: <Heart className="w-5 h-5" />,
  tip: <Lightbulb className="w-5 h-5" />,
};

const NUDGE_COLORS: Record<MotivationNudge['type'], { bg: string; border: string; accent: string }> = {
  reminder: { bg: 'bg-blue-50', border: 'border-blue-200', accent: 'text-blue-600' },
  celebration: { bg: 'bg-yellow-50', border: 'border-yellow-200', accent: 'text-yellow-600' },
  challenge: { bg: 'bg-purple-50', border: 'border-purple-200', accent: 'text-purple-600' },
  encouragement: { bg: 'bg-pink-50', border: 'border-pink-200', accent: 'text-pink-600' },
  tip: { bg: 'bg-green-50', border: 'border-green-200', accent: 'text-green-600' },
};

export function MotivationNudges({
  siteId,
  maxNudges = 3,
  showInline = true,
  onNudgeAction,
}: MotivationNudgesProps) {
  const { user } = useAuthContext();
  const [nudges, setNudges] = useState<MotivationNudge[]>([]);
  const [loading, setLoading] = useState(true);
  const [dismissedIds, setDismissedIds] = useState<Set<string>>(new Set());

  const fetchNudges = useCallback(async () => {
    if (!user) return;
    
    try {
      const data = await motivationEngine.getNudges(siteId, maxNudges);
      setNudges(data);
    } catch (error) {
      console.error('Error fetching nudges:', error);
    } finally {
      setLoading(false);
    }
  }, [user, siteId, maxNudges]);

  useEffect(() => {
    fetchNudges();
  }, [fetchNudges]);

  const handleResponse = async (
    nudgeId: string, 
    response: 'accepted' | 'dismissed' | 'snoozed',
    snoozeDurationMinutes?: number
  ) => {
    try {
      await motivationEngine.respondToNudge(nudgeId, response, snoozeDurationMinutes);
      
      // Optimistically remove from UI
      setDismissedIds(prev => {
        const newSet = new Set(prev);
        newSet.add(nudgeId);
        return newSet;
      });
      
      onNudgeAction?.(nudgeId, response);
      
      // Refresh nudges after a short delay
      setTimeout(fetchNudges, 1000);
    } catch (error) {
      console.error('Error responding to nudge:', error);
    }
  };

  const visibleNudges = nudges.filter(n => !dismissedIds.has(n.id));

  if (loading) {
    return showInline ? (
      <div className="animate-pulse flex items-center gap-2 p-3 bg-gray-100 rounded-lg">
        <div className="w-8 h-8 bg-gray-200 rounded-full" />
        <div className="flex-1 space-y-2">
          <div className="h-3 bg-gray-200 rounded w-3/4" />
          <div className="h-2 bg-gray-200 rounded w-1/2" />
        </div>
      </div>
    ) : null;
  }

  if (visibleNudges.length === 0) {
    return null;
  }

  if (showInline) {
    return (
      <div className="space-y-3">
        {visibleNudges.map((nudge) => (
          <NudgeCard
            key={nudge.id}
            nudge={nudge}
            onAccept={() => handleResponse(nudge.id, 'accepted')}
            onDismiss={() => handleResponse(nudge.id, 'dismissed')}
            onSnooze={(minutes) => handleResponse(nudge.id, 'snoozed', minutes)}
          />
        ))}
      </div>
    );
  }

  // Pop-up style for single nudge
  const primaryNudge = visibleNudges[0];
  return (
    <NudgeModal
      nudge={primaryNudge}
      onAccept={() => handleResponse(primaryNudge.id, 'accepted')}
      onDismiss={() => handleResponse(primaryNudge.id, 'dismissed')}
      onSnooze={(minutes) => handleResponse(primaryNudge.id, 'snoozed', minutes)}
    />
  );
}

// Individual nudge card component
function NudgeCard({
  nudge,
  onAccept,
  onDismiss,
  onSnooze,
}: {
  nudge: MotivationNudge;
  onAccept: () => void;
  onDismiss: () => void;
  onSnooze: (minutes: number) => void;
}) {
  const [showSnoozeOptions, setShowSnoozeOptions] = useState(false);
  const colors = NUDGE_COLORS[nudge.type];
  const icon = NUDGE_ICONS[nudge.type];
  const motivationEmoji = MOTIVATION_EMOJI[nudge.motivationTypeTarget as MotivationType] || '✨';

  return (
    <div className={`${colors.bg} ${colors.border} border rounded-xl p-4 shadow-sm transition-all hover:shadow-md`}>
      <div className="flex items-start gap-3">
        {/* Icon */}
        <div className={`${colors.accent} p-2 rounded-full bg-white shadow-sm`}>
          {icon}
        </div>

        {/* Content */}
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 mb-1">
            <h4 className="font-semibold text-gray-900 text-sm">{nudge.title}</h4>
            <span className="text-lg">{motivationEmoji}</span>
          </div>
          <p className="text-sm text-gray-600 leading-relaxed">{nudge.message}</p>

          {/* Actions */}
          <div className="flex items-center gap-2 mt-3">
            <button
              onClick={onAccept}
              className={`flex items-center gap-1 px-3 py-1.5 rounded-lg text-sm font-medium 
                bg-white border ${colors.border} ${colors.accent} hover:bg-gray-50 transition-colors`}
            >
              <Check className="w-4 h-4" />
              Got it!
            </button>
            
            <div className="relative">
              <button
                onClick={() => setShowSnoozeOptions(!showSnoozeOptions)}
                className="flex items-center gap-1 px-3 py-1.5 rounded-lg text-sm text-gray-500 hover:text-gray-700 hover:bg-white/50 transition-colors"
                title="Remind me later"
                aria-label="Snooze nudge"
              >
                <Clock className="w-4 h-4" />
                Later
              </button>
              
              {showSnoozeOptions && (
                <div className="absolute top-full left-0 mt-1 bg-white border border-gray-200 rounded-lg shadow-lg py-1 z-10">
                  {[15, 30, 60, 120].map((minutes) => (
                    <button
                      key={minutes}
                      onClick={() => {
                        onSnooze(minutes);
                        setShowSnoozeOptions(false);
                      }}
                      className="block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-50"
                    >
                      {minutes < 60 ? `${minutes} min` : `${minutes / 60} hr`}
                    </button>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Dismiss */}
        <button
          onClick={onDismiss}
          className="text-gray-400 hover:text-gray-600 transition-colors"
          title="Dismiss"
          aria-label="Dismiss nudge"
        >
          <X className="w-4 h-4" />
        </button>
      </div>
    </div>
  );
}

// Modal-style nudge for important messages
function NudgeModal({
  nudge,
  onAccept,
  onDismiss,
  onSnooze,
}: {
  nudge: MotivationNudge;
  onAccept: () => void;
  onDismiss: () => void;
  onSnooze: (minutes: number) => void;
}) {
  const colors = NUDGE_COLORS[nudge.type];
  const icon = NUDGE_ICONS[nudge.type];
  const motivationEmoji = MOTIVATION_EMOJI[nudge.motivationTypeTarget as MotivationType] || '✨';

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-4 bg-black/20 animate-fade-in">
      <div className={`${colors.bg} w-full max-w-md rounded-2xl shadow-2xl border ${colors.border} transform transition-all animate-slide-up`}>
        {/* Header */}
        <div className="flex items-center justify-between p-4 border-b border-gray-200/50">
          <div className={`flex items-center gap-2 ${colors.accent}`}>
            {icon}
            <span className="font-medium capitalize">{nudge.type}</span>
          </div>
          <button
            onClick={onDismiss}
            className="text-gray-400 hover:text-gray-600 transition-colors"
            title="Dismiss"
            aria-label="Dismiss nudge"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content */}
        <div className="p-6 text-center">
          <div className="text-4xl mb-4">{motivationEmoji}</div>
          <h3 className="text-xl font-bold text-gray-900 mb-2">{nudge.title}</h3>
          <p className="text-gray-600 leading-relaxed">{nudge.message}</p>
        </div>

        {/* Actions */}
        <div className="p-4 border-t border-gray-200/50 flex flex-col sm:flex-row gap-2">
          <button
            onClick={onAccept}
            className={`flex-1 flex items-center justify-center gap-2 px-4 py-3 rounded-xl text-sm font-semibold 
              bg-indigo-600 text-white hover:bg-indigo-700 transition-colors`}
          >
            <Sparkles className="w-4 h-4" />
            Let&apos;s Go!
            <ChevronRight className="w-4 h-4" />
          </button>
          
          <button
            onClick={() => onSnooze(30)}
            className="flex items-center justify-center gap-2 px-4 py-3 rounded-xl text-sm font-medium 
              bg-white border border-gray-200 text-gray-700 hover:bg-gray-50 transition-colors"
          >
            <Clock className="w-4 h-4" />
            Remind me in 30 min
          </button>
        </div>
      </div>
    </div>
  );
}

// Compact nudge indicator for dashboard headers
export function NudgeIndicator({ siteId }: { siteId: string }) {
  const { user } = useAuthContext();
  const [count, setCount] = useState(0);
  const [showNudges, setShowNudges] = useState(false);

  useEffect(() => {
    if (!user) return;
    
    const fetchCount = async () => {
      try {
        const nudges = await motivationEngine.getNudges(siteId, 10);
        setCount(nudges.length);
      } catch (error) {
        console.error('Error fetching nudge count:', error);
      }
    };

    fetchCount();
    const interval = setInterval(fetchCount, 60000); // Refresh every minute
    return () => clearInterval(interval);
  }, [user, siteId]);

  if (count === 0) return null;

  return (
    <div className="relative">
      <button
        onClick={() => setShowNudges(!showNudges)}
        className="relative p-2 rounded-full hover:bg-gray-100 transition-colors"
        title={`${count} motivation nudge${count > 1 ? 's' : ''}`}
        aria-label={`View ${count} motivation nudge${count > 1 ? 's' : ''}`}
      >
        <Bell className="w-5 h-5 text-gray-600" />
        <span className="absolute top-0 right-0 w-5 h-5 bg-indigo-600 text-white text-xs font-bold rounded-full flex items-center justify-center">
          {count > 9 ? '9+' : count}
        </span>
      </button>

      {showNudges && (
        <>
          {/* Backdrop */}
          <div 
            className="fixed inset-0 z-40" 
            onClick={() => setShowNudges(false)} 
          />
          
          {/* Dropdown */}
          <div className="absolute right-0 top-full mt-2 w-80 max-h-96 overflow-y-auto bg-white rounded-xl shadow-xl border border-gray-200 z-50">
            <div className="p-3 border-b border-gray-100">
              <h4 className="font-semibold text-gray-900">Your Motivation Nudges</h4>
            </div>
            <div className="p-2">
              <MotivationNudges 
                siteId={siteId} 
                maxNudges={5} 
                showInline 
                onNudgeAction={() => {
                  // Refresh count after action
                  setTimeout(async () => {
                    const nudges = await motivationEngine.getNudges(siteId, 10);
                    setCount(nudges.length);
                    if (nudges.length === 0) setShowNudges(false);
                  }, 500);
                }}
              />
            </div>
          </div>
        </>
      )}
    </div>
  );
}
