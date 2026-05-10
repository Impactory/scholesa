import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/habits/habit_models.dart';
import 'package:scholesa_app/modules/habits/habit_service.dart';
import 'package:scholesa_app/modules/learner/learner_today_page.dart';
import 'package:scholesa_app/modules/messages/message_service.dart';
import 'package:scholesa_app/modules/missions/mission_models.dart';
import 'package:scholesa_app/modules/missions/mission_service.dart';
import 'package:scholesa_app/services/firestore_service.dart';
import 'package:scholesa_app/ui/theme/scholesa_theme.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _FakeHabitService extends HabitService {
  _FakeHabitService({
    required super.firestoreService,
    required super.learnerId,
    List<Habit>? habits,
    this.loadError,
  })  : _habitsValue = habits ?? <Habit>[],
        super();

  final List<Habit> _habitsValue;
  final String? loadError;

  bool _isLoadingValue = false;
  String? _errorValue;

  @override
  List<Habit> get habits => _habitsValue;

  @override
  List<Habit> get activeHabits =>
      _habitsValue.where((Habit habit) => habit.isActive).toList();

  @override
  List<Habit> get todayHabits => activeHabits;

  @override
  bool get isLoading => _isLoadingValue;

  @override
  String? get error => _errorValue;

  @override
  int get completedTodayCount =>
      todayHabits.where((Habit habit) => habit.isCompletedToday).length;

  @override
  int get totalTodayCount => todayHabits.length;

  @override
  int get totalStreak => todayHabits.fold<int>(
      0, (int sum, Habit habit) => sum + habit.currentStreak);

  @override
  Future<void> loadHabits() async {
    _isLoadingValue = true;
    _errorValue = null;
    notifyListeners();
    await Future<void>.delayed(Duration.zero);
    _errorValue = loadError;
    _isLoadingValue = false;
    notifyListeners();
  }
}

class _FakeMissionService extends MissionService {
  _FakeMissionService({
    required super.firestoreService,
    required super.learnerId,
    List<Mission>? missions,
    this.loadError,
  })  : _missionsValue = missions ?? <Mission>[],
        super();

  final List<Mission> _missionsValue;
  final String? loadError;

  bool _isLoadingValue = false;
  String? _errorValue;

  @override
  List<Mission> get missions => _missionsValue;

  @override
  List<Mission> get activeMissions => _missionsValue
      .where((Mission mission) => mission.status == MissionStatus.inProgress)
      .toList();

  @override
  bool get isLoading => _isLoadingValue;

  @override
  String? get error => _errorValue;

  @override
  Future<void> loadMissions() async {
    _isLoadingValue = true;
    _errorValue = null;
    notifyListeners();
    await Future<void>.delayed(Duration.zero);
    _errorValue = loadError;
    _isLoadingValue = false;
    notifyListeners();
  }
}

AppState _buildLearnerState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'learner-1',
    'email': 'learner-1@scholesa.test',
    'displayName': 'Learner One',
    'role': UserRole.learner.name,
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'localeCode': 'en',
    'entitlements': const <Map<String, dynamic>>[],
  });
  return state;
}

Widget _buildHarness({
  required FirestoreService firestoreService,
  required HabitService habitService,
  required MissionService missionService,
  required MessageService messageService,
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: _buildLearnerState()),
      Provider<FirestoreService>.value(value: firestoreService),
      ChangeNotifierProvider<HabitService>.value(value: habitService),
      ChangeNotifierProvider<MissionService>.value(value: missionService),
      ChangeNotifierProvider<MessageService>.value(value: messageService),
      Provider<dynamic>.value(value: null),
    ],
    child: MaterialApp(
      theme: ScholesaTheme.light.copyWith(
        splashFactory: NoSplash.splashFactory,
      ),
      locale: const Locale('en'),
      supportedLocales: const <Locale>[
        Locale('en'),
        Locale('zh', 'CN'),
        Locale('zh', 'TW'),
      ],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const LearnerTodayPage(),
    ),
  );
}

Future<void> _scrollUntilTextVisible(
  WidgetTester tester,
  String text,
) async {
  await tester.scrollUntilVisible(
    find.text(text),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'learner today shows explicit mission and habit load errors instead of fake empty cards',
      (WidgetTester tester) async {
    final FirestoreService firestoreService = FirestoreService(
      firestore: FakeFirebaseFirestore(),
      auth: _MockFirebaseAuth(),
    );
    final HabitService habitService = _FakeHabitService(
      firestoreService: firestoreService,
      learnerId: 'learner-1',
      loadError: 'Failed to load habits from test',
    );
    final MissionService missionService = _FakeMissionService(
      firestoreService: firestoreService,
      learnerId: 'learner-1',
      loadError: 'Failed to load missions from test',
    );
    final MessageService messageService = MessageService(
      firestoreService: firestoreService,
      userId: 'learner-1',
    );

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        habitService: habitService,
        missionService: missionService,
        messageService: messageService,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('My Evidence Loop'), findsOneWidget);
    expect(find.text('Choose a mission to start your next build sprint.'),
        findsOneWidget);
    expect(find.text('Unable to load habits'), findsOneWidget);
    expect(find.text('Failed to load habits from test'), findsOneWidget);
    expect(find.text('No habits scheduled yet'), findsNothing);
    await _scrollUntilTextVisible(tester, 'Active Missions');
    expect(find.text('Unable to load missions'), findsOneWidget);
    expect(find.text('Failed to load missions from test'), findsOneWidget);
    expect(find.text('No active missions yet'), findsNothing);
  });

  testWidgets(
      'learner today keeps loaded habits and missions visible behind stale-data banners',
      (WidgetTester tester) async {
    final FirestoreService firestoreService = FirestoreService(
      firestore: FakeFirebaseFirestore(),
      auth: _MockFirebaseAuth(),
    );
    final HabitService habitService = _FakeHabitService(
      firestoreService: firestoreService,
      learnerId: 'learner-1',
      habits: <Habit>[
        Habit(
          id: 'habit-1',
          title: 'Read for 10 minutes',
          emoji: '📚',
          category: HabitCategory.learning,
          createdAt: DateTime(2026, 3, 18),
          currentStreak: 4,
        ),
      ],
      loadError: 'Failed to refresh habits from test',
    );
    final MissionService missionService = _FakeMissionService(
      firestoreService: firestoreService,
      learnerId: 'learner-1',
      missions: <Mission>[
        const Mission(
          id: 'mission-1',
          title: 'Prototype a water filter',
          description: 'Build and test a working prototype.',
          pillar: Pillar.futureSkills,
          difficulty: DifficultyLevel.intermediate,
          status: MissionStatus.inProgress,
        ),
      ],
      loadError: 'Failed to refresh missions from test',
    );
    final MessageService messageService = MessageService(
      firestoreService: firestoreService,
      userId: 'learner-1',
    );

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        habitService: habitService,
        missionService: missionService,
        messageService: messageService,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('My Evidence Loop'), findsOneWidget);
    expect(find.text('Prototype a water filter'), findsWidgets);
    expect(
      find.text(
          'Showing last loaded habits. Failed to refresh habits from test'),
      findsOneWidget,
    );
    await _scrollUntilTextVisible(tester, 'Active Missions');
    expect(
      find.text(
        'Showing last loaded mission progress. Failed to refresh missions from test',
      ),
      findsOneWidget,
    );
    expect(find.text('Read for 10 minutes'), findsOneWidget);
    expect(find.text('Prototype a water filter'), findsWidgets);
  });

  testWidgets(
      'learner today renders current evidence actions on classroom mobile width',
      (WidgetTester tester) async {
    final FirestoreService firestoreService = FirestoreService(
      firestore: FakeFirebaseFirestore(),
      auth: _MockFirebaseAuth(),
    );
    final HabitService habitService = _FakeHabitService(
      firestoreService: firestoreService,
      learnerId: 'learner-1',
      habits: <Habit>[
        Habit(
          id: 'habit-1',
          title: 'Capture one prototype photo',
          emoji: 'P',
          category: HabitCategory.learning,
          createdAt: DateTime(2026, 3, 18),
          targetMinutes: 10,
          currentStreak: 2,
        ),
      ],
    );
    final MissionService missionService = _FakeMissionService(
      firestoreService: firestoreService,
      learnerId: 'learner-1',
      missions: <Mission>[
        const Mission(
          id: 'mission-1',
          title: 'Prototype a water filter',
          description: 'Build and test a working prototype.',
          pillar: Pillar.futureSkills,
          difficulty: DifficultyLevel.intermediate,
          status: MissionStatus.inProgress,
          progress: 0.45,
          educatorFeedback: 'Explain what changed after the first test.',
          reflectionPrompt: 'What evidence shows your filter improved?',
          skills: <Skill>[
            Skill(
              id: 'skill-1',
              name: 'Prototype testing',
              pillar: Pillar.futureSkills,
            ),
          ],
        ),
      ],
    );
    final MessageService messageService = MessageService(
      firestoreService: firestoreService,
      userId: 'learner-1',
    );

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        habitService: habitService,
        missionService: missionService,
        messageService: messageService,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('My Evidence Loop'), findsOneWidget);
    expect(find.text('What I am building'), findsOneWidget);
    expect(find.text('Prototype a water filter'), findsWidgets);
    expect(find.text('What evidence I have shown'), findsOneWidget);
    expect(find.text('Explain what changed after the first test.'),
        findsOneWidget);
    expect(find.text('What capability I am growing'), findsOneWidget);
    expect(find.text('Prototype testing'), findsOneWidget);
    expect(find.text('What I need to explain or verify next'), findsOneWidget);
    expect(
        find.text('What evidence shows your filter improved?'), findsOneWidget);

    await _scrollUntilTextVisible(tester, 'Capture one prototype photo');
    expect(find.text('Start'), findsOneWidget);
    await _scrollUntilTextVisible(tester, 'Active Missions');
    expect(find.text('45%'), findsOneWidget);
  });
}
