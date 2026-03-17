import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:provider/provider.dart';
import '../../i18n/workflow_surface_i18n.dart';
import '../../auth/app_state.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';

String _tHqBilling(BuildContext context, String input) {
  return WorkflowSurfaceI18n.text(context, input);
}

/// HQ Billing Page - Platform-wide billing and revenue management
class HqBillingPage extends StatefulWidget {
  const HqBillingPage({super.key, this.billingLoader});

  final Future<Map<String, dynamic>> Function()? billingLoader;

  @override
  State<HqBillingPage> createState() => _HqBillingPageState();
}

class _HqBillingPageState extends State<HqBillingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedSite = 'all';
  String _selectedPeriod = 'month';
  bool _isLoading = false;
  List<_SiteFilterOption> _siteOptions = <_SiteFilterOption>[
    const _SiteFilterOption(id: 'all', label: 'All Sites'),
  ];
  List<Map<String, dynamic>> _invoices = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _payments = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _subscriptions = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBillingData();
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              ScholesaColors.hq.withValues(alpha: 0.05),
              context.schSurface,
              ScholesaColors.success.withValues(alpha: 0.03),
            ],
          ),
        ),
        child: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildFilters()),
              SliverToBoxAdapter(child: _buildRevenueOverview()),
              SliverToBoxAdapter(child: _buildTabBar()),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: <Widget>[
              _buildInvoicesList(),
              _buildPaymentsList(),
              _buildSubscriptionsList(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createInvoice,
        backgroundColor: ScholesaColors.hq,
        icon: const Icon(Icons.add),
        label: Text(_tHqBilling(context, 'New Invoice')),
      ),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: ScholesaColors.hqGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: ScholesaColors.hq.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.account_balance_wallet,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _tHqBilling(context, 'Billing Management'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: ScholesaColors.hq,
                        ),
                  ),
                  Text(
                    _tHqBilling(context, 'Invoices, payments & subscriptions'),
                    style: TextStyle(
                        color: context.schTextSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _exportFinancials,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ScholesaColors.hq.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.download, color: ScholesaColors.hq),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.schBorder),
              ),
              child: DropdownButton<String>(
                value: _selectedSite,
                isExpanded: true,
                underline: const SizedBox(),
                items: _siteOptions
                    .map(
                      (_SiteFilterOption option) => DropdownMenuItem<String>(
                        value: option.id,
                        child: Text(_tHqBilling(context, option.label)),
                      ),
                    )
                    .toList(),
                onChanged: (String? value) {
                  if (value != null) {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: <String, dynamic>{
                        'module': 'hq_billing',
                        'cta_id': 'set_site_filter',
                        'surface': 'filters',
                        'site': value,
                      },
                    );
                    setState(() => _selectedSite = value);
                    _loadBillingData();
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.schBorder),
              ),
              child: DropdownButton<String>(
                value: _selectedPeriod,
                isExpanded: true,
                underline: const SizedBox(),
                items: <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                      value: 'month',
                      child: Text(_tHqBilling(context, 'This Month'))),
                  DropdownMenuItem<String>(
                      value: 'quarter',
                      child: Text(_tHqBilling(context, 'This Quarter'))),
                  DropdownMenuItem<String>(
                      value: 'year',
                      child: Text(_tHqBilling(context, 'This Year'))),
                ],
                onChanged: (String? value) {
                  if (value != null) {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: <String, dynamic>{
                        'module': 'hq_billing',
                        'cta_id': 'set_period_filter',
                        'surface': 'filters',
                        'period': value,
                      },
                    );
                    setState(() => _selectedPeriod = value);
                    _loadBillingData();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueOverview() {
    final double totalRevenue =
        _invoices.fold<double>(0, (double sum, Map<String, dynamic> invoice) {
      return sum + ((invoice['amount'] as double?) ?? 0);
    });
    final double collected = _invoices.where((Map<String, dynamic> invoice) {
      final String status = (invoice['status'] as String? ?? '').toLowerCase();
      return status == 'paid' || status == 'approved' || status == 'completed';
    }).fold<double>(0, (double sum, Map<String, dynamic> invoice) {
      return sum + ((invoice['amount'] as double?) ?? 0);
    });
    final double pending = _invoices.where((Map<String, dynamic> invoice) {
      return (invoice['status'] as String? ?? '').toLowerCase() == 'pending';
    }).fold<double>(0, (double sum, Map<String, dynamic> invoice) {
      return sum + ((invoice['amount'] as double?) ?? 0);
    });
    final double overdue = _invoices.where((Map<String, dynamic> invoice) {
      return (invoice['status'] as String? ?? '').toLowerCase() == 'overdue';
    }).fold<double>(0, (double sum, Map<String, dynamic> invoice) {
      return sum + ((invoice['amount'] as double?) ?? 0);
    });

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              ScholesaColors.hq,
              ScholesaColors.hq.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: ScholesaColors.hq.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _tHqBilling(context, 'Total Revenue'),
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatCurrency(totalRevenue),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.trending_up,
                              size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            '${_invoices.length} ${_tHqBilling(context, 'invoices in period')}',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.attach_money,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                Expanded(
                  child: _RevenueStatCard(
                    label: _tHqBilling(context, 'Collected'),
                    value: _formatCurrency(collected),
                    icon: Icons.check_circle,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _RevenueStatCard(
                    label: _tHqBilling(context, 'Pending'),
                    value: _formatCurrency(pending),
                    icon: Icons.pending,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _RevenueStatCard(
                    label: _tHqBilling(context, 'Overdue'),
                    value: _formatCurrency(overdue),
                    icon: Icons.warning,
                    isAlert: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.schSurfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: context.schTextSecondary,
        indicator: BoxDecoration(
          color: ScholesaColors.hq,
          borderRadius: BorderRadius.circular(12),
        ),
        tabs: <Widget>[
          Tab(text: _tHqBilling(context, 'Invoices')),
          Tab(text: _tHqBilling(context, 'Payments')),
          Tab(text: _tHqBilling(context, 'Subscriptions')),
        ],
      ),
    );
  }

  Widget _buildInvoicesList() {
    if (_isLoading) {
      return Center(
        child: Text(
          _tHqBilling(context, 'Loading...'),
          style: const TextStyle(color: ScholesaColors.textSecondary),
        ),
      );
    }
    if (_invoices.isEmpty) {
      return Center(
        child: Text(
          _tHqBilling(context, 'No records found'),
          style: const TextStyle(color: ScholesaColors.textSecondary),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _invoices.length,
      itemBuilder: (BuildContext context, int index) {
        final Map<String, dynamic> invoice = _invoices[index];
        return _InvoiceCard(invoice: invoice);
      },
    );
  }

  Widget _buildPaymentsList() {
    if (_isLoading) {
      return Center(
        child: Text(
          _tHqBilling(context, 'Loading...'),
          style: const TextStyle(color: ScholesaColors.textSecondary),
        ),
      );
    }
    if (_payments.isEmpty) {
      return Center(
        child: Text(
          _tHqBilling(context, 'No records found'),
          style: const TextStyle(color: ScholesaColors.textSecondary),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _payments.length,
      itemBuilder: (BuildContext context, int index) {
        final Map<String, dynamic> payment = _payments[index];
        return _PaymentCard(payment: payment);
      },
    );
  }

  Widget _buildSubscriptionsList() {
    if (_isLoading) {
      return Center(
        child: Text(
          _tHqBilling(context, 'Loading...'),
          style: const TextStyle(color: ScholesaColors.textSecondary),
        ),
      );
    }
    if (_subscriptions.isEmpty) {
      return Center(
        child: Text(
          _tHqBilling(context, 'No records found'),
          style: const TextStyle(color: ScholesaColors.textSecondary),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _subscriptions.length,
      itemBuilder: (BuildContext context, int index) {
        final Map<String, dynamic> subscription = _subscriptions[index];
        return _SubscriptionCard(subscription: subscription);
      },
    );
  }

  Future<void> _createInvoice() async {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'hq_billing',
        'cta_id': 'open_create_invoice_sheet',
        'surface': 'floating_action_button',
      },
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => _CreateInvoiceSheet(
        selectedSiteId: _selectedSite == 'all' ? null : _selectedSite,
      ),
    );
    await _loadBillingData();
  }

  void _exportFinancials() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'hq_billing',
        'cta_id': 'open_export_financials_dialog',
        'surface': 'header',
      },
    );
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(_tHqBilling(context, 'Export Financials')),
        content: Text(
          '${_tHqBilling(context, 'Generate a consolidated financial report for invoices, payments, and subscriptions.')}\n\n${_tHqBilling(context, 'Financial exports are not available in the app yet.')}',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'module': 'hq_billing',
                  'cta_id': 'close_export_financials_notice',
                  'surface': 'export_financials_dialog',
                },
              );
              Navigator.pop(dialogContext);
            },
            child: Text(_tHqBilling(context, 'Close')),
          ),
        ],
      ),
    );
  }

  Future<void> _loadBillingData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final Map<String, dynamic> payload = await _loadBillingPayload();
      final List<_SiteFilterOption> callableSiteOptions = <_SiteFilterOption>[
        ..._asMapList(payload['siteOptions']).map(
          (Map<String, dynamic> row) => _SiteFilterOption(
            id: ((row['id'] as String?) ?? '').trim().isNotEmpty
                ? (row['id'] as String).trim()
                : 'all',
            label: ((row['label'] as String?) ?? '').trim().isNotEmpty
                ? (row['label'] as String).trim()
                : 'All Sites',
          ),
        ),
      ];

      final DateTime now = DateTime.now();
      final List<Map<String, dynamic>> callableInvoices = _asMapList(
        payload['invoices'],
      )
          .map((Map<String, dynamic> row) {
            final String id = ((row['id'] as String?) ?? '').trim();
            if (id.isEmpty) {
              return null;
            }
            final DateTime date = _toDateTime(row['date']) ?? now;
            return <String, dynamic>{
              'id': id,
              'parent': ((row['parent'] as String?)?.trim().isNotEmpty == true)
                ? (row['parent'] as String).trim()
                : _tHqBilling(context, 'Parent unavailable'),
              'learner': ((row['learner'] as String?)?.trim().isNotEmpty == true)
                ? (row['learner'] as String).trim()
                : _tHqBilling(context, 'Learner unavailable'),
              'site': ((row['site'] as String?)?.trim().isNotEmpty == true)
                ? (row['site'] as String).trim()
                : _tHqBilling(context, 'Site unavailable'),
              'amount': _asDouble(row['amount']) ?? 0,
              'status': _invoiceStatusFromPayoutStatus(
                (row['status'] as String?) ?? 'pending',
              ),
              'date': _formatDate(date),
            };
          })
          .whereType<Map<String, dynamic>>()
          .toList();

      final List<Map<String, dynamic>> callablePayments = _asMapList(
        payload['payments'],
      )
          .map((Map<String, dynamic> row) {
            final String id = ((row['id'] as String?) ?? '').trim();
            if (id.isEmpty) {
              return null;
            }
            final DateTime date = _toDateTime(row['date']) ?? now;
            return <String, dynamic>{
              'id': id,
              'from': ((row['from'] as String?)?.trim().isNotEmpty == true)
                  ? (row['from'] as String).trim()
                  : _tHqBilling(context, 'Payment source unavailable'),
              'method': (row['method'] as String?) ?? 'Transfer',
              'amount': _asDouble(row['amount']) ?? 0,
              'date': _formatDate(date),
              'invoice': (row['invoice'] as String?) ?? '-',
            };
          })
          .whereType<Map<String, dynamic>>()
          .toList();

      final List<Map<String, dynamic>> callableSubscriptions =
          _asMapList(payload['subscriptions']).map((Map<String, dynamic> row) {
        final DateTime? nextBilling = _toDateTime(row['nextBilling']);
        return <String, dynamic>{
            'parent': ((row['parent'] as String?)?.trim().isNotEmpty == true)
              ? (row['parent'] as String).trim()
              : _tHqBilling(context, 'Subscription owner unavailable'),
          'learners': _asInt(row['learners']) ?? 0,
          'plan': (row['plan'] as String?) ?? 'Standard',
          'amount': _asDouble(row['amount']) ?? 0,
          'status': _normalizeSubscriptionStatus(
              (row['status'] as String?) ?? 'active'),
          'nextBilling': nextBilling != null ? _formatDate(nextBilling) : '-',
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _siteOptions = callableSiteOptions.isEmpty
            ? <_SiteFilterOption>[
                const _SiteFilterOption(id: 'all', label: 'All Sites')
              ]
            : callableSiteOptions;
        if (!_siteOptions.any((option) => option.id == _selectedSite)) {
          _selectedSite = 'all';
        }
        _invoices = callableInvoices;
        _payments = callablePayments;
        _subscriptions = callableSubscriptions;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
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

  String _formatCurrency(double value) {
    return '\$${value.toStringAsFixed(2)}';
  }

  String _invoiceStatusFromPayoutStatus(String status) {
    if (status == 'approved' || status == 'paid' || status == 'completed') {
      return 'paid';
    }
    if (status == 'overdue') return 'overdue';
    return 'pending';
  }

  String _normalizeSubscriptionStatus(String status) {
    switch (status) {
      case 'active':
      case 'paused':
      case 'cancelled':
        return status;
      default:
        return 'active';
    }
  }

  Future<Map<String, dynamic>> _loadBillingPayload() async {
    if (widget.billingLoader != null) {
      return widget.billingLoader!();
    }

    final HttpsCallable callable =
        FirebaseFunctions.instance.httpsCallable('listHqBillingRecords');
    final HttpsCallableResult<dynamic> response =
        await callable.call(<String, dynamic>{
      'siteId': _selectedSite == 'all' ? null : _selectedSite,
      'period': _selectedPeriod,
      'limit': 500,
    });

    return _asMap(response.data);
  }
}

class _SiteFilterOption {
  const _SiteFilterOption({required this.id, required this.label});

  final String id;
  final String label;
}

class _RevenueStatCard extends StatelessWidget {
  const _RevenueStatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.isAlert = false,
  });
  final String label;
  final String value;
  final IconData icon;
  final bool isAlert;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            icon,
            color: isAlert ? Colors.orange.shade200 : Colors.white70,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice});
  final Map<String, dynamic> invoice;

  Color get _statusColor {
    switch (invoice['status']) {
      case 'paid':
        return ScholesaColors.success;
      case 'pending':
        return ScholesaColors.warning;
      case 'overdue':
        return ScholesaColors.error;
      default:
        return Colors.grey;
    }
  }

  void _viewInvoice(BuildContext context) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'hq_billing',
        'cta_id': 'view_invoice',
        'surface': 'invoice_card',
        'invoice_id': invoice['id'],
      },
    );
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text('${_tHqBilling(context, 'Invoice')} ${invoice['id']}'),
        content: Text(
          '${_tHqBilling(context, 'Parent')}: ${invoice['parent']}\n'
          '${_tHqBilling(context, 'Learner')}: ${invoice['learner']}\n'
          '${_tHqBilling(context, 'Site')}: ${invoice['site']}\n'
          '${_tHqBilling(context, 'Date')}: ${invoice['date']}\n'
          '${_tHqBilling(context, 'Amount')}: \$${(invoice['amount'] as double).toStringAsFixed(2)}\n'
          '${_tHqBilling(context, 'Status')}: ${_tHqBilling(context, invoice['status'] as String).toUpperCase()}',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_tHqBilling(context, 'Close')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.schBorder),
        ),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ScholesaColors.hq.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      const Icon(Icons.receipt_long, color: ScholesaColors.hq),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        invoice['id'] as String,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${invoice['parent']} • ${invoice['learner']}',
                        style: TextStyle(
                            color: context.schTextSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      '\$${(invoice['amount'] as double).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        (invoice['status'] as String).toUpperCase(),
                        style: TextStyle(
                          color: _statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  '${invoice['site']} • ${invoice['date']}',
                  style: TextStyle(
                      color: context.schTextSecondary.withValues(alpha: 0.88),
                      fontSize: 12),
                ),
                Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: () => _viewInvoice(context),
                      icon: const Icon(Icons.visibility, size: 20),
                      color: context.schTextSecondary,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _tHqBilling(
                  context,
                  'Invoice sending is not available in the app yet.',
                ),
                style: TextStyle(
                  color: context.schTextSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payment});
  final Map<String, dynamic> payment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.schBorder),
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ScholesaColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  const Icon(Icons.check_circle, color: ScholesaColors.success),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    payment['from'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${payment['method']} • ${payment['date']}',
                    style: TextStyle(
                        color: context.schTextSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  '\$${(payment['amount'] as double).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: ScholesaColors.success,
                  ),
                ),
                Text(
                  payment['invoice'] as String,
                  style: TextStyle(
                      color: context.schTextSecondary.withValues(alpha: 0.88),
                      fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.subscription});
  final Map<String, dynamic> subscription;

  Color get _statusColor {
    switch (subscription['status']) {
      case 'active':
        return ScholesaColors.success;
      case 'paused':
        return ScholesaColors.warning;
      case 'cancelled':
        return ScholesaColors.error;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.schBorder),
        ),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ScholesaColors.hq.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.autorenew, color: ScholesaColors.hq),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        subscription['parent'] as String,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${subscription['learners']} ${_tHqBilling(context, 'learner(s)')} • ${subscription['plan']} ${_tHqBilling(context, 'Plan')}',
                        style: TextStyle(
                            color: context.schTextSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _tHqBilling(context, subscription['status'] as String)
                        .toUpperCase(),
                    style: TextStyle(
                      color: _statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${_tHqBilling(context, 'Next billing')}: ${subscription['nextBilling']}',
                      style: TextStyle(
                          color:
                              context.schTextSecondary.withValues(alpha: 0.88),
                          fontSize: 12),
                    ),
                  ],
                ),
                Text(
                  '\$${(subscription['amount'] as double).toStringAsFixed(2)}/mo',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: ScholesaColors.hq,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateInvoiceSheet extends StatefulWidget {
  const _CreateInvoiceSheet({this.selectedSiteId});

  final String? selectedSiteId;

  @override
  State<_CreateInvoiceSheet> createState() => _CreateInvoiceSheetState();
}

class _CreateInvoiceSheetState extends State<_CreateInvoiceSheet> {
  String? _selectedParent;
  String? _selectedLearner;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isLoadingUsers = false;
  List<_UserOption> _parentOptions = <_UserOption>[];
  List<_UserOption> _learnerOptions = <_UserOption>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserOptions();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: <Widget>[
                Text(
                  _tHqBilling(context, 'Create Invoice'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _tHqBilling(context, 'Parent'),
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedParent,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      hintText: _tHqBilling(context, 'Select parent'),
                    ),
                    items: _parentOptions
                        .map(
                          (_UserOption option) => DropdownMenuItem<String>(
                            value: option.id,
                            child: Text(option.label),
                          ),
                        )
                        .toList(),
                    onChanged: (String? value) {
                      setState(() => _selectedParent = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _tHqBilling(context, 'Learner'),
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedLearner,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      hintText: _tHqBilling(context, 'Select learner'),
                    ),
                    items: _learnerOptions
                        .map(
                          (_UserOption option) => DropdownMenuItem<String>(
                            value: option.id,
                            child: Text(option.label),
                          ),
                        )
                        .toList(),
                    onChanged: (String? value) {
                      setState(() => _selectedLearner = value);
                    },
                  ),
                  if (_isLoadingUsers)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        _tHqBilling(context, 'Loading...'),
                        style: TextStyle(
                            fontSize: 12, color: context.schTextSecondary),
                      ),
                    )
                  else if (_parentOptions.isEmpty && _learnerOptions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        _tHqBilling(context, 'No users found'),
                        style: TextStyle(
                            fontSize: 12, color: context.schTextSecondary),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    _tHqBilling(context, 'Amount'),
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixText: r'$ ',
                      hintText: '0.00',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _tHqBilling(context, 'Description'),
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      hintText: _tHqBilling(context, 'Invoice description...'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _createInvoice,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ScholesaColors.hq,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _tHqBilling(context, 'Create Invoice'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
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

  Future<void> _createInvoice() async {
    final AppState? appState = _maybeAppState();
    final double? amount = double.tryParse(_amountController.text.trim());
    if (_selectedParent == null ||
        _selectedLearner == null ||
        amount == null ||
        amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tHqBilling(context, 'Please complete all fields')),
          backgroundColor: ScholesaColors.warning,
        ),
      );
      return;
    }

    final _UserOption? parent = _parentOptions
        .where((_UserOption option) => option.id == _selectedParent)
        .cast<_UserOption?>()
        .firstOrNull;
    final _UserOption? learner = _learnerOptions
        .where((_UserOption option) => option.id == _selectedLearner)
        .cast<_UserOption?>()
        .firstOrNull;

    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'module': 'hq_billing',
        'cta_id': 'submit_create_invoice',
        'surface': 'create_invoice_sheet',
        'parent_id': _selectedParent,
        'learner_id': _selectedLearner,
      },
    );

    try {
      final String? selectedSiteId = widget.selectedSiteId;
      final String? activeSiteId = appState?.activeSiteId;
      final String siteId =
          (selectedSiteId != null && selectedSiteId.isNotEmpty)
              ? selectedSiteId
              : ((activeSiteId != null && activeSiteId.isNotEmpty)
                  ? activeSiteId
                  : ((appState?.siteIds.isNotEmpty ?? false)
                      ? appState!.siteIds.first
                      : ''));

      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('createHqInvoice');
      await callable.call(<String, dynamic>{
        'siteId': siteId.isNotEmpty ? siteId : null,
        'parentId': _selectedParent,
        'parentName': parent?.label ?? _selectedParent,
        'learnerId': _selectedLearner,
        'learnerName': learner?.label ?? _selectedLearner,
        'amount': amount,
        'description': _descriptionController.text.trim(),
        'currency': 'USD',
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tHqBilling(context, 'Invoice creation failed')),
          backgroundColor: ScholesaColors.error,
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_tHqBilling(context, 'Invoice created successfully')),
        backgroundColor: ScholesaColors.success,
      ),
    );
  }

  Future<void> _loadUserOptions() async {
    if (!mounted) return;
    setState(() => _isLoadingUsers = true);
    try {
      final AppState? appState = _maybeAppState();
      final String? selectedSiteId = widget.selectedSiteId;
      final String? activeSiteId = appState?.activeSiteId;
      final String siteScopeId =
          (selectedSiteId != null && selectedSiteId.isNotEmpty)
              ? selectedSiteId
              : ((activeSiteId != null && activeSiteId.isNotEmpty)
                  ? activeSiteId
                  : '');

      final HttpsCallable listUsersCallable =
          FirebaseFunctions.instance.httpsCallable('listUsers');
      final List<HttpsCallableResult<dynamic>> responses =
          await Future.wait(<Future<HttpsCallableResult<dynamic>>>[
        listUsersCallable.call(<String, dynamic>{
          'role': 'parent',
          if (siteScopeId.isNotEmpty) 'siteId': siteScopeId,
          'limit': 300,
        }),
        listUsersCallable.call(<String, dynamic>{
          'role': 'learner',
          if (siteScopeId.isNotEmpty) 'siteId': siteScopeId,
          'limit': 300,
        }),
      ]);

      final List<_UserOption> parents =
          _asMapList(_asMap(responses[0].data)['users'])
              .map((_MapValue row) => _UserOption(
                    id: row.id,
                    label: _displayNameFromUserDoc(row.data, row.id),
                  ))
              .toList();
      final List<_UserOption> learners =
          _asMapList(_asMap(responses[1].data)['users'])
              .map((_MapValue row) => _UserOption(
                    id: row.id,
                    label: _displayNameFromUserDoc(row.data, row.id),
                  ))
              .toList();

      if (!mounted) return;
      setState(() {
        _parentOptions = parents;
        _learnerOptions = learners;
        if (_selectedParent != null &&
            !_parentOptions.any((option) => option.id == _selectedParent)) {
          _selectedParent = null;
        }
        if (_selectedLearner != null &&
            !_learnerOptions.any((option) => option.id == _selectedLearner)) {
          _selectedLearner = null;
        }
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingUsers = false);
      }
    }
  }

  AppState? _maybeAppState() {
    try {
      return context.read<AppState>();
    } catch (_) {
      return null;
    }
  }

  String _displayNameFromUserDoc(Map<String, dynamic> data, String fallbackId) {
    final String displayName = ((data['displayName'] as String?) ?? '').trim();
    if (displayName.isNotEmpty) return displayName;
    final String name = ((data['name'] as String?) ?? '').trim();
    if (name.isNotEmpty) return name;
    final String email = ((data['email'] as String?) ?? '').trim();
    if (email.isNotEmpty) return email;
    return fallbackId;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((dynamic key, dynamic nestedValue) =>
          MapEntry<String, dynamic>(key.toString(), nestedValue));
    }
    return <String, dynamic>{};
  }

  List<_MapValue> _asMapList(dynamic value) {
    if (value is! List) return <_MapValue>[];
    return value
        .map((dynamic row) {
          final Map<String, dynamic> data = _asMap(row);
          final String id = ((data['id'] as String?) ?? '').trim();
          if (id.isEmpty) return null;
          return _MapValue(id: id, data: data);
        })
        .whereType<_MapValue>()
        .toList();
  }
}

class _UserOption {
  const _UserOption({required this.id, required this.label});

  final String id;
  final String label;
}

class _MapValue {
  const _MapValue({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;
}
