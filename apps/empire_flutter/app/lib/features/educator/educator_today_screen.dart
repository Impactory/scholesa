import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../auth/app_state.dart';

class EducatorTodayScreen extends StatefulWidget {
  const EducatorTodayScreen({super.key});

  @override
  State<EducatorTodayScreen> createState() => _EducatorTodayScreenState();
}

class _EducatorTodayScreenState extends State<EducatorTodayScreen> {
  late Future<List<SessionOccurrenceModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<SessionOccurrenceModel>> _load() async {
    final appState = context.read<AppState>();
    final siteId = appState.primarySiteId ?? '';
    if (siteId.isEmpty) return <SessionOccurrenceModel>[];
    final repo = SessionOccurrenceRepository();
    final all = await repo.listBySite(siteId);
    // Filter to today
    final now = DateTime.now();
    return all.where((o) {
      final start = o.startAt.toDate();
      return start.year == now.year && start.month == now.month && start.day == now.day;
    }).toList()
      ..sort((a, b) => a.startAt.toDate().compareTo(b.startAt.toDate()));
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Today's Classes")),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<SessionOccurrenceModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snapshot.data ?? <SessionOccurrenceModel>[];
            if (items.isEmpty) {
              return const Center(child: Text('No classes scheduled today for this site.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final occ = items[index];
                final start = occ.startAt.toDate();
                final end = occ.endAt.toDate();
                final time = _formatRange(start, end);
                return ListTile(
                  leading: const Icon(Icons.class_outlined),
                  title: Text('Session ${occ.sessionId}'),
                  subtitle: Text('Site ${occ.siteId} • $time'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Open roster/plan not yet wired.')),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _formatRange(DateTime start, DateTime? end) {
    final endStr = end != null ? _hm(end) : '';
    return '${_hm(start)}${endStr.isNotEmpty ? ' – $endStr' : ''}';
  }

  String _hm(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}' ;
}
