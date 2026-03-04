import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';
import '../../runtime/runtime.dart';
import '../../auth/app_state.dart';
import '../../i18n/bos_coaching_i18n.dart';
import 'educator_models.dart';
import 'educator_service.dart';

const Map<String, String> _educatorLearnersEs = <String, String>{
  'My Learners': 'Mis estudiantes',
  'Track progress and engagement': 'Sigue progreso y compromiso',
  'Search learners...': 'Buscar estudiantes...',
  'All Sessions': 'Todas las sesiones',
  'Total Learners': 'Total de estudiantes',
  'Active Today': 'Activos hoy',
  'ACTIVE': 'ACTIVO',
  'Pillar Progress': 'Progreso por pilar',
  'Future Skills': 'Habilidades del futuro',
  'Leadership': 'Liderazgo',
  'Impact': 'Impacto',
  'Message': 'Mensaje',
  'Full Profile': 'Perfil completo',
  'Learner AI Coach': 'Coach IA para estudiantes',
  'Keep BOS/MIA loop active for each learner':
      'Mantén activo el ciclo BOS/MIA para cada estudiante',
  'delta': 'delta',
};

String _tEducatorLearnersPageSpecific(BuildContext context, String input) {
  final String locale = Localizations.localeOf(context).languageCode;
  if (locale != 'es') return input;
  return _educatorLearnersEs[input] ?? input;
}

// Alias for backward compatibility
String _tEducatorLearners(BuildContext context, String input) {
  return _tEducatorLearnersPageSpecific(context, input);
}

/// Educator Learners Page - View and manage learner roster
class EducatorLearnersPage extends StatefulWidget {
  const EducatorLearnersPage({super.key});

  @override
  State<EducatorLearnersPage> createState() => _EducatorLearnersPageState();
}

class _EducatorLearnersPageState extends State<EducatorLearnersPage> {
  String _searchQuery = '';
  String _selectedSession = 'all';
  final TextEditingController _searchController = TextEditingController();
  bool _loopInsightsLoading = false;
  Map<String, dynamic>? _learnerLoopInsights;
  String? _loopLearnerName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final EducatorService service = context.read<EducatorService>();
      await service.loadLearners();
      if (!mounted || service.learners.isEmpty) {
        return;
      }
      await _loadLearnerLoopInsights(service.learners.first);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              ScholesaColors.educator.withValues(alpha: 0.05),
              Colors.white,
              ScholesaColors.learner.withValues(alpha: 0.03),
            ],
          ),
        ),
        child: Consumer<EducatorService>(
          builder: (BuildContext context, EducatorService service, _) {
            return CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildSearchBar()),
                SliverToBoxAdapter(child: _buildSessionFilter(service)),
                SliverToBoxAdapter(child: _buildStats(service)),
                SliverToBoxAdapter(child: _buildLearnerLoopCard()),
                SliverToBoxAdapter(
                  child: AiContextCoachSection(
                    title: _tEducatorLearnersPageSpecific(context, 'Learner AI Coach'),
                    subtitle: _tEducatorLearnersPageSpecific(
                        context, 'Keep BOS/MIA loop active for each learner'),
                    module: 'educator_learners',
                    surface: 'learners_roster',
                    actorRole: UserRole.educator,
                    accentColor: ScholesaColors.educator,
                    conceptTags: const <String>[
                      'educator_roster',
                      'learner_progress',
                      'individual_support',
                    ],
                  ),
                ),
                if (service.isLoading)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: ScholesaColors.educator,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (BuildContext context, int index) {
                          final List<EducatorLearner> learners =
                              _getFilteredLearners(service);
                          if (index >= learners.length) return null;
                          return _LearnerCard(
                            learner: learners[index],
                            onTap: () => _openLearnerDetail(learners[index]),
                          );
                        },
                        childCount: _getFilteredLearners(service).length,
                      ),
                    ),
                  ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _loadLearnerLoopInsights(EducatorLearner learner) async {
    final AppState? appState = context.read<AppState?>();
    final String? siteId = appState?.activeSiteId;
    if (siteId == null || siteId.isEmpty) {
      return;
    }

    setState(() {
      _loopInsightsLoading = true;
      _loopLearnerName = learner.name;
    });

    try {
      final Map<String, dynamic> insights =
          await BosService.instance.getLearnerLoopInsights(
        siteId: siteId,
        learnerId: learner.id,
        lookbackDays: 30,
      );
      if (!mounted) return;
      setState(() {
        _learnerLoopInsights = insights;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _learnerLoopInsights = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loopInsightsLoading = false;
        });
      }
    }
  }

  Widget _buildLearnerLoopCard() {
    final ThemeData theme = Theme.of(context);
    final Map<String, dynamic>? insights = _learnerLoopInsights;
    final Map<String, dynamic> trend =
        (insights?['trend'] as Map<String, dynamic>?) ??
            <String, dynamic>{};
    final Map<String, dynamic> state =
        (insights?['state'] as Map<String, dynamic>?) ??
            <String, dynamic>{};
    final Map<String, dynamic> mvl =
        (insights?['mvl'] as Map<String, dynamic>?) ??
            <String, dynamic>{};
    final List<dynamic> goals =
        (insights?['activeGoals'] as List<dynamic>?) ?? <dynamic>[];

    String pct(dynamic value) {
      final double v = (value as num?)?.toDouble() ?? 0;
      return '${(v * 100).toStringAsFixed(0)}%';
    }

    String delta(dynamic value) {
      final double v = (value as num?)?.toDouble() ?? 0;
      final String sign = v >= 0 ? '+' : '';
      return '$sign${(v * 100).toStringAsFixed(1)}';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ScholesaColors.educator.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.query_stats,
                    color: ScholesaColors.educator, size: 18),
                const SizedBox(width: 8),
                Text(
                  BosCoachingI18n.sessionLoopTitle(context),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: ScholesaColors.educator,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _loopLearnerName == null
                  ? BosCoachingI18n.latestSignal(context)
                  : '${BosCoachingI18n.latestSignal(context)}: $_loopLearnerName',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            if (_loopInsightsLoading)
              const LinearProgressIndicator(minHeight: 4)
            else if (insights == null)
              Text(BosCoachingI18n.sessionLoopEmpty(context))
            else ...<Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _metricChip(
                    '${BosCoachingI18n.cognition(context)} ${pct(state['cognition'])}',
                  ),
                  _metricChip(
                    '${BosCoachingI18n.engagement(context)} ${pct(state['engagement'])}',
                  ),
                  _metricChip(
                    '${BosCoachingI18n.integrity(context)} ${pct(state['integrity'])}',
                  ),
                  _metricChip(
                    '${BosCoachingI18n.improvementScore(context)} ${delta(trend['improvementScore'])}',
                  ),
                  _metricChip(
                    '${BosCoachingI18n.mvlStatus(context)} ${mvl['active'] ?? 0}/${mvl['passed'] ?? 0}/${mvl['failed'] ?? 0}',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${_tEducatorLearnersPageSpecific(context, 'delta')}: C ${delta(trend['cognitionDelta'])}, E ${delta(trend['engagementDelta'])}, I ${delta(trend['integrityDelta'])}',
                style: theme.textTheme.bodySmall,
              ),
              if (goals.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  '${BosCoachingI18n.activeGoals(context)}: ${goals.take(3).join(' • ')}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _metricChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ScholesaColors.educator.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: ScholesaColors.educatorGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: ScholesaColors.educator.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.groups, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _tEducatorLearners(context, 'My Learners'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: ScholesaColors.educator,
                        ),
                  ),
                  Text(
                    _tEducatorLearners(context, 'Track progress and engagement'),
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        onChanged: (String value) {
          if (value.isNotEmpty) {
            TelemetryService.instance.logEvent(
              event: 'cta.clicked',
              metadata: <String, dynamic>{
                'module': 'educator_learners',
                'cta_id': 'search_input',
                'surface': 'search_bar',
                'length': value.length,
              },
            );
          }
          setState(() => _searchQuery = value);
        },
        decoration: InputDecoration(
          hintText: _tEducatorLearners(context, 'Search learners...'),
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: <String, dynamic>{
                        'module': 'educator_learners',
                        'cta_id': 'clear_search_query',
                        'surface': 'search_bar',
                      },
                    );
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionFilter(EducatorService service) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            _FilterChip(
              label: _tEducatorLearners(context, 'All Sessions'),
              isSelected: _selectedSession == 'all',
              onTap: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: <String, dynamic>{
                    'module': 'educator_learners',
                    'cta_id': 'set_session_filter',
                    'surface': 'session_filter',
                    'session_id': 'all',
                  },
                );
                setState(() => _selectedSession = 'all');
              },
            ),
            const SizedBox(width: 8),
            ...service.sessions.map(
              (EducatorSession session) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _FilterChip(
                  label: session.title,
                  isSelected: _selectedSession == session.id,
                  onTap: () {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: <String, dynamic>{
                        'module': 'educator_learners',
                        'cta_id': 'set_session_filter',
                        'surface': 'session_filter',
                        'session_id': session.id,
                      },
                    );
                    setState(() => _selectedSession = session.id);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(EducatorService service) {
    final List<EducatorLearner> learners = _getFilteredLearners(service);
    final int totalLearners = learners.length;
    final int activeToday =
        learners.where((EducatorLearner l) => l.isActiveToday).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _StatCard(
              icon: Icons.people,
              value: totalLearners.toString(),
              label: _tEducatorLearners(context, 'Total Learners'),
              color: ScholesaColors.educator,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Icons.check_circle,
              value: activeToday.toString(),
              label: _tEducatorLearners(context, 'Active Today'),
              color: ScholesaColors.success,
            ),
          ),
        ],
      ),
    );
  }

  List<EducatorLearner> _getFilteredLearners(EducatorService service) {
    List<EducatorLearner> learners = service.learners;

    // Filter by session
    if (_selectedSession != 'all') {
      learners = learners
          .where((EducatorLearner l) => l.sessionIds.contains(_selectedSession))
          .toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      learners = learners.where((EducatorLearner l) {
        return l.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            l.email.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    return learners;
  }

  void _openLearnerDetail(EducatorLearner learner) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'educator_learners',
        'cta_id': 'open_learner_detail',
        'surface': 'learner_card',
        'learner_id': learner.id,
      },
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => _LearnerDetailSheet(learner: learner),
    );
    _loadLearnerLoopInsights(learner);
  }
}

class _LearnerCard extends StatelessWidget {
  const _LearnerCard({required this.learner, required this.onTap});
  final EducatorLearner learner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 24,
                  backgroundColor:
                      ScholesaColors.learner.withValues(alpha: 0.1),
                  child: Text(
                    learner.initials,
                    style: const TextStyle(
                      color: ScholesaColors.learner,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            learner.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          if (learner.isActiveToday)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: ScholesaColors.success
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _tEducatorLearners(context, 'ACTIVE'),
                                style: const TextStyle(
                                  color: ScholesaColors.success,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        learner.email,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    _PillarProgress(
                      label: 'FS',
                      progress: learner.futureSkillsProgress,
                      color: ScholesaColors.futureSkills,
                    ),
                    const SizedBox(height: 4),
                    _PillarProgress(
                      label: 'LD',
                      progress: learner.leadershipProgress,
                      color: ScholesaColors.leadership,
                    ),
                    const SizedBox(height: 4),
                    _PillarProgress(
                      label: 'IM',
                      progress: learner.impactProgress,
                      color: ScholesaColors.impact,
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
}

class _PillarProgress extends StatelessWidget {
  const _PillarProgress({
    required this.label,
    required this.progress,
    required this.color,
  });
  final String label;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[500]),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 40,
          height: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? ScholesaColors.educator
              : ScholesaColors.educator.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : ScholesaColors.educator,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
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
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LearnerDetailSheet extends StatelessWidget {
  const _LearnerDetailSheet({required this.learner});
  final EducatorLearner learner;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 32,
                        backgroundColor:
                            ScholesaColors.learner.withValues(alpha: 0.1),
                        child: Text(
                          learner.initials,
                          style: const TextStyle(
                            color: ScholesaColors.learner,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              learner.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              learner.email,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _tEducatorLearners(context, 'Pillar Progress'),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  _ProgressBar(
                    label: _tEducatorLearners(context, 'Future Skills'),
                    progress: learner.futureSkillsProgress,
                    color: ScholesaColors.futureSkills,
                  ),
                  const SizedBox(height: 8),
                  _ProgressBar(
                    label: _tEducatorLearners(context, 'Leadership'),
                    progress: learner.leadershipProgress,
                    color: ScholesaColors.leadership,
                  ),
                  const SizedBox(height: 8),
                  _ProgressBar(
                    label: _tEducatorLearners(context, 'Impact'),
                    progress: learner.impactProgress,
                    color: ScholesaColors.impact,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            TelemetryService.instance.logEvent(
                              event: 'cta.clicked',
                              metadata: <String, dynamic>{
                                'module': 'educator_learners',
                                'cta_id': 'message_learner',
                                'surface': 'learner_detail_sheet',
                                'learner_id': learner.id,
                              },
                            );
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.message),
                          label: Text(_tEducatorLearners(context, 'Message')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ScholesaColors.educator,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(
                                color: ScholesaColors.educator),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            TelemetryService.instance.logEvent(
                              event: 'cta.clicked',
                              metadata: <String, dynamic>{
                                'module': 'educator_learners',
                                'cta_id': 'open_full_profile',
                                'surface': 'learner_detail_sheet',
                                'learner_id': learner.id,
                              },
                            );
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.assignment),
                          label: Text(_tEducatorLearners(context, 'Full Profile')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ScholesaColors.educator,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.label,
    required this.progress,
    required this.color,
  });
  final String label;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(label, style: TextStyle(color: Colors.grey[700])),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
