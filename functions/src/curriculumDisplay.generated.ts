// GENERATED FILE. Do not edit directly.
// Source: config/curriculum_display.json

export type SupportedCurriculumDisplayLocale = 'en' | 'zh-CN' | 'zh-TW' | 'es' | 'th';
export type CurriculumLegacyFamilyCode = 'FUTURE_SKILLS' | 'LEADERSHIP_AGENCY' | 'IMPACT_INNOVATION';

export const CURRICULUM_DISPLAY_LOCALES = ['en','zh-CN','zh-TW','es','th'] as const;
export const CURRICULUM_LEGACY_FAMILIES = [
  {
    'code': 'FUTURE_SKILLS',
    'storageLabels': [
      'Future Skills',
      'futureSkills',
      'future_skills',
      'future skills',
      'FS',
      'future'
    ],
    'display': {
      'en': 'Think, Make & Navigate AI',
      'zh-CN': '思考、创作与驾驭 AI',
      'zh-TW': '思考、創作與駕馭 AI',
      'es': 'Pensar, crear y navegar la IA',
      'th': 'คิด สร้าง และใช้ AI อย่างรู้เท่าทัน'
    }
  },
  {
    'code': 'LEADERSHIP_AGENCY',
    'storageLabels': [
      'Leadership & Agency',
      'Leadership',
      'leadership',
      'leadership_agency',
      'leadership agency',
      'LEAD'
    ],
    'display': {
      'en': 'Communicate & Lead',
      'zh-CN': '沟通与领导',
      'zh-TW': '溝通與領導',
      'es': 'Comunicar y liderar',
      'th': 'สื่อสารและนำ'
    }
  },
  {
    'code': 'IMPACT_INNOVATION',
    'storageLabels': [
      'Impact & Innovation',
      'Impact',
      'impact',
      'impact_innovation',
      'impact innovation',
      'IMP'
    ],
    'display': {
      'en': 'Build for the World',
      'zh-CN': '为世界而建',
      'zh-TW': '為世界而建',
      'es': 'Construir para el mundo',
      'th': 'สร้างเพื่อโลก'
    }
  }
] as const;
export const CURRICULUM_COPY_ALIASES = [
  {
    'aliases': [
      'Learning Pillars',
      'My Pillars'
    ],
    'display': {
      'en': 'Legacy Curriculum Families',
      'zh-CN': '旧版课程家族',
      'zh-TW': '舊版課程家族',
      'es': 'Familias curriculares heredadas',
      'th': 'กลุ่มหลักสูตรเดิม'
    }
  },
  {
    'aliases': [
      'Pillar Progress'
    ],
    'display': {
      'en': 'Legacy Family Progress',
      'zh-CN': '旧版家族进展',
      'zh-TW': '舊版家族進展',
      'es': 'Progreso por familia heredada',
      'th': 'ความก้าวหน้าตามกลุ่มเดิม'
    }
  },
  {
    'aliases': [
      'Pillar',
      'pillar'
    ],
    'display': {
      'en': 'Legacy family',
      'zh-CN': '旧版家族',
      'zh-TW': '舊版家族',
      'es': 'Familia heredada',
      'th': 'กลุ่มเดิม'
    }
  },
  {
    'aliases': [
      'Pillar Performance'
    ],
    'display': {
      'en': 'Legacy Family Performance',
      'zh-CN': '旧版家族表现',
      'zh-TW': '舊版家族表現',
      'es': 'Rendimiento por familia heredada',
      'th': 'ผลการดำเนินงานตามกลุ่มเดิม'
    }
  },
  {
    'aliases': [
      'Pillar Progress (Site Average)'
    ],
    'display': {
      'en': 'Legacy Family Progress (Site Average)',
      'zh-CN': '旧版家族进展（站点平均）',
      'zh-TW': '舊版家族進展（站點平均）',
      'es': 'Progreso por familia heredada (promedio del sitio)',
      'th': 'ความก้าวหน้าตามกลุ่มเดิม (ค่าเฉลี่ยของไซต์)'
    }
  },
  {
    'aliases': [
      'No pillar data available'
    ],
    'display': {
      'en': 'No legacy family data available',
      'zh-CN': '暂无旧版家族数据',
      'zh-TW': '暫無舊版家族資料',
      'es': 'No hay datos de familias heredadas disponibles',
      'th': 'ยังไม่มีข้อมูลกลุ่มเดิม'
    }
  },
  {
    'aliases': [
      'Pillar progress telemetry is not available for this site yet.'
    ],
    'display': {
      'en': 'Legacy family progress telemetry is not available for this site yet.',
      'zh-CN': '该站点的旧版家族进展遥测数据尚不可用。',
      'zh-TW': '該站點的舊版家族進展遙測資料尚不可用。',
      'es': 'La telemetría del progreso por familia heredada aún no está disponible para este sitio.',
      'th': 'ข้อมูลเทเลเมทรีความก้าวหน้าตามกลุ่มเดิมสำหรับไซต์นี้ยังไม่พร้อมใช้งาน'
    }
  },
  {
    'aliases': [
      'All pillars',
      'All Pillars'
    ],
    'display': {
      'en': 'All legacy families',
      'zh-CN': '所有旧版家族',
      'zh-TW': '所有舊版家族',
      'es': 'Todas las familias heredadas',
      'th': 'ทุกกลุ่มเดิม'
    }
  },
  {
    'aliases': [
      'Build a confident weekly shipping rhythm across Future Skills missions.'
    ],
    'display': {
      'en': 'Build a confident weekly shipping rhythm across Think, Make & Navigate AI missions.',
      'zh-CN': '在“思考、创作与驾驭 AI”任务中建立稳定的每周交付节奏。',
      'zh-TW': '在「思考、創作與駕馭 AI」任務中建立穩定的每週交付節奏。',
      'es': 'Construye un ritmo semanal de entrega constante en las misiones de pensar, crear y navegar la IA.',
      'th': 'สร้างจังหวะการส่งงานรายสัปดาห์ที่มั่นคงในภารกิจด้านการคิด การสร้าง และการใช้ AI อย่างรู้เท่าทัน'
    }
  }
] as const;

const DEFAULT_LOCALE: SupportedCurriculumDisplayLocale = 'en';

function normalizeToken(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/&/g, ' and ')
    .replace(/[_-]+/g, ' ')
    .replace(/\s+/g, ' ');
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
