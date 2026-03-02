import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../auth/app_state.dart';
import '../../services/firestore_service.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';

const Map<String, String> _siteIdentityEs = <String, String>{
  'Identity Resolution': 'Resolución de identidad',
  'Review and confirm matches between local accounts and external provider accounts.':
      'Revisa y confirma coincidencias entre cuentas locales y cuentas de proveedores externos.',
  'All Identities Resolved': 'Todas las identidades resueltas',
  'No pending identity matches to review':
      'No hay coincidencias de identidad pendientes por revisar',
  'Match confidence:': 'Confianza de coincidencia:',
  'Local Account': 'Cuenta local',
  'External Account': 'Cuenta externa',
  'Ignore': 'Ignorar',
  'Approve Match': 'Aprobar coincidencia',
  'Matched': 'Emparejado',
  'with': 'con',
  'Match ignored': 'Coincidencia ignorada',
  'Loading...': 'Cargando...',
  'Unknown local account': 'Cuenta local desconocida',
  'Unknown external account': 'Cuenta externa desconocida',
  'Match update failed': 'Error al actualizar coincidencia',
};

String _tSiteIdentity(BuildContext context, String input) {
  final String locale = Localizations.localeOf(context).languageCode;
  if (locale != 'es') return input;
  return _siteIdentityEs[input] ?? input;
}

/// Site identity resolution page
/// Based on docs/46_IDENTITY_MATCHING_RESOLUTION_SPEC.md
class SiteIdentityPage extends StatefulWidget {
  const SiteIdentityPage({super.key});

  @override
  State<SiteIdentityPage> createState() => _SiteIdentityPageState();
}

class _SiteIdentityPageState extends State<SiteIdentityPage> {
  List<_IdentityMatch> _pendingMatches = <_IdentityMatch>[];
  bool _isLoading = false;

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
      ),
      body: _isLoading
          ? Center(
              child: Text(
                _tSiteIdentity(context, 'Loading...'),
                style: const TextStyle(color: ScholesaColors.textSecondary),
              ),
            )
          : _pendingMatches.isEmpty
          ? _buildEmptyState()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _buildHeader(),
                const SizedBox(height: 16),
                ..._pendingMatches.map((match) => _buildMatchCard(match)),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 64,
              color: Colors.green,
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
                        '${_tSiteIdentity(context, 'Match confidence:')} ${(match.confidence * 100).toInt()}%',
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
                  child: _buildIdentityColumn(_tSiteIdentity(context, 'Local Account'),
                      match.localName, Icons.person_rounded),
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
                      foregroundColor: Colors.grey,
                    ),
                    child: Text(_tSiteIdentity(context, 'Ignore')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleApprove(match),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
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
      case 'github':
        icon = Icons.code_rounded;
        color = Colors.black87;
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

  Widget _buildConfidenceIndicator(double confidence) {
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

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.9) return Colors.green;
    if (confidence >= 0.7) return Colors.orange;
    return Colors.red;
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
      final FirestoreService firestoreService = context.read<FirestoreService>();
      await firestoreService.firestore
          .collection('externalIdentityLinks')
          .doc(match.id)
          .set(<String, dynamic>{
        'status': 'linked',
        if ((match.suggestedUserId ?? '').isNotEmpty)
          'scholesaUserId': match.suggestedUserId,
        'approvedBy': FirebaseAuth.instance.currentUser?.uid,
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      setState(() {
        _pendingMatches.removeWhere((_IdentityMatch m) => m.id == match.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${_tSiteIdentity(context, 'Matched')} ${match.localName} ${_tSiteIdentity(context, 'with')} ${match.externalName}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tSiteIdentity(context, 'Match update failed')),
          backgroundColor: Colors.red,
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
      final FirestoreService firestoreService = context.read<FirestoreService>();
      await firestoreService.firestore
          .collection('externalIdentityLinks')
          .doc(match.id)
          .set(<String, dynamic>{
        'status': 'ignored',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      setState(() {
        _pendingMatches.removeWhere((_IdentityMatch m) => m.id == match.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tSiteIdentity(context, 'Match ignored')),
          backgroundColor: Colors.grey,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tSiteIdentity(context, 'Match update failed')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadPendingMatches() async {
    final AppState appState = context.read<AppState>();
    final FirestoreService firestoreService = context.read<FirestoreService>();
    final String siteId = (appState.activeSiteId ??
            (appState.siteIds.isNotEmpty ? appState.siteIds.first : ''))
        .trim();

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      if (siteId.isEmpty) {
        if (!mounted) return;
        setState(() => _pendingMatches = <_IdentityMatch>[]);
        return;
      }

      Query<Map<String, dynamic>> query = firestoreService.firestore
          .collection('externalIdentityLinks')
          .where('siteId', isEqualTo: siteId)
          .where('status', isEqualTo: 'unmatched');

      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await query.orderBy('createdAt', descending: true).limit(50).get();
      } catch (_) {
        snapshot = await query.limit(50).get();
      }

      final List<_IdentityMatch> loaded =
          snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        final List<dynamic> suggestedRaw = (data['suggestedMatches'] as List?) ?? <dynamic>[];
        final Map<String, dynamic>? firstSuggestion = suggestedRaw.isNotEmpty
            ? Map<String, dynamic>.from(suggestedRaw.first as Map)
            : null;

        final String localName =
            (firstSuggestion?['displayName'] as String?)?.trim().isNotEmpty == true
                ? (firstSuggestion!['displayName'] as String).trim()
                : (firstSuggestion?['name'] as String?)?.trim().isNotEmpty == true
                    ? (firstSuggestion!['name'] as String).trim()
                    : _tSiteIdentity(context, 'Unknown local account');

        final String externalName =
            (data['providerUserId'] as String?)?.trim().isNotEmpty == true
                ? (data['providerUserId'] as String).trim()
                : _tSiteIdentity(context, 'Unknown external account');

        final dynamic rawConfidence = firstSuggestion?['confidence'] ?? firstSuggestion?['score'];
        final double confidence = rawConfidence is num
            ? rawConfidence.toDouble().clamp(0.0, 1.0)
            : 0.5;

        return _IdentityMatch(
          id: doc.id,
          localName: localName,
          externalName: externalName,
          provider: _providerLabel((data['provider'] as String?) ?? 'google_classroom'),
          confidence: confidence,
          status: _MatchStatus.pending,
          suggestedUserId: (firstSuggestion?['scholesaUserId'] as String?) ??
              (firstSuggestion?['userId'] as String?),
        );
      }).toList();

      if (!mounted) return;
      setState(() => _pendingMatches = loaded);
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
    return 'Google Classroom';
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
    required this.confidence,
    required this.status,
    this.suggestedUserId,
  });

  final String id;
  final String localName;
  final String externalName;
  final String provider;
  final double confidence;
  final _MatchStatus status;
  final String? suggestedUserId;
}
