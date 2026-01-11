import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';

class HqIntegrationsScreen extends StatefulWidget {
  const HqIntegrationsScreen({super.key});

  @override
  State<HqIntegrationsScreen> createState() => _HqIntegrationsScreenState();
}

class _HqIntegrationsScreenState extends State<HqIntegrationsScreen> {
  late Future<List<SyncJobModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = SyncJobRepository().listFailed(limit: 50);
  }

  Future<void> _refresh() async {
    setState(() => _future = SyncJobRepository().listFailed(limit: 50));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Integrations Health')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<SyncJobModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final jobs = snapshot.data ?? <SyncJobModel>[];
            if (jobs.isEmpty) {
              return const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('No failed sync jobs.')));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: jobs.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final job = jobs[index];
                return ListTile(
                  leading: const Icon(Icons.error, color: Colors.red),
                  title: Text('${job.type} • ${job.status}'),
                  subtitle: Text('Site: ${job.siteId ?? 'n/a'} • Requested by: ${job.requestedBy}\n${job.lastError ?? ''}'),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
