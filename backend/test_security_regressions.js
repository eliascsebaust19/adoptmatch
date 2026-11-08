/**
 * AdoptMatch - Security regression tests
 *
 * Covers the audit findings that were previously reproducible:
 * AM-01 test tokens, AM-02 Google identity, AM-03 payment validation,
 * AM-11 moderator authorization, AM-12 ban enforcement, AM-13 replay,
 * AM-14 upload authentication and validation.
 *
 * Run: node test_security_regressions.js
 * Exits non-zero when any assertion fails.
 */

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'security-regression-test-secret';
process.env.TEST_AUTH_SECRET = 'security-regression-test-auth-secret';
// Google verification needs a configured audience; the unconfigured 503 path is
// covered separately in test_google_auth.js.
process.env.GOOGLE_CLIENT_ID = 'test-web-client.apps.googleusercontent.com';
delete process.env.BLOB_READ_WRITE_TOKEN;
delete process.env.SUPABASE_URL;
delete process.env.SUPABASE_SERVICE_ROLE_KEY;
delete process.env.ENABLE_PAYMENT_SIMULATOR;
delete process.env.SSLCOMMERZ_IS_LIVE;
delete process.env.BKASH_OFFICIAL_NUMBER;

const assert = require('assert');
const jwt = require('jsonwebtoken');
const app = require('./server');

// Purge live/dev credentials loaded by server's dotenv to guarantee fail-closed assertions
delete process.env.BLOB_READ_WRITE_TOKEN;
delete process.env.SUPABASE_URL;
delete process.env.SUPABASE_SERVICE_ROLE_KEY;
delete process.env.ENABLE_PAYMENT_SIMULATOR;
delete process.env.SSLCOMMERZ_IS_LIVE;
delete process.env.BKASH_OFFICIAL_NUMBER;

const { JWT_SECRET } = require('./middleware/rbacMiddleware');
const userStore = require('./models/userStore');
const paymentStore = require('./models/paymentStore');
const planStore = require('./models/planStore');

const signToken = (id, role) => {
  const account = userStore.findById(id);
  return jwt.sign(
    { id, email: account.email, role, name: account.name },
    JWT_SECRET,
    { expiresIn: '1h' }
  );
};

const GIF_BASE64 = 'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';

let passed = 0;
const originalFetch = global.fetch;

async function run() {
  const server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;

  const request = async (path, { method = 'GET', body, token } = {}) => {
    const res = await fetch(base + path, {
      method,
      redirect: 'manual',
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      ...(body ? { body: JSON.stringify(body) } : {}),
    });
    const text = await res.text();
    let data;
    try {
      data = JSON.parse(text);
    } catch {
      data = text;
    }
    return { status: res.status, data };
  };

  const superAdmin = signToken('u-103', 'SUPER_ADMIN');
  const moderator = signToken('u-105', 'MODERATOR');
  const member = signToken('u-101', 'USER');

  try {
    console.log('AM-01 test token endpoint');
    let res = await request('/api/v1/auth/token', { method: 'POST', body: { role: 'SUPER_ADMIN' } });
    assert.strictEqual(res.status, 403);
    res = await request('/api/v1/auth/token', { method: 'POST', body: { role: 'USER' } });
    assert.strictEqual(res.status, 403, 'non-privileged roles must also require the secret');
    res = await request('/api/v1/auth/token', {
      method: 'POST',
      body: { role: 'USER', testSecret: process.env.TEST_AUTH_SECRET },
    });
    assert.strictEqual(res.status, 200);
    console.log('  ok  no secret -> 403 for every role; valid secret -> 200');
    passed += 2;

    const ghost = jwt.sign({ id: 'deleted-account', email: 'superadmin@adoptmatch.org', role: 'SUPER_ADMIN' }, JWT_SECRET);
    res = await request('/api/v1/auth/me', { token: ghost });
    assert.strictEqual(res.status, 401, 'JWT claims cannot impersonate a missing account');
    res = await request('/api/v1/auth/logout', { method: 'POST', body: {} });
    assert.strictEqual(res.status, 401, 'logout cannot blacklist an unauthenticated token');
    res = await request('/api/v1/payments/bkash-number');
    assert.strictEqual(res.status, 503, 'unconfigured payment destination fails closed');
    console.log('  ok  missing accounts, anonymous logout and unconfigured destination fail closed');
    passed += 3;

    console.log('AM-02 Google identity');
    res = await request('/api/v1/auth/google', {
      method: 'POST',
      body: { profile: { id: 'attacker', email: 'superadmin@adoptmatch.org' } },
    });
    assert.strictEqual(res.status, 400);
    res = await request('/api/v1/auth/google', { method: 'POST', body: { idToken: 'not-a-google-token' } });
    assert.strictEqual(res.status, 401);
    console.log('  ok  profile-only and unverified tokens rejected');
    passed += 2;

    console.log('AM-03 payment validation and ownership');
    res = await request('/api/v1/payments/initiate-sslcommerz', { method: 'POST', body: { planId: 'plan-monthly' } });
    assert.strictEqual(res.status, 401, 'checkout requires authentication');
    console.log('  ok  anonymous checkout rejected');
    passed += 1;

    const pending = paymentStore.createPayment({
      tranId: 'REGRESSION-CROSS-TRAN',
      userId: 'u-101',
      planId: 'plan-monthly',
      amount: 90,
      currency: 'BDT',
      durationDays: 30,
      status: 'PENDING',
    });

    const mockGateway = (payload) => {
      global.fetch = async (url, options) => {
        if (String(url).includes('validationserverAPI.php')) {
          return { json: async () => payload };
        }
        return originalFetch(url, options);
      };
    };

    const validGateway = {
      status: 'VALID',
      tran_id: pending.tranId,
      store_id: process.env.SSLCOMMERZ_STORE_ID || 'adoptmatch_sandbox',
      amount: '90.00',
      currency: 'BDT',
      bank_tran_id: 'BT-REGRESSION',
      card_type: 'BKASH-bKash',
    };

    mockGateway({ ...validGateway, tran_id: 'SOME-OTHER-TRANSACTION' });
    res = await request('/api/v1/payments/sslcommerz-ipn', {
      method: 'POST',
      body: { tran_id: pending.tranId, val_id: 'VAL-MISMATCH', status: 'VALID' },
    });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(paymentStore.getPaymentByTranId(pending.tranId).status, 'PENDING');
    console.log('  ok  gateway transaction mismatch rejected');
    passed += 1;

    mockGateway({ ...validGateway, amount: '1.00' });
    res = await request('/api/v1/payments/sslcommerz-ipn', {
      method: 'POST',
      body: { tran_id: pending.tranId, val_id: 'VAL-AMOUNT', status: 'VALID' },
    });
    assert.strictEqual(res.status, 400);
    console.log('  ok  gateway amount mismatch rejected');
    passed += 1;

    mockGateway({ ...validGateway, store_id: 'another-merchant' });
    res = await request('/api/v1/payments/sslcommerz-ipn', {
      method: 'POST', body: { tran_id: pending.tranId, val_id: 'VAL-STORE', status: 'VALID' },
    });
    assert.strictEqual(res.status, 400);
    console.log('  ok  gateway store mismatch rejected');
    passed += 1;

    mockGateway({ ...validGateway, currency: 'USD' });
    res = await request('/api/v1/payments/sslcommerz-ipn', {
      method: 'POST',
      body: { tran_id: pending.tranId, val_id: 'VAL-CURRENCY', status: 'VALID' },
    });
    assert.strictEqual(res.status, 400);
    console.log('  ok  IPN currency mismatch rejected');
    passed += 1;

    const { currency, ...withoutCurrency } = validGateway;
    mockGateway(withoutCurrency);
    res = await request('/api/v1/payments/sslcommerz-ipn', {
      method: 'POST',
      body: { tran_id: pending.tranId, val_id: 'VAL-PARTIAL', status: 'VALID' },
    });
    assert.strictEqual(res.status, 400);
    console.log('  ok  incomplete gateway response rejected');
    passed += 1;

    res = await request('/api/v1/payments/sslcommerz-ipn', {
      method: 'POST',
      body: { tran_id: pending.tranId, val_id: 'SIMULATED-VAL-1', status: 'VALID' },
    });
    assert.strictEqual(res.status, 400);
    console.log('  ok  simulator disabled unless explicitly enabled');
    passed += 1;

    mockGateway(validGateway);
    res = await request('/api/v1/payments/sslcommerz-ipn', {
      method: 'POST',
      body: { tran_id: pending.tranId, val_id: 'VAL-GOOD', status: 'VALID' },
    });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(userStore.getUserSubscription('u-101').isPremium, true);
    console.log('  ok  fully matching gateway response activates the subscription');
    passed += 1;

    console.log('AM-13 replay and purchased terms');
    const daysAfterActivation = userStore.getUserSubscription('u-101').remainingDays;
    await request('/api/v1/payments/sslcommerz-cancel', { method: 'POST', body: { tran_id: pending.tranId } });
    assert.strictEqual(paymentStore.getPaymentByTranId(pending.tranId).status, 'SUCCESS');
    await request('/api/v1/payments/sslcommerz-ipn', {
      method: 'POST',
      body: { tran_id: pending.tranId, val_id: 'VAL-GOOD', status: 'VALID' },
    });
    assert.strictEqual(userStore.getUserSubscription('u-101').remainingDays, daysAfterActivation);
    console.log('  ok  settled payment cannot be cancelled or replayed for extra days');
    passed += 1;

    const snapshot = paymentStore.createPayment({
      tranId: 'REGRESSION-SNAPSHOT',
      userId: 'u-102',
      planId: 'plan-monthly',
      amount: 90,
      currency: 'BDT',
      durationDays: 30,
      status: 'PENDING_APPROVAL',
      paymentMethod: 'bKash (Manual)',
      trxId: 'REGRESSION-TRX',
    });
    planStore.updatePlan('plan-monthly', { durationDays: 999 });
    res = await request(`/api/v1/admin/payments/${snapshot.tranId}/approve`, { method: 'POST', body: {}, token: superAdmin });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(userStore.getUserSubscription('u-102').remainingDays, 30);
    planStore.updatePlan('plan-monthly', { durationDays: 30 });
    console.log('  ok  manual approval grants the purchased duration, not the edited plan');
    passed += 1;

    console.log('AM-11 moderator authorization');
    res = await request('/api/v1/admin/users/u-101/permissions', {
      method: 'PATCH',
      body: { permissions: ['MANAGE_USERS', 'AUDIT_LOGS'] },
      token: moderator,
    });
    assert.strictEqual(res.status, 403);
    res = await request('/api/v1/admin/users/u-101/role', { method: 'PATCH', body: { role: 'ADMIN' }, token: moderator });
    assert.strictEqual(res.status, 403);
    const modPayment = paymentStore.createPayment({
      tranId: 'REGRESSION-MOD-PAY',
      userId: 'u-101',
      planId: 'plan-monthly',
      amount: 90,
      durationDays: 30,
      status: 'PENDING_APPROVAL',
      paymentMethod: 'bKash (Manual)',
      trxId: 'REGRESSION-MOD',
    });
    res = await request(`/api/v1/admin/payments/${modPayment.tranId}/reject`, { method: 'POST', body: {}, token: moderator });
    assert.strictEqual(res.status, 403);
    res = await request(`/api/v1/admin/payments/${modPayment.tranId}/approve`, { method: 'POST', body: {}, token: moderator });
    assert.strictEqual(res.status, 403);
    res = await request('/api/v1/admin/payments', { token: moderator });
    assert.strictEqual(res.status, 403);
    console.log('  ok  moderator denied permission edits, role edits and all payment operations');
    passed += 5;

    console.log('AM-12 ban enforcement');
    res = await request('/api/v1/admin/users/u-104/unblock', { method: 'PATCH', body: {}, token: superAdmin });
    assert.strictEqual(res.status, 200);
    const revived = signToken('u-104', 'USER');
    res = await request('/api/v1/auth/me', { token: revived });
    assert.strictEqual(res.status, 200);
    res = await request('/api/v1/admin/users/u-104/block', { method: 'PATCH', body: { reason: 'regression' }, token: superAdmin });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(String(userStore.findById('u-104').status).toUpperCase(), 'BANNED');
    await new Promise((resolve) => setTimeout(resolve, 1100));
    const afterBan = signToken('u-104', 'USER');
    res = await request('/api/v1/auth/me', { token: afterBan });
    assert.strictEqual(res.status, 403);
    res = await request('/api/v1/payments/my-subscription', { token: afterBan });
    assert.strictEqual(res.status, 403);
    console.log('  ok  ban updates the shared store and blocks freshly issued tokens');
    passed += 1;

    console.log('Payment privacy');
    res = await request('/api/v1/payments/my-subscription?userId=u-102');
    assert.strictEqual(res.status, 401);
    res = await request('/api/v1/payments/my-subscription?userId=u-102', { token: member });
    assert.strictEqual(res.status, 403);
    res = await request('/api/v1/payments/verify/REGRESSION-SNAPSHOT', { token: member });
    assert.strictEqual(res.status, 403, 'u-101 must not read a transaction owned by u-102');
    res = await request('/api/v1/payments/verify/REGRESSION-MOD-PAY', { token: member });
    assert.strictEqual(res.status, 200, 'the owner may read their own transaction');
    console.log('  ok  subscription history and transaction lookups are owner/staff only');
    passed += 3;

    console.log('AM-14 upload authentication and validation');
    res = await request('/api/v1/storage/upload', { method: 'POST', body: { base64Data: GIF_BASE64, contentType: 'image/gif' } });
    assert.strictEqual(res.status, 401);
    res = await request('/api/v1/storage/upload', {
      method: 'POST',
      body: { base64Data: GIF_BASE64, contentType: 'text/html' },
      token: member,
    });
    assert.strictEqual(res.status, 415);
    res = await request('/api/v1/storage/upload', {
      method: 'POST',
      body: { base64Data: Buffer.from('<script>alert(1)</script>').toString('base64'), contentType: 'image/png' },
      token: member,
    });
    assert.strictEqual(res.status, 415);
    res = await request('/api/v1/storage/upload', {
      method: 'POST',
      body: { base64Data: GIF_BASE64, contentType: 'image/gif' },
      token: member,
    });
    assert.strictEqual(res.status, 503, 'no storage configured must fail closed, never fabricate a URL');
    assert.strictEqual(res.data.success, false);
    console.log('  ok  anonymous, mis-typed and unconfigured uploads all rejected');
    passed += 4;

    console.log(`\nAll ${passed} security regression checks passed.`);
  } finally {
    global.fetch = originalFetch;
    await new Promise((resolve) => server.close(resolve));
  }
}

run().catch((err) => {
  console.error('\nSecurity regression failure:', err);
  process.exit(1);
});
