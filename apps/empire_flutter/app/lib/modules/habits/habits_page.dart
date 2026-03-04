import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';
import '../../runtime/runtime.dart';
import '../../auth/app_state.dart';
import 'habit_models.dart';
import 'habit_service.dart';

const Map<String, String> _habitsEs = <String, String>{
  'Habit Coach': 'Entrenador de hábitos',
  'Build powerful daily routines': 'Crea rutinas diarias poderosas',
  'Today': 'Hoy',
  'Weekly Progress': 'Progreso semanal',
  'completions': 'completaciones',
  'Rate': 'Tasa',
  'All': 'Todas',
  'No': 'No',
  'habits yet': 'hábitos aún',
  'Start building your habits!': '¡Comienza a construir tus hábitos!',
  'Tap + to create your first habit': 'Pulsa + para crear tu primer hábito',
  'min': 'min',
  'completed!': '¡completado!',
  'New Habit': 'Nuevo hábito',
  'Current Streak': 'Racha actual',
  'Best Streak': 'Mejor racha',
  'Total Done': 'Total completado',
  'Target Time': 'Tiempo objetivo',
  'Settings': 'Configuración',
  'Frequency': 'Frecuencia',
  'Preferred Time': 'Horario preferido',
  'Started': 'Iniciado',
  'Create Habit': 'Crear hábito',
  'Choose an emoji': 'Elige un emoji',
  'Habit name': 'Nombre del hábito',
  'e.g., Morning Reading': 'ej., Lectura matutina',
  'Description (optional)': 'Descripción (opcional)',
  'What does this habit involve?': '¿En qué consiste este hábito?',
  'Category': 'Categoría',
  'Target time': 'Tiempo objetivo',
  'minutes': 'minutos',
  'Please enter a habit name': 'Ingresa un nombre de hábito',
  'created!': '¡creado!',
  'Reflect with AI': 'Reflexiona con IA',
  'Get coaching on your progress': 'Obtén orientación sobre tu progreso',
  'Hide AI Reflection': 'Ocultar reflexión de IA',
};

String _tHabits(BuildContext context, String input) {
  final String locale = Localizations.localeOf(context).languageCode;
  if (locale != 'es') return input;
  return _habitsEs[input] ?? input;
}

/// Beautiful habit tracking page for learners
class HabitsPage extends StatefulWidget {
  const HabitsPage({super.key});

  @override
  State<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<HabitsPage> with TickerProviderStateMixin {
  HabitCategory? _selectedCategory;
  late AnimationController _celebrationController;

  @override
  void initState() {
    super.initState();
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HabitService>().loadHabits();
    });
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.schSurfaceMuted,
      body: Consumer<HabitService>(
        builder: (BuildContext context, HabitService service, _) {
          if (service.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: ScholesaColors.learner),
            );
          }

          return CustomScrollView(
            slivers: <Widget>[
              _buildHeader(service),
              _buildStreakCard(service),
              _buildCategoryFilter(),
              _buildHabitsList(service),
              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          );
        },
      ),
      floatingActionButton: _buildAddHabitFab(),
    );
  }

  Widget _buildHeader(HabitService service) {
    return SliverToBoxAdapter(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              ScholesaColors.learner,
              ScholesaColors.learner.withValues(alpha: 0.8),
              const Color(0xFF10B981), // Green accent
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: () {
                        TelemetryService.instance.logEvent(
                          event: 'cta.clicked',
                          metadata: const <String, dynamic>{
                            'cta': 'habits_back'
                          },
                        );
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const Spacer(),
                    _buildTodayProgressBadge(service),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '🌟',
                        style: TextStyle(fontSize: 40),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _tHabits(context, 'Habit Coach'),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _tHabits(context, 'Build powerful daily routines'),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTodayProgressBadge(HabitService service) {
    final int completed = service.completedTodayCount;
    final int total = service.totalTodayCount;
    final double progress = service.todayProgress;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Stack(
            alignment: Alignment.center,
            children: <Widget>[
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 4,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress == 1.0 ? Colors.green : ScholesaColors.learner,
                  ),
                ),
              ),
              Text(
                progress == 1.0 ? '✓' : '$completed',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color:
                      progress == 1.0 ? Colors.green : ScholesaColors.learner,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _tHabits(context, 'Today'),
                style: TextStyle(
                  fontSize: 10,
                  color: context.schTextSecondary,
                ),
              ),
              Text(
                '$completed/$total',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard(HabitService service) {
    final WeeklyHabitSummary? summary = service.weeklySummary;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Colors.orange.shade400,
                Colors.deepOrange.shade400,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.orange.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Text(
                          '🔥',
                          style: TextStyle(fontSize: 32),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              _tHabits(context, 'Weekly Progress'),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                            Text(
                              '${summary?.totalCompletions ?? 0} ${_tHabits(context, 'completions')}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildWeekDayDots(summary?.dailyCompletions ?? <bool>[]),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: <Widget>[
                    Text(
                      '${(summary?.completionRate ?? 0 * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _tHabits(context, 'Rate'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeekDayDots(List<bool> dailyCompletions) {
    const List<String> days = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final int today = DateTime.now().weekday - 1; // 0-indexed

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (int index) {
        final bool completed =
            index < dailyCompletions.length && dailyCompletions[index];
        final bool isToday = index == today;

        return Column(
          children: <Widget>[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: completed
                    ? Colors.white
                    : isToday
                        ? Colors.white.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border:
                    isToday ? Border.all(color: Colors.white, width: 2) : null,
              ),
              child: Center(
                child: completed
                    ? const Icon(Icons.check,
                        size: 18, color: Colors.deepOrange)
                    : Text(
                        days[index],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isToday ? Colors.white : Colors.white70,
                        ),
                      ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildCategoryFilter() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              _buildCategoryChip(null, _tHabits(context, 'All'), '✨'),
              ...HabitCategory.values
                  .map((HabitCategory cat) => _buildCategoryChip(
                        cat,
                        cat.label,
                        cat.emoji,
                      )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(
      HabitCategory? category, String label, String emoji) {
    final bool isSelected = _selectedCategory == category;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
        selected: isSelected,
        onSelected: (_) {
          TelemetryService.instance.logEvent(
            event: 'cta.clicked',
            metadata: <String, dynamic>{
              'cta': 'habits_select_category',
              'category': category?.name ?? 'all',
            },
          );
          setState(() {
            _selectedCategory = category;
          });
        },
        selectedColor: ScholesaColors.learner.withValues(alpha: 0.2),
        checkmarkColor: ScholesaColors.learner,
        backgroundColor: context.schSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? ScholesaColors.learner : Colors.grey[300]!,
          ),
        ),
      ),
    );
  }

  Widget _buildHabitsList(HabitService service) {
    List<Habit> habits = service.activeHabits;
    if (_selectedCategory != null) {
      habits =
          habits.where((Habit h) => h.category == _selectedCategory).toList();
    }

    if (habits.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                '🌱',
                style: TextStyle(fontSize: 64),
              ),
              const SizedBox(height: 16),
              Text(
                _selectedCategory != null
                    ? '${_tHabits(context, 'No')} ${_selectedCategory!.label.toLowerCase()} ${_tHabits(context, 'habits yet')}'
                    : _tHabits(context, 'Start building your habits!'),
                style: TextStyle(
                  fontSize: 18,
                  color: context.schTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _tHabits(context, 'Tap + to create your first habit'),
                style: TextStyle(
                  fontSize: 14,
                  color: context.schTextSecondary.withValues(alpha: 0.74),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (BuildContext context, int index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildHabitCard(service, habits[index]),
          ),
          childCount: habits.length,
        ),
      ),
    );
  }

  Widget _buildHabitCard(HabitService service, Habit habit) {
    final bool isCompletedToday = habit.isCompletedToday;
    final Color categoryColor = _getCategoryColor(habit.category);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border:
            isCompletedToday ? Border.all(color: Colors.green, width: 2) : null,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showHabitDetail(habit),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              // Emoji container
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      categoryColor.withValues(alpha: 0.2),
                      categoryColor.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    habit.emoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            habit.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              decoration: isCompletedToday
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: isCompletedToday
                                  ? Colors.grey
                                  : Colors.grey[800],
                            ),
                          ),
                        ),
                        if (habit.currentStreak > 0) ...<Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Text('🔥',
                                    style: TextStyle(fontSize: 12)),
                                const SizedBox(width: 4),
                                Text(
                                  '${habit.currentStreak}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        Icon(
                          _getTimeIcon(habit.preferredTime),
                          size: 14,
                          color:
                              context.schTextSecondary.withValues(alpha: 0.74),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          habit.preferredTime.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.schTextSecondary
                                .withValues(alpha: 0.88),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color:
                              context.schTextSecondary.withValues(alpha: 0.74),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${habit.targetMinutes} ${_tHabits(context, 'min')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.schTextSecondary
                                .withValues(alpha: 0.88),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Complete button
              _buildCompleteButton(service, habit, isCompletedToday),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompleteButton(
      HabitService service, Habit habit, bool isCompleted) {
    return GestureDetector(
      onTap: isCompleted
          ? null
          : () async {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'cta': 'habits_complete_habit',
                  'habit_id': habit.id,
                },
              );
              final bool success = await service.completeHabit(habit.id);
              if (success && mounted) {
                _celebrationController.forward(from: 0);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: <Widget>[
                        const Text('🎉 ', style: TextStyle(fontSize: 20)),
                        Text('${habit.title} ${_tHabits(context, 'completed!')}'),
                      ],
                    ),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          gradient: isCompleted
              ? const LinearGradient(
                  colors: <Color>[Colors.green, Colors.teal],
                )
              : LinearGradient(
                  colors: <Color>[
                    ScholesaColors.learner,
                    ScholesaColors.learner.withValues(alpha: 0.8),
                  ],
                ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: (isCompleted ? Colors.green : ScholesaColors.learner)
                  .withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          isCompleted ? Icons.check_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildAddHabitFab() {
    return FloatingActionButton.extended(
      onPressed: () {
        TelemetryService.instance.logEvent(
          event: 'cta.clicked',
          metadata: const <String, dynamic>{'cta': 'habits_open_create_sheet'},
        );
        _showCreateHabitSheet();
      },
      backgroundColor: ScholesaColors.learner,
      icon: const Icon(Icons.add),
      label: Text(_tHabits(context, 'New Habit')),
    );
  }

  Future<void> _showHabitDetail(Habit habit) async {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'habits_open_detail',
        'habit_id': habit.id
      },
    );
    bool popupCompleted = false;
    TelemetryService.instance.logEvent(
      event: 'popup.shown',
      metadata: <String, dynamic>{
        'popup_id': 'habit_detail_sheet',
        'surface': 'habits_page',
        'habit_id': habit.id,
      },
    );
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => _HabitDetailSheet(
        habit: habit,
        onDismissed: () {
          popupCompleted = true;
        },
      ),
    );
    if (!popupCompleted) {
      TelemetryService.instance.logEvent(
        event: 'popup.dismissed',
        metadata: <String, dynamic>{
          'popup_id': 'habit_detail_sheet',
          'surface': 'habits_page',
          'habit_id': habit.id,
          'reason': 'closed_without_action',
        },
      );
    }
  }

  Future<void> _showCreateHabitSheet() async {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{'cta': 'habits_create_sheet_opened'},
    );
    bool popupCompleted = false;
    TelemetryService.instance.logEvent(
      event: 'popup.shown',
      metadata: const <String, dynamic>{
        'popup_id': 'habit_create_sheet',
        'surface': 'habits_page',
      },
    );
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => _CreateHabitSheet(
        onCompleted: () {
          popupCompleted = true;
        },
        onDismissed: () {
          popupCompleted = true;
        },
      ),
    );
    if (!popupCompleted) {
      TelemetryService.instance.logEvent(
        event: 'popup.dismissed',
        metadata: const <String, dynamic>{
          'popup_id': 'habit_create_sheet',
          'surface': 'habits_page',
          'reason': 'closed_without_action',
        },
      );
    }
  }

  Color _getCategoryColor(HabitCategory category) {
    switch (category) {
      case HabitCategory.learning:
        return const Color(0xFF3B82F6); // Blue
      case HabitCategory.health:
        return Colors.green;
      case HabitCategory.mindfulness:
        return const Color(0xFF8B5CF6); // Purple
      case HabitCategory.social:
        return const Color(0xFF10B981); // Teal
      case HabitCategory.creativity:
        return Colors.purple;
      case HabitCategory.productivity:
        return Colors.blue;
    }
  }

  IconData _getTimeIcon(HabitTimePreference time) {
    switch (time) {
      case HabitTimePreference.morning:
        return Icons.wb_sunny_outlined;
      case HabitTimePreference.afternoon:
        return Icons.wb_cloudy_outlined;
      case HabitTimePreference.evening:
        return Icons.nights_stay_outlined;
      case HabitTimePreference.anytime:
        return Icons.schedule_outlined;
    }
  }
}

/// Habit detail bottom sheet
class _HabitDetailSheet extends StatefulWidget {
  const _HabitDetailSheet({
    required this.habit,
    required this.onDismissed,
  });
  final Habit habit;
  final VoidCallback onDismissed;

  @override
  State<_HabitDetailSheet> createState() => _HabitDetailSheetState();
}

class _HabitDetailSheetState extends State<_HabitDetailSheet> {
  bool _showAiReflection = false;

  @override
  Widget build(BuildContext context) {
    final Habit habit = widget.habit;
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Header
            Row(
              children: <Widget>[
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: ScholesaColors.learner.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      habit.emoji,
                      style: const TextStyle(fontSize: 36),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        habit.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: ScholesaColors.learner.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          habit.category.label,
                          style: const TextStyle(
                            fontSize: 12,
                            color: ScholesaColors.learner,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: <String, dynamic>{
                        'cta': 'habits_close_detail',
                        'habit_id': habit.id,
                      },
                    );
                    TelemetryService.instance.logEvent(
                      event: 'popup.dismissed',
                      metadata: <String, dynamic>{
                        'popup_id': 'habit_detail_sheet',
                        'surface': 'habits_page',
                        'habit_id': habit.id,
                      },
                    );
                    widget.onDismissed();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (habit.description != null) ...<Widget>[
              const SizedBox(height: 16),
              Text(
                habit.description!,
                style: TextStyle(
                  fontSize: 14,
                  color: context.schTextSecondary,
                ),
              ),
            ],
            const SizedBox(height: 24),
            // Stats grid
            Row(
              children: <Widget>[
                Expanded(
                  child: _buildStatCard(
                    context,
                    '🔥',
                    '${habit.currentStreak}',
                    _tHabits(context, 'Current Streak'),
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    '🏆',
                    '${habit.longestStreak}',
                    _tHabits(context, 'Best Streak'),
                    Colors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _buildStatCard(
                    context,
                    '✅',
                    '${habit.totalCompletions}',
                    _tHabits(context, 'Total Done'),
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    '⏱️',
                    '${habit.targetMinutes}m',
                    _tHabits(context, 'Target Time'),
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Settings
            Text(
              _tHabits(context, 'Settings'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingRow(
              context,
              Icons.repeat,
              _tHabits(context, 'Frequency'),
              habit.frequency.name.toUpperCase(),
            ),
            _buildSettingRow(
              context,
              Icons.schedule,
              _tHabits(context, 'Preferred Time'),
              habit.preferredTime.label,
            ),
            _buildSettingRow(
              context,
              Icons.calendar_today,
              _tHabits(context, 'Started'),
              _formatDate(habit.createdAt),
            ),
            const SizedBox(height: 24),

            // AI Reflection Section
            _buildAiReflectionSection(context),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAiReflectionSection(BuildContext context) {
    final AppState appState = context.read<AppState>();
    final String learnerId = appState.userId ?? '';
    final UserRole? role = appState.role;

    if (learnerId.isEmpty || role == null || role != UserRole.learner) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ScholesaColors.learner.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: ScholesaColors.learner.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.smart_toy_rounded,
                      color: ScholesaColors.learner, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _tHabits(context, 'Reflect with AI'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: ScholesaColors.learner,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () {
                  TelemetryService.instance.logEvent(
                    event: 'cta.clicked',
                    metadata: <String, dynamic>{
                      'cta': _showAiReflection
                          ? 'habit_ai_hide'
                          : 'habit_ai_show',
                      'habit_id': widget.habit.id,
                      'surface': 'habit_detail_sheet',
                    },
                  );
                  setState(() => _showAiReflection = !_showAiReflection);
                },
                icon: Icon(
                  _showAiReflection
                      ? Icons.expand_less
                      : Icons.expand_more,
                  color: ScholesaColors.learner,
                ),
              ),
            ],
          ),
          if (!_showAiReflection) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _tHabits(context, 'Get coaching on your progress'),
              style: TextStyle(
                color: context.schTextSecondary,
                fontSize: 13,
              ),
            ),
          ],
          if (_showAiReflection) ...<Widget>[
            const SizedBox(height: 16),
            _buildAiReflectionPanel(context, role),
          ],
        ],
      ),
    );
  }

  Widget _buildAiReflectionPanel(
      BuildContext context, UserRole role) {
    final LearningRuntimeProvider? runtime =
        context.read<LearningRuntimeProvider?>();
    if (runtime == null) {
      return Center(
        child: Text(
          'AI Coach not available',
          style: TextStyle(color: context.schTextSecondary),
        ),
      );
    }

    return SizedBox(
      height: 400,
      child: AiCoachWidget(
        runtime: runtime,
        actorRole: role,
        conceptTags: <String>['habit_reflection', widget.habit.title],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String emoji, String value,
      String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: context.schTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow(
      BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Icon(icon,
              size: 20,
              color: context.schTextSecondary.withValues(alpha: 0.88)),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: context.schTextSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

/// Create new habit bottom sheet
class _CreateHabitSheet extends StatefulWidget {
  const _CreateHabitSheet({
    required this.onCompleted,
    required this.onDismissed,
  });

  final VoidCallback onCompleted;
  final VoidCallback onDismissed;

  @override
  State<_CreateHabitSheet> createState() => _CreateHabitSheetState();
}

class _CreateHabitSheetState extends State<_CreateHabitSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedEmoji = '⭐';
  HabitCategory _selectedCategory = HabitCategory.learning;
  HabitFrequency _selectedFrequency = HabitFrequency.daily;
  final HabitTimePreference _selectedTime = HabitTimePreference.anytime;
  int _targetMinutes = 15;

  final List<String> _emojis = <String>[
    '📖',
    '💻',
    '🧘',
    '✍️',
    '🏃',
    '🤝',
    '🎨',
    '🎵',
    '🌱',
    '💪',
    '🧠',
    '❤️',
    '📝',
    '🎯',
    '⭐',
    '🌟',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  _tHabits(context, 'Create Habit'),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: const <String, dynamic>{
                        'cta': 'habits_create_sheet_close'
                      },
                    );
                    TelemetryService.instance.logEvent(
                      event: 'popup.dismissed',
                      metadata: const <String, dynamic>{
                        'popup_id': 'habit_create_sheet',
                        'surface': 'habits_page',
                      },
                    );
                    widget.onDismissed();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Emoji picker
            Text(
              _tHabits(context, 'Choose an emoji'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _emojis.map((String emoji) {
                final bool isSelected = emoji == _selectedEmoji;
                return GestureDetector(
                  onTap: () {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: <String, dynamic>{
                        'cta': 'habits_create_select_emoji',
                        'emoji': emoji,
                      },
                    );
                    setState(() => _selectedEmoji = emoji);
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? ScholesaColors.learner.withValues(alpha: 0.2)
                          : context.schSurfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: ScholesaColors.learner, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            // Title
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: _tHabits(context, 'Habit name'),
                hintText: _tHabits(context, 'e.g., Morning Reading'),
                filled: true,
                fillColor: context.schSurfaceMuted,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Description
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: _tHabits(context, 'Description (optional)'),
                hintText: _tHabits(context, 'What does this habit involve?'),
                filled: true,
                fillColor: context.schSurfaceMuted,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Category
            Text(
              _tHabits(context, 'Category'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: HabitCategory.values.map((HabitCategory cat) {
                final bool isSelected = cat == _selectedCategory;
                return ChoiceChip(
                  label: Text('${cat.emoji} ${cat.label}'),
                  selected: isSelected,
                  onSelected: (_) {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: <String, dynamic>{
                        'cta': 'habits_create_select_category',
                        'category': cat.name,
                      },
                    );
                    setState(() => _selectedCategory = cat);
                  },
                  selectedColor: ScholesaColors.learner.withValues(alpha: 0.2),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            // Frequency
            Text(
              _tHabits(context, 'Frequency'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: HabitFrequency.values.map((HabitFrequency freq) {
                final bool isSelected = freq == _selectedFrequency;
                return ChoiceChip(
                  label: Text(freq.name),
                  selected: isSelected,
                  onSelected: (_) {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: <String, dynamic>{
                        'cta': 'habits_create_select_frequency',
                        'frequency': freq.name,
                      },
                    );
                    setState(() => _selectedFrequency = freq);
                  },
                  selectedColor: ScholesaColors.learner.withValues(alpha: 0.2),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            // Target minutes
            Row(
              children: <Widget>[
                Text(
                  _tHabits(context, 'Target time'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  '$_targetMinutes ${_tHabits(context, 'minutes')}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: ScholesaColors.learner,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Slider(
              value: _targetMinutes.toDouble(),
              min: 5,
              max: 60,
              divisions: 11,
              activeColor: ScholesaColors.learner,
              onChanged: (double val) =>
                  setState(() => _targetMinutes = val.round()),
            ),
            const SizedBox(height: 24),
            // Create button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _createHabit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ScholesaColors.learner,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _tHabits(context, 'Create Habit'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _createHabit() {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tHabits(context, 'Please enter a habit name'))),
      );
      return;
    }

    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'habits_create_habit',
        'category': _selectedCategory.name,
        'frequency': _selectedFrequency.name,
      },
    );
    TelemetryService.instance.logEvent(
      event: 'popup.completed',
      metadata: <String, dynamic>{
        'popup_id': 'habit_create_sheet',
        'surface': 'habits_page',
        'completion_action': 'create_habit',
        'category': _selectedCategory.name,
        'frequency': _selectedFrequency.name,
      },
    );

    context.read<HabitService>().createHabit(
          title: _titleController.text,
          description: _descriptionController.text.isEmpty
              ? null
              : _descriptionController.text,
          emoji: _selectedEmoji,
          category: _selectedCategory,
          frequency: _selectedFrequency,
          preferredTime: _selectedTime,
          targetMinutes: _targetMinutes,
        );

    widget.onCompleted();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: <Widget>[
            const Text('🌱 ', style: TextStyle(fontSize: 20)),
            Text('${_titleController.text} ${_tHabits(context, 'created!')}'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

extension on Color {
  Color get shade700 => HSLColor.fromColor(this).withLightness(0.35).toColor();
}
