import 'server-only';
import { promises as fs } from 'fs';
import path from 'path';

const translationsCache = {};

async function loadTranslations(locale) {
  if (!translationsCache[locale]) {
    const data = await fs.readFile(path.join(process.cwd(), `locales/${locale}.json`), 'utf8');
    translationsCache[locale] = JSON.parse(data);
  }
  return translationsCache[locale];
}

export const getTranslations = async (locale: string, namespace: string) => {
  const translationsForLocale = await loadTranslations(locale);
  
  return {
    t: (key: string) => {
      return key.split('.').reduce((obj, key) => obj && obj[key], translationsForLocale[namespace]);
    },
  };
};
