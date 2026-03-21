import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/app_state.dart';
import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../../i18n/workflow_surface_i18n.dart';
import '../../services/firestore_service.dart';
import '../../services/telemetry_service.dart';
import '../../ui/auth/global_session_menu.dart';
import '../../ui/theme/scholesa_theme.dart';

String _tPartnerDeliverables(BuildContext context, String input) {
  return WorkflowSurfaceI18n.text(context, input);
}

class PartnerDeliverablesPage extends StatefulWidget {
  const PartnerDeliverablesPage({super.key});

  @override
  State<PartnerDeliverablesPage> createState() => _PartnerDeliverablesPageState();
}

class _PartnerDeliverablesPageState extends State<PartnerDeliverablesPage> {
  bool _isLoading = false;
  String? _error;
  List<_PartnerContractDeliverables> _contractDeliverables =
      const <_PartnerContractDeliverables>[];

  String _t(String input) => _tPartnerDeliverables(context, input);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDeliverables();
    });
  }

  FirestoreService? _maybeFirestoreService() {
    try {
      return context.read<FirestoreService>();
    } catch (_) {
      return null;
    }
  }

  String _partnerId() {
    final AppState appState = context.read<AppState>();
    return appState.userId?.trim() ?? '';
  }

  Future<void> _loadDeliverables() async {
    final FirestoreService? firestoreService = _maybeFirestoreService();
    final String partnerId = _partnerId();

    if (firestoreService == null) {
      setState(() {
        _error = _t('Deliverable storage unavailable right now.');
        _isLoading = false;
      });
      return;
    }

    if (partnerId.isEmpty) {
      setState(() {
        _error = _t('Partner identity unavailable right now.');
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final List<Map<String, dynamic>> contractDocs =
          await firestoreService.queryCollection(
        'partnerContracts',
        where: <List<dynamic>>[
          <dynamic>['partnerId', partnerId]
        ],
      );
      final FirebaseFirestore firestore = firestoreService.firestore;
      final PartnerDeliverableRepository deliverableRepository =
          PartnerDeliverableRepository(firestore: firestore);

      final List<_PartnerContractDeliverables> contractDeliverables =
          await Future.wait<_PartnerContractDeliverables>(
        contractDocs.map((Map<String, dynamic> doc) async {
          final String contractId = doc['id'] as String? ?? '';
          final List<PartnerDeliverableModel> deliverables =
              contractId.isEmpty
                  ? const <PartnerDeliverableModel>[]
                  : await deliverableRepository.listByContract(
                      contractId,
                      limit: 50,
                    );
          return _PartnerContractDeliverables(
            contractId: contractId,
            title: doc['title'] as String? ?? '',
            siteId: doc['siteId'] as String? ?? '',
            status: doc['status'] as String? ?? 'draft',
            deliverables: deliverables,
          );
        }),
      );

      contractDeliverables.sort((_PartnerContractDeliverables a,
          _PartnerContractDeliverables b) {
        final int aCount = a.deliverables.length;
        final int bCount = b.deliverables.length;
        if (aCount != bCount) {
          return bCount.compareTo(aCount);
        }
        return a.title.compareTo(b.title);
      });

      if (!mounted) return;
      setState(() {
        _contractDeliverables = contractDeliverables;
        _error = null;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _t('Unable to load partner deliverables right now.');
        _isLoading = false;
      });
    }
  }

  Future<void> _showSubmitDeliverableDialog() async {
    if (_contractDeliverables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('Contracts must exist before you can submit deliverables here.'),
          ),
        ),
      );
      return;
    }

    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descriptionController =
        TextEditingController();
    final TextEditingController evidenceUrlController =
        TextEditingController();
    String selectedContractId = _contractDeliverables.first.contractId;

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(_t('Submit Deliverable')),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    initialValue: selectedContractId,
                    decoration: InputDecoration(labelText: _t('Contract')),
                    items: _contractDeliverables
                        .map(
                          (_PartnerContractDeliverables contract) =>
                              DropdownMenuItem<String>(
                            value: contract.contractId,
                            child: Text(
                              contract.displayTitle(context),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (String? value) {
                      if (value == null || value.isEmpty) return;
                      selectedContractId = value;
                    },
                    validator: (String? value) {
                      if (value == null || value.isEmpty) {
                        return _t('Choose a contract');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: titleController,
                    decoration: InputDecoration(labelText: _t('Title')),
                    validator: (String? value) {
                      if ((value ?? '').trim().isEmpty) {
                        return _t('Enter a deliverable title');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descriptionController,
                    decoration: InputDecoration(labelText: _t('Description')),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: evidenceUrlController,
                    decoration: InputDecoration(labelText: _t('Evidence URL')),
                    validator: (String? value) {
                      final String normalized = (value ?? '').trim();
                      if (normalized.isEmpty) return null;
                      final Uri? uri = Uri.tryParse(normalized);
                      if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
                        return _t(
                          'Enter a valid evidence URL or leave it blank',
                        );
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_t('Cancel')),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) {
                  return;
                }
                Navigator.of(context).pop();
                await _submitDeliverable(
                  contractId: selectedContractId,
                  title: titleController.text.trim(),
                  description: descriptionController.text.trim(),
                  evidenceUrl: evidenceUrlController.text.trim(),
                );
              },
              child: Text(_t('Submit')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitDeliverable({
    required String contractId,
    required String title,
    required String description,
    required String evidenceUrl,
  }) async {
    final FirestoreService? firestoreService = _maybeFirestoreService();
    final String partnerId = _partnerId();
    if (firestoreService == null || partnerId.isEmpty) {
      return;
    }
    final PartnerDeliverableRepository repository = PartnerDeliverableRepository(
      firestore: firestoreService.firestore,
    );
    try {
      TelemetryService.instance.logEvent(
        event: 'cta.clicked',
        metadata: <String, dynamic>{
          'module': 'partner_deliverables',
          'cta_id': 'submit_deliverable',
          'contract_id': contractId,
        },
      );
      await repository.submit(
        contractId: contractId,
        title: title,
        description: description.isEmpty ? null : description,
        evidenceUrl: evidenceUrl.isEmpty ? null : evidenceUrl,
        submittedBy: partnerId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Deliverable submitted.'))),
      );
      await _loadDeliverables();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('Unable to submit deliverable right now.')),
        ),
      );
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return _t('Not scheduled');
    final DateTime value = timestamp.toDate();
    return '${value.month}/${value.day}/${value.year}';
  }

  Color _statusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'accepted':
        return ScholesaColors.success;
      case 'rejected':
        return ScholesaColors.error;
      case 'planned':
      case 'draft':
        return ScholesaColors.warning;
      default:
        return ScholesaColors.info;
    }
  }

  String _statusLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case 'accepted':
        return _t('Accepted');
      case 'rejected':
        return _t('Rejected');
      case 'submitted':
        return _t('Submitted');
      case 'approved':
        return _t('Approved');
      case 'pending':
        return _t('Pending');
      case 'active':
        return _t('Active');
      case 'draft':
      case 'planned':
        return _t('Draft');
      default:
        final String normalized = status.trim();
        return normalized.isEmpty ? _t('Unknown') : normalized;
    }
  }

  Widget _buildContractSection(_PartnerContractDeliverables contract) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
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
                      Text(
                        contract.displayTitle(context),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_t('Site')}: ${contract.siteId.trim().isEmpty ? _t('Site unavailable') : contract.siteId.trim()}',
                        style: TextStyle(color: context.schTextSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(contract.status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _statusLabel(contract.status),
                    style: TextStyle(
                      color: _statusColor(contract.status),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (contract.deliverables.isEmpty)
              Text(
                _t('No deliverables submitted yet'),
                style: TextStyle(color: context.schTextSecondary),
              )
            else
              ...contract.deliverables.map((PartnerDeliverableModel deliverable) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.schSurfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                deliverable.title.trim().isEmpty
                                    ? _t('Title unavailable')
                                    : deliverable.title.trim(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              _statusLabel(deliverable.status),
                              style: TextStyle(
                                color: _statusColor(deliverable.status),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        if ((deliverable.description ?? '').trim().isNotEmpty) ...<
                            Widget>[
                          const SizedBox(height: 6),
                          Text(deliverable.description!.trim()),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          '${_t('Submitted on')}: ${_formatDate(deliverable.submittedAt)}',
                          style: TextStyle(color: context.schTextSecondary),
                        ),
                        if ((deliverable.evidenceUrl ?? '').trim().isNotEmpty)
                          Text(
                            '${_t('Evidence URL')}: ${deliverable.evidenceUrl!.trim()}',
                            style: TextStyle(color: context.schTextSecondary),
                          ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasContracts = _contractDeliverables.isNotEmpty;

    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: Text(_t('Partner Deliverables')),
        backgroundColor: ScholesaColors.partnerGradient.colors.first,
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            tooltip: _t('Refresh'),
            onPressed: _loadDeliverables,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SessionMenuButton(
            foregroundColor: Colors.white,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showSubmitDeliverableDialog,
        backgroundColor: ScholesaColors.partnerGradient.colors.first,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.upload_file_rounded),
        label: Text(_t('Submit Deliverable')),
      ),
      body: Builder(
        builder: (BuildContext context) {
          if (_isLoading && !hasContracts) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_error != null && !hasContracts) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _buildLoadErrorState(),
              ),
            );
          }
          if (!hasContracts) {
            return _PartnerEmptyState(
              icon: Icons.assignment_outlined,
              title: _t('No partner contracts available yet'),
              message: _t(
                'Contracts must exist before you can submit deliverables here.',
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _loadDeliverables,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildStaleDataBanner(),
                  ),
                if (_contractDeliverables.every(
                  (_PartnerContractDeliverables contract) =>
                      contract.deliverables.isEmpty,
                ))
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      _t(
                        'Deliverables linked to your partner contracts will appear here.',
                      ),
                      style: TextStyle(color: Colors.blue.shade800),
                    ),
                  ),
                ..._contractDeliverables
                    .map(_buildContractSection),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.error_outline_rounded, color: ScholesaColors.error),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _t('We could not load partner deliverables right now. Retry to check the current state.'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ScholesaColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? _t('Unable to load partner deliverables right now.'),
            style: TextStyle(color: context.schTextSecondary),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: _loadDeliverables,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(_t('Retry')),
          ),
        ],
      ),
    );
  }

  Widget _buildStaleDataBanner() {
    final String message =
        _t('Unable to refresh partner deliverables right now. Showing the last successful data.') +
            (_error == null ? '' : ' ${_error!}');
    return Semantics(
      container: true,
      liveRegion: true,
      label: message,
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Color(0xFF92400E)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartnerContractDeliverables {
  const _PartnerContractDeliverables({
    required this.contractId,
    required this.title,
    required this.siteId,
    required this.status,
    required this.deliverables,
  });

  final String contractId;
  final String title;
  final String siteId;
  final String status;
  final List<PartnerDeliverableModel> deliverables;

  String displayTitle(BuildContext context) {
    if (title.trim().isEmpty) {
      return _tPartnerDeliverables(context, 'Contract unavailable');
    }
    return title.trim();
  }
}

class _PartnerEmptyState extends StatelessWidget {
  const _PartnerEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48, color: ScholesaColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.schTextSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
