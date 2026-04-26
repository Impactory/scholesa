import fs from 'node:fs/promises';
import path from 'node:path';

const repoRoot = path.resolve(new URL('.', import.meta.url).pathname, '..');
const sourcePath = path.join(repoRoot, 'config', 'curriculum_display.json');
const tsOutputPath = path.join(repoRoot, 'src', 'lib', 'curriculum', 'curriculumDisplay.generated.ts');
const functionsOutputPath = path.join(repoRoot, 'functions', 'src', 'curriculumDisplay.generated.ts');
const dartOutputPath = path.join(
  repoRoot,
  'apps',
  'empire_flutter',
  'app',
  'lib',
  'domain',
  'curriculum',
  'curriculum_display.g.dart',
);

const raw = await fs.readFile(sourcePath, 'utf8');
const source = JSON.parse(raw);

const locales = source.locales;
const legacyFamilies = source.legacyFamilies;
const copyAliases = source.copyAliases;

function escapeDartString(value) {
  return `'${String(value)
    .replace(/\\/g, '\\\\')
    .replace(/'/g, "\\'")
    .replace(/\$/g, '\\$')
    .replace(/\n/g, '\\n')}'`;
}

function toDart(value, indent = 0) {
  const spacing = ' '.repeat(indent);
  if (Array.isArray(value)) {
    if (value.length === 0) return '<Object>[]';
    const items = value.map((entry) => `${' '.repeat(indent + 2)}${toDart(entry, indent + 2)}`);
    return `[\n${items.join(',\n')}\n${spacing}]`;
  }
  if (value && typeof value === 'object') {
    const entries = Object.entries(value);
    if (entries.length === 0) return '<String, Object>{}';
    const items = entries.map(
      ([key, entry]) => `${' '.repeat(indent + 2)}${escapeDartString(key)}: ${toDart(entry, indent + 2)}`,
    );
    return `{\n${items.join(',\n')}\n${spacing}}`;
  }
  if (typeof value === 'string') return escapeDartString(value);
  if (typeof value === 'number' || typeof value === 'boolean') return String(value);
  if (value === null) return 'null';
  throw new Error(`Unsupported value for Dart generation: ${JSON.stringify(value)}`);
}

function buildTsModule() {
  return `// GENERATED FILE. Do not edit directly.
// Source: config/curriculum_display.json
/* eslint-disable quotes */

export type SupportedCurriculumDisplayLocale = ${locales.map((locale) => JSON.stringify(locale)).join(' | ')};
export type CurriculumLegacyFamilyCode = ${legacyFamilies.map((entry) => JSON.stringify(entry.code)).join(' | ')};

export const CURRICULUM_DISPLAY_LOCALES = ${JSON.stringify(locales)} as const;
export const CURRICULUM_LEGACY_FAMILIES = ${JSON.stringify(legacyFamilies, null, 2)} as const;
export const CURRICULUM_COPY_ALIASES = ${JSON.stringify(copyAliases, null, 2)} as const;

const DEFAULT_LOCALE: SupportedCurriculumDisplayLocale = 'en';

function normalizeToken(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/&/g, ' and ')
    .replace(/[_-]+/g, ' ')
    .replace(/\\s+/g, ' ');
}

const legacyFamilyAliasIndex = new Map<string, CurriculumLegacyFamilyCode>();

for (const family of CURRICULUM_LEGACY_FAMILIES) {
  legacyFamilyAliasIndex.set(normalizeToken(family.code), family.code);
  for (const label of family.storageLabels) {
    legacyFamilyAliasIndex.set(normalizeToken(label), family.code);
  }
}

function getLocaleLabel(
  display: Record<SupportedCurriculumDisplayLocale, string>,
  locale: SupportedCurriculumDisplayLocale,
): string {
  return display[locale] ?? display[DEFAULT_LOCALE];
}

export function normalizeLegacyFamilyCode(value: unknown): CurriculumLegacyFamilyCode | null {
  if (typeof value !== 'string' || value.trim().length === 0) {
    return null;
  }
  return legacyFamilyAliasIndex.get(normalizeToken(value)) ?? null;
}

export function getLegacyFamilyStorageLabel(code: CurriculumLegacyFamilyCode): string {
  const family = CURRICULUM_LEGACY_FAMILIES.find((entry) => entry.code === code);
  return family?.storageLabels[0] ?? code;
}

export function getLegacyFamilyDisplayLabel(
  code: CurriculumLegacyFamilyCode,
  locale: SupportedCurriculumDisplayLocale = DEFAULT_LOCALE,
): string {
  const family = CURRICULUM_LEGACY_FAMILIES.find((entry) => entry.code === code);
  return family ? getLocaleLabel(family.display, locale) : code;
}

export function getLegacyFamilyDisplayLabelFromAny(
  value: unknown,
  locale: SupportedCurriculumDisplayLocale = DEFAULT_LOCALE,
): string {
  const code = normalizeLegacyFamilyCode(value);
  if (!code) {
    return typeof value === 'string' && value.trim().length > 0 ? value.trim() : 'Unmapped legacy family';
  }
  return getLegacyFamilyDisplayLabel(code, locale);
}

export function localizeCurriculumDisplayText(
  input: string,
  locale: SupportedCurriculumDisplayLocale = DEFAULT_LOCALE,
  fallback?: string,
): string {
  const normalized = normalizeToken(input);
  for (const aliasEntry of CURRICULUM_COPY_ALIASES) {
    if (aliasEntry.aliases.some((alias) => normalizeToken(alias) === normalized)) {
      return getLocaleLabel(aliasEntry.display, locale);
    }
  }
  const familyCode = normalizeLegacyFamilyCode(input);
  if (familyCode) {
    return getLegacyFamilyDisplayLabel(familyCode, locale);
  }
  return fallback ?? input;
}
`;
}

function buildDartModule() {
  const localeUnion = locales.map((locale) => escapeDartString(locale)).join(', ');
  return `// GENERATED FILE. Do not edit directly.
// Source: config/curriculum_display.json
// ignore_for_file: constant_identifier_names

enum CurriculumLegacyFamilyCode {
  ${legacyFamilies.map((entry) => entry.code.toLowerCase()).join(',\n  ')},
}

class CurriculumDisplay {
  CurriculumDisplay._();

  static const List<String> supportedLocales = <String>[${localeUnion}];

  static const List<Map<String, Object>> legacyFamilies = ${toDart(legacyFamilies, 2)};
  static const List<Map<String, Object>> copyAliases = ${toDart(copyAliases, 2)};

  static String _normalizeToken(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('&', ' and ')
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'\\s+'), ' ');
  }

  static String _localeLabel(Map<String, String> display, String locale) {
    return display[locale] ?? display['en'] ?? '';
  }

  static CurriculumLegacyFamilyCode? legacyFamilyCodeFromAny(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final String normalized = _normalizeToken(value);
    for (final Map<String, Object> family in legacyFamilies) {
      final String code = family['code']! as String;
      if (_normalizeToken(code) == normalized) {
        return _familyCodeFromString(code);
      }
      final List<String> storageLabels =
          (family['storageLabels']! as List<Object>).cast<String>();
      for (final String label in storageLabels) {
        if (_normalizeToken(label) == normalized) {
          return _familyCodeFromString(code);
        }
      }
    }
    return null;
  }

  static String legacyFamilyStorageLabel(CurriculumLegacyFamilyCode code) {
    final Map<String, Object> family = _familyRecord(code);
    return (family['storageLabels']! as List<Object>).cast<String>().first;
  }

  static String legacyFamilyLabel(CurriculumLegacyFamilyCode code,
      {String locale = 'en'}) {
    final Map<String, Object> family = _familyRecord(code);
    final Map<String, String> display =
        (family['display']! as Map<Object?, Object?>).cast<String, String>();
    return _localeLabel(display, locale);
  }

  static String legacyFamilyLabelFromAny(String? value,
      {String locale = 'en'}) {
    final CurriculumLegacyFamilyCode? code = legacyFamilyCodeFromAny(value);
    if (code == null) {
      return value == null || value.trim().isEmpty
          ? 'Unmapped legacy family'
          : value.trim();
    }
    return legacyFamilyLabel(code, locale: locale);
  }

  static String localizeDisplayText(String input, String locale,
      {String? fallback}) {
    final String normalized = _normalizeToken(input);
    for (final Map<String, Object> aliasEntry in copyAliases) {
      final List<String> aliases =
          (aliasEntry['aliases']! as List<Object>).cast<String>();
      final bool matches = aliases.any(
        (String alias) => _normalizeToken(alias) == normalized,
      );
      if (!matches) {
        continue;
      }
      final Map<String, String> display =
          (aliasEntry['display']! as Map<Object?, Object?>).cast<String, String>();
      return _localeLabel(display, locale);
    }
    final CurriculumLegacyFamilyCode? familyCode = legacyFamilyCodeFromAny(input);
    if (familyCode != null) {
      return legacyFamilyLabel(familyCode, locale: locale);
    }
    return fallback ?? input;
  }

  static CurriculumLegacyFamilyCode _familyCodeFromString(String code) {
    switch (code) {
      case 'FUTURE_SKILLS':
        return CurriculumLegacyFamilyCode.future_skills;
      case 'LEADERSHIP_AGENCY':
        return CurriculumLegacyFamilyCode.leadership_agency;
      case 'IMPACT_INNOVATION':
        return CurriculumLegacyFamilyCode.impact_innovation;
      default:
        return CurriculumLegacyFamilyCode.future_skills;
    }
  }

  static Map<String, Object> _familyRecord(CurriculumLegacyFamilyCode code) {
    final String targetCode = switch (code) {
      CurriculumLegacyFamilyCode.future_skills => 'FUTURE_SKILLS',
      CurriculumLegacyFamilyCode.leadership_agency => 'LEADERSHIP_AGENCY',
      CurriculumLegacyFamilyCode.impact_innovation => 'IMPACT_INNOVATION',
    };
    return legacyFamilies.firstWhere(
      (Map<String, Object> family) => family['code'] == targetCode,
    );
  }
}
`;
}

const tsModule = buildTsModule();
const dartModule = buildDartModule();

await fs.mkdir(path.dirname(tsOutputPath), { recursive: true });
await fs.mkdir(path.dirname(functionsOutputPath), { recursive: true });
await fs.mkdir(path.dirname(dartOutputPath), { recursive: true });

await Promise.all([
  fs.writeFile(tsOutputPath, tsModule, 'utf8'),
  fs.writeFile(functionsOutputPath, tsModule, 'utf8'),
  fs.writeFile(dartOutputPath, dartModule, 'utf8'),
]);

console.log('Generated curriculum display helpers.');
