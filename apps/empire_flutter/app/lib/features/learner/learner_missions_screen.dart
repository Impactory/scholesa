import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../auth/app_state.dart';

class LearnerMissionsScreen extends StatefulWidget {
  const LearnerMissionsScreen({super.key});

  @override
  State<LearnerMissionsScreen> createState() => _LearnerMissionsScreenState();
}

class _LearnerMissionsScreenState extends State<LearnerMissionsScreen> {
  late Future<List<MissionModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<MissionModel>> _load() async {
    final siteId = context.read<AppState>().primarySiteId ?? '';
    if (siteId.isEmpty) return <MissionModel>[];
    final repo = MissionRepository();
    return repo.listBySiteOrGlobal(siteId);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Missions')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<MissionModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final missions = snapshot.data ?? <MissionModel>[];
            if (missions.isEmpty) {
              return const Center(child: Text('No missions available.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: missions.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final mission = missions[index];
                return ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(mission.title),
                  subtitle: Text(mission.description),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
