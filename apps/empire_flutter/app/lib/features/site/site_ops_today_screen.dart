import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../auth/app_state.dart';

class SiteOpsTodayScreen extends StatefulWidget {
  const SiteOpsTodayScreen({super.key});

  @override
  State<SiteOpsTodayScreen> createState() => _SiteOpsTodayScreenState();
}

class _SiteOpsTodayScreenState extends State<SiteOpsTodayScreen> {
  late Future<List<SessionOccurrenceModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<SessionOccurrenceModel>> _load() async {
    final siteId = context.read<AppState>().primarySiteId ?? '';
    if (siteId.isEmpty) return <SessionOccurrenceModel>[];
    final repo = SessionOccurrenceRepository();
    final all = await repo.listBySite(siteId);
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
      appBar: AppBar(title: const Text('Today Operations')),
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
              return const Center(child: Text('No occurrences scheduled today.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final occ = items[index];
                final time = _formatRange(occ.startAt.toDate(), occ.endAt.toDate());
                return ListTile(
                  leading: const Icon(Icons.schedule),
                  title: Text('Session ${occ.sessionId}'),
                  subtitle: Text('Site ${occ.siteId} • $time'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _formatRange(DateTime start, DateTime end) {
    return '${_hm(start)} – ${_hm(end)}';
  }

  String _hm(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}' ;
}
