import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../auth/app_state.dart';

class SiteIdentityScreen extends StatefulWidget {
  const SiteIdentityScreen({super.key});

  @override
  State<SiteIdentityScreen> createState() => _SiteIdentityScreenState();
}

class _SiteIdentityScreenState extends State<SiteIdentityScreen> {
  late Future<List<ExternalIdentityLinkModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ExternalIdentityLinkModel>> _load() async {
    final siteId = context.read<AppState>().primarySiteId ?? '';
    if (siteId.isEmpty) return <ExternalIdentityLinkModel>[];
    return ExternalIdentityLinkRepository().listUnmatchedBySite(siteId);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Identity Resolution')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<ExternalIdentityLinkModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final links = snapshot.data ?? <ExternalIdentityLinkModel>[];
            if (links.isEmpty) {
              return const Center(child: Text('No unmatched identities.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: links.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final link = links[index];
                final suggested = link.suggestedMatches?.isNotEmpty == true ? '${link.suggestedMatches!.length} suggestion(s)' : 'No suggestions';
                return ListTile(
                  leading: const Icon(Icons.link),
                  title: Text('${link.provider}: ${link.providerUserId}'),
                  subtitle: Text('Status: ${link.status} • $suggested'),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
