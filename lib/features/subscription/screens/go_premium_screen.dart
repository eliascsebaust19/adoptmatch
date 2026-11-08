import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/models/subscription_plan_model.dart';
import '../../../core/repositories/subscription_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/adoptmatch_back_button.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../../auth/bloc/auth_bloc.dart';

class GoPremiumScreen extends StatefulWidget {
  const GoPremiumScreen({super.key});

  @override
  State<GoPremiumScreen> createState() => _GoPremiumScreenState();
}

class _GoPremiumScreenState extends State<GoPremiumScreen>
    with SingleTickerProviderStateMixin {
  final _repo = SubscriptionRepository();
  List<SubscriptionPlan> _plans = const [];
  String _selectedPlanId = 'plan-quarterly'; // Default to Best Value
  bool _isLoadingPlans = true;
  bool _isProcessingPayment = false;
  String? _bkashNumber;
  String? _loadError;

  // Manual bKash Form controllers
  final _manualFormKey = GlobalKey<FormState>();
  final _senderPhoneController = TextEditingController();
  final _trxIdController = TextEditingController();
  bool _isSubmittingManual = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPlansAndBkash();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _senderPhoneController.dispose();
    _trxIdController.dispose();
    super.dispose();
  }

  Future<void> _loadPlansAndBkash() async {
    setState(() { _isLoadingPlans = true; _loadError = null; });
    try {
      final plans = await _repo.fetchPlans();
      String? bkash;
      String? manualError;
      try { bkash = await _repo.fetchBkashNumber(); }
      catch (_) { manualError = 'Manual bKash is unavailable. Do not send money to an unverified number.'; }
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _selectedPlanId = plans.any((p) => p.id == _selectedPlanId)
            ? _selectedPlanId : plans.first.id;
        _bkashNumber = bkash;
        _loadError = manualError;
        _isLoadingPlans = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _plans = const [];
        _bkashNumber = null;
        _loadError = 'Could not load current payment options. Please retry. ($e)';
        _isLoadingPlans = false;
      });
    }
  }

  SubscriptionPlan get _selectedPlan {
    return _plans.firstWhere(
      (p) => p.id == _selectedPlanId,
      orElse: () => _plans.first,
    );
  }

  Future<void> _handleSslCommerzSubscribe() async {
    if (_plans.isEmpty || _isLoadingPlans) return;
    final authState = context.read<AuthBloc>().state;
    final user = authState is Authenticated ? authState.user : null;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in before subscribing.')),
      );
      return;
    }

    setState(() => _isProcessingPayment = true);

    try {
      final result = await _repo.initiateSslCommerzPayment(
        planId: _selectedPlanId,
      );

      final gatewayUrl = result['gatewayUrl'] as String?;
      final tranId = result['tranId'] as String?;

      if (gatewayUrl != null && gatewayUrl.isNotEmpty) {
        final uri = Uri.parse(gatewayUrl);
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );

        if (!launched) {
          throw Exception(
            'Could not launch payment gateway. Please check browser settings.',
          );
        }

        if (!mounted) return;

        // Display waiting dialog instructing user to complete payment in browser
        _showPaymentPendingDialog(tranId ?? '');
      } else {
        throw Exception('Gateway URL not returned by server.');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Payment initiation failed: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }

  void _showPaymentPendingDialog(String tranId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: Row(
          children: const [
            Icon(Icons.payment_rounded, color: AppColors.primary, size: 24),
            SizedBox(width: 8),
            Text(
              'Processing Payment',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The SSLCommerz gateway has been opened in your browser to complete your payment with bKash, Nagad, or Card.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Text(
                'Transaction ID: $tranId',
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              // Ask the server whether the transaction settled; never grant locally.
              context.read<AuthBloc>().add(
                ActivateSubscriptionEvent(
                  planId: _selectedPlan.id,
                  durationDays: _selectedPlan.durationDays,
                ),
              );
              context.push('/subscription/my');
            },
            child: const Text('Check Payment Status'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleManualBkashSubmit() async {
    if (_plans.isEmpty || _bkashNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Manual payments are unavailable. Refresh payment options before sending money.')));
      return;
    }
    if (!_manualFormKey.currentState!.validate()) return;

    final authState = context.read<AuthBloc>().state;
    final user = authState is Authenticated ? authState.user : null;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in before submitting a payment.')),
      );
      return;
    }

    setState(() => _isSubmittingManual = true);

    try {
      final sender = _senderPhoneController.text.trim();
      final trx = _trxIdController.text.trim();

      await _repo.submitManualBkashPayment(
        planId: _selectedPlanId,
        senderPhone: sender,
        trxId: trx,
      );

      if (!mounted) return;

      _senderPhoneController.clear();
      _trxIdController.clear();

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          title: Row(
            children: const [
              Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF10B981),
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'Request Submitted!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ],
          ),
          content: Text(
            'Your manual bKash transaction has been submitted for review. An administrator will verify the TrxID ($trx) and activate your premium subscription shortly.',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/subscription/my');
              },
              child: const Text('View My Subscription'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.error, content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmittingManual = false);
    }
  }

  void _copyBkashNumber() {
    if (_bkashNumber == null) return;
    Clipboard.setData(ClipboardData(text: _bkashNumber));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFD12053),
        content: Text('bKash number $_bkashNumber copied to clipboard!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBn = AppLocaleScope.of(context).language == AppLanguage.bn;

    return Scaffold(
      backgroundColor: AppColors.surfaceScaffold,
      appBar: AppBar(
        leading: const AdoptMatchBackButton(fallbackPath: '/home'),
        title: Text(isBn ? 'প্রিমিয়াম সাবস্ক্রিপশন' : 'Go Premium'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.history, size: 18, color: AppColors.primary),
            label: Text(
              isBn ? 'আমার স্ট্যাটাস' : 'My Status',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: AppColors.primary,
              ),
            ),
            onPressed: () => context.push('/subscription/my'),
          ),
        ],
      ),
      body: _isLoadingPlans || _plans.isEmpty
          ? Center(
              child: _isLoadingPlans
                  ? const AppLoadingIndicator(message: 'Loading subscription packages...')
                  : Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_loadError ?? 'No subscription plans are available.', textAlign: TextAlign.center),
                          const SizedBox(height: AppSpacing.md),
                          AppPrimaryButton(text: 'Retry', onPressed: _loadPlansAndBkash),
                        ],
                      ),
                    ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  if (_loadError != null) ...[
                    Text(_loadError!, style: const TextStyle(color: AppColors.error)),
                    TextButton(onPressed: _loadPlansAndBkash, child: const Text('Refresh payment options')),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  // Hero Header Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFF59E0B),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.workspace_premium,
                            size: 36,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          isBn
                              ? 'AdoptMatch প্রিমিয়াম সাবস্ক্রিপশন'
                              : 'AdoptMatch Premium VIP',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isBn
                              ? 'প্রাণী সুরক্ষায় অবদান রাখুন এবং বিশেষ সুযোগ-সুবিধা উপভোগ করুন।'
                              : 'Support ethical rescue efforts and unlock priority features across Bangladesh.',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF94A3B8),
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Mode Tabs: Instant SSLCommerz vs Manual bKash
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textSecondary,
                      indicatorColor: AppColors.primary,
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      tabs: [
                        Tab(
                          icon: const Icon(Icons.bolt, size: 18),
                          text: isBn ? 'ইনস্ট্যান্ট গেটওয়ে' : 'Instant Gateway',
                        ),
                        Tab(
                          icon: const Icon(Icons.phone_android, size: 18),
                          text: isBn ? 'ম্যানুয়াল বিকাশ' : 'Manual bKash',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Plans Selection (Displayed in both tabs)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      isBn
                          ? '১. প্যাকেজ নির্বাচন করুন:'
                          : '1. Select Your Plan:',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.slateDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // 3 Plan Cards Row / Column
                  Column(
                    children: _plans.map((plan) {
                      final isSelected = plan.id == _selectedPlanId;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: InkWell(
                          onTap: () =>
                              setState(() => _selectedPlanId = plan.id),
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                AppRadius.card,
                              ),
                              border: Border.all(
                                color: isSelected
                                    ? (plan.isBestValue
                                          ? const Color(0xFFF59E0B)
                                          : AppColors.primary)
                                    : AppColors.border,
                                width: isSelected ? 2.2 : 1.0,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color:
                                            (plan.isBestValue
                                                    ? const Color(0xFFF59E0B)
                                                    : AppColors.primary)
                                                .withOpacity(0.12),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          isSelected
                                              ? Icons.check_circle
                                              : Icons.radio_button_unchecked,
                                          color: isSelected
                                              ? (plan.isBestValue
                                                    ? const Color(0xFFD97706)
                                                    : AppColors.primary)
                                              : const Color(0xFFCBD5E1),
                                          size: 20,
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        Text(
                                          isBn ? plan.nameBn : plan.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                            color: AppColors.slateDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (plan.isBestValue)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
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
                                          isBn ? 'সেরা সাশ্রয়ী' : 'BEST VALUE',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.xs,
                                          ),
                                        ),
                                        child: Text(
                                          isBn
                                              ? plan.durationStringBn
                                              : plan.durationString,
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.slateMedium,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.sm),

                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      plan.formattedPrice,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: isSelected
                                            ? (plan.isBestValue
                                                  ? const Color(0xFFD97706)
                                                  : AppColors.primary)
                                            : AppColors.slateDark,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      ' BDT / ${isBn ? plan.durationStringBn : plan.durationString}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.sm),

                                // Top 2 features bullets
                                ...plan.features
                                    .take(2)
                                    .map(
                                      (feat) => Padding(
                                        padding: const EdgeInsets.only(top: 3),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.check,
                                              size: 14,
                                              color: Color(0xFF10B981),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                feat,
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  color: AppColors.slateMedium,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // TAB CONTENT AREA:
                  SizedBox(
                    height: 480,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // TAB 1: SSLCOMMERZ INSTANT CHECKOUT
                        _buildInstantSslCommerzTab(isBn),

                        // TAB 2: MANUAL BKASH SUBMISSION
                        _buildManualBkashTab(isBn),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInstantSslCommerzTab(bool isBn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.security, size: 18, color: Color(0xFF10B981)),
                  SizedBox(width: 8),
                  Text(
                    'SSLCommerz 256-bit Secure Gateway',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.slateDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                isBn
                    ? 'বিকাশ (bKash), নগদ (Nagad), রকেট, ভিসা অথবা মাস্টারকার্ড দিয়ে তাৎক্ষণিক পেমেন্ট সম্পন্ন করুন।'
                    : 'Instant activation with bKash, Nagad, Rocket, Visa or Mastercard via official SSLCommerz channel.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _channelPill('bKash', const Color(0xFFD12053)),
                  _channelPill('Nagad', const Color(0xFFF97316)),
                  _channelPill('Rocket', const Color(0xFF7C3AED)),
                  _channelPill('Visa / MC', const Color(0xFF2563EB)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        AppPrimaryButton(
          text: isBn
              ? '${_selectedPlan.formattedPrice} BDT পরিশোধ করুন (SSLCommerz)'
              : 'Pay ${_selectedPlan.formattedPrice} BDT with bKash / Cards',
          icon: const Icon(Icons.lock, size: 18, color: Colors.white),
          isLoading: _isProcessingPayment,
          onPressed: _handleSslCommerzSubscribe,
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: Text(
            isBn ? 'পেমেন্ট সম্পন্ন হওয়ার সাথে সাথেই প্রিমিয়াম সক্রিয় হবে।' : 'Subscription activates automatically upon payment confirmation.',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManualBkashTab(bool isBn) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // bKash Official Number Card with Copy Action
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: const Color(0xFFFECDD3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.phone_iphone,
                          color: Color(0xFFD12053),
                          size: 20,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Official bKash Transfer Number',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF9F1239),
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD12053),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                      ),
                      icon: const Icon(Icons.copy, size: 12),
                      label: const Text(
                        'Copy',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _copyBkashNumber,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _bkashNumber ?? 'Not configured — do not send money',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF881337),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isBn
                      ? 'এই নম্বরে ${_selectedPlan.formattedPrice} টাকা Send Money / Payment করুন এবং নিচের ফর্মে TrxID দিন।'
                      : 'Send ${_selectedPlan.formattedPrice} BDT to this number and submit the sender phone + TrxID below.',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF9F1239),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Manual Verification Form
          Form(
            key: _manualFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  controller: _senderPhoneController,
                  label: isBn
                      ? 'আপনার বিকাশ প্রেরক নম্বর'
                      : 'bKash Sender Phone Number',
                  hint: 'e.g. 01712345678',
                  keyboardType: TextInputType.phone,
                  prefixIconData: Icons.phone,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter sender bKash phone number';
                    }
                    if (val.trim().length < 11) {
                      return 'Enter a valid 11-digit Bangladeshi mobile number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                AppTextField(
                  controller: _trxIdController,
                  label: isBn
                      ? 'বিকাশ ট্রানজ্যাকশন আইডি (TrxID)'
                      : 'bKash Transaction ID (TrxID)',
                  hint: 'e.g. 9G7A2K1092',
                  prefixIconData: Icons.receipt_long,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter the bKash TrxID';
                    }
                    if (val.trim().length < 6) {
                      return 'Please enter a valid TrxID from SMS';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xl),

                AppPrimaryButton(
                  text: isBn
                      ? 'বিকাশ TrxID সাবমিট করুন'
                      : 'Submit bKash Verification',
                  backgroundColor: const Color(0xFFD12053),
                  isLoading: _isSubmittingManual,
                  icon: const Icon(
                    Icons.send_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  onPressed: _handleManualBkashSubmit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _channelPill(String name, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
