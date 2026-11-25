import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/demo_config.dart';
import '../models/subscription_plan_model.dart';
import '../models/payment_record_model.dart';
import '../models/user_subscription_model.dart';
import '../storage/secure_storage_service.dart';
import '../network/api_client.dart';
import '../supabase/adoptmatch_supabase.dart';

class SubscriptionRepository {
  static final SubscriptionRepository _instance =
      SubscriptionRepository._internal();

  http.Client _client = http.Client();

  bool _isTestConfigured = false;
  void configureForTesting(http.Client client) {
    _isTestConfigured = true;
    _client = client;
    _cachedPlans = const [];
    officialBkashNumber = null;
  }

  factory SubscriptionRepository() => _instance;
  SubscriptionRepository._internal();

  bool get _useSupabase =>
      AdoptMatchBackend.isInitialized && !_isTestConfigured;

  bool _isDemoToken(String? token) =>
      token != null &&
      (token.startsWith('demo_') ||
          token.startsWith('viva-') ||
          token.contains('demo-token'));

  Future<bool> _isDemoSession([String? token]) async {
    if (_isTestConfigured || !DemoConfig.enableVivaDemoPass) return false;
    final effective = token ?? await SecureStorageService.instance.getAuthToken();
    return _isDemoToken(effective);
  }

  final List<SubscriptionPlan> _demoPlans = [
    const SubscriptionPlan(
      id: 'plan-monthly',
      name: 'Monthly VIP',
      nameBn: 'মাসিক ভিআইপি',
      price: 99,
      currency: 'BDT',
      durationDays: 30,
      tag: 'FLEXIBLE',
      features: ['Unlimited Adoptions', '24/7 Vet Chat', 'Health Passport'],
      featuresBn: ['আনলিমিটেড অ্যাডপশন', '২৪/৭ ভেট চ্যাট', 'হেলথ পাসপোর্ট'],
    ),
    const SubscriptionPlan(
      id: 'plan-quarterly',
      name: 'Quarterly Pro',
      nameBn: 'ত্রৈমাসিক প্রো',
      price: 249,
      currency: 'BDT',
      durationDays: 90,
      tag: 'POPULAR',
      isBestValue: true,
      features: ['Unlimited Adoptions', 'Priority Support', 'Vet Discount'],
      featuresBn: ['আনলিমিটেড অ্যাডপশন', 'অগ্রাধিকার সহায়তা', 'ভেট ডিসকাউন্ট'],
    ),
    const SubscriptionPlan(
      id: 'plan-annual',
      name: 'Annual Rescuer',
      nameBn: 'বাৎসরিক রেসকিউয়ার',
      price: 799,
      currency: 'BDT',
      durationDays: 365,
      tag: 'BEST VALUE',
      features: ['All VIP Perks', 'SOS Broadcast Priority', 'Verified Badge'],
      featuresBn: ['সব ভিআইপি সুবিধা', 'জরুরি SOS অগ্রাধিকার', 'ভেরিফায়েড ব্যাজ'],
    ),
  ];

  final List<PaymentRecord> _demoPayments = [
    PaymentRecord(
      tranId: 'AM-BKASH-9041',
      userId: 'u-demo-1',
      userName: 'Nadia Rahman',
      userEmail: 'nadia.rahman@demo.adoptmatch.app',
      planId: 'plan-annual',
      planName: 'Annual Rescuer',
      amount: 799,
      currency: 'BDT',
      status: 'PENDING_APPROVAL',
      paymentMethod: 'bKash (Manual)',
      senderPhone: '01712-445566',
      trxId: 'BKX84291QA',
      createdAt: DateTime.now().subtract(const Duration(minutes: 35)),
    ),
    PaymentRecord(
      tranId: 'AM-SSL-8820',
      userId: 'u-demo-2',
      userName: 'Farhan Ahmed',
      userEmail: 'farhan.ahmed@demo.adoptmatch.app',
      planId: 'plan-quarterly',
      planName: 'Quarterly Pro',
      amount: 249,
      currency: 'BDT',
      status: 'SUCCESS',
      paymentMethod: 'SSLCommerz',
      trxId: 'SSL99210PM',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  /// Configurable backend URL pointing to deployed production API by default
  String get baseUrl => ApiClient.rootUrl;

  /// Reads the stored session token so every request is attributable to a user.
  Future<Map<String, String>> _authHeaders({bool json = false}) async {
    final token = await SecureStorageService.instance.getAuthToken();
    return {
      if (json) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Only a destination explicitly configured by the server may be displayed.
  String? officialBkashNumber;

  /// Last successfully loaded catalog; never used as a checkout price authority.
  List<SubscriptionPlan> _cachedPlans = const [];
  List<SubscriptionPlan> get cachedPlans => _cachedPlans;

  /// Fetch all active subscription plans
  Future<List<SubscriptionPlan>> fetchPlans() async {
    if (await _isDemoSession()) {
      _cachedPlans = List<SubscriptionPlan>.from(_demoPlans);
      return _cachedPlans;
    }
    if (_useSupabase) {
      try {
        final rows = await AdoptMatchBackend.instance.plans();
        if (rows.isNotEmpty) {
          _cachedPlans = rows
              .map((item) => SubscriptionPlan.fromJson(item))
              .toList();
          return _cachedPlans;
        }
        throw Exception('The server returned no active subscription plans.');
      } catch (e) {
        debugPrint('[SubscriptionRepository] Supabase fetchPlans error: $e');
        rethrow;
      }
    }
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/v1/payments/plans'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rawList = data['plans'] as List<dynamic>?;
        if (rawList != null && rawList.isNotEmpty) {
          _cachedPlans = rawList
              .map(
                (item) =>
                    SubscriptionPlan.fromJson(item as Map<String, dynamic>),
              )
              .toList();
          return _cachedPlans;
        }
      }
      throw Exception('The server returned no active subscription plans.');
    } catch (e) {
      debugPrint('[SubscriptionRepository] fetchPlans error: $e');
      rethrow;
    }
  }

  /// Fetch official bKash transfer number
  Future<String> fetchBkashNumber() async {
    officialBkashNumber = null;
    if (_useSupabase) {
      try {
        final number = await AdoptMatchBackend.instance.bkashNumber();
        if (number != null && RegExp(r'^01[3-9][0-9]{8}$').hasMatch(number)) {
          officialBkashNumber = number;
          return number;
        }
      } catch (e) {
        debugPrint(
          '[SubscriptionRepository] Supabase fetchBkashNumber error: $e',
        );
      }
      throw Exception(
        'Manual bKash payments are not configured. Do not send money.',
      );
    }
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/v1/payments/bkash-number'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final number = data['bkashNumber'];
        if (data['configured'] == true &&
            number is String &&
            RegExp(r'^01[3-9][0-9]{8}$').hasMatch(number)) {
          officialBkashNumber = number;
          return number;
        }
      }
      throw Exception(
        'Manual bKash payments are not configured. Do not send money.',
      );
    } catch (e) {
      officialBkashNumber = null;
      rethrow;
    }
  }

  /// Initiate SSLCommerz Gateway Session (Server-side generated session URL)
  Future<Map<String, dynamic>> initiateSslCommerzPayment({
    required String planId,
    String? userPhone,
  }) async {
    if (_useSupabase) {
      try {
        final profile = await SecureStorageService.instance.getUserProfile();
        final data = await AdoptMatchBackend.instance.startSslcommerz(
          planId: planId,
          name: profile?.name,
          email: profile?.email,
          phone: userPhone ?? profile?.phone,
        );
        return {
          'success': true,
          'gateway_url': data['gateway_url'],
          'tran_id': data['tran_id'],
          'session': data,
        };
      } catch (e) {
        debugPrint(
          '[SubscriptionRepository] Supabase SSLCommerz initiation error: $e',
        );
        return {'success': false, 'error': e.toString()};
      }
    }
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/v1/payments/initiate-sslcommerz'),
            headers: await _authHeaders(json: true),
            // The server derives the account from the bearer token.
            body: jsonEncode({
              'planId': planId,
              if (userPhone != null && userPhone.isNotEmpty)
                'userPhone': userPhone,
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['error'] ?? 'Failed to initiate payment session');
      }
    } catch (e) {
      debugPrint('[SubscriptionRepository] SSLCommerz initiation error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Submit Manual bKash Payment (Pending Admin Approval)
  Future<PaymentRecord> submitManualBkashPayment({
    required String planId,
    required String senderPhone,
    required String trxId,
  }) async {
    if (_useSupabase) {
      try {
        final data = await AdoptMatchBackend.instance.submitManualBkash(
          planId: planId,
          trxId: trxId,
          senderPhone: senderPhone,
        );
        return PaymentRecord.fromJson(data);
      } catch (e) {
        debugPrint(
          '[SubscriptionRepository] Supabase submitManualBkashPayment error: $e',
        );
        rethrow;
      }
    }
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/v1/payments/manual-bkash'),
            headers: await _authHeaders(json: true),
            body: jsonEncode({
              'planId': planId,
              'senderPhone': senderPhone,
              'trxId': trxId,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return PaymentRecord.fromJson(data['payment'] as Map<String, dynamic>);
      } else {
        final err = jsonDecode(response.body);
        throw Exception(
          err['error'] ?? 'Failed to submit manual bKash transaction',
        );
      }
    } catch (e) {
      debugPrint('[SubscriptionRepository] submitManualBkashPayment error: $e');
      rethrow;
    }
  }

  /// Fetch user's active subscription and payment history
  /// Throws on failure so callers can show an error instead of assuming the
  /// account has no subscription.
  Future<Map<String, dynamic>> fetchMySubscription(String userId) async {
    if (_useSupabase) {
      try {
        final data = await AdoptMatchBackend.instance.mySubscription();
        final subMap = data['subscription'] as Map<String, dynamic>?;
        final historyRaw =
            data['pending'] as List<dynamic>? ??
            data['history'] as List<dynamic>?;
        return {
          'subscription': subMap != null
              ? UserSubscription.fromJson(subMap)
              : UserSubscription.free(userId: userId),
          'history': historyRaw != null
              ? historyRaw
                    .map(
                      (e) => PaymentRecord.fromJson(e as Map<String, dynamic>),
                    )
                    .toList()
              : <PaymentRecord>[],
        };
      } catch (e) {
        debugPrint(
          '[SubscriptionRepository] Supabase fetchMySubscription error: $e',
        );
        rethrow;
      }
    }
    final response = await _client
        .get(
          Uri.parse('$baseUrl/api/v1/payments/my-subscription'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception(
        'Could not load subscription (HTTP ${response.statusCode}).',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final subJson = data['subscription'] as Map<String, dynamic>?;
    final historyRaw = data['history'] as List<dynamic>?;

    return {
      'subscription': subJson != null
          ? UserSubscription.fromJson(subJson)
          : (throw Exception('The server returned no subscription record.')),
      'history': historyRaw != null
          ? historyRaw
                .map((e) => PaymentRecord.fromJson(e as Map<String, dynamic>))
                .toList()
          : <PaymentRecord>[],
    };
  }

  // ==========================================
  // ADMINISTRATIVE REPOSITORY METHODS
  // ==========================================

  /// Fetch Admin aggregated subscription statistics & active users
  Future<Map<String, dynamic>> fetchAdminSubscriptionsStats([
    String? token,
  ]) async {
    if (await _isDemoSession(token)) {
      final successPayments =
          _demoPayments.where((p) => p.status.toUpperCase() == 'SUCCESS');
      final pendingPayments =
          _demoPayments.where((p) => p.isPendingApproval);
      final totalRev = successPayments.fold<double>(
        4050.0,
        (sum, p) => sum + p.amount,
      );
      return {
        'stats': {
          'totalRevenue': totalRev,
          'successfulTransactionsCount': successPayments.length + 12,
          'pendingApprovalsCount': pendingPayments.length,
          'activePremiumUsersCount': 14,
        },
      };
    }
    if (_useSupabase) {
      final raw = await AdoptMatchBackend.instance.adminStats();
      if (raw['stats'] is Map) return raw;
      return {
        'stats': {
          'totalRevenue': (raw['revenue_bdt'] as num?)?.toDouble() ?? 0.0,
          'successfulTransactionsCount':
              (raw['successful_transactions'] as num?)?.toInt() ?? 0,
          'pendingApprovalsCount':
              (raw['unverified_payments'] as num?)?.toInt() ?? 0,
          'activePremiumUsersCount':
              (raw['active_premium_users'] as num?)?.toInt() ?? 0,
        },
      };
    }
    final headers = await _authHeaders(json: true);
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    final response = await _client
        .get(Uri.parse('$baseUrl/api/v1/admin/subscriptions'), headers: headers)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception(
        'Could not load subscription statistics (HTTP ${response.statusCode}).',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Fetch all payments for Admin review (filter by status or search)
  Future<List<PaymentRecord>> fetchAdminPayments({
    String? status,
    String? search,
    String? token,
  }) async {
    if (await _isDemoSession(token)) {
      return _demoPayments.where((p) {
        if (status != null &&
            status != 'ALL' &&
            p.status.toUpperCase() != status.toUpperCase()) {
          return false;
        }
        if (search != null && search.trim().isNotEmpty) {
          final q = search.trim().toLowerCase();
          return p.tranId.toLowerCase().contains(q) ||
              (p.trxId?.toLowerCase().contains(q) ?? false) ||
              p.userEmail.toLowerCase().contains(q) ||
              p.userName.toLowerCase().contains(q);
        }
        return true;
      }).toList();
    }
    if (_useSupabase) {
      try {
        var query = Supabase.instance.client
            .from('payments')
            .select(
              '*, user:profiles!payments_user_id_fkey(id, full_name, email), plan:subscription_plans(id, name)',
            );
        if (status != null && status != 'ALL') {
          query = query.eq('status', status.toLowerCase());
        }
        final rows = await query.order('created_at', ascending: false);
        return (rows as List)
            .map((e) => PaymentRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (postgrestErr) {
        debugPrint(
          '[SubscriptionRepository] PostgREST payments query error: $postgrestErr. Attempting flat query fallback.',
        );
        try {
          var fallbackQuery = Supabase.instance.client
              .from('payments')
              .select('*');
          if (status != null && status != 'ALL') {
            fallbackQuery = fallbackQuery.eq('status', status.toLowerCase());
          }
          final fallbackRows = await fallbackQuery.order(
            'created_at',
            ascending: false,
          );
          return (fallbackRows as List)
              .map((e) => PaymentRecord.fromJson(e as Map<String, dynamic>))
              .toList();
        } catch (flatErr) {
          debugPrint(
            '[SubscriptionRepository] Flat payments query failed: $flatErr',
          );
        }
      }
    }
    try {
      final queryParams = <String, String>{};
      if (status != null && status != 'ALL') queryParams['status'] = status;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final uri = Uri.parse('$baseUrl/api/v1/admin/payments')
          .replace(queryParameters: queryParams);
      final headers = await _authHeaders();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      final response = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception(
          'Could not load payments (HTTP ${response.statusCode}).',
        );
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rawList = data['data'] as List<dynamic>?;
      if (rawList == null) {
        throw Exception('The payment ledger response was invalid.');
      }
      return rawList
          .map((e) => PaymentRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[SubscriptionRepository] fetchAdminPayments error: $e');
      rethrow;
    }
  }

  /// Admin approves a pending manual bKash payment
  Future<bool> approveManualPayment(String tranId, [String? token]) async {
    if (await _isDemoSession(token)) {
      final idx = _demoPayments.indexWhere((p) => p.tranId == tranId);
      if (idx == -1) return false;
      final item = _demoPayments[idx];
      _demoPayments[idx] = PaymentRecord(
        tranId: item.tranId,
        userId: item.userId,
        userName: item.userName,
        userEmail: item.userEmail,
        planId: item.planId,
        planName: item.planName,
        amount: item.amount,
        currency: item.currency,
        status: 'SUCCESS',
        paymentMethod: item.paymentMethod,
        senderPhone: item.senderPhone,
        trxId: item.trxId,
        createdAt: item.createdAt,
      );
      return true;
    }
    if (_useSupabase) {
      try {
        await AdoptMatchBackend.instance.approvePayment(tranId);
        return true;
      } catch (e) {
        debugPrint(
          '[SubscriptionRepository] Supabase approveManualPayment error: $e',
        );
        return false;
      }
    }
    try {
      final effectiveToken =
          token ?? await SecureStorageService.instance.getAuthToken();
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/v1/admin/payments/$tranId/approve'),
            headers: {
              'Content-Type': 'application/json',
              if (effectiveToken != null)
                'Authorization': 'Bearer $effectiveToken',
            },
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[SubscriptionRepository] approveManualPayment error: $e');
      return false;
    }
  }

  /// Admin rejects a pending manual payment
  Future<bool> rejectManualPayment(
    String tranId,
    String reason, [
    String? token,
  ]) async {
    if (await _isDemoSession(token)) {
      final idx = _demoPayments.indexWhere((p) => p.tranId == tranId);
      if (idx == -1) return false;
      final item = _demoPayments[idx];
      _demoPayments[idx] = PaymentRecord(
        tranId: item.tranId,
        userId: item.userId,
        userName: item.userName,
        userEmail: item.userEmail,
        planId: item.planId,
        planName: item.planName,
        amount: item.amount,
        currency: item.currency,
        status: 'FAILED',
        paymentMethod: item.paymentMethod,
        senderPhone: item.senderPhone,
        trxId: item.trxId,
        adminNote: reason,
        createdAt: item.createdAt,
      );
      return true;
    }
    if (_useSupabase) {
      try {
        await AdoptMatchBackend.instance.rejectPayment(tranId, reason);
        return true;
      } catch (e) {
        debugPrint(
          '[SubscriptionRepository] Supabase rejectManualPayment error: $e',
        );
        return false;
      }
    }
    try {
      final effectiveToken =
          token ?? await SecureStorageService.instance.getAuthToken();
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/v1/admin/payments/$tranId/reject'),
            headers: {
              'Content-Type': 'application/json',
              if (effectiveToken != null)
                'Authorization': 'Bearer $effectiveToken',
            },
            body: jsonEncode({'reason': reason}),
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[SubscriptionRepository] rejectManualPayment error: $e');
      return false;
    }
  }

  /// Admin dynamically updates a subscription plan
  Future<SubscriptionPlan?> updatePlan(
    String planId,
    Map<String, dynamic> updates, [
    String? token,
  ]) async {
    if (await _isDemoSession(token)) {
      final idx = _demoPlans.indexWhere((p) => p.id == planId);
      if (idx == -1) return null;
      final existing = _demoPlans[idx];
      final updated = SubscriptionPlan(
        id: existing.id,
        name: existing.name,
        nameBn: existing.nameBn,
        price: (updates['price'] as num?)?.toDouble() ?? existing.price,
        currency: existing.currency,
        durationDays:
            (updates['durationDays'] as num?)?.toInt() ?? existing.durationDays,
        tag: existing.tag,
        isBestValue: existing.isBestValue,
        isActive: existing.isActive,
        features: existing.features,
        featuresBn: existing.featuresBn,
      );
      _demoPlans[idx] = updated;
      _cachedPlans = List<SubscriptionPlan>.from(_demoPlans);
      return updated;
    }
    if (_useSupabase) {
      try {
        await Supabase.instance.client
            .from('subscription_plans')
            .update(updates)
            .eq('id', planId);
        final row = await Supabase.instance.client
            .from('subscription_plans')
            .select()
            .eq('id', planId)
            .single();
        final updated = SubscriptionPlan.fromJson(row);
        final idx = _cachedPlans.indexWhere((p) => p.id == planId);
        if (idx != -1) _cachedPlans[idx] = updated;
        return updated;
      } catch (e) {
        debugPrint('[SubscriptionRepository] updatePlan error: $e');
        return null;
      }
    }
    try {
      final response = await _client
          .put(
            Uri.parse('$baseUrl/api/v1/admin/plans/$planId'),
            headers: {
              ...await _authHeaders(json: true),
              if (token != null && token.isNotEmpty)
                'Authorization': 'Bearer $token',
            },
            body: jsonEncode(updates),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final updated = SubscriptionPlan.fromJson(
          data['plan'] as Map<String, dynamic>,
        );
        final idx = _cachedPlans.indexWhere((p) => p.id == planId);
        if (idx != -1) _cachedPlans[idx] = updated;
        return updated;
      }
    } catch (e) {
      debugPrint('[SubscriptionRepository] updatePlan error: $e');
    }
    return null;
  }
}
