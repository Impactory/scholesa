'use client';

import { useEffect, useRef } from 'react';
import { X } from 'lucide-react';

type ProofFlowModalProps = {
  open: boolean;
  onClose: () => void;
};

export function ProofFlowModal({ open, onClose }: ProofFlowModalProps) {
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const closeButtonRef = useRef<HTMLButtonElement | null>(null);
  const previouslyFocusedRef = useRef<HTMLElement | null>(null);

  useEffect(() => {
    if (!open) return;

    previouslyFocusedRef.current = document.activeElement as HTMLElement | null;
    closeButtonRef.current?.focus();
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';

    const handleKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        event.stopPropagation();
        onClose();
      }
    };
    window.addEventListener('keydown', handleKey);

    return () => {
      window.removeEventListener('keydown', handleKey);
      document.body.style.overflow = previousOverflow;
      const video = videoRef.current;
      if (video) {
        video.pause();
        video.currentTime = 0;
      }
      previouslyFocusedRef.current?.focus?.();
    };
  }, [open, onClose]);

  if (!open) return null;

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/80 px-4 py-8 backdrop-blur-sm"
      role="dialog"
      aria-modal="true"
      aria-labelledby="proof-flow-modal-title"
      onClick={(event) => {
        if (event.target === event.currentTarget) onClose();
      }}
    >
      <div className="relative w-full max-w-5xl overflow-hidden rounded-xl border border-slate-800 bg-slate-900 shadow-2xl">
        <div className="flex items-center justify-between gap-4 border-b border-slate-800 bg-slate-900 px-5 py-3">
          <div>
            <p id="proof-flow-modal-title" className="text-base font-bold text-white">
              The Proof Flow
            </p>
            <p className="text-xs text-slate-400">How a classroom moment becomes inspectable evidence.</p>
          </div>
          <button
            ref={closeButtonRef}
            type="button"
            onClick={onClose}
            className="inline-flex h-9 w-9 items-center justify-center rounded-md border border-slate-700 bg-slate-800 text-slate-200 hover:bg-slate-700 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-cyan-400"
            aria-label="Close Proof Flow video"
          >
            <X className="h-4 w-4" aria-hidden="true" />
          </button>
        </div>
        <div className="aspect-video bg-black">
          <video
            ref={videoRef}
            className="h-full w-full"
            src="/videos/proof-flow.mp4"
            poster="/videos/proof-flow-poster.jpg"
            controls
            autoPlay
            playsInline
            preload="metadata"
          >
            <track kind="captions" />
          </video>
        </div>
      </div>
    </div>
  );
}
