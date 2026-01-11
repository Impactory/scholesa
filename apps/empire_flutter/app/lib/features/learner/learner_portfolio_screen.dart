import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../auth/app_state.dart';

class LearnerPortfolioScreen extends StatefulWidget {
  const LearnerPortfolioScreen({super.key});

  @override
  State<LearnerPortfolioScreen> createState() => _LearnerPortfolioScreenState();
}

class _LearnerPortfolioScreenState extends State<LearnerPortfolioScreen> {
  late Future<List<PortfolioItemModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<PortfolioItemModel>> _load() async {
    final learnerId = context.read<AppState>().user?.uid;
    if (learnerId == null) return <PortfolioItemModel>[];
    return PortfolioItemRepository().listByLearner(learnerId);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Portfolio')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<PortfolioItemModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snapshot.data ?? <PortfolioItemModel>[];
            if (items.isEmpty) {
              return const Center(child: Text('No portfolio items yet.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  leading: const Icon(Icons.workspace_premium),
                  title: Text(item.title),
                  subtitle: Text(item.description ?? ''),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
