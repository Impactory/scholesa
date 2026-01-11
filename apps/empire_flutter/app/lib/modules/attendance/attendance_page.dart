import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../auth/app_state.dart';
import '../../offline/sync_status_widget.dart';
import '../../ui/common/loading.dart';
import '../../ui/common/empty_state.dart';
import '../../ui/common/error_state.dart';
import 'attendance_models.dart';
import 'attendance_service.dart';

/// Attendance taking page
class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOccurrences();
    });
  }

  Future<void> _loadOccurrences() async {
    final AttendanceService? service = context.read<AttendanceService?>();
    if (service != null) {
      await service.loadTodayOccurrences();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Take Attendance'),
        actions: const <Widget>[
          SyncStatusIndicator(),
          SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: <Widget>[
          const OfflineBanner(),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final AttendanceService? service = context.watch<AttendanceService?>();
    
    if (service == null) {
      return const Center(
        child: Text('Attendance service not available'),
      );
    }

    if (service.isLoading) {
      return const LoadingWidget();
    }

    if (service.error != null) {
      return ErrorState(
        message: service.error!,
        onRetry: _loadOccurrences,
      );
    }

    return _OccurrenceSelector(
      occurrences: service.todayOccurrences,
      onRefresh: _loadOccurrences,
    );
  }
}

/// Occurrence selector view
class _OccurrenceSelector extends StatelessWidget {
  const _OccurrenceSelector({
    required this.occurrences,
    required this.onRefresh,
  });

  final List<SessionOccurrence> occurrences;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (occurrences.isEmpty) {
      return EmptyState(
        icon: Icons.event_busy,
        title: 'No classes today',
        message: 'You have no scheduled classes for today.',
        action: TextButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: occurrences.length,
        itemBuilder: (BuildContext context, int index) {
          final SessionOccurrence occ = occurrences[index];
          final String timeStr = DateFormat.jm().format(occ.startTime);
          final String endTimeStr = occ.endTime != null 
              ? ' - ${DateFormat.jm().format(occ.endTime!)}'
              : '';
          
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor,
                child: const Icon(Icons.class_, color: Colors.white),
              ),
              title: Text(occ.title),
              subtitle: Text('$timeStr$endTimeStr${occ.roomName != null ? ' • ${occ.roomName}' : ''}'),
              trailing: Chip(
                label: Text('${occ.learnerCount ?? occ.roster.length} students'),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => _AttendanceRosterView(occurrenceId: occ.id),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Roster view for taking attendance
class _AttendanceRosterView extends StatefulWidget {
  const _AttendanceRosterView({required this.occurrenceId});
  
  final String occurrenceId;

  @override
  State<_AttendanceRosterView> createState() => _AttendanceRosterViewState();
}

class _AttendanceRosterViewState extends State<_AttendanceRosterView> {
  final Map<String, AttendanceStatus> _attendance = <String, AttendanceStatus>{};
  final Map<String, String> _notes = <String, String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRoster();
    });
  }

  Future<void> _loadRoster() async {
    final AttendanceService? service = context.read<AttendanceService?>();
    if (service != null) {
      await service.loadOccurrenceRoster(widget.occurrenceId);
      
      // Initialize attendance map from existing records
      if (service.currentOccurrence != null) {
        for (final RosterLearner learner in service.currentOccurrence!.roster) {
          if (learner.currentAttendance != null) {
            _attendance[learner.id] = learner.currentAttendance!.status;
            if (learner.currentAttendance!.notes != null) {
              _notes[learner.id] = learner.currentAttendance!.notes!;
            }
          }
        }
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    context.read<AttendanceService?>()?.clearCurrentOccurrence();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AttendanceService? service = context.watch<AttendanceService?>();
    final AppState appState = context.watch<AppState>();
    
    if (service == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Class Roster')),
        body: const Center(child: Text('Service not available')),
      );
    }

    if (service.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Class Roster')),
        body: const LoadingWidget(),
      );
    }

    if (service.error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Class Roster')),
        body: ErrorState(
          message: service.error!,
          onRetry: _loadRoster,
        ),
      );
    }

    final SessionOccurrence? occurrence = service.currentOccurrence;
    if (occurrence == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Class Roster')),
        body: const EmptyState(
          icon: Icons.person_off,
          title: 'No roster found',
          message: 'Could not load the class roster.',
        ),
      );
    }

    final List<RosterLearner> roster = occurrence.roster;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(occurrence.title),
        actions: const <Widget>[
          SyncStatusIndicator(),
          SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: <Widget>[
          const OfflineBanner(),
          // Quick actions bar
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey[100],
            child: Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    label: const Text('All Present'),
                    onPressed: () => _markAll(roster, AttendanceStatus.present),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    label: const Text('All Absent'),
                    onPressed: () => _markAll(roster, AttendanceStatus.absent),
                  ),
                ),
              ],
            ),
          ),
          // Roster list
          Expanded(
            child: roster.isEmpty
                ? const EmptyState(
                    icon: Icons.people_outline,
                    title: 'No learners enrolled',
                    message: 'There are no learners enrolled in this class.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: roster.length,
                    itemBuilder: (BuildContext context, int index) {
                      final RosterLearner learner = roster[index];
                      return _StudentAttendanceCard(
                        learner: learner,
                        status: _attendance[learner.id],
                        note: _notes[learner.id],
                        onStatusChanged: (AttendanceStatus status) {
                          setState(() {
                            _attendance[learner.id] = status;
                          });
                        },
                        onNoteChanged: (String note) {
                          setState(() {
                            _notes[learner.id] = note;
                          });
                        },
                      );
                    },
                  ),
          ),
          // Submit button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: Text('Save Attendance (${_attendance.length}/${roster.length})'),
                  onPressed: _attendance.length == roster.length
                      ? () => _saveAttendance(service, appState)
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _markAll(List<RosterLearner> roster, AttendanceStatus status) {
    setState(() {
      for (final RosterLearner learner in roster) {
        _attendance[learner.id] = status;
      }
    });
  }

  Future<void> _saveAttendance(AttendanceService service, AppState appState) async {
    final List<AttendanceRecord> records = _attendance.entries.map((MapEntry<String, AttendanceStatus> entry) {
      return AttendanceRecord(
        id: '',
        occurrenceId: widget.occurrenceId,
        learnerId: entry.key,
        status: entry.value,
        recordedAt: DateTime.now(),
        recordedBy: appState.userId,
        notes: _notes[entry.key],
      );
    }).toList();

    await service.batchRecordAttendance(records);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }
}

/// Individual student attendance card
class _StudentAttendanceCard extends StatelessWidget {
  const _StudentAttendanceCard({
    required this.learner,
    this.status,
    this.note,
    required this.onStatusChanged,
    required this.onNoteChanged,
  });

  final RosterLearner learner;
  final AttendanceStatus? status;
  final String? note;
  final ValueChanged<AttendanceStatus> onStatusChanged;
  final ValueChanged<String> onNoteChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundImage: learner.photoUrl != null 
                      ? NetworkImage(learner.photoUrl!)
                      : null,
                  child: learner.photoUrl == null 
                      ? Text(learner.displayName.isNotEmpty ? learner.displayName[0] : '?')
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        learner.displayName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (learner.currentAttendance?.isOffline == true)
                        Text(
                          'Pending sync',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[700],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Status buttons
            Row(
              children: <Widget>[
                _StatusButton(
                  label: 'Present',
                  icon: Icons.check_circle,
                  color: Colors.green,
                  isSelected: status == AttendanceStatus.present,
                  onTap: () => onStatusChanged(AttendanceStatus.present),
                ),
                const SizedBox(width: 8),
                _StatusButton(
                  label: 'Late',
                  icon: Icons.schedule,
                  color: Colors.orange,
                  isSelected: status == AttendanceStatus.late,
                  onTap: () => onStatusChanged(AttendanceStatus.late),
                ),
                const SizedBox(width: 8),
                _StatusButton(
                  label: 'Absent',
                  icon: Icons.cancel,
                  color: Colors.red,
                  isSelected: status == AttendanceStatus.absent,
                  onTap: () => onStatusChanged(AttendanceStatus.absent),
                ),
                const SizedBox(width: 8),
                _StatusButton(
                  label: 'Excused',
                  icon: Icons.medical_services,
                  color: Colors.blue,
                  isSelected: status == AttendanceStatus.excused,
                  onTap: () => onStatusChanged(AttendanceStatus.excused),
                ),
              ],
            ),
            // Note field (shown for late/absent/excused)
            if (status != null && status != AttendanceStatus.present) ...<Widget>[
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Add a note (optional)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                controller: TextEditingController(text: note),
                onChanged: onNoteChanged,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
            border: Border.all(
              color: isSelected ? color : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                color: isSelected ? color : Colors.grey,
                size: 20,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? color : Colors.grey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
