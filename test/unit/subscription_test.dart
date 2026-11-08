import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../helpers/secure_storage_mock.dart';
import 'package:adoptmatch/core/models/subscription_plan_model.dart';
import 'package:adoptmatch/core/models/payment_record_model.dart';
import 'package:adoptmatch/core/repositories/subscription_repository.dart';
import 'package:adoptmatch/features/auth/bloc/auth_bloc.dart';

void main() {
  group('Subscription Models & Logic Tests', () {
    test('SubscriptionPlan contains 3 default BDT plans with correct pricing', () {
      final plans = SubscriptionPlan.defaultPlans;
      expect(plans.length, 3);

      final p1 = plans[0];
      expect(p1.id, 'plan-monthly');
      expect(p1.price, 90.0);
      expect(p1.formattedPrice, '৳90');
      expect(p1.durationDays, 30);
      expect(p1.durationString, '1 Month');

      final p2 = plans[1];
      expect(p2.id, 'plan-quarterly');
      expect(p2.price, 200.0);
      expect(p2.formattedPrice, '৳200');
      expect(p2.isBestValue, true);
      expect(p2.durationDays, 90);
      expect(p2.durationString, '3 Months');

      final p3 = plans[2];
      expect(p3.id, 'plan-annual');
      expect(p3.price, 499.0);
      expect(p3.formattedPrice, '৳499');
      expect(p3.durationDays, 365);
      expect(p3.durationString, '1 Year');
    });

    test('PaymentRecord correctly reflects status and amounts', () {
      final payment = PaymentRecord(
        tranId: 'AM-SUB-TEST-1',
        userId: 'u-101',
        userName: 'Elias Ahmed',
        userEmail: 'elias3224@gmail.com',
        planId: 'plan-quarterly',
        planName: '3 Months Saver',
        amount: 200.0,
        currency: 'BDT',
        status: 'SUCCESS',
        paymentMethod: 'bKash via SSLCommerz',
        cardType: 'BKASH-bKash',
        createdAt: DateTime.now(),
      );

      expect(payment.isSuccess, true);
      expect(payment.isPendingApproval, false);
      expect(payment.formattedAmount, '৳200 BDT');
    });

    test('UserProfile subscription state calculations and badge titles', () {
      const freeUser = UserProfile(
        id: 'u-1',
        name: 'Free Adopter',
        email: 'free@adoptmatch.org',
        phone: '01700000000',
      );
      expect(freeUser.hasActivePremium, false);
      expect(freeUser.remainingDays, 0);

      // Active Premium User
      final futureExpiry = DateTime.now().add(const Duration(days: 45));
      final premiumUser = freeUser.copyWith(
        isPremium: true,
        premiumPlanId: 'plan-quarterly',
        premiumExpiresAt: futureExpiry,
        subscriptionStatus: 'ACTIVE',
      );

      expect(premiumUser.hasActivePremium, true);
      expect(premiumUser.remainingDays, inInclusiveRange(44, 45));
      expect(premiumUser.premiumBadgeTitle, 'Gold Supporter');

      // Expired Premium User
      final pastExpiry = DateTime.now().subtract(const Duration(days: 2));
      final expiredUser = premiumUser.copyWith(
        premiumExpiresAt: pastExpiry,
      );

      expect(expiredUser.hasActivePremium, false);
      expect(expiredUser.remainingDays, 0);
    });

    test('subscription repository fails closed without server configuration', () async {
      await installSecureStorageMock();
      final repo = SubscriptionRepository()..configureForTesting(MockClient((request) async {
        if (request.url.path.endsWith('/plans')) return http.Response('{}', 503);
        if (request.url.path.endsWith('/bkash-number')) return http.Response(jsonEncode({
          'success': false, 'configured': false}), 503);
        return http.Response(jsonEncode({'success': false, 'error': 'unauthorized'}), 401);
      }));
      await expectLater(repo.fetchPlans(), throwsException);
      await expectLater(repo.fetchBkashNumber(), throwsException);
      expect(repo.officialBkashNumber, isNull);
      final init = await repo.initiateSslCommerzPayment(planId: 'plan-monthly');
      expect(init['success'], false);
      expect(await repo.approveManualPayment('txn'), false);
    });

    test('manual payment and admin decisions require successful server responses', () async {
      await installSecureStorageMock();
      final repo = SubscriptionRepository()..configureForTesting(MockClient((request) async {
        if (request.url.path.endsWith('/manual-bkash')) {
          expect(request.headers['Authorization'], isNull); // no token installed in this test
          return http.Response(jsonEncode({'success': true, 'payment': {
            'tranId': 'AM-1', 'userId': 'u-1', 'userName': 'User', 'userEmail': 'u@example.test',
            'planId': 'plan-monthly', 'planName': 'Monthly', 'amount': 90, 'currency': 'BDT',
            'status': 'PENDING_APPROVAL', 'paymentMethod': 'bKash (Manual)',
            'createdAt': '2026-11-08T00:00:00Z'}}), 200);
        }
        if (request.url.path.endsWith('/approve')) return http.Response('{"success":true}', 200);
        if (request.url.path.endsWith('/reject')) return http.Response('{"success":false}', 409);
        return http.Response('{}', 404);
      }));
      final payment = await repo.submitManualBkashPayment(planId: 'plan-monthly',
        senderPhone: '01700000000', trxId: 'ABC123');
      expect(payment.isPendingApproval, true);
      expect(await repo.approveManualPayment('AM-1'), true);
      expect(await repo.rejectManualPayment('AM-1', 'duplicate'), false);
    });
  });
}
