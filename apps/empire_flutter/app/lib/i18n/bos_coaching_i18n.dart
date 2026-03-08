import 'package:flutter/material.dart';

/// BOS/MIA coaching internationalization keys
/// 
/// Centralized i18n keys for BOS/MIA coaching surfaces.
/// Shared by all educator and parent pages to ensure consistency.
///
/// **Usage**:
/// ```dart
/// import 'package:scholesa/i18n/bos_coaching_i18n.dart';
/// 
/// final title = BosCoachingI18n.sessionLoopTitle(context);
/// ```
class BosCoachingI18n {
  static const Map<String, String> _zhCnTranslations = <String, String>{
    'sessionLoopTitle': 'BOS/MIA 课堂循环',
    'sessionLoopSubtitle': '本次课堂最新的个人成长信号',
    'sessionLoopEmpty': '暂无课堂循环数据',
    'familyLearningTitle': '家庭学习循环',
    'familyLearningSubtitle': '你孩子的学习准备度与成长信号',
    'familyLearningEmpty': '暂无家庭学习数据',
    'familyScheduleTitle': '家庭日程循环',
    'familyScheduleSubtitle': '你孩子的学习准备度与出勤信号',
    'familyScheduleEmpty': '暂无日程学习数据',
    'familyBillingTitle': '家庭账单循环',
    'familyBillingSubtitle': '学习投入度与进展指标',
    'familyBillingEmpty': '暂无账单循环数据',
    'cognition': '认知',
    'engagement': '投入度',
    'integrity': '完整性',
    'improvementScore': '提升分数',
    'activeGoals': '当前学习目标',
    'mvlStatus': '掌握度验证',
    'mvlActive': '进行中',
    'mvlPassed': '已通过',
    'mvlFailed': '需加强',
    'loadingInsights': '正在加载学习洞察...',
    'errorLoadingInsights': '无法加载学习洞察，请稍后重试',
    'latestSignal': '最新信号',
  };

  static const Map<String, String> _zhTwTranslations = <String, String>{
    'sessionLoopTitle': 'BOS/MIA 課堂循環',
    'sessionLoopSubtitle': '本次課堂最新的個人成長訊號',
    'sessionLoopEmpty': '目前沒有課堂循環資料',
    'familyLearningTitle': '家庭學習循環',
    'familyLearningSubtitle': '你孩子的學習準備度與成長訊號',
    'familyLearningEmpty': '目前沒有家庭學習資料',
    'familyScheduleTitle': '家庭日程循環',
    'familyScheduleSubtitle': '你孩子的學習準備度與出勤訊號',
    'familyScheduleEmpty': '目前沒有日程學習資料',
    'familyBillingTitle': '家庭帳單循環',
    'familyBillingSubtitle': '學習投入度與進展指標',
    'familyBillingEmpty': '目前沒有帳單循環資料',
    'cognition': '認知',
    'engagement': '投入度',
    'integrity': '完整性',
    'improvementScore': '提升分數',
    'activeGoals': '目前學習目標',
    'mvlStatus': '掌握度驗證',
    'mvlActive': '進行中',
    'mvlPassed': '已通過',
    'mvlFailed': '需加強',
    'loadingInsights': '正在載入學習洞察...',
    'errorLoadingInsights': '無法載入學習洞察，請稍後再試',
    'latestSignal': '最新訊號',
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
    final Locale locale = Localizations.localeOf(context);
    final String countryCode = (locale.countryCode ?? '').toUpperCase();
    if (locale.languageCode == 'zh') {
      if (countryCode == 'TW' || countryCode == 'HK' || countryCode == 'MO') {
        return _zhTwTranslations[key] ??
            _zhCnTranslations[key] ??
            _enTranslations[key] ??
            key;
      }
      return _zhCnTranslations[key] ??
          _zhTwTranslations[key] ??
          _enTranslations[key] ??
          key;
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
