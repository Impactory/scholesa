import enMessages from '@/locales/en.json';
import zhCNMessages from '@/locales/zh-CN.json';
import zhTWMessages from '@/locales/zh-TW.json';
import thMessages from '@/locales/th.json';
import sharedEnMessages from '@/packages/i18n/locales/en.json';
import sharedZhCNMessages from '@/packages/i18n/locales/zh-CN.json';
import sharedZhTWMessages from '@/packages/i18n/locales/zh-TW.json';
import sharedThMessages from '@/packages/i18n/locales/th.json';
import { getFallbackChain, type SupportedLocale } from './config';

type MessageDictionary = Record<string, unknown>;

type TranslationParams = Record<string, string | number>;

function isMessageDictionary(value: unknown): value is MessageDictionary {
  return !!value && typeof value === 'object' && !Array.isArray(value);
}

function mergeMessageDictionaries(
  baseMessages: MessageDictionary,
  overrideMessages: MessageDictionary,
): MessageDictionary {
  const mergedMessages: MessageDictionary = { ...baseMessages };

  for (const [key, overrideValue] of Object.entries(overrideMessages)) {
    const baseValue = mergedMessages[key];
    if (isMessageDictionary(baseValue) && isMessageDictionary(overrideValue)) {
      mergedMessages[key] = mergeMessageDictionaries(baseValue, overrideValue);
      continue;
    }
    mergedMessages[key] = overrideValue;
  }

  return mergedMessages;
}

const CATALOGS: Record<SupportedLocale, MessageDictionary> = {
  en: mergeMessageDictionaries(
    sharedEnMessages as MessageDictionary,
    enMessages as MessageDictionary,
  ),
  'zh-CN': mergeMessageDictionaries(
    sharedZhCNMessages as MessageDictionary,
    zhCNMessages as MessageDictionary,
  ),
  'zh-TW': mergeMessageDictionaries(
    sharedZhTWMessages as MessageDictionary,
    zhTWMessages as MessageDictionary,
  ),
  th: mergeMessageDictionaries(
    sharedThMessages as MessageDictionary,
    thMessages as MessageDictionary,
  ),
};

function getMessageByPath(messages: MessageDictionary, key: string): unknown {
  return key.split('.').reduce<unknown>((acc, segment) => {
    if (!acc || typeof acc !== 'object') return undefined;
    return (acc as MessageDictionary)[segment];
  }, messages);
}

function formatTemplate(template: string, params?: TranslationParams): string {
  if (!params) return template;
  return template.replace(/\{\{\s*([\w.-]+)\s*\}\}/g, (_, token: string) => {
    const value = params[token];
    return value === undefined ? '' : String(value);
  });
}

function warnMissingKey(locale: SupportedLocale, key: string): void {
  const payload = {
    type: 'i18n.missing_key',
    locale,
    key,
    fallbackLocale: 'en',
    timestamp: new Date().toISOString(),
  };
  // Structured warning for test telemetry and CI traces.
  console.warn(JSON.stringify(payload));
}

export function translate(
  locale: SupportedLocale,
  key: string,
  params?: TranslationParams,
): string {
  const fallbackChain = getFallbackChain(locale);
  for (const candidate of fallbackChain) {
    const value = getMessageByPath(CATALOGS[candidate], key);
    if (typeof value === 'string') {
      return formatTemplate(value, params);
    }
  }

  warnMissingKey(locale, key);
  return key;
}

export function getCatalog(locale: SupportedLocale): MessageDictionary {
  return CATALOGS[locale];
}

export function flattenMessageKeys(messages: MessageDictionary, prefix = ''): string[] {
  const keys: string[] = [];
  for (const [key, value] of Object.entries(messages)) {
    const nextKey = prefix ? `${prefix}.${key}` : key;
    if (value && typeof value === 'object' && !Array.isArray(value)) {
      keys.push(...flattenMessageKeys(value as MessageDictionary, nextKey));
      continue;
    }
    keys.push(nextKey);
  }
  return keys.sort((a, b) => a.localeCompare(b));
}
