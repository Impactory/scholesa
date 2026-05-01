import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/app_state.dart';
import '../../domain/models.dart';
import '../../i18n/evidence_chain_i18n.dart';
import '../../services/firestore_service.dart';

/// Learner Reflection Journal Page - Metacognitive reflections on learning.
class ReflectionJournalPage extends StatefulWidget {
  const ReflectionJournalPage({super.key});

  @override
  State<ReflectionJournalPage> createState() => _ReflectionJournalPageState();
}

class _ReflectionJournalPageState extends State<ReflectionJournalPage> {
  List<ReflectionEntryModel> _reflections = const <ReflectionEntryModel>[];
  bool _isLoading = false;
  String? _loadError;
  bool _showNewForm = false;
  bool _isSubmitting = false;

  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _responseController = TextEditingController();
  final TextEditingController _aiDetailsController = TextEditingController();
  double _engagementRating = 3.0;
  double _confidenceRating = 3.0;
  bool _aiUsed = false;

  static const List<String> _reflectionPrompts = <String>[
    'What did I learn today that surprised me?',
    'What was the hardest part of today and how did I handle it?',
    'What would I do differently next time?',
    'How did I help someone else learn today?',
    'What am I most proud of from this session?',
  ];

  String _t(String input) => EvidenceChainI18n.text(context, input);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReflections());
  }

  @override
  void dispose() {
    _promptController.dispose();
    _responseController.dispose();
    _aiDetailsController.dispose();
    super.dispose();
  }

  String _learnerId(AppState appState) => appState.userId?.trim() ?? '';

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

  Future<void> _loadReflections() async {
    final AppState appState = context.read<AppState>();
    final FirestoreService? service = _maybeFirestoreService();
    final String learnerId = _learnerId(appState);
    final String siteId = _siteId(appState);

    if (service == null || learnerId.isEmpty || siteId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Reflection data unavailable right now.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await service
          .firestore
          .collection('learnerReflections')
          .where('learnerId', isEqualTo: learnerId)
          .where('siteId', isEqualTo: siteId)
          .orderBy('createdAt', descending: true)
          .get();

      final List<ReflectionEntryModel> reflections = snapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              ReflectionEntryModel.fromDoc(doc))
          .toList();

      if (!mounted) return;
      setState(() {
        _reflections = reflections;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load reflections. Tap to retry.';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitReflection() async {
    final String prompt = _promptController.text.trim();
    final String response = _responseController.text.trim();

    if (prompt.isEmpty || response.isEmpty) {
      _showSnackBar(_t('Please fill in both the prompt and your reflection.'),
          isError: true);
      return;
    }

    final AppState appState = context.read<AppState>();
    final FirestoreService? service = _maybeFirestoreService();
    final String learnerId = _learnerId(appState);
    final String siteId = _siteId(appState);

    if (service == null || learnerId.isEmpty || siteId.isEmpty) {
      _showSnackBar(_t('Unable to submit reflection.'), isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await service.submitReflection(
        learnerId: learnerId,
        siteId: siteId,
        prompt: prompt,
        response: response,
        engagementRating: _engagementRating.round(),
        confidenceRating: _confidenceRating.round(),
        aiAssistanceUsed: _aiUsed,
        aiAssistanceDetails: _aiUsed ? _aiDetailsController.text.trim() : null,
      );
      _promptController.clear();
      _responseController.clear();
      _aiDetailsController.clear();
      setState(() {
        _engagementRating = 3.0;
        _confidenceRating = 3.0;
        _aiUsed = false;
        _showNewForm = false;
      });
      _showSnackBar(_t('Reflection saved!'));
      await _loadReflections();
    } catch (e) {
      _showSnackBar(_t('Failed to save reflection.'), isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('Reflection Journal')),
      ),
      floatingActionButton: _showNewForm
          ? null
          : FloatingActionButton.extended(
              onPressed: () => setState(() => _showNewForm = true),
              icon: const Icon(Icons.add),
              label: Text(_t('New Reflection')),
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: InkWell(
                    onTap: _loadReflections,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        _t(_loadError!),
                        style: theme.textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadReflections,
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: <Widget>[
                      if (_showNewForm) ...<Widget>[
                        _buildNewReflectionForm(theme, colors),
                        const SizedBox(height: 16.0),
                      ],
                      if (_reflections.isEmpty && !_showNewForm)
                        Padding(
                          padding: const EdgeInsets.only(top: 48.0),
                          child: Center(
                            child: Text(
                              _t('No reflections yet. Tap + to write your first one.'),
                              style: theme.textTheme.bodyLarge,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ..._reflections
                          .map((ReflectionEntryModel reflection) => Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: _buildReflectionCard(
                                    reflection, theme, colors),
                              )),
                    ],
                  ),
                ),
    );
  }

  Widget _buildNewReflectionForm(ThemeData theme, ColorScheme colors) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  _t('New Reflection'),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => setState(() => _showNewForm = false),
                  icon: const Icon(Icons.close),
                  tooltip: _t('Cancel'),
                ),
              ],
            ),
            const SizedBox(height: 12.0),

            // Prompt selection
            Text(_t('Prompt'), style: theme.textTheme.labelLarge),
            const SizedBox(height: 4.0),
            TextField(
              controller: _promptController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: _t('What are you reflecting on?'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8.0),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: _reflectionPrompts
                  .map((String prompt) => ActionChip(
                        label: Text(
                          () {
                            final String translated = _t(prompt);
                            return translated.length > 35
                                ? '${translated.substring(0, 35)}...'
                                : translated;
                          }(),
                          style: theme.textTheme.labelSmall,
                        ),
                        onPressed: () => _promptController.text = _t(prompt),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16.0),

            // Response
            Text(_t('Your Reflection'), style: theme.textTheme.labelLarge),
            const SizedBox(height: 4.0),
            TextField(
              controller: _responseController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: _t('Write your thoughts...'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16.0),

            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _aiUsed,
              onChanged: (bool? value) =>
                  setState(() => _aiUsed = value ?? false),
              title: Text(_t('I used AI tools to help with this reflection')),
            ),
            if (_aiUsed) ...<Widget>[
              const SizedBox(height: 8.0),
              TextField(
                controller: _aiDetailsController,
                decoration: InputDecoration(
                  hintText: _t('Which AI tools did you use? (optional)'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16.0),
            ],

            // Engagement rating
            Text('${_t('Engagement')}: ${_engagementRating.round()}/5',
                style: theme.textTheme.labelLarge),
            Slider(
              value: _engagementRating,
              min: 1,
              max: 5,
              divisions: 4,
              label: _engagementRating.round().toString(),
              onChanged: (double value) =>
                  setState(() => _engagementRating = value),
            ),

            // Confidence rating
            Text('${_t('Confidence')}: ${_confidenceRating.round()}/5',
                style: theme.textTheme.labelLarge),
            Slider(
              value: _confidenceRating,
              min: 1,
              max: 5,
              divisions: 4,
              label: _confidenceRating.round().toString(),
              onChanged: (double value) =>
                  setState(() => _confidenceRating = value),
            ),
            const SizedBox(height: 12.0),

            // Submit
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _isSubmitting ? null : _submitReflection,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save, size: 18),
                label: Text(_t('Save Reflection')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReflectionCard(
    ReflectionEntryModel reflection,
    ThemeData theme,
    ColorScheme colors,
  ) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Date and ratings row
            Row(
              children: <Widget>[
                if (reflection.createdAt != null)
                  Text(
                    _formatDate(reflection.createdAt!),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: colors.outline),
                  ),
                const Spacer(),
                if (reflection.engagementRating != null)
                  _buildRatingChip(
                    _t('Engagement'),
                    reflection.engagementRating!,
                    colors,
                    theme,
                  ),
                const SizedBox(width: 8.0),
                if (reflection.confidenceRating != null)
                  _buildRatingChip(
                    _t('Confidence'),
                    reflection.confidenceRating!,
                    colors,
                    theme,
                  ),
              ],
            ),
            const SizedBox(height: 8.0),

            // Prompt
            Text(
              reflection.prompt,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8.0),

            // Response
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                reflection.response,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            if (reflection.aiAssistanceUsed != null ||
                (reflection.aiAssistanceDetails?.trim().isNotEmpty ??
                    false)) ...<Widget>[
              const SizedBox(height: 8.0),
              Text(
                reflection.aiAssistanceUsed == true
                    ? _t('AI support was disclosed for this reflection.')
                    : _t(
                        'Learner declared no AI support was used for this reflection.'),
                style: theme.textTheme.bodySmall,
              ),
              if (reflection.aiAssistanceDetails?.trim().isNotEmpty ?? false)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    '${_t('AI details')}: ${reflection.aiAssistanceDetails!.trim()}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
            if (_hasProvenance(reflection)) ...<Widget>[
              const SizedBox(height: 10.0),
              _buildProvenanceChips(reflection, colors, theme),
            ],
          ],
        ),
      ),
    );
  }

  bool _hasProvenance(ReflectionEntryModel reflection) {
    return (reflection.missionId?.trim().isNotEmpty ?? false) ||
        (reflection.portfolioItemId?.trim().isNotEmpty ?? false) ||
        (reflection.sessionId?.trim().isNotEmpty ?? false);
  }

  Widget _buildProvenanceChips(
    ReflectionEntryModel reflection,
    ColorScheme colors,
    ThemeData theme,
  ) {
    final List<String> labels = <String>[
      if (reflection.missionId?.trim().isNotEmpty ?? false)
        _t('Mission-linked reflection'),
      if (reflection.portfolioItemId?.trim().isNotEmpty ?? false)
        _t('Portfolio-linked reflection'),
      if (reflection.sessionId?.trim().isNotEmpty ?? false)
        _t('Session-linked reflection'),
    ];

    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: labels
          .map(
            (String label) => Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
              decoration: BoxDecoration(
                color: colors.secondaryContainer.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.7),
                ),
              ),
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSecondaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildRatingChip(
    String label,
    int value,
    ColorScheme colors,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Text(
        '$label: $value/5',
        style: theme.textTheme.labelSmall
            ?.copyWith(color: colors.onPrimaryContainer),
      ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    final DateTime dt = timestamp.toDate();
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
