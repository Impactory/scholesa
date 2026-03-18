import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/app_state.dart';
import '../../i18n/site_surface_i18n.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';
import 'site_consent_service.dart';

String _tSiteConsent(BuildContext context, String input) {
  return SiteSurfaceI18n.text(context, input);
}

class SiteConsentPage extends StatefulWidget {
  const SiteConsentPage({
    super.key,
    this.service,
  });

  final SiteConsentService? service;

  @override
  State<SiteConsentPage> createState() => _SiteConsentPageState();
}

class _SiteConsentPageState extends State<SiteConsentPage> {
  late final SiteConsentService _service =
      widget.service ?? SiteConsentService();

  List<SiteConsentRecord> _records = <SiteConsentRecord>[];
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
        title: Text(_tSiteConsent(context, 'Consent Management')),
        backgroundColor: ScholesaColors.siteGradient.colors.first,
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            tooltip: _tSiteConsent(context, 'Refresh'),
            onPressed: _isLoading ? null : _loadData,
            icon: const Icon(Icons.refresh_rounded),
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
          _tSiteConsent(context, 'Loading...'),
          style: const TextStyle(color: ScholesaColors.textSecondary),
        ),
      );
    }

    if (_loadError != null && _records.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          _buildErrorCard(showRetry: true),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _buildIntroCard(),
        if (_loadError != null) ...<Widget>[
          const SizedBox(height: 16),
          _buildErrorCard(showRetry: false),
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
    return Card(
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _tSiteConsent(
            context,
            'Manage media capture and research consent flags for each learner using live site records.',
          ),
          style: const TextStyle(color: ScholesaColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildErrorCard({required bool showRetry}) {
    return Card(
      color: const Color(0xFFFEF2F2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _loadError ??
                  _tSiteConsent(context, 'Unable to load consent records right now'),
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
                label: Text(_tSiteConsent(context, 'Retry')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow() {
    final int mediaConfiguredCount = _records
        .where((SiteConsentRecord record) => record.mediaConsent != null)
        .length;
    final int researchConfiguredCount = _records
        .where((SiteConsentRecord record) => record.researchConsent != null)
        .length;
    final int marketingAllowedCount = _records
        .where((SiteConsentRecord record) =>
            record.mediaConsent?.marketingUseAllowed == true)
        .length;
    final int researchGrantedCount = _records
        .where((SiteConsentRecord record) =>
            record.researchConsent?.consentGiven == true)
        .length;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        _buildSummaryCard(
          _tSiteConsent(context, 'Learners'),
          _records.length.toString(),
        ),
        _buildSummaryCard(
          _tSiteConsent(context, 'Media Configured'),
          mediaConfiguredCount.toString(),
        ),
        _buildSummaryCard(
          _tSiteConsent(context, 'Research Configured'),
          researchConfiguredCount.toString(),
        ),
        _buildSummaryCard(
          _tSiteConsent(context, 'Marketing Allowed'),
          marketingAllowedCount.toString(),
        ),
        _buildSummaryCard(
          _tSiteConsent(context, 'Research Granted'),
          researchGrantedCount.toString(),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value) {
    return SizedBox(
      width: 180,
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
                style: const TextStyle(color: ScholesaColors.textSecondary),
              ),
            ],
          ),
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
        child: Text(
          _tSiteConsent(context, 'No learner consent records are available for this site yet.'),
          style: const TextStyle(color: ScholesaColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildRecordCard(SiteConsentRecord record) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              record.learnerName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: ScholesaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _buildConsentSection(
              title: _tSiteConsent(context, 'Media Consent'),
              status: _mediaStatusLabel(record),
              details: _mediaDetails(record),
              buttonLabel: _tSiteConsent(context, 'Edit Media Consent'),
              onPressed: _isSaving ? null : () => _openMediaDialog(record),
            ),
            const SizedBox(height: 16),
            _buildConsentSection(
              title: _tSiteConsent(context, 'Research Consent'),
              status: _researchStatusLabel(record),
              details: _researchDetails(record),
              buttonLabel: _tSiteConsent(context, 'Edit Research Consent'),
              onPressed: _isSaving
                  ? null
                  : (record.guardians.isNotEmpty || record.researchConsent != null)
                      ? () => _openResearchDialog(record)
                      : null,
              trailingMessage: record.guardians.isEmpty && record.researchConsent == null
                  ? _tSiteConsent(
                      context,
                      'No linked parents available for research consent.',
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsentSection({
    required String title,
    required String status,
    required List<String> details,
    required String buttonLabel,
    required VoidCallback? onPressed,
    String? trailingMessage,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ScholesaColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ScholesaColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: ScholesaColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    color: ScholesaColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...details.map(
            (String line) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                line,
                style: const TextStyle(color: ScholesaColors.textSecondary),
              ),
            ),
          ),
          if (trailingMessage != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              trailingMessage,
              style: const TextStyle(color: ScholesaColors.textSecondary),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onPressed,
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }

  String _mediaStatusLabel(SiteConsentRecord record) {
    final mediaConsent = record.mediaConsent;
    if (mediaConsent == null) {
      return _tSiteConsent(context, 'Not configured');
    }
    return _tSiteConsent(context, _titleCase(mediaConsent.consentStatus));
  }

  List<String> _mediaDetails(SiteConsentRecord record) {
    final mediaConsent = record.mediaConsent;
    if (mediaConsent == null) {
      return <String>[
        _tSiteConsent(
          context,
          'No media consent has been recorded for this learner yet.',
        ),
      ];
    }
    return <String>[
      '${_tSiteConsent(context, 'Photo capture')}: ${_booleanLabel(mediaConsent.photoCaptureAllowed)}',
      '${_tSiteConsent(context, 'Share with linked parents')}: ${_booleanLabel(mediaConsent.shareWithLinkedParents)}',
      '${_tSiteConsent(context, 'Marketing use')}: ${_booleanLabel(mediaConsent.marketingUseAllowed)}',
      '${_tSiteConsent(context, 'Consent window')}: ${_dateRangeLabel(mediaConsent.consentStartDate, mediaConsent.consentEndDate)}',
      '${_tSiteConsent(context, 'Consent document')}: ${_documentLabel(mediaConsent.consentDocumentUrl)}',
    ];
  }

  String _researchStatusLabel(SiteConsentRecord record) {
    final researchConsent = record.researchConsent;
    if (researchConsent == null) {
      return _tSiteConsent(context, 'Not configured');
    }
    if (researchConsent.revokedAt != null || !researchConsent.consentGiven) {
      return _tSiteConsent(context, 'Withheld');
    }
    return _tSiteConsent(context, 'Granted');
  }

  List<String> _researchDetails(SiteConsentRecord record) {
    final researchConsent = record.researchConsent;
    if (researchConsent == null) {
      return <String>[
        _tSiteConsent(
          context,
          'No research consent has been recorded for this learner yet.',
        ),
      ];
    }
    return <String>[
      '${_tSiteConsent(context, 'Parent')}: ${record.researchParentName?.trim().isNotEmpty == true ? record.researchParentName!.trim() : _tSiteConsent(context, 'Parent unavailable')}',
      '${_tSiteConsent(context, 'Data share scope')}: ${_titleCase(researchConsent.dataShareScope.replaceAll('_', ' '))}',
      '${_tSiteConsent(context, 'Consent version')}: ${researchConsent.consentVersion?.trim().isNotEmpty == true ? researchConsent.consentVersion!.trim() : _tSiteConsent(context, 'Unavailable')}',
      '${_tSiteConsent(context, 'Consent document')}: ${_documentLabel(researchConsent.consentDocumentUrl)}',
    ];
  }

  String _booleanLabel(bool value) {
    return value ? _tSiteConsent(context, 'Allowed') : _tSiteConsent(context, 'Blocked');
  }

  String _dateRangeLabel(String? startDate, String? endDate) {
    final String start = startDate?.trim() ?? '';
    final String end = endDate?.trim() ?? '';
    if (start.isEmpty && end.isEmpty) {
      return _tSiteConsent(context, 'Not set');
    }
    return '$start -> $end';
  }

  String _documentLabel(String? value) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return _tSiteConsent(context, 'Not provided');
    }
    return trimmed;
  }

  Future<void> _loadData() async {
    final AppState appState = context.read<AppState>();
    final String? siteId = appState.activeSiteId;
    if (siteId == null || siteId.trim().isEmpty) {
      setState(() {
        _siteId = null;
        _records = <SiteConsentRecord>[];
        _loadError = _tSiteConsent(context, 'Site context unavailable right now');
      });
      return;
    }

    setState(() {
      _siteId = siteId;
      _isLoading = true;
      _loadError = null;
    });

    try {
      final List<SiteConsentRecord> records = await _service.listRecords(siteId);
      if (!mounted) {
        return;
      }
      setState(() {
        _records = records;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError =
            _tSiteConsent(context, 'Unable to load consent records right now');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openMediaDialog(SiteConsentRecord record) async {
    final _MediaConsentDraft? draft = await showDialog<_MediaConsentDraft>(
      context: context,
      builder: (BuildContext context) => _MediaConsentDialog(record: record),
    );
    if (draft == null || _siteId == null) {
      return;
    }
    final AppState appState = context.read<AppState>();
    setState(() {
      _isSaving = true;
    });
    try {
      await _service.saveMediaConsent(
        siteId: _siteId!,
        learnerId: record.learnerId,
        actorId: appState.userId ?? '',
        actorRole: appState.role?.name ?? 'site',
        photoCaptureAllowed: draft.photoCaptureAllowed,
        shareWithLinkedParents: draft.shareWithLinkedParents,
        marketingUseAllowed: draft.marketingUseAllowed,
        consentStatus: draft.consentStatus,
        consentStartDate: draft.consentStartDate,
        consentEndDate: draft.consentEndDate,
        consentDocumentUrl: draft.consentDocumentUrl,
      );
      if (!mounted) {
        return;
      }
      TelemetryService.instance.logEvent(
        event: 'consent.media.saved',
        role: 'site',
        siteId: _siteId,
        metadata: <String, dynamic>{
          'learner_id': record.learnerId,
          'status': draft.consentStatus,
        },
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tSiteConsent(context, 'Media consent saved'),
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
            _tSiteConsent(context, 'Unable to save media consent right now'),
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

  Future<void> _openResearchDialog(SiteConsentRecord record) async {
    final _ResearchConsentDraft? draft = await showDialog<_ResearchConsentDraft>(
      context: context,
      builder: (BuildContext context) => _ResearchConsentDialog(record: record),
    );
    if (draft == null || _siteId == null) {
      return;
    }
    final AppState appState = context.read<AppState>();
    setState(() {
      _isSaving = true;
    });
    try {
      await _service.saveResearchConsent(
        siteId: _siteId!,
        learnerId: record.learnerId,
        parentId: draft.parentId,
        actorId: appState.userId ?? '',
        actorRole: appState.role?.name ?? 'site',
        consentGiven: draft.consentGiven,
        dataShareScope: draft.dataShareScope,
        consentDocumentUrl: draft.consentDocumentUrl,
        consentVersion: draft.consentVersion,
      );
      if (!mounted) {
        return;
      }
      TelemetryService.instance.logEvent(
        event: 'consent.research.saved',
        role: 'site',
        siteId: _siteId,
        metadata: <String, dynamic>{
          'learner_id': record.learnerId,
          'parent_id': draft.parentId,
          'consent_given': draft.consentGiven,
        },
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tSiteConsent(context, 'Research consent saved'),
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
            _tSiteConsent(context, 'Unable to save research consent right now'),
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

  String _titleCase(String value) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      return normalized;
    }
    return normalized
        .split(RegExp(r'\s+'))
        .map((String word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }
}

class _MediaConsentDraft {
  const _MediaConsentDraft({
    required this.photoCaptureAllowed,
    required this.shareWithLinkedParents,
    required this.marketingUseAllowed,
    required this.consentStatus,
    this.consentStartDate,
    this.consentEndDate,
    this.consentDocumentUrl,
  });

  final bool photoCaptureAllowed;
  final bool shareWithLinkedParents;
  final bool marketingUseAllowed;
  final String consentStatus;
  final String? consentStartDate;
  final String? consentEndDate;
  final String? consentDocumentUrl;
}

class _MediaConsentDialog extends StatefulWidget {
  const _MediaConsentDialog({required this.record});

  final SiteConsentRecord record;

  @override
  State<_MediaConsentDialog> createState() => _MediaConsentDialogState();
}

class _MediaConsentDialogState extends State<_MediaConsentDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late bool _photoCaptureAllowed;
  late bool _shareWithLinkedParents;
  late bool _marketingUseAllowed;
  late String _consentStatus;
  late final TextEditingController _startDateController;
  late final TextEditingController _endDateController;
  late final TextEditingController _documentUrlController;

  @override
  void initState() {
    super.initState();
    final mediaConsent = widget.record.mediaConsent;
    _photoCaptureAllowed = mediaConsent?.photoCaptureAllowed ?? false;
    _shareWithLinkedParents = mediaConsent?.shareWithLinkedParents ?? false;
    _marketingUseAllowed = mediaConsent?.marketingUseAllowed ?? false;
    _consentStatus = mediaConsent?.consentStatus ?? 'active';
    _startDateController =
        TextEditingController(text: mediaConsent?.consentStartDate ?? '');
    _endDateController =
        TextEditingController(text: mediaConsent?.consentEndDate ?? '');
    _documentUrlController =
        TextEditingController(text: mediaConsent?.consentDocumentUrl ?? '');
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    _documentUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        '${_tSiteConsent(context, 'Media Consent')} · ${widget.record.learnerName}',
      ),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_tSiteConsent(context, 'Allow photo capture')),
                  value: _photoCaptureAllowed,
                  onChanged: (bool value) {
                    setState(() {
                      _photoCaptureAllowed = value;
                    });
                  },
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title:
                      Text(_tSiteConsent(context, 'Share with linked parents')),
                  value: _shareWithLinkedParents,
                  onChanged: (bool value) {
                    setState(() {
                      _shareWithLinkedParents = value;
                    });
                  },
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_tSiteConsent(context, 'Allow marketing use')),
                  value: _marketingUseAllowed,
                  onChanged: (bool value) {
                    setState(() {
                      _marketingUseAllowed = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _consentStatus,
                  decoration: InputDecoration(
                    labelText: _tSiteConsent(context, 'Consent status'),
                    border: const OutlineInputBorder(),
                  ),
                  items: <String>['active', 'pending', 'expired', 'revoked']
                      .map(
                        (String status) => DropdownMenuItem<String>(
                          value: status,
                          child: Text(_tSiteConsent(context, _titleCase(status))),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (String? value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _consentStatus = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _startDateController,
                  decoration: InputDecoration(
                    labelText:
                        _tSiteConsent(context, 'Consent start date (YYYY-MM-DD)'),
                    border: const OutlineInputBorder(),
                  ),
                  validator: _dateValidator(context),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _endDateController,
                  decoration: InputDecoration(
                    labelText:
                        _tSiteConsent(context, 'Consent end date (YYYY-MM-DD)'),
                    border: const OutlineInputBorder(),
                  ),
                  validator: _dateValidator(context),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _documentUrlController,
                  decoration: InputDecoration(
                    labelText: _tSiteConsent(context, 'Consent document URL'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_tSiteConsent(context, 'Cancel')),
        ),
        FilledButton(
          onPressed: () {
            final FormState? form = _formKey.currentState;
            if (form == null || !form.validate()) {
              return;
            }
            Navigator.of(context).pop(
              _MediaConsentDraft(
                photoCaptureAllowed: _photoCaptureAllowed,
                shareWithLinkedParents: _shareWithLinkedParents,
                marketingUseAllowed: _marketingUseAllowed,
                consentStatus: _consentStatus,
                consentStartDate: _nullableText(_startDateController.text),
                consentEndDate: _nullableText(_endDateController.text),
                consentDocumentUrl: _nullableText(_documentUrlController.text),
              ),
            );
          },
          child: Text(_tSiteConsent(context, 'Save')),
        ),
      ],
    );
  }

  FormFieldValidator<String> _dateValidator(BuildContext context) {
    return (String? value) {
      final String trimmed = (value ?? '').trim();
      if (trimmed.isEmpty) {
        return null;
      }
      if (DateTime.tryParse(trimmed) == null) {
        return _tSiteConsent(
          context,
          'Date must use YYYY-MM-DD',
        );
      }
      return null;
    };
  }

  String? _nullableText(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _titleCase(String value) {
    return value.isEmpty
        ? value
        : '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
  }
}

class _ResearchConsentDraft {
  const _ResearchConsentDraft({
    required this.parentId,
    required this.consentGiven,
    required this.dataShareScope,
    this.consentDocumentUrl,
    this.consentVersion,
  });

  final String parentId;
  final bool consentGiven;
  final String dataShareScope;
  final String? consentDocumentUrl;
  final String? consentVersion;
}

class _ResearchConsentDialog extends StatefulWidget {
  const _ResearchConsentDialog({required this.record});

  final SiteConsentRecord record;

  @override
  State<_ResearchConsentDialog> createState() => _ResearchConsentDialogState();
}

class _ResearchConsentDialogState extends State<_ResearchConsentDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late String _selectedParentId;
  late bool _consentGiven;
  late String _dataShareScope;
  late final TextEditingController _documentUrlController;
  late final TextEditingController _versionController;

  @override
  void initState() {
    super.initState();
    final researchConsent = widget.record.researchConsent;
    _selectedParentId = researchConsent?.parentId ??
        (widget.record.guardians.isNotEmpty
            ? widget.record.guardians.first.parentId
            : '');
    _consentGiven = researchConsent?.consentGiven ?? false;
    _dataShareScope = researchConsent?.dataShareScope ?? 'pseudonymised';
    _documentUrlController =
        TextEditingController(text: researchConsent?.consentDocumentUrl ?? '');
    _versionController =
        TextEditingController(text: researchConsent?.consentVersion ?? '');
  }

  @override
  void dispose() {
    _documentUrlController.dispose();
    _versionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        '${_tSiteConsent(context, 'Research Consent')} · ${widget.record.learnerName}',
      ),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                DropdownButtonFormField<String>(
                  initialValue: _selectedParentId.isEmpty ? null : _selectedParentId,
                  decoration: InputDecoration(
                    labelText: _tSiteConsent(context, 'Parent'),
                    border: const OutlineInputBorder(),
                  ),
                  items: widget.record.guardians
                      .map(
                        (SiteConsentGuardianOption guardian) =>
                            DropdownMenuItem<String>(
                          value: guardian.parentId,
                          child: Text(guardian.parentName),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (String? value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedParentId = value;
                    });
                  },
                  validator: (String? value) {
                    if ((value ?? '').trim().isEmpty) {
                      return _tSiteConsent(context, 'Parent selection is required');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_tSiteConsent(context, 'Research consent granted')),
                  value: _consentGiven,
                  onChanged: (bool value) {
                    setState(() {
                      _consentGiven = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _dataShareScope,
                  decoration: InputDecoration(
                    labelText: _tSiteConsent(context, 'Data share scope'),
                    border: const OutlineInputBorder(),
                  ),
                  items: <String>['pseudonymised', 'identifiable', 'none']
                      .map(
                        (String scope) => DropdownMenuItem<String>(
                          value: scope,
                          child: Text(
                            _tSiteConsent(
                              context,
                              _titleCase(scope.replaceAll('_', ' ')),
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (String? value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _dataShareScope = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _versionController,
                  decoration: InputDecoration(
                    labelText: _tSiteConsent(context, 'Consent version'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _documentUrlController,
                  decoration: InputDecoration(
                    labelText: _tSiteConsent(context, 'Consent document URL'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_tSiteConsent(context, 'Cancel')),
        ),
        FilledButton(
          onPressed: () {
            final FormState? form = _formKey.currentState;
            if (form == null || !form.validate()) {
              return;
            }
            Navigator.of(context).pop(
              _ResearchConsentDraft(
                parentId: _selectedParentId,
                consentGiven: _consentGiven,
                dataShareScope: _dataShareScope,
                consentDocumentUrl: _nullableText(_documentUrlController.text),
                consentVersion: _nullableText(_versionController.text),
              ),
            );
          },
          child: Text(_tSiteConsent(context, 'Save')),
        ),
      ],
    );
  }

  String? _nullableText(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _titleCase(String value) {
    if (value.isEmpty) {
      return value;
    }
    return value
        .split(RegExp(r'\s+'))
        .map((String word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }
}
