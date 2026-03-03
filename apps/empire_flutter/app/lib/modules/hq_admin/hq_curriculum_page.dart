import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../auth/app_state.dart';
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
  'Create Snapshot': 'Crear snapshot',
  'Snapshot created': 'Snapshot creado',
  'Snapshot create failed': 'Error al crear snapshot',
  'Create Rubric': 'Crear rúbrica',
  'Rubric title': 'Título de rúbrica',
  'Criteria (comma-separated)': 'Criterios (separados por coma)',
  'Rubric title is required': 'El título de la rúbrica es obligatorio',
  'At least one criterion is required': 'Se requiere al menos un criterio',
  'Curriculum updated': 'Currículo actualizado',
  'Update failed': 'Error al actualizar currículo',
  'Rubric apply failed': 'Error al aplicar rúbrica',
  'Share failed': 'Error al compartir resumen',
  'Title': 'Título',
  'Pillar': 'Pilar',
  'Future Skills': 'Habilidades del futuro',
  'Leadership & Agency': 'Liderazgo y agencia',
  'Impact & Innovation': 'Impacto e innovación',
  'Cancel': 'Cancelar',
  'Curriculum created': 'Currículo creado',
  'Create': 'Crear',
  'Title is required': 'El título es obligatorio',
  'v': 'v',
  'h ago': 'h atrás',
  'd ago': 'd atrás',
  'draft': 'borrador',
  'review': 'revisión',
  'published': 'publicado',
  'Loading...': 'Cargando...',
  'Create failed': 'Error al crear currículo',
  'Submit for Review': 'Enviar a revisión',
  'Publish Curriculum': 'Publicar currículo',
  'Moved to In Review': 'Movido a En revisión',
  'Curriculum published': 'Currículo publicado',
  'Transition failed': 'Error al cambiar estado',
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

  final List<_Curriculum> _fallbackCurricula = <_Curriculum>[];
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
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(curriculum.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: ScholesaColors.textPrimary,
                )),
            const SizedBox(height: 8),
            Text(_tHqCurriculum(context, curriculum.pillar),
                style: TextStyle(
                  color: _getPillarColor(curriculum.pillar),
                  fontWeight: FontWeight.w600,
                )),
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
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ScholesaColors.textPrimary,
                      side: const BorderSide(color: ScholesaColors.border),
                    ),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ScholesaColors.primary,
                      foregroundColor: Colors.white,
                    ),
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
                      _showEditDialog(curriculum);
                    },
                    child: Text(_tHqCurriculum(context, 'Edit')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ScholesaColors.hq,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  TelemetryService.instance.logEvent(
                    event: 'cta.clicked',
                    metadata: <String, dynamic>{
                      'module': 'hq_curriculum',
                      'cta_id': 'create_mission_snapshot',
                      'surface': 'curriculum_details_sheet',
                      'curriculum_id': curriculum.id,
                    },
                  );
                  Navigator.pop(context);
                  await _createMissionSnapshot(curriculum);
                },
                icon: const Icon(Icons.copy_all_rounded),
                label: Text(_tHqCurriculum(context, 'Create Snapshot')),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: _buildAdvanceStatusButton(curriculum),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: ScholesaColors.textPrimary,
                  side: const BorderSide(color: ScholesaColors.border),
                ),
                onPressed: () async {
                  TelemetryService.instance.logEvent(
                    event: 'rubric.applied',
                    metadata: <String, dynamic>{
                      'module': 'hq_curriculum',
                      'curriculum_id': curriculum.id,
                      'source': 'curriculum_details_sheet',
                    },
                  );
                  Navigator.pop(context);
                  _showRubricWorkflowDialog(curriculum);
                },
                icon: const Icon(Icons.rule_rounded),
                label: Text(_tHqCurriculum(context, 'Apply Rubric')),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ScholesaColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  TelemetryService.instance.logEvent(
                    event: 'rubric.shared_to_parent_summary',
                    metadata: <String, dynamic>{
                      'module': 'hq_curriculum',
                      'curriculum_id': curriculum.id,
                      'source': 'curriculum_details_sheet',
                    },
                  );
                  Navigator.pop(context);
                  await _shareParentSummary(curriculum);
                },
                icon: const Icon(Icons.share_rounded),
                label: Text(_tHqCurriculum(context, 'Share Parent Summary')),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildAdvanceStatusButton(_Curriculum curriculum) {
    final _CurriculumStatus? targetStatus = _nextStatus(curriculum.status);
    if (targetStatus == null) {
      return const SizedBox.shrink();
    }

    final bool isPublishing = targetStatus == _CurriculumStatus.published;
    final String label = isPublishing
        ? _tHqCurriculum(context, 'Publish Curriculum')
        : _tHqCurriculum(context, 'Submit for Review');

    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: ScholesaColors.primary,
        foregroundColor: Colors.white,
      ),
      onPressed: () async {
        TelemetryService.instance.logEvent(
          event: 'curriculum.status.transition',
          metadata: <String, dynamic>{
            'module': 'hq_curriculum',
            'curriculum_id': curriculum.id,
            'from_status': curriculum.status.name,
            'to_status': targetStatus.name,
            'source': 'curriculum_details_sheet',
          },
        );
        Navigator.pop(context);
        await _advanceCurriculumStatus(curriculum, targetStatus);
      },
      icon: Icon(
        isPublishing ? Icons.publish_rounded : Icons.rate_review_rounded,
      ),
      label: Text(label),
    );
  }

  _CurriculumStatus? _nextStatus(_CurriculumStatus current) {
    switch (current) {
      case _CurriculumStatus.draft:
        return _CurriculumStatus.review;
      case _CurriculumStatus.review:
        return _CurriculumStatus.published;
      case _CurriculumStatus.published:
        return null;
    }
  }

  Future<void> _advanceCurriculumStatus(
    _Curriculum curriculum,
    _CurriculumStatus targetStatus,
  ) async {
    final FirestoreService? firestoreService = _maybeFirestoreService();
    final AppState? appState = _maybeAppState();
    if (firestoreService == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tHqCurriculum(context, 'Transition failed'))),
      );
      return;
    }

    final DateTime now = DateTime.now();
    final bool isPublishing = targetStatus == _CurriculumStatus.published;

    try {
      final Map<String, dynamic> updates = <String, dynamic>{
        'status': targetStatus.name,
        'published': isPublishing,
      };

      if (targetStatus == _CurriculumStatus.review) {
        updates['reviewSubmittedAt'] = FieldValue.serverTimestamp();
        updates['reviewSubmittedBy'] = appState?.userId;
      }

      if (isPublishing) {
        updates['publishedAt'] = FieldValue.serverTimestamp();
        updates['publishedBy'] = appState?.userId;
      }

      await firestoreService.updateDocument('missions', curriculum.id, updates);

      _replaceLocalCurriculum(
        curriculum.id,
        status: targetStatus,
        lastUpdated: now,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tHqCurriculum(
              context,
              isPublishing ? 'Curriculum published' : 'Moved to In Review',
            ),
          ),
        ),
      );

      if (_tabController.index != targetStatus.index) {
        _tabController.animateTo(targetStatus.index);
      }

      await _loadCurricula();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tHqCurriculum(context, 'Transition failed'))),
      );
    }
  }

  void _showEditDialog(_Curriculum curriculum) {
    final TextEditingController titleController =
        TextEditingController(text: curriculum.title);
    String selectedPillar = curriculum.pillar;
    bool isSubmitting = false;

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder:
            (BuildContext context, void Function(void Function()) setLocalState) {
          return AlertDialog(
            backgroundColor: ScholesaColors.surface,
            surfaceTintColor: ScholesaColors.surface,
            scrollable: true,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            title: Text(_tHqCurriculum(context, 'Edit')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  controller: titleController,
                  style: const TextStyle(
                    color: ScholesaColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    labelText: _tHqCurriculum(context, 'Title'),
                    labelStyle: const TextStyle(color: ScholesaColors.textSecondary),
                    filled: true,
                    fillColor: ScholesaColors.surfaceVariant,
                    border: const OutlineInputBorder(),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: ScholesaColors.border),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: ScholesaColors.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedPillar,
                  style: const TextStyle(
                    color: ScholesaColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  dropdownColor: ScholesaColors.surface,
                  iconEnabledColor: ScholesaColors.textSecondary,
                  decoration: InputDecoration(
                    labelText: _tHqCurriculum(context, 'Pillar'),
                    labelStyle: const TextStyle(color: ScholesaColors.textSecondary),
                    filled: true,
                    fillColor: ScholesaColors.surfaceVariant,
                    border: const OutlineInputBorder(),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: ScholesaColors.border),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: ScholesaColors.primary, width: 1.5),
                    ),
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
                style: TextButton.styleFrom(
                  foregroundColor: ScholesaColors.textPrimary,
                ),
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(_tHqCurriculum(context, 'Cancel')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ScholesaColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final String title = titleController.text.trim();
                        if (title.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  _tHqCurriculum(context, 'Title is required')),
                            ),
                          );
                          return;
                        }

                        setLocalState(() => isSubmitting = true);
                        final bool updated = await _updateCurriculum(
                          curriculum,
                          title: title,
                          pillar: selectedPillar,
                        );
                        if (!mounted || !dialogContext.mounted) return;
                        if (updated) {
                          Navigator.pop(dialogContext);
                        } else {
                          setLocalState(() => isSubmitting = false);
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_tHqCurriculum(context, 'Edit')),
              ),
            ],
          );
        },
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
              style: const TextStyle(
                color: ScholesaColors.textSecondary,
                fontWeight: FontWeight.w600,
              )),
          Text(
            value,
            style: const TextStyle(
              color: ScholesaColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog() {
    final TextEditingController titleController = TextEditingController();
    String selectedPillar = 'Future Skills';
    bool isSubmitting = false;

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder:
            (BuildContext context, void Function(void Function()) setLocalState) {
          return AlertDialog(
            backgroundColor: ScholesaColors.surface,
            surfaceTintColor: ScholesaColors.surface,
            scrollable: true,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            title: Text(_tHqCurriculum(context, 'New Curriculum')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  controller: titleController,
                  style: const TextStyle(
                    color: ScholesaColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    labelText: _tHqCurriculum(context, 'Title'),
                    labelStyle: const TextStyle(color: ScholesaColors.textSecondary),
                    filled: true,
                    fillColor: ScholesaColors.surfaceVariant,
                    border: const OutlineInputBorder(),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: ScholesaColors.border),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: ScholesaColors.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedPillar,
                  style: const TextStyle(
                    color: ScholesaColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  dropdownColor: ScholesaColors.surface,
                  iconEnabledColor: ScholesaColors.textSecondary,
                  decoration: InputDecoration(
                    labelText: _tHqCurriculum(context, 'Pillar'),
                    labelStyle: const TextStyle(color: ScholesaColors.textSecondary),
                    filled: true,
                    fillColor: ScholesaColors.surfaceVariant,
                    border: const OutlineInputBorder(),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: ScholesaColors.border),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: ScholesaColors.primary, width: 1.5),
                    ),
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
                style: TextButton.styleFrom(
                  foregroundColor: ScholesaColors.textPrimary,
                ),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: ScholesaColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                  final String title = titleController.text.trim();
                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text(_tHqCurriculum(context, 'Title is required'))),
                    );
                    return;
                  }

                  setLocalState(() => isSubmitting = true);

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

                  final bool created = await _createCurriculum(
                    title: title,
                    pillar: selectedPillar,
                  );

                  if (!mounted || !dialogContext.mounted) return;
                  if (created) {
                    Navigator.pop(dialogContext);
                  } else {
                    setLocalState(() => isSubmitting = false);
                  }
                },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_tHqCurriculum(context, 'Create')),
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

  Future<bool> _createCurriculum({
    required String title,
    required String pillar,
  }) async {
    final AppState? appState = _maybeAppState();
    final FirestoreService? firestoreService = _maybeFirestoreService();
    if (firestoreService == null) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tHqCurriculum(context, 'Create failed'))),
      );
      return false;
    }

    try {
      final String pillarCode = _pillarCodeFromLabel(pillar);
      final String? actorRole = appState?.role?.name;
      final String? actorId = appState?.userId;
      final String? activeSiteId = appState?.activeSiteId;

      final String createdId = await firestoreService.createDocument(
        'missions',
        <String, dynamic>{
        'title': title,
        'description': title,
        'pillar': pillar,
        'pillarCode': pillarCode,
        'pillarCodes': <String>[pillarCode],
        'siteId': activeSiteId,
        'createdBy': actorId,
        'createdByRole': actorRole,
        'publisherType': actorRole ?? 'hq',
        'published': false,
        'status': 'draft',
        'version': '1.0',
        },
      );

      final _Curriculum created = _Curriculum(
        id: createdId,
        title: title,
        pillar: pillar,
        version: '1.0',
        status: _CurriculumStatus.draft,
        lastUpdated: DateTime.now(),
      );

      if (mounted) {
        setState(() {
          _curricula = <_Curriculum>[created, ..._curricula];
        });
      }

      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tHqCurriculum(context, 'Curriculum created'))),
      );
      await _loadCurricula();
      return true;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tHqCurriculum(context, 'Create failed'))),
      );
      return false;
    }
  }

  Future<bool> _updateCurriculum(
    _Curriculum curriculum, {
    required String title,
    required String pillar,
  }) async {
    final FirestoreService? firestoreService = _maybeFirestoreService();
    if (firestoreService == null) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tHqCurriculum(context, 'Update failed'))),
      );
      return false;
    }

    try {
      final String pillarCode = _pillarCodeFromLabel(pillar);
      await firestoreService.updateDocument('missions', curriculum.id, <String, dynamic>{
        'title': title,
        'description': title,
        'pillar': pillar,
        'pillarCode': pillarCode,
        'pillarCodes': <String>[pillarCode],
      });

      _replaceLocalCurriculum(
        curriculum.id,
        title: title,
        pillar: pillar,
        lastUpdated: DateTime.now(),
      );

      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tHqCurriculum(context, 'Curriculum updated'))),
      );
      await _loadCurricula();
      return true;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tHqCurriculum(context, 'Update failed'))),
      );
      return false;
    }
  }

  void _showRubricWorkflowDialog(_Curriculum curriculum) {
    final TextEditingController titleController = TextEditingController(
      text: '${curriculum.title} Rubric',
    );
    final TextEditingController criteriaController = TextEditingController(
      text: 'Clarity, Evidence, Agency',
    );
    bool isSubmitting = false;

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder:
            (BuildContext context, void Function(void Function()) setLocalState) {
          return AlertDialog(
            backgroundColor: ScholesaColors.surface,
            surfaceTintColor: ScholesaColors.surface,
            scrollable: true,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            title: Text(_tHqCurriculum(context, 'Create Rubric')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  controller: titleController,
                  style: const TextStyle(
                    color: ScholesaColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    labelText: _tHqCurriculum(context, 'Rubric title'),
                    labelStyle: const TextStyle(color: ScholesaColors.textSecondary),
                    filled: true,
                    fillColor: ScholesaColors.surfaceVariant,
                    border: const OutlineInputBorder(),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: ScholesaColors.border),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: ScholesaColors.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: criteriaController,
                  minLines: 2,
                  maxLines: 4,
                  style: const TextStyle(
                    color: ScholesaColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    labelText:
                        _tHqCurriculum(context, 'Criteria (comma-separated)'),
                    labelStyle: const TextStyle(color: ScholesaColors.textSecondary),
                    filled: true,
                    fillColor: ScholesaColors.surfaceVariant,
                    border: const OutlineInputBorder(),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: ScholesaColors.border),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: ScholesaColors.primary, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: ScholesaColors.textPrimary,
                ),
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(_tHqCurriculum(context, 'Cancel')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ScholesaColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final String rubricTitle = titleController.text.trim();
                        final List<String> criteria = criteriaController.text
                            .split(',')
                            .map((String item) => item.trim())
                            .where((String item) => item.isNotEmpty)
                            .toList();

                        if (rubricTitle.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_tHqCurriculum(
                                  context, 'Rubric title is required')),
                            ),
                          );
                          return;
                        }

                        if (criteria.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_tHqCurriculum(
                                  context, 'At least one criterion is required')),
                            ),
                          );
                          return;
                        }

                        setLocalState(() => isSubmitting = true);
                        final bool applied = await _createAndApplyRubric(
                          curriculum,
                          rubricTitle: rubricTitle,
                          criteriaLabels: criteria,
                        );

                        if (!mounted || !dialogContext.mounted) return;
                        if (applied) {
                          Navigator.pop(dialogContext);
                        } else {
                          setLocalState(() => isSubmitting = false);
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_tHqCurriculum(context, 'Apply Rubric')),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<bool> _createAndApplyRubric(
    _Curriculum curriculum, {
    required String rubricTitle,
    required List<String> criteriaLabels,
  }) async {
    final FirestoreService? firestoreService = _maybeFirestoreService();
    final AppState? appState = _maybeAppState();
    if (firestoreService == null) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tHqCurriculum(context, 'Rubric apply failed'))),
      );
      return false;
    }

    try {
      final List<Map<String, dynamic>> criteria = criteriaLabels
          .asMap()
          .entries
          .map((MapEntry<int, String> entry) => <String, dynamic>{
                'id': 'c${entry.key + 1}',
                'label': entry.value,
                'pillarCode': _pillarCodeFromLabel(curriculum.pillar),
                'levels': <int>[0, 1, 2, 3, 4],
              })
          .toList();

      final String rubricId = await firestoreService.createDocument(
        'rubrics',
        <String, dynamic>{
          'title': rubricTitle,
          'siteId': appState?.activeSiteId,
          'criteria': criteria,
          'createdBy': appState?.userId,
          'createdByRole': appState?.role?.name,
        },
      );

      await firestoreService.updateDocument('missions', curriculum.id, <String, dynamic>{
        'rubricApplied': true,
        'rubricId': rubricId,
        'rubricTitle': rubricTitle,
        'rubricAppliedBy': appState?.userId,
        'rubricAppliedAt': FieldValue.serverTimestamp(),
        'status': 'review',
      });

      _replaceLocalCurriculum(
        curriculum.id,
        status: _CurriculumStatus.review,
        lastUpdated: DateTime.now(),
      );

      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(_tHqCurriculum(context, 'Rubric applied to this curriculum')),
        ),
      );
      await _loadCurricula();
      return true;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tHqCurriculum(context, 'Rubric apply failed'))),
      );
      return false;
    }
  }

  Future<void> _createMissionSnapshot(_Curriculum curriculum) async {
    final FirestoreService? firestoreService = _maybeFirestoreService();
    final AppState? appState = _maybeAppState();
    if (firestoreService == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tHqCurriculum(context, 'Snapshot create failed'))),
      );
      return;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> missionDoc =
          await firestoreService.firestore.collection('missions').doc(curriculum.id).get();
      final Map<String, dynamic> mission = missionDoc.data() ?? <String, dynamic>{};

      final String currentVersion =
          (mission['version'] as String?)?.trim().isNotEmpty == true
              ? (mission['version'] as String).trim()
              : curriculum.version;
      final String nextVersion = _incrementVersion(currentVersion);
      final String title = (mission['title'] as String?)?.trim().isNotEmpty == true
          ? (mission['title'] as String).trim()
          : curriculum.title;
      final String description =
          (mission['description'] as String?)?.trim().isNotEmpty == true
              ? (mission['description'] as String).trim()
              : title;
      final List<dynamic> pillarCodes = (mission['pillarCodes'] as List?) ??
          <dynamic>[_pillarCodeFromLabel(curriculum.pillar)];

      final String hashSource = <String>[
        curriculum.id,
        title,
        description,
        pillarCodes.join(','),
        currentVersion,
        DateTime.now().toUtc().toIso8601String(),
      ].join('|');
      final String contentHash = _simpleHash(hashSource);

      final String snapshotId = await firestoreService.createDocument(
        'missionSnapshots',
        <String, dynamic>{
          'missionId': curriculum.id,
          'contentHash': contentHash,
          'title': title,
          'description': description,
          'pillarCodes': pillarCodes,
          'skillIds': (mission['skillIds'] as List?) ?? <dynamic>[],
          'bodyJson': mission['bodyJson'],
          'publisherType': appState?.role?.name ?? 'hq',
          'publisherId': appState?.userId,
          'publishedAt': FieldValue.serverTimestamp(),
          'sourceVersion': currentVersion,
          'snapshotVersion': nextVersion,
        },
      );

      await firestoreService.updateDocument('missions', curriculum.id, <String, dynamic>{
        'version': nextVersion,
        'latestSnapshotId': snapshotId,
        'latestContentHash': contentHash,
      });

      TelemetryService.instance.logEvent(
        event: 'mission.snapshot.created',
        metadata: <String, dynamic>{
          'module': 'hq_curriculum',
          'mission_id': curriculum.id,
          'snapshot_id': snapshotId,
          'source_version': currentVersion,
          'snapshot_version': nextVersion,
        },
      );

      _replaceLocalCurriculum(
        curriculum.id,
        version: nextVersion,
        lastUpdated: DateTime.now(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tHqCurriculum(context, 'Snapshot created'))),
      );
      await _loadCurricula();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tHqCurriculum(context, 'Snapshot create failed'))),
      );
    }
  }

  Future<void> _shareParentSummary(_Curriculum curriculum) async {
    final FirestoreService? firestoreService = _maybeFirestoreService();
    final AppState? appState = _maybeAppState();
    if (firestoreService == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tHqCurriculum(context, 'Share failed'))),
      );
      return;
    }

    try {
      await firestoreService.updateDocument('missions', curriculum.id, <String, dynamic>{
        'parentSummaryShared': true,
        'parentSummarySharedBy': appState?.userId,
        'parentSummarySharedAt': FieldValue.serverTimestamp(),
      });

      _replaceLocalCurriculum(
        curriculum.id,
        lastUpdated: DateTime.now(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tHqCurriculum(context, 'Parent summary shared'))),
      );
      await _loadCurricula();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tHqCurriculum(context, 'Share failed'))),
      );
    }
  }

  void _replaceLocalCurriculum(
    String id, {
    String? title,
    String? pillar,
    String? version,
    _CurriculumStatus? status,
    DateTime? lastUpdated,
  }) {
    if (!mounted) return;
    setState(() {
      _curricula = _curricula.map((_Curriculum entry) {
        if (entry.id != id) return entry;
        return _Curriculum(
          id: entry.id,
          title: title ?? entry.title,
          pillar: pillar ?? entry.pillar,
          version: version ?? entry.version,
          status: status ?? entry.status,
          lastUpdated: lastUpdated ?? entry.lastUpdated,
        );
      }).toList();
    });
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

  String _incrementVersion(String rawVersion) {
    final List<String> parts = rawVersion.trim().split('.');
    final int major = int.tryParse(parts.isNotEmpty ? parts[0] : '1') ?? 1;
    final int minor = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final int patch = int.tryParse(parts.length > 2 ? parts[2] : '0') ?? 0;
    return '$major.$minor.${patch + 1}';
  }

  String _simpleHash(String input) {
    final int hash = input.hashCode & 0x7fffffff;
    return hash.toRadixString(16).padLeft(8, '0');
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

  AppState? _maybeAppState() {
    try {
      return context.read<AppState>();
    } catch (_) {
      return null;
    }
  }
}
