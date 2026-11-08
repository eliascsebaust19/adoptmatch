import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/payment_record_model.dart';
import '../../../core/models/subscription_plan_model.dart';
import '../../../core/repositories/subscription_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/shared_widgets.dart';

class SubscriptionManagementScreen extends StatefulWidget {
  const SubscriptionManagementScreen({super.key});

  @override
  State<SubscriptionManagementScreen> createState() =>
      _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState
    extends State<SubscriptionManagementScreen>
    with SingleTickerProviderStateMixin {
  final _repo = SubscriptionRepository();
  bool _isLoading = true;
  String? _loadError;

  Map<String, dynamic> _stats = {
    'totalRevenue': 0.0,
    'successfulTransactionsCount': 0,
    'pendingApprovalsCount': 0,
    'activePremiumUsersCount': 0,
  };

  List<PaymentRecord> _payments = [];
  List<SubscriptionPlan> _plans = [];
  String _selectedFilter = 'ALL';
  String _searchQuery = '';

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAdminData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminData() async {
    try {
      final statsData = await _repo.fetchAdminSubscriptionsStats();
      final payments = await _repo.fetchAdminPayments(
        status: _selectedFilter,
        search: _searchQuery,
      );
      final plans = await _repo.fetchPlans();

      if (!mounted) return;
      setState(() {
        _stats = (statsData['stats'] as Map<String, dynamic>?) ?? _stats;
        _payments = payments;
        _plans = plans;
        _loadError = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // Never display placeholder revenue as if it were real.
        _loadError = 'Could not load subscription data. Check your connection and permissions.\n$e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleApprove(String tranId, String userName) async {
    final success = await _repo.approveManualPayment(tranId);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          content: Text('Payment approved! Premium activated for $userName.'),
        ),
      );
      _loadAdminData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Could not approve this payment. No changes were made.'),
        ),
      );
    }
  }

  Future<void> _handleReject(String tranId) async {
    final reasonController = TextEditingController(
      text: 'Invalid bKash Transaction ID',
    );

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: const Text(
          'Reject Payment Request',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter rejection reason for the applicant:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'e.g. TrxID not found in merchant statement',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Reject Payment',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final rejected = await _repo.rejectManualPayment(tranId, reasonController.text);
      if (!mounted) return;
      if (!rejected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Could not reject this payment. No changes were made.'),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Payment rejected.'),
        ),
      );
      _loadAdminData();
    }
    reasonController.dispose();
  }

  void _showPlanEditDialog(SubscriptionPlan plan) {
    final priceController = TextEditingController(
      text: plan.price.toInt().toString(),
    );
    final durationController = TextEditingController(
      text: plan.durationDays.toString(),
    );
    bool isBestValue = plan.isBestValue;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          title: Text(
            'Edit ${plan.name}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price (BDT ৳)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Duration (Days)'),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text(
                  'Best Value Badge',
                  style: TextStyle(fontSize: 13),
                ),
                value: isBestValue,
                activeColor: const Color(0xFFF59E0B),
                onChanged: (val) => setDialogState(() => isBestValue = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                final newPrice =
                    double.tryParse(priceController.text) ?? plan.price;
                final newDuration =
                    int.tryParse(durationController.text) ?? plan.durationDays;

                await _repo.updatePlan(plan.id, {
                  'price': newPrice,
                  'durationDays': newDuration,
                  'isBestValue': isBestValue,
                });

                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Plan "${plan.name}" updated successfully!'),
                  ),
                );
                _loadAdminData();
              },
              child: const Text(
                'Save Changes',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      priceController.dispose();
      durationController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pendingQueue = _payments.where((p) => p.isPendingApproval).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: _isLoading
          ? const Center(
              child: AppLoadingIndicator(
                message: 'Loading subscription dashboard...',
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_loadError != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFFB91C1C), size: 20),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _loadError!,
                              style: const TextStyle(fontSize: 13, color: Color(0xFFB91C1C)),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() => _isLoading = true);
                              _loadAdminData();
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  // Header Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Subscription & Billing Management',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'SSLCommerz gateway monitoring, manual bKash approvals & dynamic pricing desk',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: _loadAdminData,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // KPI Metric Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Total Revenue',
                          value:
                              '৳${((_stats['totalRevenue'] as num?) ?? 0).toInt()} BDT',
                          subtitle: 'Verified SSL & bKash collections',
                          icon: Icons.monetization_on,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Active VIP Rescuers',
                          value: '${_stats['activePremiumUsersCount'] ?? 0}',
                          subtitle: 'Currently paid subscriptions',
                          icon: Icons.workspace_premium,
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Pending bKash Approvals',
                          value: '${pendingQueue.length}',
                          subtitle: 'Manual TrxID submissions',
                          icon: Icons.hourglass_top_rounded,
                          color: pendingQueue.isNotEmpty
                              ? const Color(0xFFD12053)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // Navigation Tabs
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: Colors.white,
                      unselectedLabelColor: const Color(0xFF94A3B8),
                      indicatorColor: AppColors.primary,
                      indicatorWeight: 3,
                      tabs: [
                        Tab(
                          icon: const Icon(Icons.approval, size: 16),
                          text:
                              'Pending bKash Approvals (${pendingQueue.length})',
                        ),
                        const Tab(
                          icon: Icon(Icons.receipt_long, size: 16),
                          text: 'All Payment Transactions',
                        ),
                        const Tab(
                          icon: Icon(Icons.tune, size: 16),
                          text: 'Subscription Plans Editor',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // TAB VIEW CONTENTS
                  SizedBox(
                    height: 520,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // TAB 1: PENDING BKASH QUEUE
                        _buildPendingApprovalTab(pendingQueue),

                        // TAB 2: ALL TRANSACTIONS
                        _buildTransactionsTab(),

                        // TAB 3: PLAN PRICING EDITOR
                        _buildPlansEditorTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingApprovalTab(List<PaymentRecord> queue) {
    if (queue.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(
                Icons.check_circle_outline,
                size: 48,
                color: Color(0xFF10B981),
              ),
              SizedBox(height: 12),
              Text(
                'All pending bKash transfers have been reviewed!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'New manual payments submitted by adopters will appear here in real-time.',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: queue.length,
      itemBuilder: (context, index) {
        final item = queue[index];
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: const Color(0xFFD12053).withOpacity(0.5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD12053).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.phone_android,
                  color: Color(0xFFD12053),
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          item.userName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                          child: const Text(
                            'PENDING APPROVAL',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.userEmail} • Submitted: ${DateFormat('dd MMM yyyy, hh:mm a').format(item.createdAt)}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'bKash Sender Phone:',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                Text(
                                  item.senderPhone ?? 'N/A',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'bKash TrxID:',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                Text(
                                  item.trxId ?? 'N/A',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF38BDF8),
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Plan & Amount:',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                Text(
                                  '${item.planName} (৳${item.amount.toInt()} BDT)',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),

              // Action Buttons
              Column(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text(
                      'Approve & Activate',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => _handleApprove(item.tranId, item.userName),
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                    ),
                    icon: const Icon(Icons.close, size: 14),
                    label: const Text(
                      'Reject',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => _handleReject(item.tranId),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransactionsTab() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        children: [
          // Filter & Search Controls
          Row(
            children: [
              Wrap(
                spacing: 8,
                children: ['ALL', 'SUCCESS', 'PENDING_APPROVAL', 'FAILED'].map((
                  st,
                ) {
                  final isSelected = _selectedFilter == st;
                  return ChoiceChip(
                    label: Text(
                      st,
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF94A3B8),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: const Color(0xFF0F172A),
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedFilter = st);
                        _loadAdminData();
                      }
                    },
                  );
                }).toList(),
              ),
              const Spacer(),
              SizedBox(
                width: 240,
                height: 38,
                child: TextField(
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                  onChanged: (val) {
                    _searchQuery = val;
                    _loadAdminData();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by TrxID or email...',
                    hintStyle: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                    contentPadding: EdgeInsets.zero,
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Transactions Table
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  headingTextStyle: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  dataTextStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                  columns: const [
                    DataColumn(label: Text('Transaction ID')),
                    DataColumn(label: Text('User')),
                    DataColumn(label: Text('Plan')),
                    DataColumn(label: Text('Amount')),
                    DataColumn(label: Text('Method / TrxID')),
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: _payments.map((p) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            p.tranId,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${p.userName}\n${p.userEmail}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        DataCell(Text(p.planName)),
                        DataCell(
                          Text(
                            p.formattedAmount,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${p.paymentMethod}${p.trxId != null ? ' (${p.trxId})' : ''}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        DataCell(
                          Text(
                            DateFormat('dd MMM, hh:mm a').format(p.createdAt),
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: p.isSuccess
                                  ? const Color(0xFF10B981).withOpacity(0.2)
                                  : (p.isPendingApproval
                                        ? const Color(0xFFF59E0B)
                                              .withOpacity(0.2)
                                        : const Color(0xFFE11D48)
                                              .withOpacity(0.2)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              p.status,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: p.isSuccess
                                    ? const Color(0xFF34D399)
                                    : (p.isPendingApproval
                                          ? const Color(0xFFFBBF24)
                                          : const Color(0xFFF87171)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlansEditorTab() {
    return ListView.builder(
      itemCount: _plans.length,
      itemBuilder: (context, index) {
        final plan = _plans[index];
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: plan.isBestValue
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF334155),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          plan.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        if (plan.isBestValue) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'BEST VALUE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Price: ৳${plan.price.toInt()} BDT • Duration: ${plan.durationDays} Days',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF38BDF8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      plan.features.take(3).join(' • '),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
                icon: const Icon(Icons.edit, size: 14),
                label: const Text(
                  'Edit Pricing & Duration',
                  style: TextStyle(fontSize: 12),
                ),
                onPressed: () => _showPlanEditDialog(plan),
              ),
            ],
          ),
        );
      },
    );
  }
}
