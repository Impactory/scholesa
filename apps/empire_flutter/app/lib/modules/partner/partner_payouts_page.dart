import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/shared_role_surface_i18n.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';
import 'partner_models.dart';
import 'partner_service.dart';

String _tPartnerPayouts(BuildContext context, String input) {
  return SharedRoleSurfaceI18n.text(context, input);
}

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
        title: Text(_tPartnerPayouts(context, 'Payouts')),
        backgroundColor: ScholesaColors.billingGradient.colors.first,
        foregroundColor: Colors.white,
      ),
      body: Consumer<PartnerService>(
        builder: (BuildContext context, PartnerService service, _) {
          if (service.isLoading && service.payouts.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (service.error != null && service.payouts.isEmpty) {
            return _buildLoadErrorState(service);
          }

          if (service.payouts.isEmpty) {
            return _buildEmptyState();
          }

          return Column(
            children: <Widget>[
              if (service.error != null)
                _buildStaleDataBanner(
                  _tPartnerPayouts(context, 'Unable to refresh payouts right now. Showing the last successful data.'),
                ),
              _buildSummaryCard(service.payouts),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: const <String, dynamic>{
                        'module': 'partner_payouts',
                        'cta_id': 'refresh_payouts',
                        'surface': 'payouts_list',
                      },
                    );
                    await service.loadPayouts();
                  },
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

  Widget _buildLoadErrorState(PartnerService service) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.red.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              _tPartnerPayouts(context, 'Payouts are temporarily unavailable'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ScholesaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              service.error ??
                  _tPartnerPayouts(context, 'We could not load your payout history.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: ScholesaColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: service.loadPayouts,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(_tPartnerPayouts(context, 'Retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaleDataBanner(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: ScholesaColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(List<Payout> payouts) {
    final double totalPaid = payouts
        .where((Payout p) => p.status == PayoutStatus.paid)
        .fold(0, (double sum, Payout p) => sum + p.amount);
    final double totalPending = payouts
        .where((Payout p) =>
            p.status == PayoutStatus.pending ||
            p.status == PayoutStatus.approved)
        .fold(0, (double sum, Payout p) => sum + p.amount);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: ScholesaColors.billingGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: ScholesaColors.billingGradient.colors.first
                .withValues(alpha: 0.3),
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
                  _tPartnerPayouts(context, 'Total Paid'),
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
                    _tPartnerPayouts(context, 'Pending'),
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
              color: ScholesaColors.billingGradient.colors.first
                  .withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.account_balance_rounded,
              size: 64,
              color: ScholesaColors.billingGradient.colors.first,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _tPartnerPayouts(context, 'No Payouts Yet'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ScholesaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _tPartnerPayouts(context, 'Your payout history will appear here'),
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
                        ? '${_tPartnerPayouts(context, 'Contract:')} ${payout.contractId}'
                        : _tPartnerPayouts(context, 'General payout'),
                    style: const TextStyle(
                      fontSize: 13,
                      color: ScholesaColors.textSecondary,
                    ),
                  ),
                  if (payout.paidAt != null || payout.requestedAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        payout.paidAt != null
                            ? '${_tPartnerPayouts(context, 'Paid')} ${_formatDate(payout.paidAt!)}'
                            : '${_tPartnerPayouts(context, 'Requested')} ${_formatDate(payout.requestedAt!)}',
                        style: const TextStyle(
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
        label = _tPartnerPayouts(context, 'Pending');
      case PayoutStatus.approved:
        label = _tPartnerPayouts(context, 'Approved');
      case PayoutStatus.paid:
        label = _tPartnerPayouts(context, 'Paid');
      case PayoutStatus.failed:
        label = _tPartnerPayouts(context, 'Failed');
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
