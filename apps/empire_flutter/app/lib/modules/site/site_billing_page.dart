import 'package:flutter/material.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';

const Map<String, String> _siteBillingEs = <String, String>{
  'Site Billing': 'Facturación del sitio',
  'Pro Plan': 'Plan Pro',
  'Active': 'Activo',
  'Next billing date': 'Próxima fecha de cobro',
  'Manage Plan': 'Gestionar plan',
  'Current Usage': 'Uso actual',
  'Active Learners': 'Estudiantes activos',
  'Educators': 'Educadores',
  'Storage Used': 'Almacenamiento usado',
  'Recent Invoices': 'Facturas recientes',
  'View All': 'Ver todo',
  'Paid': 'Pagada',
  'Pending': 'Pendiente',
  'Manage Site Plan': 'Gestionar plan del sitio',
  'Review current usage, upgrade limits, or contact HQ billing support.':
      'Revisa el uso actual, amplía límites o contacta al equipo de facturación HQ.',
  'Close': 'Cerrar',
  'Plan management request submitted': 'Solicitud de gestión de plan enviada',
  'Request Change': 'Solicitar cambio',
  'All Invoices': 'Todas las facturas',
};

/// Site billing page
/// Based on docs/13_PAYMENTS_BILLING_SPEC.md
class SiteBillingPage extends StatelessWidget {
  const SiteBillingPage({super.key});

  String _t(BuildContext context, String input) {
    final String locale = Localizations.localeOf(context).languageCode;
    if (locale != 'es') return input;
    return _siteBillingEs[input] ?? input;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: Text(_t(context, 'Site Billing')),
        backgroundColor: ScholesaColors.billingGradient.colors.first,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildSubscriptionCard(context),
            const SizedBox(height: 24),
            _buildUsageSection(context),
            const SizedBox(height: 24),
            _buildRecentInvoices(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard(BuildContext context) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                _t(context, 'Pro Plan'),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _t(context, 'Active'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '\$299/month',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white30),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _t(context, 'Next billing date'),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const Text(
                    'Feb 1, 2026',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              OutlinedButton(
                onPressed: () {
                  TelemetryService.instance.logEvent(
                    event: 'cta.clicked',
                    metadata: <String, dynamic>{
                      'module': 'site_billing',
                      'cta_id': 'open_manage_plan_dialog',
                      'surface': 'subscription_card',
                    },
                  );
                  _showManagePlanDialog(context);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                ),
                child: Text(_t(context, 'Manage Plan')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsageSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _t(context, 'Current Usage'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: ScholesaColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: ScholesaColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: <Widget>[
                _buildUsageRow(_t(context, 'Active Learners'), 45, 100),
                const SizedBox(height: 16),
                _buildUsageRow(_t(context, 'Educators'), 8, 15),
                const SizedBox(height: 16),
                _buildUsageRow(_t(context, 'Storage Used'), 2.5, 10, unit: 'GB'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUsageRow(String label, double used, double total,
      {String unit = ''}) {
    final double percentage = used / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${used.toStringAsFixed(unit.isNotEmpty ? 1 : 0)}$unit / ${total.toStringAsFixed(0)}$unit',
              style: const TextStyle(
                fontSize: 13,
                color: ScholesaColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.grey.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              percentage > 0.9
                  ? Colors.red
                  : percentage > 0.7
                      ? Colors.orange
                      : Colors.green,
            ),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentInvoices(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              _t(context, 'Recent Invoices'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ScholesaColors.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: <String, dynamic>{
                    'module': 'site_billing',
                    'cta_id': 'open_all_invoices',
                    'surface': 'recent_invoices_header',
                  },
                );
                _showAllInvoices(context);
              },
              child: Text(_t(context, 'View All')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          color: ScholesaColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: <Widget>[
              _buildInvoiceRow(context, 'INV-2026-001', 'Jan 1, 2026', '\$299.00', true),
              const Divider(height: 1),
              _buildInvoiceRow(context, 'INV-2025-012', 'Dec 1, 2025', '\$299.00', true),
              const Divider(height: 1),
              _buildInvoiceRow(context, 'INV-2025-011', 'Nov 1, 2025', '\$299.00', true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceRow(BuildContext context, String id, String date, String amount, bool paid) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (paid ? Colors.green : Colors.orange).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          paid ? Icons.check_circle_rounded : Icons.hourglass_empty_rounded,
          color: paid ? Colors.green : Colors.orange,
          size: 20,
        ),
      ),
      title: Text(id),
      subtitle: Text(date),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(
            amount,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            paid ? _t(context, 'Paid') : _t(context, 'Pending'),
            style: TextStyle(
              fontSize: 12,
              color: paid ? Colors.green : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  void _showManagePlanDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(_t(context, 'Manage Site Plan')),
        content: Text(
          _t(context, 'Review current usage, upgrade limits, or contact HQ billing support.'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'module': 'site_billing',
                  'cta_id': 'close_manage_plan_dialog',
                  'surface': 'manage_plan_dialog',
                },
              );
              Navigator.pop(dialogContext);
            },
            child: Text(_t(context, 'Close')),
          ),
          ElevatedButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'module': 'site_billing',
                  'cta_id': 'submit_manage_plan_request',
                  'surface': 'manage_plan_dialog',
                },
              );
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_t(context, 'Plan management request submitted')),
                  backgroundColor: ScholesaColors.hq,
                ),
              );
            },
            child: Text(_t(context, 'Request Change')),
          ),
        ],
      ),
    );
  }

  void _showAllInvoices(BuildContext context) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'site_billing',
        'cta_id': 'view_all_invoices_sheet',
        'surface': 'invoices',
      },
    );
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          shrinkWrap: true,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                _t(context, 'All Invoices'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            _buildInvoiceRow(context, 'INV-2026-001', 'Jan 1, 2026', '\$299.00', true),
            _buildInvoiceRow(context, 'INV-2025-012', 'Dec 1, 2025', '\$299.00', true),
            _buildInvoiceRow(context, 'INV-2025-011', 'Nov 1, 2025', '\$299.00', true),
          ],
        ),
      ),
    );
  }
}
