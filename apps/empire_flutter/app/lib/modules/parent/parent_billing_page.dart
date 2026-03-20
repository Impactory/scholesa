import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../i18n/workflow_surface_i18n.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';
import '../../runtime/runtime.dart';
import '../../i18n/bos_coaching_i18n.dart';
import '../../auth/app_state.dart';
import '../../services/firestore_service.dart';
import '../../ui/auth/global_session_menu.dart';
import 'parent_models.dart';
import 'parent_service.dart';

String _tParentBilling(BuildContext context, String input) {
  return WorkflowSurfaceI18n.text(context, input);
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
  static const String _canonicalLearnerUnavailableLabel = 'Learner unavailable';

  String _displayLearnerName(String learnerName) {
    final String normalized = learnerName.trim();
    if (normalized.isEmpty ||
        normalized == 'Unknown' ||
        normalized == _canonicalLearnerUnavailableLabel) {
      return _tParentBilling(context, 'Learner unavailable');
    }
    return normalized;
  }

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

  FirestoreService? _maybeFirestoreService() {
    try {
      return context.read<ParentService>().firestoreService;
    } catch (_) {
      return null;
    }
  }

  Future<String> _submitBillingSupportRequest({
    required String requestType,
    required String source,
    required String subject,
    required String message,
    required Map<String, dynamic> metadata,
  }) async {
    final FirestoreService? firestoreService = _maybeFirestoreService();
    if (firestoreService == null) {
      throw StateError(
        _tParentBilling(context, 'Support requests are unavailable right now.'),
      );
    }

    final AppState appState = context.read<AppState>();
    return firestoreService.submitSupportRequest(
      requestType: requestType,
      source: source,
      siteId: appState.activeSiteId?.trim().isNotEmpty == true
          ? appState.activeSiteId!.trim()
          : 'Not set',
      userId: appState.userId?.trim().isNotEmpty == true
          ? appState.userId!.trim()
          : 'Not set',
      userEmail: appState.email?.trim().isNotEmpty == true
          ? appState.email!.trim()
          : 'Not set',
      userName: appState.displayName?.trim().isNotEmpty == true
          ? appState.displayName!.trim()
          : 'Not set',
      role: appState.role?.name ?? 'unknown',
      subject: subject,
      message: message,
      metadata: metadata,
    );
  }

  Future<void> _handleBillingSupportRequest({
    required String requestType,
    required String source,
    required String subject,
    required String message,
    required Map<String, dynamic> metadata,
    required String successMessage,
  }) async {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': source,
        'request_type': requestType,
      },
    );

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final String requestId = await _submitBillingSupportRequest(
        requestType: requestType,
        source: source,
        subject: subject,
        message: message,
        metadata: metadata,
      );
      TelemetryService.instance.logEvent(
        event: 'parent.billing.support_request_submitted',
        metadata: <String, dynamic>{
          'request_type': requestType,
          'request_id': requestId,
        },
      );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      TelemetryService.instance.logEvent(
        event: 'parent.billing.support_request_failed',
        metadata: <String, dynamic>{
          'request_type': requestType,
          'error': error.toString(),
        },
      );
      if (!mounted) return;
      final String errorMessage = error is StateError
          ? error.message.toString()
          : _tParentBilling(
              context,
              'Unable to submit support request right now.',
            );
      messenger.showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  Widget _buildBillingSupportButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: ScholesaColors.parent,
        side: BorderSide(
          color: ScholesaColors.parent.withValues(alpha: 0.3),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
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
                      title: _tParentBilling(context, 'Billing AI Help'),
                      subtitle: _tParentBilling(
                        context,
                        'See support ideas for family billing and learner continuity',
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
                  if (service.learnerSummaries.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: _buildBillingLearnerLoopCard(service),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: ScholesaColors.parent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _tParentBilling(
                  context,
                  'Statements are shared by your site or HQ billing team.',
                ),
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: ScholesaColors.parent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const SessionMenuButton(
              foregroundColor: ScholesaColors.parent,
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLearnerFilter(ParentService service) {
    final List<LearnerSummary> learners = service.learnerSummaries;
    if (_selectedLearner != 'all' &&
        learners.every((LearnerSummary learner) =>
            learner.learnerId != _selectedLearner)) {
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
                child: Text(_displayLearnerName(learner.learnerName)),
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
    if (billing == null) {
      return _buildBillingUnavailableCard(
        title: _tParentBilling(context, 'No billing data yet'),
        body: _tParentBilling(
          context,
          'Billing details will appear once your site or HQ team provisions an active family billing account.',
        ),
        icon: Icons.receipt_long_outlined,
      );
    }
    final List<PaymentHistory> payments = billing.recentPayments;
    final DateTime now = DateTime.now();
    final double thisMonthPaid = payments
        .where((PaymentHistory payment) =>
            payment.status.toLowerCase() == 'paid' &&
            payment.date.year == now.year &&
            payment.date.month == now.month)
        .fold(
            0.0, (double sum, PaymentHistory payment) => sum + payment.amount);
    final double totalPaid = payments
        .where(
            (PaymentHistory payment) => payment.status.toLowerCase() == 'paid')
        .fold(
            0.0, (double sum, PaymentHistory payment) => sum + payment.amount);

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
                      _formatCurrency(billing.currentBalance),
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
                    value: _formatDate(billing.nextPaymentDate),
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

  Widget _buildBillingLearnerLoopCard(ParentService service) {
    LearnerSummary? selectedLearner;
    if (_selectedLearner == 'all') {
      selectedLearner = service.learnerSummaries.isNotEmpty
          ? service.learnerSummaries.first
          : null;
    } else {
      try {
        selectedLearner = service.learnerSummaries.firstWhere(
          (LearnerSummary l) => l.learnerId == _selectedLearner,
        );
      } catch (e) {
        selectedLearner = service.learnerSummaries.isNotEmpty
            ? service.learnerSummaries.first
            : null;
      }
    }

    if (selectedLearner == null) {
      return const SizedBox.shrink();
    }

    return BosLearnerLoopInsightsCard(
      title: BosCoachingI18n.familyBillingTitle(context),
      subtitle: BosCoachingI18n.familyBillingSubtitle(context),
      emptyLabel: BosCoachingI18n.familyBillingEmpty(context),
      learnerId: selectedLearner.learnerId,
      learnerName: selectedLearner.learnerName,
      accentColor: ScholesaColors.parent,
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
          onRequestInvoiceHelp: !_isDueInvoice(invoice)
              ? null
              : () => _handleBillingSupportRequest(
                    requestType: 'billing_invoice_help',
                    source: 'parent_billing_request_invoice_help',
                    subject: 'Parent invoice help request',
                    message: <String>[
                      'Please review this family invoice and follow up with the parent.',
                      '',
                      'Invoice ID: ${invoice['id']}',
                      'Learner: ${invoice['learner']}',
                      'Billing Period: ${invoice['period']}',
                      'Amount: ${_formatCurrency(invoice['amount'] as double)}',
                    ].join('\n'),
                    metadata: <String, dynamic>{
                      'invoiceId': invoice['id'],
                      'learner': invoice['learner'],
                      'billingPeriod': invoice['period'],
                      'amount': invoice['amount'],
                    },
                    successMessage: _tParentBilling(
                      context,
                      'Invoice help request submitted.',
                    ),
                  ),
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
    if (billing == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _buildBillingUnavailableCard(
          title: _tParentBilling(context, 'Billing plan unavailable'),
          body: _tParentBilling(
            context,
            'Billing details will appear once your site or HQ team provisions an active family billing account.',
          ),
          icon: Icons.account_balance_wallet_outlined,
        ),
      );
    }
    final List<PaymentHistory> payments = billing.recentPayments;
    final String planName = billing.subscriptionPlan.trim().isNotEmpty
        ? billing.subscriptionPlan.toUpperCase()
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
                  '${_formatCurrency(billing.nextPaymentAmount)}/${_tParentBilling(context, 'month')}',
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
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        _tParentBilling(
                          context,
                          'Payment method changes are handled by HQ billing support.',
                        ),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildBillingSupportButton(
                        label: _tParentBilling(
                          context,
                          'Request Payment Method Update',
                        ),
                        onPressed: () => _handleBillingSupportRequest(
                          requestType: 'billing_payment_method_update',
                          source:
                              'parent_billing_request_payment_method_update',
                          subject: 'Parent payment method update request',
                          message: <String>[
                            'Please contact this parent to review the payment method on file.',
                            '',
                            'Current Method: $paymentMethod',
                            'Plan: $planName',
                            'Learner Scope: $learnerLabel',
                          ].join('\n'),
                          metadata: <String, dynamic>{
                            'paymentMethod': paymentMethod,
                            'planName': planName,
                            'learnerScope': learnerLabel,
                          },
                          successMessage: _tParentBilling(
                            context,
                            'Payment method update request submitted.',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ScholesaColors.parent.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: ScholesaColors.parent.withValues(alpha: 0.18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _tParentBilling(
                    context,
                    'Plan changes are handled by HQ billing support.',
                  ),
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _buildBillingSupportButton(
                    label: _tParentBilling(context, 'Request Plan Change'),
                    onPressed: () => _handleBillingSupportRequest(
                      requestType: 'billing_plan_change',
                      source: 'parent_billing_request_plan_change',
                      subject: 'Parent billing plan change request',
                      message: <String>[
                        'Please follow up with this parent about changing their billing plan.',
                        '',
                        'Current Plan: $planName',
                        'Learner Scope: $learnerLabel',
                        'Next Payment Amount: ${_formatCurrency(billing.nextPaymentAmount)}',
                        'Next Payment Date: ${billing.nextPaymentDate?.toIso8601String() ?? 'Not set'}',
                      ].join('\n'),
                      metadata: <String, dynamic>{
                        'planName': planName,
                        'learnerScope': learnerLabel,
                        'nextPaymentAmount': billing.nextPaymentAmount,
                        'nextPaymentDate':
                            billing.nextPaymentDate?.toIso8601String(),
                      },
                      successMessage: _tParentBilling(
                        context,
                        'Plan change request submitted.',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _buildPaymentRows(ParentService service) {
    final BillingSummary? billing = service.billingSummary;
    final List<PaymentHistory> payments =
        billing?.recentPayments ?? <PaymentHistory>[];
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
    final List<PaymentHistory> payments =
        billing?.recentPayments ?? <PaymentHistory>[];
    final String learnerLabel = _selectedLearnerName(service);

    final List<Map<String, dynamic>> rows =
        payments.map((PaymentHistory payment) {
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
        .where(
            (LearnerSummary learner) => learner.learnerId == _selectedLearner)
        .firstOrNull;
    return selected != null
        ? _displayLearnerName(selected.learnerName)
        : _tParentBilling(context, 'All Learners');
  }

  String _formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }

  bool _isDueInvoice(Map<String, dynamic> invoice) {
    return invoice['status'] == 'due';
  }

  Widget _buildBillingUnavailableCard({
    required String title,
    required String body,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ScholesaColors.parent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: ScholesaColors.parent),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: TextStyle(color: Colors.grey[700], height: 1.4),
            ),
          ],
        ),
      ),
    );
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
  final VoidCallback? onRequestInvoiceHelp;

  const _InvoiceCard({
    required this.invoice,
    this.onRequestInvoiceHelp,
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ScholesaColors.parent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _tParentBilling(
                    context,
                    'Invoice actions are handled by your site or HQ billing team.',
                  ),
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (onRequestInvoiceHelp != null) ...<Widget>[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: onRequestInvoiceHelp,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ScholesaColors.parent,
                      side: BorderSide(
                        color: ScholesaColors.parent.withValues(alpha: 0.3),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      _tParentBilling(context, 'Request Invoice Help'),
                    ),
                  ),
                ),
              ],
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
