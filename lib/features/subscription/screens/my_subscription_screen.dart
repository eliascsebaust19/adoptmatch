import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/models/payment_record_model.dart';
import '../../../core/models/subscription_plan_model.dart';
import '../../../core/models/user_subscription_model.dart';
import '../../../core/repositories/subscription_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/adoptmatch_back_button.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../../auth/bloc/auth_bloc.dart';

class MySubscriptionScreen extends StatefulWidget {
  const MySubscriptionScreen({super.key});

  @override
  State<MySubscriptionScreen> createState() => _MySubscriptionScreenState();
}

class _MySubscriptionScreenState extends State<MySubscriptionScreen> {
  final _repo = SubscriptionRepository();
  bool _isLoading = true;
  UserSubscription? _subscription;
  List<PaymentRecord> _history = [];

  @override
  void initState() {
    super.initState();
    _loadSubscriptionDetails();
  }

  Future<void> _loadSubscriptionDetails() async {
    final authState = context.read<AuthBloc>().state;
    final userId = authState is Authenticated ? authState.user.id : 'u-101';

    final data = await _repo.fetchMySubscription(userId);

    if (mounted) {
      setState(() {
        _subscription = data['subscription'] as UserSubscription?;
        _history = (data['history'] as List<PaymentRecord>?) ?? [];
        _isLoading = false;
      });
    }
  }

  SubscriptionPlan _getPlanDetails(String? planId) {
    return _repo.cachedPlans.firstWhere(
      (p) => p.id == planId,
      orElse: () => _repo.cachedPlans[0],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBn = AppLocaleScope.of(context).language == AppLanguage.bn;
    final authState = context.watch<AuthBloc>().state;
    final user = authState is Authenticated ? authState.user : null;

    final isPremium =
        user?.hasActivePremium ?? (_subscription?.isActive ?? false);
    final remainingDays =
        user?.remainingDays ?? (_subscription?.remainingDays ?? 0);
    final isExpiringSoon = isPremium && remainingDays <= 3;
    final activePlan = _getPlanDetails(
      user?.premiumPlanId ?? _subscription?.planId,
    );

    return Scaffold(
      backgroundColor: AppColors.surfaceScaffold,
      appBar: AppBar(
        leading: const AdoptMatchBackButton(fallbackPath: '/home'),
        title: Text(isBn ? 'আমার সাবস্ক্রিপশন' : 'My Subscription'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadSubscriptionDetails();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: AppLoadingIndicator(
                message: 'Loading subscription status...',
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Expiry Reminder Banner if expiring soon
                  if (isExpiringSoon) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFFD97706),
                            size: 24,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isBn
                                      ? 'সাবস্ক্রিপশনের মেয়াদ দ্রুত শেষ হচ্ছে!'
                                      : 'Subscription Expiring Soon!',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isBn
                                      ? 'আপনার প্ল্যানের মেয়াদ আর মাত্র $remainingDays দিন বাকি আছে। সুবিধাগুলো সচল রাখতে এখনই রিনিউ করুন।'
                                      : 'Only $remainingDays days left on your plan. Renew today to maintain priority features.',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Main Status Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      gradient: isPremium
                          ? const LinearGradient(
                              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isPremium ? null : Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(
                        color: isPremium
                            ? const Color(0xFF334155)
                            : AppColors.border,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isPremium
                                    ? const Color(0xFF10B981).withOpacity(0.18)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.xs,
                                ),
                                border: Border.all(
                                  color: isPremium
                                      ? const Color(0xFF10B981)
                                      : AppColors.border,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isPremium
                                        ? Icons.check_circle
                                        : Icons.person_outline,
                                    size: 13,
                                    color: isPremium
                                        ? const Color(0xFF10B981)
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isPremium
                                        ? (isBn
                                              ? 'সক্রিয় প্রিমিয়াম'
                                              : 'ACTIVE PREMIUM')
                                        : (isBn ? 'ফ্রি মেম্বার' : 'FREE TIER'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: isPremium
                                          ? const Color(0xFF34D399)
                                          : AppColors.slateMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isPremium)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFF59E0B),
                                      Color(0xFFD97706),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.xs,
                                  ),
                                ),
                                child: Text(
                                  '$remainingDays Days Remaining',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        Text(
                          isPremium
                              ? (isBn ? activePlan.nameBn : activePlan.name)
                              : 'Basic Adopter Tier',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: isPremium
                                ? Colors.white
                                : AppColors.slateDark,
                          ),
                        ),
                        const SizedBox(height: 4),

                        Text(
                          isPremium
                              ? 'Active BDT plan • ${activePlan.formattedPrice} / ${activePlan.durationString}'
                              : 'Free community tier with standard listings',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isPremium
                                ? const Color(0xFF94A3B8)
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Expiry and Renewal Timelines
                        if (isPremium) ...[
                          const Divider(height: 1, color: Color(0xFF334155)),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Expires on:',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    user?.premiumExpiresAt != null
                                        ? DateFormat('dd MMMM yyyy')
                                              .format(user!.premiumExpiresAt!)
                                        : 'Active',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.button,
                                    ),
                                  ),
                                ),
                                onPressed: () =>
                                    context.push('/subscription/plans'),
                                child: const Text(
                                  'Extend Plan',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          AppPrimaryButton(
                            text: isBn
                                ? 'প্ল্যান আপগ্রেড করুন'
                                : 'Upgrade to Premium (from ৳90)',
                            icon: const Icon(
                              Icons.workspace_premium,
                              color: Colors.white,
                              size: 18,
                            ),
                            onPressed: () =>
                                context.push('/subscription/plans'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // Payment & Invoices History Header
                  Text(
                    isBn
                        ? 'পেমেন্ট ও ট্রানজ্যাকশন হিস্ট্রি'
                        : 'Billing & Payment History',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.slateDark,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  if (_history.isEmpty)
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: Center(
                        child: Column(
                          children: const [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 40,
                              color: Color(0xFFCBD5E1),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'No previous billing records',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Column(
                      children: _history.map((item) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: 4,
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _getStatusColor(item.status)
                                    .withOpacity(0.12),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                              ),
                              child: Icon(
                                item.isSuccess
                                    ? Icons.check_circle
                                    : (item.isPendingApproval
                                          ? Icons.hourglass_top
                                          : Icons.error_outline),
                                color: _getStatusColor(item.status),
                                size: 20,
                              ),
                            ),
                            title: Text(
                              item.planName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.slateDark,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text(
                                  '${DateFormat('dd MMM yyyy, hh:mm a').format(item.createdAt)} • ${item.paymentMethod}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                if (item.trxId != null)
                                  Text(
                                    'TrxID: ${item.trxId}',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontFamily: 'monospace',
                                      color: Color(0xFFD12053),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  item.formattedAmount,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: AppColors.slateDark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(item.status)
                                        .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.xs,
                                    ),
                                  ),
                                  child: Text(
                                    item.status,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: _getStatusColor(item.status),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'SUCCESS':
        return const Color(0xFF10B981);
      case 'PENDING_APPROVAL':
      case 'PENDING':
        return const Color(0xFFF59E0B);
      case 'FAILED':
      case 'CANCELLED':
      default:
        return const Color(0xFFE11D48);
    }
  }
}
