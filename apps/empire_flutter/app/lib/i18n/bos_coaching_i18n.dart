import 'package:flutter/material.dart';

/// MiloOS coaching internationalization keys
///
/// Centralized i18n keys for MiloOS coaching surfaces.
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
    'learnerLoopTitle': 'MiloOS 学习循环',
    'learnerLoopSubtitle': '最新的个人成长信号',
    'learnerLoopEmpty': '暂无学习循环数据',
    'sessionLoopTitle': 'MiloOS 课堂循环',
    'sessionLoopSubtitle': '本次课堂最新的个人成长信号',
    'sessionLoopEmpty': '暂无课堂循环数据',
    'classInsightsTitle': 'MiloOS 课堂洞察',
    'classInsightsSubtitle': '本课堂的学习信号、需要支持的学习者与进行中的理解检查',
    'classInsightsEmpty': '暂无课堂洞察数据',
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
    'improvementScore': '成长趋势',
    'activeGoals': '当前学习目标',
    'mvlStatus': '掌握度验证',
    'mvlActive': '进行中',
    'mvlPassed': '已通过',
    'mvlFailed': '需加强',
    'loadingInsights': '正在加载学习洞察...',
    'errorLoadingInsights': '无法加载学习洞察，请稍后重试',
    'latestSignal': '最新更新',
    'fdmStateEstimate': '学习信号摘要',
    'baeWatchlist': '需要支持的学习者',
    'activeMvlGates': '进行中的理解检查',
    'learnersTracked': '已追踪学习者',
    'viewWatchlist': '查看支持名单',
    'watchlistClear': '目前没有需要立即跟进的学习者',
    'supportRecommended': '建议优先提供支持给以下学习者',
    'learnerUnavailable': '学习者信息不可用',
    'signalUnavailable': '暂无已验证学习信号',
    'partialSignals': '部分学习信号缺失，仅显示已验证信息',
    'syntheticPreview': '当前为 MiloOS 合成预览数据，请勿视为真实课堂证据或成长记录',
  };

  static const Map<String, String> _zhTwTranslations = <String, String>{
    'learnerLoopTitle': 'MiloOS 學習循環',
    'learnerLoopSubtitle': '最新的個人成長訊號',
    'learnerLoopEmpty': '目前沒有學習循環資料',
    'sessionLoopTitle': 'MiloOS 課堂循環',
    'sessionLoopSubtitle': '本次課堂最新的個人成長訊號',
    'sessionLoopEmpty': '目前沒有課堂循環資料',
    'classInsightsTitle': 'MiloOS 課堂洞察',
    'classInsightsSubtitle': '本課堂的學習訊號、需要支持的學習者與進行中的理解檢查',
    'classInsightsEmpty': '目前沒有課堂洞察資料',
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
    'improvementScore': '成長趨勢',
    'activeGoals': '目前學習目標',
    'mvlStatus': '掌握度驗證',
    'mvlActive': '進行中',
    'mvlPassed': '已通過',
    'mvlFailed': '需加強',
    'loadingInsights': '正在載入學習洞察...',
    'errorLoadingInsights': '無法載入學習洞察，請稍後再試',
    'latestSignal': '最新更新',
    'fdmStateEstimate': '學習訊號摘要',
    'baeWatchlist': '需要支持的學習者',
    'activeMvlGates': '進行中的理解檢查',
    'learnersTracked': '已追蹤學習者',
    'viewWatchlist': '查看支持名單',
    'watchlistClear': '目前沒有需要立即跟進的學習者',
    'supportRecommended': '建議優先提供支持給以下學習者',
    'learnerUnavailable': '學習者資訊不可用',
    'signalUnavailable': '目前沒有已驗證學習訊號',
    'partialSignals': '部分學習訊號缺失，僅顯示已驗證資訊',
    'syntheticPreview': '目前顯示的是 MiloOS 合成預覽資料，請勿視為真實課堂證據或成長紀錄',
  };

  static const Map<String, String> _enTranslations = <String, String>{
    'learnerLoopTitle': 'MiloOS Learning Loop',
    'learnerLoopSubtitle': 'Latest individual improvement signal',
    'learnerLoopEmpty': 'No learner loop data yet',
    'sessionLoopTitle': 'MiloOS Session Loop',
    'sessionLoopSubtitle':
        'Latest individual improvement signal for this session',
    'sessionLoopEmpty': 'No session loop data yet',
    'classInsightsTitle': 'MiloOS Class Insights',
    'classInsightsSubtitle':
        'Class learning signals, learners who may need support, and active understanding checks',
    'classInsightsEmpty': 'No class insights yet',
    'familyLearningTitle': 'Family Learning Loop',
    'familyLearningSubtitle':
        'Your child\'s learning readiness and improvement signals',
    'familyLearningEmpty': 'No family learning data yet',
    'familyScheduleTitle': 'Family Schedule Loop',
    'familyScheduleSubtitle':
        'Your child\'s learning readiness and attendance signals',
    'familyScheduleEmpty': 'No schedule learning data yet',
    'familyBillingTitle': 'Family Billing Loop',
    'familyBillingSubtitle': 'Learning engagement and progress metrics',
    'familyBillingEmpty': 'No billing loop data yet',
    'cognition': 'Cognition',
    'engagement': 'Engagement',
    'integrity': 'Integrity',
    'improvementScore': 'Growth Trend',
    'activeGoals': 'Active Learning Goals',
    'mvlStatus': 'Mastery Validation',
    'mvlActive': 'In Progress',
    'mvlPassed': 'Passed',
    'mvlFailed': 'Challenged',
    'loadingInsights': 'Loading learning insights...',
    'errorLoadingInsights': 'Unable to load insights; try again later',
    'latestSignal': 'Latest Update',
    'fdmStateEstimate': 'Learning Signal Summary',
    'baeWatchlist': 'Learners Who May Need Support',
    'activeMvlGates': 'Active Understanding Checks',
    'learnersTracked': 'Learners Tracked',
    'viewWatchlist': 'View Support List',
    'watchlistClear': 'No learners need immediate follow-up right now',
    'supportRecommended': 'Support recommended for these learners',
    'learnerUnavailable': 'Learner unavailable',
    'signalUnavailable': 'No verified learning signals yet',
    'partialSignals': 'Some learning signals are missing; showing only verified information',
    'syntheticPreview':
        'Synthetic MiloOS preview only. Do not treat this as classroom evidence or learner growth.',
  };

  /// Get a MiloOS coaching key in the user's locale
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
  static String learnerLoopTitle(BuildContext context) =>
      get(context, 'learnerLoopTitle');
  static String learnerLoopSubtitle(BuildContext context) =>
      get(context, 'learnerLoopSubtitle');
  static String learnerLoopEmpty(BuildContext context) =>
      get(context, 'learnerLoopEmpty');
  static String sessionLoopTitle(BuildContext context) =>
      get(context, 'sessionLoopTitle');
  static String sessionLoopSubtitle(BuildContext context) =>
      get(context, 'sessionLoopSubtitle');
  static String sessionLoopEmpty(BuildContext context) =>
      get(context, 'sessionLoopEmpty');
  static String classInsightsTitle(BuildContext context) =>
      get(context, 'classInsightsTitle');
  static String classInsightsSubtitle(BuildContext context) =>
      get(context, 'classInsightsSubtitle');
  static String classInsightsEmpty(BuildContext context) =>
      get(context, 'classInsightsEmpty');
  static String familyLearningTitle(BuildContext context) =>
      get(context, 'familyLearningTitle');
  static String familyLearningSubtitle(BuildContext context) =>
      get(context, 'familyLearningSubtitle');
  static String familyLearningEmpty(BuildContext context) =>
      get(context, 'familyLearningEmpty');
  static String familyScheduleTitle(BuildContext context) =>
      get(context, 'familyScheduleTitle');
  static String familyScheduleSubtitle(BuildContext context) =>
      get(context, 'familyScheduleSubtitle');
  static String familyScheduleEmpty(BuildContext context) =>
      get(context, 'familyScheduleEmpty');
  static String familyBillingTitle(BuildContext context) =>
      get(context, 'familyBillingTitle');
  static String familyBillingSubtitle(BuildContext context) =>
      get(context, 'familyBillingSubtitle');
  static String familyBillingEmpty(BuildContext context) =>
      get(context, 'familyBillingEmpty');
  static String cognition(BuildContext context) => get(context, 'cognition');
  static String engagement(BuildContext context) => get(context, 'engagement');
  static String integrity(BuildContext context) => get(context, 'integrity');
  static String improvementScore(BuildContext context) =>
      get(context, 'improvementScore');
  static String activeGoals(BuildContext context) =>
      get(context, 'activeGoals');
  static String mvlStatus(BuildContext context) => get(context, 'mvlStatus');
  static String mvlActive(BuildContext context) => get(context, 'mvlActive');
  static String mvlPassed(BuildContext context) => get(context, 'mvlPassed');
  static String mvlFailed(BuildContext context) => get(context, 'mvlFailed');
  static String loadingInsights(BuildContext context) =>
      get(context, 'loadingInsights');
  static String errorLoadingInsights(BuildContext context) =>
      get(context, 'errorLoadingInsights');
  static String latestSignal(BuildContext context) =>
      get(context, 'latestSignal');
  static String fdmStateEstimate(BuildContext context) =>
      get(context, 'fdmStateEstimate');
  static String baeWatchlist(BuildContext context) =>
      get(context, 'baeWatchlist');
  static String activeMvlGates(BuildContext context) =>
      get(context, 'activeMvlGates');
  static String learnersTracked(BuildContext context) =>
      get(context, 'learnersTracked');
  static String viewWatchlist(BuildContext context) =>
      get(context, 'viewWatchlist');
  static String watchlistClear(BuildContext context) =>
      get(context, 'watchlistClear');
  static String supportRecommended(BuildContext context) =>
      get(context, 'supportRecommended');
  static String learnerUnavailable(BuildContext context) =>
      get(context, 'learnerUnavailable');
  static String signalUnavailable(BuildContext context) =>
      get(context, 'signalUnavailable');
  static String partialSignals(BuildContext context) =>
      get(context, 'partialSignals');
  static String syntheticPreview(BuildContext context) =>
      get(context, 'syntheticPreview');
}
