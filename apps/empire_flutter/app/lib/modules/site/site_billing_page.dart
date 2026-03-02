import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../auth/app_state.dart';
import '../../services/firestore_service.dart';
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
  'Loading...': 'Cargando...',
  'No invoices yet': 'Aún no hay facturas',
};

/// Site billing page
/// Based on docs/13_PAYMENTS_BILLING_SPEC.md
class SiteBillingPage extends StatefulWidget {
  const SiteBillingPage({super.key});

  @override
  State<SiteBillingPage> createState() => _SiteBillingPageState();
}

class _SiteBillingPageState extends State<SiteBillingPage> {
  bool _isLoading = false;
  String _planName = 'Pro Plan';
  String _planStatus = 'Active';
  String _monthlyAmount = '\$299/month';
  String _nextBillingDate = 'Feb 1, 2026';
  double _activeLearnersUsed = 45;
  double _activeLearnersTotal = 100;
  double _educatorsUsed = 8;
  double _educatorsTotal = 15;
  double _storageUsedGb = 2.5;
  double _storageTotalGb = 10;
  List<_InvoiceItem> _invoices = <_InvoiceItem>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBillingData();
    });
  }

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
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _t(context, 'Loading...'),
                  style: const TextStyle(color: ScholesaColors.textSecondary),
                ),
              ),
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
                _t(context, _planName),
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
                  _t(context, _planStatus),
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
            _monthlyAmount,
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
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _nextBillingDate,
                    style: const TextStyle(
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
                _buildUsageRow(_t(context, 'Active Learners'),
                    _activeLearnersUsed, _activeLearnersTotal),
                const SizedBox(height: 16),
                _buildUsageRow(
                    _t(context, 'Educators'), _educatorsUsed, _educatorsTotal),
                const SizedBox(height: 16),
                _buildUsageRow(_t(context, 'Storage Used'), _storageUsedGb,
                    _storageTotalGb,
                    unit: 'GB'),
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
          child: _invoices.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _t(context, 'No invoices yet'),
                    style:
                        const TextStyle(color: ScholesaColors.textSecondary),
                  ),
                )
              : Column(
                  children: <Widget>[
                    for (int index = 0;
                        index < (_invoices.length > 3 ? 3 : _invoices.length);
                        index++) ...<Widget>[
                      _buildInvoiceRow(
                        context,
                        _invoices[index].id,
                        _invoices[index].dateLabel,
                        _invoices[index].amountLabel,
                        _invoices[index].paid,
                      ),
                      if (index < ((_invoices.length > 3 ? 3 : _invoices.length) - 1))
                        const Divider(height: 1),
                    ],
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
            if (_invoices.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _t(context, 'No invoices yet'),
                  style: const TextStyle(color: ScholesaColors.textSecondary),
                ),
              ),
            ..._invoices.map(
              (_InvoiceItem invoice) => _buildInvoiceRow(
                context,
                invoice.id,
                invoice.dateLabel,
                invoice.amountLabel,
                invoice.paid,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadBillingData() async {
    final FirestoreService? firestoreService = _maybeFirestoreService();
    final AppState? appState = _maybeAppState();
    if (firestoreService == null || appState == null) {
      return;
    }

    final String siteId = (appState.activeSiteId ??
            (appState.siteIds.isNotEmpty ? appState.siteIds.first : ''))
        .trim();
    if (siteId.isEmpty) return;

    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final DocumentSnapshot<Map<String, dynamic>> siteDoc =
          await firestoreService.firestore.collection('sites').doc(siteId).get();
      if (siteDoc.exists) {
        final Map<String, dynamic>? data = siteDoc.data();
        final String plan = (data?['billingPlan'] as String?)?.trim() ?? 'Pro Plan';
        final String status = (data?['billingStatus'] as String?)?.trim() ?? 'Active';
        final num? monthlyFee = data?['monthlyFee'] as num?;
        final String currency = ((data?['currency'] as String?) ?? 'USD').toUpperCase();
        final DateTime? nextBilling = _toDateTime(data?['nextBillingDate']);
        final int learnerCount = _asInt(data?['learnerCount']) ??
            ((data?['learnerIds'] as List?)?.length ?? 0);
        final int educatorCount = _asInt(data?['educatorCount']) ??
            ((data?['educatorIds'] as List?)?.length ?? 0);
        final int learnerCap = _asInt(data?['learnerCap']) ??
            _asInt(data?['billingLearnerLimit']) ??
            100;
        final int educatorCap = _asInt(data?['educatorCap']) ??
            _asInt(data?['billingEducatorLimit']) ??
            15;
        final double storageUsed = _asDouble(data?['storageUsedGb']) ??
            _asDouble(data?['storageUsed']) ??
            0;
        final double storageCap = _asDouble(data?['storageCapGb']) ??
            _asDouble(data?['storageLimitGb']) ??
            10;

        _planName = plan;
        _planStatus = status;
        _monthlyAmount = monthlyFee != null
            ? '${_currencySymbol(currency)}${monthlyFee.toStringAsFixed(0)}/month'
            : '\$299/month';
        _nextBillingDate = nextBilling != null
            ? _formatDate(nextBilling)
            : _nextBillingDate;
        _activeLearnersUsed = learnerCount.toDouble();
        _activeLearnersTotal = learnerCap.toDouble();
        _educatorsUsed = educatorCount.toDouble();
        _educatorsTotal = educatorCap.toDouble();
        _storageUsedGb = storageUsed;
        _storageTotalGb = storageCap;
      }

      Query<Map<String, dynamic>> invoicesQuery =
          firestoreService.firestore.collection('payouts');
      try {
        invoicesQuery = invoicesQuery.where('siteId', isEqualTo: siteId);
      } catch (_) {}
      QuerySnapshot<Map<String, dynamic>> invoicesSnapshot;
      try {
        invoicesSnapshot = await invoicesQuery
            .orderBy('createdAt', descending: true)
            .limit(50)
            .get();
      } catch (_) {
        invoicesSnapshot = await invoicesQuery.limit(50).get();
      }

      final List<_InvoiceItem> invoices = invoicesSnapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        final String status = ((data['status'] as String?) ?? '').toLowerCase();
        final bool paid = status == 'approved' || status == 'paid' || status == 'completed';
        final String amountRaw = (data['amount'] as String?) ??
            ((data['amount'] as num?)?.toString() ?? '0');
        final String currency = ((data['currency'] as String?) ?? 'USD').toUpperCase();
        final DateTime date = _toDateTime(data['approvedAt']) ??
            _toDateTime(data['createdAt']) ??
            DateTime.now();

        return _InvoiceItem(
          id: doc.id,
          dateLabel: _formatDate(date),
          amountLabel: '${_currencySymbol(currency)}$amountRaw',
          paid: paid,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _invoices = invoices;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  FirestoreService? _maybeFirestoreService() {
    try {
      return context.read<FirestoreService>();
    } catch (_) {
      return null;
    }
  }

  AppState? _maybeAppState() {
    try {
      return context.read<AppState>();
    } catch (_) {
      return null;
    }
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  double? _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String _formatDate(DateTime value) {
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[value.month - 1]} ${value.day}, ${value.year}';
  }

  String _currencySymbol(String currency) {
    switch (currency) {
      case 'SGD':
      case 'USD':
      default:
        return '\$';
    }
  }
}

class _InvoiceItem {
  const _InvoiceItem({
    required this.id,
    required this.dateLabel,
    required this.amountLabel,
    required this.paid,
  });

  final String id;
  final String dateLabel;
  final String amountLabel;
  final bool paid;
}
