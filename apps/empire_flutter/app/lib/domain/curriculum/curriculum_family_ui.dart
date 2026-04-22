import 'package:flutter/material.dart';

import '../../ui/localization/inline_locale_text.dart';
import '../../ui/theme/scholesa_theme.dart';
import 'curriculum_display.g.dart';
export 'curriculum_display.g.dart' show CurriculumLegacyFamilyCode;

CurriculumLegacyFamilyCode? maybeCurriculumLegacyFamilyCode(String? value) {
  return CurriculumDisplay.legacyFamilyCodeFromAny(value);
}

CurriculumLegacyFamilyCode normalizeCurriculumLegacyFamilyCode(String? value) {
  return maybeCurriculumLegacyFamilyCode(value) ??
      CurriculumLegacyFamilyCode.future_skills;
}

String curriculumLegacyFamilyStorageLabel(CurriculumLegacyFamilyCode code) {
  return CurriculumDisplay.legacyFamilyStorageLabel(code);
}

String curriculumLegacyFamilyStorageLabelFromAny(String? value) {
  return curriculumLegacyFamilyStorageLabel(
    normalizeCurriculumLegacyFamilyCode(value),
  );
}

String curriculumLegacyFamilyDisplayLabel(
  BuildContext context,
  CurriculumLegacyFamilyCode code,
) {
  final String locale =
      InlineLocaleText.canonicalLocale(Localizations.localeOf(context));
  return CurriculumDisplay.legacyFamilyLabel(code, locale: locale);
}

String curriculumLegacyFamilyDisplayLabelFromAny(
  BuildContext context,
  String? value,
) {
  return curriculumLegacyFamilyDisplayLabel(
    context,
    normalizeCurriculumLegacyFamilyCode(value),
  );
}

String curriculumLegacyFamilyMissionCode(CurriculumLegacyFamilyCode code) {
  switch (code) {
    case CurriculumLegacyFamilyCode.leadership_agency:
      return 'leadership';
    case CurriculumLegacyFamilyCode.impact_innovation:
      return 'impact';
    case CurriculumLegacyFamilyCode.future_skills:
      return 'future_skills';
  }
}

String curriculumLegacyFamilySessionCode(CurriculumLegacyFamilyCode code) {
  switch (code) {
    case CurriculumLegacyFamilyCode.leadership_agency:
      return 'leadership_agency';
    case CurriculumLegacyFamilyCode.impact_innovation:
      return 'impact_innovation';
    case CurriculumLegacyFamilyCode.future_skills:
      return 'future_skills';
  }
}

String curriculumLegacyFamilySchemaCode(CurriculumLegacyFamilyCode code) {
  switch (code) {
    case CurriculumLegacyFamilyCode.leadership_agency:
      return 'leadership';
    case CurriculumLegacyFamilyCode.impact_innovation:
      return 'impact';
    case CurriculumLegacyFamilyCode.future_skills:
      return 'futureSkills';
  }
}

String curriculumLegacyFamilyShortCode(CurriculumLegacyFamilyCode code) {
  switch (code) {
    case CurriculumLegacyFamilyCode.leadership_agency:
      return 'LEAD';
    case CurriculumLegacyFamilyCode.impact_innovation:
      return 'IMP';
    case CurriculumLegacyFamilyCode.future_skills:
      return 'FS';
  }
}

Color curriculumLegacyFamilyColor(CurriculumLegacyFamilyCode code) {
  switch (code) {
    case CurriculumLegacyFamilyCode.leadership_agency:
      return ScholesaColors.leadership;
    case CurriculumLegacyFamilyCode.impact_innovation:
      return ScholesaColors.impact;
    case CurriculumLegacyFamilyCode.future_skills:
      return ScholesaColors.futureSkills;
  }
}

IconData curriculumLegacyFamilyIcon(CurriculumLegacyFamilyCode code) {
  switch (code) {
    case CurriculumLegacyFamilyCode.leadership_agency:
      return Icons.groups_rounded;
    case CurriculumLegacyFamilyCode.impact_innovation:
      return Icons.public_rounded;
    case CurriculumLegacyFamilyCode.future_skills:
      return Icons.psychology_rounded;
  }
}
