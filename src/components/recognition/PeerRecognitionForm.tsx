'use client';

/**
 * Peer Recognition Component
 * 
 * Allows learners to give recognition to peers (SDT belonging pillar).
 * Tracks recognition events via telemetry.
 */

import React, { useState } from 'react';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { BelongingEngine } from '@/src/lib/motivation/motivationEngine';
import { useBelongingTracking } from '@/src/hooks/useTelemetry';
import { HeartIcon, XIcon, SparklesIcon } from 'lucide-react';

interface PeerRecognitionFormProps {
  recipientId: string;
  recipientName: string;
  contextType?: 'showcase' | 'collaboration' | 'general';
  contextId?: string;
  onClose?: () => void;
  onRecognitionGiven?: () => void;
}

const RECOGNITION_TYPES = [
  { value: 'helper', label: '🤝 Helper', description: 'Helped me understand something' },
  { value: 'debugger', label: '🔍 Debugger', description: 'Found and fixed problems' },
  { value: 'clear_communicator', label: '💬 Clear Communicator', description: 'Explained things clearly' },
  { value: 'courage_to_try', label: '💪 Courage to Try', description: 'Never gave up' }
];

export function PeerRecognitionForm({ 
  recipientId, 
  recipientName,
  contextType = 'general',
  contextId,
  onClose,
  onRecognitionGiven
}: PeerRecognitionFormProps) {
  const { profile } = useAuthContext();
  const trackBelonging = useBelongingTracking();
  
  const [selectedType, setSelectedType] = useState('');
  const [message, setMessage] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  
  const giverId = profile?.uid || '';
  const siteId = profile?.activeSiteId || profile?.siteIds?.[0] || '';
  
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!selectedType) {
      setError('Please select a recognition type');
      return;
    }
    
    setLoading(true);
    setError('');
    
    try {
      // Give recognition via BelongingEngine
      await BelongingEngine.giveRecognition(
        {
          giverId,
          giverName: profile?.displayName || profile?.email || 'Anonymous',
          recipientId,
          siteId,
          sessionOccurrenceId: contextId || '',
          recognitionType: selectedType as import('@/src/types/schema').RecognitionType,
          message: message.trim(),
          isPublic: true
        },
        5 // Default to the Builders band when no grade context is available
      );
      
      // Track recognition event
      trackBelonging('recognition_given', {
        recipientId,
        recipientName,
        recognitionType: selectedType,
        hasMessage: message.trim().length > 0,
        messageLength: message.trim().length,
        contextType,
        contextId: contextId || 'none'
      });
      
      // Reset form
      setSelectedType('');
      setMessage('');
      
      // Notify parent
      if (onRecognitionGiven) onRecognitionGiven();
      if (onClose) onClose();
      
    } catch (err) {
      console.error('Failed to give recognition:', err);
      setError('Failed to give recognition. Please try again.');
    } finally {
      setLoading(false);
    }
  };
  
  return (
    <div className="bg-white rounded-lg border border-gray-200 shadow-lg p-6">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <HeartIcon className="h-6 w-6 text-pink-600" />
          <h2 className="text-xl font-bold text-gray-900">Give Recognition</h2>
        </div>
        {onClose && (
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600"
            aria-label="Close"
          >
            <XIcon className="h-5 w-5" />
          </button>
        )}
      </div>
      
      <div className="mb-4 p-3 bg-pink-50 border border-pink-200 rounded-md">
        <p className="text-sm text-pink-800">
          You're recognizing <span className="font-semibold">{recipientName}</span>
        </p>
      </div>
      
      <form onSubmit={handleSubmit} className="space-y-4">
        {/* Recognition Type */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            What do you want to recognize?
          </label>
          <div className="grid grid-cols-2 gap-2">
            {RECOGNITION_TYPES.map(type => (
              <label
                key={type.value}
                className={`flex flex-col p-3 border-2 rounded-lg cursor-pointer transition ${
                  selectedType === type.value
                    ? 'border-pink-600 bg-pink-50'
                    : 'border-gray-300 hover:border-pink-300 hover:bg-pink-50'
                }`}
              >
                <input
                  type="radio"
                  name="recognitionType"
                  value={type.value}
                  checked={selectedType === type.value}
                  onChange={(e) => setSelectedType(e.target.value)}
                  className="sr-only"
                />
                <span className="text-lg font-medium text-gray-900">{type.label}</span>
                <span className="text-xs text-gray-600 mt-1">{type.description}</span>
              </label>
            ))}
          </div>
        </div>
        
        {/* Optional Message */}
        <div>
          <label htmlFor="message" className="block text-sm font-medium text-gray-700 mb-1">
            Personal Message <span className="text-gray-500">(optional)</span>
          </label>
          <textarea
            id="message"
            value={message}
            onChange={(e) => setMessage(e.target.value)}
            placeholder="Add a personal note about why you're recognizing this person..."
            rows={3}
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-pink-500 focus:border-pink-500"
            maxLength={300}
          />
          <p className="text-xs text-gray-500 mt-1">
            {message.length}/300 characters
          </p>
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
            disabled={loading || !selectedType}
            className="flex-1 px-4 py-2 bg-pink-600 text-white rounded-md font-medium hover:bg-pink-700 disabled:opacity-50 disabled:cursor-not-allowed inline-flex items-center justify-center gap-2"
          >
            <SparklesIcon className="h-4 w-4" />
            {loading ? 'Sending...' : 'Give Recognition'}
          </button>
          {onClose && (
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 bg-gray-100 text-gray-700 rounded-md font-medium hover:bg-gray-200"
            >
              Cancel
            </button>
          )}
        </div>
      </form>
    </div>
  );
}
