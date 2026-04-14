import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/app_state.dart';
import '../../domain/curriculum/curriculum_family_ui.dart';
import '../../i18n/evidence_chain_i18n.dart';
import '../../services/firestore_service.dart';

/// HQ admin creates and manages rubric templates.
/// Lists existing rubrics, provides forms for creating rubrics with
/// dynamic level definitions (name, criteria, score), and supports CRUD.
class RubricBuilderPage extends StatefulWidget {
  const RubricBuilderPage({super.key});

  @override
  State<RubricBuilderPage> createState() => _RubricBuilderPageState();
}

class _RubricBuilderPageState extends State<RubricBuilderPage> {
  List<Map<String, dynamic>> _rubrics = <Map<String, dynamic>>[];
  bool _isLoading = true;
  String? _error;
  bool _showForm = false;
  String? _editingId;

  // Form state
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedPillar = curriculumLegacyFamilySchemaCode(
    CurriculumLegacyFamilyCode.future_skills,
  );
  List<_RubricLevel> _levels = <_RubricLevel>[];
  bool _isSubmitting = false;

  FirestoreService get _firestoreService => context.read<FirestoreService>();

  String _t(String input) => EvidenceChainI18n.text(context, input);

  List<Map<String, String>> get _pillarOptions {
    return CurriculumLegacyFamilyCode.values
        .map((CurriculumLegacyFamilyCode code) => <String, String>{
              'value': curriculumLegacyFamilySchemaCode(code),
              'label': curriculumLegacyFamilyDisplayLabel(context, code),
            })
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRubrics();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadRubrics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final List<Map<String, dynamic>> rubrics =
          await _firestoreService.queryCollection(
        'rubrics',
        orderBy: 'createdAt',
        descending: true,
      );
      setState(() {
        _rubrics = rubrics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load rubrics: $e';
        _isLoading = false;
      });
    }
  }

  void _openCreateForm() {
    _nameController.clear();
    _descriptionController.clear();
    _selectedPillar = curriculumLegacyFamilySchemaCode(
      CurriculumLegacyFamilyCode.future_skills,
    );
    _levels = <_RubricLevel>[
      _RubricLevel(name: 'Emerging', criteria: '', score: 1),
      _RubricLevel(name: 'Developing', criteria: '', score: 2),
      _RubricLevel(name: 'Proficient', criteria: '', score: 3),
      _RubricLevel(name: 'Advanced', criteria: '', score: 4),
    ];
    _editingId = null;
    setState(() => _showForm = true);
  }

  void _openEditForm(Map<String, dynamic> rubric) {
    _nameController.text = rubric['name'] as String? ?? '';
    _descriptionController.text = rubric['description'] as String? ?? '';
    _selectedPillar = rubric['pillarCode'] as String? ??
        curriculumLegacyFamilySchemaCode(
          CurriculumLegacyFamilyCode.future_skills,
        );

    final List<dynamic> rawLevels =
        rubric['levels'] as List<dynamic>? ?? <dynamic>[];
    _levels = rawLevels
        .map((dynamic l) {
          final Map<String, dynamic> m = l as Map<String, dynamic>? ?? <String, dynamic>{};
          return _RubricLevel(
            name: m['name'] as String? ?? '',
            criteria: m['criteria'] as String? ?? '',
            score: (m['score'] as num?)?.toInt() ?? 0,
          );
        })
        .toList();
    if (_levels.isEmpty) {
      _levels = <_RubricLevel>[
        _RubricLevel(name: 'Emerging', criteria: '', score: 1),
        _RubricLevel(name: 'Developing', criteria: '', score: 2),
        _RubricLevel(name: 'Proficient', criteria: '', score: 3),
        _RubricLevel(name: 'Advanced', criteria: '', score: 4),
      ];
    }

    _editingId = rubric['id'] as String?;
    setState(() => _showForm = true);
  }

  Future<void> _saveRubric() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Rubric name is required.'))),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final AppState appState = context.read<AppState>();

      final List<Map<String, dynamic>> levelsData = _levels
          .where((_RubricLevel l) => l.name.trim().isNotEmpty)
          .map((_RubricLevel l) => <String, dynamic>{
                'name': l.name.trim(),
                'criteria': l.criteria.trim(),
                'score': l.score,
              })
          .toList();

      final Map<String, dynamic> data = <String, dynamic>{
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'pillarCode': _selectedPillar,
        'levels': levelsData,
        'levelCount': levelsData.length,
        'createdBy': appState.userId,
      };

      if (_editingId != null) {
        await _firestoreService.updateDocument('rubrics', _editingId!, data);
      } else {
        await _firestoreService.createDocument('rubrics', data);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_editingId != null ? _t('Rubric updated.') : _t('Rubric created.')),
        ),
      );

      setState(() {
        _showForm = false;
        _editingId = null;
      });
      await _loadRubrics();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_t('Error saving rubric:')} $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteRubric(String id) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(_t('Delete Rubric')),
        content: Text(_t('Are you sure you want to delete this rubric template?')),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_t('Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_t('Delete'))),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _firestoreService.deleteDocument('rubrics', id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Rubric deleted.'))),
      );
      await _loadRubrics();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_t('Error deleting rubric:')} $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('Rubric Builder')),
        actions: <Widget>[
          if (!_showForm)
            IconButton(
              onPressed: _openCreateForm,
              icon: const Icon(Icons.add),
              tooltip: _t('Create Rubric'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                      const SizedBox(height: 12),
                      Text(_error!, style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _loadRubrics,
                        icon: const Icon(Icons.refresh),
                        label: Text(_t('Retry')),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRubrics,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: <Widget>[
                      if (_showForm) _buildForm(),
                      if (!_showForm && _rubrics.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: <Widget>[
                                Icon(Icons.grading_outlined,
                                    size: 48, color: theme.colorScheme.primary),
                                const SizedBox(height: 12),
                                Text(_t('No rubric templates yet.'),
                                    style: theme.textTheme.bodyLarge),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: _openCreateForm,
                                  icon: const Icon(Icons.add),
                                  label: Text(_t('Create First Rubric')),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (!_showForm) ..._rubrics.map(_buildRubricCard),
                    ],
                  ),
                ),
    );
  }

  Widget _buildForm() {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _editingId != null ? _t('Edit Rubric') : _t('Create Rubric'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: _t('Rubric Name'),
                hintText: _t('e.g. Problem Solving Rubric'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: _t('Description'),
                hintText: _t('What does this rubric assess?'),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedPillar,
              decoration: InputDecoration(
                labelText: _t('Pillar'),
                border: OutlineInputBorder(),
              ),
              items: _pillarOptions
                  .map((Map<String, String> p) => DropdownMenuItem<String>(
                        value: p['value'],
                        child: Text(p['label']!),
                      ))
                  .toList(),
              onChanged: (String? val) {
                if (val != null) setState(() => _selectedPillar = val);
              },
            ),
            const SizedBox(height: 16),
            Text(_t('Levels'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            ..._levels.asMap().entries.map(
                  (MapEntry<int, _RubricLevel> entry) =>
                      _buildLevelRow(entry.key, entry.value),
                ),
            TextButton.icon(
              onPressed: () => setState(
                  () => _levels.add(_RubricLevel(name: '', criteria: '', score: _levels.length + 1))),
              icon: const Icon(Icons.add, size: 18),
              label: Text(_t('Add Level')),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                FilledButton(
                  onPressed: _isSubmitting ? null : _saveRubric,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_editingId != null ? _t('Update') : _t('Create')),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() {
                    _showForm = false;
                    _editingId = null;
                  }),
                  child: Text(_t('Cancel')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelRow(int index, _RubricLevel level) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 100,
            child: TextField(
              decoration: InputDecoration(
                labelText: _t('Name'),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: level.name),
              onChanged: (String val) => _levels[index].name = val,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                labelText: _t('Criteria'),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: level.criteria),
              onChanged: (String val) => _levels[index].criteria = val,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: TextField(
              decoration: InputDecoration(
                labelText: _t('Score'),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              controller: TextEditingController(text: level.score.toString()),
              onChanged: (String val) =>
                  _levels[index].score = int.tryParse(val) ?? 0,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, size: 20),
            onPressed: _levels.length > 1
                ? () => setState(() => _levels.removeAt(index))
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildRubricCard(Map<String, dynamic> rubric) {
    final ThemeData theme = Theme.of(context);
    final String id = rubric['id'] as String? ?? '';
    final String name = rubric['name'] as String? ?? 'Untitled Rubric';
    final String description = rubric['description'] as String? ?? '';
    final String pillar = rubric['pillarCode'] as String? ?? '';
    final int levelCount = rubric['levelCount'] as int? ??
        (rubric['levels'] as List<dynamic>?)?.length ??
        0;

    final Color pillarColor = _pillarColor(pillar);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: pillarColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    pillar,
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: pillarColor),
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text('$levelCount ${_t('levels')}', style: const TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _openEditForm(rubric),
                  tooltip: _t('Edit'),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _deleteRubric(id),
                  tooltip: _t('Delete'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(name, style: theme.textTheme.titleMedium),
            if (description.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(description, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }

  Color _pillarColor(String pillar) {
    switch (pillar) {
      case 'futureSkills':
        return Colors.blue;
      case 'leadership':
        return Colors.purple;
      case 'impact':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

class _RubricLevel {
  _RubricLevel({required this.name, required this.criteria, required this.score});

  String name;
  String criteria;
  int score;
}
