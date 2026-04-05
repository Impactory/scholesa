import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/app_state.dart';
import '../../domain/models.dart';
import '../../services/firestore_service.dart';

/// Learner Peer Feedback Page - Give and receive structured feedback from peers.
class PeerFeedbackPage extends StatefulWidget {
  const PeerFeedbackPage({super.key});

  @override
  State<PeerFeedbackPage> createState() => _PeerFeedbackPageState();
}

class _PeerFeedbackPageState extends State<PeerFeedbackPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<MissionAttemptModel> _peerAttempts = const <MissionAttemptModel>[];
  List<PeerFeedbackModel> _feedbackGiven = const <PeerFeedbackModel>[];
  List<PeerFeedbackModel> _feedbackReceived = const <PeerFeedbackModel>[];
  bool _isLoading = false;
  String? _loadError;

  /// Tracks which mission attempt is expanded for giving feedback.
  final Set<String> _expandedAttempts = <String>{};

  /// Rating value per attempt id (1-5).
  final Map<String, int> _ratings = <String, int>{};

  /// Controllers keyed by attempt id for strengths.
  final Map<String, TextEditingController> _strengthsControllers =
      <String, TextEditingController>{};

  /// Controllers keyed by attempt id for suggestions.
  final Map<String, TextEditingController> _suggestionsControllers =
      <String, TextEditingController>{};

  /// Tracks which attempts are currently being submitted.
  final Set<String> _submitting = <String>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final TextEditingController c in _strengthsControllers.values) {
      c.dispose();
    }
    for (final TextEditingController c in _suggestionsControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _learnerId(AppState appState) =>
      appState.userId?.trim() ?? '';

  String _siteId(AppState appState) {
    final String active = appState.activeSiteId?.trim() ?? '';
    if (active.isNotEmpty) return active;
    if (appState.siteIds.isNotEmpty) return appState.siteIds.first.trim();
    return '';
  }

  FirestoreService? _maybeFirestoreService() {
    try {
      return context.read<FirestoreService>();
    } catch (_) {
      return null;
    }
  }

  TextEditingController _strengthsController(String id) {
    return _strengthsControllers.putIfAbsent(
        id, () => TextEditingController());
  }

  TextEditingController _suggestionsController(String id) {
    return _suggestionsControllers.putIfAbsent(
        id, () => TextEditingController());
  }

  Future<void> _loadData() async {
    final AppState appState = context.read<AppState>();
    final FirestoreService? service = _maybeFirestoreService();
    final String learnerId = _learnerId(appState);
    final String siteId = _siteId(appState);

    if (service == null || learnerId.isEmpty || siteId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Peer feedback data unavailable right now.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      // Load peer attempts, feedback given, and feedback received in parallel.
      final List<Object> results = await Future.wait(<Future<Object>>[
        // Submitted mission attempts from peers (not self).
        service.firestore
            .collection('missionAttempts')
            .where('siteId', isEqualTo: siteId)
            .where('status', isEqualTo: 'submitted')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .get(),
        // Feedback this learner has given.
        service.firestore
            .collection('peerFeedback')
            .where('fromLearnerId', isEqualTo: learnerId)
            .orderBy('createdAt', descending: true)
            .get(),
        // Feedback this learner has received.
        service.firestore
            .collection('peerFeedback')
            .where('toLearnerId', isEqualTo: learnerId)
            .orderBy('createdAt', descending: true)
            .get(),
      ]);

      final QuerySnapshot<Map<String, dynamic>> attemptsSnapshot =
          results[0] as QuerySnapshot<Map<String, dynamic>>;
      final QuerySnapshot<Map<String, dynamic>> givenSnapshot =
          results[1] as QuerySnapshot<Map<String, dynamic>>;
      final QuerySnapshot<Map<String, dynamic>> receivedSnapshot =
          results[2] as QuerySnapshot<Map<String, dynamic>>;

      // Filter out self-authored attempts.
      final List<MissionAttemptModel> peerAttempts = attemptsSnapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              MissionAttemptModel.fromDoc(doc))
          .where((MissionAttemptModel a) => a.learnerId != learnerId)
          .toList();

      final List<PeerFeedbackModel> given = givenSnapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              PeerFeedbackModel.fromDoc(doc))
          .toList();

      final List<PeerFeedbackModel> received = receivedSnapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              PeerFeedbackModel.fromDoc(doc))
          .toList();

      if (!mounted) return;
      setState(() {
        _peerAttempts = peerAttempts;
        _feedbackGiven = given;
        _feedbackReceived = received;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load peer feedback data. Tap to retry.';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitFeedback(MissionAttemptModel attempt) async {
    final AppState appState = context.read<AppState>();
    final FirestoreService? service = _maybeFirestoreService();
    final String learnerId = _learnerId(appState);
    final String siteId = _siteId(appState);

    if (service == null || learnerId.isEmpty || siteId.isEmpty) {
      _showSnackBar('Unable to submit feedback.', isError: true);
      return;
    }

    final int? rating = _ratings[attempt.id];
    final String strengths = _strengthsController(attempt.id).text.trim();
    final String suggestions = _suggestionsController(attempt.id).text.trim();

    if (rating == null) {
      _showSnackBar('Please select a rating.', isError: true);
      return;
    }

    setState(() => _submitting.add(attempt.id));

    try {
      await service.submitPeerFeedback(
        fromLearnerId: learnerId,
        toLearnerId: attempt.learnerId,
        missionAttemptId: attempt.id,
        siteId: siteId,
        rating: rating,
        strengths: strengths.isNotEmpty ? strengths : null,
        suggestions: suggestions.isNotEmpty ? suggestions : null,
      );

      _strengthsController(attempt.id).clear();
      _suggestionsController(attempt.id).clear();
      _ratings.remove(attempt.id);
      _expandedAttempts.remove(attempt.id);

      _showSnackBar('Feedback submitted!');
      await _loadData();
    } catch (e) {
      _showSnackBar('Failed to submit feedback.', isError: true);
    } finally {
      if (mounted) setState(() => _submitting.remove(attempt.id));
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Peer Feedback'),
        bottom: TabBar(
          controller: _tabController,
          tabs: <Widget>[
            Tab(
              text: 'Review Peers',
              icon: Badge(
                isLabelVisible: _peerAttempts.isNotEmpty,
                label: Text('${_peerAttempts.length}'),
                child: const Icon(Icons.rate_review_outlined),
              ),
            ),
            Tab(
              text: 'Given',
              icon: Badge(
                isLabelVisible: _feedbackGiven.isNotEmpty,
                label: Text('${_feedbackGiven.length}'),
                child: const Icon(Icons.send_outlined),
              ),
            ),
            Tab(
              text: 'Received',
              icon: Badge(
                isLabelVisible: _feedbackReceived.isNotEmpty,
                label: Text('${_feedbackReceived.length}'),
                child: const Icon(Icons.inbox_outlined),
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: InkWell(
                    onTap: _loadData,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        _loadError!,
                        style: theme.textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: <Widget>[
                    _buildReviewTab(theme, colors),
                    _buildGivenTab(theme, colors),
                    _buildReceivedTab(theme, colors),
                  ],
                ),
    );
  }

  // ==================== Review Peers Tab ====================

  Widget _buildReviewTab(ThemeData theme, ColorScheme colors) {
    if (_peerAttempts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'No peer submissions available for review right now.',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.all(16.0),
        itemCount: _peerAttempts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12.0),
        itemBuilder: (BuildContext context, int index) {
          return _buildPeerAttemptCard(
              _peerAttempts[index], theme, colors);
        },
      ),
    );
  }

  Widget _buildPeerAttemptCard(
    MissionAttemptModel attempt,
    ThemeData theme,
    ColorScheme colors,
  ) {
    final bool isExpanded = _expandedAttempts.contains(attempt.id);
    final int currentRating = _ratings[attempt.id] ?? 0;

    return Card(
      elevation: 1,
      child: Column(
        children: <Widget>[
          // Header
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedAttempts.remove(attempt.id);
                } else {
                  _expandedAttempts.add(attempt.id);
                }
              });
            },
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(12.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: <Widget>[
                  Icon(Icons.person_outline,
                      size: 24, color: colors.primary),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Mission: ${attempt.missionId}',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'By: ${attempt.learnerId}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (attempt.createdAt != null)
                    Text(
                      _formatDate(attempt.createdAt!),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: colors.outline),
                    ),
                  const SizedBox(width: 8.0),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: colors.outline,
                  ),
                ],
              ),
            ),
          ),

          // Expanded feedback form
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Divider(),

                  // Show submission content if available
                  if (attempt.reflection != null &&
                      attempt.reflection!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8.0),
                    Text('Submission notes:',
                        style: theme.textTheme.labelMedium),
                    const SizedBox(height: 4.0),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Text(
                        attempt.reflection!,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16.0),

                  // Star rating
                  Text('Rating', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4.0),
                  Row(
                    children: List<Widget>.generate(5, (int index) {
                      final int starValue = index + 1;
                      return IconButton(
                        onPressed: () {
                          setState(
                              () => _ratings[attempt.id] = starValue);
                        },
                        icon: Icon(
                          starValue <= currentRating
                              ? Icons.star
                              : Icons.star_border,
                          color: starValue <= currentRating
                              ? Colors.amber
                              : colors.outline,
                          size: 28,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12.0),

                  // Strengths
                  Text('Strengths', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4.0),
                  TextField(
                    controller: _strengthsController(attempt.id),
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'What did they do well?',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12.0),

                  // Suggestions
                  Text('Suggestions', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4.0),
                  TextField(
                    controller: _suggestionsController(attempt.id),
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'What could be improved?',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12.0),

                  // Submit
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _submitting.contains(attempt.id)
                          ? null
                          : () => _submitFeedback(attempt),
                      icon: _submitting.contains(attempt.id)
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : const Icon(Icons.send, size: 18),
                      label: const Text('Submit Feedback'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ==================== Given Tab ====================

  Widget _buildGivenTab(ThemeData theme, ColorScheme colors) {
    if (_feedbackGiven.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'You have not given any peer feedback yet.',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: _feedbackGiven.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12.0),
      itemBuilder: (BuildContext context, int index) {
        return _buildFeedbackCard(
            _feedbackGiven[index], theme, colors,
            showRecipient: true);
      },
    );
  }

  // ==================== Received Tab ====================

  Widget _buildReceivedTab(ThemeData theme, ColorScheme colors) {
    if (_feedbackReceived.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'You have not received any peer feedback yet.',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: _feedbackReceived.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12.0),
      itemBuilder: (BuildContext context, int index) {
        return _buildFeedbackCard(
            _feedbackReceived[index], theme, colors,
            showRecipient: false);
      },
    );
  }

  Widget _buildFeedbackCard(
    PeerFeedbackModel feedback,
    ThemeData theme,
    ColorScheme colors, {
    required bool showRecipient,
  }) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Header row
            Row(
              children: <Widget>[
                Icon(
                  showRecipient ? Icons.send_outlined : Icons.inbox_outlined,
                  size: 18,
                  color: colors.primary,
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    showRecipient
                        ? 'To: ${feedback.toLearnerId}'
                        : 'From: ${feedback.fromLearnerId}',
                    style: theme.textTheme.labelMedium,
                  ),
                ),
                if (feedback.createdAt != null)
                  Text(
                    _formatDate(feedback.createdAt!),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: colors.outline),
                  ),
              ],
            ),
            const SizedBox(height: 8.0),

            // Rating stars
            if (feedback.rating != null)
              Row(
                children: List<Widget>.generate(5, (int index) {
                  return Icon(
                    index < feedback.rating!
                        ? Icons.star
                        : Icons.star_border,
                    color: index < feedback.rating!
                        ? Colors.amber
                        : colors.outline,
                    size: 20,
                  );
                }),
              ),
            const SizedBox(height: 8.0),

            // Strengths
            if (feedback.strengths != null &&
                feedback.strengths!.isNotEmpty) ...<Widget>[
              Text('Strengths:',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4.0),
              Text(feedback.strengths!, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8.0),
            ],

            // Suggestions
            if (feedback.suggestions != null &&
                feedback.suggestions!.isNotEmpty) ...<Widget>[
              Text('Suggestions:',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4.0),
              Text(feedback.suggestions!,
                  style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    final DateTime dt = timestamp.toDate();
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
