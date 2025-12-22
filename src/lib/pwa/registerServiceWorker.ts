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

    // Fallback to plain navigator registration
    navigator.serviceWorker
      .register('/sw.js')
      .catch(() => {
        // swallow errors during registration to avoid breaking client render
      });
  } catch (err) {
    // silent catch
  }
}

export default registerServiceWorker;
