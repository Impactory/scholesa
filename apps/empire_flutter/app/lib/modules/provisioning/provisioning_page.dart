import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/app_state.dart';
import '../../services/telemetry_service.dart';
import '../../ui/common/empty_state.dart';
import 'provisioning_models.dart';
import 'provisioning_service.dart';

const Map<String, String> _provisioningEs = <String, String>{
  'Provisioning': 'Aprovisionamiento',
  'Learners': 'Estudiantes',
  'Parents': 'Padres',
  'Links': 'Vínculos',
  'No learners yet': 'Aún no hay estudiantes',
  'Add learners to your site to get started.': 'Agrega estudiantes a tu sede para comenzar.',
  'No parents yet': 'Aún no hay padres',
  'Add parent accounts to link with learners.':
      'Agrega cuentas de padres para vincularlas con estudiantes.',
  'No guardian links': 'No hay vínculos de tutores',
  'Link parents to learners to enable family access.':
      'Vincula padres con estudiantes para habilitar acceso familiar.',
  'Grade': 'Grado',
  'Edit Learner': 'Editar estudiante',
  'Manage Guardian Links': 'Gestionar vínculos de tutores',
  'Edit Parent': 'Editar padre',
  'Manage Learner Links': 'Gestionar vínculos de estudiantes',
  'Primary': 'Principal',
  'Delete Link': 'Eliminar vínculo',
  'Cancel': 'Cancelar',
  'Delete': 'Eliminar',
  'No site selected': 'No hay sede seleccionada',
  'Learner created successfully': 'Estudiante creado correctamente',
  'Failed to create learner': 'No se pudo crear el estudiante',
  'Add Learner': 'Agregar estudiante',
  'Full Name': 'Nombre completo',
  'Required': 'Obligatorio',
  'Email': 'Correo electrónico',
  'Invalid email': 'Correo electrónico inválido',
  'Grade Level': 'Nivel de grado',
  'Create': 'Crear',
  'Parent created successfully': 'Padre creado correctamente',
  'Failed to create parent': 'No se pudo crear el padre',
  'Add Parent': 'Agregar padre',
  'Phone (optional)': 'Teléfono (opcional)',
  'Link removed': 'Vínculo eliminado',
  'Failed to remove link': 'No se pudo eliminar el vínculo',
  'Guardian link created successfully': 'Vínculo de tutor creado correctamente',
  'Failed to create link': 'No se pudo crear el vínculo',
  'Learner updated': 'Estudiante actualizado',
  'Failed to update learner': 'No se pudo actualizar el estudiante',
  'Parent updated': 'Padre actualizado',
  'Failed to update parent': 'No se pudo actualizar el padre',
  'Father': 'Padre',
  'Mother': 'Madre',
  'Guardian': 'Tutor',
  'Grandparent': 'Abuelo/Abuela',
  'Other': 'Otro',
  'Create Guardian Link': 'Crear vínculo de tutor',
  'Parent': 'Padre',
  'No parents available': 'No hay padres disponibles',
  'Learner': 'Estudiante',
  'No learners available': 'No hay estudiantes disponibles',
  'Relationship': 'Relación',
  'Primary guardian': 'Tutor principal',
  'Receives all notifications': 'Recibe todas las notificaciones',
  'Create Link': 'Crear vínculo',
  'Save': 'Guardar',
  'Phone': 'Teléfono',
};

String _tProvisioning(BuildContext context, String input) {
  final String locale = Localizations.localeOf(context).languageCode;
  if (locale != 'es') return input;
  return _provisioningEs[input] ?? input;
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
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        return;
      }
      final String tab = switch (_tabController.index) {
        0 => 'learners',
        1 => 'parents',
        2 => 'links',
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
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const <Widget>[
          _LearnersTab(),
          _ParentsTab(),
          _LinksTab(),
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
      case 1:
        _showCreateParentDialog(context);
      case 2:
        _showCreateLinkDialog(context);
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
                    content: Text(
                        success
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
              validator: (String? v) =>
                  v?.isEmpty ?? true ? _tProvisioning(context, 'Required') : null,
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
                if (v?.isEmpty ?? true) return _tProvisioning(context, 'Required');
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
            content: Text(_tProvisioning(context, 'Parent created successfully'))),
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
              validator: (String? v) =>
                  v?.isEmpty ?? true ? _tProvisioning(context, 'Required') : null,
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
                if (v?.isEmpty ?? true) return _tProvisioning(context, 'Required');
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
            content: Text(
                service.error ?? _tProvisioning(context, 'Failed to create link'))),
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
                          child:
                              Text(_tProvisioning(context, 'No parents available')),
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
                          child:
                              Text(_tProvisioning(context, 'No learners available')),
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
              validator: (String? v) =>
                  v?.isEmpty ?? true ? _tProvisioning(context, 'Required') : null,
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
              validator: (String? v) =>
                  v?.isEmpty ?? true ? _tProvisioning(context, 'Required') : null,
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
