import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/app_state.dart';
import '../../domain/models.dart';
import '../../services/firestore_service.dart';

/// Learner Checkpoint Submission Page - Answer checkpoint questions during missions.
class CheckpointSubmissionPage extends StatefulWidget {
  const CheckpointSubmissionPage({super.key});

  @override
  State<CheckpointSubmissionPage> createState() =>
      _CheckpointSubmissionPageState();
}

class _CheckpointSubmissionPageState extends State<CheckpointSubmissionPage> {
  List<CheckpointModel> _checkpoints = const <CheckpointModel>[];
  bool _isLoading = false;
  String? _loadError;

  /// Tracks which checkpoint is showing the explain-it-back follow-up.
  final Set<String> _awaitingExplainItBack = <String>{};

  /// Controllers keyed by checkpoint id for the initial response.
  final Map<String, TextEditingController> _responseControllers =
      <String, TextEditingController>{};

  /// Controllers keyed by checkpoint id for the explain-it-back response.
  final Map<String, TextEditingController> _explainControllers =
      <String, TextEditingController>{};

  /// Tracks which checkpoints are currently being submitted.
  final Set<String> _submitting = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCheckpoints());
  }

  @override
  void dispose() {
    for (final TextEditingController c in _responseControllers.values) {
      c.dispose();
    }
    for (final TextEditingController c in _explainControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _learnerId(AppState appState) =>
      appState.userId?.trim() ?? '';

  String _siteId(AppState appState) {
    final String active = appState.activeSiteId?.trim() ?? '';
    if (active.isNotEmpty) return active;
    if (appState.siteIds.isNotEmpty) return appState.siteIds.first.trim();
    return '';
  }

  FirestoreService? _maybeFirestoreService() {
    try {
      return context.read<FirestoreService>();
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadCheckpoints() async {
    final AppState appState = context.read<AppState>();
    final FirestoreService? service = _maybeFirestoreService();
    final String learnerId = _learnerId(appState);

    if (service == null || learnerId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Checkpoint data unavailable right now.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await service
          .firestore
          .collection('checkpointHistory')
          .where('learnerId', isEqualTo: learnerId)
          .orderBy('createdAt', descending: true)
          .get();

      final List<CheckpointModel> checkpoints = snapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              CheckpointModel.fromDoc(doc))
          .toList();

      if (!mounted) return;
      setState(() {
        _checkpoints = checkpoints;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load checkpoints. Tap to retry.';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitCheckpoint({
    required String question,
    required String learnerResponse,
    required bool explainItBackRequired,
    required String missionId,
    String? skillId,
  }) async {
    final AppState appState = context.read<AppState>();
    final FirestoreService? service = _maybeFirestoreService();
    final String learnerId = _learnerId(appState);
    final String siteId = _siteId(appState);

    if (service == null || learnerId.isEmpty || siteId.isEmpty) {
      _showSnackBar('Unable to submit checkpoint.', isError: true);
      return;
    }

    try {
      await service.submitCheckpointResult(
        learnerId: learnerId,
        missionId: missionId,
        siteId: siteId,
        question: question,
        learnerResponse: learnerResponse,
        isCorrect: false, // Correctness determined server-side or by educator
        explainItBackRequired: explainItBackRequired,
      );
      _showSnackBar('Checkpoint submitted!');
      await _loadCheckpoints();
    } catch (e) {
      _showSnackBar('Failed to submit checkpoint.', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  TextEditingController _responseController(String id) {
    return _responseControllers.putIfAbsent(
        id, () => TextEditingController());
  }

  TextEditingController _explainController(String id) {
    return _explainControllers.putIfAbsent(
        id, () => TextEditingController());
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkpoints'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: InkWell(
                    onTap: _loadCheckpoints,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        _loadError!,
                        style: theme.textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              : _checkpoints.isEmpty
                  ? Center(
                      child: Text(
                        'No checkpoints yet. They will appear when you start a mission.',
                        style: theme.textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadCheckpoints,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _checkpoints.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12.0),
                        itemBuilder: (BuildContext context, int index) {
                          return _buildCheckpointCard(
                              _checkpoints[index], colors, theme);
                        },
                      ),
                    ),
    );
  }

  Widget _buildCheckpointCard(
    CheckpointModel checkpoint,
    ColorScheme colors,
    ThemeData theme,
  ) {
    final bool isCompleted = checkpoint.learnerResponse.trim().isNotEmpty;
    final bool needsExplain = checkpoint.explainItBackRequired &&
        (checkpoint.explainItBackResponse?.trim().isEmpty ?? true);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Status chip
            Row(
              children: <Widget>[
                Icon(
                  isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 20,
                  color: isCompleted
                      ? (checkpoint.isCorrect
                          ? colors.primary
                          : colors.error)
                      : colors.outline,
                ),
                const SizedBox(width: 8.0),
                Text(
                  isCompleted
                      ? (checkpoint.isCorrect ? 'Correct' : 'Submitted')
                      : 'Pending',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isCompleted
                        ? (checkpoint.isCorrect
                            ? colors.primary
                            : colors.onSurfaceVariant)
                        : colors.outline,
                  ),
                ),
                const Spacer(),
                if (checkpoint.createdAt != null)
                  Text(
                    _formatDate(checkpoint.createdAt!),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: colors.outline),
                  ),
              ],
            ),
            const SizedBox(height: 12.0),

            // Question text
            Text(
              checkpoint.question,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12.0),

            // Completed: show response
            if (isCompleted) ...<Widget>[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  checkpoint.learnerResponse,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              if (checkpoint.explainItBackRequired &&
                  checkpoint.explainItBackResponse != null &&
                  checkpoint.explainItBackResponse!.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 8.0),
                Text(
                  'Explain-it-back:',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4.0),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Text(
                    checkpoint.explainItBackResponse!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
              // Show explain-it-back prompt if needed and not yet done
              if (needsExplain) ...<Widget>[
                const SizedBox(height: 12.0),
                Text(
                  'Explain what you learned in your own words:',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 8.0),
                TextField(
                  controller: _explainController(checkpoint.id),
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Explain what you learned...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8.0),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _submitting.contains('explain_${checkpoint.id}')
                        ? null
                        : () => _submitExplainItBack(checkpoint),
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('Submit Explanation'),
                  ),
                ),
              ],
            ],

            // Not completed: show input
            if (!isCompleted) ...<Widget>[
              TextField(
                controller: _responseController(checkpoint.id),
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Type your answer...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8.0),
              if (checkpoint.explainItBackRequired)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.info_outline,
                          size: 16, color: colors.primary),
                      const SizedBox(width: 4.0),
                      Expanded(
                        child: Text(
                          'You will need to explain what you learned after submitting.',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: colors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _submitting.contains(checkpoint.id)
                      ? null
                      : () async {
                          final String response =
                              _responseController(checkpoint.id).text.trim();
                          if (response.isEmpty) {
                            _showSnackBar('Please enter a response.',
                                isError: true);
                            return;
                          }
                          setState(() => _submitting.add(checkpoint.id));
                          await _submitCheckpoint(
                            question: checkpoint.question,
                            learnerResponse: response,
                            explainItBackRequired:
                                checkpoint.explainItBackRequired,
                            missionId: checkpoint.missionId,
                            skillId: checkpoint.skillId,
                          );
                          _responseController(checkpoint.id).clear();
                          if (checkpoint.explainItBackRequired) {
                            setState(() {
                              _awaitingExplainItBack.add(checkpoint.id);
                            });
                          }
                          setState(() => _submitting.remove(checkpoint.id));
                        },
                  child: _submitting.contains(checkpoint.id)
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submitExplainItBack(CheckpointModel checkpoint) async {
    final String explanation =
        _explainController(checkpoint.id).text.trim();
    if (explanation.isEmpty) {
      _showSnackBar('Please write your explanation.', isError: true);
      return;
    }

    final FirestoreService? service = _maybeFirestoreService();
    if (service == null) {
      _showSnackBar('Unable to submit explanation.', isError: true);
      return;
    }

    final String key = 'explain_${checkpoint.id}';
    setState(() => _submitting.add(key));

    try {
      await service.firestore
          .collection('checkpointHistory')
          .doc(checkpoint.id)
          .update(<String, dynamic>{
        'explainItBackResponse': explanation,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _explainController(checkpoint.id).clear();
      _showSnackBar('Explanation submitted!');
      await _loadCheckpoints();
    } catch (e) {
      _showSnackBar('Failed to submit explanation.', isError: true);
    } finally {
      if (mounted) setState(() => _submitting.remove(key));
    }
  }

  String _formatDate(Timestamp timestamp) {
    final DateTime dt = timestamp.toDate();
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
