'use client';

import { useState } from 'react';
import { LearnerPortfolioBrowser } from '@/src/components/evidence/LearnerPortfolioBrowser';
import { LearnerEvidenceSubmission } from '@/src/components/evidence/LearnerEvidenceSubmission';

type View = 'browse' | 'submit';

export default function LearnerPortfolioPage() {
  const [view, setView] = useState<View>('browse');

  return (
    <div className="space-y-4">
      <div className="flex gap-2 border-b border-app pb-2">
        <button
          type="button"
          onClick={() => setView('browse')}
          className={`px-3 py-1.5 text-sm font-medium rounded-t-md transition-colors ${
            view === 'browse'
              ? 'bg-app-surface text-app-foreground border border-b-0 border-app'
              : 'text-app-muted hover:text-app-foreground'
          }`}
        >
          My Portfolio
        </button>
        <button
          type="button"
          onClick={() => setView('submit')}
          className={`px-3 py-1.5 text-sm font-medium rounded-t-md transition-colors ${
            view === 'submit'
              ? 'bg-app-surface text-app-foreground border border-b-0 border-app'
              : 'text-app-muted hover:text-app-foreground'
          }`}
        >
          Submit Evidence
        </button>
      </div>
      {view === 'browse' ? <LearnerPortfolioBrowser /> : <LearnerEvidenceSubmission />}
    </div>
  );
}
