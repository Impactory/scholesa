import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/app_state.dart';
import '../../domain/models.dart';
import '../../services/firestore_service.dart';

/// Educator applies rubric judgments to learner evidence.
/// Loads submitted mission attempts and allows inline rubric application
/// that triggers the full evidence chain: rubricApplication -> capabilityMastery -> growthEvent.
class RubricApplicationPage extends StatefulWidget {
  const RubricApplicationPage({super.key});

  @override
  State<RubricApplicationPage> createState() => _RubricApplicationPageState();
}

class _RubricApplicationPageState extends State<RubricApplicationPage> {
  List<Map<String, dynamic>> _pendingAttempts = <Map<String, dynamic>>[];
  bool _isLoading = true;
  String? _error;
  String? _expandedAttemptId;

  // Inline rubric form state
  String _selectedLevel = 'emerging';
  final TextEditingController _feedbackController = TextEditingController();
  bool _isSubmitting = false;

  static const List<String> _rubricLevels = <String>[
    'emerging',
    'developing',
    'proficient',
    'advanced',
  ];

  static const Map<String, Color> _levelColors = <String, Color>{
    'emerging': Colors.orange,
    'developing': Colors.blue,
    'proficient': Colors.teal,
    'advanced': Colors.green,
  };

  FirestoreService get _firestoreService => context.read<FirestoreService>();

  String? _activeSiteId() {
    final AppState appState = context.read<AppState>();
    final String activeSiteId = (appState.activeSiteId ?? '').trim();
    if (activeSiteId.isNotEmpty) return activeSiteId;
    if (appState.siteIds.isNotEmpty) {
      final String first = appState.siteIds.first.trim();
      if (first.isNotEmpty) return first;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPendingAttempts();
    });
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _loadPendingAttempts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final String? siteId = _activeSiteId();
      if (siteId == null) {
        setState(() {
          _error = 'No active site selected.';
          _isLoading = false;
        });
        return;
      }
      final List<Map<String, dynamic>> submitted =
          await _firestoreService.queryCollection(
        'missionAttempts',
        where: <List<dynamic>>[
          <dynamic>['siteId', siteId],
          <dynamic>['status', 'submitted'],
        ],
        orderBy: 'createdAt',
        descending: true,
      );
      final List<Map<String, dynamic>> pendingReview =
          await _firestoreService.queryCollection(
        'missionAttempts',
        where: <List<dynamic>>[
          <dynamic>['siteId', siteId],
          <dynamic>['status', 'pending_review'],
        ],
        orderBy: 'createdAt',
        descending: true,
      );
      setState(() {
        _pendingAttempts = <Map<String, dynamic>>[...submitted, ...pendingReview];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load attempts: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _applyRubric(Map<String, dynamic> attempt) async {
    final AppState appState = context.read<AppState>();
    final String educatorId = appState.userId ?? '';
    final String learnerId = attempt['learnerId'] as String? ?? '';
    final String attemptId = attempt['id'] as String? ?? '';
    final String? siteId = _activeSiteId();

    if (educatorId.isEmpty || learnerId.isEmpty || siteId == null) return;

    setState(() => _isSubmitting = true);

    try {
      // 1. Apply rubric judgment
      final String rubricAppId = await _firestoreService.applyRubric(
        learnerId: learnerId,
        capabilityId: attempt['capabilityId'] as String? ?? attemptId,
        educatorId: educatorId,
        level: _selectedLevel,
        feedback: _feedbackController.text.trim().isNotEmpty
            ? _feedbackController.text.trim()
            : null,
        evidenceRefIds: <String>[attemptId],
        siteId: siteId,
      );

      // 2. Update capability mastery
      await _firestoreService.updateCapabilityMastery(
        learnerId: learnerId,
        capabilityId: attempt['capabilityId'] as String? ?? attemptId,
        newLevel: _selectedLevel,
        educatorId: educatorId,
      );

      // 3. Create immutable growth event
      await _firestoreService.createCapabilityGrowthEvent(
        learnerId: learnerId,
        capabilityId: attempt['capabilityId'] as String? ?? attemptId,
        toLevel: _selectedLevel,
        educatorId: educatorId,
        rubricApplicationId: rubricAppId,
        evidenceIds: <String>[attemptId],
        siteId: siteId,
      );

      // 4. Update attempt status
      await _firestoreService.updateDocument(
        'missionAttempts',
        attemptId,
        <String, dynamic>{'status': 'reviewed'},
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rubric applied and growth event recorded.')),
      );

      _feedbackController.clear();
      _selectedLevel = 'emerging';
      _expandedAttemptId = null;
      await _loadPendingAttempts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error applying rubric: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Apply Rubric Judgments'),
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
                        onPressed: _loadPendingAttempts,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _pendingAttempts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.check_circle_outline,
                              size: 48, color: theme.colorScheme.primary),
                          const SizedBox(height: 12),
                          Text('No pending submissions to review.',
                              style: theme.textTheme.bodyLarge),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadPendingAttempts,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _pendingAttempts.length,
                        itemBuilder: (BuildContext context, int index) {
                          return _buildAttemptCard(_pendingAttempts[index]);
                        },
                      ),
                    ),
    );
  }

  Widget _buildAttemptCard(Map<String, dynamic> attempt) {
    final String attemptId = attempt['id'] as String? ?? '';
    final String learnerName =
        attempt['learnerName'] as String? ?? attempt['learnerId'] as String? ?? 'Unknown';
    final String missionTitle =
        attempt['missionTitle'] as String? ?? attempt['missionId'] as String? ?? 'Unknown Mission';
    final String content = attempt['content'] as String? ?? attempt['response'] as String? ?? '';
    final Timestamp? createdAt = attempt['createdAt'] as Timestamp?;
    final bool isExpanded = _expandedAttemptId == attemptId;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.person_outline, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(learnerName, style: Theme.of(context).textTheme.titleMedium),
                ),
                if (createdAt != null)
                  Text(
                    _formatDate(createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(missionTitle, style: Theme.of(context).textTheme.bodyMedium),
            if (content.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  content,
                  maxLines: isExpanded ? null : 3,
                  overflow: isExpanded ? null : TextOverflow.ellipsis,
                ),
              ),
            ],
            const SizedBox(height: 8),
            if (!isExpanded)
              FilledButton.tonal(
                onPressed: () => setState(() => _expandedAttemptId = attemptId),
                child: const Text('Apply Rubric'),
              )
            else
              _buildRubricForm(attempt),
          ],
        ),
      ),
    );
  }

  Widget _buildRubricForm(Map<String, dynamic> attempt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Divider(),
        Text('Select Level', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _rubricLevels.map((String level) {
            final bool selected = _selectedLevel == level;
            return ChoiceChip(
              label: Text(level[0].toUpperCase() + level.substring(1)),
              selected: selected,
              selectedColor: _levelColors[level]?.withValues(alpha: 0.3),
              onSelected: (_) => setState(() => _selectedLevel = level),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _feedbackController,
          decoration: const InputDecoration(
            labelText: 'Feedback (optional)',
            hintText: 'Provide feedback on this submission...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 8),
        Text(
          'Evidence ref: ${attempt['id'] ?? 'N/A'}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            FilledButton(
              onPressed: _isSubmitting ? null : () => _applyRubric(attempt),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit Rubric'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => setState(() => _expandedAttemptId = null),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDate(Timestamp ts) {
    final DateTime dt = ts.toDate();
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
