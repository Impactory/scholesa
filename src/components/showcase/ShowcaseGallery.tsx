'use client';

/**
 * Showcase Gallery Component
 * 
 * Displays student work submissions (showcase items) with ability to:
 * - View submitted work
 * - Give peer recognition
 * - Submit new work
 * - Filter by visibility/program
 */

import React, { useState, useEffect } from 'react';
import Image from 'next/image';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { ShowcaseSubmissionForm } from './ShowcaseSubmissionForm';
import { PeerRecognitionForm } from '@/src/components/recognition/PeerRecognitionForm';
import { collection, query, where, getDocs, orderBy, limit, Timestamp } from 'firebase/firestore';
import { db } from '@/src/firebase/client-init';
import { 
  SparklesIcon, 
  HeartIcon, 
  EyeIcon,
  PlusIcon,
  FilterIcon
} from 'lucide-react';
import { usePageViewTracking } from '@/src/hooks/useTelemetry';

interface ShowcaseItem {
  id: string;
  learnerId: string;
  learnerName: string;
  siteId: string;
  title: string;
  description: string;
  visibility: 'site' | 'program' | 'public';
  recognitionCount: number | null;
  viewCount: number | null;
  artifactUrl?: string;
  createdAt: Date;
}

function readFiniteNumber(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

export function ShowcaseGallery() {
  usePageViewTracking('showcase_gallery');
  
  const { profile } = useAuthContext();
  const [showcaseItems, setShowcaseItems] = useState<ShowcaseItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [showSubmitForm, setShowSubmitForm] = useState(false);
  const [selectedItem, setSelectedItem] = useState<ShowcaseItem | null>(null);
  const [showRecognitionForm, setShowRecognitionForm] = useState(false);
  const [filterVisibility, setFilterVisibility] = useState<'all' | 'site' | 'program' | 'public'>('all');
  
  const siteId = profile?.activeSiteId || profile?.siteIds?.[0] || '';

  useEffect(() => {
    if (!siteId) return;
    
    const fetchShowcase = async () => {
      setLoading(true);
      try {
        // Query showcase submissions
        const showcaseRef = collection(db, 'showcaseSubmissions');
        let q = query(
          showcaseRef,
          where('siteId', '==', siteId),
          where('status', '==', 'approved'),
          orderBy('createdAt', 'desc'),
          limit(50)
        );
        
        // Apply visibility filter
        if (filterVisibility !== 'all') {
          q = query(
            showcaseRef,
            where('siteId', '==', siteId),
            where('visibility', '==', filterVisibility),
            where('status', '==', 'approved'),
            orderBy('createdAt', 'desc'),
            limit(50)
          );
        }
        
        const snapshot = await getDocs(q);
        const items: ShowcaseItem[] = snapshot.docs.map(doc => {
          const data = doc.data();
          return {
            id: doc.id,
            learnerId: data.learnerId,
            learnerName: data.learnerName || 'Unknown',
            siteId: data.siteId,
            title: data.title,
            description: data.description,
            visibility: data.visibility,
            recognitionCount: readFiniteNumber(data.recognitionCount),
            viewCount: readFiniteNumber(data.viewCount),
            artifactUrl: data.artifactUrl,
            createdAt: (data.createdAt as Timestamp).toDate()
          };
        });
        
        setShowcaseItems(items);
      } catch (err) {
        console.error('Failed to load showcase:', err);
      } finally {
        setLoading(false);
      }
    };
    
    fetchShowcase();
  }, [siteId, filterVisibility]);
  
  if (loading) {
    return (
      <div className="space-y-4 animate-pulse">
        {[1,2,3].map(i => (
          <div key={i} className="h-48 bg-gray-200 rounded-lg" />
        ))}
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Showcase Gallery</h1>
          <p className="text-gray-600 mt-1">Celebrate student work and give recognition</p>
        </div>
        <button
          onClick={() => setShowSubmitForm(true)}
          className="flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700"
        >
          <PlusIcon className="h-5 w-5" />
          Submit Work
        </button>
      </div>
      
      {/* Filters */}
      <div className="flex items-center gap-4">
        <FilterIcon className="h-5 w-5 text-gray-400" />
        <div className="flex gap-2">
          {(['all', 'site', 'program', 'public'] as const).map(vis => (
            <button
              key={vis}
              onClick={() => setFilterVisibility(vis)}
              className={`px-3 py-1.5 rounded-md text-sm font-medium transition ${
                filterVisibility === vis
                  ? 'bg-indigo-100 text-indigo-700'
                  : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
              }`}
            >
              {vis.charAt(0).toUpperCase() + vis.slice(1)}
            </button>
          ))}
        </div>
      </div>
      
      {/* Gallery Grid */}
      {showcaseItems.length === 0 ? (
        <div className="bg-white rounded-lg border border-gray-200 p-12 text-center">
          <SparklesIcon className="h-12 w-12 text-gray-400 mx-auto mb-4" />
          <p className="text-gray-500">No showcase items yet. Be the first to share your work!</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {showcaseItems.map(item => (
            <ShowcaseCard
              key={item.id}
              item={item}
              onRecognize={() => {
                setSelectedItem(item);
                setShowRecognitionForm(true);
              }}
            />
          ))}
        </div>
      )}
      
      {/* Submit Form Modal */}
      {showSubmitForm && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg max-w-2xl w-full max-h-[90vh] overflow-y-auto">
            <ShowcaseSubmissionForm
              onClose={() => setShowSubmitForm(false)}
              onSubmitted={(_submissionId) => {
                setShowSubmitForm(false);
                // Refresh gallery
                window.location.reload();
              }}
            />
          </div>
        </div>
      )}
      
      {/* Recognition Form Modal */}
      {showRecognitionForm && selectedItem && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg max-w-md w-full">
            <PeerRecognitionForm
              recipientId={selectedItem.learnerId}
              recipientName={selectedItem.learnerName}
              onClose={() => {
                setShowRecognitionForm(false);
                setSelectedItem(null);
              }}
              onRecognitionGiven={() => {
                setShowRecognitionForm(false);
                setSelectedItem(null);
                // Refresh gallery to update recognition counts
                window.location.reload();
              }}
            />
          </div>
        </div>
      )}
    </div>
  );
}

// ==================== HELPER COMPONENTS ====================

interface ShowcaseCardProps {
  item: ShowcaseItem;
  onRecognize: () => void;
}

function ShowcaseCard({ item, onRecognize }: ShowcaseCardProps) {
  const visibilityColors = {
    site: 'bg-blue-100 text-blue-700',
    program: 'bg-purple-100 text-purple-700',
    public: 'bg-green-100 text-green-700'
  };
  
  return (
    <div className="bg-white rounded-lg border border-gray-200 shadow-sm hover:shadow-md transition overflow-hidden">
      {/* Image/Placeholder */}
      <div className="h-48 bg-gradient-to-br from-indigo-100 to-purple-100 flex items-center justify-center relative">
        {item.artifactUrl ? (
          <Image src={item.artifactUrl} alt={item.title} fill className="object-cover" />
        ) : (
          <SparklesIcon className="h-16 w-16 text-indigo-400" />
        )}
      </div>
      
      {/* Content */}
      <div className="p-4">
        <div className="flex items-start justify-between mb-2">
          <h3 className="text-lg font-semibold text-gray-900 line-clamp-1">{item.title}</h3>
          <span className={`px-2 py-1 rounded-md text-xs font-medium ${visibilityColors[item.visibility]}`}>
            {item.visibility}
          </span>
        </div>
        
        <p className="text-gray-600 text-sm line-clamp-2 mb-3">{item.description}</p>
        
        <div className="flex items-center gap-1 text-xs text-gray-500 mb-3">
          <span>by {item.learnerName}</span>
          <span>•</span>
          <span>{item.createdAt.toLocaleDateString()}</span>
        </div>
        
        {/* Stats */}
        <div className="flex items-center justify-between pt-3 border-t border-gray-100">
          <div className="flex items-center gap-4 text-sm text-gray-600">
            <div className="flex items-center gap-1">
              <HeartIcon className="h-4 w-4" />
              <span>{item.recognitionCount != null ? item.recognitionCount : 'Unavailable'}</span>
            </div>
            <div className="flex items-center gap-1">
              <EyeIcon className="h-4 w-4" />
              <span>{item.viewCount != null ? item.viewCount : 'Unavailable'}</span>
            </div>
          </div>
          
          <button
            onClick={onRecognize}
            className="flex items-center gap-1 px-3 py-1.5 bg-pink-50 text-pink-700 rounded-md hover:bg-pink-100 text-sm font-medium"
          >
            <HeartIcon className="h-4 w-4" />
            Recognize
          </button>
        </div>
      </div>
    </div>
  );
}
