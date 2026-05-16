import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../../services/notification_service.dart';
import '../../services/telemetry_service.dart';
import '../../services/firestore_service.dart';
import '../../ui/theme/scholesa_theme.dart';
import '../../runtime/runtime.dart';
import '../../runtime/milo_voice_persona.dart';
import '../../auth/app_state.dart';
import '../../i18n/bos_coaching_i18n.dart';
import '../../i18n/learner_surface_i18n.dart';
import '../../ui/auth/global_session_menu.dart';
import '../missions/missions.dart';
import '../habits/habits.dart';
import '../messages/message_service.dart';

/// Learner Today Page - Daily summary for learners
class LearnerTodayPage extends StatefulWidget {
  const LearnerTodayPage({
    super.key,
    this.forceSetupMode = false,
  });

  final bool forceSetupMode;

  @override
  State<LearnerTodayPage> createState() => _LearnerTodayPageState();
}

class _LearnerTodayPageState extends State<LearnerTodayPage> {
  bool _showAiCoach = false;
  LearnerProfileModel? _learnerProfile;
  bool _isProfileLoading = false;
  bool _didLogOnboardingStart = false;
  bool _didAutoOpenForcedSetup = false;
  final FlutterTts _setupMiloTts = FlutterTts();

  String _t(String input) {
    return LearnerSurfaceI18n.text(context, input);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MissionService>().loadMissions();
      context.read<HabitService>().loadHabits();
      context.read<MessageService>().loadMessages();
      unawaited(_loadLearnerProfile(openSetupAfterLoad: widget.forceSetupMode));
    });
  }

  @override
  void dispose() {
    unawaited(_setupMiloTts.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = scheme.brightness == Brightness.dark;
    if (widget.forceSetupMode) {
      return MiloRuntimeScope(child: _buildOnboardingScaffold(scheme, isDark));
    }

    return MiloRuntimeScope(
        child: Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              isDark ? scheme.surface : const Color(0xFFF0FDF8),
              isDark ? scheme.surfaceContainerLow : const Color(0xFFF8FAFC),
              isDark ? scheme.surfaceContainer : const Color(0xFFFFFBEB),
            ],
            stops: const <double>[0.0, 0.5, 1.0],
          ),
        ),
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildGreetingCard()),
            SliverToBoxAdapter(child: _buildTodayProgress()),
            SliverToBoxAdapter(child: _buildEvidenceLoopCard()),
            SliverToBoxAdapter(child: _buildLearnerSetupCard()),
            SliverToBoxAdapter(child: _buildMotivationLoopCard()),
            SliverToBoxAdapter(child: _buildAiCoachingSection(context)),
            SliverToBoxAdapter(child: _buildLearnerLoopInsights(context)),
            SliverToBoxAdapter(child: _buildQuickActions()),
            SliverToBoxAdapter(child: _buildTodayHabits()),
            SliverToBoxAdapter(child: _buildActiveMissions()),
            const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
          ],
        ),
      ),
    ));
  }

  Widget _buildOnboardingScaffold(ColorScheme scheme, bool isDark) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              isDark ? scheme.surface : const Color(0xFFF0FDF8),
              isDark ? scheme.surfaceContainerLow : const Color(0xFFF8FAFC),
              isDark ? scheme.surfaceContainer : const Color(0xFFFFFBEB),
            ],
            stops: const <double>[0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _t('Learner onboarding'),
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _t('Build your goals, reminders, and reflection rhythm before you jump into missions.'),
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const SessionMenuHeaderAction(
                    foregroundColor: ScholesaColors.learner,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildLearnerSetupCard(),
              _buildMotivationLoopCard(isOnboardingSurface: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    Widget buildIdentityBlock() {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[ScholesaColors.learner, Color(0xFF059669)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: ScholesaColors.learner.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.wb_sunny, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _getGreeting(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _t('Today'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    Widget buildNotificationsAction() {
      return Consumer<MessageService>(
        builder: (BuildContext context, MessageService service, _) {
          final int unreadCount = service.unreadNotificationCount;
          return IconButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'cta': 'learner_today_open_notifications',
                  'unread_count': unreadCount,
                },
              );
              context.push('/notifications');
            },
            icon: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Icon(
                  unreadCount > 0
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_outlined,
                  color: context.schTextSecondary,
                  size: 28,
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: ScholesaColors.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    }

    final Widget sessionAction = SessionMenuHeaderAction(
      foregroundColor: scheme.onSurface,
    );

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compactHeader = constraints.maxWidth < 420;
            final Widget identityBlock = buildIdentityBlock();
            final Widget notificationsAction = buildNotificationsAction();

            if (compactHeader) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: identityBlock),
                  const SizedBox(width: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      notificationsAction,
                      const SizedBox(width: 4),
                      sessionAction,
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: <Widget>[
                Expanded(child: identityBlock),
                notificationsAction,
                const SizedBox(width: 4),
                sessionAction,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildGreetingCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF10B981), Color(0xFF047857)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.black.withValues(alpha: 0.08),
                      Colors.black.withValues(alpha: 0.18),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _t('🌟 Keep Going!'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _t(
                          "You're making amazing progress. Complete today's habits to maintain your streak!",
                        ),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.96),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.34)),
                  ),
                  child: Consumer<HabitService>(
                    builder: (BuildContext context, HabitService service, _) {
                      return Column(
                        children: <Widget>[
                          const Text(
                            '🔥',
                            style: TextStyle(fontSize: 32),
                          ),
                          Text(
                            '${service.totalStreak}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _t('day streak'),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayProgress() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Consumer<HabitService>(
              builder: (BuildContext context, HabitService service, _) {
                return _ProgressCard(
                  title: _t('Habits'),
                  completed: service.completedTodayCount,
                  total: service.totalTodayCount,
                  icon: Icons.check_circle,
                  color: const Color(0xFF8B5CF6),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Consumer<MissionService>(
              builder: (BuildContext context, MissionService service, _) {
                final int active = service.activeMissions.length;
                return _ProgressCard(
                  title: _t('Missions'),
                  completed: active,
                  total: active,
                  icon: Icons.rocket_launch,
                  color: const Color(0xFFF59E0B),
                  label: _t('active'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceLoopCard() {
    return Consumer<MissionService>(
      builder: (BuildContext context, MissionService service, _) {
        final _EvidenceLoopCopy loopCopy = _resolveEvidenceLoopCopy(service);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: _DashboardInfoCard(
              title: _t('My Evidence Loop'),
              body: <Widget>[
                _EvidenceLoopRow(
                  icon: Icons.handyman_rounded,
                  label: _t('What I am building'),
                  value: loopCopy.building,
                ),
                const SizedBox(height: 12),
                _EvidenceLoopRow(
                  icon: Icons.fact_check_rounded,
                  label: _t('What evidence I have shown'),
                  value: loopCopy.evidenceShown,
                ),
                const SizedBox(height: 12),
                _EvidenceLoopRow(
                  icon: Icons.track_changes_rounded,
                  label: _t('What capability I am growing'),
                  value: loopCopy.capability,
                ),
                const SizedBox(height: 12),
                _EvidenceLoopRow(
                  icon: Icons.record_voice_over_rounded,
                  label: _t('What I need to explain or verify next'),
                  value: loopCopy.nextVerify,
                ),
                const SizedBox(height: 12),
                _EvidenceLoopRow(
                  icon: Icons.collections_bookmark_rounded,
                  label: _t('What artifact belongs in my portfolio'),
                  value: loopCopy.portfolioArtifact,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  _EvidenceLoopCopy _resolveEvidenceLoopCopy(MissionService service) {
    final String emptyBuilding =
        _t('Choose a mission to start your next build sprint.');
    final String emptyCapability =
        _t('Your next capability focus appears when a mission is active.');
    final String emptyEvidence = _t(
        'Show your thinking through a checkpoint, share-out, or reflection.');
    final String emptyNextVerify =
        _t('Be ready to explain your next step in your own words.');
    final String emptyPortfolio = _t(
      'Your best artifact will appear here after you build something worth keeping.',
    );

    try {
      final List<Mission> activeMissions = service.activeMissions;
      final Mission? mission =
          activeMissions.isNotEmpty ? activeMissions.first : null;
      final String? profileGoal = _firstMeaningful(_learnerProfile?.goals);
      final String? profileStrength =
          _firstMeaningful(_learnerProfile?.strengths);
      final String? profileHighlight =
          _meaningful(_learnerProfile?.portfolioHighlight);
      final String? missionSkill = mission == null || mission.skills.isEmpty
          ? null
          : _meaningful(mission.skills.first.name);
      final String? missionPillar = mission?.pillar.label;
      final String? educatorFeedback = _meaningful(mission?.educatorFeedback);
      final String? reflectionPrompt = _meaningful(mission?.reflectionPrompt);

      return _EvidenceLoopCopy(
        building: _meaningful(mission?.title) ?? profileGoal ?? emptyBuilding,
        evidenceShown: educatorFeedback ??
            (mission != null &&
                    (mission.status == MissionStatus.submitted ||
                        mission.status == MissionStatus.completed)
                ? _t('Your mission work is ready for educator review.')
                : emptyEvidence),
        capability: missionSkill ??
            _meaningful(missionPillar) ??
            profileStrength ??
            emptyCapability,
        nextVerify: reflectionPrompt ?? emptyNextVerify,
        portfolioArtifact: profileHighlight ??
            (mission != null
                ? _t(
                    'Save the strongest draft, screenshot, photo, or demo from this mission.',
                  )
                : emptyPortfolio),
      );
    } catch (_) {
      return _EvidenceLoopCopy(
        building: emptyBuilding,
        evidenceShown: emptyEvidence,
        capability: emptyCapability,
        nextVerify: emptyNextVerify,
        portfolioArtifact: emptyPortfolio,
      );
    }
  }

  String? _firstMeaningful(List<String>? values) {
    if (values == null) {
      return null;
    }
    for (final String value in values) {
      final String? meaningfulValue = _meaningful(value);
      if (meaningfulValue != null) {
        return meaningfulValue;
      }
    }
    return null;
  }

  String? _meaningful(String? value) {
    final String trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _QuickActionCard(
              icon: Icons.trending_up,
              label: _t('Habits'),
              color: const Color(0xFF8B5CF6),
              onTap: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: const <String, dynamic>{
                    'cta': 'learner_today_open_habits'
                  },
                );
                context.push('/learner/habits');
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActionCard(
              icon: Icons.rocket_launch,
              label: _t('Missions'),
              color: const Color(0xFFF59E0B),
              onTap: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: const <String, dynamic>{
                    'cta': 'learner_today_open_missions'
                  },
                );
                context.push('/learner/missions');
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActionCard(
              icon: Icons.message,
              label: _t('Messages'),
              color: const Color(0xFF6366F1),
              onTap: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: const <String, dynamic>{
                    'cta': 'learner_today_open_messages_quick_action'
                  },
                );
                context.push('/messages');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayHabits() {
    return Consumer<HabitService>(
      builder: (BuildContext context, HabitService service, _) {
        final List<Habit> habits = service.todayHabits.take(3).toList();
        if (service.error != null && habits.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: _DashboardInfoCard(
              title: _t("Today's Habits"),
              body: <Widget>[
                Text(
                  _t('Unable to load habits'),
                  style: TextStyle(
                    color: context.schTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  service.error!,
                  style: TextStyle(
                    color: context.schTextSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }

        if (habits.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: _DashboardInfoCard(
              title: _t("Today's Habits"),
              body: <Widget>[
                Text(
                  _t('No habits scheduled yet'),
                  style: TextStyle(color: context.schTextPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  _t('Set up a habit to start your daily streak.'),
                  style:
                      TextStyle(color: context.schTextSecondary, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (service.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SectionHealthBanner(
                    message:
                        _t('Showing last loaded habits. ') + service.error!,
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _t("Today's Habits"),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: const <String, dynamic>{
                          'cta': 'learner_today_see_all_habits'
                        },
                      );
                      context.push('/learner/habits');
                    },
                    child: Text(
                      _t('See all'),
                      style: TextStyle(color: ScholesaColors.learner),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...habits.map((Habit habit) => _HabitTile(habit: habit)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveMissions() {
    return Consumer<MissionService>(
      builder: (BuildContext context, MissionService service, _) {
        final List<Mission> missions = service.activeMissions.take(2).toList();
        if (service.error != null && missions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _DashboardInfoCard(
              title: _t('Active Missions'),
              body: <Widget>[
                Text(
                  _t('Unable to load missions'),
                  style: TextStyle(
                    color: context.schTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  service.error!,
                  style: TextStyle(
                    color: context.schTextSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }

        if (missions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _DashboardInfoCard(
              title: _t('Active Missions'),
              body: <Widget>[
                Text(
                  _t('No active missions yet'),
                  style: TextStyle(color: context.schTextPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  _t('Start a mission to build real learning evidence today.'),
                  style:
                      TextStyle(color: context.schTextSecondary, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (service.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SectionHealthBanner(
                    message: _t('Showing last loaded mission progress. ') +
                        service.error!,
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _t('Active Missions'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: const <String, dynamic>{
                          'cta': 'learner_today_see_all_missions'
                        },
                      );
                      context.push('/learner/missions');
                    },
                    child: Text(
                      _t('See all'),
                      style: TextStyle(color: ScholesaColors.learner),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...missions
                  .map((Mission mission) => _MissionTile(mission: mission)),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadLearnerProfile({
    bool openSetupAfterLoad = false,
  }) async {
    final AppState appState = context.read<AppState>();
    final String learnerId = appState.userId?.trim() ?? '';
    final String siteId = _activeSiteId(appState);
    if (learnerId.isEmpty || siteId.isEmpty) {
      if (mounted) {
        setState(() {
          _learnerProfile = null;
          _isProfileLoading = false;
        });
      }
      return;
    }

    final FirebaseFirestore firestore =
        context.read<FirestoreService>().firestore;
    final LearnerProfileRepository repository =
        LearnerProfileRepository(firestore: firestore);

    if (mounted) {
      setState(() => _isProfileLoading = true);
    }

    try {
      final LearnerProfileModel? profile = await repository.getByLearnerAndSite(
        learnerId: learnerId,
        siteId: siteId,
      );
      if (!mounted) return;
      setState(() {
        _learnerProfile = profile;
        _isProfileLoading = false;
      });
      if (openSetupAfterLoad &&
          !(profile?.onboardingCompleted ?? false) &&
          !_didAutoOpenForcedSetup) {
        _didAutoOpenForcedSetup = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            unawaited(_openLearnerSetupSheet());
          }
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Learner setup profile load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      unawaited(TelemetryService.instance.logEvent(
        event: 'onboarding.check_failed',
        role: 'learner',
        siteId: siteId,
        metadata: <String, dynamic>{
          'surface': widget.forceSetupMode
              ? 'learner_onboarding_route'
              : 'learner_today_setup',
          'stage': 'profile_load',
          'errorType': error.runtimeType.toString(),
        },
      ));
      if (!mounted) return;
      setState(() => _isProfileLoading = false);
    }
  }

  Future<void> _speakLearnerSetupStep(
    String text, {
    required String stepId,
  }) async {
    final Locale locale = Localizations.localeOf(context);
    final String siteId = _activeSiteId(context.read<AppState>());
    try {
      await MiloVoicePersona.configure(
        _setupMiloTts,
        locale: locale,
      );
      await _setupMiloTts.stop();
      await _setupMiloTts.speak(text);
      await TelemetryService.instance.logEvent(
        event: 'voice.tts',
        role: 'learner',
        siteId: siteId,
        metadata: <String, dynamic>{
          'source': 'learner_setup_miloos',
          'surface': 'learner_onboarding',
          'stepId': stepId,
          'chars': text.length,
        },
      );
    } catch (error, stackTrace) {
      debugPrint('Learner setup MiloOS speech failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      unawaited(TelemetryService.instance.logEvent(
        event: 'voice.tts',
        role: 'learner',
        siteId: siteId,
        metadata: <String, dynamic>{
          'source': 'learner_setup_miloos_failed',
          'surface': 'learner_onboarding',
          'stepId': stepId,
          'errorType': error.runtimeType.toString(),
        },
      ));
    }
  }

  String _activeSiteId(AppState appState) {
    final String activeSiteId = appState.activeSiteId?.trim() ?? '';
    if (activeSiteId.isNotEmpty) return activeSiteId;
    if (appState.siteIds.isNotEmpty) {
      return appState.siteIds.first.trim();
    }
    return '';
  }

  bool get _setupComplete => _learnerProfile?.onboardingCompleted ?? false;

  Widget _buildLearnerSetupCard() {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<_SummaryChipData> chips = <_SummaryChipData>[
      _SummaryChipData(
        label: _setupComplete ? _t('Setup complete') : _t('Setup needed'),
        color: _setupComplete ? ScholesaColors.success : ScholesaColors.warning,
      ),
      if ((_learnerProfile?.goals.length ?? 0) > 0)
        _SummaryChipData(
          label: '${_t('Goals')}: ${_learnerProfile!.goals.length}',
          color: ScholesaColors.learner,
        ),
      if ((_learnerProfile?.interests.length ?? 0) > 0)
        _SummaryChipData(
          label: '${_t('Interests')}: ${_learnerProfile!.interests.length}',
          color: const Color(0xFF0EA5E9),
        ),
      if ((_learnerProfile?.weeklyTargetMinutes ?? 0) > 0)
        _SummaryChipData(
          label:
              '${_t('Weekly target minutes')}: ${_learnerProfile!.weeklyTargetMinutes}',
          color: const Color(0xFFF59E0B),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.18)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ScholesaColors.learner.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: ScholesaColors.learner,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _t('Learner Setup'),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _t(
                          'Complete your setup to personalize goals, reminders, and accessibility supports.',
                        ),
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isProfileLoading)
              const LinearProgressIndicator(minHeight: 4)
            else if (chips.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: chips
                    .map(
                      (_SummaryChipData chip) =>
                          _SummaryChip(label: chip.label, color: chip.color),
                    )
                    .toList(),
              ),
            const SizedBox(height: 16),
            if (!_setupComplete && widget.forceSetupMode)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _t('You will unlock the learner dashboard after this setup is saved.'),
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final List<Widget> actions = <Widget>[
                  OutlinedButton.icon(
                    onPressed: () => _openQuickReflectionSheet(),
                    icon: const Icon(Icons.rate_review_outlined),
                    label: Text(_t('Quick reflection')),
                  ),
                  ElevatedButton.icon(
                    onPressed: _openLearnerSetupSheet,
                    icon: const Icon(Icons.auto_awesome_mosaic),
                    label: Text(
                      _setupComplete
                          ? _t('Update setup')
                          : _t('Complete setup'),
                    ),
                  ),
                ];
                if (constraints.maxWidth < 520) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      actions[0],
                      const SizedBox(height: 10),
                      actions[1],
                    ],
                  );
                }
                return Row(
                  children: <Widget>[
                    Expanded(child: actions[0]),
                    const SizedBox(width: 12),
                    Expanded(child: actions[1]),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMotivationLoopCard({
    bool isOnboardingSurface = false,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final LearnerProfileModel? profile = _learnerProfile;
    final String valuePrompt = profile?.valuePrompt?.trim() ?? '';
    final List<String> summaryChips = <String>[
      if ((profile?.weeklyTargetMinutes ?? 0) > 0)
        '${_t('Weekly target minutes')}: ${profile!.weeklyTargetMinutes}',
      '${_t('Reminder')}: ${_reminderScheduleLabel(profile?.reminderSchedule)}',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.loop_rounded,
                    color: Color(0xFF0EA5E9),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _t('Motivation loop'),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isOnboardingSurface
                            ? _t(
                                'Start with a plan, reflect after each session, and save a weekly review rhythm.')
                            : _t(
                                'Keep a simple plan-reflect-review rhythm tied to your goals and reminders.'),
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (valuePrompt.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ScholesaColors.learner.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '"$valuePrompt"',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: summaryChips
                  .map(
                    (String label) => _SummaryChip(
                      label: label,
                      color: const Color(0xFF0EA5E9),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            Consumer2<HabitService, MissionService>(
              builder: (
                BuildContext context,
                HabitService habitService,
                MissionService missionService,
                _,
              ) {
                final String shoutOutMessage = _motivationShoutOutMessage(
                  totalStreak: habitService.totalStreak,
                  activeMissionCount: missionService.activeMissions.length,
                  weeklyTargetMinutes: profile?.weeklyTargetMinutes ?? 0,
                );
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _t('Shout-out'),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        shoutOutMessage,
                        style: TextStyle(
                          color: scheme.onSurface,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ElevatedButton.icon(
                          onPressed: () => _saveMotivationShoutOut(
                            shoutOutMessage,
                          ),
                          icon: const Icon(Icons.celebration_outlined),
                          label: Text(_t('Save shout-out')),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () => _openQuickReflectionSheet(
                    initialReflectionType: 'pre_plan',
                  ),
                  icon: const Icon(Icons.flag_rounded),
                  label: Text(_t('Pre-plan reflection')),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openQuickReflectionSheet(
                    initialReflectionType: 'post_session',
                  ),
                  icon: const Icon(Icons.rate_review_outlined),
                  label: Text(_t('Post-session reflection')),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openQuickReflectionSheet(
                    initialReflectionType: 'weekly_review',
                  ),
                  icon: const Icon(Icons.event_note_rounded),
                  label: Text(_t('Weekly review reflection')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _motivationShoutOutMessage({
    required int totalStreak,
    required int activeMissionCount,
    required int weeklyTargetMinutes,
  }) {
    if (totalStreak >= 3) {
      return _t(
          'You kept showing up for your goals. That consistency matters.');
    }
    if (activeMissionCount > 0) {
      return _t(
          'You are carrying active missions forward. That momentum counts.');
    }
    if (weeklyTargetMinutes > 0) {
      return _t('You set a clear goal for your week. That is real progress.');
    }
    return _t('You checked in and kept your learning moving today.');
  }

  Future<void> _openLearnerSetupSheet() async {
    final AppState appState = context.read<AppState>();
    final String learnerId = appState.userId?.trim() ?? '';
    final String siteId = _activeSiteId(appState);
    if (learnerId.isEmpty || siteId.isEmpty) return;

    if (!_setupComplete && !_didLogOnboardingStart) {
      _didLogOnboardingStart = true;
      unawaited(TelemetryService.instance.logEvent(
        event: 'onboarding.started',
        role: 'learner',
        siteId: siteId,
        metadata: <String, dynamic>{
          'surface': widget.forceSetupMode
              ? 'learner_onboarding_route'
              : 'learner_today_setup',
        },
      ));
    }

    final LearnerProfileModel? currentProfile = _learnerProfile;
    final TextEditingController interestsController =
        TextEditingController(text: currentProfile?.interests.join(', ') ?? '');
    final TextEditingController goalsController =
        TextEditingController(text: currentProfile?.goals.join(', ') ?? '');
    final TextEditingController valuePromptController =
        TextEditingController(text: currentProfile?.valuePrompt ?? '');

    String readingLevel = currentProfile?.readingLevelSelfCheck ?? 'just_right';
    String? diagnosticBand = currentProfile?.diagnosticConfidenceBand;
    double weeklyTargetMinutes =
        (currentProfile?.weeklyTargetMinutes ?? 90).toDouble();
    String reminderSchedule = currentProfile?.reminderSchedule ?? 'weekdays';
    bool ttsEnabled = currentProfile?.ttsEnabled ?? false;
    bool reducedDistractionEnabled =
        currentProfile?.reducedDistractionEnabled ?? false;
    bool keyboardOnlyEnabled = currentProfile?.keyboardOnlyEnabled ?? false;
    bool highContrastEnabled = currentProfile?.highContrastEnabled ?? false;
    bool miloReadsSetup = !_setupComplete || ttsEnabled;
    bool didSpeakSetupIntro = false;
    int setupStepIndex = 0;
    bool isSaving = false;

    final List<String> selectedSupports =
        List<String>.from(currentProfile?.learningNeeds ?? const <String>[]);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext bottomSheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalSetState) {
            final List<_LearnerSetupStepData> setupSteps =
                <_LearnerSetupStepData>[
              _LearnerSetupStepData(
                id: 'reading',
                title: _t('Step 1: Reading comfort'),
                helper: _t('Pick the choice that feels most true today.'),
                speech: _t(
                    'Hi, I am MiloOS. We will do this one small step at a time. First, tell me how reading feels today.'),
                content: DropdownButtonFormField<String>(
                  initialValue: readingLevel,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: _t('Reading check')),
                  items: <DropdownMenuItem<String>>[
                    DropdownMenuItem(
                        value: 'need_support',
                        child: Text(_t('Need support'))),
                    DropdownMenuItem(
                        value: 'just_right', child: Text(_t('Just right'))),
                    DropdownMenuItem(
                        value: 'challenge_me',
                        child: Text(_t('Ready for a challenge'))),
                  ],
                  onChanged: isSaving
                      ? null
                      : (String? value) {
                          if (value == null) return;
                          modalSetState(() => readingLevel = value);
                        },
                ),
              ),
              _LearnerSetupStepData(
                id: 'confidence',
                title: _t('Step 2: Confidence'),
                helper: _t('It is okay to leave this blank if you are not sure.'),
                speech: _t(
                    'Now choose how confident you feel. There is no bad answer. This only helps us support you.'),
                content: DropdownButtonFormField<String>(
                  initialValue: diagnosticBand,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: _t('Mastery confidence'),
                    helperText: _t('Leave blank until you know'),
                  ),
                  items: <DropdownMenuItem<String>>[
                    DropdownMenuItem(
                        value: 'emerging', child: Text(_t('Emerging'))),
                    DropdownMenuItem(
                        value: 'developing', child: Text(_t('Developing'))),
                    DropdownMenuItem(
                        value: 'confident', child: Text(_t('Confident'))),
                  ],
                  onChanged: isSaving
                      ? null
                      : (String? value) {
                          modalSetState(() => diagnosticBand = value);
                        },
                ),
              ),
              _LearnerSetupStepData(
                id: 'interests_goals',
                title: _t('Step 3: What you like'),
                helper: _t('Write a few interests and goals. Short words are fine.'),
                speech: _t(
                    'Next, tell me what you like and what you want to get better at. You can use simple words.'),
                content: Column(
                  children: <Widget>[
                    TextField(
                      controller: interestsController,
                      decoration: InputDecoration(
                        labelText: _t('Interests'),
                        helperText: _t('Comma separated'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: goalsController,
                      decoration: InputDecoration(
                        labelText: _t('Goals'),
                        helperText: _t('Comma separated'),
                      ),
                    ),
                  ],
                ),
              ),
              _LearnerSetupStepData(
                id: 'rhythm',
                title: _t('Step 4: Your rhythm'),
                helper: _t('Choose a small weekly goal and reminder plan.'),
                speech: _t(
                    'Now let us make a simple plan. Pick a weekly time goal and when reminders should help you.'),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${_t('Weekly target minutes')}: ${weeklyTargetMinutes.round()}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Slider(
                      value: weeklyTargetMinutes,
                      min: 30,
                      max: 240,
                      divisions: 7,
                      label: weeklyTargetMinutes.round().toString(),
                      onChanged: isSaving
                          ? null
                          : (double value) {
                              modalSetState(() => weeklyTargetMinutes = value);
                            },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: reminderSchedule,
                      isExpanded: true,
                      decoration:
                          InputDecoration(labelText: _t('Reminder schedule')),
                      items: <DropdownMenuItem<String>>[
                        DropdownMenuItem(value: 'off', child: Text(_t('Off'))),
                        DropdownMenuItem(
                            value: 'daily', child: Text(_t('Daily'))),
                        DropdownMenuItem(
                            value: 'weekdays', child: Text(_t('Weekdays'))),
                        DropdownMenuItem(
                            value: 'weekends', child: Text(_t('Weekends'))),
                      ],
                      onChanged: isSaving
                          ? null
                          : (String? value) {
                              if (value == null) return;
                              modalSetState(() => reminderSchedule = value);
                            },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: valuePromptController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: _t('Why does this matter to you?'),
                      ),
                    ),
                  ],
                ),
              ),
              _LearnerSetupStepData(
                id: 'accessibility',
                title: _t('Step 5: Helpful tools'),
                helper: _t('Turn on any tools that make Scholesa easier to use.'),
                speech: _t(
                    'Last step. Pick any tools that help you focus, read, or use the keyboard.'),
                content: Column(
                  children: <Widget>[
                    CheckboxListTile(
                      value: ttsEnabled,
                      onChanged: isSaving
                          ? null
                          : (bool? value) {
                              modalSetState(() {
                                ttsEnabled = value ?? false;
                                miloReadsSetup = ttsEnabled || !_setupComplete;
                              });
                            },
                      title: Text(_t('Text-to-Speech')),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      value: reducedDistractionEnabled,
                      onChanged: isSaving
                          ? null
                          : (bool? value) {
                              modalSetState(() =>
                                  reducedDistractionEnabled = value ?? false);
                            },
                      title: Text(_t('Reduced distraction')),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      value: keyboardOnlyEnabled,
                      onChanged: isSaving
                          ? null
                          : (bool? value) {
                              modalSetState(
                                  () => keyboardOnlyEnabled = value ?? false);
                            },
                      title: Text(_t('Keyboard only')),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      value: highContrastEnabled,
                      onChanged: isSaving
                          ? null
                          : (bool? value) {
                              modalSetState(
                                  () => highContrastEnabled = value ?? false);
                            },
                      title: Text(_t('High contrast')),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ];

            final _LearnerSetupStepData currentStep = setupSteps[setupStepIndex];

            void logAndSpeakStep(int index) {
              final _LearnerSetupStepData step = setupSteps[index];
              unawaited(TelemetryService.instance.logEvent(
                event: 'onboarding.step.viewed',
                role: 'learner',
                siteId: siteId,
                metadata: <String, dynamic>{
                  'surface': widget.forceSetupMode
                      ? 'learner_onboarding_route'
                      : 'learner_today_setup',
                  'stepId': step.id,
                  'stepIndex': index + 1,
                  'stepCount': setupSteps.length,
                },
              ));
              if (miloReadsSetup) {
                unawaited(_speakLearnerSetupStep(
                  step.speech,
                  stepId: step.id,
                ));
              }
            }

            if (!didSpeakSetupIntro) {
              didSpeakSetupIntro = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  logAndSpeakStep(setupStepIndex);
                }
              });
            }

            return SizedBox(
              height: MediaQuery.sizeOf(bottomSheetContext).height * 0.9,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom:
                      MediaQuery.of(bottomSheetContext).viewInsets.bottom + 16,
                ),
                child: SafeArea(
                  child: SingleChildScrollView(
                    child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _t('Learner Setup'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _t('MiloOS will guide you one step at a time. You can keep answers short.'),
                        style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ScholesaColors.learner.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: ScholesaColors.learner.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                const Icon(Icons.record_voice_over_rounded,
                                    color: ScholesaColors.learner),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _t('MiloOS setup guide'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ),
                                Switch(
                                  value: miloReadsSetup,
                                  onChanged: isSaving
                                      ? null
                                      : (bool value) {
                                          modalSetState(
                                              () => miloReadsSetup = value);
                                        },
                                ),
                              ],
                            ),
                            Text(
                              currentStep.speech,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: isSaving
                                  ? null
                                  : () => _speakLearnerSetupStep(
                                        currentStep.speech,
                                        stepId: currentStep.id,
                                      ),
                              icon: const Icon(Icons.volume_up_rounded),
                              label: Text(_t('Read this step')),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${_t('Step')} ${setupStepIndex + 1} ${_t('of')} ${setupSteps.length}',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: ScholesaColors.learner,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Container(
                          key: ValueKey<String>(currentStep.id),
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                currentStep.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                currentStep.helper,
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 14),
                              currentStep.content,
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: <Widget>[
                          if (setupStepIndex > 0) ...<Widget>[
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: isSaving
                                    ? null
                                    : () {
                                        modalSetState(
                                            () => setupStepIndex -= 1);
                                        logAndSpeakStep(setupStepIndex);
                                      },
                                icon: const Icon(Icons.arrow_back_rounded),
                                label: Text(_t('Back')),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: setupStepIndex < setupSteps.length - 1
                                ? ElevatedButton.icon(
                                    onPressed: isSaving
                                        ? null
                                        : () {
                                            modalSetState(
                                                () => setupStepIndex += 1);
                                            logAndSpeakStep(setupStepIndex);
                                          },
                                    icon:
                                        const Icon(Icons.arrow_forward_rounded),
                                    label: Text(_t('Next')),
                                  )
                                : ElevatedButton.icon(
                                    icon: isSaving
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.check_rounded),
                                    label: Text(_t('Finish setup')),
                                    onPressed: isSaving
                                  ? null
                                  : () async {
                                      modalSetState(() => isSaving = true);
                                      final LearnerProfileModel updatedProfile =
                                          LearnerProfileModel(
                                        id: currentProfile?.id ??
                                            '${siteId}_$learnerId',
                                        learnerId: learnerId,
                                        siteId: siteId,
                                        legalName: currentProfile?.legalName,
                                        preferredName:
                                            currentProfile?.preferredName,
                                        dateOfBirth:
                                            currentProfile?.dateOfBirth,
                                        gradeLevel: currentProfile?.gradeLevel,
                                        strengths: currentProfile?.strengths ??
                                            const <String>[],
                                        learningNeeds: selectedSupports,
                                        interests:
                                            _splitCsv(interestsController.text),
                                        goals: _splitCsv(goalsController.text),
                                        readingLevelSelfCheck: readingLevel,
                                        diagnosticConfidenceBand:
                                            diagnosticBand,
                                        weeklyTargetMinutes:
                                            weeklyTargetMinutes.round(),
                                        reminderSchedule: reminderSchedule,
                                        valuePrompt:
                                            valuePromptController.text.trim(),
                                        ttsEnabled: ttsEnabled,
                                        reducedDistractionEnabled:
                                            reducedDistractionEnabled,
                                        keyboardOnlyEnabled:
                                            keyboardOnlyEnabled,
                                        highContrastEnabled:
                                            highContrastEnabled,
                                        onboardingCompleted: true,
                                        lastSetupAt: Timestamp.now(),
                                        emergencyContact:
                                            currentProfile?.emergencyContact,
                                        createdAt: currentProfile?.createdAt,
                                        updatedAt: Timestamp.now(),
                                      );

                                      final NavigatorState sheetNavigator =
                                          Navigator.of(bottomSheetContext);
                                      final ScaffoldMessengerState messenger =
                                          ScaffoldMessenger.of(context);
                                      final GoRouter router =
                                          GoRouter.of(context);
                                      final FirebaseFirestore firestore =
                                          context
                                              .read<FirestoreService>()
                                              .firestore;
                                      final LearnerProfileRepository
                                          repository = LearnerProfileRepository(
                                              firestore: firestore);

                                      try {
                                        await repository.upsert(updatedProfile);
                                        await NotificationService.instance
                                            .syncLearnerReminderPreference(
                                          siteId: siteId,
                                          schedule: reminderSchedule,
                                          weeklyTargetMinutes:
                                              weeklyTargetMinutes.round(),
                                          localeCode:
                                              appState.preferredLocaleCode,
                                          timeZone: appState.timeZone,
                                          valuePrompt:
                                              valuePromptController.text.trim(),
                                        );
                                        await _logLearnerSetupEvents(
                                          previous: currentProfile,
                                          current: updatedProfile,
                                          siteId: siteId,
                                        );
                                        if (!mounted) return;
                                        setState(() =>
                                            _learnerProfile = updatedProfile);
                                        sheetNavigator.pop();
                                        messenger.showSnackBar(
                                          SnackBar(
                                              content: Text(_t('Setup saved'))),
                                        );
                                        if (widget.forceSetupMode) {
                                          router.go('/learner/today');
                                        }
                                      } catch (error, stackTrace) {
                                        debugPrint(
                                            'Learner setup save failed: $error');
                                        debugPrintStack(stackTrace: stackTrace);
                                        await TelemetryService.instance.logEvent(
                                          event: 'onboarding.save_failed',
                                          role: 'learner',
                                          siteId: siteId,
                                          metadata: <String, dynamic>{
                                            'surface': widget.forceSetupMode
                                                ? 'learner_onboarding_route'
                                                : 'learner_today_setup',
                                            'errorType':
                                                error.runtimeType.toString(),
                                            'stepId': currentStep.id,
                                          },
                                        );
                                        if (!mounted) return;
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(_t(
                                                'Setup could not be saved right now. Please try again.')),
                                          ),
                                        );
                                      } finally {
                                        if (bottomSheetContext.mounted) {
                                          modalSetState(() => isSaving = false);
                                        }
                                      }
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _reminderScheduleLabel(String? schedule) {
    switch (schedule) {
      case 'daily':
        return _t('Daily');
      case 'weekdays':
        return _t('Weekdays');
      case 'weekends':
        return _t('Weekends');
      case 'off':
      default:
        return _t('Off');
    }
  }

  List<String> _splitCsv(String input) {
    return input
        .split(',')
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toSet()
        .take(6)
        .toList();
  }

  Future<void> _logLearnerSetupEvents({
    required LearnerProfileModel? previous,
    required LearnerProfileModel current,
    required String siteId,
  }) async {
    if (previous == null || !previous.onboardingCompleted) {
      await TelemetryService.instance.logEvent(
        event: 'onboarding.completed',
        role: 'learner',
        siteId: siteId,
        metadata: <String, dynamic>{
          'interestCount': current.interests.length,
          'goalCount': current.goals.length,
          'readingLevel': current.readingLevelSelfCheck,
        },
      );
    }

    if (previous?.diagnosticConfidenceBand !=
        current.diagnosticConfidenceBand) {
      await TelemetryService.instance.logEvent(
        event: 'diagnostic.submitted',
        role: 'learner',
        siteId: siteId,
        metadata: <String, dynamic>{
          'readingLevel': current.readingLevelSelfCheck,
          if (current.diagnosticConfidenceBand != null)
            'confidenceBand': current.diagnosticConfidenceBand,
        },
      );
    }

    if (previous?.weeklyTargetMinutes != current.weeklyTargetMinutes ||
        previous?.reminderSchedule != current.reminderSchedule ||
        previous?.goals.join('|') != current.goals.join('|') ||
        previous?.valuePrompt != current.valuePrompt) {
      await TelemetryService.instance.logEvent(
        event: 'learner.goal.updated',
        role: 'learner',
        siteId: siteId,
        metadata: <String, dynamic>{
          'goalCount': current.goals.length,
          'weeklyTargetMinutes': current.weeklyTargetMinutes,
          'reminderSchedule': current.reminderSchedule,
          'hasValuePrompt': (current.valuePrompt?.isNotEmpty ?? false),
        },
      );
    }

    final Map<String, bool> previousSettings = <String, bool>{
      'ttsEnabled': previous?.ttsEnabled ?? false,
      'reducedDistractionEnabled': previous?.reducedDistractionEnabled ?? false,
      'keyboardOnlyEnabled': previous?.keyboardOnlyEnabled ?? false,
      'highContrastEnabled': previous?.highContrastEnabled ?? false,
    };
    final Map<String, bool> currentSettings = <String, bool>{
      'ttsEnabled': current.ttsEnabled,
      'reducedDistractionEnabled': current.reducedDistractionEnabled,
      'keyboardOnlyEnabled': current.keyboardOnlyEnabled,
      'highContrastEnabled': current.highContrastEnabled,
    };

    for (final MapEntry<String, bool> entry in currentSettings.entries) {
      if (previousSettings[entry.key] == entry.value) continue;
      await TelemetryService.instance.logEvent(
        event: 'accessibility.setting.changed',
        role: 'learner',
        siteId: siteId,
        metadata: <String, dynamic>{
          'settingKey': entry.key,
          'enabled': entry.value,
        },
      );
    }
  }

  String _promptForReflectionType(String reflectionType) {
    switch (reflectionType) {
      case 'shout_out':
        return _t('What win are you proud of today?');
      case 'pre_plan':
        return _t('What is your plan for this session?');
      case 'weekly_review':
        return _t(
            'What pattern do you notice from this week, and what will you adjust next?');
      case 'post_session':
      default:
        return _t('What worked? What is your next step?');
    }
  }

  Future<void> _saveMotivationShoutOut(String message) async {
    final AppState appState = context.read<AppState>();
    final String learnerId = appState.userId?.trim() ?? '';
    final String siteId = _activeSiteId(appState);
    if (learnerId.isEmpty || siteId.isEmpty) {
      return;
    }

    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      role: 'learner',
      siteId: siteId,
      metadata: const <String, dynamic>{
        'cta': 'learner_today_save_shout_out',
      },
    );

    final FirebaseFirestore firestore =
        context.read<FirestoreService>().firestore;
    final LearnerReflectionRepository repository =
        LearnerReflectionRepository(firestore: firestore);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    await repository.create(
      learnerId: learnerId,
      siteId: siteId,
      reflectionType: 'shout_out',
      response: message,
      prompt: _promptForReflectionType('shout_out'),
    );
    if (!mounted) {
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text(_t('Shout-out saved'))),
    );
  }

  Future<void> _openQuickReflectionSheet({
    String initialReflectionType = 'post_session',
  }) async {
    final AppState appState = context.read<AppState>();
    final String learnerId = appState.userId?.trim() ?? '';
    final String siteId = _activeSiteId(appState);
    if (learnerId.isEmpty || siteId.isEmpty) return;

    final TextEditingController reflectionController = TextEditingController();
    String reflectionType = initialReflectionType;
    bool isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext bottomSheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalSetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom:
                    MediaQuery.of(bottomSheetContext).viewInsets.bottom + 16,
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _t('Quick reflection'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: reflectionType,
                      decoration:
                          InputDecoration(labelText: _t('Reflection type')),
                      items: <DropdownMenuItem<String>>[
                        DropdownMenuItem(
                            value: 'pre_plan', child: Text(_t('Pre-plan'))),
                        DropdownMenuItem(
                            value: 'post_session',
                            child: Text(_t('Post-session'))),
                        DropdownMenuItem(
                            value: 'weekly_review',
                            child: Text(_t('Weekly review'))),
                      ],
                      onChanged: isSaving
                          ? null
                          : (String? value) {
                              if (value == null) return;
                              modalSetState(() => reflectionType = value);
                            },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reflectionController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: _t('What worked? What is your next step?'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSaving
                                ? null
                                : () => Navigator.pop(bottomSheetContext),
                            child: Text(_t('Cancel')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    final String response =
                                        reflectionController.text.trim();
                                    if (response.isEmpty) return;
                                    final NavigatorState sheetNavigator =
                                        Navigator.of(bottomSheetContext);
                                    final ScaffoldMessengerState messenger =
                                        ScaffoldMessenger.of(context);
                                    modalSetState(() => isSaving = true);
                                    final FirebaseFirestore firestore = context
                                        .read<FirestoreService>()
                                        .firestore;
                                    final LearnerReflectionRepository
                                        repository =
                                        LearnerReflectionRepository(
                                            firestore: firestore);
                                    try {
                                      await repository.create(
                                        learnerId: learnerId,
                                        siteId: siteId,
                                        reflectionType: reflectionType,
                                        response: response,
                                        prompt: _promptForReflectionType(
                                            reflectionType),
                                      );
                                      if (!mounted) return;
                                      sheetNavigator.pop();
                                      messenger.showSnackBar(
                                        SnackBar(
                                            content:
                                                Text(_t('Reflection saved'))),
                                      );
                                    } finally {
                                      if (bottomSheetContext.mounted) {
                                        modalSetState(() => isSaving = false);
                                      }
                                    }
                                  },
                            child: Text(_t('Save')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _getGreeting() {
    final int hour = DateTime.now().hour;
    if (hour < 12) return _t('Good morning');
    if (hour < 17) return _t('Good afternoon');
    return _t('Good evening');
  }

  Widget _buildAiCoachingSection(BuildContext context) {
    final AppState appState = context.read<AppState>();
    final UserRole? role = appState.role;

    if (role == null || role != UserRole.learner) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              color: ScholesaColors.learner.withValues(alpha: 0.1),
              border: Border.all(
                color: ScholesaColors.learner.withValues(alpha: 0.2),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Icon(
                Icons.smart_toy_rounded,
                color: ScholesaColors.learner,
              ),
              title: Text(_t('Daily Coaching')),
              subtitle: Text(_t('Get personalized guidance for today')),
              trailing: IconButton(
                icon: Icon(
                  _showAiCoach ? Icons.expand_less : Icons.expand_more,
                ),
                onPressed: () {
                  setState(() => _showAiCoach = !_showAiCoach);
                  TelemetryService.instance.logEvent(
                    event: 'cta.clicked',
                    metadata: <String, dynamic>{
                      'module': 'learner_today',
                      'cta': 'daily_ai_${_showAiCoach ? 'show' : 'hide'}',
                      'surface': 'today_dashboard',
                    },
                  );
                },
              ),
            ),
          ),
          if (_showAiCoach) _buildAiCoachPanel(context, role),
        ],
      ),
    );
  }

  Widget _buildAiCoachPanel(BuildContext context, UserRole role) {
    final LearningRuntimeProvider? runtime =
        context.read<LearningRuntimeProvider?>();
    if (runtime == null) {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        child: _DashboardInfoCard(
          title: _t('MiloOS is loading'),
          compactTitle: true,
          body: <Widget>[
            Text(
              _t('Runtime context is syncing. Try again in a moment.'),
              style: TextStyle(color: context.schTextSecondary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: ScholesaColors.learner.withValues(alpha: 0.05),
        border: Border.all(
          color: ScholesaColors.learner.withValues(alpha: 0.1),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      constraints: const BoxConstraints(minHeight: 350),
      child: AiCoachWidget(
        runtime: runtime,
        actorRole: role,
        conceptTags: <String>[
          'daily_planning',
          'today_goals',
          'motivation',
        ],
      ),
    );
  }

  Widget _buildLearnerLoopInsights(BuildContext context) {
    final AppState appState = context.read<AppState>();
    final String? learnerId = appState.userId;
    return BosLearnerLoopInsightsCard(
      title: BosCoachingI18n.learnerLoopTitle(context),
      subtitle: BosCoachingI18n.learnerLoopSubtitle(context),
      emptyLabel: BosCoachingI18n.learnerLoopEmpty(context),
      learnerId: learnerId,
      learnerName: appState.displayName,
      accentColor: ScholesaColors.learner,
    );
  }
}

class _SummaryChipData {
  const _SummaryChipData({required this.label, required this.color});

  final String label;
  final Color color;
}

class _LearnerSetupStepData {
  const _LearnerSetupStepData({
    required this.id,
    required this.title,
    required this.helper,
    required this.speech,
    required this.content,
  });

  final String id;
  final String title;
  final String helper;
  final String speech;
  final Widget content;
}

class _EvidenceLoopCopy {
  const _EvidenceLoopCopy({
    required this.building,
    required this.evidenceShown,
    required this.capability,
    required this.nextVerify,
    required this.portfolioArtifact,
  });

  final String building;
  final String evidenceShown;
  final String capability;
  final String nextVerify;
  final String portfolioArtifact;
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DashboardInfoCard extends StatelessWidget {
  const _DashboardInfoCard({
    required this.title,
    required this.body,
    this.compactTitle = false,
  });

  final String title;
  final List<Widget> body;
  final bool compactTitle;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.22)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              fontSize: compactTitle ? 17 : 19,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          ...body,
        ],
      ),
    );
  }
}

class _SectionHealthBanner extends StatelessWidget {
  const _SectionHealthBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF92400E)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.title,
    required this.completed,
    required this.total,
    required this.icon,
    required this.color,
    this.label,
  });
  final String title;
  final int completed;
  final int total;
  final IconData icon;
  final Color color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double progress = total > 0 ? completed / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.24)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Text(
                '$completed',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                '/$total',
                style: TextStyle(
                  fontSize: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  LearnerSurfaceI18n.text(context, label ?? 'done'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.22)),
      ),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.14),
      child: InkWell(
        onTap: () {
          TelemetryService.instance.logEvent(
            event: 'cta.clicked',
            metadata: <String, dynamic>{
              'cta': 'learner_today_quick_action',
              'label': label,
            },
          );
          onTap();
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          child: Column(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 0.1,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EvidenceLoopRow extends StatelessWidget {
  const _EvidenceLoopRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ScholesaColors.learner.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: ScholesaColors.learner),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: scheme.onSurface,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HabitTile extends StatelessWidget {
  const _HabitTile({required this.habit});
  final Habit habit;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: habit.isCompletedToday
              ? ScholesaColors.success.withValues(alpha: 0.3)
              : scheme.outlineVariant,
        ),
      ),
      child: Row(
        children: <Widget>[
          Text(habit.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  habit.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    decoration: habit.isCompletedToday
                        ? TextDecoration.lineThrough
                        : null,
                    color: habit.isCompletedToday
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                  ),
                ),
                Text(
                  '${habit.targetMinutes} min',
                  style: TextStyle(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
                      fontSize: 12),
                ),
              ],
            ),
          ),
          if (habit.isCompletedToday)
            const Icon(Icons.check_circle, color: ScholesaColors.success)
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: ScholesaColors.learner,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                LearnerSurfaceI18n.text(context, 'Start'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MissionTile extends StatelessWidget {
  const _MissionTile({required this.mission});
  final Mission mission;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(mission.pillar.emoji,
                  style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  mission.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: mission.progress,
                          backgroundColor:
                              const Color(0xFFF59E0B).withValues(alpha: 0.1),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFF59E0B)),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(mission.progress * 100).toInt()}%',
                      style: const TextStyle(
                        color: Color(0xFFB45309),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
