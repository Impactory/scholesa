import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../auth/app_state.dart';

class ParentSummaryScreen extends StatefulWidget {
  const ParentSummaryScreen({super.key});

  @override
  State<ParentSummaryScreen> createState() => _ParentSummaryScreenState();
}

class _ParentSummaryScreenState extends State<ParentSummaryScreen> {
  late Future<_SummaryData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_SummaryData> _load() async {
    final appState = context.read<AppState>();
    final parentId = appState.user?.uid;
    final siteId = appState.primarySiteId ?? '';
    if (parentId == null || siteId.isEmpty) return const _SummaryData();
    final links = await GuardianLinkRepository().listByParent(parentId);
    final learnerIds = links.map((l) => l.learnerId).toSet().toList();
    if (learnerIds.isEmpty) return const _SummaryData();
    final records = await AttendanceRepository().listRecentByLearners(learnerIds, limit: 50);
    return _SummaryData(links: links, records: records);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Child Summary')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_SummaryData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data ?? const _SummaryData();
            if (data.links.isEmpty) {
              return const Center(child: Text('No linked learners for this parent.'));
            }
            final records = data.records;
            if (records.isEmpty) {
              return const Center(child: Text('No recent attendance records for linked learners.'));
            }
            // Simple parent-safe rollup: count statuses.
            final counts = <String, int>{};
            for (final r in records) {
              final key = r.status.toUpperCase();
              counts[key] = (counts[key] ?? 0) + 1;
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Recent attendance (parent-safe)'),
                const SizedBox(height: 12),
                for (final entry in counts.entries)
                  ListTile(
                    leading: const Icon(Icons.checklist_rtl),
                    title: Text(entry.key),
                    trailing: Text(entry.value.toString()),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryData {
  const _SummaryData({
    this.links = const <GuardianLinkModel>[],
    this.records = const <AttendanceRecordModel>[],
  });

  final List<GuardianLinkModel> links;
  final List<AttendanceRecordModel> records;
}
