import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../ui/theme/scholesa_theme.dart';
import 'partner_models.dart';
import 'partner_service.dart';

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
        title: const Text('My Contracts'),
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
            onRefresh: () => service.loadContracts(),
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
          const Text(
            'No Contracts Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ScholesaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your contracts will appear here',
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
                    child: const Icon(Icons.description_rounded, color: Colors.white, size: 24),
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
                          'Site: ${contract.siteId}',
                          style: TextStyle(
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
                        'Total Value',
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
                        'Deliverables',
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
        label = 'Draft';
      case ContractStatus.submitted:
        color = Colors.orange;
        label = 'Submitted';
      case ContractStatus.negotiation:
        color = Colors.blue;
        label = 'Negotiation';
      case ContractStatus.approved:
        color = Colors.teal;
        label = 'Approved';
      case ContractStatus.active:
        color = Colors.green;
        label = 'Active';
      case ContractStatus.completed:
        color = Colors.purple;
        label = 'Completed';
      case ContractStatus.terminated:
        color = Colors.red;
        label = 'Terminated';
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
        builder: (BuildContext context, ScrollController scrollController) => Padding(
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
              _buildInfoRow('Total Value', '\$${contract.totalValue.toStringAsFixed(2)}'),
              _buildInfoRow('Site ID', contract.siteId),
              if (contract.startDate != null)
                _buildInfoRow('Start Date', _formatDate(contract.startDate!)),
              if (contract.endDate != null)
                _buildInfoRow('End Date', _formatDate(contract.endDate!)),
              const SizedBox(height: 24),
              const Text(
                'Deliverables',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              if (contract.deliverables.isEmpty)
                Text(
                  'No deliverables defined',
                  style: TextStyle(color: ScholesaColors.textSecondary),
                )
              else
                ...contract.deliverables.map((PartnerDeliverable d) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    d.status == DeliverableStatus.accepted
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: d.status == DeliverableStatus.accepted ? Colors.green : Colors.grey,
                  ),
                  title: Text(d.title),
                  subtitle: Text(d.status.name),
                )),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
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
            style: TextStyle(color: ScholesaColors.textSecondary),
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
