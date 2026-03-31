import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../../services/firestore_service.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';
import '../../ui/auth/global_session_menu.dart';
import '../../runtime/runtime.dart';
import '../../auth/app_state.dart';
import '../../i18n/learner_surface_i18n.dart';

String _tLearnerPortfolio(BuildContext context, String input) {
  return LearnerSurfaceI18n.text(context, input);
}

class LearnerPortfolioSnapshot {
  const LearnerPortfolioSnapshot({
    this.profile,
    this.items = const <PortfolioItemModel>[],
    this.credentials = const <CredentialModel>[],
  });

  final LearnerProfileModel? profile;
  final List<PortfolioItemModel> items;
  final List<CredentialModel> credentials;
}

/// Learner Portfolio Page - Achievements, badges, and skill showcase
class LearnerPortfolioPage extends StatefulWidget {
  const LearnerPortfolioPage({
    super.key,
    this.sharedPreferences,
    this.portfolioStateLoader,
  });

  final SharedPreferences? sharedPreferences;
  final Future<LearnerPortfolioSnapshot> Function(
      String learnerId, String siteId)? portfolioStateLoader;

  @override
  State<LearnerPortfolioPage> createState() => _LearnerPortfolioPageState();
}

class _LearnerPortfolioPageState extends State<LearnerPortfolioPage>
    with SingleTickerProviderStateMixin {
  static const List<String> _portfolioTabs = <String>[
    'badges',
    'skills',
    'projects',
  ];

  late TabController _tabController;
  SharedPreferences? _prefsCache;
  bool _showAiCoach = false;
  LearnerProfileModel? _learnerProfile;
  List<PortfolioItemModel> _portfolioItems = const <PortfolioItemModel>[];
  Map<String, CapabilityGrowthEventModel> _growthEventsById =
      const <String, CapabilityGrowthEventModel>{};
  List<CredentialModel> _credentials = const <CredentialModel>[];
  bool _isPortfolioLoading = true;
  String? _portfolioLoadError;

  String _t(String input) => _tLearnerPortfolio(context, input);

  String _learnerName(AppState appState) {
    final String displayName = appState.displayName?.trim() ?? '';
    if (displayName.isNotEmpty) return displayName;
    final String email = appState.email?.trim() ?? '';
    if (email.isNotEmpty) return email;
    return _t('Learner');
  }

  String _siteLabel(AppState appState) {
    final String siteId = appState.activeSiteId?.trim() ?? '';
    if (siteId.isEmpty) {
      return _t('Site unavailable');
    }
    return siteId;
  }

  String _effectiveHeadline(AppState appState) {
    final String headline = _learnerProfile?.portfolioHeadline?.trim() ?? '';
    if (headline.isNotEmpty) return headline;
    return '${_t('Future Innovator')} • ${_siteLabel(appState)}';
  }

  String _effectiveGoal() {
    final String goal = _learnerProfile?.portfolioGoal?.trim() ?? '';
    if (goal.isNotEmpty) return goal;
    return _t(
        'Build a confident weekly shipping rhythm across Future Skills missions.');
  }

  String _effectiveHighlight() {
    final String highlight = _learnerProfile?.portfolioHighlight?.trim() ?? '';
    if (highlight.isNotEmpty) return highlight;
    return _t('Latest highlight: Team Presentation');
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        return;
      }
      final String tab = switch (_tabController.index) {
        0 => 'badges',
        1 => 'skills',
        2 => 'projects',
        _ => 'unknown',
      };
      _persistSelectedTab(tab);
      TelemetryService.instance.logEvent(
        event: 'cta.clicked',
        metadata: <String, dynamic>{
          'module': 'learner_portfolio',
          'cta_id': 'change_tab',
          'surface': 'tab_bar',
          'tab': tab,
        },
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _restoreSavedViewState();
      if (!mounted) return;
      unawaited(_loadPortfolioState());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  FirestoreService? _maybeFirestoreService() {
    try {
      return context.read<FirestoreService>();
    } catch (_) {
      return null;
    }
  }

  Future<SharedPreferences> _prefs() async {
    final SharedPreferences? injected = widget.sharedPreferences;
    if (injected != null) {
      return injected;
    }
    return _prefsCache ??= await SharedPreferences.getInstance();
  }

  String _viewPrefsScope(AppState appState) {
    final String learnerKey = appState.userId?.trim().isNotEmpty == true
        ? appState.userId!.trim()
        : 'anonymous';
    final String siteKey = _activeSiteId(appState).trim().isNotEmpty
        ? _activeSiteId(appState).trim()
        : 'no-site';
    return '$learnerKey.$siteKey';
  }

  String _showAiCoachPrefsKey(AppState appState) {
    return 'learner_portfolio.show_ai_coach.${_viewPrefsScope(appState)}';
  }

  String _selectedTabPrefsKey(AppState appState) {
    return 'learner_portfolio.selected_tab.${_viewPrefsScope(appState)}';
  }

  String _normalizePortfolioTab(String? value) {
    if (value == null) {
      return _portfolioTabs.first;
    }
    final String normalized =
        value.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
    if (_portfolioTabs.contains(normalized)) {
      return normalized;
    }
    return _portfolioTabs.first;
  }

  int _tabIndexForName(String value) {
    final int index = _portfolioTabs.indexOf(_normalizePortfolioTab(value));
    return index >= 0 ? index : 0;
  }

  Future<void> _restoreSavedViewState() async {
    final AppState appState = context.read<AppState>();
    final SharedPreferences prefs = await _prefs();
    final bool restoredAiCoach =
        prefs.getBool(_showAiCoachPrefsKey(appState)) ?? false;
    final int restoredTabIndex = _tabIndexForName(
      prefs.getString(_selectedTabPrefsKey(appState)) ?? _portfolioTabs.first,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _showAiCoach = restoredAiCoach;
      _tabController.index = restoredTabIndex;
    });
  }

  Future<void> _persistSelectedTab(String value) async {
    final AppState appState = context.read<AppState>();
    final SharedPreferences prefs = await _prefs();
    await prefs.setString(
      _selectedTabPrefsKey(appState),
      _normalizePortfolioTab(value),
    );
  }

  Future<void> _setShowAiCoach(bool value) async {
    final AppState appState = context.read<AppState>();
    final SharedPreferences prefs = await _prefs();
    await prefs.setBool(_showAiCoachPrefsKey(appState), value);
    if (!mounted) {
      return;
    }
    setState(() => _showAiCoach = value);
  }

  String _activeSiteId(AppState appState) {
    final String activeSiteId = appState.activeSiteId?.trim() ?? '';
    if (activeSiteId.isNotEmpty) return activeSiteId;
    if (appState.siteIds.isNotEmpty) {
      return appState.siteIds.first.trim();
    }
    return '';
  }

  Future<void> _loadPortfolioState() async {
    final AppState appState = context.read<AppState>();
    final FirestoreService? firestoreService = _maybeFirestoreService();
    final String learnerId = appState.userId?.trim() ?? '';
    final String siteId = _activeSiteId(appState);
    final bool hadVisibleData = _hasVisiblePortfolioData;

    if (firestoreService == null || learnerId.isEmpty || siteId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _portfolioLoadError = _t('Portfolio data unavailable right now.');
        _isPortfolioLoading = false;
      });
      return;
    }

    setState(() {
      _isPortfolioLoading = true;
      _portfolioLoadError = null;
    });
    final FirebaseFirestore firestore = firestoreService.firestore;

    try {
      final LearnerPortfolioSnapshot snapshot =
          await (widget.portfolioStateLoader != null
              ? widget.portfolioStateLoader!(learnerId, siteId)
              : _loadPortfolioSnapshot(
                  firestore: firestore,
                  learnerId: learnerId,
                  siteId: siteId,
                ));
      final LearnerProfileModel? profile = snapshot.profile;
      final List<PortfolioItemModel> items = snapshot.items
          .where((PortfolioItemModel item) => item.siteId.trim() == siteId)
          .toList(growable: false)
        ..sort((PortfolioItemModel a, PortfolioItemModel b) {
          final int aMillis =
              (a.updatedAt ?? a.createdAt)?.millisecondsSinceEpoch ?? 0;
          final int bMillis =
              (b.updatedAt ?? b.createdAt)?.millisecondsSinceEpoch ?? 0;
          return bMillis.compareTo(aMillis);
        });
      final List<CredentialModel> credentials =
          snapshot.credentials.toList(growable: false);
      final Map<String, CapabilityGrowthEventModel> growthEventsById =
          await _loadGrowthEventsById(
        firestore: firestore,
        siteId: siteId,
        items: items,
      );
      if (!mounted) return;
      setState(() {
        _learnerProfile = profile;
        _portfolioItems = items;
        _growthEventsById = growthEventsById;
        _credentials = credentials;
        _portfolioLoadError = null;
        _isPortfolioLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _portfolioLoadError = hadVisibleData
            ? _t(
                'Unable to refresh portfolio right now. Showing the last successful data.',
              )
            : _t(
                'We could not load portfolio data right now. Retry to check the current state.',
              );
        _isPortfolioLoading = false;
      });
    }
  }

  Future<Map<String, CapabilityGrowthEventModel>> _loadGrowthEventsById({
    required FirebaseFirestore firestore,
    required String siteId,
    required List<PortfolioItemModel> items,
  }) async {
    final Set<String> growthEventIds = items
        .where((PortfolioItemModel item) => item.siteId.trim() == siteId)
        .expand((PortfolioItemModel item) => item.growthEventIds)
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toSet();

    if (growthEventIds.isEmpty) {
      return const <String, CapabilityGrowthEventModel>{};
    }

    final Map<String, CapabilityGrowthEventModel> growthEventsById =
        <String, CapabilityGrowthEventModel>{};
    await Future.wait<void>(
      growthEventIds.map((String growthEventId) async {
        try {
          final DocumentSnapshot<Map<String, dynamic>> growthDoc =
              await firestore
                  .collection('capabilityGrowthEvents')
                  .doc(growthEventId)
                  .get();
          if (growthDoc.exists) {
            growthEventsById[growthEventId] =
                CapabilityGrowthEventModel.fromDoc(growthDoc);
          }
        } catch (_) {
          // Omit missing growth detail instead of inventing it.
        }
      }),
    );
    return growthEventsById;
  }

  Future<LearnerPortfolioSnapshot> _loadPortfolioSnapshot({
    required FirebaseFirestore firestore,
    required String learnerId,
    required String siteId,
  }) async {
    final LearnerProfileRepository profileRepository =
        LearnerProfileRepository(firestore: firestore);
    final PortfolioItemRepository portfolioItemRepository =
        PortfolioItemRepository(firestore: firestore);
    final CredentialRepository credentialRepository =
        CredentialRepository(firestore: firestore);

    final List<Object?> results = await Future.wait<Object?>(<Future<Object?>>[
      profileRepository.getByLearnerAndSite(
        learnerId: learnerId,
        siteId: siteId,
      ),
      portfolioItemRepository.listByLearner(learnerId),
      credentialRepository.listByLearner(
        learnerId,
        siteId: siteId,
        limit: 50,
      ),
    ]);

    final List<PortfolioItemModel> items =
        (results[1] as List<PortfolioItemModel>).toList(growable: false);
    final List<PortfolioItemModel> enrichedItems =
        await _enrichPortfolioItemsWithProofBundles(
      firestore: firestore,
      siteId: siteId,
      items: items,
    );

    return LearnerPortfolioSnapshot(
      profile: results.first as LearnerProfileModel?,
      items: enrichedItems,
      credentials:
          (results.last as List<CredentialModel>).toList(growable: false),
    );
  }

  Future<List<PortfolioItemModel>> _enrichPortfolioItemsWithProofBundles({
    required FirebaseFirestore firestore,
    required String siteId,
    required List<PortfolioItemModel> items,
  }) async {
    final Set<String> proofBundleIds = items
        .where((PortfolioItemModel item) => item.siteId.trim() == siteId)
        .map((PortfolioItemModel item) => (item.proofBundleId ?? '').trim())
        .where((String proofBundleId) => proofBundleId.isNotEmpty)
        .toSet();

    if (proofBundleIds.isEmpty) {
      return items;
    }

    final Map<String, Map<String, dynamic>> proofBundles =
        <String, Map<String, dynamic>>{};
    await Future.wait<void>(
      proofBundleIds.map((String proofBundleId) async {
        try {
          final DocumentSnapshot<Map<String, dynamic>> proofBundleDoc =
              await firestore
                  .collection('proofOfLearningBundles')
                  .doc(proofBundleId)
                  .get();
          if (proofBundleDoc.exists && proofBundleDoc.data() != null) {
            proofBundles[proofBundleId] = proofBundleDoc.data()!;
          }
        } catch (_) {
          // Omit missing proof detail instead of synthesizing it.
        }
      }),
    );

    return items.map((PortfolioItemModel item) {
      final String proofBundleId = (item.proofBundleId ?? '').trim();
      final Map<String, dynamic>? proofBundle =
          proofBundleId.isEmpty ? null : proofBundles[proofBundleId];
      if (proofBundle == null) {
        return item;
      }

      final List<Map<String, dynamic>> checkpoints =
          _proofBundleCheckpoints(proofBundle);
      return item.copyWith(
        artifactUrls: item.artifactUrls.isNotEmpty
            ? item.artifactUrls
            : _proofBundleArtifactUrls(proofBundle),
        proofCheckpointCount: item.proofCheckpointCount > 0
            ? item.proofCheckpointCount
            : checkpoints.length,
        proofHasExplainItBack: item.proofHasExplainItBack ||
            _nonEmpty(proofBundle['explainItBack']),
        proofHasOralCheck: item.proofHasOralCheck ||
            _nonEmpty(proofBundle['oralCheckResponse']),
        proofHasMiniRebuild: item.proofHasMiniRebuild ||
            _nonEmpty(proofBundle['miniRebuildPlan']),
        proofExplainItBackExcerpt: item.proofExplainItBackExcerpt ??
            _trimmedString(proofBundle['explainItBack']),
        proofOralCheckExcerpt: item.proofOralCheckExcerpt ??
            _trimmedString(proofBundle['oralCheckResponse']),
        proofMiniRebuildExcerpt: item.proofMiniRebuildExcerpt ??
            _trimmedString(proofBundle['miniRebuildPlan']),
        checkpointSummary:
            item.checkpointSummary ?? _latestCheckpointSummary(checkpoints),
        aiAssistanceUsed:
            item.aiAssistanceUsed ?? (proofBundle['aiAssistanceUsed'] == true),
        aiAssistanceDetails: item.aiAssistanceDetails ??
            _trimmedString(proofBundle['aiAssistanceDetails']),
      );
    }).toList(growable: false);
  }

  List<Map<String, dynamic>> _proofBundleCheckpoints(
      Map<String, dynamic> proofBundle) {
    final List<dynamic> rawHistory =
        proofBundle['versionHistory'] as List<dynamic>? ?? <dynamic>[];
    return rawHistory
        .whereType<Map<dynamic, dynamic>>()
        .map((Map<dynamic, dynamic> entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
  }

  List<String> _proofBundleArtifactUrls(Map<String, dynamic> proofBundle) {
    return List<String>.from(
      proofBundle['artifactUrls'] as List<dynamic>? ?? <dynamic>[],
    );
  }

  String? _latestCheckpointSummary(List<Map<String, dynamic>> checkpoints) {
    for (final Map<String, dynamic> checkpoint in checkpoints.reversed) {
      final String? summary = _trimmedString(checkpoint['summary']);
      if (summary != null) {
        return summary;
      }
    }
    return null;
  }

  bool _nonEmpty(dynamic value) => _trimmedString(value) != null;

  String? _trimmedString(dynamic value) {
    final String trimmed = (value as String? ?? '').trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  bool get _hasVisiblePortfolioData =>
      _learnerProfile != null ||
      _portfolioItems.isNotEmpty ||
      _credentials.isNotEmpty;

  Widget _buildPortfolioBanner(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: ScholesaColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortfolioLoadErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              _portfolioLoadError!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: _loadPortfolioState,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(_t('Retry')),
            ),
          ],
        ),
      ),
    );
  }

  int _savedPortfolioSignalCount() {
    int count = 0;
    if (_learnerProfile?.onboardingCompleted ?? false) {
      count += 1;
    }
    if ((_learnerProfile?.portfolioHeadline?.trim() ?? '').isNotEmpty) {
      count += 1;
    }
    if ((_learnerProfile?.portfolioGoal?.trim() ?? '').isNotEmpty) {
      count += 1;
    }
    if (_portfolioItems.isNotEmpty) {
      count += 1;
    }
    return count;
  }

  String _portfolioReadinessMessage() {
    if (!(_learnerProfile?.onboardingCompleted ?? false)) {
      return _t(
          'Complete learner setup to unlock a stronger portfolio summary.');
    }
    if ((_learnerProfile?.portfolioHeadline?.trim() ?? '').isEmpty ||
        (_learnerProfile?.portfolioGoal?.trim() ?? '').isEmpty ||
        _portfolioItems.isEmpty) {
      return _t(
        'Add a headline, a goal, and at least one project artifact to finish this summary.',
      );
    }
    return _t(
      'Your portfolio summary reflects saved profile details and real artifacts.',
    );
  }

  int _goalCount() {
    return _learnerProfile?.goals
            .where((String goal) => goal.trim().isNotEmpty)
            .length ??
        0;
  }

  String _normalizePillarKey(String raw) {
    final String normalized = raw.trim().toLowerCase();
    switch (normalized) {
      case 'future skills':
      case 'future-skills':
      case 'future_skills':
        return 'future_skills';
      case 'leadership':
      case 'leadership & agency':
      case 'leadership-agency':
      case 'leadership_agency':
        return 'leadership';
      case 'impact':
      case 'impact & innovation':
      case 'impact-innovation':
      case 'impact_innovation':
        return 'impact';
      default:
        return normalized;
    }
  }

  int _projectsForPillar(String pillarKey) {
    return _reviewedPortfolioItems.where((PortfolioItemModel item) {
      return item.pillarCodes
          .map(_normalizePillarKey)
          .contains(_normalizePillarKey(pillarKey));
    }).length;
  }

  bool _isReviewedPortfolioItem(PortfolioItemModel item) {
    final String verificationStatus =
        (item.verificationStatus ?? '').trim().toLowerCase();
    return verificationStatus == 'reviewed' || verificationStatus == 'verified';
  }

  List<PortfolioItemModel> get _reviewedPortfolioItems =>
      _portfolioItems.where(_isReviewedPortfolioItem).toList(growable: false);

  List<PortfolioItemModel> get _awaitingReviewPortfolioItems => _portfolioItems
      .where((PortfolioItemModel item) => !_isReviewedPortfolioItem(item))
      .toList(growable: false);

  String _primaryPillarLabel(PortfolioItemModel item) {
    for (final String code in item.pillarCodes) {
      switch (_normalizePillarKey(code)) {
        case 'future_skills':
          return _t('Future Skills');
        case 'leadership':
          return _t('Leadership');
        case 'impact':
          return _t('Impact');
      }
    }
    return _t('Projects');
  }

  Color _projectColor(PortfolioItemModel item) {
    for (final String code in item.pillarCodes) {
      switch (_normalizePillarKey(code)) {
        case 'future_skills':
          return ScholesaColors.futureSkills;
        case 'leadership':
          return ScholesaColors.leadership;
        case 'impact':
          return ScholesaColors.impact;
      }
    }
    return ScholesaColors.learner;
  }

  String _formatProjectDate(PortfolioItemModel item) {
    final DateTime? date = (item.updatedAt ?? item.createdAt)?.toDate();
    if (date == null) {
      return _t('Saved recently');
    }
    return '${date.month}/${date.day}/${date.year}';
  }

  String _formatCredentialDate(CredentialModel credential) {
    final DateTime issuedAt = credential.issuedAt.toDate();
    return '${issuedAt.month}/${issuedAt.day}/${issuedAt.year}';
  }

  String _credentialPillarLabel(String code) {
    switch (_normalizePillarKey(code)) {
      case 'future_skills':
        return _t('Future Skills');
      case 'leadership':
        return _t('Leadership');
      case 'impact':
        return _t('Impact');
      default:
        return code.trim().isEmpty ? _t('Credentials') : code.trim();
    }
  }

  Color _credentialPillarColor(String code) {
    switch (_normalizePillarKey(code)) {
      case 'future_skills':
        return ScholesaColors.futureSkills;
      case 'leadership':
        return ScholesaColors.leadership;
      case 'impact':
        return ScholesaColors.impact;
      default:
        return ScholesaColors.learner;
    }
  }

  List<_PortfolioSignal> _portfolioSignals() {
    final LearnerProfileModel? profile = _learnerProfile;
    if (profile == null) {
      return const <_PortfolioSignal>[];
    }

    final List<_PortfolioSignal> signals = <_PortfolioSignal>[
      ...profile.strengths.where((String value) => value.trim().isNotEmpty).map(
            (String value) => _PortfolioSignal(
              label: value.trim(),
              category: _t('Strength'),
              icon: Icons.bolt_rounded,
              color: ScholesaColors.futureSkills,
            ),
          ),
      ...profile.interests.where((String value) => value.trim().isNotEmpty).map(
            (String value) => _PortfolioSignal(
              label: value.trim(),
              category: _t('Interest'),
              icon: Icons.interests_rounded,
              color: ScholesaColors.leadership,
            ),
          ),
      ...profile.goals.where((String value) => value.trim().isNotEmpty).map(
            (String value) => _PortfolioSignal(
              label: value.trim(),
              category: _t('Goal'),
              icon: Icons.flag_rounded,
              color: ScholesaColors.impact,
            ),
          ),
    ];

    return signals;
  }

  Widget _buildEmptyTabState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.schBorder),
        ),
        child: Column(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ScholesaColors.learner.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: ScholesaColors.learner, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.schTextSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              ScholesaColors.learner.withValues(alpha: 0.05),
              context.schSurface,
              ScholesaColors.futureSkills.withValues(alpha: 0.03),
            ],
          ),
        ),
        child: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverToBoxAdapter(child: _buildHeader()),
              if (_portfolioLoadError != null)
                SliverToBoxAdapter(
                  child: _buildPortfolioBanner(_portfolioLoadError!),
                ),
              SliverToBoxAdapter(child: _buildProfileCard()),
              SliverToBoxAdapter(child: _buildLevelProgress()),
              SliverToBoxAdapter(child: _buildPillarStats()),
              SliverToBoxAdapter(child: _buildAiCoachingSection(context)),
              SliverToBoxAdapter(child: _buildTabBar()),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: <Widget>[
              _buildBadgesList(),
              _buildSkillsList(),
              _buildProjectsList(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          TelemetryService.instance.logEvent(
            event: 'cta.clicked',
            metadata: <String, dynamic>{
              'module': 'learner_portfolio',
              'cta_id': 'open_share_portfolio_dialog',
              'surface': 'floating_action_button',
            },
          );
          _sharePortfolio();
        },
        backgroundColor: ScholesaColors.learner,
        icon: const Icon(Icons.share),
        label: Text(_t('Share')),
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
                gradient: ScholesaColors.learnerGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: ScholesaColors.learner.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.workspace_premium,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _t('My Portfolio'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: ScholesaColors.learner,
                        ),
                  ),
                  Text(
                    _t('Showcase your saved work and credentials'),
                    style: TextStyle(
                        color: context.schTextSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: _t('Refresh'),
              onPressed: _loadPortfolioState,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ScholesaColors.learner.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  color: ScholesaColors.learner,
                ),
              ),
            ),
            IconButton(
              tooltip: _t('Credentials'),
              onPressed: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: const <String, dynamic>{
                    'module': 'learner_portfolio',
                    'cta_id': 'open_credentials_route',
                    'surface': 'header',
                  },
                );
                context.go('/learner/credentials');
              },
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ScholesaColors.learner.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: ScholesaColors.learner,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const SessionMenuHeaderAction(
              foregroundColor: ScholesaColors.learner,
            ),
            IconButton(
              onPressed: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: <String, dynamic>{
                    'module': 'learner_portfolio',
                    'cta_id': 'open_edit_profile_dialog',
                    'surface': 'header',
                  },
                );
                _editProfile();
              },
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ScholesaColors.learner.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.edit, color: ScholesaColors.learner),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final AppState appState = context.watch<AppState>();
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF0F766E), Color(0xFF115E59)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0xFF115E59).withValues(alpha: 0.24),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
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
                    _learnerName(appState),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _effectiveHeadline(appState),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _effectiveGoal(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      const Icon(Icons.local_fire_department,
                          color: Colors.orange, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '${_t('Goals')}: ${_goalCount()}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.star, color: Colors.amber, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '${_t('Projects')}: ${_reviewedPortfolioItems.length}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _effectiveHighlight(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '${_credentials.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _t('Credentials'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelProgress() {
    final int savedSignals = _savedPortfolioSignalCount();
    final double progress = savedSignals / 4;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.schBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            ScholesaColors.futureSkills.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.rocket_launch,
                          color: ScholesaColors.futureSkills, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _t('Portfolio readiness'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          _t('Profile signals live'),
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: ScholesaColors.futureSkills.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$savedSignals / 4',
                    style: TextStyle(
                      color: ScholesaColors.futureSkills,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor:
                    ScholesaColors.futureSkills.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  ScholesaColors.futureSkills,
                ),
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$savedSignals / 4 ${_t('Profile signals live')}',
              style: const TextStyle(
                color: ScholesaColors.futureSkills,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _portfolioReadinessMessage(),
              style: TextStyle(color: context.schTextSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillarStats() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _PillarStatCard(
              icon: Icons.code,
              label: _t('Future Skills'),
              count: _projectsForPillar('future_skills'),
              caption: _t('Projects'),
              color: ScholesaColors.futureSkills,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _PillarStatCard(
              icon: Icons.emoji_events,
              label: _t('Leadership'),
              count: _projectsForPillar('leadership'),
              caption: _t('Projects'),
              color: ScholesaColors.leadership,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _PillarStatCard(
              icon: Icons.eco,
              label: _t('Impact'),
              count: _projectsForPillar('impact'),
              caption: _t('Projects'),
              color: ScholesaColors.impact,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.schSurfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: context.schTextSecondary,
        indicator: BoxDecoration(
          color: ScholesaColors.learner,
          borderRadius: BorderRadius.circular(12),
        ),
        tabs: <Widget>[
          Tab(text: _t('Badges')),
          Tab(text: _t('Skills')),
          Tab(text: _t('Projects')),
        ],
      ),
    );
  }

  Widget _buildBadgesList() {
    if (_isPortfolioLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_portfolioLoadError != null && !_hasVisiblePortfolioData) {
      return _buildPortfolioLoadErrorState();
    }

    if (_credentials.isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ScholesaColors.learner.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: ScholesaColors.learner,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _t(
                      'These badges reflect issued credentials. Evidence, rubric, and growth links are not shown in this tab yet.',
                    ),
                    style: TextStyle(
                      color: context.schTextSecondary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ..._credentials.map((CredentialModel credential) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:
                                ScholesaColors.learner.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.workspace_premium_rounded,
                            color: ScholesaColors.learner,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                credential.title.trim().isEmpty
                                    ? _t('Credential title unavailable')
                                    : credential.title.trim(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_t('Issued')} ${_formatCredentialDate(credential)}',
                                style: TextStyle(
                                  color: context.schTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (credential.pillarCodes.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: credential.pillarCodes.map((String code) {
                          final Color color = _credentialPillarColor(code);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _credentialPillarLabel(code),
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(growable: false),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      );
    }

    return _buildEmptyTabState(
      icon: Icons.workspace_premium_outlined,
      title: _t('No badges earned yet'),
      message: _t(
        'Badges will appear here after your educator or site publishes earned credentials.',
      ),
    );
  }

  Widget _buildSkillsList() {
    final List<_PortfolioSignal> signals = _portfolioSignals();
    if (_isPortfolioLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_portfolioLoadError != null && !_hasVisiblePortfolioData) {
      return _buildPortfolioLoadErrorState();
    }
    if (signals.isEmpty) {
      return _buildEmptyTabState(
        icon: Icons.auto_awesome_outlined,
        title: _t('No skills or interests saved yet'),
        message: _t(
          'Complete learner setup or add strengths and interests to show real learner signals here.',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: signals.length,
      itemBuilder: (BuildContext context, int index) {
        return _PortfolioSignalCard(signal: signals[index]);
      },
    );
  }

  Widget _buildProjectsList() {
    final List<PortfolioItemModel> reviewedItems = _reviewedPortfolioItems;
    final List<PortfolioItemModel> awaitingReviewItems =
        _awaitingReviewPortfolioItems;
    if (_isPortfolioLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_portfolioLoadError != null && !_hasVisiblePortfolioData) {
      return _buildPortfolioLoadErrorState();
    }
    if (reviewedItems.isEmpty && awaitingReviewItems.isEmpty) {
      return _buildEmptyTabState(
        icon: Icons.folder_open_outlined,
        title: _t('No reviewed projects yet'),
        message: _t(
          'Reviewed projects appear here after educator review links evidence, rubric feedback, and proof of learning.',
        ),
      );
    }

    final List<Widget> children = <Widget>[
      if (reviewedItems.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildEmptyTabState(
            icon: Icons.verified_outlined,
            title: _t('No reviewed projects yet'),
            message: _t(
              'Reviewed projects appear here after educator review links evidence, rubric feedback, and proof of learning.',
            ),
          ),
        ),
      ...reviewedItems.map(
        (PortfolioItemModel item) => _ProjectCard(
          project: _projectCardData(
            item,
            statusLabel: (item.verificationStatus?.trim().isNotEmpty ?? false)
                ? '${_t('Evidence linked')} • ${_titleCase(item.verificationStatus!.trim())}'
                : _t('Evidence linked'),
          ),
        ),
      ),
      if (awaitingReviewItems.isNotEmpty) ...<Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _t('Awaiting educator review'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                _t('These saved submissions are not part of your reviewed portfolio yet.'),
                style: TextStyle(
                  color: context.schTextSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        ...awaitingReviewItems.map(
          (PortfolioItemModel item) => _ProjectCard(
            project: _projectCardData(
              item,
              statusLabel: _t('Awaiting educator review'),
              fallbackDescription: _t(
                'Saved submission awaiting educator review before it becomes portfolio evidence.',
              ),
            ),
          ),
        ),
      ],
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: children,
    );
  }

  Map<String, dynamic> _projectCardData(
    PortfolioItemModel item, {
    required String statusLabel,
    String? fallbackDescription,
  }) {
    final List<String> detailLines = <String>[
      ..._growthDetailLines(item),
      ..._proofDetailLines(item),
      ..._verificationDetailLines(item),
      ..._reflectionDetailLines(item),
      ..._artifactDetailLines(item),
      ..._aiDetailLines(item),
    ];
    return <String, dynamic>{
      'title': item.title.trim(),
      'description': (item.description?.trim().isNotEmpty ?? false)
          ? item.description!.trim()
          : (fallbackDescription ?? _t('Saved to your portfolio.')),
      'pillar': _primaryPillarLabel(item),
      'date': _formatProjectDate(item),
      'capabilityTitles': item.capabilityTitles,
      'evidenceLinked': item.evidenceRecordIds.isNotEmpty,
      'statusLabel': statusLabel,
      'detailLines': detailLines,
      'image': null,
      'color': _projectColor(item),
    };
  }

  List<String> _proofDetailLines(PortfolioItemModel item) {
    final List<String> lines = <String>[];
    final String? proofStatus =
        _proofOfLearningLabel(item.proofOfLearningStatus);
    if (proofStatus != null) {
      lines.add('${_t('Proof of learning')}: $proofStatus');
    }

    final List<String> proofChecks = <String>[];
    if (item.proofHasExplainItBack) {
      proofChecks.add(_t('Explain-it-back'));
    }
    if (item.proofHasOralCheck) {
      proofChecks.add(_t('Oral check'));
    }
    if (item.proofHasMiniRebuild) {
      proofChecks.add(_t('Mini-rebuild'));
    }
    if (item.proofCheckpointCount > 0) {
      proofChecks.add(
        item.proofCheckpointCount == 1
            ? _t('1 checkpoint')
            : '${item.proofCheckpointCount} ${_t('checkpoints')}',
      );
    }
    if (proofChecks.isNotEmpty) {
      lines.add('${_t('Proof checks')}: ${proofChecks.join(', ')}');
    }
    if ((item.proofExplainItBackExcerpt?.trim().isNotEmpty ?? false)) {
      lines.add(
        '${_t('Explain-it-back note')}: ${item.proofExplainItBackExcerpt!.trim()}',
      );
    }
    if ((item.proofOralCheckExcerpt?.trim().isNotEmpty ?? false)) {
      lines.add(
        '${_t('Oral check note')}: ${item.proofOralCheckExcerpt!.trim()}',
      );
    }
    if ((item.proofMiniRebuildExcerpt?.trim().isNotEmpty ?? false)) {
      lines.add(
        '${_t('Mini-rebuild note')}: ${item.proofMiniRebuildExcerpt!.trim()}',
      );
    }
    return lines;
  }

  List<String> _verificationDetailLines(PortfolioItemModel item) {
    final List<String> lines = <String>[];
    if ((item.verificationPrompt?.trim().isNotEmpty ?? false)) {
      lines.add(
        '${_t('Verification prompt')}: ${item.verificationPrompt!.trim()}',
      );
    }
    if (item.checkpointMappings.isNotEmpty) {
      final List<String> criteria = item.checkpointMappings
          .map((Map<String, dynamic> mapping) {
            final String phaseLabel =
                (mapping['phaseLabel'] as String? ?? mapping['phaseKey'] as String? ?? '')
                    .trim();
            final String guidance =
                (mapping['guidance'] as String? ?? mapping['prompt'] as String? ?? '')
                    .trim();
            if (guidance.isEmpty) {
              return '';
            }
            return phaseLabel.isEmpty ? guidance : '$phaseLabel: $guidance';
          })
          .where((String value) => value.isNotEmpty)
          .toList(growable: false);
      if (criteria.isNotEmpty) {
        lines.add('${_t('Verification criteria')}: ${criteria.join(' | ')}');
      }
    }
    if (item.progressionDescriptors.isNotEmpty) {
      lines.add(
        '${_t('Progression descriptors')}: ${item.progressionDescriptors.join(' | ')}',
      );
    }
    return lines;
  }

  List<String> _growthDetailLines(PortfolioItemModel item) {
    final List<CapabilityGrowthEventModel> growthEvents = item.growthEventIds
        .map((String growthEventId) => _growthEventsById[growthEventId.trim()])
        .whereType<CapabilityGrowthEventModel>()
        .toList(growable: false);
    if (growthEvents.isEmpty) {
      return const <String>[];
    }

    return growthEvents.map((CapabilityGrowthEventModel growthEvent) {
      final String capabilityTitle =
          (growthEvent.capabilityTitle?.trim().isNotEmpty ?? false)
              ? growthEvent.capabilityTitle!.trim()
              : _fallbackGrowthCapabilityTitle(item, growthEvent.capabilityId);
      final List<String> parts = <String>[
        capabilityTitle,
        '${_t('Level')} ${growthEvent.level}',
        '${_t('Reviewed score')} ${growthEvent.rawScore}/${growthEvent.maxScore}',
      ];
      final List<String> lines = <String>[
        '${_t('Capability update')}: ${parts.join(' • ')}',
      ];
      if (growthEvent.progressionDescriptors.isNotEmpty) {
        lines.add(
            '${_t('Progression descriptors')}: ${growthEvent.progressionDescriptors.join(' | ')}');
      }
      return lines.join('\n');
    }).toList(growable: false);
  }

  String _fallbackGrowthCapabilityTitle(
    PortfolioItemModel item,
    String capabilityId,
  ) {
    final int matchingIndex = item.capabilityIds.indexOf(capabilityId);
    if (matchingIndex >= 0 && matchingIndex < item.capabilityTitles.length) {
      final String matchedTitle = item.capabilityTitles[matchingIndex].trim();
      if (matchedTitle.isNotEmpty) {
        return matchedTitle;
      }
    }
    if (item.capabilityTitles.isNotEmpty) {
      final String firstTitle = item.capabilityTitles.first.trim();
      if (firstTitle.isNotEmpty) {
        return firstTitle;
      }
    }
    return _t('Capability evidence');
  }

  List<String> _reflectionDetailLines(PortfolioItemModel item) {
    final List<String> lines = <String>[];
    if ((item.checkpointSummary?.trim().isNotEmpty ?? false)) {
      lines.add(
          '${_t('Checkpoint summary')}: ${item.checkpointSummary!.trim()}');
    }
    if ((item.reflectionNote?.trim().isNotEmpty ?? false)) {
      lines.add('${_t('Reflection')}: ${item.reflectionNote!.trim()}');
    }
    return lines;
  }

  List<String> _artifactDetailLines(PortfolioItemModel item) {
    if (item.artifactUrls.isEmpty) {
      return const <String>[];
    }
    final String countLabel = item.artifactUrls.length == 1
        ? _t('1 artifact')
        : '${item.artifactUrls.length} ${_t('artifacts')}';
    return <String>['${_t('Artifacts linked')}: $countLabel'];
  }

  List<String> _aiDetailLines(PortfolioItemModel item) {
    final List<String> lines = <String>[];
    final String? disclosureLabel = _aiDisclosureLabel(item);
    if (disclosureLabel != null) {
      lines.add('${_t('AI disclosure')}: $disclosureLabel');
    }
    if ((item.aiAssistanceDetails?.trim().isNotEmpty ?? false)) {
      lines.add('${_t('AI details')}: ${item.aiAssistanceDetails!.trim()}');
    }
    return lines;
  }

  String? _proofOfLearningLabel(String? status) {
    switch ((status ?? '').trim()) {
      case 'verified':
        return _t('Verified');
      case 'partial':
        return _t('Partial');
      case 'missing':
        return _t('Missing');
      case 'not-available':
        return _t('Not available');
      default:
        return null;
    }
  }

  String? _aiDisclosureLabel(PortfolioItemModel item) {
    switch ((item.aiDisclosureStatus ?? '').trim()) {
      case 'learner-ai-verified':
        return _t('Learner disclosed AI use and explained it');
      case 'learner-ai-verification-gap':
        return _t('Learner disclosed AI use; proof still needs verification');
      case 'learner-ai-not-used':
        return _t('Learner said no AI support was used');
      case 'educator-observed-ai-use':
        return _t('Educator observed AI use during review');
      case 'educator-observed-no-ai-use':
        return _t('Educator confirmed no AI use during review');
      case 'educator-feedback-ai':
        return _t('AI-assisted educator feedback is attached');
      case 'no-learner-ai-signal':
        return _t('No learner AI disclosure was recorded');
      default:
        if (item.aiAssistanceUsed == true) {
          return _t('AI support was used');
        }
        if ((item.aiAssistanceDetails?.trim().isNotEmpty ?? false)) {
          return _t('AI support details recorded');
        }
        return null;
    }
  }

  void _editProfile() {
    final AppState appState = context.read<AppState>();
    final String learnerId = appState.userId?.trim() ?? '';
    final String siteId = _activeSiteId(appState);
    final TextEditingController headlineController = TextEditingController(
      text: _effectiveHeadline(appState),
    );
    final TextEditingController goalController = TextEditingController(
      text: _effectiveGoal(),
    );
    final TextEditingController highlightController = TextEditingController(
      text: _effectiveHighlight(),
    );
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final NavigatorState dialogNavigator = Navigator.of(dialogContext);
        return AlertDialog(
          title: Text(_t('Edit Portfolio Profile')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _t('Update your portfolio bio, goals, and featured highlights.'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: headlineController,
                  decoration: InputDecoration(
                    labelText: _t('Portfolio Headline'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: goalController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: _t('Current Goal'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: highlightController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: _t('Featured Highlight'),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: <String, dynamic>{
                    'module': 'learner_portfolio',
                    'cta_id': 'cancel_edit_profile',
                    'surface': 'edit_profile_dialog',
                  },
                );
                Navigator.pop(dialogContext);
              },
              child: Text(_t('Cancel')),
            ),
            FilledButton(
              onPressed: () async {
                final FirestoreService? firestoreService =
                    _maybeFirestoreService();
                if (firestoreService == null ||
                    learnerId.isEmpty ||
                    siteId.isEmpty) {
                  dialogNavigator.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content:
                          Text(_t('Profile storage unavailable right now.')),
                    ),
                  );
                  return;
                }

                final LearnerProfileModel currentProfile = _learnerProfile ??
                    LearnerProfileModel(
                      id: learnerId,
                      learnerId: learnerId,
                      siteId: siteId,
                      createdAt: Timestamp.now(),
                      updatedAt: Timestamp.now(),
                    );
                final LearnerProfileModel updatedProfile = LearnerProfileModel(
                  id: currentProfile.id,
                  learnerId: currentProfile.learnerId,
                  siteId: currentProfile.siteId,
                  legalName: currentProfile.legalName,
                  preferredName: currentProfile.preferredName,
                  dateOfBirth: currentProfile.dateOfBirth,
                  gradeLevel: currentProfile.gradeLevel,
                  strengths: currentProfile.strengths,
                  learningNeeds: currentProfile.learningNeeds,
                  interests: currentProfile.interests,
                  goals: currentProfile.goals,
                  readingLevelSelfCheck: currentProfile.readingLevelSelfCheck,
                  diagnosticConfidenceBand:
                      currentProfile.diagnosticConfidenceBand,
                  weeklyTargetMinutes: currentProfile.weeklyTargetMinutes,
                  reminderSchedule: currentProfile.reminderSchedule,
                  valuePrompt: currentProfile.valuePrompt,
                  portfolioHeadline: headlineController.text.trim(),
                  portfolioGoal: goalController.text.trim(),
                  portfolioHighlight: highlightController.text.trim(),
                  ttsEnabled: currentProfile.ttsEnabled,
                  reducedDistractionEnabled:
                      currentProfile.reducedDistractionEnabled,
                  keyboardOnlyEnabled: currentProfile.keyboardOnlyEnabled,
                  highContrastEnabled: currentProfile.highContrastEnabled,
                  onboardingCompleted: currentProfile.onboardingCompleted,
                  lastSetupAt: currentProfile.lastSetupAt,
                  emergencyContact: currentProfile.emergencyContact,
                  createdAt: currentProfile.createdAt,
                  updatedAt: Timestamp.now(),
                );
                final LearnerProfileRepository repository =
                    LearnerProfileRepository(
                  firestore: firestoreService.firestore,
                );

                try {
                  await repository.upsert(updatedProfile);
                  if (!mounted || !dialogNavigator.mounted) return;
                  setState(() => _learnerProfile = updatedProfile);
                  TelemetryService.instance.logEvent(
                    event: 'learner.portfolio.profile.updated',
                    metadata: <String, dynamic>{
                      'module': 'learner_portfolio',
                      'surface': 'edit_profile_dialog',
                    },
                  );
                  dialogNavigator.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(_t('Portfolio profile updated.')),
                    ),
                  );
                } catch (_) {
                  if (dialogNavigator.mounted) {
                    dialogNavigator.pop();
                  }
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        _t('Could not save portfolio profile right now.'),
                      ),
                    ),
                  );
                }
              },
              child: Text(_t('Save')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sharePortfolio() async {
    final AppState appState = context.read<AppState>();
    final String shareText = <String>[
      _t('Share Portfolio'),
      '${_learnerName(appState)} • ${_effectiveHeadline(appState)}',
      _effectiveGoal(),
      _effectiveHighlight(),
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: shareText));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_t('Portfolio summary copied for sharing.')),
      ),
    );
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
              color: context.schSurface,
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
              title: Text(_t('Reflect on Progress')),
              subtitle: Text(
                _t(
                  'Get experimental AI insights on your saved work and goals. These notes do not replace your evidence record.',
                ),
              ),
              trailing: IconButton(
                icon: Icon(
                  _showAiCoach ? Icons.expand_less : Icons.expand_more,
                ),
                onPressed: () {
                  final bool nextValue = !_showAiCoach;
                  _setShowAiCoach(nextValue);
                  TelemetryService.instance.logEvent(
                    event: 'cta.clicked',
                    metadata: <String, dynamic>{
                      'module': 'learner_portfolio',
                      'cta': 'portfolio_ai_${nextValue ? 'show' : 'hide'}',
                      'surface': 'portfolio_header',
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.schSurface,
          border: Border.all(
            color: ScholesaColors.learner.withValues(alpha: 0.1),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(
              Icons.info_outline_rounded,
              color: ScholesaColors.learner,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _t('AI guidance unavailable right now.'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _t('Your saved badges, skills, and projects are still available while AI reflection reconnects.'),
                    style: TextStyle(
                      color: context.schTextSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: context.schSurface,
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
          'portfolio',
          'reflection',
          'achievements',
        ],
      ),
    );
  }
}

class _PillarStatCard extends StatelessWidget {
  const _PillarStatCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.caption,
    required this.color,
  });
  final IconData icon;
  final String label;
  final int count;
  final String caption;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.schBorder),
      ),
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.schTextSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: color,
            ),
          ),
          Text(
            caption,
            style: TextStyle(
                color: context.schTextSecondary.withValues(alpha: 0.88),
                fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _PortfolioSignal {
  const _PortfolioSignal({
    required this.label,
    required this.category,
    required this.icon,
    required this.color,
  });

  final String label;
  final String category;
  final IconData icon;
  final Color color;
}

class _PortfolioSignalCard extends StatelessWidget {
  const _PortfolioSignalCard({required this.signal});
  final _PortfolioSignal signal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.schBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: signal.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(signal.icon, color: signal.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        signal.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        signal.category,
                        style: TextStyle(
                          color: signal.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});
  final Map<String, dynamic> project;

  @override
  Widget build(BuildContext context) {
    final List<String> capabilityTitles =
        ((project['capabilityTitles'] as List?)?.cast<String>() ??
                const <String>[])
            .where((String value) => value.trim().isNotEmpty)
            .toList(growable: false);
    final List<String> detailLines =
        ((project['detailLines'] as List?)?.cast<String>() ?? const <String>[])
            .where((String value) => value.trim().isNotEmpty)
            .toList(growable: false);
    final String statusLabel = (project['statusLabel'] as String? ?? '').trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.schBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: (project['color'] as Color).withValues(alpha: 0.15),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.folder_special,
                  size: 48,
                  color: project['color'] as Color,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (project['color'] as Color)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          project['pillar'] as String,
                          style: TextStyle(
                            color: project['color'] as Color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        project['date'] as String,
                        style: TextStyle(
                            color: context.schTextSecondary
                                .withValues(alpha: 0.88),
                            fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    project['title'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    project['description'] as String,
                    style: TextStyle(
                        color: context.schTextSecondary, fontSize: 14),
                  ),
                  if (statusLabel.isNotEmpty ||
                      capabilityTitles.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        if (statusLabel.isNotEmpty)
                          _ProjectMetaChip(
                            label: statusLabel,
                            color: project['color'] as Color,
                          ),
                        ...capabilityTitles.take(3).map(
                              (String value) => _ProjectMetaChip(
                                label: value,
                                color: project['color'] as Color,
                              ),
                            ),
                      ],
                    ),
                  ],
                  if (detailLines.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    ...detailLines.map(
                      (String line) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          line,
                          style: TextStyle(
                            color: context.schTextSecondary,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectMetaChip extends StatelessWidget {
  const _ProjectMetaChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String _titleCase(String value) {
  if (value.isEmpty) {
    return value;
  }
  final String normalized = value.replaceAll('_', ' ').trim();
  if (normalized.isEmpty) {
    return value;
  }
  return normalized
      .split(RegExp(r'\s+'))
      .where((String part) => part.isNotEmpty)
      .map(
        (String part) =>
            '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}
