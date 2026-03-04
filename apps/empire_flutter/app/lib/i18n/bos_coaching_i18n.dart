/// Centralized i18n keys for BOS/MIA coaching surfaces.
/// Shared by all educator and parent pages to ensure consistency.
///
/// **Usage**:
/// ```dart
/// import 'package:scholesa/i18n/bos_coaching_i18n.dart';
/// 
/// final title = BosCoachingI18n.sessionLoopTitle(context);
/// ```

import 'package:flutter/material.dart';

/// BOS/MIA coaching internationalization keys
class BosCoachingI18n {
  static const Map<String, String> _esTranslations = <String, String>{
    'sessionLoopTitle': 'Ciclo de sesión BOS/MIA',
    'sessionLoopSubtitle': 'Señal de mejora individual más reciente para esta sesión',
    'sessionLoopEmpty': 'Sin datos de ciclo de sesión aún',
    'familyLearningTitle': 'Ciclo de aprendizaje familiar',
    'familyLearningSubtitle': 'Disponibilidad de aprendizaje de tu hijo y señales de mejora',
    'familyLearningEmpty': 'Sin datos de aprendizaje familiar aún',
    'familyScheduleTitle': 'Ciclo de horario familiar',
    'familyScheduleSubtitle': 'Disponibilidad de aprendizaje de tu hijo y señales de asistencia',
    'familyScheduleEmpty': 'Sin datos de aprendizaje de horario aún',
    'familyBillingTitle': 'Ciclo de facturación familiar',
    'familyBillingSubtitle': 'Métricas de compromiso de aprendizaje y progreso',
    'familyBillingEmpty': 'Sin datos de ciclo de facturación aún',
    'cognition': 'Cognición',
    'engagement': 'Participación',
    'integrity': 'Integridad',
    'improvementScore': 'Puntuación de mejora',
    'activeGoals': 'Objetivos de aprendizaje activos',
    'mvlStatus': 'Validación de dominio',
    'mvlActive': 'En progreso',
    'mvlPassed': 'Aprobado',
    'mvlFailed': 'Desafiado',
    'loadingInsights': 'Cargando información de aprendizaje...',
    'errorLoadingInsights': 'No se puede cargar información; intenta más tarde',
    'latestSignal': 'Señal más reciente',
  };

  static const Map<String, String> _enTranslations = <String, String>{
    'sessionLoopTitle': 'BOS/MIA Session Loop',
    'sessionLoopSubtitle': 'Latest individual improvement signal for this session',
    'sessionLoopEmpty': 'No session loop data yet',
    'familyLearningTitle': 'Family Learning Loop',
    'familyLearningSubtitle': 'Your child\'s learning readiness and improvement signals',
    'familyLearningEmpty': 'No family learning data yet',
    'familyScheduleTitle': 'Family Schedule Loop',
    'familyScheduleSubtitle': 'Your child\'s learning readiness and attendance signals',
    'familyScheduleEmpty': 'No schedule learning data yet',
    'familyBillingTitle': 'Family Billing Loop',
    'familyBillingSubtitle': 'Learning engagement and progress metrics',
    'familyBillingEmpty': 'No billing loop data yet',
    'cognition': 'Cognition',
    'engagement': 'Engagement',
    'integrity': 'Integrity',
    'improvementScore': 'Improvement Score',
    'activeGoals': 'Active Learning Goals',
    'mvlStatus': 'Mastery Validation',
    'mvlActive': 'In Progress',
    'mvlPassed': 'Passed',
    'mvlFailed': 'Challenged',
    'loadingInsights': 'Loading learning insights...',
    'errorLoadingInsights': 'Unable to load insights; try again later',
    'latestSignal': 'Latest Signal',
  };

  /// Get a BOS/MIA coaching key in the user's locale
  /// Returns English default if locale not supported
  static String get(BuildContext context, String key) {
    final String locale = Localizations.localeOf(context).languageCode;
    if (locale == 'es') {
      return _esTranslations[key] ?? _enTranslations[key] ?? key;
    }
    return _enTranslations[key] ?? key;
  }

  // Convenience getters for commonly used keys
  static String sessionLoopTitle(BuildContext context) => get(context, 'sessionLoopTitle');
  static String sessionLoopSubtitle(BuildContext context) => get(context, 'sessionLoopSubtitle');
  static String sessionLoopEmpty(BuildContext context) => get(context, 'sessionLoopEmpty');
  static String familyLearningTitle(BuildContext context) => get(context, 'familyLearningTitle');
  static String familyLearningSubtitle(BuildContext context) => get(context, 'familyLearningSubtitle');
  static String familyLearningEmpty(BuildContext context) => get(context, 'familyLearningEmpty');
  static String familyScheduleTitle(BuildContext context) => get(context, 'familyScheduleTitle');
  static String familyScheduleSubtitle(BuildContext context) => get(context, 'familyScheduleSubtitle');
  static String familyScheduleEmpty(BuildContext context) => get(context, 'familyScheduleEmpty');
  static String familyBillingTitle(BuildContext context) => get(context, 'familyBillingTitle');
  static String familyBillingSubtitle(BuildContext context) => get(context, 'familyBillingSubtitle');
  static String familyBillingEmpty(BuildContext context) => get(context, 'familyBillingEmpty');
  static String cognition(BuildContext context) => get(context, 'cognition');
  static String engagement(BuildContext context) => get(context, 'engagement');
  static String integrity(BuildContext context) => get(context, 'integrity');
  static String improvementScore(BuildContext context) => get(context, 'improvementScore');
  static String activeGoals(BuildContext context) => get(context, 'activeGoals');
  static String mvlStatus(BuildContext context) => get(context, 'mvlStatus');
  static String mvlActive(BuildContext context) => get(context, 'mvlActive');
  static String mvlPassed(BuildContext context) => get(context, 'mvlPassed');
  static String mvlFailed(BuildContext context) => get(context, 'mvlFailed');
  static String loadingInsights(BuildContext context) => get(context, 'loadingInsights');
  static String errorLoadingInsights(BuildContext context) => get(context, 'errorLoadingInsights');
  static String latestSignal(BuildContext context) => get(context, 'latestSignal');
}
