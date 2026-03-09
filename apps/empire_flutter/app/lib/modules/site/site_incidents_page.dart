import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../auth/app_state.dart';
import '../../i18n/site_surface_i18n.dart';
import '../../services/firestore_service.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';

String _tSiteIncidents(BuildContext context, String input) {
  return SiteSurfaceI18n.text(context, input);
}

/// Site incidents management page
/// Based on docs/41_SAFETY_CONSENT_INCIDENTS_SPEC.md
class SiteIncidentsPage extends StatefulWidget {
  const SiteIncidentsPage({super.key});

  @override
  State<SiteIncidentsPage> createState() => _SiteIncidentsPageState();
}

enum _Severity { minor, major, critical }

enum _Status { submitted, reviewed, closed }

class _Incident {
  const _Incident({
    required this.id,
    required this.title,
    required this.severity,
    required this.status,
    required this.reportedBy,
    required this.reportedAt,
    required this.learnerName,
  });

  final String id;
  final String title;
  final _Severity severity;
  final _Status status;
  final String reportedBy;
  final DateTime reportedAt;
  final String learnerName;
}

class _SiteIncidentsPageState extends State<SiteIncidentsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<_Incident> _incidents = <_Incident>[];
  bool _isLoading = false;
  String? _siteId;

  String _statusLabel(_Status status) {
    switch (status) {
      case _Status.submitted:
        return _tSiteIncidents(context, 'Open');
      case _Status.reviewed:
        return _tSiteIncidents(context, 'Reviewed');
      case _Status.closed:
        return _tSiteIncidents(context, 'Closed');
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadIncidents();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: Text(_tSiteIncidents(context, 'Safety & Incidents')),
        backgroundColor: ScholesaColors.safetyGradient.colors.first,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          onTap: (int index) {
            final List<String> tabs = <String>['open', 'reviewed', 'closed'];
            TelemetryService.instance.logEvent(
              event: 'cta.clicked',
              metadata: <String, dynamic>{
                'module': 'site_incidents',
                'cta_id': 'switch_tab',
                'surface': 'incidents_tab_bar',
                'tab': tabs[index],
              },
            );
          },
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: <Widget>[
            Tab(text: _tSiteIncidents(context, 'Open')),
            Tab(text: _tSiteIncidents(context, 'Reviewed')),
            Tab(text: _tSiteIncidents(context, 'Closed')),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          TelemetryService.instance.logEvent(
            event: 'cta.clicked',
            metadata: <String, dynamic>{
              'module': 'site_incidents',
              'cta_id': 'open_create_incident_dialog',
              'surface': 'floating_action_button',
            },
          );
          _showCreateIncidentDialog();
        },
        backgroundColor: ScholesaColors.safetyGradient.colors.first,
        icon: const Icon(Icons.add_rounded),
        label: Text(_tSiteIncidents(context, 'Report Incident')),
      ),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          _buildIncidentList(_Status.submitted),
          _buildIncidentList(_Status.reviewed),
          _buildIncidentList(_Status.closed),
        ],
      ),
    );
  }

  Widget _buildIncidentList(_Status statusFilter) {
    if (_isLoading) {
      return Center(
        child: Text(
          _tSiteIncidents(context, 'Loading...'),
          style: const TextStyle(color: ScholesaColors.textSecondary),
        ),
      );
    }

    final List<_Incident> filtered =
        _incidents.where((_Incident i) => i.status == statusFilter).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.check_circle_rounded,
              size: 64,
              color: Colors.green.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              '${_tSiteIncidents(context, 'No incidents')} ${_tSiteIncidents(context, statusFilter.name)}',
              style: const TextStyle(
                fontSize: 16,
                color: ScholesaColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (BuildContext context, int index) {
        return _buildIncidentCard(filtered[index]);
      },
    );
  }

  Widget _buildIncidentCard(_Incident incident) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          TelemetryService.instance.logEvent(
            event: 'cta.clicked',
            metadata: <String, dynamic>{
              'module': 'site_incidents',
              'cta_id': 'tap_incident_card',
              'surface': 'incident_list',
              'incident_id': incident.id,
            },
          );
          _showIncidentDetails(incident);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _buildSeverityBadge(incident.severity),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      incident.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: ScholesaColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  const Icon(Icons.person_rounded,
                      size: 16, color: ScholesaColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    incident.learnerName,
                    style: const TextStyle(
                      fontSize: 13,
                      color: ScholesaColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.schedule_rounded,
                      size: 16, color: ScholesaColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateTime(incident.reportedAt),
                    style: const TextStyle(
                      fontSize: 13,
                      color: ScholesaColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${_tSiteIncidents(context, 'Reported by')} ${incident.reportedBy}',
                style: const TextStyle(
                  fontSize: 12,
                  color: ScholesaColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeverityBadge(_Severity severity) {
    Color color;
    String label;
    switch (severity) {
      case _Severity.minor:
        color = Colors.orange;
        label = _tSiteIncidents(context, 'Minor');
      case _Severity.major:
        color = Colors.deepOrange;
        label = _tSiteIncidents(context, 'Major');
      case _Severity.critical:
        color = Colors.red;
        label = _tSiteIncidents(context, 'Critical');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  void _showIncidentDetails(_Incident incident) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'site_incidents',
        'cta_id': 'open_incident_details',
        'surface': 'incident_card',
        'incident_id': incident.id,
        'status': incident.status.name,
      },
    );
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ScholesaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _buildSeverityBadge(incident.severity),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    incident.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(_tSiteIncidents(context, 'Learner'), incident.learnerName),
            _buildInfoRow(_tSiteIncidents(context, 'Reported By'), incident.reportedBy),
            _buildInfoRow(_tSiteIncidents(context, 'Date'), _formatDateTime(incident.reportedAt)),
            _buildInfoRow(_tSiteIncidents(context, 'Status'), _statusLabel(incident.status).toUpperCase()),
            const SizedBox(height: 24),
            if (incident.status != _Status.closed)
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        TelemetryService.instance.logEvent(
                          event: 'cta.clicked',
                          metadata: <String, dynamic>{
                            'module': 'site_incidents',
                            'cta_id': 'close_incident_details',
                            'surface': 'incident_details_sheet',
                            'incident_id': incident.id,
                          },
                        );
                        Navigator.pop(context);
                      },
                      child: Text(_tSiteIncidents(context, 'Close')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        TelemetryService.instance.logEvent(
                          event: 'cta.clicked',
                          metadata: <String, dynamic>{
                            'module': 'site_incidents',
                            'cta_id': incident.status == _Status.submitted
                                ? 'review_incident'
                                : 'close_incident',
                            'surface': 'incident_details_sheet',
                            'incident_id': incident.id,
                          },
                        );
                        Navigator.pop(context);
                        await _advanceIncidentStatus(incident);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            ScholesaColors.safetyGradient.colors.first,
                      ),
                      child: Text(incident.status == _Status.submitted
                          ? _tSiteIncidents(context, 'Review')
                          : _tSiteIncidents(context, 'Close Incident')),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: <String, dynamic>{
                        'module': 'site_incidents',
                        'cta_id': 'close_closed_incident_details',
                        'surface': 'incident_details_sheet',
                        'incident_id': incident.id,
                      },
                    );
                    Navigator.pop(context);
                  },
                  child: Text(_tSiteIncidents(context, 'Close')),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(color: ScholesaColors.textSecondary),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  void _showCreateIncidentDialog() {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController learnerController = TextEditingController();
    _Severity selectedSeverity = _Severity.minor;

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context,
            void Function(void Function()) setLocalState) {
          return AlertDialog(
            backgroundColor: ScholesaColors.surface,
            title: Text(_tSiteIncidents(context, 'Report New Incident')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: _tSiteIncidents(context, 'Incident Title'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: learnerController,
                  decoration: InputDecoration(
                    labelText:
                        _tSiteIncidents(context, 'Learner Name (optional)'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<_Severity>(
                  initialValue: selectedSeverity,
                  decoration: InputDecoration(
                    labelText: _tSiteIncidents(context, 'Severity'),
                    border: const OutlineInputBorder(),
                  ),
                  items: _Severity.values
                      .map((_Severity s) => DropdownMenuItem<_Severity>(
                            value: s,
                            child: Text(_tSiteIncidents(context,
                                s.name[0].toUpperCase() + s.name.substring(1))),
                          ))
                      .toList(),
                  onChanged: (_Severity? value) {
                    if (value != null) {
                      setLocalState(() => selectedSeverity = value);
                    }
                  },
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  TelemetryService.instance.logEvent(
                    event: 'cta.clicked',
                    metadata: <String, dynamic>{
                      'module': 'site_incidents',
                      'cta_id': 'cancel_incident_report',
                      'surface': 'create_incident_dialog',
                    },
                  );
                  Navigator.pop(dialogContext);
                },
                child: Text(_tSiteIncidents(context, 'Cancel')),
              ),
              ElevatedButton(
                onPressed: () async {
                  final String title = titleController.text.trim();
                  if (title.isEmpty) {
                    Navigator.pop(dialogContext);
                    return;
                  }
                  TelemetryService.instance.logEvent(
                    event: 'cta.clicked',
                    metadata: <String, dynamic>{
                      'module': 'site_incidents',
                      'cta_id': 'submit_incident_report',
                      'surface': 'create_incident_dialog',
                    },
                  );
                  Navigator.pop(dialogContext);
                  await _createIncident(
                    title: title,
                    severity: selectedSeverity,
                    learnerName: learnerController.text.trim(),
                  );
                },
                child: Text(_tSiteIncidents(context, 'Submit')),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _loadIncidents() async {
    final AppState appState = context.read<AppState>();
    final FirestoreService firestoreService = context.read<FirestoreService>();
    final String resolvedSiteId = (appState.activeSiteId ??
            (appState.siteIds.isNotEmpty ? appState.siteIds.first : ''))
        .trim();
    _siteId = resolvedSiteId;

    setState(() => _isLoading = true);
    try {
      Query<Map<String, dynamic>> query =
          firestoreService.firestore.collection('incidents');
      if (resolvedSiteId.isNotEmpty) {
        query = query.where('siteId', isEqualTo: resolvedSiteId);
      }

      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await query.orderBy('reportedAt', descending: true).get();
      } catch (_) {
        snapshot = await query.get();
      }

      final List<_Incident> loaded = snapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
            final Map<String, dynamic> data = doc.data();
            final _Severity severity = _parseSeverity(
              (data['severity'] as String?) ?? (data['type'] as String?),
            );
            final _Status status = _parseStatus(data['status'] as String?);
            final String learnerName =
                (data['learnerName'] as String?)?.trim().isNotEmpty == true
                    ? (data['learnerName'] as String).trim()
                    : _tSiteIncidents(context, 'Unknown');

            return _Incident(
              id: doc.id,
              title: (data['title'] as String?)?.trim().isNotEmpty == true
                  ? (data['title'] as String).trim()
                  : (data['description'] as String? ?? 'Incident'),
              severity: severity,
              status: status,
              reportedBy: (data['reportedByName'] as String?) ??
                  (data['reportedBy'] as String?) ??
                  _tSiteIncidents(context, 'Unknown'),
              reportedAt: _parseDateTime(data['reportedAt']) ??
                  _parseDateTime(data['createdAt']) ??
                  DateTime.now(),
              learnerName: learnerName,
            );
          })
          .toList();

      loaded.sort(
          (_Incident a, _Incident b) => b.reportedAt.compareTo(a.reportedAt));
      if (!mounted) return;
      setState(() => _incidents = loaded);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createIncident({
    required String title,
    required _Severity severity,
    required String learnerName,
  }) async {
    final FirestoreService firestoreService = context.read<FirestoreService>();
    final User? user = FirebaseAuth.instance.currentUser;
    final String siteId = _siteId ?? '';

    await firestoreService.firestore.collection('incidents').add(<String, dynamic>{
      if (siteId.isNotEmpty) 'siteId': siteId,
      'title': title,
      'description': title,
      'severity': severity.name,
      'type': severity.name,
      'status': 'submitted',
      'learnerName': learnerName,
      'reportedBy': user?.uid,
      'reportedByName':
          (user?.displayName?.trim().isNotEmpty ?? false) ? user!.displayName : 'Staff',
      'reportedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_tSiteIncidents(context, 'Incident reported'))),
    );
    await _loadIncidents();
  }

  Future<void> _advanceIncidentStatus(_Incident incident) async {
    final FirestoreService firestoreService = context.read<FirestoreService>();
    final _Status nextStatus = incident.status == _Status.submitted
        ? _Status.reviewed
        : _Status.closed;

    await firestoreService.firestore
        .collection('incidents')
        .doc(incident.id)
        .set(<String, dynamic>{
      'status': nextStatus.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_tSiteIncidents(context, 'Incident updated'))),
    );
    await _loadIncidents();
  }

  _Severity _parseSeverity(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'critical':
        return _Severity.critical;
      case 'major':
      case 'high':
        return _Severity.major;
      default:
        return _Severity.minor;
    }
  }

  _Status _parseStatus(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'closed':
        return _Status.closed;
      case 'reviewed':
      case 'in_review':
        return _Status.reviewed;
      default:
        return _Status.submitted;
    }
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
