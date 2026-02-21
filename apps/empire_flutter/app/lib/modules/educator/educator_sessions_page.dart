import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';
import 'educator_models.dart';
import 'educator_service.dart';

/// Educator Sessions Page - Manage and view all sessions
class EducatorSessionsPage extends StatefulWidget {
  const EducatorSessionsPage({super.key});

  @override
  State<EducatorSessionsPage> createState() => _EducatorSessionsPageState();
}

class _EducatorSessionsPageState extends State<EducatorSessionsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EducatorService>().loadSessions();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
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
              ScholesaColors.futureSkills.withValues(alpha: 0.03),
            ],
          ),
        ),
        child: Consumer<EducatorService>(
          builder: (BuildContext context, EducatorService service, _) {
            return CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildTabBar()),
                SliverToBoxAdapter(child: _buildFilters()),
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
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (BuildContext context, int index) {
                          final List<EducatorSession> sessions = _getFilteredSessions(service);
                          if (index >= sessions.length) return null;
                          return _SessionCard(
                            session: sessions[index],
                            onTap: () => _openSessionDetail(sessions[index]),
                          );
                        },
                        childCount: _getFilteredSessions(service).length,
                      ),
                    ),
                  ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewSession,
        backgroundColor: ScholesaColors.educator,
        icon: const Icon(Icons.add),
        label: const Text('New Session'),
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
              child: const Icon(Icons.event_note, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'My Sessions',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: ScholesaColors.educator,
                        ),
                  ),
                  Text(
                    'Manage your teaching schedule',
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

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: ScholesaColors.educator,
            borderRadius: BorderRadius.circular(10),
          ),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[600],
          tabs: const <Widget>[
            Tab(text: 'Upcoming'),
            Tab(text: 'Ongoing'),
            Tab(text: 'Past'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            _FilterChip(
              label: 'All',
              isSelected: _filterStatus == 'all',
              onTap: () => setState(() => _filterStatus = 'all'),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Future Skills',
              isSelected: _filterStatus == 'future_skills',
              color: ScholesaColors.futureSkills,
              onTap: () => setState(() => _filterStatus = 'future_skills'),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Leadership',
              isSelected: _filterStatus == 'leadership',
              color: ScholesaColors.leadership,
              onTap: () => setState(() => _filterStatus = 'leadership'),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Impact',
              isSelected: _filterStatus == 'impact',
              color: ScholesaColors.impact,
              onTap: () => setState(() => _filterStatus = 'impact'),
            ),
          ],
        ),
      ),
    );
  }

  List<EducatorSession> _getFilteredSessions(EducatorService service) {
    if (_filterStatus == 'all') {
      return service.sessions;
    }
    return service.sessions
        .where((EducatorSession s) => s.pillar.toLowerCase().replaceAll(' ', '_') == _filterStatus)
        .toList();
  }

  void _openSessionDetail(EducatorSession session) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{'cta': 'educator_sessions_open_detail', 'session_id': session.id},
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => _SessionDetailSheet(session: session),
    );
  }

  void _createNewSession() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{'cta': 'educator_sessions_open_create_dialog'},
    );
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => const _CreateSessionDialog(),
    );
  }
}

class _CreateSessionDialog extends StatefulWidget {
  const _CreateSessionDialog();

  @override
  State<_CreateSessionDialog> createState() => _CreateSessionDialogState();
}

class _CreateSessionDialogState extends State<_CreateSessionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  String _pillar = 'Future Skills';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'educator_sessions_create_submit',
        'pillar': _pillar,
      },
    );

    setState(() => _isSubmitting = true);

    final DateTime now = DateTime.now();
    final DateTime start = now.add(const Duration(hours: 1));
    final DateTime end = start.add(const Duration(hours: 1));

    final EducatorService service = context.read<EducatorService>();
    final EducatorSession? created = await service.createSession(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      location: _locationController.text.trim(),
      pillar: _pillar,
      startTime: start,
      endTime: end,
    );

    if (!mounted) {
      return;
    }

    setState(() => _isSubmitting = false);

    if (created == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(service.error ?? 'Failed to create session')),
      );
      return;
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Session created and added to your list'),
        backgroundColor: ScholesaColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Session'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Session title'),
              validator: (String? value) =>
                  value == null || value.trim().isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Location (optional)'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _pillar,
              decoration: const InputDecoration(labelText: 'Pillar'),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: 'Future Skills',
                  child: Text('Future Skills'),
                ),
                DropdownMenuItem<String>(
                  value: 'Leadership',
                  child: Text('Leadership'),
                ),
                DropdownMenuItem<String>(
                  value: 'Impact',
                  child: Text('Impact'),
                ),
              ],
              onChanged: (String? value) {
                if (value != null) {
                  setState(() => _pillar = value);
                }
              },
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {

  const _SessionCard({required this.session, required this.onTap});
  final EducatorSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            TelemetryService.instance.logEvent(
              event: 'cta.clicked',
              metadata: <String, dynamic>{
                'cta': 'educator_sessions_open_session',
                'session_title': session.title,
                'pillar': session.pillar,
                'status': session.status,
              },
            );
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _getPillarColor().withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getPillarIcon(),
                        color: _getPillarColor(),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            session.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${session.learnerCount} learners enrolled',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor().withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        session.status.toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(),
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      _formatSchedule(),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getPillarColor().withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        session.pillar,
                        style: TextStyle(
                          color: _getPillarColor(),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
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

  Color _getPillarColor() {
    switch (session.pillar.toLowerCase()) {
      case 'future skills':
        return ScholesaColors.futureSkills;
      case 'leadership':
        return ScholesaColors.leadership;
      case 'impact':
        return ScholesaColors.impact;
      default:
        return ScholesaColors.educator;
    }
  }

  IconData _getPillarIcon() {
    switch (session.pillar.toLowerCase()) {
      case 'future skills':
        return Icons.code;
      case 'leadership':
        return Icons.emoji_events;
      case 'impact':
        return Icons.eco;
      default:
        return Icons.school;
    }
  }

  Color _getStatusColor() {
    switch (session.status.toLowerCase()) {
      case 'active':
        return ScholesaColors.success;
      case 'upcoming':
        return ScholesaColors.info;
      case 'completed':
        return Colors.grey;
      default:
        return ScholesaColors.educator;
    }
  }

  String _formatSchedule() {
    return '${session.dayOfWeek} • ${session.startTime} - ${session.endTime}';
  }
}

class _FilterChip extends StatelessWidget {

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.color,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color chipColor = color ?? ScholesaColors.educator;
    return GestureDetector(
      onTap: () {
        TelemetryService.instance.logEvent(
          event: 'cta.clicked',
          metadata: <String, dynamic>{
            'cta': 'educator_sessions_filter_chip',
            'label': label,
            'selected': isSelected,
          },
        );
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : chipColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : chipColor,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _SessionDetailSheet extends StatelessWidget {

  const _SessionDetailSheet({required this.session});
  final EducatorSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
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
                  Text(
                    session.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (session.description != null)
                    Text(
                      session.description!,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  const SizedBox(height: 24),
                  _DetailRow(
                    icon: Icons.people,
                    label: 'Enrolled',
                    value: '${session.learnerCount} learners',
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.schedule,
                    label: 'Schedule',
                    value: '${session.dayOfWeek} ${session.startTime} - ${session.endTime}',
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.category,
                    label: 'Pillar',
                    value: session.pillar,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ScholesaColors.educator,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('View Full Details'),
                    ),
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

class _DetailRow extends StatelessWidget {

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ScholesaColors.educator.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: ScholesaColors.educator),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }
}
