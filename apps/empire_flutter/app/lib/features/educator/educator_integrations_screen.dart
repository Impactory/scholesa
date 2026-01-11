import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../auth/app_state.dart';

class EducatorIntegrationsScreen extends StatefulWidget {
  const EducatorIntegrationsScreen({super.key});

  @override
  State<EducatorIntegrationsScreen> createState() => _EducatorIntegrationsScreenState();
}

class _EducatorIntegrationsScreenState extends State<EducatorIntegrationsScreen> {
  late Future<_IntegrationData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_IntegrationData> _load() async {
    final appState = context.read<AppState>();
    final userId = appState.user?.uid;
    final siteId = appState.primarySiteId;
    if (userId == null) return const _IntegrationData();

    final connections = await IntegrationConnectionRepository().listByOwner(userId, limit: 20);
    final githubConnections = await GitHubConnectionRepository().listByOwner(userId, limit: 20);
    final courseLinks = siteId == null || siteId.isEmpty ? <ExternalCourseLinkModel>[] : await ExternalCourseLinkRepository().listBySite(siteId, limit: 20);
    final courseworkLinks = siteId == null || siteId.isEmpty ? <ExternalCourseworkLinkModel>[] : await ExternalCourseworkLinkRepository().listBySite(siteId, limit: 20);
    final cursors = await SyncCursorRepository().listByOwner(userId, limit: 20);
    final jobs = siteId == null || siteId.isEmpty ? await SyncJobRepository().listRecent(limit: 10) : await SyncJobRepository().listBySite(siteId, limit: 10);

    return _IntegrationData(
      connections: connections,
      githubConnections: githubConnections,
      courseLinks: courseLinks,
      courseworkLinks: courseworkLinks,
      cursors: cursors,
      jobs: jobs,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Integrations')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_IntegrationData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data ?? const _IntegrationData();
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section('Google Classroom Connections', data.connections.map(_connectionTile).toList(), emptyText: 'No Classroom connections.'),
                const SizedBox(height: 12),
                _section('GitHub Connections', data.githubConnections.map(_githubConnectionTile).toList(), emptyText: 'No GitHub connections.'),
                const SizedBox(height: 12),
                _section('Course Links', data.courseLinks.map(_courseLinkTile).toList(), emptyText: 'No linked courses.'),
                const SizedBox(height: 12),
                _section('Coursework Links', data.courseworkLinks.map(_courseworkLinkTile).toList(), emptyText: 'No linked coursework.'),
                const SizedBox(height: 12),
                _section('Sync Cursors', data.cursors.map(_cursorTile).toList(), emptyText: 'No cursors stored.'),
                const SizedBox(height: 12),
                _section('Recent Sync Jobs', data.jobs.map(_jobTile).toList(), emptyText: 'No sync jobs.'),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children, {required String emptyText}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (children.isEmpty) Text(emptyText, style: Theme.of(context).textTheme.bodySmall),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _connectionTile(IntegrationConnectionModel c) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.class_rounded),
      title: Text('${c.provider} • ${c.status}'),
      subtitle: Text('Scopes: ${c.scopesGranted?.join(', ') ?? 'n/a'}'),
      trailing: c.lastError != null ? const Icon(Icons.error, color: Colors.red) : null,
    );
  }

  Widget _githubConnectionTile(GitHubConnectionModel c) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.code),
      title: Text('${c.authType} • ${c.status}'),
      subtitle: Text(c.orgLogin != null ? 'Org: ${c.orgLogin}' : 'Personal connection'),
      trailing: c.lastError != null ? const Icon(Icons.error, color: Colors.red) : null,
    );
  }

  Widget _courseLinkTile(ExternalCourseLinkModel link) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.book_outlined),
      title: Text('${link.provider} • Course ${link.providerCourseId}'),
      subtitle: Text('Session: ${link.sessionId} • Sync: ${link.syncPolicy ?? 'manual'}'),
    );
  }

  Widget _courseworkLinkTile(ExternalCourseworkLinkModel link) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.assignment_outlined),
      title: Text('Coursework ${link.providerCourseWorkId}'),
      subtitle: Text('Mission: ${link.missionId} • Published: ${link.publishedAt}'),
    );
  }

  Widget _cursorTile(SyncCursorModel cursor) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.flag_outlined),
      title: Text('${cursor.cursorType} cursor'),
      subtitle: Text('Course ${cursor.providerCourseId} • Next: ${cursor.nextPageToken ?? 'n/a'}'),
    );
  }

  Widget _jobTile(SyncJobModel job) {
    return ListTile(
      dense: true,
      leading: Icon(job.status == 'failed' ? Icons.error : Icons.sync),
      title: Text('${job.type} • ${job.status}'),
      subtitle: Text('Requested by ${job.requestedBy}${job.siteId != null ? ' • Site ${job.siteId}' : ''}'),
      trailing: job.lastError != null ? const Icon(Icons.error, color: Colors.red) : null,
    );
  }
}

class _IntegrationData {
  const _IntegrationData({
    this.connections = const <IntegrationConnectionModel>[],
    this.githubConnections = const <GitHubConnectionModel>[],
    this.courseLinks = const <ExternalCourseLinkModel>[],
    this.courseworkLinks = const <ExternalCourseworkLinkModel>[],
    this.cursors = const <SyncCursorModel>[],
    this.jobs = const <SyncJobModel>[],
  });

  final List<IntegrationConnectionModel> connections;
  final List<GitHubConnectionModel> githubConnections;
  final List<ExternalCourseLinkModel> courseLinks;
  final List<ExternalCourseworkLinkModel> courseworkLinks;
  final List<SyncCursorModel> cursors;
  final List<SyncJobModel> jobs;
}
