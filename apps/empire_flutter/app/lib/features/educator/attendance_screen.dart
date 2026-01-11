import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../auth/app_state.dart';

class EducatorAttendanceScreen extends StatefulWidget {
  const EducatorAttendanceScreen({super.key});

  @override
  State<EducatorAttendanceScreen> createState() => _EducatorAttendanceScreenState();
}

class _EducatorAttendanceScreenState extends State<EducatorAttendanceScreen> {
  late Future<_AttendanceData> _future;
  String? _selectedOccurrenceId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AttendanceData> _load() async {
    final appState = context.read<AppState>();
    final siteId = appState.primarySiteId ?? '';
    if (siteId.isEmpty) return const _AttendanceData();
    final occurrences = await SessionOccurrenceRepository().listBySite(siteId);
    final enrollments = await EnrollmentRepository().listBySite(siteId);
    final records = await AttendanceRepository().listRecentBySite(siteId, limit: 200);
    _selectedOccurrenceId ??= occurrences.isNotEmpty ? occurrences.first.id : null;
    return _AttendanceData(
      occurrences: occurrences,
      enrollments: enrollments,
      records: records,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _mark(String learnerId, String status) async {
    final occurrenceId = _selectedOccurrenceId;
    if (occurrenceId == null) return;
    setState(() => _saving = true);
    final appState = context.read<AppState>();
    final repo = AttendanceRepository();
    final model = AttendanceRecordModel(
      id: '',
      siteId: appState.primarySiteId ?? '',
      sessionOccurrenceId: occurrenceId,
      learnerId: learnerId,
      status: status,
      recordedBy: appState.user?.uid ?? '',
      note: null,
      createdAt: null,
      updatedAt: null,
    );
    await repo.upsert(model);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Marked $status')));
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_AttendanceData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data ?? const _AttendanceData();
            if (data.occurrences.isEmpty) {
              return const Center(child: Text('No occurrences for this site.'));
            }
            final selected = data.occurrences.firstWhere(
              (o) => o.id == _selectedOccurrenceId,
              orElse: () => data.occurrences.first,
            );
            final learners = data.enrollments.map((e) => e.learnerId).toSet();
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Select occurrence', border: OutlineInputBorder()),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selected.id,
                      items: data.occurrences
                          .map((o) => DropdownMenuItem<String>(value: o.id, child: Text('Session ${o.sessionId}')))
                          .toList(),
                      onChanged: (value) => setState(() => _selectedOccurrenceId = value),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final learnerId in learners) _buildLearnerTile(learnerId, data.records),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLearnerTile(String learnerId, List<AttendanceRecordModel> records) {
    final record = records.firstWhere(
      (r) => r.learnerId == learnerId && r.sessionOccurrenceId == _selectedOccurrenceId,
      orElse: () => AttendanceRecordModel(
        id: '',
        siteId: '',
        sessionOccurrenceId: _selectedOccurrenceId ?? '',
        learnerId: learnerId,
        status: 'unmarked',
        recordedBy: '',
        note: null,
        createdAt: null,
        updatedAt: null,
      ),
    );
    final status = record.status.toUpperCase();
    Color badgeColor;
    switch (status) {
      case 'PRESENT':
        badgeColor = Colors.green;
        break;
      case 'LATE':
        badgeColor = Colors.orange;
        break;
      case 'ABSENT':
        badgeColor = Colors.red;
        break;
      default:
        badgeColor = Colors.grey;
    }
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: badgeColor, child: Text(status.isNotEmpty ? status[0] : '?')),
        title: Text('Learner $learnerId'),
        subtitle: Text('Status: $status'),
        trailing: _saving
            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : Wrap(
                spacing: 8,
                children: [
                  TextButton(onPressed: () => _mark(learnerId, 'PRESENT'), child: const Text('Present')),
                  TextButton(onPressed: () => _mark(learnerId, 'LATE'), child: const Text('Late')),
                  TextButton(onPressed: () => _mark(learnerId, 'ABSENT'), child: const Text('Absent')),
                ],
              ),
      ),
    );
  }
}

class _AttendanceData {
  const _AttendanceData({
    this.occurrences = const <SessionOccurrenceModel>[],
    this.enrollments = const <EnrollmentModel>[],
    this.records = const <AttendanceRecordModel>[],
  });

  final List<SessionOccurrenceModel> occurrences;
  final List<EnrollmentModel> enrollments;
  final List<AttendanceRecordModel> records;
}
