import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/app_state.dart';
import '../../domain/models.dart';
import '../../i18n/parent_surface_i18n.dart';
import '../../ui/theme/scholesa_theme.dart';
import 'parent_consent_service.dart';

class ParentConsentPage extends StatefulWidget {
  const ParentConsentPage({
    super.key,
    this.service,
  });

  final ParentConsentService? service;

  @override
  State<ParentConsentPage> createState() => _ParentConsentPageState();
}

class _ParentConsentPageState extends State<ParentConsentPage> {
  late final ParentConsentService _service =
      widget.service ?? ParentConsentService();

  List<ParentConsentRecord> _records = <ParentConsentRecord>[];
  bool _isLoading = false;
  String? _loadError;

  String _t(String input) => ParentSurfaceI18n.text(context, input);

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
        title: Text(_t('Consent Records')),
        backgroundColor: ScholesaColors.parent,
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            tooltip: _t('Refresh'),
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
          _t('Loading...'),
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
          _t(
            'View the live consent records currently on file for your linked learners. Contact your site admin to request changes.',
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
              _loadError ?? _t('Unable to load consent records right now'),
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
                label: Text(_t('Retry')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow() {
    final int mediaConfiguredCount = _records
        .where((ParentConsentRecord record) => record.mediaConsent != null)
        .length;
    final int researchConfiguredCount = _records
        .where((ParentConsentRecord record) => record.researchConsent != null)
        .length;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        _buildSummaryCard(_t('Learners'), _records.length.toString()),
        _buildSummaryCard(
          _t('Media Configured'),
          mediaConfiguredCount.toString(),
        ),
        _buildSummaryCard(
          _t('Research Configured'),
          researchConfiguredCount.toString(),
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
          _t('No linked learner consent records are available right now.'),
          style: const TextStyle(color: ScholesaColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildRecordCard(ParentConsentRecord record) {
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
            const SizedBox(height: 6),
            Text(
              '${_t('Site')}: ${record.siteId?.trim().isNotEmpty == true ? record.siteId!.trim() : _t('Site unavailable')}',
              style: const TextStyle(color: ScholesaColors.textSecondary),
            ),
            const SizedBox(height: 12),
            _buildConsentSection(
              title: _t('Media Consent'),
              status: _mediaStatusLabel(record.mediaConsent),
              details: _mediaDetails(record.mediaConsent),
            ),
            const SizedBox(height: 16),
            _buildConsentSection(
              title: _t('Research Consent'),
              status: _researchStatusLabel(record.researchConsent),
              details: _researchDetails(record.researchConsent),
            ),
            const SizedBox(height: 12),
            Text(
              _t(
                'This screen is view-only. Contact your site admin to change these records.',
              ),
              style: const TextStyle(color: ScholesaColors.textSecondary),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: ScholesaColors.parent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    color: ScholesaColors.parent,
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
        ],
      ),
    );
  }

  String _mediaStatusLabel(MediaConsentModel? mediaConsent) {
    if (mediaConsent == null) {
      return _t('Not configured');
    }
    return _t(_titleCase(mediaConsent.consentStatus));
  }

  String _researchStatusLabel(ResearchConsentModel? researchConsent) {
    if (researchConsent == null) {
      return _t('Not configured');
    }
    if (researchConsent.revokedAt != null || !researchConsent.consentGiven) {
      return _t('Withheld');
    }
    return _t('Granted');
  }

  List<String> _mediaDetails(MediaConsentModel? mediaConsent) {
    if (mediaConsent == null) {
      return <String>[
        _t('No site media consent has been recorded for this learner yet.'),
      ];
    }
    return <String>[
      '${_t('Photo capture')}: ${_booleanLabel(mediaConsent.photoCaptureAllowed)}',
      '${_t('Share with linked parents')}: ${_booleanLabel(mediaConsent.shareWithLinkedParents)}',
      '${_t('Marketing use')}: ${_booleanLabel(mediaConsent.marketingUseAllowed)}',
      '${_t('Consent window')}: ${_dateRangeLabel(mediaConsent.consentStartDate, mediaConsent.consentEndDate)}',
      '${_t('Consent document')}: ${_documentLabel(mediaConsent.consentDocumentUrl)}',
    ];
  }

  List<String> _researchDetails(ResearchConsentModel? researchConsent) {
    if (researchConsent == null) {
      return <String>[
        _t(
          'No research consent has been recorded for your account for this learner.',
        ),
      ];
    }
    return <String>[
      '${_t('Parent account')}: ${researchConsent.parentId}',
      '${_t('Data share scope')}: ${_titleCase(researchConsent.dataShareScope.replaceAll('_', ' '))}',
      '${_t('Consent version')}: ${researchConsent.consentVersion?.trim().isNotEmpty == true ? researchConsent.consentVersion!.trim() : _t('Unavailable')}',
      '${_t('Consent document')}: ${_documentLabel(researchConsent.consentDocumentUrl)}',
    ];
  }

  String _booleanLabel(bool value) {
    return value ? _t('Allowed') : _t('Blocked');
  }

  String _dateRangeLabel(String? startDate, String? endDate) {
    final String start = startDate?.trim() ?? '';
    final String end = endDate?.trim() ?? '';
    if (start.isEmpty && end.isEmpty) {
      return _t('Not set');
    }
    return '$start -> $end';
  }

  String _documentLabel(String? value) {
    final String trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? _t('Not provided') : trimmed;
  }

  Future<void> _loadData() async {
    final String parentId = context.read<AppState>().userId?.trim() ?? '';
    if (parentId.isEmpty) {
      setState(() {
        _records = <ParentConsentRecord>[];
        _loadError = _t('Parent context unavailable right now');
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final List<ParentConsentRecord> records = await _service.listRecords(parentId);
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
        _loadError = _t('Unable to load consent records right now');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
