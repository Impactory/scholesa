import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../auth/app_state.dart';

class LearnerHabitsScreen extends StatefulWidget {
  const LearnerHabitsScreen({super.key});

  @override
  State<LearnerHabitsScreen> createState() => _LearnerHabitsScreenState();
}

class _LearnerHabitsScreenState extends State<LearnerHabitsScreen> {
  late Future<List<HabitModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<HabitModel>> _load() async {
    final learnerId = context.read<AppState>().user?.uid;
    if (learnerId == null) return <HabitModel>[];
    return HabitRepository().listActiveByLearner(learnerId);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
  }

  Future<void> _complete(HabitModel habit) async {
    await HabitRepository().markCompleted(id: habit.id);
    await _refresh();
  }

  Future<void> _reflect(HabitModel habit) async {
    await HabitRepository().recordReflection(id: habit.id);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Habit Coach')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<HabitModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final habits = snapshot.data ?? <HabitModel>[];
            if (habits.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  Text('No active habits yet.'),
                  SizedBox(height: 8),
                  Text('Habits track commitment, evidence, and reflection per specs 21/22.'),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: habits.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final habit = habits[index];
                return ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(habit.title),
                  subtitle: Text('Status: ${habit.status}'),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      TextButton(onPressed: () => _complete(habit), child: const Text('Done')),
                      TextButton(onPressed: () => _reflect(habit), child: const Text('Reflect')),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
