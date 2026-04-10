import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/app_state.dart';
import '../../domain/models.dart';
import '../../i18n/evidence_chain_i18n.dart';
import '../../services/firestore_service.dart';

/// Learner Proof Assembly Page - Assemble proof-of-learning bundles for portfolio items.
class ProofAssemblyPage extends StatefulWidget {
  const ProofAssemblyPage({super.key});

  @override
  State<ProofAssemblyPage> createState() => _ProofAssemblyPageState();
}

class _ProofAssemblyPageState extends State<ProofAssemblyPage> {
  List<PortfolioItemModel> _portfolioItems = const <PortfolioItemModel>[];
  Map<String, ProofOfLearningBundleModel> _proofBundles =
      const <String, ProofOfLearningBundleModel>{};
  bool _isLoading = false;
  String? _loadError;

  /// Tracks which portfolio item is expanded for proof assembly.
  final Set<String> _expandedItems = <String>{};

  /// Controllers for explain-it-back excerpts, keyed by portfolio item id.
  final Map<String, TextEditingController> _explainControllers =
      <String, TextEditingController>{};

  /// Controllers for mini-rebuild excerpts, keyed by portfolio item id.
  final Map<String, TextEditingController> _rebuildControllers =
      <String, TextEditingController>{};

  /// Controllers for oral check notes, keyed by portfolio item id.
  final Map<String, TextEditingController> _oralControllers =
      <String, TextEditingController>{};

  /// Tracks which items are currently being submitted.
  final Set<String> _submitting = <String>{};

  String _t(String input) => EvidenceChainI18n.text(context, input);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    for (final TextEditingController c in _explainControllers.values) {
      c.dispose();
    }
    for (final TextEditingController c in _rebuildControllers.values) {
      c.dispose();
    }
    for (final TextEditingController c in _oralControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _learnerId(AppState appState) =>
      appState.userId?.trim() ?? '';

  FirestoreService? _maybeFirestoreService() {
    try {
      return context.read<FirestoreService>();
    } catch (_) {
      return null;
    }
  }

  TextEditingController _explainController(String id) {
    return _explainControllers.putIfAbsent(
        id, () => TextEditingController());
  }

  TextEditingController _rebuildController(String id) {
    return _rebuildControllers.putIfAbsent(
        id, () => TextEditingController());
  }

  TextEditingController _oralController(String id) {
    return _oralControllers.putIfAbsent(
        id, () => TextEditingController());
  }

  Future<void> _loadData() async {
    final AppState appState = context.read<AppState>();
    final FirestoreService? service = _maybeFirestoreService();
    final String learnerId = _learnerId(appState);

    if (service == null || learnerId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Portfolio data unavailable right now.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      // Load portfolio items and proof bundles in parallel.
      final List<Object> results = await Future.wait(<Future<Object>>[
        service.firestore
            .collection('portfolioItems')
            .where('learnerId', isEqualTo: learnerId)
            .orderBy('createdAt', descending: true)
            .get(),
        service.firestore
            .collection('proofOfLearningBundles')
            .where('learnerId', isEqualTo: learnerId)
            .get(),
      ]);

      final QuerySnapshot<Map<String, dynamic>> itemsSnapshot =
          results[0] as QuerySnapshot<Map<String, dynamic>>;
      final QuerySnapshot<Map<String, dynamic>> bundlesSnapshot =
          results[1] as QuerySnapshot<Map<String, dynamic>>;

      final List<PortfolioItemModel> items = itemsSnapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              PortfolioItemModel.fromDoc(doc))
          .toList();

      final Map<String, ProofOfLearningBundleModel> bundles =
          <String, ProofOfLearningBundleModel>{};
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in bundlesSnapshot.docs) {
        final ProofOfLearningBundleModel bundle =
            ProofOfLearningBundleModel.fromDoc(doc);
        bundles[bundle.portfolioItemId] = bundle;
      }

      // Pre-populate controllers with existing excerpts.
      for (final PortfolioItemModel item in items) {
        final ProofOfLearningBundleModel? bundle = bundles[item.id];
        if (bundle != null) {
          if (bundle.explainItBackExcerpt != null &&
              bundle.explainItBackExcerpt!.isNotEmpty) {
            _explainController(item.id).text = bundle.explainItBackExcerpt!;
          }
          if (bundle.miniRebuildExcerpt != null &&
              bundle.miniRebuildExcerpt!.isNotEmpty) {
            _rebuildController(item.id).text = bundle.miniRebuildExcerpt!;
          }
          if (bundle.oralCheckExcerpt != null &&
              bundle.oralCheckExcerpt!.isNotEmpty) {
            _oralController(item.id).text = bundle.oralCheckExcerpt!;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _portfolioItems = items;
        _proofBundles = bundles;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load portfolio items. Tap to retry.';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitProof(PortfolioItemModel item) async {
    final AppState appState = context.read<AppState>();
    final FirestoreService? service = _maybeFirestoreService();
    final String learnerId = _learnerId(appState);

    if (service == null || learnerId.isEmpty) {
      _showSnackBar(_t('Unable to save proof bundle.'), isError: true);
      return;
    }

    final String explainText = _explainController(item.id).text.trim();
    final String rebuildText = _rebuildController(item.id).text.trim();
    final String oralText = _oralController(item.id).text.trim();

    setState(() => _submitting.add(item.id));

    try {
      final ProofOfLearningBundleModel? existing = _proofBundles[item.id];

      if (existing != null) {
        // Update existing bundle.
        await service.updateProofOfLearningBundle(
          bundleId: existing.id,
          hasExplainItBack: explainText.isNotEmpty,
          hasMiniRebuild: rebuildText.isNotEmpty,
          hasOralCheck: oralText.isNotEmpty,
          explainItBackExcerpt:
              explainText.isNotEmpty ? explainText : null,
          oralCheckExcerpt:
              oralText.isNotEmpty ? oralText : null,
          miniRebuildExcerpt:
              rebuildText.isNotEmpty ? rebuildText : null,
        );
      } else {
        // Create new bundle, then update with content.
        final String bundleId = await service.createProofOfLearningBundle(
          learnerId: learnerId,
          portfolioItemId: item.id,
        );
        if (explainText.isNotEmpty || rebuildText.isNotEmpty || oralText.isNotEmpty) {
          await service.updateProofOfLearningBundle(
            bundleId: bundleId,
            hasExplainItBack: explainText.isNotEmpty,
            hasMiniRebuild: rebuildText.isNotEmpty,
            hasOralCheck: oralText.isNotEmpty,
            explainItBackExcerpt:
                explainText.isNotEmpty ? explainText : null,
            oralCheckExcerpt:
                oralText.isNotEmpty ? oralText : null,
            miniRebuildExcerpt:
                rebuildText.isNotEmpty ? rebuildText : null,
          );
        }
      }

      _showSnackBar(_t('Proof bundle saved!'));
      await _loadData();
    } catch (e) {
      _showSnackBar(_t('Failed to save proof bundle.'), isError: true);
    } finally {
      if (mounted) setState(() => _submitting.remove(item.id));
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
        title: Text(_t('Proof of Learning')),
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
                        _t(_loadError!),
                        style: theme.textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              : _portfolioItems.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          _t('No portfolio items yet. Add items to your portfolio to assemble proof.'),
                          style: theme.textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _portfolioItems.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12.0),
                        itemBuilder: (BuildContext context, int index) {
                          return _buildPortfolioProofCard(
                              _portfolioItems[index], theme, colors);
                        },
                      ),
                    ),
    );
  }

  Widget _buildPortfolioProofCard(
    PortfolioItemModel item,
    ThemeData theme,
    ColorScheme colors,
  ) {
    final ProofOfLearningBundleModel? bundle = _proofBundles[item.id];
    final String status = bundle?.verificationStatus ?? 'missing';
    final bool isExpanded = _expandedItems.contains(item.id);

    final Color statusColor = switch (status) {
      'verified' => colors.primary,
      'partial' => colors.tertiary,
      _ => colors.outline,
    };

    final IconData statusIcon = switch (status) {
      'verified' => Icons.verified,
      'partial' => Icons.pending,
      _ => Icons.help_outline,
    };

    return Card(
      elevation: 1,
      child: Column(
        children: <Widget>[
          // Header - tap to expand
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedItems.remove(item.id);
                } else {
                  _expandedItems.add(item.id);
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.title,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (item.description != null &&
                            item.description!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              item.description!,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: colors.onSurfaceVariant),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 4.0),
                        Text(
                          status[0].toUpperCase() + status.substring(1),
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: statusColor),
                        ),
                      ],
                    ),
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

          // Expanded proof assembly form
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Divider(),
                  const SizedBox(height: 8.0),

                  // Verification method indicators
                  _buildMethodIndicator(
                    _t('Explain-It-Back'),
                    bundle?.hasExplainItBack ?? false,
                    Icons.lightbulb_outline,
                    theme,
                    colors,
                  ),
                  _buildMethodIndicator(
                    _t('Oral Check'),
                    bundle?.hasOralCheck ?? false,
                    Icons.mic,
                    theme,
                    colors,
                  ),
                  _buildMethodIndicator(
                    _t('Mini Rebuild'),
                    bundle?.hasMiniRebuild ?? false,
                    Icons.build_outlined,
                    theme,
                    colors,
                  ),
                  const SizedBox(height: 16.0),

                  // Explain-it-Back section
                  Text(
                    _t('Explain-It-Back'),
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    _t('Explain what you learned and how you did this work in your own words.'),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8.0),
                  TextField(
                    controller: _explainController(item.id),
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: _t('I learned that...'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16.0),

                  // Oral Check section
                  Text(
                    _t('Oral Check'),
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    _t('Say it out loud, then write what you said.'),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8.0),
                  TextField(
                    controller: _oralController(item.id),
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: _t('When I explain this out loud, I say...'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16.0),

                  // Mini Rebuild section
                  Text(
                    _t('Mini Rebuild'),
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    _t('Describe how you would rebuild or remix this work from scratch.'),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8.0),
                  TextField(
                    controller: _rebuildController(item.id),
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: _t('If I were to rebuild this, I would...'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16.0),

                  // Submit button
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _submitting.contains(item.id)
                          ? null
                          : () => _submitProof(item),
                      icon: _submitting.contains(item.id)
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : const Icon(Icons.save, size: 18),
                      label: Text(
                        bundle != null ? _t('Update Proof') : _t('Save Proof'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMethodIndicator(
    String label,
    bool completed,
    IconData icon,
    ThemeData theme,
    ColorScheme colors,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: <Widget>[
          Icon(
            completed ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: completed ? colors.primary : colors.outline,
          ),
          const SizedBox(width: 8.0),
          Icon(icon, size: 16, color: colors.onSurfaceVariant),
          const SizedBox(width: 4.0),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: completed ? colors.primary : colors.onSurfaceVariant,
              fontWeight: completed ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
