import 'package:flutter/material.dart';
import '../../ui/theme/scholesa_theme.dart';

/// Site Sessions Page - Schedule and manage sessions
class SiteSessionsPage extends StatefulWidget {
  const SiteSessionsPage({super.key});

  @override
  State<SiteSessionsPage> createState() => _SiteSessionsPageState();
}

class _SiteSessionsPageState extends State<SiteSessionsPage> {
  DateTime _selectedDate = DateTime.now();
  String _viewMode = 'week';
  final Map<String, List<_SessionData>> _sessionsByTime =
      <String, List<_SessionData>>{
    '9:00 AM': <_SessionData>[
      const _SessionData(
        title: 'AI Explorers - Level 1',
        educator: 'Ms. Sarah Chen',
        room: 'Lab A',
        learnerCount: 12,
        pillar: 'Future Skills',
      ),
    ],
    '10:30 AM': <_SessionData>[
      const _SessionData(
        title: 'Leadership Workshop',
        educator: 'Mr. James Wilson',
        room: 'Main Hall',
        learnerCount: 15,
        pillar: 'Leadership',
      ),
      const _SessionData(
        title: 'Coding Fundamentals',
        educator: 'Ms. Emily Park',
        room: 'Lab B',
        learnerCount: 10,
        pillar: 'Future Skills',
      ),
    ],
    '1:00 PM': <_SessionData>[
      const _SessionData(
        title: 'Community Project',
        educator: 'Dr. Michael Brown',
        room: 'Garden Area',
        learnerCount: 18,
        pillar: 'Impact',
      ),
    ],
    '2:30 PM': <_SessionData>[
      const _SessionData(
        title: 'Robotics Club',
        educator: 'Ms. Sarah Chen',
        room: 'Lab A',
        learnerCount: 8,
        pillar: 'Future Skills',
      ),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<String, List<_SessionData>>> timeSlots =
        _sessionsByTime.entries.toList(growable: false);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              ScholesaColors.site.withValues(alpha: 0.05),
              Colors.white,
              ScholesaColors.scheduleGradient.colors.first.withValues(alpha: 0.03),
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildViewToggle()),
            SliverToBoxAdapter(child: _buildCalendarStrip()),
            SliverToBoxAdapter(child: _buildSessionsHeader()),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                    if (index >= timeSlots.length) {
                      return null;
                    }

                    final MapEntry<String, List<_SessionData>> slot =
                        timeSlots[index];
                    return _SessionTimeSlot(
                      time: slot.key,
                      sessions: slot.value,
                    );
                  },
                  childCount: timeSlots.length,
                ),
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewSession,
        backgroundColor: ScholesaColors.site,
        icon: const Icon(Icons.add),
        label: const Text('New Session'),
      ),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: ScholesaColors.scheduleGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: ScholesaColors.site.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.calendar_month, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Session Schedule',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: ScholesaColors.site,
                        ),
                  ),
                  Text(
                    'Manage site sessions and rooms',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: _ViewToggleButton(
                label: 'Day',
                isSelected: _viewMode == 'day',
                onTap: () => setState(() => _viewMode = 'day'),
              ),
            ),
            Expanded(
              child: _ViewToggleButton(
                label: 'Week',
                isSelected: _viewMode == 'week',
                onTap: () => setState(() => _viewMode = 'week'),
              ),
            ),
            Expanded(
              child: _ViewToggleButton(
                label: 'Month',
                isSelected: _viewMode == 'month',
                onTap: () => setState(() => _viewMode = 'month'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarStrip() {
    final DateTime today = DateTime.now();
    final List<DateTime> weekDays = List<DateTime>.generate(
      7,
      (int i) => today.subtract(Duration(days: today.weekday - 1 - i)),
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.subtract(const Duration(days: 7));
              });
            },
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: weekDays.map((DateTime date) {
                final bool isSelected = date.day == _selectedDate.day &&
                    date.month == _selectedDate.month;
                final bool isToday =
                    date.day == today.day && date.month == today.month;
                return GestureDetector(
                  onTap: () => setState(() => _selectedDate = date),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? ScholesaColors.site
                          : isToday
                              ? ScholesaColors.site.withValues(alpha: 0.1)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: <Widget>[
                        Text(
                          _getDayAbbrev(date.weekday),
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : isToday
                                    ? ScholesaColors.site
                                    : Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          date.day.toString(),
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : isToday
                                    ? ScholesaColors.site
                                    : Colors.grey[800],
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.add(const Duration(days: 7));
              });
            },
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            _formatSelectedDate(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          TextButton.icon(
            onPressed: _showFilterSheet,
            icon: const Icon(Icons.filter_list, size: 18),
            label: const Text('Filter'),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Session Filters',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: <String>['day', 'week', 'month']
                    .map(
                      (String mode) => ChoiceChip(
                        label: Text(mode.toUpperCase()),
                        selected: _viewMode == mode,
                        onSelected: (_) {
                          setState(() => _viewMode = mode);
                          Navigator.pop(sheetContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Showing ${mode.toUpperCase()} view'),
                              backgroundColor: ScholesaColors.site,
                            ),
                          );
                        },
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDayAbbrev(int weekday) {
    const List<String> days = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  String _formatSelectedDate() {
    const List<String> months = <String>[
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[_selectedDate.month - 1]} ${_selectedDate.day}, ${_selectedDate.year}';
  }

  Future<void> _createNewSession() async {
    final _NewSessionResult? result = await showModalBottomSheet<_NewSessionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => const _CreateSessionSheet(),
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _sessionsByTime.putIfAbsent(result.time, () => <_SessionData>[]);
      _sessionsByTime[result.time]!.add(result.session);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Session created successfully'),
        backgroundColor: ScholesaColors.success,
      ),
    );
  }
}

class _NewSessionResult {
  const _NewSessionResult({required this.time, required this.session});

  final String time;
  final _SessionData session;
}

class _ViewToggleButton extends StatelessWidget {

  const _ViewToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? ScholesaColors.site : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionData {

  const _SessionData({
    required this.title,
    required this.educator,
    required this.room,
    required this.learnerCount,
    required this.pillar,
  });
  final String title;
  final String educator;
  final String room;
  final int learnerCount;
  final String pillar;
}

class _SessionTimeSlot extends StatelessWidget {

  const _SessionTimeSlot({required this.time, required this.sessions});
  final String time;
  final List<_SessionData> sessions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 70,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                time,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: sessions.map((_SessionData session) => _SessionCard(session: session)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {

  const _SessionCard({required this.session});
  final _SessionData session;

  Color get _pillarColor {
    switch (session.pillar.toLowerCase()) {
      case 'future skills':
        return ScholesaColors.futureSkills;
      case 'leadership':
        return ScholesaColors.leadership;
      case 'impact':
        return ScholesaColors.impact;
      default:
        return ScholesaColors.site;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: _pillarColor, width: 4)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    session.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _pillarColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    session.pillar,
                    style: TextStyle(
                      color: _pillarColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Icon(Icons.person, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  session.educator,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(width: 16),
                Icon(Icons.meeting_room, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  session.room,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const Spacer(),
                Icon(Icons.people, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  '${session.learnerCount}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateSessionSheet extends StatefulWidget {
  const _CreateSessionSheet();

  @override
  State<_CreateSessionSheet> createState() => _CreateSessionSheetState();
}

class _CreateSessionSheetState extends State<_CreateSessionSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _educatorController =
      TextEditingController(text: 'Ms. Sarah Chen');
  final TextEditingController _learnerCountController =
      TextEditingController(text: '12');
  String _selectedPillar = 'Future Skills';
  String _selectedRoom = 'Lab A';
  String _selectedTime = '9:00 AM';

  @override
  void dispose() {
    _titleController.dispose();
    _educatorController.dispose();
    _learnerCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Create New Session',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Session Title',
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Pillar',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      _PillarOption(
                        label: 'Future Skills',
                        color: ScholesaColors.futureSkills,
                        isSelected: _selectedPillar == 'Future Skills',
                        onTap: () => setState(() => _selectedPillar = 'Future Skills'),
                      ),
                      const SizedBox(width: 8),
                      _PillarOption(
                        label: 'Leadership',
                        color: ScholesaColors.leadership,
                        isSelected: _selectedPillar == 'Leadership',
                        onTap: () => setState(() => _selectedPillar = 'Leadership'),
                      ),
                      const SizedBox(width: 8),
                      _PillarOption(
                        label: 'Impact',
                        color: ScholesaColors.impact,
                        isSelected: _selectedPillar == 'Impact',
                        onTap: () => setState(() => _selectedPillar = 'Impact'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedTime,
                    decoration: InputDecoration(
                      labelText: 'Time Slot',
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: <String>['9:00 AM', '10:30 AM', '1:00 PM', '2:30 PM', '4:00 PM']
                        .map((String time) => DropdownMenuItem<String>(
                              value: time,
                              child: Text(time),
                            ))
                        .toList(),
                    onChanged: (String? value) {
                      if (value != null) {
                        setState(() => _selectedTime = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _educatorController,
                    decoration: InputDecoration(
                      labelText: 'Educator',
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _learnerCountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Learner Count',
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedRoom,
                    decoration: InputDecoration(
                      labelText: 'Room',
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: <String>['Lab A', 'Lab B', 'Main Hall', 'Garden Area']
                        .map((String room) => DropdownMenuItem<String>(
                              value: room,
                              child: Text(room),
                            ))
                        .toList(),
                    onChanged: (String? value) {
                      if (value != null) {
                        setState(() => _selectedRoom = value);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final String title = _titleController.text.trim();
                        if (title.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Session title is required'),
                            ),
                          );
                          return;
                        }

                        final int learnerCount =
                            int.tryParse(_learnerCountController.text.trim()) ?? 0;

                        Navigator.pop(
                          context,
                          _NewSessionResult(
                            time: _selectedTime,
                            session: _SessionData(
                              title: title,
                              educator: _educatorController.text.trim().isEmpty
                                  ? 'Unassigned'
                                  : _educatorController.text.trim(),
                              room: _selectedRoom,
                              learnerCount: learnerCount,
                              pillar: _selectedPillar,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ScholesaColors.site,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Create Session'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillarOption extends StatelessWidget {

  const _PillarOption({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
