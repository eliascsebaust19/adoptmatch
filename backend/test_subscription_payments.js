/**
 * AdoptMatch - Subscription & SSLCommerz/bKash Payment Verification Test
 */

process.env.ENABLE_PAYMENT_SIMULATOR = 'true';
process.env.NODE_ENV = 'test';
process.env.BKASH_OFFICIAL_NUMBER = '01700000000'; // test-only destination, never a real payment account

const assert = require('assert');
const jwt = require('jsonwebtoken');
const app = require('./server');
const { JWT_SECRET } = require('./middleware/rbacMiddleware');

const MEMBER_TOKEN = jwt.sign(
  { id: 'u-101', email: 'elias3224@gmail.com', role: 'USER', name: 'Elias Ahmed' },
  JWT_SECRET,
  { expiresIn: '1h' }
);

const SHELTER_TOKEN = jwt.sign(
  { id: 'u-102', email: 'info@careforpaws.bd', role: 'SHELTER', name: 'Care For Paws Staff' },
  JWT_SECRET,
  { expiresIn: '1h' }
);

const ADMIN_TOKEN = jwt.sign(
  { id: 'u-103', email: 'superadmin@adoptmatch.org', role: 'SUPER_ADMIN', name: 'Sarah Rahman' },
  JWT_SECRET,
  { expiresIn: '1h' }
);

async function runTests() {
  console.log('--- Starting AdoptMatch SSLCommerz & bKash Subscription Tests ---\n');

  const server = app.listen(0);
  const port = server.address().port;
  const baseUrl = `http://localhost:${port}`;

  try {
    // 1. Fetch Dynamic Plans
    console.log('[TEST 1] Fetching dynamic subscription plans...');
    const plansRes = await fetch(`${baseUrl}/api/v1/payments/plans`);
    assert.strictEqual(plansRes.status, 200);
    const plansData = await plansRes.json();
    assert.strictEqual(plansData.plans.length, 3);
    assert.strictEqual(plansData.plans[0].price, 90);
    assert.strictEqual(plansData.plans[1].price, 200);
    assert.strictEqual(plansData.plans[1].isBestValue, true);
    assert.strictEqual(plansData.plans[2].price, 499);
    console.log('✓ 3 Plans in BDT verified! (৳90, ৳200, ৳499)');

    // 2. Fetch Official bKash Number & Guide
    console.log('\n[TEST 2] Fetching official bKash support number...');
    const bkashRes = await fetch(`${baseUrl}/api/v1/payments/bkash-number`);
    assert.strictEqual(bkashRes.status, 200);
    const bkashData = await bkashRes.json();
    assert.ok(bkashData.bkashNumber);
    assert.ok(bkashData.instructionsBn.length > 0);
    console.log(`✓ Official bKash Number: ${bkashData.bkashNumber}`);

    // 3. Initiate SSLCommerz Payment Session
    console.log('\n[TEST 3] Initiating SSLCommerz Session for Plan 2 (৳200)...');
    const initRes = await fetch(`${baseUrl}/api/v1/payments/initiate-sslcommerz`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${MEMBER_TOKEN}` },
      body: JSON.stringify({
        planId: 'plan-quarterly',
        userId: 'u-101',
        userName: 'Elias Ahmed',
        userEmail: 'elias3224@gmail.com',
      }),
    });
    assert.strictEqual(initRes.status, 200);
    const initData = await initRes.json();
    assert.ok(initData.tranId);
    assert.ok(initData.gatewayUrl);
    assert.strictEqual(initData.amount, 200);
    console.log(`✓ Payment initiated! Tran ID: ${initData.tranId}, Gateway URL: ${initData.gatewayUrl}`);

    // 4. SSLCommerz Success Callback (Server-Side Validation & Idempotency)
    console.log('\n[TEST 4] Simulating SSLCommerz Success Callback with Server Validation...');
    const successRes = await fetch(`${baseUrl}/api/v1/payments/sslcommerz-success`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        tran_id: initData.tranId,
        val_id: `SIMULATED-VAL-${Date.now()}`,
        amount: '200.00',
        card_type: 'BKASH-bKash',
        bank_tran_id: 'BT-BKASH-771199',
      }).toString(),
    });
    assert.strictEqual(successRes.status, 200);
    const successHtml = await successRes.text();
    assert.ok(successHtml.includes('Payment Successful'));
    console.log('✓ SSLCommerz Success callback validated and handled!');

    // 5. Verify User Subscription Activated
    console.log('\n[TEST 5] Checking User Subscription Status (GET /api/v1/payments/my-subscription)...');
    const subRes = await fetch(`${baseUrl}/api/v1/payments/my-subscription`, {
      headers: { Authorization: `Bearer ${MEMBER_TOKEN}` },
    });
    assert.strictEqual(subRes.status, 200);
    const subData = await subRes.json();
    assert.strictEqual(subData.subscription.isPremium, true);
    assert.strictEqual(subData.subscription.premiumPlanId, 'plan-quarterly');
    assert.ok(subData.subscription.remainingDays >= 89);
    console.log(`✓ Premium Active! Plan: ${subData.subscription.premiumPlanId}, Days Remaining: ${subData.subscription.remainingDays}`);

    // 6. Manual bKash Payment Submission (Pending Approval)
    console.log('\n[TEST 6] Testing Manual bKash Submission (TrxID + Sender Number)...');
    const manualRes = await fetch(`${baseUrl}/api/v1/payments/manual-bkash`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${SHELTER_TOKEN}` },
      body: JSON.stringify({
        planId: 'plan-annual',
        userId: 'u-102',
        userName: 'Care For Paws Staff',
        userEmail: 'info@careforpaws.bd',
        senderPhone: '01712345678',
        trxId: '9K8J7H6G5F',
      }),
    });
    assert.strictEqual(manualRes.status, 200);
    const manualData = await manualRes.json();
    assert.strictEqual(manualData.payment.status, 'PENDING_APPROVAL');
    assert.strictEqual(manualData.payment.amount, 499);
    console.log(`✓ Manual bKash submitted! Status: ${manualData.payment.status}, TrxID: ${manualData.payment.trxId}`);
    const duplicateRes = await fetch(`${baseUrl}/api/v1/payments/manual-bkash`, {
      method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${MEMBER_TOKEN}` },
      body: JSON.stringify({ planId: 'plan-monthly', senderPhone: '01712345678', trxId: '9k8j7h6g5f' }),
    });
    assert.strictEqual(duplicateRes.status, 409, 'normalized TrxID must be unique across accounts');
    console.log('✓ Duplicate manual TrxID rejected across accounts');

    // 7. Admin Approves Manual bKash Payment
    console.log('\n[TEST 7] Admin Approves Manual bKash Payment...');
    const approveRes = await fetch(`${baseUrl}/api/v1/admin/payments/${manualData.payment.tranId}/approve`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${ADMIN_TOKEN}`,
      },
      body: JSON.stringify({}),
    });
    assert.strictEqual(approveRes.status, 200);
    const approveData = await approveRes.json();
    assert.strictEqual(approveData.payment.status, 'SUCCESS');
    assert.strictEqual(approveData.user.isPremium, true);
    console.log(`✓ Admin Approval Verified! User "${approveData.user.name}" is now VIP Rescuer for 365 days!`);

    // 8. Admin Dynamically Updates Plan Pricing / Duration
    console.log('\n[TEST 8] Admin Modifies Plan (PUT /api/v1/admin/plans/plan-monthly)...');
    const updatePlanRes = await fetch(`${baseUrl}/api/v1/admin/plans/plan-monthly`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${ADMIN_TOKEN}`,
      },
      body: JSON.stringify({
        price: 95,
        tag: 'Promo Special',
      }),
    });
    assert.strictEqual(updatePlanRes.status, 200);
    const updatePlanData = await updatePlanRes.json();
    assert.strictEqual(updatePlanData.plan.price, 95);
    assert.strictEqual(updatePlanData.plan.tag, 'Promo Special');
    console.log(`✓ Dynamic Plan Editing Verified! New price: ৳${updatePlanData.plan.price}`);

    // 9. Admin Subscriptions Stats
    console.log('\n[TEST 9] Fetching Admin Subscriptions Stats...');
    const statsRes = await fetch(`${baseUrl}/api/v1/admin/subscriptions`, {
      headers: { Authorization: `Bearer ${ADMIN_TOKEN}` },
    });
    assert.strictEqual(statsRes.status, 200);
    const statsData = await statsRes.json();
    assert.ok(statsData.stats.totalRevenue > 0);
    assert.ok(statsData.stats.activePremiumUsersCount >= 2);
    console.log(`✓ Admin Stats Verified: Total Revenue ৳${statsData.stats.totalRevenue} BDT, Active Users: ${statsData.stats.activePremiumUsersCount}`);

    console.log('\n=======================================================');
    console.log(' ALL SSLCOMMERZ & BKASH SUBSCRIPTION TESTS PASSED! 🚀');
    console.log('=======================================================');
  } finally {
    server.close();
  }
}

runTests().catch((err) => {
  console.error('Test Failed:', err);
  process.exit(1);
});

