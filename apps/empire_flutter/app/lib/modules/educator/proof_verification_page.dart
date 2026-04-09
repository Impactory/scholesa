import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/app_state.dart';
import '../../i18n/evidence_chain_i18n.dart';
import '../../services/firestore_service.dart';

/// Educator reviews and verifies learner proof-of-learning bundles.
/// Shows unverified proof bundles with their ExplainItBack / OralCheck / MiniRebuild
/// status and allows verification or revision requests.
class ProofVerificationPage extends StatefulWidget {
  const ProofVerificationPage({super.key});

  @override
  State<ProofVerificationPage> createState() => _ProofVerificationPageState();
}

class _ProofVerificationPageState extends State<ProofVerificationPage> {
  List<Map<String, dynamic>> _pendingBundles = <Map<String, dynamic>>[];
  bool _isLoading = true;
  String? _error;

  FirestoreService get _firestoreService => context.read<FirestoreService>();

  String _t(String input) => EvidenceChainI18n.text(context, input);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPendingBundles();
    });
  }

  Future<void> _loadPendingBundles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Load bundles that are not yet verified
      final List<Map<String, dynamic>> partial =
          await _firestoreService.queryCollection(
        'proofOfLearningBundles',
        where: <List<dynamic>>[
          <dynamic>['verificationStatus', 'partial'],
        ],
        orderBy: 'createdAt',
        descending: true,
      );
      final List<Map<String, dynamic>> missing =
          await _firestoreService.queryCollection(
        'proofOfLearningBundles',
        where: <List<dynamic>>[
          <dynamic>['verificationStatus', 'missing'],
        ],
        orderBy: 'createdAt',
        descending: true,
      );

      setState(() {
        _pendingBundles = <Map<String, dynamic>>[...partial, ...missing];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load proof bundles: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyBundle(Map<String, dynamic> bundle) async {
    final AppState appState = context.read<AppState>();
    final String educatorId = appState.userId ?? '';
    final String bundleId = bundle['id'] as String? ?? '';

    if (educatorId.isEmpty || bundleId.isEmpty) return;

    try {
      await _firestoreService.verifyProofOfLearning(
        bundleId: bundleId,
        educatorId: educatorId,
        verificationStatus: 'verified',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Proof of learning verified.'))),
      );
      await _loadPendingBundles();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_t('Error verifying proof:')} $e')),
      );
    }
  }

  Future<void> _requestRevision(Map<String, dynamic> bundle) async {
    final String bundleId = bundle['id'] as String? ?? '';
    if (bundleId.isEmpty) return;

    try {
      await _firestoreService.updateDocument(
        'proofOfLearningBundles',
        bundleId,
        <String, dynamic>{'verificationStatus': 'revision_requested'},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Revision requested.'))),
      );
      await _loadPendingBundles();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_t('Error requesting revision:')} $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('Verify Proof of Learning')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                      const SizedBox(height: 12),
                      Text(_error!, style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _loadPendingBundles,
                        icon: const Icon(Icons.refresh),
                        label: Text(_t('Retry')),
                      ),
                    ],
                  ),
                )
              : _pendingBundles.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.verified_outlined,
                              size: 48, color: theme.colorScheme.primary),
                          const SizedBox(height: 12),
                          Text(_t('All proof bundles have been verified.'),
                              style: theme.textTheme.bodyLarge),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadPendingBundles,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _pendingBundles.length,
                        itemBuilder: (BuildContext context, int index) {
                          return _buildBundleCard(_pendingBundles[index]);
                        },
                      ),
                    ),
    );
  }

  Widget _buildBundleCard(Map<String, dynamic> bundle) {
    final ThemeData theme = Theme.of(context);
    final String learnerName =
        bundle['learnerName'] as String? ?? bundle['learnerId'] as String? ?? 'Unknown';
    final String portfolioItemTitle =
        bundle['portfolioItemTitle'] as String? ??
            bundle['portfolioItemId'] as String? ??
            'Portfolio Item';
    final String status = bundle['verificationStatus'] as String? ?? 'missing';
    final bool hasEIB = bundle['hasExplainItBack'] as bool? ?? false;
    final bool hasOC = bundle['hasOralCheck'] as bool? ?? false;
    final bool hasMR = bundle['hasMiniRebuild'] as bool? ?? false;
    final String? eibExcerpt = bundle['explainItBackExcerpt'] as String?;
    final String? ocExcerpt = bundle['oralCheckExcerpt'] as String?;
    final String? mrExcerpt = bundle['miniRebuildExcerpt'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(learnerName, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(portfolioItemTitle, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
                _StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 12),
            // Proof method checklist
            _ProofMethodRow(
              label: _t('Explain-It-Back'),
              completed: hasEIB,
              excerpt: eibExcerpt,
            ),
            _ProofMethodRow(
              label: _t('Oral Check'),
              completed: hasOC,
              excerpt: ocExcerpt,
            ),
            _ProofMethodRow(
              label: _t('Mini Rebuild'),
              completed: hasMR,
              excerpt: mrExcerpt,
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                FilledButton.icon(
                  onPressed: () => _verifyBundle(bundle),
                  icon: const Icon(Icons.verified, size: 18),
                  label: Text(_t('Verify')),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _requestRevision(bundle),
                  icon: const Icon(Icons.edit_note, size: 18),
                  label: Text(_t('Request Revision')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color textColor;
    switch (status) {
      case 'partial':
        bgColor = Colors.orange.shade50;
        textColor = Colors.orange.shade700;
      case 'missing':
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
      default:
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
      ),
    );
  }
}

class _ProofMethodRow extends StatelessWidget {
  const _ProofMethodRow({
    required this.label,
    required this.completed,
    this.excerpt,
  });

  final String label;
  final bool completed;
  final String? excerpt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            completed ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 20,
            color: completed ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: completed ? null : Colors.grey,
                  ),
                ),
                if (excerpt != null && excerpt!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      excerpt!,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
