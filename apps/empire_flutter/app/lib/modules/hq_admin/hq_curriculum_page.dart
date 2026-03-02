import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/firestore_service.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';

const Map<String, String> _hqCurriculumEs = <String, String>{
  'Curriculum Manager': 'Gestor curricular',
  'Published': 'Publicado',
  'In Review': 'En revisión',
  'Drafts': 'Borradores',
  'New Curriculum': 'Nuevo currículo',
  'No': 'No',
  'curricula': 'currículos',
  'Updated': 'Actualizado',
  'Version': 'Versión',
  'Status': 'Estado',
  'Close': 'Cerrar',
  'Opening curriculum editor...': 'Abriendo editor curricular...',
  'Edit': 'Editar',
  'Rubric applied to this curriculum':
      'Rúbrica aplicada a este currículo',
  'Apply Rubric': 'Aplicar rúbrica',
  'Parent summary shared': 'Resumen para familias compartido',
  'Share Parent Summary': 'Compartir resumen para familias',
  'Title': 'Título',
  'Pillar': 'Pilar',
  'Future Skills': 'Habilidades del futuro',
  'Leadership & Agency': 'Liderazgo y agencia',
  'Impact & Innovation': 'Impacto e innovación',
  'Cancel': 'Cancelar',
  'Curriculum created': 'Currículo creado',
  'Create': 'Crear',
  'v': 'v',
  'h ago': 'h atrás',
  'd ago': 'd atrás',
  'draft': 'borrador',
  'review': 'revisión',
  'published': 'publicado',
  'Loading...': 'Cargando...',
  'Create failed': 'Error al crear currículo',
};

String _tHqCurriculum(BuildContext context, String input) {
  final String locale = Localizations.localeOf(context).languageCode;
  if (locale != 'es') return input;
  return _hqCurriculumEs[input] ?? input;
}

/// HQ Curriculum page for managing curriculum versions and rubrics
/// Based on docs/45_CURRICULUM_VERSIONING_RUBRICS_SPEC.md
class HqCurriculumPage extends StatefulWidget {
  const HqCurriculumPage({super.key});

  @override
  State<HqCurriculumPage> createState() => _HqCurriculumPageState();
}

enum _CurriculumStatus {
  draft,
  review,
  published,
}

class _Curriculum {
  const _Curriculum({
    required this.id,
    required this.title,
    required this.pillar,
    required this.version,
    required this.status,
    required this.lastUpdated,
  });

  final String id;
  final String title;
  final String pillar;
  final String version;
  final _CurriculumStatus status;
  final DateTime lastUpdated;
}

class _HqCurriculumPageState extends State<HqCurriculumPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  final List<_Curriculum> _fallbackCurricula = <_Curriculum>[
    _Curriculum(
      id: '1',
      title: 'AI Fundamentals',
      pillar: 'Future Skills',
      version: '2.0',
      status: _CurriculumStatus.published,
      lastUpdated: DateTime.now().subtract(const Duration(days: 7)),
    ),
    _Curriculum(
      id: '2',
      title: 'Leadership Essentials',
      pillar: 'Leadership & Agency',
      version: '1.5',
      status: _CurriculumStatus.published,
      lastUpdated: DateTime.now().subtract(const Duration(days: 30)),
    ),
    _Curriculum(
      id: '3',
      title: 'Community Impact Projects',
      pillar: 'Impact & Innovation',
      version: '3.0',
      status: _CurriculumStatus.review,
      lastUpdated: DateTime.now().subtract(const Duration(days: 2)),
    ),
    _Curriculum(
      id: '4',
      title: 'Robotics Intro',
      pillar: 'Future Skills',
      version: '1.0-beta',
      status: _CurriculumStatus.draft,
      lastUpdated: DateTime.now().subtract(const Duration(hours: 6)),
    ),
  ];
  List<_Curriculum> _curricula = <_Curriculum>[];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurricula();
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
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: Text(_tHqCurriculum(context, 'Curriculum Manager')),
        backgroundColor: ScholesaColors.hqGradient.colors.first,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          onTap: (int index) {
            final String tab = switch (index) {
              0 => 'published',
              1 => 'in_review',
              2 => 'drafts',
              _ => 'unknown',
            };
            TelemetryService.instance.logEvent(
              event: 'cta.clicked',
              metadata: <String, dynamic>{
                'module': 'hq_curriculum',
                'cta_id': 'change_tab',
                'surface': 'appbar_tab_bar',
                'tab': tab,
              },
            );
          },
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: <Widget>[
            Tab(text: _tHqCurriculum(context, 'Published')),
            Tab(text: _tHqCurriculum(context, 'In Review')),
            Tab(text: _tHqCurriculum(context, 'Drafts')),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          TelemetryService.instance.logEvent(
            event: 'cta.clicked',
            metadata: <String, dynamic>{
              'module': 'hq_curriculum',
              'cta_id': 'open_create_curriculum_dialog',
              'surface': 'floating_action_button',
            },
          );
          _showCreateDialog();
        },
        backgroundColor: ScholesaColors.hqGradient.colors.first,
        icon: const Icon(Icons.add_rounded),
        label: Text(_tHqCurriculum(context, 'New Curriculum')),
      ),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          _buildCurriculumList(_CurriculumStatus.published),
          _buildCurriculumList(_CurriculumStatus.review),
          _buildCurriculumList(_CurriculumStatus.draft),
        ],
      ),
    );
  }

  Widget _buildCurriculumList(_CurriculumStatus status) {
    if (_isLoading) {
      return Center(
        child: Text(
          _tHqCurriculum(context, 'Loading...'),
          style: const TextStyle(color: ScholesaColors.textSecondary),
        ),
      );
    }

    final List<_Curriculum> filtered =
        _curricula.where((_Curriculum c) => c.status == status).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.menu_book_rounded,
                size: 64,
                color: ScholesaColors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              '${_tHqCurriculum(context, 'No')} ${_tHqCurriculum(context, status.name)} ${_tHqCurriculum(context, 'curricula')}',
                style: const TextStyle(color: ScholesaColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (BuildContext context, int index) =>
          _buildCurriculumCard(filtered[index]),
    );
  }

  Widget _buildCurriculumCard(_Curriculum curriculum) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showCurriculumDetails(curriculum),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _buildPillarIcon(curriculum.pillar),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(curriculum.title,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(_tHqCurriculum(context, curriculum.pillar),
                            style: TextStyle(
                                fontSize: 12,
                                color: _getPillarColor(curriculum.pillar))),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ScholesaColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${_tHqCurriculum(context, 'v')}${curriculum.version}',
                        style: const TextStyle(
                            fontSize: 12, color: ScholesaColors.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${_tHqCurriculum(context, 'Updated')} ${_formatTime(curriculum.lastUpdated)}',
                style: const TextStyle(
                    fontSize: 12, color: ScholesaColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPillarIcon(String pillar) {
    IconData icon;
    Color color = _getPillarColor(pillar);
    switch (pillar) {
      case 'Future Skills':
        icon = Icons.psychology_rounded;
      case 'Leadership & Agency':
        icon = Icons.groups_rounded;
      case 'Impact & Innovation':
        icon = Icons.lightbulb_rounded;
      default:
        icon = Icons.star_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Color _getPillarColor(String pillar) {
    switch (pillar) {
      case 'Future Skills':
        return Colors.blue;
      case 'Leadership & Agency':
        return Colors.purple;
      case 'Impact & Innovation':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _showCurriculumDetails(_Curriculum curriculum) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'hq_curriculum',
        'cta_id': 'open_curriculum_details',
        'surface': 'curriculum_card',
        'curriculum_id': curriculum.id,
        'status': curriculum.status.name,
      },
    );
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ScholesaColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(curriculum.title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_tHqCurriculum(context, curriculum.pillar),
                style: TextStyle(color: _getPillarColor(curriculum.pillar))),
            const SizedBox(height: 16),
            _buildDetailRow(_tHqCurriculum(context, 'Version'), curriculum.version),
            _buildDetailRow(_tHqCurriculum(context, 'Status'),
              _tHqCurriculum(context, curriculum.status.name).toUpperCase()),
            _buildDetailRow(
              _tHqCurriculum(context, 'Updated'), _formatTime(curriculum.lastUpdated)),
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: <String, dynamic>{
                          'module': 'hq_curriculum',
                          'cta_id': 'close_curriculum_details',
                          'surface': 'curriculum_details_sheet',
                          'curriculum_id': curriculum.id,
                        },
                      );
                      Navigator.pop(context);
                    },
                    child: Text(_tHqCurriculum(context, 'Close')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: <String, dynamic>{
                          'module': 'hq_curriculum',
                          'cta_id': 'open_curriculum_editor',
                          'surface': 'curriculum_details_sheet',
                          'curriculum_id': curriculum.id,
                        },
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(_tHqCurriculum(
                                context, 'Opening curriculum editor...'))),
                      );
                    },
                    child: Text(_tHqCurriculum(context, 'Edit')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  TelemetryService.instance.logEvent(
                    event: 'rubric.applied',
                    metadata: <String, dynamic>{
                      'module': 'hq_curriculum',
                      'curriculum_id': curriculum.id,
                      'source': 'curriculum_details_sheet',
                    },
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(_tHqCurriculum(
                            context, 'Rubric applied to this curriculum'))),
                  );
                },
                icon: const Icon(Icons.rule_rounded),
                label: Text(_tHqCurriculum(context, 'Apply Rubric')),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  TelemetryService.instance.logEvent(
                    event: 'rubric.shared_to_parent_summary',
                    metadata: <String, dynamic>{
                      'module': 'hq_curriculum',
                      'curriculum_id': curriculum.id,
                      'source': 'curriculum_details_sheet',
                    },
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text(_tHqCurriculum(context, 'Parent summary shared'))),
                  );
                },
                icon: const Icon(Icons.share_rounded),
                label: Text(_tHqCurriculum(context, 'Share Parent Summary')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label,
              style: const TextStyle(color: ScholesaColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _showCreateDialog() {
    final TextEditingController titleController = TextEditingController();
    String selectedPillar = 'Future Skills';

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder:
            (BuildContext context, void Function(void Function()) setLocalState) {
          return AlertDialog(
            backgroundColor: ScholesaColors.surface,
            title: Text(_tHqCurriculum(context, 'New Curriculum')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: _tHqCurriculum(context, 'Title'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedPillar,
                  decoration: InputDecoration(
                    labelText: _tHqCurriculum(context, 'Pillar'),
                    border: const OutlineInputBorder(),
                  ),
                  items: <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                      value: 'Future Skills',
                      child: Text(_tHqCurriculum(context, 'Future Skills')),
                    ),
                    DropdownMenuItem<String>(
                      value: 'Leadership & Agency',
                      child:
                          Text(_tHqCurriculum(context, 'Leadership & Agency')),
                    ),
                    DropdownMenuItem<String>(
                      value: 'Impact & Innovation',
                      child:
                          Text(_tHqCurriculum(context, 'Impact & Innovation')),
                    ),
                  ],
                  onChanged: (String? value) {
                    if (value != null) {
                      setLocalState(() => selectedPillar = value);
                    }
                  },
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  TelemetryService.instance.logEvent(
                    event: 'cta.clicked',
                    metadata: const <String, dynamic>{
                      'module': 'hq_curriculum',
                      'cta_id': 'cancel_create_curriculum',
                      'surface': 'create_curriculum_dialog',
                    },
                  );
                  Navigator.pop(dialogContext);
                },
                child: Text(_tHqCurriculum(context, 'Cancel')),
              ),
              ElevatedButton(
                onPressed: () async {
                  final String title = titleController.text.trim();
                  if (title.isEmpty) {
                    Navigator.pop(dialogContext);
                    return;
                  }

                  TelemetryService.instance.logEvent(
                    event: 'cta.clicked',
                    metadata: const <String, dynamic>{
                      'module': 'hq_curriculum',
                      'cta_id': 'submit_create_curriculum',
                      'surface': 'create_curriculum_dialog',
                    },
                  );
                  TelemetryService.instance.logEvent(
                    event: 'mission.snapshot.created',
                    metadata: <String, dynamic>{
                      'module': 'hq_curriculum',
                      'source': 'create_curriculum_dialog',
                    },
                  );

                  Navigator.pop(dialogContext);
                  await _createCurriculum(title: title, pillar: selectedPillar);
                },
                child: Text(_tHqCurriculum(context, 'Create')),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatTime(DateTime time) {
    final Duration diff = DateTime.now().difference(time);
    if (diff.inHours < 24) return '${diff.inHours}${_tHqCurriculum(context, 'h ago')}';
    return '${diff.inDays}${_tHqCurriculum(context, 'd ago')}';
  }

  Future<void> _loadCurricula() async {
    final FirestoreService? firestoreService = _maybeFirestoreService();
    if (firestoreService == null) {
      if (!mounted) return;
      setState(() => _curricula = _fallbackCurricula);
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await firestoreService.firestore
            .collection('missions')
            .orderBy('updatedAt', descending: true)
            .limit(200)
            .get();
      } catch (_) {
        snapshot = await firestoreService.firestore
            .collection('missions')
            .limit(200)
            .get();
      }

      final List<_Curriculum> loaded = snapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        final String title = (data['title'] as String?)?.trim().isNotEmpty == true
            ? (data['title'] as String).trim()
            : 'Curriculum';

        final DateTime lastUpdated = _toDateTime(data['updatedAt']) ??
            _toDateTime(data['createdAt']) ??
            DateTime.now();

        return _Curriculum(
          id: doc.id,
          title: title,
          pillar: _pillarFromData(data),
          version: (data['version'] as String?) ?? '1.0',
          status: _parseCurriculumStatus(data['status'] as String?),
          lastUpdated: lastUpdated,
        );
      }).toList();

      loaded.sort((_Curriculum a, _Curriculum b) =>
          b.lastUpdated.compareTo(a.lastUpdated));

      if (!mounted) return;
      setState(() => _curricula = loaded);
    } catch (_) {
      if (!mounted) return;
      setState(() => _curricula = _fallbackCurricula);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createCurriculum({
    required String title,
    required String pillar,
  }) async {
    final FirestoreService? firestoreService = _maybeFirestoreService();
    if (firestoreService == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tHqCurriculum(context, 'Curriculum created'))),
      );
      return;
    }

    try {
      final String pillarCode = _pillarCodeFromLabel(pillar);
      await firestoreService.firestore.collection('missions').add(<String, dynamic>{
        'title': title,
        'description': title,
        'pillar': pillar,
        'pillarCode': pillarCode,
        'pillarCodes': <String>[pillarCode],
        'status': 'draft',
        'version': '1.0',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tHqCurriculum(context, 'Curriculum created'))),
      );
      await _loadCurricula();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tHqCurriculum(context, 'Create failed'))),
      );
    }
  }

  _CurriculumStatus _parseCurriculumStatus(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'published':
      case 'active':
        return _CurriculumStatus.published;
      case 'review':
      case 'in_review':
      case 'pending_review':
        return _CurriculumStatus.review;
      default:
        return _CurriculumStatus.draft;
    }
  }

  String _pillarFromData(Map<String, dynamic> data) {
    final String? direct = data['pillar'] as String?;
    if (direct != null && direct.trim().isNotEmpty) {
      return direct.trim();
    }
    final String? pillarCode = data['pillarCode'] as String?;
    if (pillarCode != null && pillarCode.trim().isNotEmpty) {
      return _pillarLabelFromCode(pillarCode);
    }
    final List<dynamic> pillarCodes = (data['pillarCodes'] as List?) ?? <dynamic>[];
    if (pillarCodes.isNotEmpty) {
      return _pillarLabelFromCode(pillarCodes.first.toString());
    }
    return 'Future Skills';
  }

  String _pillarLabelFromCode(String raw) {
    final String code = raw.trim().toUpperCase();
    switch (code) {
      case 'LEAD':
      case 'LEADERSHIP':
        return 'Leadership & Agency';
      case 'IMP':
      case 'IMPACT':
        return 'Impact & Innovation';
      default:
        return 'Future Skills';
    }
  }

  String _pillarCodeFromLabel(String label) {
    final String value = label.trim().toLowerCase();
    if (value.contains('leadership')) return 'LEAD';
    if (value.contains('impact')) return 'IMP';
    return 'FS';
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }

  FirestoreService? _maybeFirestoreService() {
    try {
      return context.read<FirestoreService>();
    } catch (_) {
      return null;
    }
  }
}
