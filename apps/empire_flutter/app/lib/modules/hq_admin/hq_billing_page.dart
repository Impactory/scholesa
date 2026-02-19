import 'package:flutter/material.dart';
import '../../ui/theme/scholesa_theme.dart';

/// HQ Billing Page - Platform-wide billing and revenue management
class HqBillingPage extends StatefulWidget {
  const HqBillingPage({super.key});

  @override
  State<HqBillingPage> createState() => _HqBillingPageState();
}

class _HqBillingPageState extends State<HqBillingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedSite = 'all';
  String _selectedPeriod = 'month';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
              ScholesaColors.hq.withOpacity(0.05),
              Colors.white,
              ScholesaColors.success.withOpacity(0.03),
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
        label: const Text('New Invoice'),
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
                    color: ScholesaColors.hq.withOpacity(0.3),
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
                    'Billing Management',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: ScholesaColors.hq,
                        ),
                  ),
                  Text(
                    'Invoices, payments & subscriptions',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _exportFinancials,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ScholesaColors.hq.withOpacity(0.1),
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
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: DropdownButton<String>(
                value: _selectedSite,
                isExpanded: true,
                underline: const SizedBox(),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(value: 'all', child: Text('All Sites')),
                  DropdownMenuItem<String>(value: 'sg', child: Text('Singapore')),
                  DropdownMenuItem<String>(value: 'kl', child: Text('Kuala Lumpur')),
                  DropdownMenuItem<String>(value: 'jkt', child: Text('Jakarta')),
                ],
                onChanged: (String? value) {
                  if (value != null) setState(() => _selectedSite = value);
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
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: DropdownButton<String>(
                value: _selectedPeriod,
                isExpanded: true,
                underline: const SizedBox(),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(value: 'month', child: Text('This Month')),
                  DropdownMenuItem<String>(value: 'quarter', child: Text('This Quarter')),
                  DropdownMenuItem<String>(value: 'year', child: Text('This Year')),
                ],
                onChanged: (String? value) {
                  if (value != null) setState(() => _selectedPeriod = value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueOverview() {
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
              ScholesaColors.hq.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: ScholesaColors.hq.withOpacity(0.3),
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
                    const Text(
                      'Total Revenue',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      r'$124,580',
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
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.trending_up, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            '+18.2% vs last period',
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
                    color: Colors.white.withOpacity(0.2),
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
            const Row(
              children: <Widget>[
                Expanded(
                  child: _RevenueStatCard(
                    label: 'Collected',
                    value: r'$112,430',
                    icon: Icons.check_circle,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _RevenueStatCard(
                    label: 'Pending',
                    value: r'$8,650',
                    icon: Icons.pending,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _RevenueStatCard(
                    label: 'Overdue',
                    value: r'$3,500',
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
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[600],
        indicator: BoxDecoration(
          color: ScholesaColors.hq,
          borderRadius: BorderRadius.circular(12),
        ),
        tabs: const <Widget>[
          Tab(text: 'Invoices'),
          Tab(text: 'Payments'),
          Tab(text: 'Subscriptions'),
        ],
      ),
    );
  }

  Widget _buildInvoicesList() {
    final List<Map<String, dynamic>> invoices = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'INV-2024-001',
        'parent': 'Sarah Johnson',
        'learner': 'Emma Johnson',
        'site': 'Singapore',
        'amount': 450.00,
        'status': 'paid',
        'date': 'Dec 1, 2024',
      },
      <String, dynamic>{
        'id': 'INV-2024-002',
        'parent': 'Michael Chen',
        'learner': 'Liam Chen',
        'site': 'Kuala Lumpur',
        'amount': 380.00,
        'status': 'pending',
        'date': 'Dec 5, 2024',
      },
      <String, dynamic>{
        'id': 'INV-2024-003',
        'parent': 'Ana Martinez',
        'learner': 'Sofia Martinez',
        'site': 'Singapore',
        'amount': 450.00,
        'status': 'overdue',
        'date': 'Nov 15, 2024',
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: invoices.length,
      itemBuilder: (BuildContext context, int index) {
        final Map<String, dynamic> invoice = invoices[index];
        return _InvoiceCard(invoice: invoice);
      },
    );
  }

  Widget _buildPaymentsList() {
    final List<Map<String, dynamic>> payments = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'PAY-001',
        'from': 'Sarah Johnson',
        'method': 'Credit Card',
        'amount': 450.00,
        'date': 'Dec 1, 2024',
        'invoice': 'INV-2024-001',
      },
      <String, dynamic>{
        'id': 'PAY-002',
        'from': 'David Lee',
        'method': 'Bank Transfer',
        'amount': 380.00,
        'date': 'Nov 28, 2024',
        'invoice': 'INV-2024-004',
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: payments.length,
      itemBuilder: (BuildContext context, int index) {
        final Map<String, dynamic> payment = payments[index];
        return _PaymentCard(payment: payment);
      },
    );
  }

  Widget _buildSubscriptionsList() {
    final List<Map<String, dynamic>> subscriptions = <Map<String, dynamic>>[
      <String, dynamic>{
        'parent': 'Sarah Johnson',
        'learners': 2,
        'plan': 'Premium',
        'amount': 450.00,
        'status': 'active',
        'nextBilling': 'Jan 1, 2025',
      },
      <String, dynamic>{
        'parent': 'Michael Chen',
        'learners': 1,
        'plan': 'Standard',
        'amount': 280.00,
        'status': 'active',
        'nextBilling': 'Jan 5, 2025',
      },
      <String, dynamic>{
        'parent': 'Ana Martinez',
        'learners': 1,
        'plan': 'Premium',
        'amount': 350.00,
        'status': 'paused',
        'nextBilling': '-',
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: subscriptions.length,
      itemBuilder: (BuildContext context, int index) {
        final Map<String, dynamic> subscription = subscriptions[index];
        return _SubscriptionCard(subscription: subscription);
      },
    );
  }

  void _createInvoice() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => _CreateInvoiceSheet(),
    );
  }

  void _exportFinancials() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Financial report export coming soon'),
        backgroundColor: ScholesaColors.hq,
      ),
    );
  }
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
        color: Colors.white.withOpacity(0.15),
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
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ScholesaColors.hq.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.receipt_long, color: ScholesaColors.hq),
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
                        color: _statusColor.withOpacity(0.1),
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
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.visibility, size: 20),
                      color: Colors.grey[600],
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.send, size: 20),
                      color: ScholesaColors.hq,
                    ),
                  ],
                ),
              ],
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
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ScholesaColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.check_circle, color: ScholesaColors.success),
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
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
                  style: TextStyle(color: Colors.grey[500], fontSize: 10),
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
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ScholesaColors.hq.withOpacity(0.1),
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
                        '${subscription['learners']} learner(s) • ${subscription['plan']} Plan',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
                    color: _statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    (subscription['status'] as String).toUpperCase(),
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
                      'Next billing: ${subscription['nextBilling']}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
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
  @override
  State<_CreateInvoiceSheet> createState() => _CreateInvoiceSheetState();
}

class _CreateInvoiceSheetState extends State<_CreateInvoiceSheet> {
  String? _selectedParent;
  String? _selectedLearner;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

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
                const Text(
                  'Create Invoice',
                  style: TextStyle(
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
                  const Text(
                    'Parent',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedParent,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      hintText: 'Select parent',
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: 'p1',
                        child: Text('Sarah Johnson'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'p2',
                        child: Text('Michael Chen'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'p3',
                        child: Text('Ana Martinez'),
                      ),
                    ],
                    onChanged: (String? value) {
                      setState(() => _selectedParent = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Learner',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedLearner,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      hintText: 'Select learner',
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: 'l1',
                        child: Text('Emma Johnson'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'l2',
                        child: Text('Liam Chen'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'l3',
                        child: Text('Sofia Martinez'),
                      ),
                    ],
                    onChanged: (String? value) {
                      setState(() => _selectedLearner = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Amount',
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
                  const Text(
                    'Description',
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
                      hintText: 'Invoice description...',
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
                      child: const Text(
                        'Create Invoice',
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

  void _createInvoice() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invoice created successfully'),
        backgroundColor: ScholesaColors.success,
      ),
    );
  }
}
