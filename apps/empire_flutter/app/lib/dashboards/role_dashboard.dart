import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../auth/auth_service.dart';
import '../auth/app_state.dart';
import '../router/app_router.dart';
import '../modules/messages/message_service.dart';
import '../services/telemetry_service.dart';
import '../ui/localization/app_strings.dart';
import '../ui/localization/inline_locale_text.dart';
import '../ui/theme/scholesa_theme.dart';
import '../ui/widgets/cards.dart';

const Map<String, String> _roleDashboardZhCn = <String, String>{
  'Today': '今日',
  'Your schedule for today': '你今天的日程',
  'My Missions': '我的任务',
  'Start and continue missions': '开始并继续任务',
  '3 Active': '3 个进行中',
  'Habit Coach': '习惯教练',
  'Build great habits daily': '每天建立好习惯',
  'Portfolio': '作品集',
  'Your achievements & work': '你的成就与作品',
  "Today's Classes": '今日课程',
  'View roster and plans': '查看名单与计划',
  '4 Classes': '4 节课',
  'Take Attendance': '记录出勤',
  'Mark student attendance': '标记学生出勤',
  'Plan Missions': '规划任务',
  'Create and edit lesson plans': '创建并编辑课程计划',
  'Review Queue': '审核队列',
  'Review student submissions': '审核学生提交内容',
  '12 Pending': '12 个待处理',
  'Learner Supports': '学习者支持',
  'Track interventions': '跟踪干预措施',
  'Integrations': '集成',
  'Classroom & GitHub': 'Classroom 与 GitHub',
  'Child Summary': '孩子概览',
  'Weekly progress overview': '每周进度概览',
  'Schedule': '日程',
  'Upcoming classes': '即将到来的课程',
  'Portfolio Highlights': '作品集亮点',
  'Shared achievements': '共享成就',
  'Billing': '账单',
  'Invoices and payments': '发票与付款',
  'Today Operations': '今日运营',
  'Daily overview': '每日概览',
  'Check-in / Check-out': '签到 / 签退',
  'Manage arrivals and pickups': '管理到校与接送',
  'Provisioning': '配置',
  'Manage users and links': '管理用户与关联',
  'Safety & Incidents': '安全与事件',
  'Review and manage incidents': '审核并处理事件',
  '2 Open': '2 个未结',
  'Identity Resolution': '身份解析',
  'Match external accounts': '匹配外部账户',
  'Integrations Health': '集成健康状态',
  'Sync status': '同步状态',
  'Site Billing': '站点账单',
  'Subscription management': '订阅管理',
  'Listings': '列表',
  'Manage marketplace listings': '管理市场列表',
  'Contracts': '合同',
  'View and manage contracts': '查看并管理合同',
  'Payouts': '结算',
  'Payment history': '付款历史',
  'Deliverables': '交付项',
  'Track submitted evidence': '跟踪已提交的证据',
  'Partner Integrations': '合作方集成',
  'Connected external systems': '已连接的外部系统',
  'User Administration': '用户管理',
  'Manage all users': '管理所有用户',
  'Approvals Queue': '审批队列',
  'Review submissions': '审核提交内容',
  '5 Pending': '5 个待处理',
  'Audit & Logs': '审计与日志',
  'System audit trail': '系统审计记录',
  'Safety Oversight': '安全监督',
  'Critical incidents': '关键事件',
  'Billing Admin': '账单管理',
  'Platform billing': '平台账单',
  'Global sync status': '全局同步状态',
  'Site Management': '站点管理',
  'All sites overview': '所有站点概览',
  'Platform Analytics': '平台分析',
  'Global metrics & insights': '全局指标与洞察',
  'Role Impersonation': '角色模拟',
  'Test other role views': '测试其他角色视图',
  'Curriculum Builder': '课程构建器',
  'Pillars, skills, missions': '支柱、技能、任务',
  'Feature Flags': '功能开关',
  'Toggle platform features': '切换平台功能',
  'Messages': '消息',
  'Conversations': '会话',
  'Notifications': '通知',
  'Recent alerts': '最近提醒',
  '5 New': '5 条新消息',
  'Welcome back,': '欢迎回来，',
  'User': '用户',
  'Dashboard': '仪表板',
  'Switch site': '切换站点',
  'Settings': '设置',
  'Sign out': '退出登录',
  'Quick Actions': '快捷操作',
  'View All': '查看全部',
  'All Quick Actions': '全部快捷操作',
  'This action is not available for your current role or site setup. You can review your access in Settings.':
      '当前角色或站点配置下无法使用此操作。你可以在设置中查看访问权限。',
  'Close': '关闭',
  'Open Settings': '打开设置',
  'Switch Site': '切换站点',
  'Students Today': '今日学生数',
  'Attendance': '出勤',
  'To Review': '待审核',
  'On Site': '在站点',
  'Checked In': '已签到',
  'Open Incidents': '未结事件',
  'Active Sites': '活跃站点',
  'Total Users': '用户总数',
  'Pending': '待处理',
  '7-day': '7 天',
  'within SLA': 'SLA 内',
  'hours': '小时',
  'Sign Out': '退出登录',
  'Sign out so another family member can switch accounts on this device?':
      '要退出登录，让其他家庭成员在这台设备上切换账户吗？',
  'learner': '学习者',
  'educator': '教育者',
  'parent': '家长',
  'site': '站点',
  'partner': '合作方',
  'hq': '总部',
  'No live metrics yet': '暂无实时指标',
};

const Map<String, String> _roleDashboardZhTw = <String, String>{
  'Today': '今日',
  'Your schedule for today': '你今天的日程',
  'My Missions': '我的任務',
  'Start and continue missions': '開始並繼續任務',
  '3 Active': '3 個進行中',
  'Habit Coach': '習慣教練',
  'Build great habits daily': '每天建立好習慣',
  'Portfolio': '作品集',
  'Your achievements & work': '你的成就與作品',
  "Today's Classes": '今日課程',
  'View roster and plans': '檢視名單與計畫',
  '4 Classes': '4 堂課',
  'Take Attendance': '記錄出勤',
  'Mark student attendance': '標記學生出勤',
  'Plan Missions': '規劃任務',
  'Create and edit lesson plans': '建立並編輯課程計畫',
  'Review Queue': '審核佇列',
  'Review student submissions': '審核學生提交內容',
  '12 Pending': '12 個待處理',
  'Learner Supports': '學習者支持',
  'Track interventions': '追蹤介入措施',
  'Integrations': '整合',
  'Classroom & GitHub': 'Classroom 與 GitHub',
  'Child Summary': '孩子摘要',
  'Weekly progress overview': '每週進度概覽',
  'Schedule': '日程',
  'Upcoming classes': '即將到來的課程',
  'Portfolio Highlights': '作品集亮點',
  'Shared achievements': '共享成就',
  'Billing': '帳單',
  'Invoices and payments': '發票與付款',
  'Today Operations': '今日營運',
  'Daily overview': '每日概覽',
  'Check-in / Check-out': '簽到 / 簽退',
  'Manage arrivals and pickups': '管理到校與接送',
  'Provisioning': '配置',
  'Manage users and links': '管理使用者與連結',
  'Safety & Incidents': '安全與事件',
  'Review and manage incidents': '審核並處理事件',
  '2 Open': '2 個未結',
  'Identity Resolution': '身份解析',
  'Match external accounts': '配對外部帳戶',
  'Integrations Health': '整合健康狀態',
  'Sync status': '同步狀態',
  'Site Billing': '站點帳單',
  'Subscription management': '訂閱管理',
  'Listings': '列表',
  'Manage marketplace listings': '管理市集列表',
  'Contracts': '合約',
  'View and manage contracts': '檢視並管理合約',
  'Payouts': '撥款',
  'Payment history': '付款歷史',
  'Deliverables': '交付項',
  'Track submitted evidence': '追蹤已提交的證據',
  'Partner Integrations': '合作夥伴整合',
  'Connected external systems': '已連接的外部系統',
  'User Administration': '使用者管理',
  'Manage all users': '管理所有使用者',
  'Approvals Queue': '審批佇列',
  'Review submissions': '審核提交內容',
  '5 Pending': '5 個待處理',
  'Audit & Logs': '稽核與日誌',
  'System audit trail': '系統稽核紀錄',
  'Safety Oversight': '安全監督',
  'Critical incidents': '關鍵事件',
  'Billing Admin': '帳單管理',
  'Platform billing': '平台帳單',
  'Global sync status': '全域同步狀態',
  'Site Management': '站點管理',
  'All sites overview': '所有站點概覽',
  'Platform Analytics': '平台分析',
  'Global metrics & insights': '全域指標與洞察',
  'Role Impersonation': '角色模擬',
  'Test other role views': '測試其他角色視圖',
  'Curriculum Builder': '課程建構器',
  'Pillars, skills, missions': '支柱、技能、任務',
  'Feature Flags': '功能開關',
  'Toggle platform features': '切換平台功能',
  'Messages': '訊息',
  'Conversations': '對話',
  'Notifications': '通知',
  'Recent alerts': '最近提醒',
  '5 New': '5 則新訊息',
  'Welcome back,': '歡迎回來，',
  'User': '使用者',
  'Dashboard': '儀表板',
  'Switch site': '切換站點',
  'Settings': '設定',
  'Sign out': '登出',
  'Quick Actions': '快捷操作',
  'View All': '查看全部',
  'All Quick Actions': '全部快捷操作',
  'This action is not available for your current role or site setup. You can review your access in Settings.':
      '目前角色或站點設定下無法使用此操作。你可以在設定中查看存取權限。',
  'Close': '關閉',
  'Open Settings': '開啟設定',
  'Switch Site': '切換站點',
  'Students Today': '今日學生數',
  'Attendance': '出勤',
  'To Review': '待審核',
  'On Site': '在站點',
  'Checked In': '已簽到',
  'Open Incidents': '未結事件',
  'Active Sites': '活躍站點',
  'Total Users': '使用者總數',
  'Pending': '待處理',
  '7-day': '7 天',
  'within SLA': 'SLA 內',
  'hours': '小時',
  'Sign Out': '登出',
  'Sign out so another family member can switch accounts on this device?':
      '要登出，讓其他家庭成員在這台裝置上切換帳戶嗎？',
  'learner': '學習者',
  'educator': '教育者',
  'parent': '家長',
  'site': '站點',
  'partner': '合作夥伴',
  'hq': '總部',
  'No live metrics yet': '尚無即時指標',
};

/// Dashboard card definition from docs/47_ROLE_DASHBOARD_CARD_REGISTRY.md
class DashboardCard {
  const DashboardCard({
    required this.id,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.route,
    required this.gradient,
    this.badgeText,
  });
  final String id;
  final String title;
  final String? subtitle;
  final IconData icon;
  final String route;
  final LinearGradient gradient;
  final String? badgeText;
}

/// Card registry per role - based on docs/47
final Map<UserRole, List<DashboardCard>> _cardRegistry =
    <UserRole, List<DashboardCard>>{
  // ═══════════════════════════════════════════════════════════════════════════
  // LEARNER DASHBOARD - Cyan/Blue theme
  // ═══════════════════════════════════════════════════════════════════════════
  UserRole.learner: <DashboardCard>[
    const DashboardCard(
      id: 'learner_today',
      title: 'Today',
      subtitle: 'Your schedule for today',
      icon: Icons.today_rounded,
      route: '/learner/today',
      gradient: ScholesaColors.scheduleGradient,
    ),
    const DashboardCard(
      id: 'learner_missions',
      title: 'My Missions',
      subtitle: 'Start and continue missions',
      icon: Icons.rocket_launch_rounded,
      route: '/learner/missions',
      gradient: ScholesaColors.missionGradient,
    ),
    const DashboardCard(
      id: 'learner_habits',
      title: 'Habit Coach',
      subtitle: 'Build great habits daily',
      icon: Icons.psychology_rounded,
      route: '/learner/habits',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFF10B981), Color(0xFF34D399)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    const DashboardCard(
      id: 'learner_portfolio',
      title: 'Portfolio',
      subtitle: 'Your achievements & work',
      icon: Icons.folder_special_rounded,
      route: '/learner/portfolio',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFFF59E0B), Color(0xFFFBBF24)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ],

  // ═══════════════════════════════════════════════════════════════════════════
  // EDUCATOR DASHBOARD - Purple theme
  // ═══════════════════════════════════════════════════════════════════════════
  UserRole.educator: <DashboardCard>[
    const DashboardCard(
      id: 'educator_today_classes',
      title: "Today's Classes",
      subtitle: 'View roster and plans',
      icon: Icons.calendar_today_rounded,
      route: '/educator/today',
      gradient: ScholesaColors.scheduleGradient,
    ),
    const DashboardCard(
      id: 'educator_attendance',
      title: 'Take Attendance',
      subtitle: 'Mark student attendance',
      icon: Icons.fact_check_rounded,
      route: '/educator/attendance',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFF22C55E), Color(0xFF4ADE80)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    const DashboardCard(
      id: 'educator_plan',
      title: 'Plan Missions',
      subtitle: 'Create and edit lesson plans',
      icon: Icons.edit_note_rounded,
      route: '/educator/mission-plans',
      gradient: ScholesaColors.missionGradient,
    ),
    const DashboardCard(
      id: 'educator_review_queue',
      title: 'Review Queue',
      subtitle: 'Review student submissions',
      icon: Icons.rate_review_rounded,
      route: '/educator/missions/review',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFFF59E0B), Color(0xFFFBBF24)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    const DashboardCard(
      id: 'educator_supports',
      title: 'Learner Supports',
      subtitle: 'Track interventions',
      icon: Icons.support_agent_rounded,
      route: '/educator/learner-supports',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFF06B6D4), Color(0xFF22D3EE)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    const DashboardCard(
      id: 'educator_integrations',
      title: 'Integrations',
      subtitle: 'Classroom & GitHub',
      icon: Icons.integration_instructions_rounded,
      route: '/educator/integrations',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFF64748B), Color(0xFF94A3B8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ],

  // ═══════════════════════════════════════════════════════════════════════════
  // PARENT DASHBOARD - Amber/Warm theme
  // ═══════════════════════════════════════════════════════════════════════════
  UserRole.parent: <DashboardCard>[
    const DashboardCard(
      id: 'parent_child_summary',
      title: 'Child Summary',
      subtitle: 'Weekly progress overview',
      icon: Icons.child_care_rounded,
      route: '/parent/summary',
      gradient: ScholesaColors.parentGradient,
    ),
    const DashboardCard(
      id: 'parent_schedule',
      title: 'Schedule',
      subtitle: 'Upcoming classes',
      icon: Icons.schedule_rounded,
      route: '/parent/schedule',
      gradient: ScholesaColors.scheduleGradient,
    ),
    const DashboardCard(
      id: 'parent_portfolio',
      title: 'Portfolio Highlights',
      subtitle: 'Shared achievements',
      icon: Icons.photo_library_rounded,
      route: '/parent/portfolio',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFF8B5CF6), Color(0xFFA78BFA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    const DashboardCard(
      id: 'parent_billing',
      title: 'Billing',
      subtitle: 'Invoices and payments',
      icon: Icons.receipt_long_rounded,
      route: '/parent/billing',
      gradient: ScholesaColors.billingGradient,
    ),
  ],

  // ═══════════════════════════════════════════════════════════════════════════
  // SITE DASHBOARD - Teal theme
  // ═══════════════════════════════════════════════════════════════════════════
  UserRole.site: <DashboardCard>[
    const DashboardCard(
      id: 'site_ops_today',
      title: 'Today Operations',
      subtitle: 'Daily overview',
      icon: Icons.dashboard_rounded,
      route: '/site/ops',
      gradient: ScholesaColors.siteGradient,
    ),
    const DashboardCard(
      id: 'site_checkin_checkout',
      title: 'Check-in / Check-out',
      subtitle: 'Manage arrivals and pickups',
      icon: Icons.qr_code_scanner_rounded,
      route: '/site/checkin',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFF3B82F6), Color(0xFF60A5FA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    const DashboardCard(
      id: 'site_provisioning',
      title: 'Provisioning',
      subtitle: 'Manage users and links',
      icon: Icons.person_add_rounded,
      route: '/site/provisioning',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFF6366F1), Color(0xFF818CF8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    const DashboardCard(
      id: 'site_incidents',
      title: 'Safety & Incidents',
      subtitle: 'Review and manage incidents',
      icon: Icons.warning_rounded,
      route: '/site/incidents',
      gradient: ScholesaColors.safetyGradient,
    ),
    const DashboardCard(
      id: 'site_identity_resolution',
      title: 'Identity Resolution',
      subtitle: 'Match external accounts',
      icon: Icons.link_rounded,
      route: '/site/identity',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFF64748B), Color(0xFF94A3B8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    const DashboardCard(
      id: 'site_integrations_health',
      title: 'Integrations Health',
      subtitle: 'Sync status',
      icon: Icons.sync_rounded,
      route: '/site/integrations-health',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFF22C55E), Color(0xFF4ADE80)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    const DashboardCard(
      id: 'site_billing',
      title: 'Site Billing',
      subtitle: 'Subscription management',
      icon: Icons.payment_rounded,
      route: '/site/billing',
      gradient: ScholesaColors.billingGradient,
    ),
  ],

  // ═══════════════════════════════════════════════════════════════════════════
  // PARTNER DASHBOARD - Pink theme
  // ═══════════════════════════════════════════════════════════════════════════
  UserRole.partner: <DashboardCard>[
    const DashboardCard(
      id: 'partner_listings',
      title: 'Listings',
      subtitle: 'Manage marketplace listings',
      icon: Icons.storefront_rounded,
      route: '/partner/listings',
      gradient: ScholesaColors.partnerGradient,
    ),
    const DashboardCard(
      id: 'partner_contracts',
      title: 'Contracts',
      subtitle: 'View and manage contracts',
      icon: Icons.description_rounded,
      route: '/partner/contracts',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFF6366F1), Color(0xFF818CF8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    const DashboardCard(
      id: 'partner_deliverables',
      title: 'Deliverables',
      subtitle: 'Track submitted evidence',
      icon: Icons.inventory_2_rounded,
      route: '/partner/deliverables',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFFEC4899), Color(0xFFF472B6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    const DashboardCard(
      id: 'partner_integrations',
      title: 'Partner Integrations',
      subtitle: 'Connected external systems',
      icon: Icons.hub_rounded,
      route: '/partner/integrations',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFF0EA5E9), Color(0xFF38BDF8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    const DashboardCard(
      id: 'partner_payouts',
      title: 'Payouts',
      subtitle: 'Payment history',
      icon: Icons.account_balance_rounded,
      route: '/partner/payouts',
      gradient: ScholesaColors.billingGradient,
    ),
  ],

  // ═══════════════════════════════════════════════════════════════════════════
  // HQ DASHBOARD - Indigo theme
  // ═══════════════════════════════════════════════════════════════════════════
  UserRole.hq: <DashboardCard>[
    const DashboardCard(
      id: 'hq_user_admin',
      title: 'User Administration',
      subtitle: 'Manage all users',
      icon: Icons.admin_panel_settings_rounded,
      route: '/hq/user-admin',
      gradient: ScholesaColors.hqGradient,
    ),
    const DashboardCard(
      id: 'hq_approvals',
      title: 'Approvals Queue',
      subtitle: 'Review submissions',
      icon: Icons.approval_rounded,
      route: '/hq/approvals',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFFF59E0B), Color(0xFFFBBF24)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    const DashboardCard(
      id: 'hq_audit_logs',
      title: 'Audit & Logs',
      subtitle: 'System audit trail',
      icon: Icons.history_rounded,
      route: '/hq/audit',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFF64748B), Color(0xFF94A3B8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    const DashboardCard(
      id: 'hq_safety_oversight',
      title: 'Safety Oversight',
      subtitle: 'Critical incidents',
      icon: Icons.shield_rounded,
      route: '/hq/safety',
      gradient: ScholesaColors.safetyGradient,
    ),
    const DashboardCard(
      id: 'hq_billing_admin',
      title: 'Billing Admin',
      subtitle: 'Platform billing',
      icon: Icons.monetization_on_rounded,
      route: '/hq/billing',
      gradient: ScholesaColors.billingGradient,
    ),
    const DashboardCard(
      id: 'hq_integrations_health',
      title: 'Integrations Health',
      subtitle: 'Global sync status',
      icon: Icons.health_and_safety_rounded,
      route: '/hq/integrations-health',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFF22C55E), Color(0xFF4ADE80)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    const DashboardCard(
      id: 'hq_sites',
      title: 'Site Management',
      subtitle: 'All sites overview',
      icon: Icons.business_rounded,
      route: '/hq/sites',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFF0EA5E9), Color(0xFF38BDF8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    const DashboardCard(
      id: 'hq_analytics',
      title: 'Platform Analytics',
      subtitle: 'Global metrics & insights',
      icon: Icons.analytics_rounded,
      route: '/hq/analytics',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFF8B5CF6), Color(0xFFA78BFA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    const DashboardCard(
      id: 'hq_role_switcher',
      title: 'Role Impersonation',
      subtitle: 'Test other role views',
      icon: Icons.swap_horizontal_circle_rounded,
      route: '/hq/role-switcher',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFFEC4899), Color(0xFFF472B6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    const DashboardCard(
      id: 'hq_curriculum',
      title: 'Curriculum Builder',
      subtitle: 'Pillars, skills, missions',
      icon: Icons.school_rounded,
      route: '/hq/curriculum',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFF059669), Color(0xFF10B981)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    const DashboardCard(
      id: 'hq_feature_flags',
      title: 'Feature Flags',
      subtitle: 'Toggle platform features',
      icon: Icons.flag_rounded,
      route: '/hq/feature-flags',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFF6366F1), Color(0xFF818CF8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ],
};

/// Shared cards for all roles
final List<DashboardCard> _sharedCards = <DashboardCard>[
  const DashboardCard(
    id: 'messages',
    title: 'Messages',
    subtitle: 'Conversations',
    icon: Icons.message_rounded,
    route: '/messages',
    gradient: LinearGradient(
      colors: <Color>[Color(0xFF3B82F6), Color(0xFF60A5FA)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  const DashboardCard(
    id: 'notifications',
    title: 'Notifications',
    subtitle: 'Recent alerts',
    icon: Icons.notifications_rounded,
    route: '/notifications',
    gradient: LinearGradient(
      colors: <Color>[Color(0xFFF59E0B), Color(0xFFFBBF24)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
];

/// Main role-based dashboard with beautiful colorful UI
class RoleDashboard extends StatelessWidget {
  const RoleDashboard({super.key});

  String _t(BuildContext context, String input) {
    return InlineLocaleText.of(
      context,
      input,
      zhCn: _roleDashboardZhCn,
      zhTw: _roleDashboardZhTw,
    );
  }

  String _roleLabel(BuildContext context, UserRole role) {
    final String localizedRole = _t(context, role.name);
    return '$localizedRole ${_t(context, 'Dashboard')}';
  }

  Widget? _buildDynamicBadge(
    BuildContext context,
    DashboardCard card,
    MessageService messageService,
    bool isEnabled,
  ) {
    if (!isEnabled) {
      return null;
    }

    int? count;
    if (card.id == 'notifications') {
      count = messageService.unreadNotificationCount;
    } else if (card.id == 'messages') {
      count = messageService.unreadDirectCount;
    }

    if (count == null || count <= 0) {
      return null;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AppState, MessageService>(
      builder: (
        BuildContext context,
        AppState appState,
        MessageService messageService,
        _,
      ) {
        final ColorScheme scheme = Theme.of(context).colorScheme;
        final UserRole? role = appState.role;

        if (role == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final List<DashboardCard> cards = <DashboardCard>[
          ...(_cardRegistry[role] ?? <DashboardCard>[]),
          ..._sharedCards
        ];
        final LinearGradient roleGradient = role.name.roleGradient;
        final Color roleColor = role.name.roleColor;

        return Scaffold(
          backgroundColor: scheme.surfaceContainerLowest,
          body: CustomScrollView(
            slivers: <Widget>[
              // Beautiful gradient header
              SliverAppBar(
                expandedHeight: 160,
                pinned: true,
                backgroundColor: roleColor,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      Container(
                        decoration: BoxDecoration(gradient: roleGradient),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              Color.fromRGBO(0, 0, 0, 0.22),
                              Color.fromRGBO(0, 0, 0, 0.12),
                            ],
                          ),
                        ),
                      ),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  UserAvatar(
                                    name: appState.displayName ??
                                        _t(context, 'User'),
                                    size: 50,
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.25),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          _t(context, 'Welcome back,'),
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.white.withValues(
                                              alpha: 0.95,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          appState.displayName ??
                                              _t(context, 'User'),
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(
                                      _getRoleIcon(role),
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _roleLabel(context, role),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: <Widget>[
                  if (appState.siteIds.length > 1)
                    IconButton(
                      icon: const Icon(Icons.swap_horiz, color: Colors.white),
                      tooltip: _t(context, 'Switch site'),
                      onPressed: () {
                        TelemetryService.instance.logEvent(
                          event: 'cta.clicked',
                          metadata: const <String, dynamic>{
                            'cta': 'role_dashboard_open_site_switcher',
                            'surface': 'appbar',
                          },
                        );
                        _showSiteSwitcher(context, appState);
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined,
                        color: Colors.white),
                    tooltip: _t(context, 'Settings'),
                    onPressed: () {
                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: const <String, dynamic>{
                          'cta': 'role_dashboard_open_settings',
                          'surface': 'appbar',
                        },
                      );
                      context.push('/settings');
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    tooltip: _t(context, 'Sign out'),
                    onPressed: () => _showLogoutDialog(context),
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              // Quick stats section (optional based on role)
              if (role == UserRole.educator ||
                  role == UserRole.site ||
                  role == UserRole.hq)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: _buildQuickStats(role, appState),
                  ),
                ),

              // Section title
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: <Widget>[
                      Text(
                        _t(context, 'Quick Actions'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _showAllActionsSheet(context, cards),
                        child: Text(_t(context, 'View All')),
                      ),
                    ],
                  ),
                ),
              ),

              // Cards grid
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                      final DashboardCard card = cards[index];
                      final bool isEnabled = isRouteEnabled(card.route);

                      return GradientCard(
                        title: _t(context, card.title),
                        subtitle: card.subtitle == null
                            ? null
                            : _t(context, card.subtitle!),
                        icon: card.icon,
                        gradient: card.gradient,
                        isEnabled: isEnabled,
                        badgeText: _buildDynamicBadge(
                                      context,
                                      card,
                                      messageService,
                                      isEnabled,
                                    ) ==
                                    null &&
                                card.badgeText != null
                            ? _t(context, card.badgeText!)
                            : null,
                        badge: _buildDynamicBadge(
                          context,
                          card,
                          messageService,
                          isEnabled,
                        ),
                        onTap: () => _handleCardTap(context, card, isEnabled),
                      );
                    },
                    childCount: cards.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.9,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickStats(UserRole role, AppState appState) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadRoleStats(role, appState),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
      ) {
        final List<Map<String, dynamic>> stats =
            snapshot.data ?? const <Map<String, dynamic>>[];
        if (stats.isEmpty) {
          return SizedBox(
            height: 100,
            child: Center(
              child: Text(
                _t(context, 'No live metrics yet'),
                style: const TextStyle(color: ScholesaColors.textSecondary),
              ),
            ),
          );
        }
        return SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: stats.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (BuildContext context, int index) {
              final Map<String, dynamic> stat = stats[index];
              return SizedBox(
                width: 140,
                child: StatCard(
                  label: _t(context, stat['label'] as String),
                  value: stat['value'] as String,
                  icon: stat['icon'] as IconData,
                  color: stat['color'] as Color,
                  trend: (stat['trend'] as String?) == null
                      ? null
                      : _t(context, stat['trend'] as String),
                  isPositive: stat['positive'] as bool? ?? true,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadRoleStats(
    UserRole role,
    AppState appState,
  ) async {
    final HttpsCallable callable =
        FirebaseFunctions.instance.httpsCallable('getRoleDashboardSnapshot');
    final HttpsCallableResult<dynamic> result =
        await callable.call(<String, dynamic>{
      'role': role.name,
      'siteId': appState.activeSiteId,
      'period': 'week',
    });
    final Map<String, dynamic>? payload = _asStringDynamicMap(result.data);
    if (payload == null) return <Map<String, dynamic>>[];
    final List<dynamic> rawStats =
        payload['stats'] as List<dynamic>? ?? <dynamic>[];
    if (rawStats.isEmpty) return <Map<String, dynamic>>[];

    final List<Map<String, dynamic>> stats = <Map<String, dynamic>>[];
    for (final dynamic raw in rawStats) {
      final Map<String, dynamic>? item = _asStringDynamicMap(raw);
      if (item == null) continue;
      final String label = (item['label'] as String? ?? '').trim();
      final String value = (item['value'] as String? ?? '').trim();
      if (label.isEmpty || value.isEmpty) continue;
      final String iconKey = (item['icon'] as String? ?? '').trim();
      final String colorKey = (item['color'] as String? ?? '').trim();
      stats.add(<String, dynamic>{
        'label': label,
        'value': value,
        'icon': _iconFromKey(iconKey),
        'color': _colorFromKey(colorKey),
        if (item['trend'] is String) 'trend': item['trend'] as String,
        if (item['positive'] is bool) 'positive': item['positive'] as bool,
      });
    }
    if (stats.isEmpty) return <Map<String, dynamic>>[];
    return stats;
  }

  Map<String, dynamic>? _asStringDynamicMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((dynamic key, dynamic nestedValue) =>
          MapEntry<String, dynamic>(key.toString(), nestedValue));
    }
    return null;
  }

  IconData _iconFromKey(String key) {
    switch (key) {
      case 'people':
        return Icons.people;
      case 'check_circle':
        return Icons.check_circle;
      case 'rate_review':
        return Icons.rate_review;
      case 'location_on':
        return Icons.location_on;
      case 'login':
        return Icons.login;
      case 'warning':
        return Icons.warning;
      case 'business':
        return Icons.business;
      case 'pending_actions':
        return Icons.pending_actions;
      default:
        return Icons.bar_chart;
    }
  }

  Color _colorFromKey(String key) {
    switch (key) {
      case 'primary':
        return ScholesaColors.primary;
      case 'info':
        return ScholesaColors.info;
      case 'success':
        return ScholesaColors.success;
      case 'warning':
        return ScholesaColors.warning;
      case 'error':
        return ScholesaColors.error;
      default:
        return ScholesaColors.primary;
    }
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.learner:
        return Icons.school_rounded;
      case UserRole.educator:
        return Icons.cast_for_education_rounded;
      case UserRole.parent:
        return Icons.family_restroom_rounded;
      case UserRole.site:
        return Icons.business_rounded;
      case UserRole.partner:
        return Icons.handshake_rounded;
      case UserRole.hq:
        return Icons.corporate_fare_rounded;
    }
  }

  void _handleCardTap(
      BuildContext context, DashboardCard card, bool isEnabled) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'role_dashboard_card_tap',
        'card_id': card.id,
        'route': card.route,
        'enabled': isEnabled,
      },
    );
    if (isEnabled) {
      context.push(card.route);
    } else {
      _showUnavailableActionDialog(context, card);
    }
  }

  void _showAllActionsSheet(BuildContext context, List<DashboardCard> cards) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{
        'cta': 'role_dashboard_view_all_actions'
      },
    );
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: cards.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (BuildContext context, int index) {
            if (index == 0) {
              return Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  _t(sheetContext, 'All Quick Actions'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(sheetContext).colorScheme.onSurface,
                  ),
                ),
              );
            }

            final DashboardCard card = cards[index - 1];
            final bool enabled = isRouteEnabled(card.route);
            return ListTile(
              leading: Icon(card.icon,
                  color: enabled
                      ? null
                      : Theme.of(sheetContext).colorScheme.onSurfaceVariant),
              title: Text(_t(sheetContext, card.title)),
              subtitle: Text(card.subtitle == null
                  ? ''
                  : _t(sheetContext, card.subtitle!)),
              trailing: Icon(
                enabled ? Icons.arrow_forward_ios : Icons.lock_outline,
                size: 16,
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _handleCardTap(context, card, enabled);
              },
            );
          },
        ),
      ),
    );
  }

  void _showUnavailableActionDialog(BuildContext context, DashboardCard card) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(_t(dialogContext, card.title)),
        content: Text(
          _t(
            dialogContext,
            'This action is not available for your current role or site setup. You can review your access in Settings.',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'cta': 'role_dashboard_close_unavailable_action_dialog',
                  'surface': 'unavailable_action_dialog',
                },
              );
              Navigator.pop(dialogContext);
            },
            child: Text(_t(dialogContext, 'Close')),
          ),
          ElevatedButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'cta': 'role_dashboard_open_settings_from_unavailable_action',
                  'surface': 'unavailable_action_dialog',
                },
              );
              Navigator.pop(dialogContext);
              context.push('/settings');
            },
            child: Text(_t(dialogContext, 'Open Settings')),
          ),
        ],
      ),
    );
  }

  void _showSiteSwitcher(BuildContext context, AppState appState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                _t(context, 'Switch Site'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            ...appState.siteIds.map((String siteId) => ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ScholesaColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.business,
                      color: siteId == appState.activeSiteId
                          ? ScholesaColors.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  title: Text(siteId),
                  trailing: siteId == appState.activeSiteId
                      ? const Icon(Icons.check_circle,
                          color: ScholesaColors.success)
                      : null,
                  onTap: () {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: <String, dynamic>{
                        'cta': 'role_dashboard_switch_site',
                        'surface': 'site_switcher_sheet',
                        'site_id': siteId,
                      },
                    );
                    appState.switchSite(siteId);
                    Navigator.pop(context);
                  },
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{
        'cta': 'role_dashboard_open_sign_out_dialog'
      },
    );
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: <Widget>[
            const Icon(Icons.logout, color: ScholesaColors.error),
            const SizedBox(width: 12),
            Text(_t(dialogContext, 'Sign Out')),
          ],
        ),
        content: Text(
          _t(
            dialogContext,
            'Sign out so another family member can switch accounts on this device?',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'cta': 'role_dashboard_cancel_sign_out',
                  'surface': 'sign_out_dialog',
                },
              );
              Navigator.pop(dialogContext);
            },
            child: Text(_t(dialogContext, 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'cta': 'role_dashboard_confirm_sign_out'
                },
              );
              Navigator.pop(dialogContext);
              final AuthService authService = context.read<AuthService>();
              try {
                await authService.signOut(source: 'role_dashboard');
                if (context.mounted) {
                  context.go('/welcome');
                }
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppStrings.of(context, 'auth.error.signOutFailed'),
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ScholesaColors.error,
            ),
            child: Text(_t(dialogContext, 'Sign Out')),
          ),
        ],
      ),
    );
  }
}
