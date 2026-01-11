import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../auth/app_state.dart';

class SiteIntegrationsScreen extends StatefulWidget {
  const SiteIntegrationsScreen({super.key});

  @override
  State<SiteIntegrationsScreen> createState() => _SiteIntegrationsScreenState();
}

class _SiteIntegrationsScreenState extends State<SiteIntegrationsScreen> {
  late Future<_SiteIntegrationData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_SiteIntegrationData> _load() async {
    final siteId = context.read<AppState>().primarySiteId ?? '';
    if (siteId.isEmpty) return const _SiteIntegrationData();

    final courseLinks = await ExternalCourseLinkRepository().listBySite(siteId, limit: 50);
    final userLinks = await ExternalUserLinkRepository().listBySite(siteId, limit: 50);
    final courseworkLinks = await ExternalCourseworkLinkRepository().listBySite(siteId, limit: 50);
    final repoLinks = await ExternalRepoLinkRepository().listBySite(siteId, limit: 50);
    final jobs = await SyncJobRepository().listBySite(siteId, limit: 25);
    return _SiteIntegrationData(
      courseLinks: courseLinks,
      userLinks: userLinks,
      courseworkLinks: courseworkLinks,
      repoLinks: repoLinks,
      jobs: jobs,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Integrations Health')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_SiteIntegrationData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data ?? const _SiteIntegrationData();
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section('Classroom Course Links', data.courseLinks.map(_courseLinkTile).toList(), 'No linked courses.'),
                const SizedBox(height: 12),
                _section('Classroom User Links', data.userLinks.map(_userLinkTile).toList(), 'No linked users.'),
                const SizedBox(height: 12),
                _section('Published Coursework', data.courseworkLinks.map(_courseworkTile).toList(), 'No coursework published.'),
                const SizedBox(height: 12),
                _section('GitHub Repositories', data.repoLinks.map(_repoLinkTile).toList(), 'No repos linked.'),
                const SizedBox(height: 12),
                _section('Recent Sync Jobs', data.jobs.map(_jobTile).toList(), 'No sync jobs yet.'),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> tiles, String emptyText) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (tiles.isEmpty) Text(emptyText, style: Theme.of(context).textTheme.bodySmall),
            ...tiles,
          ],
        ),
      ),
    );
  }

  Widget _courseLinkTile(ExternalCourseLinkModel link) {
    final rosterAt = link.lastRosterSyncAt != null ? link.lastRosterSyncAt!.toDate().toIso8601String() : '-';
    final courseworkAt = link.lastCourseworkSyncAt != null ? link.lastCourseworkSyncAt!.toDate().toIso8601String() : '-';
    return ListTile(
      dense: true,
      leading: const Icon(Icons.book_outlined),
      title: Text('${link.provider} • Course ${link.providerCourseId}'),
      subtitle: Text('Session ${link.sessionId} • Roster $rosterAt • Coursework $courseworkAt'),
    );
  }

  Widget _userLinkTile(ExternalUserLinkModel link) {
    final target = link.scholesaUserId.isEmpty ? 'unmatched' : link.scholesaUserId;
    return ListTile(
      dense: true,
      leading: const Icon(Icons.person_outline),
      title: Text('${link.providerUserId} → $target'),
      subtitle: Text('Role: ${link.roleHint ?? '-'} • Source: ${link.matchSource ?? '-'}'),
    );
  }

  Widget _courseworkTile(ExternalCourseworkLinkModel link) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.assignment_outlined),
      title: Text('Coursework ${link.providerCourseWorkId}'),
      subtitle: Text('Mission ${link.missionId} • Published: ${link.publishedAt}'),
    );
  }

  Widget _repoLinkTile(ExternalRepoLinkModel link) {
    final repoStatus = link.status == null ? 'active' : link.status!;
    return ListTile(
      dense: true,
      leading: const Icon(Icons.code),
      title: Text(link.repoFullName),
      subtitle: Text('Status: $repoStatus'),
    );
  }

  Widget _jobTile(SyncJobModel job) {
    final siteSuffix = job.siteId == null ? '' : ' • Site ${job.siteId}';
    return ListTile(
      dense: true,
      leading: Icon(job.status == 'failed' ? Icons.error : Icons.sync),
      title: Text('${job.type} • ${job.status}'),
      subtitle: Text('Requested by ${job.requestedBy}$siteSuffix'),
      trailing: job.lastError != null ? const Icon(Icons.error, color: Colors.red) : null,
    );
  }
}

class _SiteIntegrationData {
  const _SiteIntegrationData({
    this.courseLinks = const <ExternalCourseLinkModel>[],
    this.userLinks = const <ExternalUserLinkModel>[],
    this.courseworkLinks = const <ExternalCourseworkLinkModel>[],
    this.repoLinks = const <ExternalRepoLinkModel>[],
    this.jobs = const <SyncJobModel>[],
  });

  final List<ExternalCourseLinkModel> courseLinks;
  final List<ExternalUserLinkModel> userLinks;
  final List<ExternalCourseworkLinkModel> courseworkLinks;
  final List<ExternalRepoLinkModel> repoLinks;
  final List<SyncJobModel> jobs;
}
