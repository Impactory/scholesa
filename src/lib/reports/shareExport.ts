export type BrowserShareStatus = 'shared' | 'copied' | 'unavailable' | 'aborted';

export async function shareTextWithFallback({
  title,
  text,
}: {
  title: string;
  text: string;
}): Promise<BrowserShareStatus> {
  try {
    if (typeof navigator !== 'undefined' && typeof navigator.share === 'function') {
      await navigator.share({ title, text });
      return 'shared';
    }

    if (typeof navigator !== 'undefined' && navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(text);
      return 'copied';
    }

    return 'unavailable';
  } catch (err) {
    if (typeof DOMException !== 'undefined' && err instanceof DOMException && err.name === 'AbortError') {
      return 'aborted';
    }

    return 'unavailable';
  }
}

export function downloadTextReport({
  fileName,
  lines,
}: {
  fileName: string;
  lines: string[];
}): boolean {
  if (typeof document === 'undefined' || typeof URL === 'undefined') {
    return false;
  }

  const blob = new Blob([lines.join('\n')], { type: 'text/plain' });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement('a');
  anchor.href = url;
  anchor.download = fileName;
  anchor.style.display = 'none';

  try {
    document.body?.appendChild(anchor);
    anchor.click();
    anchor.remove();
  } finally {
    URL.revokeObjectURL(url);
  }

  return true;
}