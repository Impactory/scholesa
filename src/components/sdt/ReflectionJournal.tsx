'use client';

/**
 * Reflection Journal
 * 
 * Level 1: Must-have for flow and retention
 * 30-second prompts + emoji scale + "what I'll try next"
 * This is your motivation engine fuel!
 */

import React, { useState } from 'react';
import {
  SparklesIcon,
  TrendingUpIcon,
  CheckCircle2Icon
} from 'lucide-react';
import { sdtMotivation } from '@/src/lib/motivation/sdtMotivation';

interface ReflectionJournalProps {
  learnerId: string;
  siteId: string;
  sprintSessionId?: string;
  missionId?: string;
  cycleId?: string;
  onComplete?: () => void;
}

type EmojiLevel = 1 | 2 | 3 | 4 | 5;

export function ReflectionJournal({
  learnerId,
  siteId,
  sprintSessionId,
  missionId,
  cycleId: _cycleId,
  onComplete
}: ReflectionJournalProps) {
  // Form state
  const [proudOf, setProudOf] = useState('');
  const [nextIWill, setNextIWill] = useState('');
  const [effortLevel, setEffortLevel] = useState<EmojiLevel | null>(null);
  const [enjoymentLevel, setEnjoymentLevel] = useState<EmojiLevel | null>(null);
  const [effectiveStrategy, setEffectiveStrategy] = useState('');
  
  // UI state
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!proudOf.trim() || !nextIWill.trim()) {
      setError('Please answer both reflection questions');
      return;
    }

    try {
      setLoading(true);
      setError(null);

      await sdtMotivation.submitReflection(
        learnerId,
        siteId,
        proudOf,
        nextIWill,
        sprintSessionId,
        missionId,
        effortLevel || undefined,
        enjoymentLevel || undefined,
        effectiveStrategy || undefined
      );

      setSuccess(true);
      setTimeout(() => {
        onComplete?.();
      }, 1500);
    } catch (err) {
      console.error('Reflection submission error:', err);
      setError('Failed to save reflection. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  if (success) {
    return (
      <div className="bg-white rounded-lg border border-gray-200 p-8 text-center shadow-lg">
        <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
          <CheckCircle2Icon className="w-8 h-8 text-green-600" />
        </div>
        <h3 className="text-xl font-bold text-gray-900 mb-2">Reflection Saved! 🎉</h3>
        <p className="text-gray-600">Great job thinking about your learning!</p>
      </div>
    );
  }

  return (
    <div className="max-w-2xl mx-auto">
      <form onSubmit={handleSubmit} className="bg-white rounded-lg border border-gray-200 shadow-sm">
        {/* Header */}
        <div className="bg-gradient-to-r from-purple-500 to-pink-600 rounded-t-lg p-6 text-white">
          <h2 className="text-2xl font-bold mb-2 flex items-center gap-2">
            <SparklesIcon className="w-6 h-6" />
            Time to Reflect
          </h2>
          <p className="text-purple-100">
            Taking a moment to think about your learning helps you grow faster!
          </p>
        </div>

        <div className="p-6 space-y-6">
          {/* Core Prompts */}
          <div className="space-y-4">
            {/* I'm Proud Of */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                🌟 I'm proud of...
              </label>
              <textarea
                value={proudOf}
                onChange={(e) => setProudOf(e.target.value)}
                placeholder="Example: I figured out how to fix the bug by testing each line. I didn't give up!"
                className="w-full h-24 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent resize-none"
                required
              />
              <p className="text-xs text-gray-500 mt-1">What did you accomplish? What are you happy about?</p>
            </div>

            {/* Next I Will */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                🚀 Next I will...
              </label>
              <textarea
                value={nextIWill}
                onChange={(e) => setNextIWill(e.target.value)}
                placeholder="Example: Try the Silver challenge next time. Ask for help earlier if I get stuck."
                className="w-full h-24 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent resize-none"
                required
              />
              <p className="text-xs text-gray-500 mt-1">What will you try or do differently next time?</p>
            </div>
          </div>

          {/* Emoji Scales */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 pt-4 border-t">
            {/* Effort Scale */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-3">
                💪 How hard did you try?
              </label>
              <div className="flex justify-between gap-2">
                {([1, 2, 3, 4, 5] as EmojiLevel[]).map((level) => (
                  <button
                    key={level}
                    type="button"
                    onClick={() => setEffortLevel(level)}
                    className={`flex-1 p-3 rounded-lg border-2 transition-all ${
                      effortLevel === level
                        ? 'border-purple-500 bg-purple-50 scale-110'
                        : 'border-gray-200 hover:border-gray-300'
                    }`}
                    title={`Effort level ${level}`}
                    aria-label={`Effort level ${level}`}
                  >
                    <div className={`text-2xl ${effortLevel === level ? 'scale-125' : ''} transition-transform`}>
                      {getEffortEmoji(level)}
                    </div>
                  </button>
                ))}
              </div>
              <div className="flex justify-between text-xs text-gray-500 mt-1 px-1">
                <span>Coasting</span>
                <span>All-in!</span>
              </div>
            </div>

            {/* Enjoyment Scale */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-3">
                😊 How much fun was it?
              </label>
              <div className="flex justify-between gap-2">
                {([1, 2, 3, 4, 5] as EmojiLevel[]).map((level) => (
                  <button
                    key={level}
                    type="button"
                    onClick={() => setEnjoymentLevel(level)}
                    className={`flex-1 p-3 rounded-lg border-2 transition-all ${
                      enjoymentLevel === level
                        ? 'border-pink-500 bg-pink-50 scale-110'
                        : 'border-gray-200 hover:border-gray-300'
                    }`}
                    title={`Enjoyment level ${level}`}
                    aria-label={`Enjoyment level ${level}`}
                  >
                    <div className={`text-2xl ${enjoymentLevel === level ? 'scale-125' : ''} transition-transform`}>
                      {getEnjoymentEmoji(level)}
                    </div>
                  </button>
                ))}
              </div>
              <div className="flex justify-between text-xs text-gray-500 mt-1 px-1">
                <span>Meh</span>
                <span>Loved it!</span>
              </div>
            </div>
          </div>

          {/* Effective Strategy (Optional) */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              <TrendingUpIcon className="w-4 h-4 inline mr-1" />
              What strategy worked well? (optional)
            </label>
            <input
              type="text"
              value={effectiveStrategy}
              onChange={(e) => setEffectiveStrategy(e.target.value)}
              placeholder="Example: Breaking the problem into smaller steps"
              className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent"
            />
            <p className="text-xs text-gray-500 mt-1">This helps us understand what works for you!</p>
          </div>

          {/* Error */}
          {error && (
            <div className="bg-red-50 border border-red-200 rounded-lg p-3 text-sm text-red-800">
              {error}
            </div>
          )}

          {/* Submit */}
          <button
            type="submit"
            disabled={loading || !proudOf.trim() || !nextIWill.trim()}
            className="w-full bg-gradient-to-r from-purple-600 to-pink-600 text-white px-6 py-3 rounded-lg font-medium hover:from-purple-700 hover:to-pink-700 disabled:from-gray-300 disabled:to-gray-300 disabled:cursor-not-allowed flex items-center justify-center gap-2"
          >
            {loading ? (
              <>
                <div className="animate-spin rounded-full h-5 w-5 border-2 border-white border-t-transparent"></div>
                <span>Saving...</span>
              </>
            ) : (
              <>
                <CheckCircle2Icon className="w-5 h-5" />
                <span>Save Reflection</span>
              </>
            )}
          </button>

          {/* Encouragement */}
          <div className="bg-gradient-to-r from-blue-50 to-purple-50 rounded-lg p-4 text-center">
            <p className="text-sm text-gray-700">
              ✨ <strong>Remember:</strong> Reflection helps your brain remember what you learned!
            </p>
          </div>
        </div>
      </form>
    </div>
  );
}

// Helper functions for emoji scales
function getEffortEmoji(level: EmojiLevel): string {
  const emojis: Record<EmojiLevel, string> = {
    1: '😴',
    2: '🙂',
    3: '💪',
    4: '🔥',
    5: '🚀'
  };
  return emojis[level];
}

function getEnjoymentEmoji(level: EmojiLevel): string {
  const emojis: Record<EmojiLevel, string> = {
    1: '😐',
    2: '🙂',
    3: '😊',
    4: '😄',
    5: '🤩'
  };
  return emojis[level];
}

/**
 * Quick Reflection - Compact version for post-sprint
 */
export function QuickReflection({
  learnerId,
  siteId,
  sprintSessionId,
  onComplete
}: {
  learnerId: string;
  siteId: string;
  sprintSessionId: string;
  onComplete?: () => void;
}) {
  const [proudOf, setProudOf] = useState('');
  const [nextIWill, setNextIWill] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async () => {
    if (!proudOf.trim() || !nextIWill.trim()) return;

    try {
      setLoading(true);
      await sdtMotivation.submitReflection(
        learnerId,
        siteId,
        proudOf,
        nextIWill,
        sprintSessionId
      );
      onComplete?.();
    } catch (err) {
      console.error('Quick reflection error:', err);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="bg-white rounded-lg border border-gray-200 p-4 space-y-3">
      <h3 className="font-semibold text-gray-900 flex items-center gap-2">
        <SparklesIcon className="w-5 h-5 text-purple-600" />
        Quick Reflection
      </h3>
      
      <input
        type="text"
        value={proudOf}
        onChange={(e) => setProudOf(e.target.value)}
        placeholder="I'm proud of..."
        className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-purple-500"
      />
      
      <input
        type="text"
        value={nextIWill}
        onChange={(e) => setNextIWill(e.target.value)}
        placeholder="Next I will..."
        className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-purple-500"
      />
      
      <button
        onClick={handleSubmit}
        disabled={loading || !proudOf.trim() || !nextIWill.trim()}
        className="w-full bg-purple-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-purple-700 disabled:bg-gray-300"
      >
        {loading ? 'Saving...' : 'Save'}
      </button>
    </div>
  );
}
