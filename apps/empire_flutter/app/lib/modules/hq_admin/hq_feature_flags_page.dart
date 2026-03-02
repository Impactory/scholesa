import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/firestore_service.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';

const Map<String, String> _hqFeatureFlagsEs = <String, String>{
  'Feature Flags': 'Banderas de funciones',
  'Opening change history...': 'Abriendo historial de cambios...',
  'Feature flags control which features are available to users. Changes take effect immediately.':
    'Las banderas de funciones controlan qué funciones están disponibles para los usuarios. Los cambios surten efecto de inmediato.',
  'enabled': 'activado',
  'disabled': 'desactivado',
  'global': 'global',
  'site': 'sede',
  'user': 'usuario',
  'Enable redesigned dashboard layout with improved metrics':
    'Habilitar diseño renovado del panel con métricas mejoradas',
  'Enable AI-powered reflection prompts for learners':
    'Habilitar sugerencias de reflexión con IA para estudiantes',
  'Enable GitHub classroom integration for coding missions':
    'Habilitar integración de aula GitHub para misiones de programación',
  'Allow parents to view detailed learner portfolios':
    'Permitir a las familias ver portafolios detallados de estudiantes',
  'Show beta missions to selected educators':
    'Mostrar misiones beta a educadores seleccionados',
  'Loading...': 'Cargando...',
  'Feature flag update failed': 'Error al actualizar bandera',
  'No feature flags found': 'No se encontraron banderas',
};

String _tHqFeatureFlags(BuildContext context, String input) {
  final String locale = Localizations.localeOf(context).languageCode;
  if (locale != 'es') return input;
  return _hqFeatureFlagsEs[input] ?? input;
}

/// HQ Feature Flags page for managing feature toggles
/// Based on docs/49_ROUTE_FLIP_TRACKER.md
class HqFeatureFlagsPage extends StatefulWidget {
  const HqFeatureFlagsPage({super.key});

  @override
  State<HqFeatureFlagsPage> createState() => _HqFeatureFlagsPageState();
}

class _FeatureFlag {
  _FeatureFlag({
    required this.id,
    required this.name,
    required this.description,
    required this.isEnabled,
    required this.scope,
    this.enabledSites,
  });

  final String id;
  final String name;
  final String description;
  bool isEnabled;
  final String scope; // 'global', 'site', 'user'
  final List<String>? enabledSites;
}

class _HqFeatureFlagsPageState extends State<HqFeatureFlagsPage> {
  final List<_FeatureFlag> _fallbackFlags = <_FeatureFlag>[
    _FeatureFlag(
      id: '1',
      name: 'new_dashboard',
      description: 'Enable redesigned dashboard layout with improved metrics',
      isEnabled: true,
      scope: 'global',
    ),
    _FeatureFlag(
      id: '2',
      name: 'ai_reflections',
      description: 'Enable AI-powered reflection prompts for learners',
      isEnabled: true,
      scope: 'global',
    ),
    _FeatureFlag(
      id: '3',
      name: 'github_integration',
      description: 'Enable GitHub classroom integration for coding missions',
      isEnabled: false,
      scope: 'site',
      enabledSites: <String>['Downtown Studio', 'Tech Campus'],
    ),
    _FeatureFlag(
      id: '4',
      name: 'parent_portfolio_view',
      description: 'Allow parents to view detailed learner portfolios',
      isEnabled: true,
      scope: 'global',
    ),
    _FeatureFlag(
      id: '5',
      name: 'beta_missions',
      description: 'Show beta missions to selected educators',
      isEnabled: false,
      scope: 'user',
    ),
  ];
  List<_FeatureFlag> _flags = <_FeatureFlag>[];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFlags();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: Text(_tHqFeatureFlags(context, 'Feature Flags')),
        backgroundColor: ScholesaColors.hqGradient.colors.first,
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'module': 'hq_feature_flags',
                  'cta_id': 'open_change_history',
                  'surface': 'appbar',
                },
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(_tHqFeatureFlags(
                        context, 'Opening change history...'))),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _buildInfoCard(),
          const SizedBox(height: 24),
          if (_isLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  _tHqFeatureFlags(context, 'Loading...'),
                  style: const TextStyle(color: ScholesaColors.textSecondary),
                ),
              ),
            ),
          if (!_isLoading && _flags.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  _tHqFeatureFlags(context, 'No feature flags found'),
                  style: const TextStyle(color: ScholesaColors.textSecondary),
                ),
              ),
            ),
          ..._flags.map((flag) => _buildFlagCard(flag)),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.info_outline_rounded, color: Colors.blue.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _tHqFeatureFlags(context,
                  'Feature flags control which features are available to users. Changes take effect immediately.'),
              style: TextStyle(fontSize: 13, color: Colors.blue.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlagCard(_FeatureFlag flag) {
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            flag.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildScopeChip(flag.scope),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _tHqFeatureFlags(context, flag.description),
                        style: const TextStyle(
                            fontSize: 13, color: ScholesaColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: flag.isEnabled,
                  onChanged: (bool value) async {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: <String, dynamic>{
                        'module': 'hq_feature_flags',
                        'cta_id': 'toggle_feature_flag',
                        'surface': 'flag_card',
                        'flag_id': flag.id,
                        'flag_name': flag.name,
                        'enabled': value,
                      },
                    );
                    await _toggleFlag(flag, value);
                  },
                  activeThumbColor: Colors.green,
                ),
              ],
            ),
            if (flag.scope == 'site' && flag.enabledSites != null) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: flag.enabledSites!
                    .map((String site) => Chip(
                          label:
                              Text(site, style: const TextStyle(fontSize: 11)),
                          backgroundColor: Colors.blue.withValues(alpha: 0.1),
                          side: BorderSide.none,
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScopeChip(String scope) {
    Color color;
    IconData icon;
    switch (scope) {
      case 'global':
        color = Colors.green;
        icon = Icons.public_rounded;
      case 'site':
        color = Colors.blue;
        icon = Icons.location_on_rounded;
      case 'user':
        color = Colors.purple;
        icon = Icons.person_rounded;
      default:
        color = Colors.grey;
        icon = Icons.flag_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(_tHqFeatureFlags(context, scope),
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _loadFlags() async {
    final FirestoreService? firestoreService = _maybeFirestoreService();
    if (firestoreService == null) {
      if (!mounted) return;
      setState(() => _flags = _fallbackFlags);
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await firestoreService.firestore
            .collection('featureFlags')
            .orderBy('name')
            .limit(200)
            .get();
      } catch (_) {
        snapshot = await firestoreService.firestore
            .collection('featureFlags')
            .limit(200)
            .get();
      }

      final List<_FeatureFlag> loaded = snapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        final List<String>? enabledSites =
            (data['enabledSites'] as List?)?.map((dynamic e) => e.toString()).toList();
        return _FeatureFlag(
          id: doc.id,
          name: (data['name'] as String?) ?? doc.id,
          description: (data['description'] as String?) ?? '',
          isEnabled: (data['isEnabled'] as bool?) ?? false,
          scope: (data['scope'] as String?) ?? 'global',
          enabledSites: enabledSites,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _flags = loaded;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _flags = _fallbackFlags);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleFlag(_FeatureFlag flag, bool enabled) async {
    final FirestoreService? firestoreService = _maybeFirestoreService();
    if (firestoreService == null) {
      if (!mounted) return;
      setState(() => flag.isEnabled = enabled);
      return;
    }

    try {
      await firestoreService.firestore.collection('featureFlags').doc(flag.id).set(
        <String, dynamic>{
          'name': flag.name,
          'description': flag.description,
          'scope': flag.scope,
          'isEnabled': enabled,
          if (flag.enabledSites != null) 'enabledSites': flag.enabledSites,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      setState(() => flag.isEnabled = enabled);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${flag.name} ${enabled ? _tHqFeatureFlags(context, 'enabled') : _tHqFeatureFlags(context, 'disabled')}'),
          backgroundColor: enabled ? Colors.green : Colors.orange,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tHqFeatureFlags(context, 'Feature flag update failed')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  FirestoreService? _maybeFirestoreService() {
    try {
      return context.read<FirestoreService>();
    } catch (_) {
      return null;
    }
  }
}
