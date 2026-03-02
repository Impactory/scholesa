import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';
import 'partner_models.dart';
import 'partner_service.dart';

const Map<String, String> _partnerContractsEs = <String, String>{
  'My Contracts': 'Mis contratos',
  'No Contracts Yet': 'Aún no hay contratos',
  'Your contracts will appear here': 'Tus contratos aparecerán aquí',
  'Site:': 'Sede:',
  'Total Value': 'Valor total',
  'Deliverables': 'Entregables',
  'Draft': 'Borrador',
  'Submitted': 'Enviado',
  'Negotiation': 'Negociación',
  'Approved': 'Aprobado',
  'Active': 'Activo',
  'Completed': 'Completado',
  'Terminated': 'Terminado',
  'Site ID': 'ID de sede',
  'Start Date': 'Fecha de inicio',
  'End Date': 'Fecha de fin',
  'No deliverables defined': 'No hay entregables definidos',
  'Close': 'Cerrar',
};

String _tPartnerContracts(BuildContext context, String input) {
  final String locale = Localizations.localeOf(context).languageCode;
  if (locale != 'es') return input;
  return _partnerContractsEs[input] ?? input;
}

/// Partner contracts management page
/// Based on docs/16_PARTNER_CONTRACTING_WORKFLOWS_SPEC.md
class PartnerContractsPage extends StatefulWidget {
  const PartnerContractsPage({super.key});

  @override
  State<PartnerContractsPage> createState() => _PartnerContractsPageState();
}

class _PartnerContractsPageState extends State<PartnerContractsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PartnerService>().loadContracts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: Text(_tPartnerContracts(context, 'My Contracts')),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
      ),
      body: Consumer<PartnerService>(
        builder: (BuildContext context, PartnerService service, _) {
          if (service.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (service.contracts.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'module': 'partner_contracts',
                  'cta_id': 'refresh_contracts',
                  'surface': 'contracts_list',
                },
              );
              return service.loadContracts();
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: service.contracts.length,
              itemBuilder: (BuildContext context, int index) {
                return _buildContractCard(service.contracts[index]);
              },
            ),
          );
        },
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
              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.description_rounded,
              size: 64,
              color: Color(0xFF6366F1),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _tPartnerContracts(context, 'No Contracts Yet'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ScholesaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _tPartnerContracts(context, 'Your contracts will appear here'),
            style: TextStyle(
              fontSize: 14,
              color: ScholesaColors.textSecondary,
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
                    child: const Icon(Icons.description_rounded,
                        color: Colors.white, size: 24),
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
                        style: TextStyle(
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
                        style: TextStyle(
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

  Widget _buildStatusChip(ContractStatus status) {
    Color color;
    String label;
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
                  '\$${contract.totalValue.toStringAsFixed(2)}'),
              _buildInfoRow(_tPartnerContracts(context, 'Site ID'), contract.siteId),
              if (contract.startDate != null)
                _buildInfoRow(_tPartnerContracts(context, 'Start Date'),
                    _formatDate(contract.startDate!)),
              if (contract.endDate != null)
                _buildInfoRow(_tPartnerContracts(context, 'End Date'),
                    _formatDate(contract.endDate!)),
              const SizedBox(height: 24),
              Text(
                _tPartnerContracts(context, 'Deliverables'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              if (contract.deliverables.isEmpty)
                Text(
                  _tPartnerContracts(context, 'No deliverables defined'),
                  style: TextStyle(color: ScholesaColors.textSecondary),
                )
              else
                ...contract.deliverables.map((PartnerDeliverable d) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        d.status == DeliverableStatus.accepted
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: d.status == DeliverableStatus.accepted
                            ? Colors.green
                            : Colors.grey,
                      ),
                      title: Text(d.title),
                      subtitle: Text(d.status.name),
                    )),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  TelemetryService.instance.logEvent(
                    event: 'cta.clicked',
                    metadata: <String, dynamic>{
                      'module': 'partner_contracts',
                      'cta_id': 'close_contract_details',
                      'surface': 'contract_details_sheet',
                      'contract_id': contract.id,
                    },
                  );
                  Navigator.pop(context);
                },
                child: Text(_tPartnerContracts(context, 'Close')),
              ),
            ],
          ),
        ),
      ),
    );
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
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
