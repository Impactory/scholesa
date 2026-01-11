import 'server-only';
import { promises as fs } from 'fs';
import path from 'path';

// Cache translations per locale
const translationsCache: Record<string, any> = {};

async function loadTranslations(locale: string): Promise<any> {
  if (!translationsCache[locale]) {
    const data = await fs.readFile(path.join(process.cwd(), `locales/${locale}.json`), 'utf8');
    translationsCache[locale] = JSON.parse(data);
  }
  return translationsCache[locale];
}

export const getTranslations = async (locale: string, namespace: string) => {
  const translationsForLocale: any = await loadTranslations(locale);
  
  return {
    t: (key: string) => {
      return key
        .split('.')
        .reduce((obj: any, k: string) => (obj && typeof obj === 'object' ? obj[k] : undefined), translationsForLocale[namespace]);
    },
  };
};
