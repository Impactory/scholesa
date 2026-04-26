'use client';

/**
 * Showcase Submission Form
 * 
 * Allows learners to submit work to the public showcase (SDT belonging pillar).
 * Tracks showcase submission events via telemetry.
 */

import React, { useState } from 'react';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { addDoc, Timestamp } from 'firebase/firestore';
import { showcaseSubmissionsCollection } from '@/src/firebase/firestore/collections';
import { useBelongingTracking } from '@/src/hooks/useTelemetry';
import { SparklesIcon, XIcon, ImageIcon, GlobeIcon, UsersIcon } from 'lucide-react';

interface ShowcaseSubmissionFormProps {
  missionId?: string;
  attemptId?: string;
  artifactUrl?: string;
  onClose?: () => void;
  onSubmitted?: (showcaseId: string) => void;
}

export function ShowcaseSubmissionForm({ 
  missionId, 
  attemptId, 
  artifactUrl,
  onClose, 
  onSubmitted 
}: ShowcaseSubmissionFormProps) {
  const { profile } = useAuthContext();
  const trackBelonging = useBelongingTracking();
  
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [visibility, setVisibility] = useState<'site' | 'program' | 'public'>('site');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  
  const learnerId = profile?.uid || '';
  const siteId = profile?.activeSiteId || profile?.siteIds?.[0] || '';
  
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!title.trim()) {
      setError('Please give your work a title');
      return;
    }
    
    if (!description.trim()) {
      setError('Please describe your work');
      return;
    }
    
    setLoading(true);
    setError('');
    
    try {
      // Create showcase submission
      const showcaseData = {
        learnerId,
        siteId,
        learnerName: profile?.displayName || 'Learner',
        title: title.trim(),
        description: description.trim(),
        artifactType: 'document' as const,
        artifactUrl: artifactUrl || '',
        microSkillIds: [],
        recognitions: [],
        visibility,
        visibleToCrew: visibility === 'site',
        visibleToSite: true,
        missionId: missionId || null,
        attemptId: attemptId || null,
        submittedAt: Timestamp.now(),
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        viewCount: 0,
        likeCount: 0,
        commentCount: 0,
      };
      
      const showcaseRef = await addDoc(showcaseSubmissionsCollection, showcaseData);
      const showcaseId = showcaseRef.id;
      
      // Track showcase submission event
      trackBelonging('showcase_submitted', {
        showcaseId,
        missionId: missionId || 'none',
        visibility,
        titleLength: title.trim().length,
        descriptionLength: description.trim().length,
        hasArtifact: !!artifactUrl
      });
      
      // Reset form
      setTitle('');
      setDescription('');
      setVisibility('site');
      
      // Notify parent
      if (onSubmitted) onSubmitted(showcaseId);
      if (onClose) onClose();
      
    } catch (err) {
      console.error('Failed to submit to showcase:', err);
      setError('Failed to submit. Please try again.');
    } finally {
      setLoading(false);
    }
  };
  
  return (
    <div className="bg-white rounded-lg border border-gray-200 shadow-lg p-6">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <SparklesIcon className="h-6 w-6 text-pink-600" />
          <h2 className="text-xl font-bold text-gray-900">Share to Showcase</h2>
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
      
      <p className="text-sm text-gray-600 mb-4">
        Share your best work with the community! Get recognition from peers and educators.
      </p>
      
      {artifactUrl && (
        <div className="mb-4 p-3 bg-blue-50 border border-blue-200 rounded-md">
          <div className="flex items-center gap-2 text-sm text-blue-800">
            <ImageIcon className="h-4 w-4" />
            <span>Artifact attached</span>
          </div>
        </div>
      )}
      
      <form onSubmit={handleSubmit} className="space-y-4">
        {/* Title */}
        <div>
          <label htmlFor="title" className="block text-sm font-medium text-gray-700 mb-1">
            Title
          </label>
          <input
            type="text"
            id="title"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="Give your work a catchy title"
            maxLength={100}
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-pink-500 focus:border-pink-500"
          />
          <p className="text-xs text-gray-500 mt-1">
            {title.length}/100 characters
          </p>
        </div>
        
        {/* Description */}
        <div>
          <label htmlFor="description" className="block text-sm font-medium text-gray-700 mb-1">
            Description
          </label>
          <textarea
            id="description"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="What did you create? What did you learn? What are you proud of?"
            rows={4}
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-pink-500 focus:border-pink-500"
            maxLength={500}
          />
          <p className="text-xs text-gray-500 mt-1">
            {description.length}/500 characters
          </p>
        </div>
        
        {/* Visibility */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Who can see this?
          </label>
          <div className="space-y-2">
            <label className="flex items-center gap-3 p-3 border border-gray-300 rounded-md cursor-pointer hover:bg-gray-50">
              <input
                type="radio"
                name="visibility"
                value="site"
                checked={visibility === 'site'}
                onChange={(e) => setVisibility(e.target.value as 'site')}
                className="text-pink-600 focus:ring-pink-500"
              />
              <UsersIcon className="h-5 w-5 text-gray-600" />
              <div className="flex-1">
                <p className="font-medium text-gray-900">My Site</p>
                <p className="text-xs text-gray-500">Only people at my learning studio</p>
              </div>
            </label>
            
            <label className="flex items-center gap-3 p-3 border border-gray-300 rounded-md cursor-pointer hover:bg-gray-50">
              <input
                type="radio"
                name="visibility"
                value="program"
                checked={visibility === 'program'}
                onChange={(e) => setVisibility(e.target.value as 'program')}
                className="text-pink-600 focus:ring-pink-500"
              />
              <GlobeIcon className="h-5 w-5 text-gray-600" />
              <div className="flex-1">
                <p className="font-medium text-gray-900">My Program</p>
                <p className="text-xs text-gray-500">All sites in my program network</p>
              </div>
            </label>
            
            <label className="flex items-center gap-3 p-3 border border-gray-300 rounded-md cursor-pointer hover:bg-gray-50">
              <input
                type="radio"
                name="visibility"
                value="public"
                checked={visibility === 'public'}
                onChange={(e) => setVisibility(e.target.value as 'public')}
                className="text-pink-600 focus:ring-pink-500"
              />
              <SparklesIcon className="h-5 w-5 text-gray-600" />
              <div className="flex-1">
                <p className="font-medium text-gray-900">Public Showcase</p>
                <p className="text-xs text-gray-500">Everyone on Scholesa platform</p>
              </div>
            </label>
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
            disabled={loading || !title.trim() || !description.trim()}
            className="flex-1 px-4 py-2 bg-pink-600 text-white rounded-md font-medium hover:bg-pink-700 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loading ? 'Submitting...' : 'Share to Showcase'}
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
