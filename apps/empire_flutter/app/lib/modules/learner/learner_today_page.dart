import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';
import '../../runtime/runtime.dart';
import '../../auth/app_state.dart';
import '../missions/missions.dart';
import '../habits/habits.dart';

const Map<String, String> _learnerTodayEs = <String, String>{
  'Today': 'Hoy',
  '🌟 Keep Going!': '🌟 ¡Sigue así!',
  "You're making amazing progress. Complete today's habits to maintain your streak!":
      'Estás avanzando increíblemente. Completa los hábitos de hoy para mantener tu racha.',
  'day streak': 'días de racha',
  'Habits': 'Hábitos',
  'Missions': 'Misiones',
  'Messages': 'Mensajes',
  'active': 'activas',
  "Today's Habits": 'Hábitos de hoy',
  'See all': 'Ver todo',
  'Active Missions': 'Misiones activas',
  'Good morning': 'Buenos días',
  'Good afternoon': 'Buenas tardes',
  'Good evening': 'Buenas noches',
  'done': 'hecho',
  'Start': 'Iniciar',
  'Daily Coaching': 'Asesoramiento diario',
  'Get personalized guidance for today': 'Obtén orientación personalizada para hoy',
  'Hide Coaching': 'Ocultar asesoramiento',
    'No habits scheduled yet': 'Aún no hay hábitos programados',
    'Set up a habit to start your daily streak.':
      'Configura un hábito para iniciar tu racha diaria.',
    'No active missions yet': 'Aún no hay misiones activas',
    'Start a mission to activate your learning loop.':
      'Inicia una misión para activar tu ciclo de aprendizaje.',
    'AI coaching is loading': 'El asesoramiento de IA se está cargando',
    'Runtime context is syncing. Try again in a moment.':
      'El contexto runtime se está sincronizando. Inténtalo en un momento.',
    'BOS/MIA Learning Loop': 'Ciclo de aprendizaje BOS/MIA',
    'Latest individual improvement signal': 'Última señal individual de mejora',
    'No learner loop data yet': 'Aún no hay datos del ciclo de aprendizaje',
};

/// Learner Today Page - Daily summary for learners
class LearnerTodayPage extends StatefulWidget {
  const LearnerTodayPage({super.key});

  @override
  State<LearnerTodayPage> createState() => _LearnerTodayPageState();
}

class _LearnerTodayPageState extends State<LearnerTodayPage> {
  bool _showAiCoach = false;

  String _t(String input) {
    final String locale = Localizations.localeOf(context).languageCode;
    if (locale != 'es') return input;
    return _learnerTodayEs[input] ?? input;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MissionService>().loadMissions();
      context.read<HabitService>().loadHabits();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = scheme.brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              isDark ? scheme.surface : const Color(0xFFF0FDF8),
              isDark ? scheme.surfaceContainerLow : const Color(0xFFF8FAFC),
              isDark ? scheme.surfaceContainer : const Color(0xFFFFFBEB),
            ],
            stops: const <double>[0.0, 0.5, 1.0],
          ),
        ),
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildGreetingCard()),
            SliverToBoxAdapter(child: _buildTodayProgress()),
            SliverToBoxAdapter(child: _buildAiCoachingSection(context)),
            SliverToBoxAdapter(child: _buildLearnerLoopInsights(context)),
            SliverToBoxAdapter(child: _buildQuickActions()),
            SliverToBoxAdapter(child: _buildTodayHabits()),
            SliverToBoxAdapter(child: _buildActiveMissions()),
            const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[ScholesaColors.learner, Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: ScholesaColors.learner.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.wb_sunny, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _getGreeting(),
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _t('Today'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      ),
                ),
              ],
            ),
            const Spacer(),
            IconButton(
              onPressed: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: const <String, dynamic>{
                    'cta': 'learner_today_open_messages'
                  },
                );
                context.push('/messages');
              },
              icon: Stack(
                children: <Widget>[
                  Icon(Icons.notifications_outlined,
                      color: context.schTextSecondary, size: 28),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: ScholesaColors.error,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGreetingCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF0E9F6E), Color(0xFF04684A)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: ScholesaColors.learner.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.18),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _t('🌟 Keep Going!'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _t(
                        "You're making amazing progress. Complete today's habits to maintain your streak!",
                      ),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.96),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.34)),
                ),
                child: Consumer<HabitService>(
                  builder: (BuildContext context, HabitService service, _) {
                    return Column(
                      children: <Widget>[
                        const Text(
                          '🔥',
                          style: TextStyle(fontSize: 32),
                        ),
                        Text(
                          '${service.totalStreak}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _t('day streak'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayProgress() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Consumer<HabitService>(
              builder: (BuildContext context, HabitService service, _) {
                return _ProgressCard(
                  title: _t('Habits'),
                  completed: service.completedTodayCount,
                  total: service.totalTodayCount,
                  icon: Icons.check_circle,
                  color: const Color(0xFF8B5CF6),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Consumer<MissionService>(
              builder: (BuildContext context, MissionService service, _) {
                final int active = service.activeMissions.length;
                return _ProgressCard(
                  title: _t('Missions'),
                  completed: active,
                  total: active,
                  icon: Icons.rocket_launch,
                  color: const Color(0xFFF59E0B),
                  label: _t('active'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _QuickActionCard(
              icon: Icons.trending_up,
              label: _t('Habits'),
              color: const Color(0xFF8B5CF6),
              onTap: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: const <String, dynamic>{
                    'cta': 'learner_today_open_habits'
                  },
                );
                context.push('/learner/habits');
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActionCard(
              icon: Icons.rocket_launch,
              label: _t('Missions'),
              color: const Color(0xFFF59E0B),
              onTap: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: const <String, dynamic>{
                    'cta': 'learner_today_open_missions'
                  },
                );
                context.push('/learner/missions');
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActionCard(
              icon: Icons.message,
              label: _t('Messages'),
              color: const Color(0xFF6366F1),
              onTap: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: const <String, dynamic>{
                    'cta': 'learner_today_open_messages_quick_action'
                  },
                );
                context.push('/messages');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayHabits() {
    return Consumer<HabitService>(
      builder: (BuildContext context, HabitService service, _) {
        final List<Habit> habits = service.todayHabits.take(3).toList();
        if (habits.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _t("Today's Habits"),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t('No habits scheduled yet'),
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _t('Set up a habit to start your daily streak.'),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    _t("Today's Habits"),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: const <String, dynamic>{
                          'cta': 'learner_today_see_all_habits'
                        },
                      );
                      context.push('/learner/habits');
                    },
                    child: Text(
                      _t('See all'),
                      style: TextStyle(color: ScholesaColors.learner),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...habits.map((Habit habit) => _HabitTile(habit: habit)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveMissions() {
    return Consumer<MissionService>(
      builder: (BuildContext context, MissionService service, _) {
        final List<Mission> missions = service.activeMissions.take(2).toList();
        if (missions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _t('Active Missions'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t('No active missions yet'),
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _t('Start a mission to activate your learning loop.'),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    _t('Active Missions'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: const <String, dynamic>{
                          'cta': 'learner_today_see_all_missions'
                        },
                      );
                      context.push('/learner/missions');
                    },
                    child: Text(
                      _t('See all'),
                      style: TextStyle(color: ScholesaColors.learner),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...missions
                  .map((Mission mission) => _MissionTile(mission: mission)),
            ],
          ),
        );
      },
    );
  }

  String _getGreeting() {
    final int hour = DateTime.now().hour;
    if (hour < 12) return _t('Good morning');
    if (hour < 17) return _t('Good afternoon');
    return _t('Good evening');
  }

  Widget _buildAiCoachingSection(BuildContext context) {
    final AppState appState = context.read<AppState>();
    final UserRole? role = appState.role;

    if (role == null || role != UserRole.learner) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              color: ScholesaColors.learner.withValues(alpha: 0.1),
              border: Border.all(
                color: ScholesaColors.learner.withValues(alpha: 0.2),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Icon(
                Icons.smart_toy_rounded,
                color: ScholesaColors.learner,
              ),
              title: Text(_t('Daily Coaching')),
              subtitle: Text(_t('Get personalized guidance for today')),
              trailing: IconButton(
                icon: Icon(
                  _showAiCoach ? Icons.expand_less : Icons.expand_more,
                ),
                onPressed: () {
                  setState(() => _showAiCoach = !_showAiCoach);
                  TelemetryService.instance.logEvent(
                    event: 'cta.clicked',
                    metadata: <String, dynamic>{
                      'module': 'learner_today',
                      'cta': 'daily_ai_${_showAiCoach ? 'show' : 'hide'}',
                      'surface': 'today_dashboard',
                    },
                  );
                },
              ),
            ),
          ),
          if (_showAiCoach) _buildAiCoachPanel(context, role),
        ],
      ),
    );
  }

  Widget _buildAiCoachPanel(BuildContext context, UserRole role) {
    final LearningRuntimeProvider? runtime =
        context.read<LearningRuntimeProvider?>();
    if (runtime == null) {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _t('AI coaching is loading'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              _t('Runtime context is syncing. Try again in a moment.'),
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: ScholesaColors.learner.withValues(alpha: 0.05),
        border: Border.all(
          color: ScholesaColors.learner.withValues(alpha: 0.1),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      constraints: const BoxConstraints(minHeight: 350),
      child: AiCoachWidget(
        runtime: runtime,
        actorRole: role,
        conceptTags: <String>[
          'daily_planning',
          'today_goals',
          'motivation',
        ],
      ),
    );
  }

  Widget _buildLearnerLoopInsights(BuildContext context) {
    final AppState appState = context.read<AppState>();
    final String? learnerId = appState.userId;
    return BosLearnerLoopInsightsCard(
      title: _t('BOS/MIA Learning Loop'),
      subtitle: _t('Latest individual improvement signal'),
      emptyLabel: _t('No learner loop data yet'),
      learnerId: learnerId,
      learnerName: appState.displayName,
      accentColor: ScholesaColors.learner,
    );
  }

}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.title,
    required this.completed,
    required this.total,
    required this.icon,
    required this.color,
    this.label,
  });
  final String title;
  final int completed;
  final int total;
  final IconData icon;
  final Color color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    String t(String input) {
      final String locale = Localizations.localeOf(context).languageCode;
      if (locale != 'es') return input;
      return _learnerTodayEs[input] ?? input;
    }
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double progress = total > 0 ? completed / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Text(
                '$completed',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                '/$total',
                style: TextStyle(
                  fontSize: 18,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                t(label ?? 'done'),
                style: TextStyle(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          TelemetryService.instance.logEvent(
            event: 'cta.clicked',
            metadata: <String, dynamic>{
              'cta': 'learner_today_quick_action',
              'label': label,
            },
          );
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: <Widget>[
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HabitTile extends StatelessWidget {
  const _HabitTile({required this.habit});
  final Habit habit;

  @override
  Widget build(BuildContext context) {
    String t(String input) {
      final String locale = Localizations.localeOf(context).languageCode;
      if (locale != 'es') return input;
      return _learnerTodayEs[input] ?? input;
    }
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: habit.isCompletedToday
              ? ScholesaColors.success.withValues(alpha: 0.3)
              : scheme.outlineVariant,
        ),
      ),
      child: Row(
        children: <Widget>[
          Text(habit.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  habit.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    decoration: habit.isCompletedToday
                        ? TextDecoration.lineThrough
                        : null,
                    color: habit.isCompletedToday
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                  ),
                ),
                Text(
                  '${habit.targetMinutes} min',
                  style: TextStyle(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
                      fontSize: 12),
                ),
              ],
            ),
          ),
          if (habit.isCompletedToday)
            const Icon(Icons.check_circle, color: ScholesaColors.success)
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: ScholesaColors.learner,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                t('Start'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MissionTile extends StatelessWidget {
  const _MissionTile({required this.mission});
  final Mission mission;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(mission.pillar.emoji,
                  style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  mission.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: mission.progress,
                          backgroundColor:
                              const Color(0xFFF59E0B).withValues(alpha: 0.1),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFF59E0B)),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(mission.progress * 100).toInt()}%',
                      style: const TextStyle(
                        color: Color(0xFFB45309),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

