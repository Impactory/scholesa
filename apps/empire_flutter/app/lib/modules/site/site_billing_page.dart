import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:provider/provider.dart';
import '../../auth/app_state.dart';
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
  String _planName = 'Standard';
  String _planStatus = 'Active';
  String _monthlyAmount = '\$0/month';
  String _nextBillingDate = '-';
  double _activeLearnersUsed = 0;
  double _activeLearnersTotal = 100;
  double _educatorsUsed = 0;
  double _educatorsTotal = 15;
  double _storageUsedGb = 0;
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
                    style: const TextStyle(color: ScholesaColors.textSecondary),
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
                      if (index <
                          ((_invoices.length > 3 ? 3 : _invoices.length) - 1))
                        const Divider(height: 1),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildInvoiceRow(
      BuildContext context, String id, String date, String amount, bool paid) {
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
          _t(context,
              'Review current usage, upgrade limits, or contact HQ billing support.'),
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
            onPressed: () async {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'module': 'site_billing',
                  'cta_id': 'submit_manage_plan_request',
                  'surface': 'manage_plan_dialog',
                },
              );
              Navigator.pop(dialogContext);
              await _requestPlanChange();
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
    final AppState? appState = _maybeAppState();
    if (appState == null) {
      return;
    }

    final String siteId = (appState.activeSiteId ??
            (appState.siteIds.isNotEmpty ? appState.siteIds.first : ''))
        .trim();
    if (siteId.isEmpty) return;

    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('getSiteBillingSnapshot');
      final HttpsCallableResult<dynamic> result =
          await callable.call(<String, dynamic>{'siteId': siteId});
      final Map<String, dynamic> payload = _asMap(result.data);
      final DateTime? nextBilling = _toDateTime(payload['nextBillingDate']);

      final List<_InvoiceItem> invoices = _asMapList(payload['invoices'])
          .map((Map<String, dynamic> row) {
            final String id = ((row['id'] as String?) ?? '').trim();
            if (id.isEmpty) {
              return null;
            }
            final String currency =
                ((row['currency'] as String?) ?? 'USD').toUpperCase();
            final String amount =
                ((_asDouble(row['amount']) ?? 0)).toStringAsFixed(2);
            final String status =
                ((row['status'] as String?) ?? '').toLowerCase();
            final bool paid = status == 'approved' ||
                status == 'paid' ||
                status == 'completed';
            final DateTime date = _toDateTime(row['date']) ?? DateTime.now();
            return _InvoiceItem(
              id: id,
              dateLabel: _formatDate(date),
              amountLabel: '${_currencySymbol(currency)}$amount',
              paid: paid,
            );
          })
          .whereType<_InvoiceItem>()
          .toList();

      if (!mounted) return;
      setState(() {
        _planName = (payload['planName'] as String?)?.trim().isNotEmpty == true
            ? (payload['planName'] as String).trim()
            : _planName;
        _planStatus =
            (payload['planStatus'] as String?)?.trim().isNotEmpty == true
                ? (payload['planStatus'] as String).trim()
                : _planStatus;
        final double monthlyAmount = _asDouble(payload['monthlyAmount']) ?? 0;
        final String currency =
            ((payload['currency'] as String?) ?? 'USD').toUpperCase();
        _monthlyAmount =
            '${_currencySymbol(currency)}${monthlyAmount.toStringAsFixed(0)}/month';
        _nextBillingDate =
            nextBilling != null ? _formatDate(nextBilling) : _nextBillingDate;
        _activeLearnersUsed =
            (_asDouble(payload['activeLearnersUsed']) ?? _activeLearnersUsed);
        _activeLearnersTotal =
            (_asDouble(payload['activeLearnersTotal']) ?? _activeLearnersTotal);
        _educatorsUsed =
            (_asDouble(payload['educatorsUsed']) ?? _educatorsUsed);
        _educatorsTotal =
            (_asDouble(payload['educatorsTotal']) ?? _educatorsTotal);
        _storageUsedGb =
            (_asDouble(payload['storageUsedGb']) ?? _storageUsedGb);
        _storageTotalGb =
            (_asDouble(payload['storageTotalGb']) ?? _storageTotalGb);
        _invoices = invoices;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _requestPlanChange() async {
    final AppState? appState = _maybeAppState();
    final String siteId = (appState?.activeSiteId ??
            ((appState?.siteIds.isNotEmpty ?? false)
                ? appState!.siteIds.first
                : ''))
        .trim();

    try {
      final HttpsCallable callable = FirebaseFunctions.instance
          .httpsCallable('requestSiteBillingPlanChange');
      await callable.call(<String, dynamic>{
        if (siteId.isNotEmpty) 'siteId': siteId,
        'reason': 'Requested from site billing UI',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t(context, 'Plan management request submitted')),
          backgroundColor: ScholesaColors.hq,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t(context, 'Plan management request submitted')),
          backgroundColor: ScholesaColors.warning,
        ),
      );
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((dynamic key, dynamic nestedValue) =>
          MapEntry<String, dynamic>(key.toString(), nestedValue));
    }
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value.map<Map<String, dynamic>>(_asMap).toList();
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

  double? _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String _formatDate(DateTime value) {
    const List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
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
