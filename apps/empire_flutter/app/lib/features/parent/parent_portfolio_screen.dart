import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../auth/app_state.dart';

class ParentPortfolioScreen extends StatefulWidget {
  const ParentPortfolioScreen({super.key});

  @override
  State<ParentPortfolioScreen> createState() => _ParentPortfolioScreenState();
}

class _ParentPortfolioScreenState extends State<ParentPortfolioScreen> {
  late Future<List<PortfolioItemModel>> _future;
  List<GuardianLinkModel> _links = const <GuardianLinkModel>[];
  Map<String, LearnerProfileModel> _profiles = const <String, LearnerProfileModel>{};
  String? _selectedLearnerId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<void> _loadContext() async {
    final appState = context.read<AppState>();
    final parentId = appState.user?.uid;
    if (parentId == null) return;
    final links = await GuardianLinkRepository().listByParent(parentId);
    final siteId = appState.primarySiteId;
    Map<String, LearnerProfileModel> profiles = const <String, LearnerProfileModel>{};
    if (siteId != null && siteId.isNotEmpty) {
      final siteProfiles = await LearnerProfileRepository().listBySite(siteId);
      profiles = {for (final p in siteProfiles) p.learnerId: p};
    }
    _links = links;
    _profiles = profiles;
    _selectedLearnerId ??= links.isNotEmpty ? links.first.learnerId : null;
  }

  Future<List<PortfolioItemModel>> _load() async {
    await _loadContext();
    final learnerId = _selectedLearnerId;
    if (learnerId == null || learnerId.isEmpty) return <PortfolioItemModel>[];
    return PortfolioItemRepository().listByLearner(learnerId);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Portfolio Highlights')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<PortfolioItemModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snapshot.data ?? <PortfolioItemModel>[];
            if (_links.isEmpty) {
              return const Center(child: Text('No linked learners found for this parent.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length + 1,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return ListTile(
                    title: const Text('Learner'),
                    subtitle: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedLearnerId,
                      items: _links
                          .map(
                            (l) => DropdownMenuItem<String>(
                              value: l.learnerId,
                              child: Text(_learnerLabel(l.learnerId)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedLearnerId = value;
                          _future = _load();
                        });
                      },
                    ),
                  );
                }
                final item = items[index - 1];
                return ListTile(
                  leading: const Icon(Icons.photo_album),
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

  String _learnerLabel(String learnerId) {
    final profile = _profiles[learnerId];
    return profile?.preferredName ?? profile?.legalName ?? learnerId;
  }
}
