// GENERATED FILE. Do not edit directly.
// Source: config/curriculum_display.json

enum CurriculumLegacyFamilyCode {
  future_skills,
  leadership_agency,
  impact_innovation,
}

class CurriculumDisplay {
  CurriculumDisplay._();

  static const List<String> supportedLocales = <String>['en', 'zh-CN', 'zh-TW', 'es', 'th'];

  static const List<Map<String, Object>> legacyFamilies = [
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
  ];
  static const List<Map<String, Object>> copyAliases = [
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
  ];

  static String _normalizeToken(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('&', ' and ')
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
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
