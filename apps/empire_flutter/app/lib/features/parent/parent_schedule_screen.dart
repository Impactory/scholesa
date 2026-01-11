import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../auth/app_state.dart';

class ParentScheduleScreen extends StatefulWidget {
  const ParentScheduleScreen({super.key});

  @override
  State<ParentScheduleScreen> createState() => _ParentScheduleScreenState();
}

class _ParentScheduleScreenState extends State<ParentScheduleScreen> {
  late Future<List<SessionOccurrenceModel>> _future;
  List<GuardianLinkModel> _links = const <GuardianLinkModel>[];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<SessionOccurrenceModel>> _load() async {
    final siteId = context.read<AppState>().primarySiteId ?? '';
    final userId = context.read<AppState>().user?.uid;
    if (siteId.isEmpty || userId == null) return <SessionOccurrenceModel>[];
    final links = await GuardianLinkRepository().listByParent(userId);
    _links = links;
    final learnerIds = links.map((l) => l.learnerId).toSet().toList();
    if (learnerIds.isEmpty) return <SessionOccurrenceModel>[];

    final enrollments = await EnrollmentRepository().listByLearnerIds(siteId: siteId, learnerIds: learnerIds);
    final sessionIds = enrollments.map((e) => e.sessionId).toSet();
    final repo = SessionOccurrenceRepository();
    final all = await repo.listBySite(siteId);
    final filtered = all.where((o) => sessionIds.contains(o.sessionId)).toList();
    final now = DateTime.now();
    return filtered.where((o) => o.startAt.toDate().isAfter(now.subtract(const Duration(days: 1)))).toList()
      ..sort((a, b) => a.startAt.toDate().compareTo(b.startAt.toDate()));
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Schedule')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<SessionOccurrenceModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snapshot.data ?? <SessionOccurrenceModel>[];
            if (_links.isEmpty) {
              return const Center(child: Text('No linked learners for this parent.'));
            }
            if (items.isEmpty) {
              return const Center(child: Text('No upcoming sessions for linked learners.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final occ = items[index];
                final start = occ.startAt.toDate();
                final end = occ.endAt.toDate();
                return ListTile(
                  leading: const Icon(Icons.event),
                  title: Text('Session ${occ.sessionId}'),
                  subtitle: Text('${_md(start)} • ${_hm(start)} – ${_hm(end)}'),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _md(DateTime dt) => '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  String _hm(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
