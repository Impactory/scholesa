import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/app_state.dart';
import '../../i18n/site_surface_i18n.dart';
import '../../modules/checkin/checkin_models.dart';
import '../../services/telemetry_service.dart';
import '../../ui/auth/global_session_menu.dart';
import '../../ui/theme/scholesa_theme.dart';
import 'site_pickup_auth_service.dart';

String _tSitePickupAuth(BuildContext context, String input) {
  return SiteSurfaceI18n.text(context, input);
}

const String _canonicalLearnerUnavailable = 'Learner unavailable';

class SitePickupAuthPage extends StatefulWidget {
  const SitePickupAuthPage({
    super.key,
    this.service,
  });

  final SitePickupAuthorizationService? service;

  @override
  State<SitePickupAuthPage> createState() => _SitePickupAuthPageState();
}

class _SitePickupAuthPageState extends State<SitePickupAuthPage> {
  late final SitePickupAuthorizationService _service =
      widget.service ?? SitePickupAuthorizationService();

  List<SitePickupAuthorizationRecord> _records =
      <SitePickupAuthorizationRecord>[];
  List<SitePickupAuthorizationLearnerOption> _learners =
      <SitePickupAuthorizationLearnerOption>[];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _siteId;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: Text(_tSitePickupAuth(context, 'Pickup Authorizations')),
        backgroundColor: ScholesaColors.siteGradient.colors.first,
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            tooltip: _tSitePickupAuth(context, 'Refresh'),
            onPressed: _isLoading ? null : _loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: _tSitePickupAuth(context, 'Add Authorization'),
            onPressed: _isLoading || _isSaving ? null : _openEditor,
            icon: const Icon(Icons.add_rounded),
          ),
          const SessionMenuButton(
            foregroundColor: Colors.white,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _records.isEmpty) {
      return Center(
        child: Text(
          _tSitePickupAuth(context, 'Loading...'),
          style: const TextStyle(color: ScholesaColors.textSecondary),
        ),
      );
    }

    if (_loadError != null && _records.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          _buildErrorCard(
            message: _loadError!,
            showRetry: true,
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _buildIntroCard(),
        if (_loadError != null) ...<Widget>[
          const SizedBox(height: 16),
          _buildErrorCard(
            message: _loadError!,
            showRetry: false,
          ),
        ],
        const SizedBox(height: 16),
        _buildSummaryRow(),
        const SizedBox(height: 16),
        if (_records.isEmpty)
          _buildEmptyState()
        else
          ..._records.map(_buildRecordCard),
      ],
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ScholesaColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _tSitePickupAuth(
              context,
              'Manage explicit pickup lists and review guardian-link fallback coverage.',
            ),
            style: const TextStyle(
              color: ScholesaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _buildSourceChip(
                label: _tSitePickupAuth(context, 'Explicit list'),
                color: ScholesaColors.primary,
              ),
              _buildSourceChip(
                label: _tSitePickupAuth(context, 'Guardian fallback'),
                color: const Color(0xFFF59E0B),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSourceChip({
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSummaryRow() {
    final int explicitCount =
        _records.where((SitePickupAuthorizationRecord record) => !record.isFallback).length;
    final int fallbackCount =
        _records.where((SitePickupAuthorizationRecord record) => record.isFallback).length;
    final int totalPickupCount = _records
        .fold<int>(0, (int total, SitePickupAuthorizationRecord record) => total + record.pickups.length);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        _buildSummaryCard(
          _tSitePickupAuth(context, 'Learners Covered'),
          _records.length.toString(),
        ),
        _buildSummaryCard(
          _tSitePickupAuth(context, 'Explicit Records'),
          explicitCount.toString(),
        ),
        _buildSummaryCard(
          _tSitePickupAuth(context, 'Guardian Fallback'),
          fallbackCount.toString(),
        ),
        _buildSummaryCard(
          _tSitePickupAuth(context, 'Authorized Pickups'),
          totalPickupCount.toString(),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value) {
    return SizedBox(
      width: 170,
      child: Card(
        color: ScholesaColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                value,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: ScholesaColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: ScholesaColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard({
    required String message,
    required bool showRetry,
  }) {
    return Card(
      color: const Color(0xFFFEF2F2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              message,
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (showRetry) ...<Widget>[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(_tSitePickupAuth(context, 'Retry')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _tSitePickupAuth(context, 'No pickup authorizations found'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: ScholesaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _learners.isEmpty
                  ? _tSitePickupAuth(
                      context,
                      'Learner roster unavailable for pickup authorization setup.',
                    )
                  : _tSitePickupAuth(
                      context,
                      'Add an explicit pickup list or rely on guardian-link fallback where available.',
                    ),
              style: const TextStyle(color: ScholesaColors.textSecondary),
            ),
            if (_learners.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isSaving ? null : _openEditor,
                icon: const Icon(Icons.add_rounded),
                label: Text(_tSitePickupAuth(context, 'Add Authorization')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCard(SitePickupAuthorizationRecord record) {
    final Color accentColor =
        record.isFallback ? const Color(0xFFF59E0B) : ScholesaColors.primary;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  record.learnerName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: ScholesaColors.textPrimary,
                  ),
                ),
                _buildSourceChip(
                  label: record.isFallback
                      ? _tSitePickupAuth(context, 'Guardian fallback')
                      : _tSitePickupAuth(context, 'Explicit list'),
                  color: accentColor,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              record.isFallback
                  ? _tSitePickupAuth(
                      context,
                      'Derived from guardian links until an explicit pickup list is saved.',
                    )
                  : _buildExplicitRecordMeta(record),
              style: const TextStyle(color: ScholesaColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ...record.pickups.map((AuthorizedPickup pickup) => _buildPickupTile(pickup)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                FilledButton.tonalIcon(
                  onPressed: _isSaving ? null : () => _openEditor(record: record),
                  icon: const Icon(Icons.edit_rounded),
                  label: Text(
                    _tSitePickupAuth(
                      context,
                      record.isFallback
                          ? 'Create Explicit List'
                          : 'Edit Authorizations',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickupTile(AuthorizedPickup pickup) {
    final List<String> detailBits = <String>[
      pickup.relationship,
      if ((pickup.phone ?? '').trim().isNotEmpty) pickup.phone!.trim(),
      if ((pickup.email ?? '').trim().isNotEmpty) pickup.email!.trim(),
    ];
    final List<String> metaBits = <String>[
      if (pickup.isPrimaryContact)
        _tSitePickupAuth(context, 'Primary contact'),
      if ((pickup.verificationCode ?? '').trim().isNotEmpty)
        '${_tSitePickupAuth(context, 'Verification code')}: ${pickup.verificationCode!.trim()}',
      if (pickup.expiresAt != null)
        '${_tSitePickupAuth(context, 'Expires')}: ${_formatDate(pickup.expiresAt!)}',
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ScholesaColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ScholesaColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.family_restroom_rounded,
              color: ScholesaColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  pickup.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ScholesaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detailBits.join(' • '),
                  style: const TextStyle(color: ScholesaColors.textSecondary),
                ),
                if (metaBits.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    metaBits.join(' • '),
                    style: const TextStyle(
                      fontSize: 12,
                      color: ScholesaColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildExplicitRecordMeta(SitePickupAuthorizationRecord record) {
    final List<String> bits = <String>[];
    if (record.updatedAt != null) {
      bits.add(
        '${_tSitePickupAuth(context, 'Last updated')}: ${_formatDateTime(record.updatedAt!)}',
      );
    }
    final String updatedBy = record.updatedBy.trim();
    if (updatedBy.isNotEmpty) {
      bits.add('${_tSitePickupAuth(context, 'Updated by')}: $updatedBy');
    }
    return bits.isEmpty
        ? _tSitePickupAuth(context, 'Explicit pickup authorization saved for this learner.')
        : bits.join(' • ');
  }

  Future<void> _loadData() async {
    final AppState appState = context.read<AppState>();
    final String? siteId = appState.activeSiteId;
    if (siteId == null || siteId.trim().isEmpty) {
      setState(() {
        _siteId = null;
        _records = <SitePickupAuthorizationRecord>[];
        _learners = <SitePickupAuthorizationLearnerOption>[];
        _loadError =
            _tSitePickupAuth(context, 'Site context unavailable right now');
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _siteId = siteId;
      _loadError = null;
    });
    final bool hadRecords = _records.isNotEmpty;

    try {
      final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
        _service.listRecords(siteId),
        _service.listLearners(siteId),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _records = results[0] as List<SitePickupAuthorizationRecord>;
        _learners = results[1] as List<SitePickupAuthorizationLearnerOption>;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = _tSitePickupAuth(
          context,
          hadRecords
              ? 'Unable to refresh pickup authorizations right now. Showing the last successful data.'
              : 'Unable to load pickup authorizations right now',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openEditor({
    SitePickupAuthorizationRecord? record,
  }) async {
    if (_siteId == null) {
      return;
    }
    final AppState appState = context.read<AppState>();
    final _PickupAuthorizationEditorResult? result =
        await showDialog<_PickupAuthorizationEditorResult>(
      context: context,
      builder: (BuildContext context) => _PickupAuthorizationEditorDialog(
        learners: _learners,
        initialRecord: record,
      ),
    );
    if (result == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _service.saveAuthorization(
        siteId: _siteId!,
        learnerId: result.learnerId,
        pickups: result.pickups,
        updatedBy: appState.userId ?? '',
      );
      if (!mounted) {
        return;
      }
      TelemetryService.instance.logEvent(
        event: 'pickup_authorization.saved',
        role: 'site',
        siteId: _siteId,
        metadata: <String, dynamic>{
          'learner_id': result.learnerId,
          'pickup_count': result.pickups.length,
          'source': record?.source ?? 'create',
        },
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tSitePickupAuth(context, 'Pickup authorizations saved'),
          ),
        ),
      );
      await _loadData();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tSitePickupAuth(
              context,
              'Unable to save pickup authorizations right now',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _formatDate(DateTime value) {
    return MaterialLocalizations.of(context).formatShortDate(value);
  }

  String _formatDateTime(DateTime value) {
    final MaterialLocalizations localizations =
        MaterialLocalizations.of(context);
    return '${localizations.formatShortDate(value)} ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(value), alwaysUse24HourFormat: true)}';
  }
}

class _PickupAuthorizationEditorResult {
  const _PickupAuthorizationEditorResult({
    required this.learnerId,
    required this.pickups,
  });

  final String learnerId;
  final List<AuthorizedPickup> pickups;
}

class _PickupAuthorizationEditorDialog extends StatefulWidget {
  const _PickupAuthorizationEditorDialog({
    required this.learners,
    this.initialRecord,
  });

  final List<SitePickupAuthorizationLearnerOption> learners;
  final SitePickupAuthorizationRecord? initialRecord;

  @override
  State<_PickupAuthorizationEditorDialog> createState() =>
      _PickupAuthorizationEditorDialogState();
}

class _PickupAuthorizationEditorDialogState
    extends State<_PickupAuthorizationEditorDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final List<_EditablePickup> _pickups;
  String? _selectedLearnerId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedLearnerId = widget.initialRecord?.learnerId;
    _pickups = (widget.initialRecord?.pickups ?? const <AuthorizedPickup>[])
        .map(_EditablePickup.fromAuthorizedPickup)
        .toList(growable: true);
    if (_pickups.isEmpty) {
      _pickups.add(_EditablePickup.empty());
    }
  }

  @override
  void dispose() {
    for (final _EditablePickup pickup in _pickups) {
      pickup.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditingExisting = widget.initialRecord != null;
    final String title = widget.initialRecord == null
        ? _tSitePickupAuth(context, 'Add Pickup Authorization')
        : widget.initialRecord!.isFallback
            ? _tSitePickupAuth(context, 'Create Explicit Pickup Authorization')
            : _tSitePickupAuth(context, 'Edit Pickup Authorization');

    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.all(16),
      title: Text(title),
      content: SizedBox(
        width: 680,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (isEditingExisting)
                _buildLockedLearnerField()
              else
                DropdownButtonFormField<String>(
                  initialValue: _selectedLearnerId,
                  decoration: InputDecoration(
                    labelText: _tSitePickupAuth(context, 'Learner'),
                    border: const OutlineInputBorder(),
                  ),
                  items: widget.learners
                      .map(
                        (SitePickupAuthorizationLearnerOption learner) =>
                            DropdownMenuItem<String>(
                          value: learner.learnerId,
                          child: Text(learner.learnerName),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (String? value) {
                    setState(() {
                      _selectedLearnerId = value;
                    });
                  },
                  validator: (String? value) {
                    if ((value ?? '').trim().isEmpty) {
                      return _tSitePickupAuth(
                        context,
                        'Learner selection is required',
                      );
                    }
                    return null;
                  },
                ),
              if (widget.initialRecord?.isFallback ?? false) ...<Widget>[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _tSitePickupAuth(
                      context,
                      'Saving here creates an explicit pickup list for this learner and replaces guardian-link fallback in site operations.',
                    ),
                    style: const TextStyle(color: Color(0xFF92400E)),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ..._buildPickupForms(),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _addPickup,
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  _tSitePickupAuth(context, 'Add Authorized Pickup'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(_tSitePickupAuth(context, 'Cancel')),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: Text(_tSitePickupAuth(context, 'Save')),
        ),
      ],
    );
  }

  Widget _buildLockedLearnerField() {
    final String learnerName = widget.initialRecord?.learnerName.isNotEmpty == true
        ? widget.initialRecord!.learnerName
        : _tSitePickupAuth(context, _canonicalLearnerUnavailable);
    return InputDecorator(
      decoration: InputDecoration(
        labelText: _tSitePickupAuth(context, 'Learner'),
        border: const OutlineInputBorder(),
      ),
      child: Text(learnerName),
    );
  }

  List<Widget> _buildPickupForms() {
    return _pickups.asMap().entries.map((MapEntry<int, _EditablePickup> entry) {
      final int index = entry.key;
      final _EditablePickup pickup = entry.value;
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ScholesaColors.background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${_tSitePickupAuth(context, 'Authorized Pickup')} ${index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: ScholesaColors.textPrimary,
                    ),
                  ),
                ),
                if (_pickups.length > 1)
                  IconButton(
                    tooltip: _tSitePickupAuth(context, 'Remove Authorized Pickup'),
                    onPressed: _isSaving ? null : () => _removePickup(index),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: pickup.nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: _tSitePickupAuth(context, 'Pickup Name'),
                border: const OutlineInputBorder(),
              ),
              validator: (String? value) {
                if ((value ?? '').trim().isEmpty) {
                  return _tSitePickupAuth(context, 'Pickup name is required');
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: pickup.relationshipController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: _tSitePickupAuth(context, 'Relationship'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: pickup.phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: _tSitePickupAuth(context, 'Phone'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: pickup.emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: _tSitePickupAuth(context, 'Email'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: pickup.codeController,
              decoration: InputDecoration(
                labelText: _tSitePickupAuth(context, 'Verification code'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: pickup.expiryController,
              decoration: InputDecoration(
                labelText: _tSitePickupAuth(context, 'Expires (YYYY-MM-DD)'),
                border: const OutlineInputBorder(),
              ),
              validator: (String? value) {
                final String trimmed = (value ?? '').trim();
                if (trimmed.isEmpty) {
                  return null;
                }
                return DateTime.tryParse(trimmed) == null
                    ? _tSitePickupAuth(
                        context,
                        'Expiration must use YYYY-MM-DD',
                      )
                    : null;
              },
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(_tSitePickupAuth(context, 'Primary contact')),
              value: pickup.isPrimaryContact,
              onChanged: _isSaving
                  ? null
                  : (bool value) {
                      setState(() {
                        pickup.isPrimaryContact = value;
                      });
                    },
            ),
          ],
        ),
      );
    }).toList(growable: false);
  }

  void _addPickup() {
    setState(() {
      _pickups.add(_EditablePickup.empty());
    });
  }

  void _removePickup(int index) {
    setState(() {
      final _EditablePickup pickup = _pickups.removeAt(index);
      pickup.dispose();
    });
  }

  void _save() {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    if ((_selectedLearnerId ?? '').trim().isEmpty) {
      return;
    }

    final String learnerId = _selectedLearnerId!.trim();
    final List<AuthorizedPickup> pickups = _pickups
        .asMap()
        .entries
        .map((MapEntry<int, _EditablePickup> entry) {
      final _EditablePickup draft = entry.value;
      final DateTime? expiresAt = draft.expiryController.text.trim().isEmpty
          ? null
          : DateTime.parse(draft.expiryController.text.trim());
      return AuthorizedPickup(
        id: draft.id ?? '$learnerId-${entry.key}',
        learnerId: learnerId,
        name: draft.nameController.text.trim(),
        phone: _nullableText(draft.phoneController.text),
        email: _nullableText(draft.emailController.text),
        relationship: _nullableText(draft.relationshipController.text) ??
            _tSitePickupAuth(context, 'Authorized pickup'),
        photoUrl: draft.photoUrl,
        isPrimaryContact: draft.isPrimaryContact,
        expiresAt: expiresAt,
        verificationCode: _nullableText(draft.codeController.text),
      );
    }).toList(growable: false);

    setState(() {
      _isSaving = true;
    });
    Navigator.of(context).pop(
      _PickupAuthorizationEditorResult(
        learnerId: learnerId,
        pickups: pickups,
      ),
    );
  }

  String? _nullableText(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _EditablePickup {
  _EditablePickup({
    required this.id,
    required this.nameController,
    required this.relationshipController,
    required this.phoneController,
    required this.emailController,
    required this.codeController,
    required this.expiryController,
    required this.isPrimaryContact,
    required this.photoUrl,
  });

  factory _EditablePickup.empty() {
    return _EditablePickup(
      id: null,
      nameController: TextEditingController(),
      relationshipController: TextEditingController(text: 'Authorized pickup'),
      phoneController: TextEditingController(),
      emailController: TextEditingController(),
      codeController: TextEditingController(),
      expiryController: TextEditingController(),
      isPrimaryContact: false,
      photoUrl: null,
    );
  }

  factory _EditablePickup.fromAuthorizedPickup(AuthorizedPickup pickup) {
    return _EditablePickup(
      id: pickup.id,
      nameController: TextEditingController(text: pickup.name),
      relationshipController:
          TextEditingController(text: pickup.relationship),
      phoneController: TextEditingController(text: pickup.phone ?? ''),
      emailController: TextEditingController(text: pickup.email ?? ''),
      codeController:
          TextEditingController(text: pickup.verificationCode ?? ''),
      expiryController: TextEditingController(
        text: pickup.expiresAt == null
            ? ''
            : pickup.expiresAt!.toIso8601String().split('T').first,
      ),
      isPrimaryContact: pickup.isPrimaryContact,
      photoUrl: pickup.photoUrl,
    );
  }

  final String? id;
  final TextEditingController nameController;
  final TextEditingController relationshipController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController codeController;
  final TextEditingController expiryController;
  bool isPrimaryContact;
  final String? photoUrl;

  void dispose() {
    nameController.dispose();
    relationshipController.dispose();
    phoneController.dispose();
    emailController.dispose();
    codeController.dispose();
    expiryController.dispose();
  }
}
