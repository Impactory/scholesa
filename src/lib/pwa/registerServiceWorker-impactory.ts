// Minimal service worker registration helper
export function registerServiceWorker(): void {
  if (typeof window === 'undefined') return;
  if (!('serviceWorker' in navigator)) return;

  try {
    // If Workbox is injected/available, prefer its registration API
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const w = (window as any)?.workbox;
    if (w && typeof w.register === 'function') {
      w.register();
      return;
    }

    // Only register in production by default unless explicitly enabled
    const enable = (process.env.NEXT_PUBLIC_ENABLE_SW || 'false').toLowerCase() === 'true';
    const isProd = process.env.NODE_ENV === 'production';
    if (!isProd && !enable) return;

    if (!('serviceWorker' in navigator)) return;

    // Allow overriding SW path at build time
    const swPath = process.env.NEXT_PUBLIC_SW_PATH || '/sw.js';

    // Fallback to plain navigator registration
    navigator.serviceWorker
      .register(swPath)
      .catch(() => {
        // swallow registration errors to avoid breaking client render
      });
  } catch (err) {
    // silent catch
  }
}

export default registerServiceWorker;
