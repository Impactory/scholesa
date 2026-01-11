import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../auth/app_state.dart';

class EducatorReviewQueueScreen extends StatefulWidget {
  const EducatorReviewQueueScreen({super.key});

  @override
  State<EducatorReviewQueueScreen> createState() => _EducatorReviewQueueScreenState();
}

class _EducatorReviewQueueScreenState extends State<EducatorReviewQueueScreen> {
  late Future<List<RubricModel>> _futureRubrics;
  RubricModel? _selectedRubric;
  final Map<String, int> _scores = <String, int>{};
  final TextEditingController _attemptController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  List<MissionAttemptModel> _attempts = <MissionAttemptModel>[];
  List<RubricApplicationModel> _applications = <RubricApplicationModel>[];

  @override
  void initState() {
    super.initState();
    _futureRubrics = _loadRubrics();
  }

  Future<List<RubricModel>> _loadRubrics() async {
    final appState = context.read<AppState>();
    final siteId = appState.primarySiteId;
    final rubrics = await RubricRepository().listBySiteOrGlobal(siteId, limit: 25);
    if (rubrics.isNotEmpty) {
      _setSelectedRubric(rubrics.first);
    }
    return rubrics;
  }

  void _setSelectedRubric(RubricModel rubric) {
    _selectedRubric = rubric;
    _scores
      ..clear()
      ..addEntries(rubric.criteria.map((c) => MapEntry<String, int>(c['title']?.toString() ?? '', 0)));
    setState(() {});
  }

  Future<void> _loadApplications() async {
    final attemptId = _attemptController.text.trim();
    if (attemptId.isEmpty) return;
    final apps = await RubricApplicationRepository().listByAttempt(attemptId, limit: 20);
    setState(() => _applications = apps);
  }

  Future<void> _loadAttempts() async {
    final siteId = context.read<AppState>().primarySiteId;
    if (siteId == null || siteId.isEmpty) return;
    final attempts = await MissionAttemptRepository().listBySite(siteId, limit: 50);
    setState(() => _attempts = attempts);
  }

  Future<void> _applyRubric() async {
    final appState = context.read<AppState>();
    final siteId = appState.primarySiteId;
    final educatorId = appState.user?.uid;
    final attemptId = _attemptController.text.trim();
    final rubric = _selectedRubric;
    if (siteId == null || siteId.isEmpty || educatorId == null || attemptId.isEmpty || rubric == null) return;

    final scores = rubric.criteria.map((c) {
      final title = c['title']?.toString() ?? '';
      final level = _scores[title] ?? 0;
      return <String, dynamic>{'criterionTitle': title, 'level': level, 'note': null};
    }).toList();

    final id = 'ra_${DateTime.now().millisecondsSinceEpoch}';
    final app = RubricApplicationModel(
      id: id,
      siteId: siteId,
      missionAttemptId: attemptId,
      educatorId: educatorId,
      rubricId: rubric.id,
      scores: scores,
      overallNote: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      createdAt: null,
      updatedAt: null,
    );
    await RubricApplicationRepository().upsert(app);
    await _loadApplications();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rubric applied.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review Queue')),
      body: FutureBuilder<List<RubricModel>>(
        future: _futureRubrics,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final rubrics = snapshot.data ?? <RubricModel>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Select rubric', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedRubric?.id,
                        items: rubrics
                            .map((r) => DropdownMenuItem<String>(value: r.id, child: Text(r.title)))
                            .toList(),
                        onChanged: (value) {
                          final rubric = rubrics.firstWhere((r) => r.id == value);
                          _setSelectedRubric(rubric);
                        },
                        decoration: const InputDecoration(labelText: 'Rubric'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _attemptController,
                        decoration: const InputDecoration(labelText: 'Mission Attempt ID'),
                        onTap: () async {
                          await _loadAttempts();
                          if (!context.mounted) return;
                          if (_attempts.isEmpty) return;
                          final selected = await showModalBottomSheet<MissionAttemptModel>(
                            context: context,
                            builder: (context) {
                              return ListView(
                                children: _attempts
                                    .map((a) => ListTile(
                                          title: Text('Attempt ${a.id}'),
                                          subtitle: Text('Mission ${a.missionId} • Learner ${a.learnerId} • ${a.status}'),
                                          onTap: () => Navigator.pop(context, a),
                                        ))
                                    .toList(),
                              );
                            },
                          );
                          if (!context.mounted) return;
                          if (selected != null) {
                            _attemptController.text = selected.id;
                            await _loadApplications();
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _noteController,
                        decoration: const InputDecoration(labelText: 'Overall note (optional)'),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      if (_selectedRubric != null) _buildCriteria(_selectedRubric!),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          ElevatedButton(onPressed: _applyRubric, child: const Text('Apply rubric')),
                          const SizedBox(width: 12),
                          TextButton(onPressed: _loadApplications, child: const Text('Load attempt history')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Previous applications', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (_applications.isEmpty)
                        Text('None loaded.', style: Theme.of(context).textTheme.bodySmall)
                      else
                        ..._applications.map((a) => ListTile(
                              leading: const Icon(Icons.assignment_turned_in),
                              title: Text('Rubric ${a.rubricId} • ${a.scores.length} criteria'),
                              subtitle: Text('Educator ${a.educatorId} • ${a.overallNote ?? 'No note'}'),
                            )),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCriteria(RubricModel rubric) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rubric.criteria.map((c) {
        final title = c['title']?.toString() ?? '';
        final current = _scores[title] ?? 0;
        return Row(
          children: [
            Expanded(child: Text(title)),
            DropdownButton<int>(
              value: current,
              items: List<int>.generate(5, (i) => i)
                  .map((v) => DropdownMenuItem<int>(value: v, child: Text('L$v')))
                  .toList(),
              onChanged: (value) => setState(() => _scores[title] = value ?? 0),
            ),
          ],
        );
      }).toList(),
    );
  }
}
