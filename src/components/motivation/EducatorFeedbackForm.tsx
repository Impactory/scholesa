'use client';

import React, { useState } from 'react';
import { httpsCallable } from 'firebase/functions';
import { functions } from '@/src/firebase/client-init';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import type { MotivationType } from '@/src/types/schema';
import { 
  Star, 
  CheckCircle, 
  Sparkles,
  Users,
  Target,
  Compass,
  Globe,
  Trophy,
  Palette,
  ChevronDown,
  ChevronUp,
  Loader2,
  X
} from 'lucide-react';

interface EducatorFeedbackFormProps {
  learnerId: string;
  learnerName: string;
  siteId: string;
  sessionOccurrenceId?: string;
  onSuccess?: () => void;
  onCancel?: () => void;
}

const MOTIVATION_TYPES: { type: MotivationType; label: string; icon: React.ReactNode; description: string }[] = [
  { type: 'achievement', label: 'Achievement', icon: <Target className="w-4 h-4" />, description: 'Loves completing tasks and earning rewards' },
  { type: 'social', label: 'Social', icon: <Users className="w-4 h-4" />, description: 'Motivated by collaboration and recognition' },
  { type: 'mastery', label: 'Mastery', icon: <Sparkles className="w-4 h-4" />, description: 'Driven by learning and skill development' },
  { type: 'autonomy', label: 'Autonomy', icon: <Compass className="w-4 h-4" />, description: 'Wants choice and self-direction' },
  { type: 'purpose', label: 'Purpose', icon: <Globe className="w-4 h-4" />, description: 'Motivated by real-world impact' },
  { type: 'competition', label: 'Competition', icon: <Trophy className="w-4 h-4" />, description: 'Thrives on challenges and leaderboards' },
  { type: 'creativity', label: 'Creativity', icon: <Palette className="w-4 h-4" />, description: 'Loves self-expression and projects' },
];

const PARTICIPATION_TYPES = [
  { value: 'leader', label: '🌟 Leader', description: 'Takes initiative, helps others' },
  { value: 'active', label: '✋ Active', description: 'Participates regularly' },
  { value: 'quiet', label: '🤫 Quiet', description: 'Engaged but not vocal' },
  { value: 'observer', label: '👀 Observer', description: 'Watches more than participates' },
  { value: 'reluctant', label: '😕 Reluctant', description: 'Hesitant to engage' },
] as const;

const STRATEGY_SUGGESTIONS: Record<MotivationType, string[]> = {
  achievement: ['Set clear mini-goals', 'Use progress trackers', 'Celebrate small wins', 'Award badges/points'],
  social: ['Pair with a buddy', 'Group activities', 'Peer teaching', 'Share accomplishments publicly'],
  mastery: ['Explain the "why"', 'Deep-dive opportunities', 'Self-paced learning', 'Expert challenges'],
  autonomy: ['Offer choices', 'Self-directed projects', 'Flexible deadlines', 'Personal goal setting'],
  purpose: ['Connect to real problems', 'Community projects', 'Show impact', 'Meaningful missions'],
  competition: ['Leaderboards', 'Time challenges', 'Personal bests', 'Friendly contests'],
  creativity: ['Open-ended projects', 'Multiple solutions encouraged', 'Art/design elements', 'Showcase opportunities'],
};

export function EducatorFeedbackForm({
  learnerId,
  learnerName,
  siteId,
  sessionOccurrenceId,
  onSuccess,
  onCancel,
}: EducatorFeedbackFormProps) {
  const { user } = useAuthContext();
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [showAdvanced, setShowAdvanced] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Form state
  const [engagementLevel, setEngagementLevel] = useState<1 | 2 | 3 | 4 | 5>(3);
  const [participationType, setParticipationType] = useState<typeof PARTICIPATION_TYPES[number]['value']>('active');
  const [respondedWellTo, setRespondedWellTo] = useState<MotivationType[]>([]);
  const [struggledWith, setStruggledWith] = useState('');
  const [effectiveStrategies, setEffectiveStrategies] = useState<Array<{ type: MotivationType; strategy: string }>>([]);
  const [notes, setNotes] = useState('');
  const [highlights, setHighlights] = useState<string[]>([]);
  const [newHighlight, setNewHighlight] = useState('');

  const toggleMotivationType = (type: MotivationType) => {
    setRespondedWellTo(prev => 
      prev.includes(type) 
        ? prev.filter(t => t !== type)
        : [...prev, type]
    );
  };

  const addStrategy = (type: MotivationType, strategy: string) => {
    if (!effectiveStrategies.some(s => s.type === type && s.strategy === strategy)) {
      setEffectiveStrategies(prev => [...prev, { type, strategy }]);
    }
  };

  const removeStrategy = (index: number) => {
    setEffectiveStrategies(prev => prev.filter((_, i) => i !== index));
  };

  const addHighlight = () => {
    if (newHighlight.trim()) {
      setHighlights(prev => [...prev, newHighlight.trim()]);
      setNewHighlight('');
    }
  };

  const removeHighlight = (index: number) => {
    setHighlights(prev => prev.filter((_, i) => i !== index));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user) return;

    setIsSubmitting(true);
    setError(null);

    try {
      const submitFeedback = httpsCallable(functions, 'submitEducatorFeedback');
      await submitFeedback({
        learnerId,
        siteId,
        sessionOccurrenceId,
        engagementLevel,
        participationType,
        respondedWellTo,
        struggledWith: struggledWith || undefined,
        effectiveStrategies: effectiveStrategies.length > 0 ? effectiveStrategies : undefined,
        notes: notes || undefined,
        highlights: highlights.length > 0 ? highlights : undefined,
      });

      onSuccess?.();
    } catch (err: any) {
      console.error('Error submitting feedback:', err);
      setError(err.message || 'Failed to submit feedback');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between border-b pb-4">
        <div>
          <h3 className="text-lg font-semibold text-gray-900">Learner Feedback</h3>
          <p className="text-sm text-gray-500">for {learnerName}</p>
        </div>
        {onCancel && (
          <button
            type="button"
            onClick={onCancel}
            className="text-gray-400 hover:text-gray-600"
            title="Close feedback form"
            aria-label="Close"
          >
            <X className="w-5 h-5" />
          </button>
        )}
      </div>

      {error && (
        <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg">
          {error}
        </div>
      )}

      {/* Engagement Level */}
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-2">
          Today&apos;s Engagement Level
        </label>
        <div className="flex gap-2">
          {([1, 2, 3, 4, 5] as const).map((level) => (
            <button
              key={level}
              type="button"
              onClick={() => setEngagementLevel(level)}
              className={`flex-1 py-3 px-2 rounded-lg border-2 transition-all ${
                engagementLevel === level
                  ? 'border-indigo-500 bg-indigo-50'
                  : 'border-gray-200 hover:border-gray-300'
              }`}
            >
              <div className="flex flex-col items-center gap-1">
                <Star 
                  className={`w-6 h-6 ${
                    engagementLevel >= level ? 'text-yellow-400 fill-yellow-400' : 'text-gray-300'
                  }`} 
                />
                <span className="text-xs text-gray-600">
                  {level === 1 && 'Low'}
                  {level === 2 && 'Below'}
                  {level === 3 && 'Average'}
                  {level === 4 && 'Good'}
                  {level === 5 && 'Excellent'}
                </span>
              </div>
            </button>
          ))}
        </div>
      </div>

      {/* Participation Type */}
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-2">
          Participation Style
        </label>
        <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
          {PARTICIPATION_TYPES.map((p) => (
            <button
              key={p.value}
              type="button"
              onClick={() => setParticipationType(p.value)}
              className={`p-3 rounded-lg border-2 text-left transition-all ${
                participationType === p.value
                  ? 'border-indigo-500 bg-indigo-50'
                  : 'border-gray-200 hover:border-gray-300'
              }`}
            >
              <div className="font-medium text-sm">{p.label}</div>
              <div className="text-xs text-gray-500">{p.description}</div>
            </button>
          ))}
        </div>
      </div>

      {/* What Worked */}
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-2">
          What motivated them today? <span className="text-gray-400">(select all that apply)</span>
        </label>
        <div className="flex flex-wrap gap-2">
          {MOTIVATION_TYPES.map((m) => (
            <button
              key={m.type}
              type="button"
              onClick={() => toggleMotivationType(m.type)}
              className={`flex items-center gap-2 px-3 py-2 rounded-full border-2 transition-all ${
                respondedWellTo.includes(m.type)
                  ? 'border-green-500 bg-green-50 text-green-700'
                  : 'border-gray-200 hover:border-gray-300 text-gray-600'
              }`}
            >
              {m.icon}
              <span className="text-sm">{m.label}</span>
              {respondedWellTo.includes(m.type) && <CheckCircle className="w-4 h-4" />}
            </button>
          ))}
        </div>
      </div>

      {/* Quick Highlights */}
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-2">
          Celebration moments 🎉 <span className="text-gray-400">(optional)</span>
        </label>
        <div className="flex gap-2 mb-2">
          <input
            type="text"
            value={newHighlight}
            onChange={(e) => setNewHighlight(e.target.value)}
            onKeyPress={(e) => e.key === 'Enter' && (e.preventDefault(), addHighlight())}
            placeholder="e.g., Led the group discussion brilliantly!"
            className="flex-1 px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
          />
          <button
            type="button"
            onClick={addHighlight}
            disabled={!newHighlight.trim()}
            className="px-4 py-2 bg-indigo-600 text-white rounded-lg text-sm hover:bg-indigo-700 disabled:bg-gray-300 disabled:cursor-not-allowed"
          >
            Add
          </button>
        </div>
        {highlights.length > 0 && (
          <div className="flex flex-wrap gap-2">
            {highlights.map((h, i) => (
              <span
                key={i}
                className="inline-flex items-center gap-1 px-3 py-1 bg-yellow-50 text-yellow-800 rounded-full text-sm"
              >
                ✨ {h}
                <button
                  type="button"
                  onClick={() => removeHighlight(i)}
                  className="hover:text-yellow-600"
                  title="Remove highlight"
                  aria-label="Remove highlight"
                >
                  <X className="w-3 h-3" />
                </button>
              </span>
            ))}
          </div>
        )}
      </div>

      {/* Advanced Section */}
      <div className="border-t pt-4">
        <button
          type="button"
          onClick={() => setShowAdvanced(!showAdvanced)}
          className="flex items-center gap-2 text-sm text-gray-600 hover:text-gray-900"
        >
          {showAdvanced ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
          {showAdvanced ? 'Hide' : 'Show'} advanced options
        </button>

        {showAdvanced && (
          <div className="mt-4 space-y-4">
            {/* Struggled With */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                What they struggled with <span className="text-gray-400">(optional)</span>
              </label>
              <input
                type="text"
                value={struggledWith}
                onChange={(e) => setStruggledWith(e.target.value)}
                placeholder="e.g., Staying focused during group work"
                className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
              />
            </div>

            {/* Effective Strategies */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Strategies that worked <span className="text-gray-400">(help the system learn)</span>
              </label>
              
              {respondedWellTo.length > 0 && (
                <div className="space-y-3 mb-3">
                  {respondedWellTo.map((type) => (
                    <div key={type} className="bg-gray-50 rounded-lg p-3">
                      <div className="text-sm font-medium text-gray-700 mb-2 flex items-center gap-2">
                        {MOTIVATION_TYPES.find(m => m.type === type)?.icon}
                        {MOTIVATION_TYPES.find(m => m.type === type)?.label} strategies:
                      </div>
                      <div className="flex flex-wrap gap-1">
                        {STRATEGY_SUGGESTIONS[type].map((strategy) => (
                          <button
                            key={strategy}
                            type="button"
                            onClick={() => addStrategy(type, strategy)}
                            disabled={effectiveStrategies.some(s => s.type === type && s.strategy === strategy)}
                            className={`px-2 py-1 text-xs rounded-full transition-all ${
                              effectiveStrategies.some(s => s.type === type && s.strategy === strategy)
                                ? 'bg-green-100 text-green-700 border border-green-300'
                                : 'bg-white border border-gray-200 hover:border-indigo-300 text-gray-600'
                            }`}
                          >
                            + {strategy}
                          </button>
                        ))}
                      </div>
                    </div>
                  ))}
                </div>
              )}

              {effectiveStrategies.length > 0 && (
                <div className="flex flex-wrap gap-2">
                  {effectiveStrategies.map((s, i) => (
                    <span
                      key={i}
                      className="inline-flex items-center gap-1 px-3 py-1 bg-green-50 text-green-700 rounded-full text-sm"
                    >
                      {MOTIVATION_TYPES.find(m => m.type === s.type)?.icon}
                      {s.strategy}
                      <button
                        type="button"
                        onClick={() => removeStrategy(i)}
                        className="hover:text-green-900"
                        title="Remove strategy"
                        aria-label="Remove strategy"
                      >
                        <X className="w-3 h-3" />
                      </button>
                    </span>
                  ))}
                </div>
              )}
            </div>

            {/* Notes */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Additional notes <span className="text-gray-400">(optional)</span>
              </label>
              <textarea
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                rows={3}
                placeholder="Any other observations that might help personalize their learning experience..."
                className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
              />
            </div>
          </div>
        )}
      </div>

      {/* Submit */}
      <div className="flex gap-3 pt-4 border-t">
        {onCancel && (
          <button
            type="button"
            onClick={onCancel}
            className="flex-1 px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50"
          >
            Cancel
          </button>
        )}
        <button
          type="submit"
          disabled={isSubmitting}
          className="flex-1 px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 disabled:bg-indigo-400 flex items-center justify-center gap-2"
        >
          {isSubmitting ? (
            <>
              <Loader2 className="w-4 h-4 animate-spin" />
              Saving...
            </>
          ) : (
            <>
              <CheckCircle className="w-4 h-4" />
              Save Feedback
            </>
          )}
        </button>
      </div>
    </form>
  );
}
