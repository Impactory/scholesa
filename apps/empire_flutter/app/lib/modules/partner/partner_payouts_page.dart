import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../ui/theme/scholesa_theme.dart';
import 'partner_models.dart';
import 'partner_service.dart';

/// Partner payouts management page
/// Based on docs/16_PARTNER_CONTRACTING_WORKFLOWS_SPEC.md
class PartnerPayoutsPage extends StatefulWidget {
  const PartnerPayoutsPage({super.key});

  @override
  State<PartnerPayoutsPage> createState() => _PartnerPayoutsPageState();
}

class _PartnerPayoutsPageState extends State<PartnerPayoutsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PartnerService>().loadPayouts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: const Text('Payouts'),
        backgroundColor: ScholesaColors.billingGradient.colors.first,
        foregroundColor: Colors.white,
      ),
      body: Consumer<PartnerService>(
        builder: (BuildContext context, PartnerService service, _) {
          if (service.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (service.payouts.isEmpty) {
            return _buildEmptyState();
          }

          return Column(
            children: <Widget>[
              _buildSummaryCard(service.payouts),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => service.loadPayouts(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: service.payouts.length,
                    itemBuilder: (BuildContext context, int index) {
                      return _buildPayoutCard(service.payouts[index]);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(List<Payout> payouts) {
    final double totalPaid = payouts
        .where((Payout p) => p.status == PayoutStatus.paid)
        .fold(0, (double sum, Payout p) => sum + p.amount);
    final double totalPending = payouts
        .where((Payout p) => p.status == PayoutStatus.pending || p.status == PayoutStatus.approved)
        .fold(0, (double sum, Payout p) => sum + p.amount);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: ScholesaColors.billingGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: ScholesaColors.billingGradient.colors.first.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Total Paid',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${totalPaid.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Pending',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${totalPending.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
              color: ScholesaColors.billingGradient.colors.first.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.account_balance_rounded,
              size: 64,
              color: ScholesaColors.billingGradient.colors.first,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Payouts Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ScholesaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your payout history will appear here',
            style: TextStyle(
              fontSize: 14,
              color: ScholesaColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutCard(Payout payout) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _getStatusColor(payout.status).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getStatusIcon(payout.status),
                color: _getStatusColor(payout.status),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '\$${payout.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ScholesaColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    payout.contractId != null
                        ? 'Contract: ${payout.contractId}'
                        : 'General payout',
                    style: TextStyle(
                      fontSize: 13,
                      color: ScholesaColors.textSecondary,
                    ),
                  ),
                  if (payout.paidAt != null || payout.requestedAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        payout.paidAt != null
                            ? 'Paid ${_formatDate(payout.paidAt!)}'
                            : 'Requested ${_formatDate(payout.requestedAt!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: ScholesaColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _buildStatusChip(payout.status),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(PayoutStatus status) {
    final Color color = _getStatusColor(status);
    String label;
    switch (status) {
      case PayoutStatus.pending:
        label = 'Pending';
      case PayoutStatus.approved:
        label = 'Approved';
      case PayoutStatus.paid:
        label = 'Paid';
      case PayoutStatus.failed:
        label = 'Failed';
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

  Color _getStatusColor(PayoutStatus status) {
    switch (status) {
      case PayoutStatus.pending:
        return Colors.orange;
      case PayoutStatus.approved:
        return Colors.blue;
      case PayoutStatus.paid:
        return Colors.green;
      case PayoutStatus.failed:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(PayoutStatus status) {
    switch (status) {
      case PayoutStatus.pending:
        return Icons.hourglass_empty_rounded;
      case PayoutStatus.approved:
        return Icons.thumb_up_rounded;
      case PayoutStatus.paid:
        return Icons.check_circle_rounded;
      case PayoutStatus.failed:
        return Icons.error_rounded;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
