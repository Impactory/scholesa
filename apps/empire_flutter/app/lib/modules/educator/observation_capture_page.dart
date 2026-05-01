import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../auth/app_state.dart';
import '../../i18n/evidence_chain_i18n.dart';
import '../../offline/offline_queue.dart';
import '../../offline/sync_coordinator.dart';
import '../../services/firestore_service.dart';

/// Quick evidence capture for educators (10-second rule).
/// Shows learners in the current session and enables fast observation logging
/// with observation type selection. Tracks capture time to encourage speed.
class ObservationCapturePage extends StatefulWidget {
  const ObservationCapturePage({super.key});

  @override
  State<ObservationCapturePage> createState() => _ObservationCapturePageState();
}

class _ObservationCapturePageState extends State<ObservationCapturePage> {
  List<Map<String, dynamic>> _learners = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _recentObservations = <Map<String, dynamic>>[];
  bool _isLoading = true;
  String? _error;

  // Capture form state
  String? _selectedLearnerId;
  String? _selectedLearnerName;
  String _selectedType = 'engagement';
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;

  // Timer for 10-second capture goal
  DateTime? _captureStartTime;

  static const List<Map<String, dynamic>> _observationTypes =
      <Map<String, dynamic>>[
    <String, dynamic>{
      'value': 'engagement',
      'label': 'Engagement',
      'icon': Icons.visibility
    },
    <String, dynamic>{
      'value': 'participation',
      'label': 'Participation',
      'icon': Icons.record_voice_over
    },
    <String, dynamic>{
      'value': 'skill-demonstration',
      'label': 'Skill Demo',
      'icon': Icons.star_outline
    },
    <String, dynamic>{
      'value': 'collaboration',
      'label': 'Collaboration',
      'icon': Icons.group_outlined
    },
  ];

  FirestoreService get _firestoreService => context.read<FirestoreService>();

  String _t(String input) => EvidenceChainI18n.text(context, input);

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
      _loadData();
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
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

      // Capture context-dependent state before any awaits
      final AppState appState = context.read<AppState>();

      // Load learners enrolled at this site
      final List<Map<String, dynamic>> learners =
          await _firestoreService.queryCollection(
        'users',
        where: <List<dynamic>>[
          <dynamic>['role', 'learner'],
          <dynamic>['siteIds', 'arrayContains', siteId],
        ],
        limit: 100,
      );

      // Load recent observations by this educator
      final List<Map<String, dynamic>> recent =
          await _firestoreService.queryCollection(
        'evidenceRecords',
        where: <List<dynamic>>[
          <dynamic>['siteId', siteId],
          <dynamic>['recordedBy', appState.userId],
        ],
        orderBy: 'createdAt',
        descending: true,
        limit: 10,
      );

      setState(() {
        _learners = learners;
        _recentObservations = recent;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }

  void _selectLearner(String learnerId, String learnerName) {
    setState(() {
      _selectedLearnerId = learnerId;
      _selectedLearnerName = learnerName;
      _captureStartTime = DateTime.now();
    });
  }

  Future<void> _submitObservation() async {
    final AppState appState = context.read<AppState>();
    final String educatorId = appState.userId ?? '';
    final String? siteId = _activeSiteId();

    if (_selectedLearnerId == null || educatorId.isEmpty || siteId == null) {
      return;
    }
    if (_noteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Please enter an observation note.'))),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final int captureMs = _captureStartTime != null
          ? DateTime.now().difference(_captureStartTime!).inMilliseconds
          : 0;

      final Map<String, dynamic> payload = <String, dynamic>{
        'learnerId': _selectedLearnerId,
        'learnerName': _selectedLearnerName,
        'educatorId': educatorId,
        'siteId': siteId,
        'recordedBy': educatorId,
        'type': 'observation',
        'observationType': _selectedType,
        'note': _noteController.text.trim(),
        'captureTimeMs': captureMs,
        'rubricStatus': 'pending',
        'growthStatus': 'pending',
        'status': 'recorded',
        'queuedAtClient': DateTime.now().millisecondsSinceEpoch,
      };

      // Route through offline queue so observations survive connectivity loss.
      final SyncCoordinator? syncCoordinator = context.read<SyncCoordinator?>();
      if (syncCoordinator != null) {
        await syncCoordinator.queueOperation(
            OpType.observationCapture, payload);
      } else {
        // Fallback: direct write when sync coordinator is not provided (tests).
        await _firestoreService.createDocument('evidenceRecords', payload);
      }

      if (!mounted) return;

      final int captureSeconds = (captureMs / 1000).round();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            captureSeconds <= 10
                ? '${_t('Observation captured!')} ${captureSeconds}s'
                : '${_t('Observation captured!')} ${captureSeconds}s',
          ),
        ),
      );

      _noteController.clear();
      _selectedLearnerId = null;
      _selectedLearnerName = null;
      _captureStartTime = null;
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_t('Error recording observation:')} $e')),
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
        title: Text(_t('Quick Observation Capture')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.error_outline,
                          size: 48, color: theme.colorScheme.error),
                      const SizedBox(height: 12),
                      Text(_t(_error!), style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh),
                        label: Text(_t('Retry')),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: <Widget>[
                      if (_selectedLearnerId != null) _buildCaptureForm(),
                      if (_selectedLearnerId == null) ...<Widget>[
                        Text(_t('Select a Learner'),
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        if (_learners.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(_t('No learners found for this site.')),
                          )
                        else
                          ..._learners.map(_buildLearnerCard),
                      ],
                      const SizedBox(height: 24),
                      Text(_t('Recent Observations'),
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (_recentObservations.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(_t('No recent observations.')),
                        )
                      else
                        ..._recentObservations.map(_buildRecentCard),
                    ],
                  ),
                ),
    );
  }

  Widget _buildLearnerCard(Map<String, dynamic> learner) {
    final String id = learner['id'] as String? ?? '';
    final String name = learner['displayName'] as String? ??
        learner['email'] as String? ??
        'Unknown';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?')),
        title: Text(name),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _selectLearner(id, name),
      ),
    );
  }

  Widget _buildCaptureForm() {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${_t('Observing:')} $_selectedLearnerName',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (_captureStartTime != null)
                  _CaptureTimer(startTime: _captureStartTime!),
              ],
            ),
            const SizedBox(height: 12),
            Text(_t('Observation Type'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _observationTypes.map((Map<String, dynamic> type) {
                final bool selected = _selectedType == type['value'];
                return ChoiceChip(
                  avatar: Icon(type['icon'] as IconData, size: 18),
                  label: Text(_t(type['label'] as String)),
                  selected: selected,
                  onSelected: (_) =>
                      setState(() => _selectedType = type['value'] as String),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: _t('Observation note'),
                hintText: _t('What did you observe?'),
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submitObservation(),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submitObservation,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(_t('Record')),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() {
                    _selectedLearnerId = null;
                    _selectedLearnerName = null;
                    _captureStartTime = null;
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

  Widget _buildRecentCard(Map<String, dynamic> obs) {
    final String learnerName = obs['learnerName'] as String? ?? 'Unknown';
    final String note = obs['note'] as String? ?? '';
    final String obsType = obs['observationType'] as String? ?? '';
    final Timestamp? createdAt = obs['createdAt'] as Timestamp?;
    final int captureMs = obs['captureTimeMs'] as int? ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.note_outlined),
        title: Text('$learnerName — $obsType'),
        subtitle: Text(note, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            if (createdAt != null)
              Text(
                _formatTime(createdAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (captureMs > 0)
              Text(
                '${(captureMs / 1000).round()}s',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: captureMs <= 10000 ? Colors.green : null,
                    ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(Timestamp ts) {
    final DateTime dt = ts.toDate();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

/// Live timer widget showing elapsed seconds since capture started.
class _CaptureTimer extends StatefulWidget {
  const _CaptureTimer({required this.startTime});

  final DateTime startTime;

  @override
  State<_CaptureTimer> createState() => _CaptureTimerState();
}

class _CaptureTimerState extends State<_CaptureTimer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      final int seconds = DateTime.now().difference(widget.startTime).inSeconds;
      if (seconds != _elapsedSeconds) {
        setState(() => _elapsedSeconds = seconds);
      }
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool underGoal = _elapsedSeconds <= 10;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: underGoal ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${_elapsedSeconds}s',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: underGoal ? Colors.green.shade700 : Colors.orange.shade700,
        ),
      ),
    );
  }
}
