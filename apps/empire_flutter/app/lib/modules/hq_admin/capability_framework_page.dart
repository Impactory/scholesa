import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/app_state.dart';
import '../../services/firestore_service.dart';

/// HQ admin defines and manages capability frameworks.
/// Lists existing capabilities, provides forms for creating new ones
/// with progression levels, and supports editing and deletion.
class CapabilityFrameworkPage extends StatefulWidget {
  const CapabilityFrameworkPage({super.key});

  @override
  State<CapabilityFrameworkPage> createState() => _CapabilityFrameworkPageState();
}

class _CapabilityFrameworkPageState extends State<CapabilityFrameworkPage> {
  List<Map<String, dynamic>> _capabilities = <Map<String, dynamic>>[];
  bool _isLoading = true;
  String? _error;
  bool _showForm = false;
  String? _editingId;

  // Form state
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedPillar = 'futureSkills';
  List<_ProgressionLevel> _progressionLevels = <_ProgressionLevel>[
    _ProgressionLevel(name: 'Emerging', descriptor: ''),
    _ProgressionLevel(name: 'Developing', descriptor: ''),
    _ProgressionLevel(name: 'Proficient', descriptor: ''),
    _ProgressionLevel(name: 'Advanced', descriptor: ''),
  ];
  bool _isSubmitting = false;

  static const List<Map<String, String>> _pillars = <Map<String, String>>[
    <String, String>{'value': 'futureSkills', 'label': 'Future Skills'},
    <String, String>{'value': 'leadership', 'label': 'Leadership'},
    <String, String>{'value': 'impact', 'label': 'Impact'},
  ];

  FirestoreService get _firestoreService => context.read<FirestoreService>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCapabilities();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadCapabilities() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final List<Map<String, dynamic>> caps =
          await _firestoreService.queryCollection(
        'capabilities',
        orderBy: 'createdAt',
        descending: true,
      );
      setState(() {
        _capabilities = caps;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load capabilities: $e';
        _isLoading = false;
      });
    }
  }

  void _openCreateForm() {
    _nameController.clear();
    _descriptionController.clear();
    _selectedPillar = 'futureSkills';
    _progressionLevels = <_ProgressionLevel>[
      _ProgressionLevel(name: 'Emerging', descriptor: ''),
      _ProgressionLevel(name: 'Developing', descriptor: ''),
      _ProgressionLevel(name: 'Proficient', descriptor: ''),
      _ProgressionLevel(name: 'Advanced', descriptor: ''),
    ];
    _editingId = null;
    setState(() => _showForm = true);
  }

  void _openEditForm(Map<String, dynamic> cap) {
    _nameController.text = cap['name'] as String? ?? '';
    _descriptionController.text = cap['description'] as String? ?? '';
    _selectedPillar = cap['pillarCode'] as String? ?? 'futureSkills';
    final Map<String, dynamic> levels =
        cap['progressionLevels'] as Map<String, dynamic>? ?? <String, dynamic>{};
    _progressionLevels = levels.entries
        .map((MapEntry<String, dynamic> e) =>
            _ProgressionLevel(name: e.key, descriptor: e.value as String? ?? ''))
        .toList();
    if (_progressionLevels.isEmpty) {
      _progressionLevels = <_ProgressionLevel>[
        _ProgressionLevel(name: 'Emerging', descriptor: ''),
        _ProgressionLevel(name: 'Developing', descriptor: ''),
        _ProgressionLevel(name: 'Proficient', descriptor: ''),
        _ProgressionLevel(name: 'Advanced', descriptor: ''),
      ];
    }
    _editingId = cap['id'] as String?;
    setState(() => _showForm = true);
  }

  Future<void> _saveCapability() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capability name is required.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final AppState appState = context.read<AppState>();
      final Map<String, String> levelsMap = <String, String>{};
      for (final _ProgressionLevel level in _progressionLevels) {
        if (level.name.trim().isNotEmpty) {
          levelsMap[level.name.trim()] = level.descriptor.trim();
        }
      }

      final Map<String, dynamic> data = <String, dynamic>{
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'pillarCode': _selectedPillar,
        'progressionLevels': levelsMap,
        'createdBy': appState.userId,
      };

      if (_editingId != null) {
        await _firestoreService.updateDocument('capabilities', _editingId!, data);
      } else {
        await _firestoreService.createDocument('capabilities', data);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_editingId != null ? 'Capability updated.' : 'Capability created.'),
        ),
      );

      setState(() {
        _showForm = false;
        _editingId = null;
      });
      await _loadCapabilities();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving capability: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteCapability(String id) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete Capability'),
        content: const Text('Are you sure you want to delete this capability?'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _firestoreService.deleteDocument('capabilities', id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capability deleted.')),
      );
      await _loadCapabilities();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting capability: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capability Frameworks'),
        actions: <Widget>[
          if (!_showForm)
            IconButton(
              onPressed: _openCreateForm,
              icon: const Icon(Icons.add),
              tooltip: 'Add Capability',
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
                        onPressed: _loadCapabilities,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadCapabilities,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: <Widget>[
                      if (_showForm) _buildForm(),
                      if (!_showForm && _capabilities.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: <Widget>[
                                Icon(Icons.category_outlined,
                                    size: 48, color: theme.colorScheme.primary),
                                const SizedBox(height: 12),
                                Text('No capabilities defined yet.',
                                    style: theme.textTheme.bodyLarge),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: _openCreateForm,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add First Capability'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (!_showForm)
                        ..._capabilities.map(_buildCapabilityCard),
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
              _editingId != null ? 'Edit Capability' : 'Add Capability',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Critical Thinking',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Describe what this capability represents...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedPillar,
              decoration: const InputDecoration(
                labelText: 'Pillar',
                border: OutlineInputBorder(),
              ),
              items: _pillars
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
            Text('Progression Levels', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            ..._progressionLevels.asMap().entries.map(
                  (MapEntry<int, _ProgressionLevel> entry) =>
                      _buildLevelRow(entry.key, entry.value),
                ),
            TextButton.icon(
              onPressed: () => setState(() =>
                  _progressionLevels.add(_ProgressionLevel(name: '', descriptor: ''))),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Level'),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                FilledButton(
                  onPressed: _isSubmitting ? null : _saveCapability,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_editingId != null ? 'Update' : 'Create'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() {
                    _showForm = false;
                    _editingId = null;
                  }),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelRow(int index, _ProgressionLevel level) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 120,
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Level',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: level.name),
              onChanged: (String val) => _progressionLevels[index].name = val,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Descriptor',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: level.descriptor),
              onChanged: (String val) => _progressionLevels[index].descriptor = val,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, size: 20),
            onPressed: _progressionLevels.length > 1
                ? () => setState(() => _progressionLevels.removeAt(index))
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildCapabilityCard(Map<String, dynamic> cap) {
    final ThemeData theme = Theme.of(context);
    final String id = cap['id'] as String? ?? '';
    final String name = cap['name'] as String? ?? 'Untitled';
    final String description = cap['description'] as String? ?? '';
    final String pillar = cap['pillarCode'] as String? ?? '';
    final Map<String, dynamic> levels =
        cap['progressionLevels'] as Map<String, dynamic>? ?? <String, dynamic>{};

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
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _openEditForm(cap),
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _deleteCapability(id),
                  tooltip: 'Delete',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(name, style: theme.textTheme.titleMedium),
            if (description.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(description, style: theme.textTheme.bodyMedium),
            ],
            if (levels.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: levels.keys
                    .map((String k) => Chip(
                          label: Text(k, style: const TextStyle(fontSize: 12)),
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
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

class _ProgressionLevel {
  _ProgressionLevel({required this.name, required this.descriptor});

  String name;
  String descriptor;
}
