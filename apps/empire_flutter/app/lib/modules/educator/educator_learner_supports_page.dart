import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';
import '../../runtime/runtime.dart';
import '../../i18n/bos_coaching_i18n.dart';
import '../../auth/app_state.dart';
import 'educator_models.dart';
import 'educator_service.dart';

const Map<String, String> _educatorLearnerSupportsEs = <String, String>{
  'Learner Supports': 'Apoyos del estudiante',
  'Active Support Plans': 'Planes de apoyo activos',
  'High Priority': 'Alta prioridad',
  'Active Plans': 'Planes activos',
  'Reviews Due': 'Revisiones pendientes',
  'High': 'Alta',
  'Medium': 'Media',
  'Low': 'Baja',
  'Academic': 'Académico',
  'Social-Emotional': 'Socioemocional',
  'Behavioral': 'Conductual',
  'Extended time': 'Tiempo extendido',
  'Quiet space': 'Espacio tranquilo',
  'Check-in support': 'Apoyo de seguimiento',
  'Peer buddy': 'Compañero de apoyo',
  'Movement breaks': 'Pausas de movimiento',
  'Clear transitions': 'Transiciones claras',
  'Responds well to visual aids': 'Responde bien a ayudas visuales',
  'Building confidence in group settings':
      'Fortaleciendo la confianza en entornos grupales',
  'Use positive reinforcement': 'Usar refuerzo positivo',
  'Note': 'Nota',
  'Support Plan': 'Plan de apoyo',
  'Accommodations': 'Adaptaciones',
  'Notes': 'Notas',
  'No notes': 'Sin notas',
  'Close': 'Cerrar',
  'Edit Plan': 'Editar plan',
  'Search Learner Supports': 'Buscar apoyos del estudiante',
  'Enter learner name or support tag':
      'Ingresa el nombre del estudiante o etiqueta de apoyo',
  'Cancel': 'Cancelar',
  'Search': 'Buscar',
  'Found': 'Se encontraron',
  'matching support plans': 'planes de apoyo coincidentes',
  'Log Support Outcome': 'Registrar resultado del apoyo',
  'Select the outcome from this support action.':
      'Selecciona el resultado de esta acción de apoyo.',
  'Partial': 'Parcial',
  'No Change': 'Sin cambios',
  'Helped': 'Ayudó',
  'Support outcome logged': 'Resultado de apoyo registrado',
  'No support plans yet': 'Aún no hay planes de apoyo',
  'Loading...': 'Cargando...',
  'Support AI Coach': 'Coach IA de apoyos',
  'Keep BOS/MIA loop active for each learner support plan':
      'Mantén activo el ciclo BOS/MIA para cada plan de apoyo del estudiante',
  'BOS/MIA Support Loop': 'Ciclo de apoyo BOS/MIA',
  'Latest individual improvement signal for support planning':
      'Señal de mejora individual más reciente para planificación de apoyos',
  'No support loop data yet': 'Sin datos de ciclo de apoyo aún',
};

String _tEducatorLearnerSupports(BuildContext context, String input) {
  final String locale = Localizations.localeOf(context).languageCode;
  if (locale != 'es') return input;
  return _educatorLearnerSupportsEs[input] ?? input;
}

/// Educator learner supports page for tracking learner wellbeing & accommodations
/// Based on docs/09_LEARNER_SUPPORT_ACCOMMODATIONS_SPEC.md
class EducatorLearnerSupportsPage extends StatefulWidget {
  const EducatorLearnerSupportsPage({super.key});

  @override
  State<EducatorLearnerSupportsPage> createState() =>
      _EducatorLearnerSupportsPageState();
}

class _EducatorLearnerSupportsPageState
    extends State<EducatorLearnerSupportsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EducatorService>().loadLearners();
    });
    TelemetryService.instance.logEvent(
      event: 'insight.viewed',
      metadata: const <String, dynamic>{
        'surface': 'educator_learner_supports',
        'insight_type': 'support_overview',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: Text(_tEducatorLearnerSupports(context, 'Learner Supports')),
        backgroundColor: ScholesaColors.educatorGradient.colors.first,
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: _showSearchDialog,
          ),
        ],
      ),
      body: Consumer<EducatorService>(
        builder: (BuildContext context, EducatorService service, _) {
          final List<_LearnerSupport> supports = _supportsFromService(service);
          if (service.isLoading && supports.isEmpty) {
            return Center(
              child: Text(
                _tEducatorLearnerSupports(context, 'Loading...'),
                style: const TextStyle(color: ScholesaColors.textSecondary),
              ),
            );
          }

          if (supports.isEmpty) {
            return Center(
              child: Text(
                _tEducatorLearnerSupports(context, 'No support plans yet'),
                style: const TextStyle(color: ScholesaColors.textSecondary),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              AiContextCoachSection(
                title: _tEducatorLearnerSupports(context, 'Support AI Coach'),
                subtitle: _tEducatorLearnerSupports(
                  context,
                  'Keep BOS/MIA loop active for each learner support plan',
                ),
                module: 'educator_learner_supports',
                surface: 'support_plans',
                actorRole: UserRole.educator,
                accentColor: ScholesaColors.educator,
                conceptTags: const <String>[
                  'learner_supports',
                  'accommodations',
                  'wellbeing',
                ],
              ),
              if (service.learners.isNotEmpty)
                BosLearnerLoopInsightsCard(
                  title: BosCoachingI18n.sessionLoopTitle(context),
                  subtitle: BosCoachingI18n.sessionLoopSubtitle(context),
                  emptyLabel: BosCoachingI18n.sessionLoopEmpty(context),
                  learnerId: service.learners.first.id,
                  learnerName: service.learners.first.name,
                  accentColor: ScholesaColors.educator,
                ),
              _buildSummaryCards(supports),
              const SizedBox(height: 24),
              Text(
                _tEducatorLearnerSupports(context, 'Active Support Plans'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ScholesaColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ...supports.map((support) => _buildSupportCard(support)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCards(List<_LearnerSupport> supports) {
    final int highPriorityCount =
        supports.where((_LearnerSupport s) => s.priority == _Priority.high).length;
    final DateTime now = DateTime.now();
    final int reviewsDue = supports
        .where((_LearnerSupport support) =>
            now.difference(support.lastUpdated).inDays >= 7)
        .length;

    return Row(
      children: <Widget>[
        Expanded(
          child: _buildSummaryCard(
            _tEducatorLearnerSupports(context, 'High Priority'),
            highPriorityCount.toString(),
            Colors.red,
            Icons.priority_high_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            _tEducatorLearnerSupports(context, 'Active Plans'),
            supports.length.toString(),
            Colors.blue,
            Icons.people_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            _tEducatorLearnerSupports(context, 'Reviews Due'),
            reviewsDue.toString(),
            Colors.orange,
            Icons.schedule_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
      String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ScholesaColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: ScholesaColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSupportCard(_LearnerSupport support) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showSupportDetails(support),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: ScholesaColors
                        .educatorGradient.colors.first
                        .withValues(alpha: 0.2),
                    child: Text(
                      support.learnerName.substring(0, 1),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: ScholesaColors.educatorGradient.colors.first,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          support.learnerName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: ScholesaColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _tEducatorLearnerSupports(context, support.supportType),
                          style: const TextStyle(
                            fontSize: 13,
                            color: ScholesaColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildPriorityBadge(support.priority),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: support.accommodations
                    .map((String a) => _buildAccommodationChip(
                        _tEducatorLearnerSupports(context, a)))
                    .toList(),
              ),
              if (support.notes.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  '${_tEducatorLearnerSupports(context, 'Note')}: ${_tEducatorLearnerSupports(context, support.notes)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: ScholesaColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(_Priority priority) {
    Color color;
    String label;
    switch (priority) {
      case _Priority.high:
        color = Colors.red;
        label = _tEducatorLearnerSupports(context, 'High');
      case _Priority.medium:
        color = Colors.orange;
        label = _tEducatorLearnerSupports(context, 'Medium');
      case _Priority.low:
        color = Colors.green;
        label = _tEducatorLearnerSupports(context, 'Low');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildAccommodationChip(String accommodation) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Text(
        accommodation,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.blue,
        ),
      ),
    );
  }

  Future<void> _showSupportDetails(_LearnerSupport support) async {
    bool popupCompleted = false;
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'educator_learner_supports',
        'cta_id': 'open_support_details',
        'surface': 'support_card',
        'learner_id': support.learnerId,
        'priority': support.priority.name,
      },
    );
    TelemetryService.instance.logEvent(
      event: 'insight.viewed',
      metadata: <String, dynamic>{
        'surface': 'educator_learner_supports',
        'insight_type': 'learner_support_plan',
        'learner_id': support.learnerId,
        'support_type': support.supportType,
      },
    );
    TelemetryService.instance.logEvent(
      event: 'popup.shown',
      metadata: <String, dynamic>{
        'popup_id': 'support_details_sheet',
        'surface': 'educator_learner_supports',
        'learner_id': support.learnerId,
      },
    );
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ScholesaColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (BuildContext context, ScrollController scrollController) =>
            ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 30,
                  backgroundColor: ScholesaColors.educatorGradient.colors.first
                      .withValues(alpha: 0.2),
                  child: Text(
                    support.learnerName.substring(0, 1),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: ScholesaColors.educatorGradient.colors.first,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        support.learnerName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_tEducatorLearnerSupports(context, 'Support Plan')} • ${_tEducatorLearnerSupports(context, support.supportType)}',
                        style: const TextStyle(
                            color: ScholesaColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              _tEducatorLearnerSupports(context, 'Accommodations'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...support.accommodations.map((String a) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Text(_tEducatorLearnerSupports(context, a)),
                    ],
                  ),
                )),
            const SizedBox(height: 16),
            Text(
              _tEducatorLearnerSupports(context, 'Notes'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              support.notes.isNotEmpty
                  ? _tEducatorLearnerSupports(context, support.notes)
                  : _tEducatorLearnerSupports(context, 'No notes'),
              style: const TextStyle(color: ScholesaColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: <String, dynamic>{
                          'module': 'educator_learner_supports',
                          'cta_id': 'close_support_details',
                          'surface': 'support_details_sheet',
                          'learner_id': support.learnerId,
                        },
                      );
                      TelemetryService.instance.logEvent(
                        event: 'popup.dismissed',
                        metadata: <String, dynamic>{
                          'popup_id': 'support_details_sheet',
                          'surface': 'educator_learner_supports',
                          'learner_id': support.learnerId,
                        },
                      );
                      popupCompleted = true;
                      Navigator.pop(context);
                    },
                    child: Text(_tEducatorLearnerSupports(context, 'Close')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: <String, dynamic>{
                          'module': 'educator_learner_supports',
                          'cta_id': 'edit_support_plan',
                          'surface': 'support_details_sheet',
                          'learner_id': support.learnerId,
                        },
                      );
                      TelemetryService.instance.logEvent(
                        event: 'support.applied',
                        metadata: <String, dynamic>{
                          'learner_id': support.learnerId,
                          'support_type': support.supportType,
                          'priority': support.priority.name,
                          'action': 'edit_support_plan',
                        },
                      );
                      TelemetryService.instance.logEvent(
                        event: 'popup.completed',
                        metadata: <String, dynamic>{
                          'popup_id': 'support_details_sheet',
                          'surface': 'educator_learner_supports',
                          'completion_action': 'edit_support_plan',
                          'learner_id': support.learnerId,
                        },
                      );
                      popupCompleted = true;
                      Navigator.pop(context);
                      _showOutcomeDialog(support);
                    },
                    child:
                        Text(_tEducatorLearnerSupports(context, 'Edit Plan')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (!popupCompleted) {
      TelemetryService.instance.logEvent(
        event: 'popup.dismissed',
        metadata: <String, dynamic>{
          'popup_id': 'support_details_sheet',
          'surface': 'educator_learner_supports',
          'learner_id': support.learnerId,
          'reason': 'closed_without_action',
        },
      );
    }
  }

  Future<void> _showSearchDialog() async {
    final List<_LearnerSupport> supports =
        _supportsFromService(context.read<EducatorService>());
    bool popupCompleted = false;
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'educator_learner_supports',
        'cta_id': 'open_search_dialog',
        'surface': 'appbar',
      },
    );
    TelemetryService.instance.logEvent(
      event: 'popup.shown',
      metadata: const <String, dynamic>{
        'popup_id': 'support_search_dialog',
        'surface': 'educator_learner_supports',
      },
    );
    final TextEditingController controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title:
            Text(_tEducatorLearnerSupports(context, 'Search Learner Supports')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: _tEducatorLearnerSupports(
                context, 'Enter learner name or support tag'),
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'module': 'educator_learner_supports',
                  'cta_id': 'cancel_search',
                  'surface': 'search_dialog',
                },
              );
              TelemetryService.instance.logEvent(
                event: 'popup.dismissed',
                metadata: const <String, dynamic>{
                  'popup_id': 'support_search_dialog',
                  'surface': 'educator_learner_supports',
                },
              );
              popupCompleted = true;
              Navigator.pop(dialogContext);
            },
            child: Text(_tEducatorLearnerSupports(context, 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              final String query = controller.text.trim().toLowerCase();
              final int matches = supports
                  .where((support) =>
                      support.learnerName.toLowerCase().contains(query))
                  .length;
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'module': 'educator_learner_supports',
                  'cta_id': 'submit_search',
                  'surface': 'search_dialog',
                  'query_length': query.length,
                  'matches': matches,
                },
              );
              TelemetryService.instance.logEvent(
                event: 'popup.completed',
                metadata: <String, dynamic>{
                  'popup_id': 'support_search_dialog',
                  'surface': 'educator_learner_supports',
                  'completion_action': 'search',
                  'matches': matches,
                },
              );
              popupCompleted = true;
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        '${_tEducatorLearnerSupports(context, 'Found')} $matches ${_tEducatorLearnerSupports(context, 'matching support plans')}')),
              );
            },
            child: Text(_tEducatorLearnerSupports(context, 'Search')),
          ),
        ],
      ),
    );
    if (!popupCompleted) {
      TelemetryService.instance.logEvent(
        event: 'popup.dismissed',
        metadata: const <String, dynamic>{
          'popup_id': 'support_search_dialog',
          'surface': 'educator_learner_supports',
          'reason': 'closed_without_action',
        },
      );
    }
  }

  Future<void> _showOutcomeDialog(_LearnerSupport support) async {
    TelemetryService.instance.logEvent(
      event: 'popup.shown',
      metadata: <String, dynamic>{
        'popup_id': 'support_outcome_dialog',
        'surface': 'educator_learner_supports',
        'learner_id': support.learnerId,
      },
    );

    final String? outcome = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(_tEducatorLearnerSupports(context, 'Log Support Outcome')),
        content: Text(
          _tEducatorLearnerSupports(
              context, 'Select the outcome from this support action.'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'popup.dismissed',
                metadata: const <String, dynamic>{
                  'popup_id': 'support_outcome_dialog',
                  'surface': 'educator_learner_supports',
                },
              );
              Navigator.pop(dialogContext, null);
            },
            child: Text(_tEducatorLearnerSupports(context, 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'partial'),
            child: Text(_tEducatorLearnerSupports(context, 'Partial')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'no_change'),
            child: Text(_tEducatorLearnerSupports(context, 'No Change')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, 'helped'),
            child: Text(_tEducatorLearnerSupports(context, 'Helped')),
          ),
        ],
      ),
    );

    if (outcome == null) {
      return;
    }

    TelemetryService.instance.logEvent(
      event: 'support.outcome.logged',
      metadata: <String, dynamic>{
        'learner_id': support.learnerId,
        'support_type': support.supportType,
        'priority': support.priority.name,
        'outcome': outcome,
      },
    );
    TelemetryService.instance.logEvent(
      event: 'popup.completed',
      metadata: <String, dynamic>{
        'popup_id': 'support_outcome_dialog',
        'surface': 'educator_learner_supports',
        'completion_action': 'log_outcome',
        'outcome': outcome,
      },
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              '${_tEducatorLearnerSupports(context, 'Support outcome logged')}: $outcome')),
    );
  }

  List<_LearnerSupport> _supportsFromService(EducatorService service) {
    final List<EducatorLearner> learners = service.learners;
    final List<_LearnerSupport> supports = <_LearnerSupport>[];

    for (int index = 0; index < learners.length; index++) {
      final EducatorLearner learner = learners[index];
      final _Priority priority = _priorityForLearner(learner);
      final String supportType = _supportTypeForIndex(index);
      supports.add(
        _LearnerSupport(
          learnerId: learner.id,
          learnerName: learner.name,
          avatarUrl: learner.photoUrl,
          supportType: supportType,
          accommodations: _accommodationsForPriority(priority),
          notes: _supportNoteForPriority(priority),
          lastUpdated: DateTime.now().subtract(Duration(days: (index % 10) + 1)),
          priority: priority,
        ),
      );
    }

    return supports;
  }

  _Priority _priorityForLearner(EducatorLearner learner) {
    if (learner.attendanceRate < 60) {
      return _Priority.high;
    }
    if (learner.attendanceRate < 80) {
      return _Priority.medium;
    }
    return _Priority.low;
  }

  String _supportTypeForIndex(int index) {
    switch (index % 3) {
      case 0:
        return 'Academic';
      case 1:
        return 'Social-Emotional';
      default:
        return 'Behavioral';
    }
  }

  List<String> _accommodationsForPriority(_Priority priority) {
    switch (priority) {
      case _Priority.high:
        return <String>['Check-in support', 'Peer buddy'];
      case _Priority.medium:
        return <String>['Extended time', 'Quiet space'];
      case _Priority.low:
        return <String>['Movement breaks', 'Clear transitions'];
    }
  }

  String _supportNoteForPriority(_Priority priority) {
    switch (priority) {
      case _Priority.high:
        return 'Building confidence in group settings';
      case _Priority.medium:
        return 'Responds well to visual aids';
      case _Priority.low:
        return 'Use positive reinforcement';
    }
  }
}

enum _Priority { high, medium, low }

class _LearnerSupport {
  const _LearnerSupport({
    required this.learnerId,
    required this.learnerName,
    required this.avatarUrl,
    required this.supportType,
    required this.accommodations,
    required this.notes,
    required this.lastUpdated,
    required this.priority,
  });

  final String learnerId;
  final String learnerName;
  final String? avatarUrl;
  final String supportType;
  final List<String> accommodations;
  final String notes;
  final DateTime lastUpdated;
  final _Priority priority;
}
