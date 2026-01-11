import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../auth/app_state.dart';

class SiteIncidentsScreen extends StatefulWidget {
  const SiteIncidentsScreen({super.key});

  @override
  State<SiteIncidentsScreen> createState() => _SiteIncidentsScreenState();
}

class _SiteIncidentsScreenState extends State<SiteIncidentsScreen> {
  late Future<List<IncidentReportModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<IncidentReportModel>> _load() async {
    final siteId = context.read<AppState>().primarySiteId ?? '';
    if (siteId.isEmpty) return <IncidentReportModel>[];
    return IncidentReportRepository().listRecentBySite(siteId);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safety & Incidents')),
      floatingActionButton: FloatingActionButton(
        onPressed: _createIncident,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<IncidentReportModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final incidents = snapshot.data ?? <IncidentReportModel>[];
            if (incidents.isEmpty) {
              return const Center(child: Text('No incidents reported.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: incidents.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final inc = incidents[index];
                return ListTile(
                  leading: Icon(_iconForSeverity(inc.severity), color: _colorForSeverity(inc.severity)),
                  title: Text(inc.summary),
                  subtitle: Text('Severity: ${inc.severity} • Status: ${inc.status}'),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _createIncident() async {
    final appState = context.read<AppState>();
    final siteId = appState.primarySiteId;
    final reporterId = appState.user?.uid;
    if (siteId == null || siteId.isEmpty || reporterId == null) return;

    String severity = 'minor';
    String category = 'other';
    final summaryController = TextEditingController();
    final detailsController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('New incident'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownMenu<String>(
                    initialSelection: severity,
                    label: const Text('Severity'),
                    dropdownMenuEntries: const ['minor', 'major', 'critical']
                        .map((s) => DropdownMenuEntry<String>(value: s, label: s))
                        .toList(),
                    onSelected: (value) => setStateDialog(() => severity = value ?? 'minor'),
                  ),
                  DropdownMenu<String>(
                    initialSelection: category,
                    label: const Text('Category'),
                    dropdownMenuEntries: const ['injury', 'behavior', 'bullying', 'facility', 'late_pickup', 'other']
                        .map((c) => DropdownMenuEntry<String>(value: c, label: c))
                        .toList(),
                    onSelected: (value) => setStateDialog(() => category = value ?? 'other'),
                  ),
                  TextField(
                    controller: summaryController,
                    decoration: const InputDecoration(labelText: 'Summary'),
                  ),
                  TextField(
                    controller: detailsController,
                    decoration: const InputDecoration(labelText: 'Details (optional)'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  if (summaryController.text.trim().isEmpty) return;
                  Navigator.pop(context, true);
                },
                child: const Text('Submit'),
              ),
            ],
          );
        });
      },
    );

    if (result != true) return;
    await IncidentReportRepository().create(
      siteId: siteId,
      reportedBy: reporterId,
      severity: severity,
      category: category,
      summary: summaryController.text.trim(),
      details: detailsController.text.trim().isEmpty ? null : detailsController.text.trim(),
      status: 'submitted',
    );
    await _refresh();
  }

  IconData _iconForSeverity(String severity) {
    switch (severity) {
      case 'critical':
        return Icons.error;
      case 'major':
        return Icons.report_problem;
      default:
        return Icons.info;
    }
  }

  Color _colorForSeverity(String severity) {
    switch (severity) {
      case 'critical':
        return Colors.red;
      case 'major':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }
}
