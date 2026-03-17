import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../auth/app_state.dart';
import '../../domain/models.dart';
import '../../i18n/site_surface_i18n.dart';
import '../../services/firestore_service.dart';
import '../../services/telemetry_service.dart';
import '../../services/workflow_bridge_service.dart';
import '../../ui/theme/scholesa_theme.dart';

String _tSiteOps(BuildContext context, String input) {
  return SiteSurfaceI18n.text(context, input);
}

/// Site operations page for daily operations overview
/// Based on docs/42_PHYSICAL_SITE_CHECKIN_CHECKOUT_SPEC.md
class SiteOpsPage extends StatefulWidget {
  const SiteOpsPage({super.key, this.workflowBridge});

  final WorkflowBridgeService? workflowBridge;

  @override
  State<SiteOpsPage> createState() => _SiteOpsPageState();
}

class _SiteOpsPageState extends State<SiteOpsPage> {
  bool _isDayOpen = false;
  int _presentCount = 0;
  int _pendingPickups = 0;
  int _openIncidents = 0;
  bool _isLoading = false;
  String? _siteId;
  List<_ActivityEntry> _recentActivity = <_ActivityEntry>[];
  List<_TimetableEntry> _todaySessions = <_TimetableEntry>[];
  List<_KitChecklistItem> _kitChecklist = _defaultKitChecklist;
  List<_SafetyNoteEntry> _safetyNotes = <_SafetyNoteEntry>[];
  FederatedLearningResolvedRuntimePackageModel? _runtimePackage;
  List<FederatedLearningRuntimeDeliveryRecordModel> _runtimeDeliveries =
      <FederatedLearningRuntimeDeliveryRecordModel>[];
  List<FederatedLearningRuntimeActivationRecordModel> _runtimeActivations =
      <FederatedLearningRuntimeActivationRecordModel>[];
  bool _isLoadingRuntimeRollout = false;
  String? _runtimeRolloutError;
  final TextEditingController _safetyNoteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOpsData();
    });
  }

  @override
  void dispose() {
    _safetyNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: Text(_tSiteOps(context, 'Today Operations')),
        backgroundColor: ScholesaColors.siteGradient.colors.first,
        foregroundColor: Colors.white,
        actions: <Widget>[
          Switch(
            value: _isDayOpen,
            onChanged: (bool value) {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'module': 'site_ops',
                  'cta_id': 'toggle_day_open',
                  'surface': 'appbar_switch',
                  'is_day_open': value,
                },
              );
              setState(() => _isDayOpen = value);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(value
                      ? _tSiteOps(context, 'Day opened')
                      : _tSiteOps(context, 'Day closed')),
                  backgroundColor: value ? Colors.green : Colors.orange,
                ),
              );
            },
            activeThumbColor: Colors.white,
            activeTrackColor: Colors.green.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildStatusBanner(),
            const SizedBox(height: 24),
            _buildQuickStats(),
            const SizedBox(height: 24),
            _buildRuntimeRolloutCard(),
            const SizedBox(height: 24),
            _buildTimetableSnapshot(),
            const SizedBox(height: 24),
            _buildKitChecklist(),
            const SizedBox(height: 24),
            _buildSafetyNotes(),
            const SizedBox(height: 24),
            _buildQuickActions(),
            const SizedBox(height: 24),
            _buildRecentActivity(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimetableSnapshot() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _tSiteOps(context, 'Today Timetable'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: ScholesaColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: ScholesaColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: _todaySessions.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    _tSiteOps(context, 'No sessions scheduled today'),
                    style: const TextStyle(color: ScholesaColors.textSecondary),
                  ),
                )
              : Column(
                  children: _todaySessions
                      .map((_TimetableEntry session) => ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: ScholesaColors.siteGradient.colors.first
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.schedule_rounded,
                                color: ScholesaColors.primary,
                              ),
                            ),
                            title: Text(session.title),
                            subtitle: Text(
                              '${session.timeLabel} • ${session.educator} • ${session.room}',
                            ),
                            trailing: Text(
                              '${session.learnerCount} ${_tSiteOps(context, 'learners')}',
                              style: const TextStyle(
                                color: ScholesaColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ))
                      .toList(growable: false),
                ),
        ),
      ],
    );
  }

  Widget _buildKitChecklist() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _tSiteOps(context, 'Kit Checklist'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: ScholesaColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: ScholesaColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: _kitChecklist
                .map((_KitChecklistItem item) => CheckboxListTile(
                      value: item.completed,
                      title: Text(_tSiteOps(context, item.label)),
                      subtitle: item.note == null || item.note!.isEmpty
                          ? null
                          : Text(_tSiteOps(context, item.note!)),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (bool? value) {
                        _toggleChecklistItem(item, value ?? false);
                      },
                    ))
                .toList(growable: false),
          ),
        ),
      ],
    );
  }

  Widget _buildSafetyNotes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _tSiteOps(context, 'Safety Notes'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: ScholesaColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: ScholesaColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  controller: _safetyNoteController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: _tSiteOps(context, 'Capture handoff changes, medical context, or room risks'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _saveSafetyNote,
                    icon: const Icon(Icons.note_add_rounded),
                    label: Text(_tSiteOps(context, 'Save Safety Note')),
                  ),
                ),
                const SizedBox(height: 16),
                if (_safetyNotes.isEmpty)
                  Text(
                    _tSiteOps(context, 'No safety notes logged today'),
                    style: const TextStyle(color: ScholesaColors.textSecondary),
                  )
                else
                  ..._safetyNotes.map(
                    (_SafetyNoteEntry note) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.shield_outlined,
                        color: ScholesaColors.primary,
                      ),
                      title: Text(note.note),
                      subtitle: Text(
                        '${note.authorLabel} • ${_formatTime(note.createdAt)}',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: _isDayOpen
            ? const LinearGradient(
                colors: <Color>[Color(0xFF22C55E), Color(0xFF4ADE80)])
            : const LinearGradient(
                colors: <Color>[Color(0xFFF59E0B), Color(0xFFFBBF24)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: (_isDayOpen ? Colors.green : Colors.orange)
                .withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isDayOpen
                  ? Icons.door_front_door_rounded
                  : Icons.door_sliding_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _isDayOpen
                      ? _tSiteOps(context, 'Site is OPEN')
                      : _tSiteOps(context, 'Site is CLOSED'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isDayOpen
                      ? _tSiteOps(context, 'Check-ins and operations active')
                      : _tSiteOps(context, 'Toggle switch to open the day'),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: <Widget>[
        Expanded(
          child: _buildStatCard(_tSiteOps(context, 'Present'), _presentCount.toString(),
                Icons.people_rounded, Colors.green)),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(_tSiteOps(context, 'Pickups'), _pendingPickups.toString(),
                Icons.directions_walk_rounded, Colors.blue)),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(_tSiteOps(context, 'Incidents'), _openIncidents.toString(),
                Icons.warning_rounded, Colors.orange)),
      ],
    );
  }

  Widget _buildRuntimeRolloutCard() {
    final _SiteRuntimeRolloutSummary summary = _siteRuntimeRolloutSummary();
    final FederatedLearningResolvedRuntimePackageModel? runtimePackage =
        _runtimePackage;
    final FederatedLearningRuntimeActivationRecordModel? latestActivation =
        _latestRuntimeActivation();
    final bool hasRolloutData = runtimePackage != null ||
        _runtimeDeliveries.isNotEmpty ||
        _runtimeActivations.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _tSiteOps(context, 'Federated Runtime'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: ScholesaColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: ScholesaColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _isLoadingRuntimeRollout
                ? Text(
                    _tSiteOps(context, 'Loading...'),
                    style: const TextStyle(
                      color: ScholesaColors.textSecondary,
                    ),
                  )
                : _runtimeRolloutError != null && !hasRolloutData
                    ? Text(
                        _tSiteOps(
                          context,
                          'Runtime rollout details are unavailable right now',
                        ),
                        style: const TextStyle(
                          color: ScholesaColors.textSecondary,
                        ),
                      )
                    : !hasRolloutData
                        ? Text(
                            _tSiteOps(
                              context,
                              'No bounded runtime package assigned',
                            ),
                            style: const TextStyle(
                              color: ScholesaColors.textSecondary,
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                _tSiteOps(
                                  context,
                                  'Active bounded runtime package and rollout status for this site',
                                ),
                                style: const TextStyle(
                                  color: ScholesaColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (runtimePackage != null) ...<Widget>[
                                Text(
                                  '${_tSiteOps(context, 'Current package')}: ${runtimePackage.packageId} · ${_runtimeStatusLabel(runtimePackage.resolutionStatus)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_tSiteOps(context, 'Runtime target')}: ${runtimePackage.runtimeTarget} · ${_tSiteOps(context, 'Model version')}: ${runtimePackage.modelVersion}',
                                  style: const TextStyle(
                                    color: ScholesaColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_tSiteOps(context, 'Vector length')}: ${runtimePackage.runtimeVectorLength} · ${_tSiteOps(context, 'Manifest digest')}: ${runtimePackage.manifestDigest}',
                                  style: const TextStyle(
                                    color: ScholesaColors.textSecondary,
                                  ),
                                ),
                                if (_runtimePackageReason(runtimePackage)
                                    .isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_tSiteOps(context, 'Runtime status')}: ${_runtimePackageReason(runtimePackage)}',
                                    style: const TextStyle(
                                      color: ScholesaColors.textSecondary,
                                    ),
                                  ),
                                ],
                                if (runtimePackage.rolloutControlMode != null &&
                                    runtimePackage.rolloutControlMode!
                                        .trim()
                                        .isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_tSiteOps(context, 'HQ control')}: ${_runtimeStatusLabel(runtimePackage.rolloutControlMode!)}',
                                    style: const TextStyle(
                                      color: ScholesaColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                              if (runtimePackage != null)
                                const SizedBox(height: 12)
                              else
                                const SizedBox(height: 4),
                              Text(
                                '${_tSiteOps(context, 'Site rollout')}: ${summary.resolvedCount} ${_tSiteOps(context, 'resolved')} · ${summary.stagedCount} ${_tSiteOps(context, 'staged')} · ${summary.fallbackCount} ${_tSiteOps(context, 'fallback')} · ${summary.pendingCount} ${_tSiteOps(context, 'pending')}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_tSiteOps(context, 'Active manifests')}: ${_runtimeDeliveries.length} · ${_tSiteOps(context, 'Activation reports')}: ${_runtimeActivations.length}',
                                style: const TextStyle(
                                  color: ScholesaColors.textSecondary,
                                ),
                              ),
                              if (latestActivation != null) ...<Widget>[
                                const SizedBox(height: 4),
                                Text(
                                  '${_tSiteOps(context, 'Latest site report')}: ${_runtimeStatusLabel(latestActivation.status)}${_latestActivationNotes(latestActivation)}',
                                  style: const TextStyle(
                                    color: ScholesaColors.textSecondary,
                                  ),
                                ),
                              ],
                              if (_runtimeRolloutError != null) ...<Widget>[
                                const SizedBox(height: 8),
                                Text(
                                  _tSiteOps(
                                    context,
                                    'Runtime rollout details are partially unavailable right now',
                                  ),
                                  style: const TextStyle(
                                    color: ScholesaColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ScholesaColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: ScholesaColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _tSiteOps(context, 'Quick Actions'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: ScholesaColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.5,
          children: <Widget>[
            _buildActionButton(
              'Check-in', Icons.login_rounded, '/site/checkin'),
            _buildActionButton(
              'Check-out', Icons.logout_rounded, '/site/checkin'),
            _buildActionButton(
              'New Incident', Icons.add_alert_rounded, '/site/incidents'),
            _buildActionButton(
              'View Roster', Icons.list_alt_rounded, '/site/sessions'),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, String route) {
    return Material(
      color: ScholesaColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          TelemetryService.instance.logEvent(
            event: 'cta.clicked',
            metadata: <String, dynamic>{
              'module': 'site_ops',
              'cta_id': 'quick_action',
              'surface': 'quick_actions',
              'label': label,
              'route': route,
            },
          );
          _handleQuickAction(label);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: <Widget>[
              Icon(icon, color: ScholesaColors.primary, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _tSiteOps(context, label),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _tSiteOps(context, 'Recent Activity'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: ScholesaColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: ScholesaColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: _isLoading
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      _tSiteOps(context, 'Loading...'),
                      style:
                          const TextStyle(color: ScholesaColors.textSecondary),
                    ),
                  ),
                )
              : _recentActivity.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Text(
                          _tSiteOps(context, 'No recent activity yet'),
                          style: const TextStyle(
                              color: ScholesaColors.textSecondary),
                        ),
                      ),
                    )
                  : Column(
                      children: <Widget>[
                        ..._buildRecentActivityRows(),
                      ],
                    ),
        ),
      ],
    );
  }

  List<Widget> _buildRecentActivityRows() {
    final List<Widget> rows = <Widget>[];
    for (var index = 0; index < _recentActivity.length; index++) {
      final _ActivityEntry entry = _recentActivity[index];
      rows.add(
          _buildActivityItem(entry.title, entry.time, entry.icon, entry.color));
      if (index < _recentActivity.length - 1) {
        rows.add(const Divider(height: 1));
      }
    }
    return rows;
  }

  Future<void> _handleQuickAction(String label) async {
    if (label == 'New Incident') {
      if (!mounted) return;
      Navigator.of(context).pushNamed('/site/incidents');
      return;
    }

    try {
      final FirestoreService firestoreService = context.read<FirestoreService>();
      final String siteId = _siteId ?? '';
      if (siteId.isNotEmpty) {
        await firestoreService.firestore.collection('siteOpsEvents').add(
          <String, dynamic>{
            'siteId': siteId,
            'action': label,
            'createdBy': FirebaseAuth.instance.currentUser?.uid,
            'createdAt': FieldValue.serverTimestamp(),
          },
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label ${_tSiteOps(context, 'completed')}')),
      );
      await _loadOpsData();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tSiteOps(context, 'Action failed'))),
      );
    }
  }

  Future<void> _loadOpsData() async {
    final AppState appState = context.read<AppState>();
    final FirestoreService firestoreService = context.read<FirestoreService>();
    final String resolvedSiteId = (appState.activeSiteId ??
            (appState.siteIds.isNotEmpty ? appState.siteIds.first : ''))
        .trim();
    _siteId = resolvedSiteId;

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      if (resolvedSiteId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _presentCount = 0;
          _pendingPickups = 0;
          _openIncidents = 0;
          _isDayOpen = false;
          _recentActivity = <_ActivityEntry>[];
          _todaySessions = <_TimetableEntry>[];
          _kitChecklist = _defaultKitChecklist;
          _safetyNotes = <_SafetyNoteEntry>[];
          _runtimePackage = null;
          _runtimeDeliveries = <FederatedLearningRuntimeDeliveryRecordModel>[];
          _runtimeActivations =
              <FederatedLearningRuntimeActivationRecordModel>[];
          _runtimeRolloutError = null;
        });
        return;
      }

      final DateTime now = DateTime.now();
      final DateTime dayStart = DateTime(now.year, now.month, now.day);
      final DateTime nextDay = dayStart.add(const Duration(days: 1));
      final List<_TimedActivity> activities = <_TimedActivity>[];
      final List<_TimetableEntry> timetable = <_TimetableEntry>[];
      final _SiteRuntimeRolloutState runtimeRolloutState =
          await _loadRuntimeRolloutState(resolvedSiteId);

      final QuerySnapshot<Map<String, dynamic>> presenceSnap =
          await firestoreService.firestore
              .collection('checkins')
              .where('siteId', isEqualTo: resolvedSiteId)
              .limit(250)
              .get();
        if (!mounted) return;

      final Set<String> presentLearners = <String>{};
      int pickupSignals = 0;
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in presenceSnap.docs) {
        final Map<String, dynamic> data = doc.data();
        final DateTime? eventAt = _toDateTime(data['timestamp']);
        if (eventAt == null || eventAt.isBefore(dayStart)) continue;

        final String learnerId = (data['learnerId'] as String?) ?? '';
        final String type =
            ((data['type'] as String?) ?? '').trim().toLowerCase();
        if (type == 'checkin' && learnerId.isNotEmpty) {
          presentLearners.add(learnerId);
          activities.add(
            _TimedActivity(
              title: _tSiteOps(context, 'Manual check-in recorded'),
              at: eventAt,
              icon: Icons.login_rounded,
              color: Colors.green,
            ),
          );
        } else if (type == 'checkout' && learnerId.isNotEmpty) {
          presentLearners.remove(learnerId);
          pickupSignals += 1;
          activities.add(
            _TimedActivity(
              title: _tSiteOps(context, 'Manual check-out recorded'),
              at: eventAt,
              icon: Icons.logout_rounded,
              color: Colors.blue,
            ),
          );
        }
      }

      QuerySnapshot<Map<String, dynamic>> incidentsSnap;
      try {
        incidentsSnap = await firestoreService.firestore
            .collection('incidents')
            .where('siteId', isEqualTo: resolvedSiteId)
            .orderBy('reportedAt', descending: true)
            .limit(100)
            .get();
      } catch (_) {
        incidentsSnap = await firestoreService.firestore
            .collection('incidents')
            .where('siteId', isEqualTo: resolvedSiteId)
            .limit(100)
            .get();
      }
      if (!mounted) return;

      int openIncidents = 0;
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in incidentsSnap.docs) {
        final Map<String, dynamic> data = doc.data();
        final String status =
            ((data['status'] as String?) ?? '').trim().toLowerCase();
        if (status != 'closed') {
          openIncidents += 1;
        }
        final DateTime? incidentAt =
            _toDateTime(data['reportedAt']) ?? _toDateTime(data['createdAt']);
        if (incidentAt == null || incidentAt.isBefore(dayStart)) continue;

        activities.add(
          _TimedActivity(
            title: _tSiteOps(context, 'New incident created'),
            at: incidentAt,
            icon: Icons.warning_rounded,
            color: Colors.orange,
          ),
        );
      }

      QuerySnapshot<Map<String, dynamic>> opsEventSnap;
      try {
        opsEventSnap = await firestoreService.firestore
            .collection('siteOpsEvents')
            .where('siteId', isEqualTo: resolvedSiteId)
            .orderBy('createdAt', descending: true)
            .limit(100)
            .get();
      } catch (_) {
        opsEventSnap = await firestoreService.firestore
            .collection('siteOpsEvents')
            .where('siteId', isEqualTo: resolvedSiteId)
            .limit(100)
            .get();
      }
      if (!mounted) return;

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in opsEventSnap.docs) {
        final Map<String, dynamic> data = doc.data();
        final DateTime? at = _toDateTime(data['createdAt']);
        if (at == null || at.isBefore(dayStart)) continue;
        final String action = (data['action'] as String?) ?? '';
        final ({String title, IconData icon, Color color}) mapped =
          _mapActionToDisplay(action, context);
        activities.add(
          _TimedActivity(
            title: mapped.title,
            at: at,
            icon: mapped.icon,
            color: mapped.color,
          ),
        );
      }

      QuerySnapshot<Map<String, dynamic>> sessionsSnap;
      try {
        sessionsSnap = await firestoreService.firestore
            .collection('sessions')
            .where('siteId', isEqualTo: resolvedSiteId)
            .orderBy('startTime')
            .limit(50)
            .get();
      } catch (_) {
        sessionsSnap = await firestoreService.firestore
            .collection('sessions')
            .where('siteId', isEqualTo: resolvedSiteId)
            .limit(50)
            .get();
      }
      if (!mounted) return;

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in sessionsSnap.docs) {
        final Map<String, dynamic> data = doc.data();
        final DateTime? startAt = _toDateTime(data['startTime']);
        if (startAt == null || startAt.isBefore(dayStart) || !startAt.isBefore(nextDay)) {
          continue;
        }
        timetable.add(
          _TimetableEntry(
            title: ((data['title'] as String?) ?? '').trim().isNotEmpty
                ? (data['title'] as String).trim()
                : doc.id,
            timeLabel: _formatTime(startAt),
            educator: ((data['educatorName'] as String?) ?? '').trim().isNotEmpty
                ? (data['educatorName'] as String).trim()
                : _tSiteOps(context, 'Unassigned'),
            room: ((data['room'] as String?) ?? '').trim().isNotEmpty
                ? (data['room'] as String).trim()
                : _tSiteOps(context, 'Unassigned'),
            learnerCount: (data['learnerCount'] as num?)?.toInt() ?? 0,
          ),
        );
      }

      QuerySnapshot<Map<String, dynamic>> checklistSnap;
      try {
        checklistSnap = await firestoreService.firestore
            .collection('siteOpsKitChecklist')
            .where('siteId', isEqualTo: resolvedSiteId)
            .where('dayKey', isEqualTo: _dayKey(dayStart))
            .orderBy('order')
            .limit(20)
            .get();
      } catch (_) {
        checklistSnap = await firestoreService.firestore
            .collection('siteOpsKitChecklist')
            .where('siteId', isEqualTo: resolvedSiteId)
            .where('dayKey', isEqualTo: _dayKey(dayStart))
            .limit(20)
            .get();
      }
      if (!mounted) return;

      final List<_KitChecklistItem> checklist = checklistSnap.docs.isEmpty
          ? _defaultKitChecklist
          : checklistSnap.docs
              .map((doc) {
                final Map<String, dynamic> data = doc.data();
                return _KitChecklistItem(
                  id: doc.id,
                  label: (data['label'] as String?) ?? 'Checklist item',
                  completed: data['completed'] == true,
                  order: (data['order'] as num?)?.toInt() ?? 0,
                  note: data['note'] as String?,
                );
              })
              .toList(growable: false);

      QuerySnapshot<Map<String, dynamic>> safetyNotesSnap;
      try {
        safetyNotesSnap = await firestoreService.firestore
            .collection('siteSafetyNotes')
            .where('siteId', isEqualTo: resolvedSiteId)
            .where('dayKey', isEqualTo: _dayKey(dayStart))
            .orderBy('createdAt', descending: true)
            .limit(10)
            .get();
      } catch (_) {
        safetyNotesSnap = await firestoreService.firestore
            .collection('siteSafetyNotes')
            .where('siteId', isEqualTo: resolvedSiteId)
            .where('dayKey', isEqualTo: _dayKey(dayStart))
            .limit(10)
            .get();
      }
      if (!mounted) return;

      final List<_SafetyNoteEntry> safetyNotes = safetyNotesSnap.docs
          .map((doc) {
            final Map<String, dynamic> data = doc.data();
            return _SafetyNoteEntry(
              note: (data['note'] as String?) ?? '',
              createdAt: _toDateTime(data['createdAt']) ?? dayStart,
              authorLabel: ((data['createdByName'] as String?) ?? '').trim().isNotEmpty
                  ? (data['createdByName'] as String).trim()
                  : _tSiteOps(context, 'Site Team'),
            );
          })
          .where((_SafetyNoteEntry note) => note.note.trim().isNotEmpty)
          .toList(growable: false);

      activities.sort((_TimedActivity a, _TimedActivity b) => b.at.compareTo(a.at));
      final List<_ActivityEntry> recent = activities
          .take(8)
          .map(
            (_TimedActivity item) => _ActivityEntry(
              item.title,
              _formatTime(item.at),
              item.icon,
              item.color,
            ),
          )
          .toList();

      if (!mounted) return;
      setState(() {
        _presentCount = presentLearners.length;
        _pendingPickups = pickupSignals;
        _openIncidents = openIncidents;
        _isDayOpen = _presentCount > 0;
        _recentActivity = recent;
        _todaySessions = timetable;
        _kitChecklist = checklist;
        _safetyNotes = safetyNotes;
        _runtimePackage = runtimeRolloutState.package;
        _runtimeDeliveries = runtimeRolloutState.deliveries;
        _runtimeActivations = runtimeRolloutState.activations;
        _runtimeRolloutError = runtimeRolloutState.error;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<_SiteRuntimeRolloutState> _loadRuntimeRolloutState(
    String siteId,
  ) async {
    final WorkflowBridgeService workflowBridge =
        widget.workflowBridge ?? WorkflowBridgeService.instance;
    if (mounted) {
      setState(() => _isLoadingRuntimeRollout = true);
    }
    try {
      final List<dynamic> payload = await Future.wait<dynamic>(<Future<dynamic>>[
        workflowBridge.listSiteFederatedLearningRuntimeDeliveryRecords(
          siteId: siteId,
          limit: 12,
        ),
        workflowBridge.listSiteFederatedLearningRuntimeActivationRecords(
          siteId: siteId,
          limit: 12,
        ),
        workflowBridge.resolveSiteFederatedLearningRuntimePackage(siteId: siteId),
      ]);

      final List<FederatedLearningRuntimeDeliveryRecordModel> deliveries =
          (payload[0] as List<dynamic>)
              .whereType<Map<String, dynamic>>()
              .map(
                (Map<String, dynamic> row) =>
                    FederatedLearningRuntimeDeliveryRecordModel.fromMap(
                  row['id'] as String? ?? '',
                  row,
                ),
              )
              .toList(growable: false);
      final List<FederatedLearningRuntimeActivationRecordModel> activations =
          (payload[1] as List<dynamic>)
              .whereType<Map<String, dynamic>>()
              .map(
                (Map<String, dynamic> row) =>
                    FederatedLearningRuntimeActivationRecordModel.fromMap(
                  row['id'] as String? ?? '',
                  row,
                ),
              )
              .toList(growable: false);
      final Map<String, dynamic>? packageRow = payload[2] as Map<String, dynamic>?;
      final FederatedLearningResolvedRuntimePackageModel? package =
          packageRow == null
              ? null
              : FederatedLearningResolvedRuntimePackageModel.fromMap(packageRow);
      return _SiteRuntimeRolloutState(
        package: package,
        deliveries: deliveries,
        activations: activations,
      );
    } catch (error) {
      return _SiteRuntimeRolloutState(
        deliveries: const <FederatedLearningRuntimeDeliveryRecordModel>[],
        activations: const <FederatedLearningRuntimeActivationRecordModel>[],
        error: error.toString(),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingRuntimeRollout = false);
      }
    }
  }

  _SiteRuntimeRolloutSummary _siteRuntimeRolloutSummary() {
    int resolvedCount = 0;
    int stagedCount = 0;
    int fallbackCount = 0;
    final Map<String, FederatedLearningRuntimeActivationRecordModel>
        latestByDeliveryId = <String, FederatedLearningRuntimeActivationRecordModel>{};

    for (final FederatedLearningRuntimeActivationRecordModel activation
        in _runtimeActivations) {
      final FederatedLearningRuntimeActivationRecordModel? current =
          latestByDeliveryId[activation.deliveryRecordId];
      if (current == null ||
          _runtimeActivationTimestamp(activation) >
              _runtimeActivationTimestamp(current)) {
        latestByDeliveryId[activation.deliveryRecordId] = activation;
      }
    }

    for (final FederatedLearningRuntimeActivationRecordModel activation
        in latestByDeliveryId.values) {
      switch (activation.status.trim()) {
        case 'resolved':
          resolvedCount += 1;
          break;
        case 'staged':
          stagedCount += 1;
          break;
        case 'fallback':
          fallbackCount += 1;
          break;
      }
    }

    final int pendingCount = _runtimeDeliveries
        .where(
          (FederatedLearningRuntimeDeliveryRecordModel delivery) =>
              !latestByDeliveryId.containsKey(delivery.id),
        )
        .length;

    return _SiteRuntimeRolloutSummary(
      resolvedCount: resolvedCount,
      stagedCount: stagedCount,
      fallbackCount: fallbackCount,
      pendingCount: pendingCount,
    );
  }

  FederatedLearningRuntimeActivationRecordModel? _latestRuntimeActivation() {
    if (_runtimeActivations.isEmpty) {
      return null;
    }
    final List<FederatedLearningRuntimeActivationRecordModel> sorted =
        List<FederatedLearningRuntimeActivationRecordModel>.from(
      _runtimeActivations,
    )..sort(
            (FederatedLearningRuntimeActivationRecordModel a,
                    FederatedLearningRuntimeActivationRecordModel b) =>
                _runtimeActivationTimestamp(b)
                    .compareTo(_runtimeActivationTimestamp(a)),
          );
    return sorted.first;
  }

  int _runtimeActivationTimestamp(
    FederatedLearningRuntimeActivationRecordModel activation,
  ) {
    return activation.updatedAt?.millisecondsSinceEpoch ??
        activation.reportedAt?.millisecondsSinceEpoch ??
        activation.createdAt?.millisecondsSinceEpoch ??
        0;
  }

  String _runtimeStatusLabel(String value) {
    switch (value.trim()) {
      case 'resolved':
      case 'staged':
      case 'fallback':
      case 'pending':
      case 'assigned':
      case 'active':
      case 'revoked':
      case 'superseded':
      case 'expired':
      case 'restricted':
      case 'paused':
      case 'monitor':
        return _tSiteOps(context, value.trim());
      default:
        return value.trim();
    }
  }

  String _runtimePackageReason(
    FederatedLearningResolvedRuntimePackageModel package,
  ) {
    switch (package.resolutionStatus.trim()) {
      case 'paused':
      case 'restricted':
        return package.rolloutControlReason?.trim() ?? '';
      case 'revoked':
        return package.revocationReason?.trim() ?? '';
      case 'superseded':
        return package.supersessionReason?.trim() ?? '';
      default:
        return '';
    }
  }

  String _latestActivationNotes(
    FederatedLearningRuntimeActivationRecordModel activation,
  ) {
    final String notes = (activation.notes ?? '').trim();
    if (notes.isEmpty) {
      return '';
    }
    return ' · $notes';
  }

  Future<void> _toggleChecklistItem(
    _KitChecklistItem item,
    bool completed,
  ) async {
    final FirestoreService firestoreService = context.read<FirestoreService>();
    final AppState appState = context.read<AppState>();
    final String siteId = (_siteId ?? '').trim();
    if (siteId.isEmpty) return;
    final DateTime now = DateTime.now();
    final _KitChecklistItem updated = item.copyWith(completed: completed);
    setState(() {
      _kitChecklist = _kitChecklist
          .map((_KitChecklistItem current) => current.id == item.id ? updated : current)
          .toList(growable: false);
    });
    try {
      await firestoreService.firestore
          .collection('siteOpsKitChecklist')
          .doc(updated.id)
          .set(<String, dynamic>{
        'siteId': siteId,
        'dayKey': _dayKey(now),
        'label': updated.label,
        'completed': completed,
        'order': updated.order,
        if ((updated.note ?? '').trim().isNotEmpty) 'note': updated.note,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': appState.userId,
      }, SetOptions(merge: true));
      await firestoreService.firestore.collection('siteOpsEvents').add(
        <String, dynamic>{
          'siteId': siteId,
          'action': 'Kit checklist updated',
          'createdBy': FirebaseAuth.instance.currentUser?.uid,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
      TelemetryService.instance.logEvent(
        event: 'cta.clicked',
        metadata: <String, dynamic>{
          'module': 'site_ops',
          'cta_id': 'toggle_kit_checklist_item',
          'surface': 'kit_checklist',
          'label': updated.label,
          'completed': completed,
        },
      );
      await _loadOpsData();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tSiteOps(context, 'Action failed'))),
      );
    }
  }

  Future<void> _saveSafetyNote() async {
    final String note = _safetyNoteController.text.trim();
    if (note.isEmpty) {
      return;
    }
    final FirestoreService firestoreService = context.read<FirestoreService>();
    final AppState appState = context.read<AppState>();
    final String siteId = (_siteId ?? '').trim();
    if (siteId.isEmpty) {
      return;
    }

    try {
      await firestoreService.firestore.collection('siteSafetyNotes').add(
        <String, dynamic>{
          'siteId': siteId,
          'dayKey': _dayKey(DateTime.now()),
          'note': note,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': appState.userId,
          'createdByName': appState.displayName,
        },
      );
      await firestoreService.firestore.collection('siteOpsEvents').add(
        <String, dynamic>{
          'siteId': siteId,
          'action': 'Safety note saved',
          'createdBy': FirebaseAuth.instance.currentUser?.uid,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
      TelemetryService.instance.logEvent(
        event: 'cta.clicked',
        metadata: <String, dynamic>{
          'module': 'site_ops',
          'cta_id': 'save_safety_note',
          'surface': 'safety_notes',
        },
      );
      _safetyNoteController.clear();
      await _loadOpsData();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tSiteOps(context, 'Action failed'))),
      );
    }
  }

  String _dayKey(DateTime dateTime) {
    final String month = dateTime.month.toString().padLeft(2, '0');
    final String day = dateTime.day.toString().padLeft(2, '0');
    return '${dateTime.year}-$month-$day';
  }

  String _formatTime(DateTime dateTime) {
    final int hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final String minute = dateTime.minute.toString().padLeft(2, '0');
    final String period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  ({String title, IconData icon, Color color}) _mapActionToDisplay(
      String action, BuildContext context) {
    switch (action) {
      case 'Check-in':
        return (
          title: _tSiteOps(context, 'Manual check-in recorded'),
          icon: Icons.login_rounded,
          color: Colors.green,
        );
      case 'Check-out':
        return (
          title: _tSiteOps(context, 'Manual check-out recorded'),
          icon: Icons.logout_rounded,
          color: Colors.blue,
        );
      case 'View Roster':
        return (
          title: _tSiteOps(context, 'Roster viewed'),
          icon: Icons.list_alt_rounded,
          color: ScholesaColors.primary,
        );
      case 'Kit checklist updated':
        return (
          title: _tSiteOps(context, 'Kit checklist updated'),
          icon: Icons.inventory_2_outlined,
          color: Colors.deepPurple,
        );
      case 'Safety note saved':
        return (
          title: _tSiteOps(context, 'Safety note saved'),
          icon: Icons.shield_outlined,
          color: Colors.redAccent,
        );
      default:
        return (
          title: action,
          icon: Icons.info_outline,
          color: ScholesaColors.textSecondary,
        );
    }
  }

  Widget _buildActivityItem(
      String title, String time, IconData icon, Color color) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(_tSiteOps(context, title)),
      trailing: Text(
        time,
        style: const TextStyle(
          fontSize: 12,
          color: ScholesaColors.textSecondary,
        ),
      ),
    );
  }
}

class _ActivityEntry {
  const _ActivityEntry(this.title, this.time, this.icon, this.color);

  final String title;
  final String time;
  final IconData icon;
  final Color color;
}

class _TimedActivity {
  const _TimedActivity({
    required this.title,
    required this.at,
    required this.icon,
    required this.color,
  });

  final String title;
  final DateTime at;
  final IconData icon;
  final Color color;
}

class _TimetableEntry {
  const _TimetableEntry({
    required this.title,
    required this.timeLabel,
    required this.educator,
    required this.room,
    required this.learnerCount,
  });

  final String title;
  final String timeLabel;
  final String educator;
  final String room;
  final int learnerCount;
}

class _KitChecklistItem {
  const _KitChecklistItem({
    required this.id,
    required this.label,
    required this.completed,
    required this.order,
    this.note,
  });

  final String id;
  final String label;
  final bool completed;
  final int order;
  final String? note;

  _KitChecklistItem copyWith({bool? completed}) {
    return _KitChecklistItem(
      id: id,
      label: label,
      completed: completed ?? this.completed,
      order: order,
      note: note,
    );
  }
}

class _SafetyNoteEntry {
  const _SafetyNoteEntry({
    required this.note,
    required this.createdAt,
    required this.authorLabel,
  });

  final String note;
  final DateTime createdAt;
  final String authorLabel;
}

class _SiteRuntimeRolloutState {
  const _SiteRuntimeRolloutState({
    this.package,
    required this.deliveries,
    required this.activations,
    this.error,
  });

  final FederatedLearningResolvedRuntimePackageModel? package;
  final List<FederatedLearningRuntimeDeliveryRecordModel> deliveries;
  final List<FederatedLearningRuntimeActivationRecordModel> activations;
  final String? error;
}

class _SiteRuntimeRolloutSummary {
  const _SiteRuntimeRolloutSummary({
    required this.resolvedCount,
    required this.stagedCount,
    required this.fallbackCount,
    required this.pendingCount,
  });

  final int resolvedCount;
  final int stagedCount;
  final int fallbackCount;
  final int pendingCount;
}

const List<_KitChecklistItem> _defaultKitChecklist = <_KitChecklistItem>[
  _KitChecklistItem(
    id: 'arrival-tablets',
    label: 'Tablets charged',
    completed: false,
    order: 1,
    note: 'Verify every learner device is above 70%',
  ),
  _KitChecklistItem(
    id: 'maker-kits',
    label: 'Maker kits staged',
    completed: false,
    order: 2,
    note: 'Place robotics and lab kits in the session rooms',
  ),
  _KitChecklistItem(
    id: 'safety-bag',
    label: 'First-aid bag confirmed',
    completed: false,
    order: 3,
    note: 'Confirm the bag is stocked before doors open',
  ),
];
