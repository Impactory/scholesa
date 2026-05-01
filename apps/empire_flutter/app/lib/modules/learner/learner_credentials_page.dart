import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/app_state.dart';
import '../../domain/curriculum/curriculum_family_ui.dart';
import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../../i18n/learner_surface_i18n.dart';
import '../../services/firestore_service.dart';
import '../../services/telemetry_service.dart';
import '../../ui/auth/global_session_menu.dart';
import '../../ui/theme/scholesa_theme.dart';

String _tLearnerCredentials(BuildContext context, String input) {
  return LearnerSurfaceI18n.text(context, input);
}

class LearnerCredentialsPage extends StatefulWidget {
  const LearnerCredentialsPage({
    super.key,
    this.credentialsLoader,
  });

  final Future<List<CredentialModel>> Function(
      String learnerId, String? siteId)? credentialsLoader;

  @override
  State<LearnerCredentialsPage> createState() => _LearnerCredentialsPageState();
}

class _LearnerCredentialsPageState extends State<LearnerCredentialsPage> {
  bool _isLoading = false;
  String? _error;
  List<CredentialModel> _credentials = const <CredentialModel>[];

  String _t(String input) => _tLearnerCredentials(context, input);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCredentials();
    });
  }

  FirestoreService? _maybeFirestoreService() {
    try {
      return context.read<FirestoreService>();
    } catch (_) {
      return null;
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

  Future<void> _loadCredentials() async {
    final AppState appState = context.read<AppState>();
    final FirestoreService? firestoreService = _maybeFirestoreService();
    final String learnerId = appState.userId?.trim() ?? '';
    final String siteId = _activeSiteId(appState);
    final bool hadCredentials = _credentials.isNotEmpty;

    if (firestoreService == null) {
      setState(() {
        _error = _t('Credential storage unavailable right now.');
        _isLoading = false;
      });
      return;
    }

    if (learnerId.isEmpty) {
      setState(() {
        _error = _t('Learner identity unavailable right now.');
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final List<CredentialModel> credentials =
          await (widget.credentialsLoader != null
              ? widget.credentialsLoader!(
                  learnerId,
                  siteId.isEmpty ? null : siteId,
                )
              : CredentialRepository(firestore: firestoreService.firestore)
                  .listByLearner(
                  learnerId,
                  siteId: siteId.isEmpty ? null : siteId,
                  limit: 50,
                ));
      if (!mounted) return;
      setState(() {
        _credentials = credentials;
        _error = null;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = hadCredentials
            ? _t(
                'Unable to refresh credentials right now. Showing the last successful data.',
              )
            : _t('Unable to load credentials right now.');
        _isLoading = false;
      });
    }
  }

  Widget _buildLoadErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: const <String, dynamic>{
                    'module': 'learner_credentials',
                    'cta_id': 'retry_load_credentials',
                    'surface': 'error_state',
                  },
                );
                _loadCredentials();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: Text(_t('Retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaleDataBanner() {
    return Container(
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
              _error!,
              style: const TextStyle(color: ScholesaColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  String _formatIssuedDate(CredentialModel credential) {
    final DateTime issuedAt = credential.issuedAt.toDate();
    return '${issuedAt.month}/${issuedAt.day}/${issuedAt.year}';
  }

  String _pillarLabel(String code) {
    final CurriculumLegacyFamilyCode? legacyFamilyCode =
        maybeCurriculumLegacyFamilyCode(code);
    if (legacyFamilyCode == null) {
      return code.trim().isEmpty ? _t('Credentials') : code.trim();
    }
    return curriculumLegacyFamilyDisplayLabel(context, legacyFamilyCode);
  }

  Color _pillarColor(String code) {
    final CurriculumLegacyFamilyCode? legacyFamilyCode =
        maybeCurriculumLegacyFamilyCode(code);
    if (legacyFamilyCode == null) {
      return ScholesaColors.learner;
    }
    return curriculumLegacyFamilyColor(legacyFamilyCode);
  }

  Widget _buildEmptyState() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Container(
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
                child: const Icon(
                  Icons.verified_outlined,
                  color: ScholesaColors.learner,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _t('No credentials issued yet'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _t(
                  'Credentials issued by your educator or site will appear here.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.schTextSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCredentialCard(CredentialModel credential) {
    final String issuer = credential.issuerId?.trim() ?? '';
    final String rubricApplicationId =
        credential.rubricApplicationId?.trim() ?? '';
    final bool hasEvidenceProvenance = credential.evidenceIds.isNotEmpty ||
        credential.portfolioItemIds.isNotEmpty ||
        credential.proofBundleIds.isNotEmpty ||
        credential.growthEventIds.isNotEmpty ||
        rubricApplicationId.isNotEmpty;

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
                    color: ScholesaColors.learner.withValues(alpha: 0.1),
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
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_t('Issued')} ${_formatIssuedDate(credential)}',
                        style: TextStyle(
                          color: context.schTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (credential.pillarCodes.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: credential.pillarCodes.map((String code) {
                  final Color color = _pillarColor(code);
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
                      _pillarLabel(code),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(growable: false),
              ),
            if (credential.pillarCodes.isNotEmpty) const SizedBox(height: 12),
            Text(
              '${_t('Skills tagged')}: ${credential.skillIds.length}',
              style: TextStyle(color: context.schTextSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              '${_t('Credential site')}: ${credential.siteId.trim().isEmpty ? _t('Site unavailable') : credential.siteId.trim()}',
              style: TextStyle(color: context.schTextSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              '${_t('Issued by')}: ${issuer.isEmpty ? _t('Issuer unavailable') : issuer}',
              style: TextStyle(color: context.schTextSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasEvidenceProvenance
                    ? ScholesaColors.success.withValues(alpha: 0.08)
                    : ScholesaColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasEvidenceProvenance
                      ? ScholesaColors.success.withValues(alpha: 0.3)
                      : ScholesaColors.warning.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    hasEvidenceProvenance
                        ? _t('Evidence provenance')
                        : _t('Evidence provenance missing'),
                    style: TextStyle(
                      color: hasEvidenceProvenance
                          ? ScholesaColors.success
                          : ScholesaColors.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_t('Source evidence')}: ${credential.evidenceIds.length}',
                  ),
                  Text(
                    '${_t('Portfolio artifacts')}: ${credential.portfolioItemIds.length}',
                  ),
                  Text(
                    '${_t('Proof bundles')}: ${credential.proofBundleIds.length}',
                  ),
                  Text(
                    '${_t('Growth events')}: ${credential.growthEventIds.length}',
                  ),
                  Text(
                    '${_t('Rubric review')}: ${rubricApplicationId.isEmpty ? _t('Not linked') : rubricApplicationId}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialScopeNotice() {
    return Container(
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
                'Credentials here show issuer and evidence provenance when linked. They do not replace portfolio artifacts, proof bundles, or rubric review.',
              ),
              style: TextStyle(
                color: context.schTextSecondary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('Credentials')),
        actions: <Widget>[
          IconButton(
            tooltip: _t('Refresh'),
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'module': 'learner_credentials',
                  'cta_id': 'refresh_credentials',
                  'surface': 'appbar',
                },
              );
              _loadCredentials();
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SessionMenuButton(),
        ],
      ),
      body: Builder(
        builder: (BuildContext context) {
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_error != null && _credentials.isEmpty) {
            return _buildLoadErrorState();
          }

          if (_credentials.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: _loadCredentials,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                if (_error != null) _buildStaleDataBanner(),
                _buildCredentialScopeNotice(),
                ..._credentials.map(_buildCredentialCard),
              ],
            ),
          );
        },
      ),
    );
  }
}
