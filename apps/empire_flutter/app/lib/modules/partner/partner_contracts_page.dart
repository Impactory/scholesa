import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/workflow_surface_i18n.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';
import 'partner_models.dart';
import 'partner_service.dart';

String _tPartnerContracts(BuildContext context, String input) {
  return WorkflowSurfaceI18n.text(context, input);
}

class PartnerContractsPage extends StatefulWidget {
  const PartnerContractsPage({super.key});

  @override
  State<PartnerContractsPage> createState() => _PartnerContractsPageState();
}

class _PartnerContractsPageState extends State<PartnerContractsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        TelemetryService.instance.logEvent(
          event: 'cta.clicked',
          metadata: <String, dynamic>{
            'module': 'partner_contracts',
            'cta_id': 'change_tab',
            'tab': _tabController.index == 0 ? 'contracts' : 'launches',
          },
        );
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final PartnerService service = context.read<PartnerService>();
      Future.wait<void>(<Future<void>>[
        service.loadContracts(),
        service.loadPartnerLaunches(),
      ]);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: Text(_tPartnerContracts(context, 'Partner Workflows')),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: <Widget>[
            Tab(text: _tPartnerContracts(context, 'Contracts')),
            Tab(text: _tPartnerContracts(context, 'Launches')),
          ],
        ),
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _tabController,
        builder: (BuildContext context, Widget? child) {
          if (_tabController.index != 1) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton.extended(
            onPressed: _showCreatePartnerLaunchDialog,
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.rocket_launch_rounded),
            label: Text(_tPartnerContracts(context, 'Create Launch')),
          );
        },
      ),
      body: Consumer<PartnerService>(
        builder: (BuildContext context, PartnerService service, _) {
          if (service.isLoading &&
              service.contracts.isEmpty &&
              service.partnerLaunches.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (service.error != null &&
              service.contracts.isEmpty &&
              service.partnerLaunches.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: _buildLoadErrorState(service.error!, service),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: <Widget>[
              _buildContractsTab(service),
              _buildLaunchesTab(service),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContractsTab(PartnerService service) {
    if (service.error != null && service.contracts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _buildLoadErrorState(service.error!, service),
      );
    }

    if (service.error != null && service.contracts.isNotEmpty) {
      return Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _buildStaleDataBanner(service.error!),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await service.loadContracts();
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: service.contracts.length,
                itemBuilder: (BuildContext context, int index) {
                  return _buildContractCard(service.contracts[index]);
                },
              ),
            ),
          ),
        ],
      );
    }

    if (service.contracts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.description_rounded,
        title: _tPartnerContracts(context, 'No Contracts Yet'),
        message: _tPartnerContracts(
          context,
          'Your contracts will appear here',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        TelemetryService.instance.logEvent(
          event: 'cta.clicked',
          metadata: const <String, dynamic>{
            'module': 'partner_contracts',
            'cta_id': 'refresh_contracts',
            'surface': 'contracts_list',
          },
        );
        await service.loadContracts();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: service.contracts.length,
        itemBuilder: (BuildContext context, int index) {
          return _buildContractCard(service.contracts[index]);
        },
      ),
    );
  }

  Widget _buildLaunchesTab(PartnerService service) {
    if (service.error != null && service.partnerLaunches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _buildLoadErrorState(service.error!, service),
      );
    }

    if (service.error != null && service.partnerLaunches.isNotEmpty) {
      return Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _buildStaleDataBanner(service.error!),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await service.loadPartnerLaunches();
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: service.partnerLaunches.length,
                itemBuilder: (BuildContext context, int index) {
                  return _buildLaunchCard(service.partnerLaunches[index]);
                },
              ),
            ),
          ),
        ],
      );
    }

    if (service.partnerLaunches.isEmpty) {
      return _buildEmptyState(
        icon: Icons.rocket_launch_rounded,
        title: _tPartnerContracts(context, 'No Launches Yet'),
        message: _tPartnerContracts(
          context,
          'Partner launch plans will appear here',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        TelemetryService.instance.logEvent(
          event: 'cta.clicked',
          metadata: const <String, dynamic>{
            'module': 'partner_contracts',
            'cta_id': 'refresh_partner_launches',
            'surface': 'launches_list',
          },
        );
        await service.loadPartnerLaunches();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: service.partnerLaunches.length,
        itemBuilder: (BuildContext context, int index) {
          return _buildLaunchCard(service.partnerLaunches[index]);
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 64, color: const Color(0xFF6366F1)),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ScholesaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              color: ScholesaColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadErrorState(String message, PartnerService service) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.error_outline_rounded, color: ScholesaColors.error),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Unable to load partner workflows',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ScholesaColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: ScholesaColors.textSecondary),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              await Future.wait<void>(<Future<void>>[
                service.loadContracts(),
                service.loadPartnerLaunches(),
              ]);
            },
            icon: const Icon(Icons.refresh_rounded),
            label: Text(_tPartnerContracts(context, 'Retry')),
          ),
        ],
      ),
    );
  }

  Widget _buildStaleDataBanner(String message) {
    return Container(
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
              _tPartnerContracts(context, 'Showing last loaded workflow data. ') + message,
              style: const TextStyle(color: Color(0xFF92400E)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContractCard(PartnerContract contract) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showContractDetails(contract),
        borderRadius: BorderRadius.circular(12),
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
                      gradient: const LinearGradient(
                        colors: <Color>[Color(0xFF6366F1), Color(0xFF818CF8)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.description_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          contract.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: ScholesaColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_tPartnerContracts(context, 'Site:')} ${contract.siteId}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: ScholesaColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(contract.status),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _tPartnerContracts(context, 'Total Value'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: ScholesaColors.textSecondary,
                        ),
                      ),
                      Text(
                        '\$${contract.totalValue.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: ScholesaColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        _tPartnerContracts(context, 'Deliverables'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: ScholesaColors.textSecondary,
                        ),
                      ),
                      Text(
                        '${contract.deliverables.length}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: ScholesaColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLaunchCard(PartnerLaunch launch) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showLaunchDetails(launch),
        borderRadius: BorderRadius.circular(12),
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
                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.rocket_launch_rounded,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          launch.partnerName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${launch.region} • ${launch.locale}',
                          style: const TextStyle(
                            color: ScholesaColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildLaunchLifecycleChip(launch.status),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _LifecyclePill(
                    label:
                        '${_tPartnerContracts(context, 'Due Diligence')}: ${launch.dueDiligenceStatus}',
                    color: _launchStatusColor(launch.dueDiligenceStatus),
                  ),
                  _LifecyclePill(
                    label:
                        '${_tPartnerContracts(context, 'Planning Workshop')}: ${launch.planningWorkshopStatus}',
                    color: _launchStatusColor(launch.planningWorkshopStatus),
                  ),
                  _LifecyclePill(
                    label:
                        '${_tPartnerContracts(context, 'Trainer of Trainers')}: ${launch.trainerOfTrainersStatus}',
                    color: _launchStatusColor(launch.trainerOfTrainersStatus),
                  ),
                  _LifecyclePill(
                    label:
                        '${_tPartnerContracts(context, 'KPI Logging')}: ${launch.kpiLoggingStatus}',
                    color: _launchStatusColor(launch.kpiLoggingStatus),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${_tPartnerContracts(context, 'Pilot Cohorts')}: ${launch.pilotCohortCount ?? 0}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(ContractStatus status) {
    late final Color color;
    late final String label;
    switch (status) {
      case ContractStatus.draft:
        color = Colors.grey;
        label = _tPartnerContracts(context, 'Draft');
      case ContractStatus.submitted:
        color = Colors.orange;
        label = _tPartnerContracts(context, 'Submitted');
      case ContractStatus.negotiation:
        color = Colors.blue;
        label = _tPartnerContracts(context, 'Negotiation');
      case ContractStatus.approved:
        color = Colors.teal;
        label = _tPartnerContracts(context, 'Approved');
      case ContractStatus.active:
        color = Colors.green;
        label = _tPartnerContracts(context, 'Active');
      case ContractStatus.completed:
        color = Colors.purple;
        label = _tPartnerContracts(context, 'Completed');
      case ContractStatus.terminated:
        color = Colors.red;
        label = _tPartnerContracts(context, 'Terminated');
    }

    return _LifecyclePill(label: label, color: color);
  }

  Widget _buildLaunchLifecycleChip(String status) {
    return _LifecyclePill(
      label: status,
      color: _launchStatusColor(status),
    );
  }

  void _showContractDetails(PartnerContract contract) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'partner_contracts',
        'cta_id': 'open_contract_details',
        'surface': 'contract_card',
        'contract_id': contract.id,
        'status': contract.status.name,
      },
    );
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ScholesaColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (BuildContext context, ScrollController scrollController) =>
            Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: scrollController,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      contract.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildStatusChip(contract.status),
                ],
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                _tPartnerContracts(context, 'Total Value'),
                '\$${contract.totalValue.toStringAsFixed(2)}',
              ),
              _buildInfoRow(
                _tPartnerContracts(context, 'Site ID'),
                contract.siteId,
              ),
              if (contract.startDate != null)
                _buildInfoRow(
                  _tPartnerContracts(context, 'Start Date'),
                  _formatDate(contract.startDate!),
                ),
              if (contract.endDate != null)
                _buildInfoRow(
                  _tPartnerContracts(context, 'End Date'),
                  _formatDate(contract.endDate!),
                ),
              const SizedBox(height: 24),
              Text(
                _tPartnerContracts(context, 'Deliverables'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              if (contract.deliverables.isEmpty)
                Text(
                  _tPartnerContracts(context, 'No deliverables defined'),
                  style: const TextStyle(color: ScholesaColors.textSecondary),
                )
              else
                ...contract.deliverables.map((PartnerDeliverable deliverable) {
                  final bool accepted =
                      deliverable.status == DeliverableStatus.accepted;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      accepted
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: accepted ? Colors.green : Colors.grey,
                    ),
                    title: Text(deliverable.title),
                    subtitle: Text(deliverable.status.name),
                  );
                }),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_tPartnerContracts(context, 'Close')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLaunchDetails(PartnerLaunch launch) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'partner_contracts',
        'cta_id': 'open_partner_launch_details',
        'launch_id': launch.id,
      },
    );
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ScholesaColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    launch.partnerName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildLaunchLifecycleChip(launch.status),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              _tPartnerContracts(context, 'Region'),
              launch.region,
            ),
            _buildInfoRow(
              _tPartnerContracts(context, 'Locale'),
              launch.locale,
            ),
            _buildInfoRow(
              _tPartnerContracts(context, 'Pilot Cohorts'),
              '${launch.pilotCohortCount ?? 0}',
            ),
            _buildInfoRow(
              _tPartnerContracts(context, 'Due Diligence'),
              launch.dueDiligenceStatus,
            ),
            _buildInfoRow(
              _tPartnerContracts(context, 'Planning Workshop'),
              launch.planningWorkshopStatus,
            ),
            _buildInfoRow(
              _tPartnerContracts(context, 'Trainer of Trainers'),
              launch.trainerOfTrainersStatus,
            ),
            _buildInfoRow(
              _tPartnerContracts(context, 'KPI Logging'),
              launch.kpiLoggingStatus,
            ),
            _buildInfoRow(
              _tPartnerContracts(context, '90-Day Review'),
              launch.review90DayStatus,
            ),
            if ((launch.notes ?? '').trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                launch.notes!.trim(),
                style: const TextStyle(color: ScholesaColors.textSecondary),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_tPartnerContracts(context, 'Close')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreatePartnerLaunchDialog() async {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{
        'module': 'partner_contracts',
        'cta_id': 'open_create_partner_launch_dialog',
      },
    );

    final TextEditingController partnerNameController = TextEditingController();
    final TextEditingController regionController =
        TextEditingController(text: 'APAC');
    final TextEditingController localeController =
        TextEditingController(text: 'en');
    final TextEditingController pilotCountController =
        TextEditingController(text: '1');
    final TextEditingController notesController = TextEditingController();
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context,
            void Function(void Function()) setLocalState) {
          return AlertDialog(
            title: Text(_tPartnerContracts(context, 'Create Launch')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: partnerNameController,
                    decoration: InputDecoration(
                      labelText: _tPartnerContracts(context, 'Partner Name'),
                      prefixIcon: const Icon(Icons.business_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: regionController,
                    decoration: InputDecoration(
                      labelText: _tPartnerContracts(context, 'Region'),
                      prefixIcon: const Icon(Icons.public_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: localeController,
                    decoration: InputDecoration(
                      labelText: _tPartnerContracts(context, 'Locale'),
                      prefixIcon: const Icon(Icons.language_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pilotCountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: _tPartnerContracts(context, 'Pilot Cohorts'),
                      prefixIcon: const Icon(Icons.groups_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: _tPartnerContracts(context, 'Notes'),
                      prefixIcon: const Icon(Icons.notes_rounded),
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed:
                    isSubmitting ? null : () => Navigator.pop(dialogContext),
                child: Text(_tPartnerContracts(context, 'Close')),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final String partnerName =
                            partnerNameController.text.trim();
                        if (partnerName.isEmpty) {
                          return;
                        }
                        setLocalState(() => isSubmitting = true);
                        final int pilotCount = int.tryParse(
                              pilotCountController.text.trim(),
                            ) ??
                            1;
                        final PartnerLaunch? created = await context
                            .read<PartnerService>()
                            .createPartnerLaunch(
                              partnerName: partnerName,
                              region: regionController.text.trim().isEmpty
                                  ? 'APAC'
                                  : regionController.text.trim(),
                              locale: localeController.text.trim().isEmpty
                                  ? 'en'
                                  : localeController.text.trim(),
                              pilotCohortCount: pilotCount,
                              notes: notesController.text.trim(),
                            );
                        if (!mounted || !dialogContext.mounted) {
                          return;
                        }
                        if (created != null) {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _tPartnerContracts(context, 'Launch created'),
                              ),
                            ),
                          );
                          return;
                        }
                        setLocalState(() => isSubmitting = false);
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.read<PartnerService>().error ??
                                  _tPartnerContracts(
                                    context,
                                    'Failed to create launch',
                                  ),
                            ),
                          ),
                        );
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_tPartnerContracts(context, 'Create Launch')),
              ),
            ],
          );
        },
      ),
    );

    partnerNameController.dispose();
    regionController.dispose();
    localeController.dispose();
    pilotCountController.dispose();
    notesController.dispose();
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(color: ScholesaColors.textSecondary),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}

class _LifecyclePill extends StatelessWidget {
  const _LifecyclePill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

Color _launchStatusColor(String value) {
  switch (value.trim().toLowerCase()) {
    case 'completed':
    case 'active':
    case 'confirmed':
    case 'approved':
      return Colors.green;
    case 'planning':
    case 'scheduled':
      return Colors.indigo;
    case 'pending':
    case 'draft':
      return Colors.orange;
    default:
      return Colors.blueGrey;
  }
}
