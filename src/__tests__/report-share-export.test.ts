import { shareTextWithFallback } from '@/src/lib/reports/shareExport';

describe('report share/export helpers', () => {
  const originalNavigator = Object.getOwnPropertyDescriptor(globalThis, 'navigator');

  afterEach(() => {
    if (originalNavigator) {
      Object.defineProperty(globalThis, 'navigator', originalNavigator);
    } else {
      Reflect.deleteProperty(globalThis, 'navigator');
    }
  });

  it('uses native share when available', async () => {
    const share = jest.fn().mockResolvedValue(undefined);
    Object.defineProperty(globalThis, 'navigator', {
      configurable: true,
      value: { share },
    });

    await expect(shareTextWithFallback({ title: 'Family summary', text: 'Evidence-backed' }))
      .resolves.toBe('shared');
    expect(share).toHaveBeenCalledWith({ title: 'Family summary', text: 'Evidence-backed' });
  });

  it('falls back to clipboard when native share is unavailable', async () => {
    const writeText = jest.fn().mockResolvedValue(undefined);
    Object.defineProperty(globalThis, 'navigator', {
      configurable: true,
      value: { clipboard: { writeText } },
    });

    await expect(shareTextWithFallback({ title: 'Family summary', text: 'Evidence-backed' }))
      .resolves.toBe('copied');
    expect(writeText).toHaveBeenCalledWith('Evidence-backed');
  });

  it('returns unavailable when no browser share channel exists', async () => {
    Reflect.deleteProperty(globalThis, 'navigator');

    await expect(shareTextWithFallback({ title: 'Family summary', text: 'Evidence-backed' }))
      .resolves.toBe('unavailable');
  });
});