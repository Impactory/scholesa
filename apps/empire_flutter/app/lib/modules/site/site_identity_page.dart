import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:provider/provider.dart';

import '../../auth/app_state.dart';
import '../../i18n/site_surface_i18n.dart';
import '../../services/telemetry_service.dart';
import '../../ui/auth/global_session_menu.dart';
import '../../ui/theme/scholesa_theme.dart';

String _tSiteIdentity(BuildContext context, String input) {
  return SiteSurfaceI18n.text(context, input);
}

/// Site identity resolution page
/// Based on docs/46_IDENTITY_MATCHING_RESOLUTION_SPEC.md
class SiteIdentityPage extends StatefulWidget {
  const SiteIdentityPage({
    super.key,
    this.identityLoader,
    this.identityResolver,
  });

  final Future<List<Map<String, dynamic>>> Function(String siteId)?
      identityLoader;
  final Future<void> Function(
    String id,
    String rawProvider,
    String decision,
    String? suggestedUserId,
  )? identityResolver;

  @override
  State<SiteIdentityPage> createState() => _SiteIdentityPageState();
}

class _SiteIdentityPageState extends State<SiteIdentityPage> {
  List<_IdentityMatch> _pendingMatches = <_IdentityMatch>[];
  bool _isLoading = false;
  String? _loadError;
  String? _loadErrorDetail;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPendingMatches();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: Text(_tSiteIdentity(context, 'Identity Resolution')),
        backgroundColor: const Color(0xFF64748B),
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            tooltip: _tSiteIdentity(context, 'Refresh'),
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshPendingMatches,
          ),
          const SessionMenuButton(
            foregroundColor: Colors.white,
          ),
        ],
      ),
      body: _isLoading && _pendingMatches.isEmpty
          ? Center(
              child: Text(
                _tSiteIdentity(context, 'Loading...'),
                style: const TextStyle(color: ScholesaColors.textSecondary),
              ),
            )
          : _loadError != null && _pendingMatches.isEmpty
              ? _buildLoadErrorState(
                  _tSiteIdentity(
                      context, 'Identity matches are temporarily unavailable'),
                  _loadError!,
                )
              : _pendingMatches.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: <Widget>[
                        if (_loadError != null)
                          _buildStaleDataBanner(
                            _tSiteIdentity(context,
                                    'Unable to refresh identity matches right now. Showing the last successful data.') +
                                (_loadErrorDetail == null ||
                                        _loadErrorDetail!.trim().isEmpty
                                    ? ''
                                    : ' ${_loadErrorDetail!.trim()}'),
                          ),
                        _buildHeader(),
                        const SizedBox(height: 16),
                        ..._pendingMatches
                            .map((match) => _buildMatchCard(match)),
                      ],
                    ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF64748B).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFF64748B).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.info_outline_rounded, color: Color(0xFF64748B)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _tSiteIdentity(context,
                  'Review and confirm matches between local accounts and external provider accounts.'),
              style: const TextStyle(
                fontSize: 13,
                color: ScholesaColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer.withValues(alpha: 0.72),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              size: 64,
              color: scheme.secondary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _tSiteIdentity(context, 'All Identities Resolved'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ScholesaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _tSiteIdentity(context, 'No pending identity matches to review'),
            style: const TextStyle(
              fontSize: 14,
              color: ScholesaColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadErrorState(String title, String message) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: scheme.error.withValues(alpha: 0.76),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ScholesaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: ScholesaColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _retryLoadPendingMatches,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(_tSiteIdentity(context, 'Retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaleDataBanner(String message) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      liveRegion: true,
      label: message,
      child: ExcludeSemantics(
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.tertiaryContainer.withValues(alpha: 0.56),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.tertiary.withValues(alpha: 0.36)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.warning_amber_rounded, color: scheme.tertiary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: context.schTextPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchCard(_IdentityMatch match) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _buildProviderIcon(match.provider),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        match.provider,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: ScholesaColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatConfidenceLabel(context, match.confidence),
                        style: TextStyle(
                          fontSize: 12,
                          color: _getConfidenceColor(match.confidence),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildConfidenceIndicator(match.confidence),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: _buildIdentityColumn(
                      _tSiteIdentity(context, 'Local Account'),
                      match.localName,
                      Icons.person_rounded),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF64748B).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.compare_arrows_rounded,
                      size: 20, color: Color(0xFF64748B)),
                ),
                Expanded(
                  child: _buildIdentityColumn(
                      _tSiteIdentity(context, 'External Account'),
                      match.externalName,
                      Icons.cloud_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleIgnore(match),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    child: Text(_tSiteIdentity(context, 'Ignore')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleApprove(match),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor:
                          Theme.of(context).colorScheme.onSecondary,
                    ),
                    child: Text(_tSiteIdentity(context, 'Approve Match')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderIcon(String provider) {
    IconData icon;
    Color color;
    switch (provider.toLowerCase()) {
      case 'google classroom':
        icon = Icons.school_rounded;
        color = Colors.blue;
        break;
      case 'clever':
        icon = Icons.apartment_rounded;
        color = Colors.orange;
        break;
      case 'classlink':
        icon = Icons.hub_rounded;
        color = Colors.purple;
        break;
      case 'github':
        icon = Icons.code_rounded;
        color = Colors.black87;
        break;
      default:
        icon = Icons.cloud_rounded;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildIdentityColumn(String label, String name, IconData icon) {
    return Column(
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: ScholesaColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Icon(icon, color: ScholesaColors.textSecondary, size: 24),
        const SizedBox(height: 4),
        Text(
          name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatConfidenceLabel(BuildContext context, double? confidence) {
    if (confidence == null) {
      return _tSiteIdentity(context, 'Match confidence unavailable');
    }
    return '${_tSiteIdentity(context, 'Match confidence:')} ${(confidence * 100).toInt()}%';
  }

  Widget _buildConfidenceIndicator(double? confidence) {
    if (confidence == null) {
      return Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.grey.withValues(alpha: 0.45),
            width: 2,
          ),
        ),
        child: const Text(
          '?',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            value: confidence,
            backgroundColor: Colors.grey.withValues(alpha: 0.2),
            valueColor:
                AlwaysStoppedAnimation<Color>(_getConfidenceColor(confidence)),
            strokeWidth: 4,
          ),
        ),
        Text(
          '${(confidence * 100).toInt()}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: _getConfidenceColor(confidence),
          ),
        ),
      ],
    );
  }

  Color _getConfidenceColor(double? confidence) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    if (confidence == null) return scheme.onSurfaceVariant;
    if (confidence >= 0.9) return scheme.secondary;
    if (confidence >= 0.7) return scheme.tertiary;
    return scheme.error;
  }

  Future<void> _handleApprove(_IdentityMatch match) async {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'site_identity',
        'cta_id': 'approve_identity_match',
        'surface': 'identity_match_card',
        'match_id': match.id,
        'provider': match.provider,
      },
    );
    try {
      await _resolveMatch(match, 'link');
      if (!mounted) return;
      final bool reloaded = await _loadPendingMatches();
      if (!mounted) return;
      final bool removedFromQueue =
          !_pendingMatches.any((_IdentityMatch m) => m.id == match.id);
      if (!reloaded) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_tSiteIdentity(
              context,
              'Match update was submitted, but the queue could not be reloaded. Retry to verify the current state.',
            )),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
          ),
        );
        return;
      }
      if (!removedFromQueue) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_tSiteIdentity(
              context,
              'The identity queue did not update after save. Retry to verify the current state.',
            )),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${_tSiteIdentity(context, 'Matched')} ${match.localName} ${_tSiteIdentity(context, 'with')} ${match.externalName}'),
          backgroundColor: Theme.of(context).colorScheme.secondary,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tSiteIdentity(context, 'Match update failed')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _handleIgnore(_IdentityMatch match) async {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'site_identity',
        'cta_id': 'ignore_identity_match',
        'surface': 'identity_match_card',
        'match_id': match.id,
        'provider': match.provider,
      },
    );
    try {
      await _resolveMatch(match, 'ignore');
      if (!mounted) return;
      final bool reloaded = await _loadPendingMatches();
      if (!mounted) return;
      final bool removedFromQueue =
          !_pendingMatches.any((_IdentityMatch m) => m.id == match.id);
      if (!reloaded) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_tSiteIdentity(
              context,
              'Match update was submitted, but the queue could not be reloaded. Retry to verify the current state.',
            )),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
          ),
        );
        return;
      }
      if (!removedFromQueue) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_tSiteIdentity(
              context,
              'The identity queue did not update after save. Retry to verify the current state.',
            )),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tSiteIdentity(context, 'Match ignored')),
          backgroundColor: Theme.of(context).colorScheme.inverseSurface,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tSiteIdentity(context, 'Match update failed')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _refreshPendingMatches() async {
    await _loadPendingMatches();
  }

  Future<void> _retryLoadPendingMatches() async {
    await _loadPendingMatches(clearStaleState: true);
  }

  Future<bool> _loadPendingMatches({bool clearStaleState = false}) async {
    final AppState appState = context.read<AppState>();
    final String siteId = (appState.activeSiteId ??
            (appState.siteIds.isNotEmpty ? appState.siteIds.first : ''))
        .trim();

    if (!mounted) return false;
    setState(() {
      _isLoading = true;
      if (clearStaleState || _pendingMatches.isEmpty) {
        _loadError = null;
        _loadErrorDetail = null;
      }
    });

    try {
      if (siteId.isEmpty) {
        if (!mounted) return false;
        setState(() {
          _pendingMatches = <_IdentityMatch>[];
          _loadError = null;
          _loadErrorDetail = null;
        });
        return true;
      }

      final List<dynamic> rows = widget.identityLoader != null
          ? await widget.identityLoader!(siteId)
          : await _fetchIdentityRows(siteId);
      final List<_IdentityMatch> loaded = rows
          .whereType<Map<dynamic, dynamic>>()
          .map((Map<dynamic, dynamic> row) => row.map(
              (dynamic key, dynamic value) => MapEntry(key.toString(), value)))
          .where((Map<String, dynamic> data) =>
              ((data['status'] as String?) ?? '').toLowerCase() == 'unmatched')
          .map((Map<String, dynamic> data) {
        final String localName =
            (data['scholesaUserName'] as String?)?.trim().isNotEmpty == true
                ? (data['scholesaUserName'] as String).trim()
                : _tSiteIdentity(context, 'Local account unavailable');
        final String externalName =
            (data['providerUserId'] as String?)?.trim().isNotEmpty == true
                ? (data['providerUserId'] as String).trim()
                : _tSiteIdentity(context, 'External account unavailable');
        final num? rawConfidence = data['confidence'] as num?;
        final double? confidence = rawConfidence == null
            ? null
            : _normalizeConfidence(rawConfidence.toDouble());
        return _IdentityMatch(
          id: (data['id'] as String?) ?? '',
          localName: localName,
          externalName: externalName,
          provider: _providerLabel(
              (data['provider'] as String?) ?? 'google_classroom'),
          rawProvider: (data['provider'] as String?) ?? 'google_classroom',
          confidence: confidence,
          status: _MatchStatus.pending,
          suggestedUserId: (data['scholesaUserId'] as String?) ??
              (data['userId'] as String?),
        );
      }).toList();

      if (!mounted) return false;
      setState(() {
        _pendingMatches = loaded;
        _loadError = null;
        _loadErrorDetail = null;
      });
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() {
        _loadError = _tSiteIdentity(
          context,
          'We could not load the identity review queue. Retry to check the current state.',
        );
        _loadErrorDetail = error.toString();
      });
      return false;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _providerLabel(String rawProvider) {
    final String provider = rawProvider.trim().toLowerCase();
    if (provider.contains('github')) return 'GitHub';
    if (provider.contains('canvas')) return 'Canvas LMS';
    if (provider.contains('clever')) return 'Clever';
    if (provider.contains('classlink')) return 'ClassLink';
    return 'Google Classroom';
  }

  double? _normalizeConfidence(double value) {
    if (!value.isFinite) {
      return null;
    }
    return (value.clamp(0.0, 1.0) as num).toDouble();
  }

  Future<List<dynamic>> _fetchIdentityRows(String siteId) async {
    final HttpsCallable callable =
        FirebaseFunctions.instance.httpsCallable('listExternalIdentityLinks');
    final HttpsCallableResult<dynamic> result =
        await callable.call(<String, dynamic>{'siteId': siteId});
    final Map<String, dynamic> payload =
        Map<String, dynamic>.from(result.data as Map<dynamic, dynamic>);
    return payload['links'] as List<dynamic>? ?? <dynamic>[];
  }

  Future<void> _resolveMatch(_IdentityMatch match, String decision) async {
    if (widget.identityResolver != null) {
      await widget.identityResolver!(
        match.id,
        match.rawProvider,
        decision,
        match.suggestedUserId,
      );
      return;
    }

    final String provider = match.rawProvider.trim().toLowerCase();
    final bool hasSuggestedUser = match.suggestedUserId != null &&
        match.suggestedUserId!.trim().isNotEmpty;

    if (provider.contains('clever')) {
      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('resolveCleverIdentityLink');
      await callable.call(<String, dynamic>{
        'id': match.id,
        'decision': decision,
        if (decision == 'link' && hasSuggestedUser)
          'scholesaUserId': match.suggestedUserId,
      });
      return;
    }
    if (provider.contains('classlink')) {
      final HttpsCallable callable = FirebaseFunctions.instance
          .httpsCallable('resolveClassLinkIdentityLink');
      await callable.call(<String, dynamic>{
        'id': match.id,
        'decision': decision,
        if (decision == 'link' && hasSuggestedUser)
          'scholesaUserId': match.suggestedUserId,
      });
      return;
    }

    final HttpsCallable callable =
        FirebaseFunctions.instance.httpsCallable('resolveExternalIdentityLink');
    await callable.call(<String, dynamic>{
      'id': match.id,
      'status': decision == 'ignore' ? 'ignored' : 'linked',
    });
  }
}

// ignore: unused_field
enum _MatchStatus { pending, approved, rejected }

class _IdentityMatch {
  const _IdentityMatch({
    required this.id,
    required this.localName,
    required this.externalName,
    required this.provider,
    required this.rawProvider,
    required this.confidence,
    required this.status,
    this.suggestedUserId,
  });

  final String id;
  final String localName;
  final String externalName;
  final String provider;
  final String rawProvider;
  final double? confidence;
  final _MatchStatus status;
  final String? suggestedUserId;
}
