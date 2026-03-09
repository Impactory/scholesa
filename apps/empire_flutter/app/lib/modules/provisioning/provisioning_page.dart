import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../i18n/workflow_surface_i18n.dart';
import '../../auth/app_state.dart';
import '../../services/telemetry_service.dart';
import '../../ui/common/empty_state.dart';
import 'provisioning_models.dart';
import 'provisioning_service.dart';

String _tProvisioning(BuildContext context, String input) {
  return WorkflowSurfaceI18n.text(context, input);
}

void _logProvisioningCta(String ctaId, {Map<String, dynamic>? metadata}) {
  TelemetryService.instance.logEvent(
    event: 'cta.clicked',
    metadata: <String, dynamic>{
      'module': 'provisioning',
      'cta_id': ctaId,
      ...?metadata,
    },
  );
}

/// Provisioning page for site admins
class ProvisioningPage extends StatefulWidget {
  const ProvisioningPage({super.key});

  @override
  State<ProvisioningPage> createState() => _ProvisioningPageState();
}

class _ProvisioningPageState extends State<ProvisioningPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _lastLoadedSiteId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        return;
      }
      final String tab = switch (_tabController.index) {
        0 => 'learners',
        1 => 'parents',
        2 => 'links',
        3 => 'cohorts',
        _ => 'unknown',
      };
      TelemetryService.instance.logEvent(
        event: 'cta.clicked',
        metadata: <String, dynamic>{
          'module': 'provisioning',
          'cta_id': 'change_tab',
          'surface': 'provisioning_tab_bar',
          'tab': tab,
        },
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final String? activeSiteId = context.read<AppState>().activeSiteId;
    if (activeSiteId != null && activeSiteId != _lastLoadedSiteId) {
      _lastLoadedSiteId = activeSiteId;
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final appState = context.read<AppState>();
    final siteId = appState.activeSiteId;
    if (siteId == null) return;

    final service = context.read<ProvisioningService>();
    await Future.wait(<Future<void>>[
      service.loadLearners(siteId),
      service.loadParents(siteId),
      service.loadGuardianLinks(siteId),
      service.loadCohortLaunches(siteId),
    ]);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tProvisioning(context, 'Provisioning')),
        bottom: TabBar(
          controller: _tabController,
          tabs: <Widget>[
            Tab(
                icon: const Icon(Icons.child_care),
                text: _tProvisioning(context, 'Learners')),
            Tab(
                icon: const Icon(Icons.family_restroom),
                text: _tProvisioning(context, 'Parents')),
            Tab(
                icon: const Icon(Icons.link),
                text: _tProvisioning(context, 'Links')),
            Tab(
                icon: const Icon(Icons.rocket_launch_rounded),
                text: _tProvisioning(context, 'Cohorts')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const <Widget>[
          _LearnersTab(),
          _ParentsTab(),
          _LinksTab(),
          _CohortsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          TelemetryService.instance.logEvent(
            event: 'cta.clicked',
            metadata: <String, dynamic>{
              'module': 'provisioning',
              'cta_id': 'open_create_dialog',
              'tab_index': _tabController.index,
            },
          );
          _showCreateDialog(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final int currentTab = _tabController.index;
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'provisioning',
        'cta_id': 'select_create_dialog_type',
        'tab_index': currentTab,
      },
    );

    switch (currentTab) {
      case 0:
        _showCreateLearnerDialog(context);
        return;
      case 1:
        _showCreateParentDialog(context);
        return;
      case 2:
        _showCreateLinkDialog(context);
        return;
      case 3:
        _showCreateCohortDialog(context);
        return;
    }
  }

  void _showCreateLearnerDialog(BuildContext context) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{
        'module': 'provisioning',
        'cta_id': 'open_create_learner_dialog',
      },
    );
    showDialog(
      context: context,
      builder: (BuildContext context) => const _CreateLearnerDialog(),
    );
  }

  void _showCreateParentDialog(BuildContext context) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{
        'module': 'provisioning',
        'cta_id': 'open_create_parent_dialog',
      },
    );
    showDialog(
      context: context,
      builder: (BuildContext context) => const _CreateParentDialog(),
    );
  }

  void _showCreateLinkDialog(BuildContext context) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{
        'module': 'provisioning',
        'cta_id': 'open_create_guardian_link_dialog',
      },
    );
    showDialog(
      context: context,
      builder: (BuildContext context) => const _CreateLinkDialog(),
    );
  }

  void _showCreateCohortDialog(BuildContext context) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{
        'module': 'provisioning',
        'cta_id': 'open_create_cohort_launch_dialog',
      },
    );
    showDialog(
      context: context,
      builder: (BuildContext context) => const _CreateCohortDialog(),
    );
  }
}

/// Learners tab - uses ProvisioningService data
class _LearnersTab extends StatelessWidget {
  const _LearnersTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<ProvisioningService>(
      builder:
          (BuildContext context, ProvisioningService service, Widget? child) {
        if (service.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<LearnerProfile> learners = service.learners;

        if (learners.isEmpty) {
          return EmptyState(
            icon: Icons.child_care,
            title: _tProvisioning(context, 'No learners yet'),
            message: _tProvisioning(
                context, 'Add learners to your site to get started.'),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            TelemetryService.instance.logEvent(
              event: 'cta.clicked',
              metadata: const <String, dynamic>{
                'module': 'provisioning',
                'cta_id': 'refresh_learners_tab',
              },
            );
            final appState = context.read<AppState>();
            final siteId = appState.activeSiteId;
            if (siteId != null) {
              await service.loadLearners(siteId);
            }
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: learners.length,
            itemBuilder: (BuildContext context, int index) {
              final LearnerProfile learner = learners[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(learner.displayName.isNotEmpty
                        ? learner.displayName[0]
                        : '?'),
                  ),
                  title: Text(learner.displayName),
                  subtitle: learner.gradeLevel != null
                      ? Text(
                          '${_tProvisioning(context, 'Grade')} ${learner.gradeLevel}')
                      : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () {
                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: <String, dynamic>{
                          'module': 'provisioning',
                          'cta_id': 'open_learner_options',
                          'learner_id': learner.id,
                        },
                      );
                      _showLearnerOptions(context, learner);
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showLearnerOptions(BuildContext context, LearnerProfile learner) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.edit),
            title: Text(_tProvisioning(context, 'Edit Learner')),
            onTap: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'module': 'provisioning',
                  'cta_id': 'open_edit_learner_dialog',
                  'learner_id': learner.id,
                },
              );
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (BuildContext ctx) =>
                    _EditLearnerDialog(learner: learner),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: Text(_tProvisioning(context, 'Manage Guardian Links')),
            onTap: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'module': 'provisioning',
                  'cta_id': 'open_manage_guardian_links',
                  'learner_id': learner.id,
                },
              );
              Navigator.pop(context);
              // Switch to Links tab (index 2) — links are already loaded
              final _ProvisioningPageState? pageState =
                  context.findAncestorStateOfType<_ProvisioningPageState>();
              pageState?._tabController.animateTo(2);
            },
          ),
        ],
      ),
    );
  }
}

/// Parents tab - uses ProvisioningService data
class _ParentsTab extends StatelessWidget {
  const _ParentsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<ProvisioningService>(
      builder:
          (BuildContext context, ProvisioningService service, Widget? child) {
        if (service.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<ParentProfile> parents = service.parents;

        if (parents.isEmpty) {
          return EmptyState(
            icon: Icons.family_restroom,
            title: _tProvisioning(context, 'No parents yet'),
            message: _tProvisioning(
                context, 'Add parent accounts to link with learners.'),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            TelemetryService.instance.logEvent(
              event: 'cta.clicked',
              metadata: const <String, dynamic>{
                'module': 'provisioning',
                'cta_id': 'refresh_parents_tab',
              },
            );
            final appState = context.read<AppState>();
            final siteId = appState.activeSiteId;
            if (siteId != null) {
              await service.loadParents(siteId);
            }
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: parents.length,
            itemBuilder: (BuildContext context, int index) {
              final ParentProfile parent = parents[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Text(
                      parent.displayName.isNotEmpty
                          ? parent.displayName[0]
                          : '?',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(parent.displayName),
                  subtitle: Text(parent.email ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () {
                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: <String, dynamic>{
                          'module': 'provisioning',
                          'cta_id': 'open_parent_options',
                          'parent_id': parent.id,
                        },
                      );
                      _showParentOptions(context, parent);
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showParentOptions(BuildContext context, ParentProfile parent) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.edit),
            title: Text(_tProvisioning(context, 'Edit Parent')),
            onTap: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'module': 'provisioning',
                  'cta_id': 'open_edit_parent_dialog',
                  'parent_id': parent.id,
                },
              );
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (BuildContext ctx) =>
                    _EditParentDialog(parent: parent),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: Text(_tProvisioning(context, 'Manage Learner Links')),
            onTap: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'module': 'provisioning',
                  'cta_id': 'open_manage_learner_links',
                  'parent_id': parent.id,
                },
              );
              Navigator.pop(context);
              // Switch to Links tab (index 2) — links are already loaded
              final _ProvisioningPageState? pageState =
                  context.findAncestorStateOfType<_ProvisioningPageState>();
              pageState?._tabController.animateTo(2);
            },
          ),
        ],
      ),
    );
  }
}

/// Guardian links tab - uses ProvisioningService data
class _LinksTab extends StatelessWidget {
  const _LinksTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<ProvisioningService>(
      builder:
          (BuildContext context, ProvisioningService service, Widget? child) {
        if (service.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<GuardianLink> links = service.guardianLinks;

        if (links.isEmpty) {
          return EmptyState(
            icon: Icons.link,
            title: _tProvisioning(context, 'No guardian links'),
            message: _tProvisioning(
                context, 'Link parents to learners to enable family access.'),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            TelemetryService.instance.logEvent(
              event: 'cta.clicked',
              metadata: const <String, dynamic>{
                'module': 'provisioning',
                'cta_id': 'refresh_links_tab',
              },
            );
            final appState = context.read<AppState>();
            final siteId = appState.activeSiteId;
            if (siteId != null) {
              await service.loadGuardianLinks(siteId);
            }
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: links.length,
            itemBuilder: (BuildContext context, int index) {
              final GuardianLink link = links[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.link, size: 32),
                  title: Text(
                      '${link.parentName ?? link.parentId} → ${link.learnerName ?? link.learnerId}'),
                  subtitle: Row(
                    children: <Widget>[
                      Text(link.relationship),
                      if (link.isPrimary) ...<Widget>[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _tProvisioning(context, 'Primary'),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.green[800],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () {
                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: <String, dynamic>{
                          'module': 'provisioning',
                          'cta_id': 'open_delete_guardian_link_confirm',
                          'link_id': link.id,
                        },
                      );
                      _confirmDelete(context, link, service);
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _confirmDelete(
      BuildContext context, GuardianLink link, ProvisioningService service) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(_tProvisioning(context, 'Delete Link')),
        content: Text(
          Localizations.localeOf(context).languageCode == 'es'
              ? '¿Eliminar el vínculo de tutor entre ${link.parentName ?? link.parentId} y ${link.learnerName ?? link.learnerId}?'
              : 'Remove the guardian link between ${link.parentName ?? link.parentId} and ${link.learnerName ?? link.learnerId}?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'module': 'provisioning',
                  'cta_id': 'cancel_delete_guardian_link',
                  'link_id': link.id,
                },
              );
              Navigator.pop(context);
            },
            child: Text(_tProvisioning(context, 'Cancel')),
          ),
          TextButton(
            onPressed: () async {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'module': 'provisioning',
                  'cta_id': 'delete_guardian_link',
                  'link_id': link.id,
                },
              );
              Navigator.pop(context);
              final bool success = await service.deleteGuardianLink(link.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? _tProvisioning(context, 'Link removed')
                        : _tProvisioning(context, 'Failed to remove link')),
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(_tProvisioning(context, 'Delete')),
          ),
        ],
      ),
    );
  }
}

class _CohortsTab extends StatelessWidget {
  const _CohortsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<ProvisioningService>(
      builder:
          (BuildContext context, ProvisioningService service, Widget? child) {
        if (service.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<CohortLaunch> launches = service.cohortLaunches;
        if (launches.isEmpty) {
          return EmptyState(
            icon: Icons.rocket_launch_rounded,
            title: _tProvisioning(context, 'No cohort launches yet'),
            message: _tProvisioning(
              context,
              'Track launch readiness, parent comms, and kickoff status here.',
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            _logProvisioningCta('refresh_cohort_launches_tab');
            final String? siteId = context.read<AppState>().activeSiteId;
            if (siteId != null) {
              await service.loadCohortLaunches(siteId);
            }
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: launches.length,
            itemBuilder: (BuildContext context, int index) {
              final CohortLaunch launch = launches[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.indigo.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.rocket_launch_rounded,
                              color: Colors.indigo,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  launch.cohortName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${launch.scheduleLabel} • ${launch.curriculumTerm}',
                                  style: const TextStyle(
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _StatusPill(
                            label: launch.status,
                            color: _cohortStatusColor(launch.status),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          _StatusPill(
                            label:
                                '${_tProvisioning(context, 'Roster Status')}: ${launch.rosterStatus}',
                            color: _cohortStatusColor(launch.rosterStatus),
                          ),
                          _StatusPill(
                            label:
                                '${_tProvisioning(context, 'Parent Comms')}: ${launch.parentCommunicationStatus}',
                            color: _cohortStatusColor(
                                launch.parentCommunicationStatus),
                          ),
                          _StatusPill(
                            label:
                                '${_tProvisioning(context, 'Baseline Survey')}: ${launch.baselineSurveyStatus}',
                            color:
                                _cohortStatusColor(launch.baselineSurveyStatus),
                          ),
                          _StatusPill(
                            label:
                                '${_tProvisioning(context, 'Kickoff')}: ${launch.kickoffStatus}',
                            color: _cohortStatusColor(launch.kickoffStatus),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              '${_tProvisioning(context, 'Age Band')}: ${launch.ageBand}',
                              style: const TextStyle(color: Colors.black87),
                            ),
                          ),
                          Text(
                            '${_tProvisioning(context, 'Learner Count')}: ${launch.learnerCount ?? 0}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if ((launch.notes ?? '').trim().isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          launch.notes!.trim(),
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

Color _cohortStatusColor(String value) {
  switch (value.trim().toLowerCase()) {
    case 'completed':
    case 'active':
    case 'confirmed':
    case 'sent':
    case 'ready':
      return Colors.green;
    case 'scheduled':
    case 'planning':
      return Colors.indigo;
    case 'pending':
    case 'draft':
      return Colors.orange;
    default:
      return Colors.blueGrey;
  }
}

/// Create learner dialog - wired to ProvisioningService
class _CreateLearnerDialog extends StatefulWidget {
  const _CreateLearnerDialog();

  @override
  State<_CreateLearnerDialog> createState() => _CreateLearnerDialogState();
}

class _CreateLearnerDialogState extends State<_CreateLearnerDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  int? _selectedGrade;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{
        'module': 'provisioning',
        'cta_id': 'submit_create_learner',
      },
    );

    setState(() => _isSubmitting = true);

    final appState = context.read<AppState>();
    final siteId = appState.activeSiteId;
    if (siteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tProvisioning(context, 'No site selected'))),
      );
      return;
    }

    final service = context.read<ProvisioningService>();
    final result = await service.createLearner(
      siteId: siteId,
      email: _emailController.text.trim(),
      displayName: _nameController.text.trim(),
      gradeLevel: _selectedGrade,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result != null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(_tProvisioning(context, 'Learner created successfully'))),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(service.error ??
                _tProvisioning(context, 'Failed to create learner'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_tProvisioning(context, 'Add Learner')),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: _tProvisioning(context, 'Full Name'),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (String? v) => v?.isEmpty ?? true
                  ? _tProvisioning(context, 'Required')
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: _tProvisioning(context, 'Email'),
                prefixIcon: Icon(Icons.email),
              ),
              validator: (String? v) {
                if (v?.isEmpty ?? true) {
                  return _tProvisioning(context, 'Required');
                }
                if (!v!.contains('@')) {
                  return _tProvisioning(context, 'Invalid email');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _selectedGrade,
              decoration: InputDecoration(
                labelText: _tProvisioning(context, 'Grade Level'),
                prefixIcon: Icon(Icons.school),
              ),
              items: List.generate(9, (int i) => i + 1)
                  .map((int g) => DropdownMenuItem(
                        value: g,
                        child: Text('${_tProvisioning(context, 'Grade')} $g'),
                      ))
                  .toList(),
              onChanged: (int? v) => setState(() => _selectedGrade = v),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () {
                  _logProvisioningCta('cancel_create_learner');
                  Navigator.pop(context);
                },
          child: Text(_tProvisioning(context, 'Cancel')),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_tProvisioning(context, 'Create')),
        ),
      ],
    );
  }
}

/// Create parent dialog - wired to ProvisioningService
class _CreateParentDialog extends StatefulWidget {
  const _CreateParentDialog();

  @override
  State<_CreateParentDialog> createState() => _CreateParentDialogState();
}

class _CreateParentDialogState extends State<_CreateParentDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{
        'module': 'provisioning',
        'cta_id': 'submit_create_parent',
      },
    );

    setState(() => _isSubmitting = true);

    final appState = context.read<AppState>();
    final siteId = appState.activeSiteId;
    if (siteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tProvisioning(context, 'No site selected'))),
      );
      return;
    }

    final service = context.read<ProvisioningService>();
    final phone = _phoneController.text.trim();
    final result = await service.createParent(
      siteId: siteId,
      email: _emailController.text.trim(),
      displayName: _nameController.text.trim(),
      phone: phone.isNotEmpty ? phone : null,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result != null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(_tProvisioning(context, 'Parent created successfully'))),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(service.error ??
                _tProvisioning(context, 'Failed to create parent'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_tProvisioning(context, 'Add Parent')),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: _tProvisioning(context, 'Full Name'),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (String? v) => v?.isEmpty ?? true
                  ? _tProvisioning(context, 'Required')
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: _tProvisioning(context, 'Email'),
                prefixIcon: Icon(Icons.email),
              ),
              validator: (String? v) {
                if (v?.isEmpty ?? true) {
                  return _tProvisioning(context, 'Required');
                }
                if (!v!.contains('@')) {
                  return _tProvisioning(context, 'Invalid email');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: _tProvisioning(context, 'Phone (optional)'),
                prefixIcon: Icon(Icons.phone),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () {
                  _logProvisioningCta('cancel_create_parent');
                  Navigator.pop(context);
                },
          child: Text(_tProvisioning(context, 'Cancel')),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_tProvisioning(context, 'Create')),
        ),
      ],
    );
  }
}

/// Create guardian link dialog - wired to ProvisioningService
class _CreateLinkDialog extends StatefulWidget {
  const _CreateLinkDialog();

  @override
  State<_CreateLinkDialog> createState() => _CreateLinkDialogState();
}

class _CreateLinkDialogState extends State<_CreateLinkDialog> {
  String? _selectedParentId;
  String? _selectedLearnerId;
  String _relationship = 'Parent';
  bool _isPrimary = false;
  bool _isSubmitting = false;

  final List<String> _relationships = <String>[
    'Parent',
    'Father',
    'Mother',
    'Guardian',
    'Grandparent',
    'Other'
  ];

  Future<void> _submit() async {
    if (_selectedParentId == null || _selectedLearnerId == null) return;
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'provisioning',
        'cta_id': 'submit_create_guardian_link',
        'parent_id': _selectedParentId,
        'learner_id': _selectedLearnerId,
      },
    );

    setState(() => _isSubmitting = true);

    final appState = context.read<AppState>();
    final siteId = appState.activeSiteId;
    if (siteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tProvisioning(context, 'No site selected'))),
      );
      return;
    }

    final service = context.read<ProvisioningService>();
    final result = await service.createGuardianLink(
      siteId: siteId,
      parentId: _selectedParentId!,
      learnerId: _selectedLearnerId!,
      relationship: _relationship,
      isPrimary: _isPrimary,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result != null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                _tProvisioning(context, 'Guardian link created successfully'))),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(service.error ??
                _tProvisioning(context, 'Failed to create link'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProvisioningService>(
      builder:
          (BuildContext context, ProvisioningService service, Widget? child) {
        final List<ParentProfile> parents = service.parents;
        final List<LearnerProfile> learners = service.learners;

        return AlertDialog(
          title: Text(_tProvisioning(context, 'Create Guardian Link')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DropdownButtonFormField<String>(
                initialValue: _selectedParentId,
                decoration: InputDecoration(
                  labelText: _tProvisioning(context, 'Parent'),
                  prefixIcon: Icon(Icons.family_restroom),
                ),
                items: parents.isEmpty
                    ? <DropdownMenuItem<String>>[
                        DropdownMenuItem(
                          enabled: false,
                          child: Text(
                              _tProvisioning(context, 'No parents available')),
                        ),
                      ]
                    : parents
                        .map((ParentProfile p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(p.displayName),
                            ))
                        .toList(),
                onChanged: (String? v) => setState(() => _selectedParentId = v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedLearnerId,
                decoration: InputDecoration(
                  labelText: _tProvisioning(context, 'Learner'),
                  prefixIcon: Icon(Icons.child_care),
                ),
                items: learners.isEmpty
                    ? <DropdownMenuItem<String>>[
                        DropdownMenuItem(
                          enabled: false,
                          child: Text(
                              _tProvisioning(context, 'No learners available')),
                        ),
                      ]
                    : learners
                        .map((LearnerProfile l) => DropdownMenuItem(
                              value: l.id,
                              child: Text(l.displayName),
                            ))
                        .toList(),
                onChanged: (String? v) =>
                    setState(() => _selectedLearnerId = v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _relationship,
                decoration: InputDecoration(
                  labelText: _tProvisioning(context, 'Relationship'),
                  prefixIcon: Icon(Icons.people),
                ),
                items: _relationships
                    .map((String r) => DropdownMenuItem<String>(
                        value: r, child: Text(_tProvisioning(context, r))))
                    .toList(),
                onChanged: (String? v) =>
                    setState(() => _relationship = v ?? 'Parent'),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: Text(_tProvisioning(context, 'Primary guardian')),
                subtitle:
                    Text(_tProvisioning(context, 'Receives all notifications')),
                value: _isPrimary,
                onChanged: (bool v) => setState(() => _isPrimary = v),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: _isSubmitting
                  ? null
                  : () {
                      _logProvisioningCta('cancel_create_guardian_link');
                      Navigator.pop(context);
                    },
              child: Text(_tProvisioning(context, 'Cancel')),
            ),
            ElevatedButton(
              onPressed: _isSubmitting ||
                      _selectedParentId == null ||
                      _selectedLearnerId == null
                  ? null
                  : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_tProvisioning(context, 'Create Link')),
            ),
          ],
        );
      },
    );
  }
}

class _CreateCohortDialog extends StatefulWidget {
  const _CreateCohortDialog();

  @override
  State<_CreateCohortDialog> createState() => _CreateCohortDialogState();
}

class _CreateCohortDialogState extends State<_CreateCohortDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _cohortNameController = TextEditingController();
  final TextEditingController _scheduleController = TextEditingController(
    text: 'Mon/Wed 4:00 PM',
  );
  final TextEditingController _termController = TextEditingController(
    text: 'Term 1',
  );
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _learnerCountController = TextEditingController();

  String _ageBand = 'Mixed Ages';
  String _programFormat = 'gold';
  String _rosterStatus = 'draft';
  String _parentCommunicationStatus = 'pending';
  String _baselineSurveyStatus = 'pending';
  String _kickoffStatus = 'pending';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _cohortNameController.dispose();
    _scheduleController.dispose();
    _termController.dispose();
    _notesController.dispose();
    _learnerCountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    _logProvisioningCta('submit_create_cohort_launch');
    setState(() => _isSubmitting = true);

    final String? siteId = context.read<AppState>().activeSiteId;
    if (siteId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tProvisioning(context, 'No site selected'))),
      );
      setState(() => _isSubmitting = false);
      return;
    }

    final int? learnerCount = int.tryParse(_learnerCountController.text.trim());
    final ProvisioningService service = context.read<ProvisioningService>();
    final CohortLaunch? result = await service.createCohortLaunch(
      siteId: siteId,
      cohortName: _cohortNameController.text.trim(),
      ageBand: _ageBand,
      scheduleLabel: _scheduleController.text.trim(),
      programFormat: _programFormat,
      curriculumTerm: _termController.text.trim(),
      rosterStatus: _rosterStatus,
      parentCommunicationStatus: _parentCommunicationStatus,
      baselineSurveyStatus: _baselineSurveyStatus,
      kickoffStatus: _kickoffStatus,
      learnerCount: learnerCount,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result != null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tProvisioning(context, 'Cohort launch created successfully'),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            service.error ??
                _tProvisioning(context, 'Failed to create cohort launch'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_tProvisioning(context, 'Create Cohort Launch')),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: _cohortNameController,
                  decoration: InputDecoration(
                    labelText: _tProvisioning(context, 'Cohort Name'),
                    prefixIcon: const Icon(Icons.group_rounded),
                  ),
                  validator: (String? value) => (value?.trim().isEmpty ?? true)
                      ? _tProvisioning(context, 'Required')
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _ageBand,
                  decoration: InputDecoration(
                    labelText: _tProvisioning(context, 'Age Band'),
                    prefixIcon: const Icon(Icons.groups_rounded),
                  ),
                  items: <String>[
                    'Mixed Ages',
                    'K-5',
                    'Middle School',
                    'High School',
                  ].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(_tProvisioning(context, value)),
                    );
                  }).toList(),
                  onChanged: (String? value) =>
                      setState(() => _ageBand = value ?? 'Mixed Ages'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _scheduleController,
                  decoration: InputDecoration(
                    labelText: _tProvisioning(context, 'Schedule'),
                    prefixIcon: const Icon(Icons.schedule_rounded),
                  ),
                  validator: (String? value) => (value?.trim().isEmpty ?? true)
                      ? _tProvisioning(context, 'Required')
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _programFormat,
                  decoration: InputDecoration(
                    labelText: _tProvisioning(context, 'Program Format'),
                    prefixIcon: const Icon(Icons.rocket_rounded),
                  ),
                  items: const <String>['gold', 'silver', 'pilot']
                      .map((String value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              _tProvisioning(
                                context,
                                value[0].toUpperCase() + value.substring(1),
                              ),
                            ),
                          ))
                      .toList(),
                  onChanged: (String? value) =>
                      setState(() => _programFormat = value ?? 'gold'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _termController,
                  decoration: InputDecoration(
                    labelText: _tProvisioning(context, 'Curriculum Term'),
                    prefixIcon: const Icon(Icons.flag_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _learnerCountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _tProvisioning(context, 'Learner Count'),
                    prefixIcon: const Icon(Icons.countertops_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _rosterStatus,
                  decoration: InputDecoration(
                    labelText: _tProvisioning(context, 'Roster Status'),
                    prefixIcon: const Icon(Icons.fact_check_rounded),
                  ),
                  items: const <String>['draft', 'ready', 'active']
                      .map((String value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              _tProvisioning(
                                context,
                                value[0].toUpperCase() + value.substring(1),
                              ),
                            ),
                          ))
                      .toList(),
                  onChanged: (String? value) =>
                      setState(() => _rosterStatus = value ?? 'draft'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _parentCommunicationStatus,
                  decoration: InputDecoration(
                    labelText: _tProvisioning(context, 'Parent Comms'),
                    prefixIcon: const Icon(Icons.mark_email_read_rounded),
                  ),
                  items: const <String>['pending', 'sent', 'confirmed']
                      .map((String value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              _tProvisioning(
                                context,
                                value[0].toUpperCase() + value.substring(1),
                              ),
                            ),
                          ))
                      .toList(),
                  onChanged: (String? value) => setState(
                    () => _parentCommunicationStatus = value ?? 'pending',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _baselineSurveyStatus,
                  decoration: InputDecoration(
                    labelText: _tProvisioning(context, 'Baseline Survey'),
                    prefixIcon: const Icon(Icons.assignment_rounded),
                  ),
                  items: const <String>['pending', 'ready', 'completed']
                      .map((String value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              _tProvisioning(
                                context,
                                value[0].toUpperCase() + value.substring(1),
                              ),
                            ),
                          ))
                      .toList(),
                  onChanged: (String? value) => setState(
                    () => _baselineSurveyStatus = value ?? 'pending',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _kickoffStatus,
                  decoration: InputDecoration(
                    labelText: _tProvisioning(context, 'Kickoff'),
                    prefixIcon: const Icon(Icons.celebration_rounded),
                  ),
                  items: const <String>['pending', 'scheduled', 'completed']
                      .map((String value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              _tProvisioning(
                                context,
                                value[0].toUpperCase() + value.substring(1),
                              ),
                            ),
                          ))
                      .toList(),
                  onChanged: (String? value) =>
                      setState(() => _kickoffStatus = value ?? 'pending'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () {
                  _logProvisioningCta('cancel_create_cohort_launch');
                  Navigator.pop(context);
                },
          child: Text(_tProvisioning(context, 'Cancel')),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_tProvisioning(context, 'Create')),
        ),
      ],
    );
  }
}

/// Edit learner dialog — pre-populated from existing profile
class _EditLearnerDialog extends StatefulWidget {
  const _EditLearnerDialog({required this.learner});
  final LearnerProfile learner;

  @override
  State<_EditLearnerDialog> createState() => _EditLearnerDialogState();
}

class _EditLearnerDialogState extends State<_EditLearnerDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  int? _selectedGrade;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.learner.displayName);
    _selectedGrade = widget.learner.gradeLevel;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'provisioning',
        'cta_id': 'submit_edit_learner',
        'learner_id': widget.learner.id,
      },
    );

    setState(() => _isSubmitting = true);

    final appState = context.read<AppState>();
    final siteId = appState.activeSiteId;
    if (siteId == null) return;

    final service = context.read<ProvisioningService>();
    final result = await service.updateLearner(
      siteId: siteId,
      learnerId: widget.learner.id,
      displayName: _nameController.text.trim(),
      gradeLevel: _selectedGrade,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result != null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tProvisioning(context, 'Learner updated'))),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(service.error ??
                _tProvisioning(context, 'Failed to update learner'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_tProvisioning(context, 'Edit Learner')),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: _tProvisioning(context, 'Full Name'),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (String? v) => v?.isEmpty ?? true
                  ? _tProvisioning(context, 'Required')
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _selectedGrade,
              decoration: InputDecoration(
                labelText: _tProvisioning(context, 'Grade Level'),
                prefixIcon: Icon(Icons.school),
              ),
              items: List.generate(9, (int i) => i + 1)
                  .map((int g) => DropdownMenuItem(
                      value: g,
                      child: Text('${_tProvisioning(context, 'Grade')} $g')))
                  .toList(),
              onChanged: (int? v) => setState(() => _selectedGrade = v),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () {
                  _logProvisioningCta(
                    'cancel_edit_learner',
                    metadata: <String, dynamic>{
                      'learner_id': widget.learner.id
                    },
                  );
                  Navigator.pop(context);
                },
          child: Text(_tProvisioning(context, 'Cancel')),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_tProvisioning(context, 'Save')),
        ),
      ],
    );
  }
}

/// Edit parent dialog — pre-populated from existing profile
class _EditParentDialog extends StatefulWidget {
  const _EditParentDialog({required this.parent});
  final ParentProfile parent;

  @override
  State<_EditParentDialog> createState() => _EditParentDialogState();
}

class _EditParentDialogState extends State<_EditParentDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.parent.displayName);
    _emailController = TextEditingController(text: widget.parent.email ?? '');
    _phoneController = TextEditingController(text: widget.parent.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'provisioning',
        'cta_id': 'submit_edit_parent',
        'parent_id': widget.parent.id,
      },
    );

    setState(() => _isSubmitting = true);

    final appState = context.read<AppState>();
    final siteId = appState.activeSiteId;
    if (siteId == null) return;

    final service = context.read<ProvisioningService>();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final result = await service.updateParent(
      siteId: siteId,
      parentId: widget.parent.id,
      displayName: _nameController.text.trim(),
      phone: phone.isNotEmpty ? phone : null,
      email: email.isNotEmpty ? email : null,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result != null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tProvisioning(context, 'Parent updated'))),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(service.error ??
                _tProvisioning(context, 'Failed to update parent'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_tProvisioning(context, 'Edit Parent')),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: _tProvisioning(context, 'Full Name'),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (String? v) => v?.isEmpty ?? true
                  ? _tProvisioning(context, 'Required')
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: _tProvisioning(context, 'Email'),
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: _tProvisioning(context, 'Phone'),
                prefixIcon: Icon(Icons.phone),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () {
                  _logProvisioningCta(
                    'cancel_edit_parent',
                    metadata: <String, dynamic>{'parent_id': widget.parent.id},
                  );
                  Navigator.pop(context);
                },
          child: Text(_tProvisioning(context, 'Cancel')),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_tProvisioning(context, 'Save')),
        ),
      ],
    );
  }
}
