import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/app_state.dart';
import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../../i18n/learner_surface_i18n.dart';
import '../../services/firestore_service.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';

String _tLearnerCredentials(BuildContext context, String input) {
  return LearnerSurfaceI18n.text(context, input);
}

class LearnerCredentialsPage extends StatefulWidget {
  const LearnerCredentialsPage({super.key});

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

    if (firestoreService == null) {
      setState(() {
        _error = _t('Credential storage unavailable right now.');
        _credentials = const <CredentialModel>[];
        _isLoading = false;
      });
      return;
    }

    if (learnerId.isEmpty) {
      setState(() {
        _error = _t('Learner identity unavailable right now.');
        _credentials = const <CredentialModel>[];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final CredentialRepository repository =
          CredentialRepository(firestore: firestoreService.firestore);
      final List<CredentialModel> credentials = await repository.listByLearner(
        learnerId,
        siteId: siteId.isEmpty ? null : siteId,
        limit: 50,
      );
      if (!mounted) return;
      setState(() {
        _credentials = credentials;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _t('Unable to load credentials right now.');
        _credentials = const <CredentialModel>[];
        _isLoading = false;
      });
    }
  }

  String _formatIssuedDate(CredentialModel credential) {
    final DateTime issuedAt = credential.issuedAt.toDate();
    return '${issuedAt.month}/${issuedAt.day}/${issuedAt.year}';
  }

  String _pillarLabel(String code) {
    switch (code.trim().toLowerCase()) {
      case 'future_skills':
      case 'future skills':
        return _t('Future Skills');
      case 'leadership':
      case 'leadership_agency':
        return _t('Leadership');
      case 'impact':
      case 'impact_innovation':
        return _t('Impact');
      default:
        return code.trim().isEmpty ? _t('Credentials') : code.trim();
    }
  }

  Color _pillarColor(String code) {
    switch (code.trim().toLowerCase()) {
      case 'future_skills':
      case 'future skills':
        return ScholesaColors.futureSkills;
      case 'leadership':
      case 'leadership_agency':
        return ScholesaColors.leadership;
      case 'impact':
      case 'impact_innovation':
        return ScholesaColors.impact;
      default:
        return ScholesaColors.learner;
    }
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
          ],
        ),
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
        ],
      ),
      body: Builder(
        builder: (BuildContext context) {
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_error != null) {
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

          if (_credentials.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: _loadCredentials,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _credentials.length,
              itemBuilder: (BuildContext context, int index) =>
                  _buildCredentialCard(_credentials[index]),
            ),
          );
        },
      ),
    );
  }
}
