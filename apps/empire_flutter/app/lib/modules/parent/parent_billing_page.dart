import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';
import '../../runtime/runtime.dart';
import '../../auth/app_state.dart';
import 'parent_models.dart';
import 'parent_service.dart';

const Map<String, String> _parentBillingEs = <String, String>{
  'Billing & Payments': 'Facturación y pagos',
  'Manage your payments': 'Administra tus pagos',
  'All Learners': 'Todos los estudiantes',
  'Current Balance': 'Saldo actual',
  'All paid': 'Todo pagado',
  'This Month': 'Este mes',
  'Next Due': 'Próximo vencimiento',
  'Total Paid': 'Total pagado',
  'Invoices': 'Facturas',
  'Payments': 'Pagos',
  'Plan': 'Plan',
  'PREMIUM PLAN': 'PLAN PREMIUM',
  'Active': 'Activo',
  'For Emma Johnson • Billed monthly': 'Para Emma Johnson • Facturación mensual',
  'Plan Includes:': 'El plan incluye:',
  'Unlimited session access': 'Acceso ilimitado a sesiones',
  'All 3 pillars curriculum': 'Currículo de los 3 pilares',
  '1-on-1 educator support': 'Apoyo 1 a 1 con educador',
  'Real-time progress reports': 'Reportes de progreso en tiempo real',
  'Certificates & badges': 'Certificados e insignias',
  'Payment Method': 'Método de pago',
  'Update': 'Actualizar',
  'Manage Plan': 'Gestionar plan',
  'Downloading statements...': 'Descargando estados de cuenta...',
  'Paying invoice': 'Pagando factura',
  'Viewing invoice': 'Viendo factura',
  'Update Payment Method': 'Actualizar método de pago',
  'Select your preferred payment method update action.':
      'Selecciona la acción para actualizar tu método de pago.',
  'Cancel': 'Cancelar',
  'Continue': 'Continuar',
  'Payment method update request submitted':
      'Solicitud de actualización del método de pago enviada',
  'You can review your current subscription and request plan changes.':
      'Puedes revisar tu suscripción actual y solicitar cambios de plan.',
  'Close': 'Cerrar',
  'Request Change': 'Solicitar cambio',
  'Plan review request sent to billing team':
      'Solicitud de revisión del plan enviada al equipo de facturación',
  'PAID': 'PAGADO',
  'DUE': 'PENDIENTE',
  'View': 'Ver',
  'Pay Now': 'Pagar ahora',
  'Loading...': 'Cargando...',
  'No invoices yet': 'Aún no hay facturas',
  'No payments yet': 'Aún no hay pagos',
  'STANDARD PLAN': 'PLAN ESTÁNDAR',
  'On file': 'En archivo',
  'Billed monthly': 'Facturación mensual',
  'month': 'mes',
  'Billing AI Coach': 'Coach IA de facturación',
  'Keep BOS/MIA loop active around family billing and learner continuity':
      'Mantén activo el ciclo BOS/MIA alrededor de la facturación familiar y la continuidad del estudiante',
};

String _tParentBilling(BuildContext context, String input) {
  final String locale = Localizations.localeOf(context).languageCode;
  if (locale != 'es') return input;
  return _parentBillingEs[input] ?? input;
}

/// Parent Billing Page - View payment history and invoices
class ParentBillingPage extends StatefulWidget {
  const ParentBillingPage({super.key});

  @override
  State<ParentBillingPage> createState() => _ParentBillingPageState();
}

class _ParentBillingPageState extends State<ParentBillingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedLearner = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ParentService>().loadParentData();
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
      body: Consumer<ParentService>(
        builder: (BuildContext context, ParentService service, _) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  ScholesaColors.parent.withValues(alpha: 0.05),
                  Colors.white,
                  ScholesaColors.success.withValues(alpha: 0.03),
                ],
              ),
            ),
            child: NestedScrollView(
              headerSliverBuilder:
                  (BuildContext context, bool innerBoxIsScrolled) {
                return <Widget>[
                  SliverToBoxAdapter(child: _buildHeader(service)),
                  SliverToBoxAdapter(child: _buildLearnerFilter(service)),
                  SliverToBoxAdapter(child: _buildBalanceSummary(service)),
                  SliverToBoxAdapter(
                    child: AiContextCoachSection(
                      title: _tParentBilling(context, 'Billing AI Coach'),
                      subtitle: _tParentBilling(
                        context,
                        'Keep BOS/MIA loop active around family billing and learner continuity',
                      ),
                      module: 'parent_billing',
                      surface: 'billing_dashboard',
                      actorRole: UserRole.parent,
                      accentColor: ScholesaColors.parent,
                      conceptTags: const <String>[
                        'billing_support',
                        'family_continuity',
                        'plan_guidance',
                      ],
                    ),
                  ),
                  SliverToBoxAdapter(child: _buildTabBar()),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: <Widget>[
                  _buildInvoicesList(service),
                  _buildPaymentsList(service),
                  _buildSubscriptionInfo(service),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(ParentService service) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: ScholesaColors.parentGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: ScholesaColors.parent.withValues(alpha: 0.3),
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
                    _tParentBilling(context, 'Billing & Payments'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: ScholesaColors.parent,
                        ),
                  ),
                  Text(
                    _tParentBilling(context, 'Manage your payments'),
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _downloadStatements,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ScholesaColors.parent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.download, color: ScholesaColors.parent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLearnerFilter(ParentService service) {
    final List<LearnerSummary> learners = service.learnerSummaries;
    if (_selectedLearner != 'all' &&
        learners.every((LearnerSummary learner) => learner.learnerId != _selectedLearner)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _selectedLearner = 'all');
        }
      });
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: DropdownButton<String>(
          value: _selectedLearner,
          isExpanded: true,
          underline: const SizedBox(),
          icon: const Icon(Icons.keyboard_arrow_down),
          items: <DropdownMenuItem<String>>[
            DropdownMenuItem<String>(
              value: 'all',
              child: Text(_tParentBilling(context, 'All Learners')),
            ),
            ...learners.map(
              (LearnerSummary learner) => DropdownMenuItem<String>(
                value: learner.learnerId,
                child: Text(learner.learnerName),
              ),
            ),
          ],
          onChanged: (String? value) {
            if (value != null) {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'cta': 'parent_billing_select_learner',
                  'learner': value,
                },
              );
              setState(() => _selectedLearner = value);
            }
          },
        ),
      ),
    );
  }

  Widget _buildBalanceSummary(ParentService service) {
    final BillingSummary? billing = service.billingSummary;
    final List<PaymentHistory> payments = billing?.recentPayments ?? <PaymentHistory>[];
    final DateTime now = DateTime.now();
    final double thisMonthPaid = payments
      .where((PaymentHistory payment) =>
        payment.status.toLowerCase() == 'paid' &&
        payment.date.year == now.year &&
        payment.date.month == now.month)
      .fold(0.0, (double sum, PaymentHistory payment) => sum + payment.amount);
    final double totalPaid = payments
      .where((PaymentHistory payment) => payment.status.toLowerCase() == 'paid')
      .fold(0.0, (double sum, PaymentHistory payment) => sum + payment.amount);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              ScholesaColors.parent,
              ScholesaColors.parent.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: ScholesaColors.parent.withValues(alpha: 0.3),
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
                      _tParentBilling(context, 'Current Balance'),
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatCurrency(billing?.currentBalance ?? 0),
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
                          Icon(Icons.check_circle,
                              size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            _tParentBilling(context, 'All paid'),
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
                    Icons.receipt_long,
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
                  child: _BalanceStatCard(
                    label: _tParentBilling(context, 'This Month'),
                    value: _formatCurrency(thisMonthPaid),
                    icon: Icons.calendar_today,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _BalanceStatCard(
                    label: _tParentBilling(context, 'Next Due'),
                    value: _formatDate(billing?.nextPaymentDate),
                    icon: Icons.event,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _BalanceStatCard(
                    label: _tParentBilling(context, 'Total Paid'),
                    value: _formatCurrency(totalPaid),
                    icon: Icons.check_circle_outline,
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
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (int index) {
          final List<String> tabs = <String>['invoices', 'payments', 'plan'];
          TelemetryService.instance.logEvent(
            event: 'cta.clicked',
            metadata: <String, dynamic>{
              'cta': 'parent_billing_tab_change',
              'tab': tabs[index],
            },
          );
        },
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[600],
        indicator: BoxDecoration(
          color: ScholesaColors.parent,
          borderRadius: BorderRadius.circular(12),
        ),
        tabs: <Widget>[
          Tab(text: _tParentBilling(context, 'Invoices')),
          Tab(text: _tParentBilling(context, 'Payments')),
          Tab(text: _tParentBilling(context, 'Plan')),
        ],
      ),
    );
  }

  Widget _buildInvoicesList(ParentService service) {
    final List<Map<String, dynamic>> invoices = _buildInvoiceRows(service);

    if (invoices.isEmpty) {
      return Center(
        child: Text(
          service.isLoading
              ? _tParentBilling(context, 'Loading...')
              : _tParentBilling(context, 'No invoices yet'),
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: invoices.length,
      itemBuilder: (BuildContext context, int index) {
        final Map<String, dynamic> invoice = invoices[index];
        return _InvoiceCard(
          invoice: invoice,
          onPay: () => _payInvoice(invoice),
          onView: () => _viewInvoice(invoice),
        );
      },
    );
  }

  Widget _buildPaymentsList(ParentService service) {
    final List<Map<String, dynamic>> payments = _buildPaymentRows(service);

    if (payments.isEmpty) {
      return Center(
        child: Text(
          service.isLoading
              ? _tParentBilling(context, 'Loading...')
              : _tParentBilling(context, 'No payments yet'),
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: payments.length,
      itemBuilder: (BuildContext context, int index) {
        final Map<String, dynamic> payment = payments[index];
        return _PaymentCard(payment: payment);
      },
    );
  }

  Widget _buildSubscriptionInfo(ParentService service) {
    final BillingSummary? billing = service.billingSummary;
    final List<PaymentHistory> payments = billing?.recentPayments ?? <PaymentHistory>[];
    final String planName =
        (billing?.subscriptionPlan.trim().isNotEmpty ?? false)
            ? billing!.subscriptionPlan.toUpperCase()
        : _tParentBilling(context, 'STANDARD PLAN');
    final String learnerLabel = _selectedLearnerName(service);
    final String paymentMethod =
      payments.isNotEmpty && payments.first.description.isNotEmpty
        ? payments.first.description
        : _tParentBilling(context, 'On file');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: ScholesaColors.parent.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: ScholesaColors.parent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        planName,
                        style: TextStyle(
                          color: ScholesaColors.parent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.check_circle,
                        color: ScholesaColors.success),
                    const SizedBox(width: 4),
                    Text(
                      _tParentBilling(context, 'Active'),
                      style: TextStyle(
                        color: ScholesaColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '${_formatCurrency(billing?.nextPaymentAmount ?? 0)}/${_tParentBilling(context, 'month')}',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$learnerLabel • ${_tParentBilling(context, 'Billed monthly')}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  _tParentBilling(context, 'Plan Includes:'),
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _PlanFeature(
                  icon: Icons.school,
                  text: _tParentBilling(context, 'Unlimited session access'),
                ),
                _PlanFeature(
                  icon: Icons.rocket_launch,
                  text: _tParentBilling(context, 'All 3 pillars curriculum'),
                ),
                _PlanFeature(
                  icon: Icons.person,
                  text: _tParentBilling(context, '1-on-1 educator support'),
                ),
                _PlanFeature(
                  icon: Icons.insights,
                  text: _tParentBilling(context, 'Real-time progress reports'),
                ),
                _PlanFeature(
                  icon: Icons.workspace_premium,
                  text: _tParentBilling(context, 'Certificates & badges'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ScholesaColors.parent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.credit_card,
                      color: ScholesaColors.parent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _tParentBilling(context, 'Payment Method'),
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        paymentMethod,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _updatePaymentMethod,
                  child: Text(_tParentBilling(context, 'Update')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _managePlan,
              style: OutlinedButton.styleFrom(
                foregroundColor: ScholesaColors.parent,
                side: const BorderSide(color: ScholesaColors.parent),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(_tParentBilling(context, 'Manage Plan')),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _buildPaymentRows(ParentService service) {
    final BillingSummary? billing = service.billingSummary;
    final List<PaymentHistory> payments = billing?.recentPayments ?? <PaymentHistory>[];
    return payments.map((PaymentHistory payment) {
      return <String, dynamic>{
        'id': payment.id,
        'amount': payment.amount,
        'date': _formatDate(payment.date),
        'method': payment.description.isNotEmpty
            ? payment.description
            : _tParentBilling(context, 'On file'),
        'invoice': payment.id,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _buildInvoiceRows(ParentService service) {
    final BillingSummary? billing = service.billingSummary;
    final List<PaymentHistory> payments = billing?.recentPayments ?? <PaymentHistory>[];
    final String learnerLabel = _selectedLearnerName(service);

    final List<Map<String, dynamic>> rows = payments.map((PaymentHistory payment) {
      return <String, dynamic>{
        'id': payment.id,
        'learner': learnerLabel,
        'period': _formatMonthYear(payment.date),
        'amount': payment.amount,
        'status': payment.status.toLowerCase() == 'paid' ? 'paid' : 'due',
      };
    }).toList();

    if ((billing?.nextPaymentAmount ?? 0) > 0) {
      rows.insert(
        0,
        <String, dynamic>{
          'id': 'NEXT-DUE',
          'learner': learnerLabel,
          'period': _formatMonthYear(billing?.nextPaymentDate),
          'amount': billing?.nextPaymentAmount ?? 0.0,
          'status': 'due',
        },
      );
    }

    return rows;
  }

  String _selectedLearnerName(ParentService service) {
    if (_selectedLearner == 'all') {
      return _tParentBilling(context, 'All Learners');
    }
    final LearnerSummary? selected = service.learnerSummaries
        .where((LearnerSummary learner) => learner.learnerId == _selectedLearner)
        .firstOrNull;
    return selected?.learnerName ?? _tParentBilling(context, 'All Learners');
  }

  String _formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '--';
    final String day = value.day.toString().padLeft(2, '0');
    final String month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  String _formatMonthYear(DateTime? value) {
    if (value == null) return '--';
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
      'Dec',
    ];
    return '${months[value.month - 1]} ${value.year}';
  }

  void _downloadStatements() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{
        'cta': 'parent_billing_download_statements'
      },
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_tParentBilling(context, 'Downloading statements...')),
        backgroundColor: ScholesaColors.parent,
      ),
    );
  }

  void _payInvoice(Map<String, dynamic> invoice) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'parent_billing_pay_invoice',
        'invoice_id': invoice['id']
      },
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '${_tParentBilling(context, 'Paying invoice')} ${invoice['id']}...'),
        backgroundColor: ScholesaColors.parent,
      ),
    );
  }

  void _viewInvoice(Map<String, dynamic> invoice) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'parent_billing_view_invoice',
        'invoice_id': invoice['id']
      },
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '${_tParentBilling(context, 'Viewing invoice')} ${invoice['id']}...'),
        backgroundColor: ScholesaColors.parent,
      ),
    );
  }

  void _updatePaymentMethod() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{
        'cta': 'parent_billing_update_payment_method'
      },
    );
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(_tParentBilling(context, 'Update Payment Method')),
        content: Text(
          _tParentBilling(
              context, 'Select your preferred payment method update action.'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'cta': 'parent_billing_cancel_update_payment_method',
                },
              );
              Navigator.pop(dialogContext);
            },
            child: Text(_tParentBilling(context, 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'cta': 'parent_billing_continue_update_payment_method',
                },
              );
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_tParentBilling(
                      context, 'Payment method update request submitted')),
                  backgroundColor: ScholesaColors.parent,
                ),
              );
            },
            child: Text(_tParentBilling(context, 'Continue')),
          ),
        ],
      ),
    );
  }

  void _managePlan() {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{'cta': 'parent_billing_manage_plan'},
    );
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(_tParentBilling(context, 'Manage Plan')),
        content: Text(
          _tParentBilling(
              context, 'You can review your current subscription and request plan changes.'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'cta': 'parent_billing_close_manage_plan_dialog'
                },
              );
              Navigator.pop(dialogContext);
            },
            child: Text(_tParentBilling(context, 'Close')),
          ),
          ElevatedButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'cta': 'parent_billing_request_plan_change'
                },
              );
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_tParentBilling(
                      context, 'Plan review request sent to billing team')),
                  backgroundColor: ScholesaColors.parent,
                ),
              );
            },
            child: Text(_tParentBilling(context, 'Request Change')),
          ),
        ],
      ),
    );
  }
}

class _BalanceStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _BalanceStatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

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
          Icon(icon, color: Colors.white70, size: 18),
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
  final Map<String, dynamic> invoice;
  final VoidCallback onPay;
  final VoidCallback onView;

  const _InvoiceCard({
    required this.invoice,
    required this.onPay,
    required this.onView,
  });

  bool get _isPaid => invoice['status'] == 'paid';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isPaid
                ? Colors.grey.shade200
                : ScholesaColors.warning.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (_isPaid
                            ? ScholesaColors.success
                            : ScholesaColors.warning)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isPaid ? Icons.check_circle : Icons.pending,
                    color: _isPaid
                        ? ScholesaColors.success
                        : ScholesaColors.warning,
                  ),
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
                        '${invoice['learner']} • ${invoice['period']}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
                        color: (_isPaid
                                ? ScholesaColors.success
                                : ScholesaColors.warning)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _isPaid
                            ? _tParentBilling(context, 'PAID')
                            : _tParentBilling(context, 'DUE'),
                        style: TextStyle(
                          color: _isPaid
                              ? ScholesaColors.success
                              : ScholesaColors.warning,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (!_isPaid) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        TelemetryService.instance.logEvent(
                          event: 'cta.clicked',
                          metadata: <String, dynamic>{
                            'cta': 'parent_billing_invoice_view',
                            'invoice_id': invoice['id'],
                          },
                        );
                        onView();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ScholesaColors.parent,
                      ),
                      child: Text(_tParentBilling(context, 'View')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        TelemetryService.instance.logEvent(
                          event: 'cta.clicked',
                          metadata: <String, dynamic>{
                            'cta': 'parent_billing_invoice_pay',
                            'invoice_id': invoice['id'],
                          },
                        );
                        onPay();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ScholesaColors.parent,
                      ),
                      child: Text(
                        _tParentBilling(context, 'Pay Now'),
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final Map<String, dynamic> payment;

  const _PaymentCard({required this.payment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
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
                    '\$${(payment['amount'] as double).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${payment['method']} • ${payment['date']}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              payment['invoice'] as String,
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanFeature extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PlanFeature({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: ScholesaColors.parent),
          const SizedBox(width: 12),
          Text(text),
        ],
      ),
    );
  }
}
