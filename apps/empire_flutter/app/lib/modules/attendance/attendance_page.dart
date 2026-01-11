import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    // TODO: Get attendance service from provider and load
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
    // For now, show placeholder until service is wired
    return const _OccurrenceSelector();
  }
}

/// Occurrence selector view
class _OccurrenceSelector extends StatelessWidget {
  const _OccurrenceSelector();

  @override
  Widget build(BuildContext context) {
    // Mock data for demonstration
    final List<_MockOccurrence> mockOccurrences = <_MockOccurrence>[
      _MockOccurrence(
        id: '1',
        title: 'Grade 3 - Morning Session',
        time: '9:00 AM - 10:30 AM',
        room: 'Room A',
        studentCount: 15,
      ),
      _MockOccurrence(
        id: '2',
        title: 'Grade 4 - Afternoon Session',
        time: '1:00 PM - 2:30 PM',
        room: 'Room B',
        studentCount: 12,
      ),
    ];

    if (mockOccurrences.isEmpty) {
      return const EmptyState(
        icon: Icons.event_busy,
        title: 'No classes today',
        message: 'You have no scheduled classes for today.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: mockOccurrences.length,
      itemBuilder: (BuildContext context, int index) {
        final _MockOccurrence occ = mockOccurrences[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(Icons.class_, color: Colors.white),
            ),
            title: Text(occ.title),
            subtitle: Text('${occ.time} • ${occ.room}'),
            trailing: Chip(
              label: Text('${occ.studentCount} students'),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _AttendanceRosterView(occurrenceId: occ.id),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _MockOccurrence {

  _MockOccurrence({
    required this.id,
    required this.title,
    required this.time,
    required this.room,
    required this.studentCount,
  });
  final String id;
  final String title;
  final String time;
  final String room;
  final int studentCount;
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

  // Mock roster for demonstration
  final List<_MockStudent> _mockRoster = <_MockStudent>[
    _MockStudent(id: '1', name: 'Alice Johnson'),
    _MockStudent(id: '2', name: 'Bob Smith'),
    _MockStudent(id: '3', name: 'Charlie Brown'),
    _MockStudent(id: '4', name: 'Diana Prince'),
    _MockStudent(id: '5', name: 'Edward Norton'),
  ];

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Class Roster'),
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
                    onPressed: () => _markAll(AttendanceStatus.present),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    label: const Text('All Absent'),
                    onPressed: () => _markAll(AttendanceStatus.absent),
                  ),
                ),
              ],
            ),
          ),
          // Roster list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _mockRoster.length,
              itemBuilder: (BuildContext context, int index) {
                final _MockStudent student = _mockRoster[index];
                return _StudentAttendanceCard(
                  student: student,
                  status: _attendance[student.id],
                  note: _notes[student.id],
                  onStatusChanged: (AttendanceStatus status) {
                    setState(() {
                      _attendance[student.id] = status;
                    });
                  },
                  onNoteChanged: (String note) {
                    setState(() {
                      _notes[student.id] = note;
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
                  label: Text('Save Attendance (${_attendance.length}/${_mockRoster.length})'),
                  onPressed: _attendance.length == _mockRoster.length
                      ? () => _saveAttendance(appState)
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _markAll(AttendanceStatus status) {
    setState(() {
      for (final _MockStudent student in _mockRoster) {
        _attendance[student.id] = status;
      }
    });
  }

  Future<void> _saveAttendance(AppState appState) async {
    // TODO: Submit via AttendanceService
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Attendance saved (offline sync enabled)'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context);
  }
}

class _MockStudent {

  _MockStudent({required this.id, required this.name});
  final String id;
  final String name;
}

/// Individual student attendance card
class _StudentAttendanceCard extends StatelessWidget {

  const _StudentAttendanceCard({
    required this.student,
    this.status,
    this.note,
    required this.onStatusChanged,
    required this.onNoteChanged,
  });
  final _MockStudent student;
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
                  child: Text(student.name[0]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    student.name,
                    style: Theme.of(context).textTheme.titleMedium,
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
