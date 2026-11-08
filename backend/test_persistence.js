process.env.NODE_ENV = 'test';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'adoptmatch-db-'));
process.env.DATABASE_PATH = path.join(dir, 'test.sqlite');
const { db } = require('./models/database');
const users = require('./models/userStore');
const payments = require('./models/paymentStore');
const plans = require('./models/planStore');
const { revokeUserTokens, isUserRevoked } = require('./middleware/rbacMiddleware');
let passed = 0;
try {
  const user = users.createUser({ id: 'durable-user', email: 'durable@example.test', name: 'Durable' });
  const plan = plans.getPlanById('plan-monthly');
  const payment = payments.createPayment({ tranId: 'durable-payment', userId: user.id, planId: plan.id,
    amount: 10, durationDays: 30, status: 'PENDING_APPROVAL', paymentMethod: 'bKash (Manual)', trxId: 'DURABLETRX' });
  const results = [payments.approveManualPayment(payment.tranId, 'test'), payments.approveManualPayment(payment.tranId, 'test')];
  assert.equal(results[0].alreadySuccess, false);
  assert.equal(results[1].alreadySuccess, true);
  assert.equal(db.prepare('SELECT COUNT(*) AS n FROM subscription_grants WHERE tran_id=?').get(payment.tranId).n, 1);
  assert.equal(users.getUserSubscription(user.id).remainingDays, 30);
  console.log('  ok  repeated settlement grants exactly one subscription'); passed++;

  payments.createPayment({ tranId: 'ghost-payment', userId: 'missing-account', planId: plan.id,
    amount: 10, durationDays: 30, status: 'PENDING_APPROVAL', paymentMethod: 'bKash (Manual)', trxId: 'GHOSTTRX' });
  assert.throws(() => payments.approveManualPayment('ghost-payment', 'test'), /missing account/);
  assert.equal(payments.getPaymentByTranId('ghost-payment').status, 'PENDING_APPROVAL');
  console.log('  ok  failed entitlement grant rolls back payment settlement'); passed++;

  assert.throws(() => plans.updatePlan(plan.id, { price: -1 }));
  assert.throws(() => plans.updatePlan(plan.id, { durationDays: 0 }));
  assert.throws(() => plans.updatePlan(plan.id, { features: 'not-an-array' }));
  assert.throws(() => plans.updatePlan(plan.id, { unexpectedField: true }));
  assert.throws(() => payments.createPayment({ tranId: 'duplicate-trx', userId: user.id, planId: plan.id,
    amount: 10, durationDays: 30, status: 'PENDING_APPROVAL', paymentMethod: 'bKash (Manual)', trxId: 'DURABLETRX' }), /UNIQUE constraint/);
  const rejected = payments.createPayment({ tranId: 'rejected-trx', userId: user.id, planId: plan.id,
    amount: 10, durationDays: 30, status: 'PENDING_APPROVAL', paymentMethod: 'bKash (Manual)', trxId: 'REJECTEDTRX' });
  payments.rejectManualPayment(rejected.tranId, 'test rejection', 'test');
  assert.throws(() => payments.createPayment({ tranId: 'reuse-rejected-trx', userId: user.id, planId: plan.id,
    amount: 10, durationDays: 30, status: 'PENDING_APPROVAL', paymentMethod: 'bKash (Manual)', trxId: 'REJECTEDTRX' }), /UNIQUE constraint/);
  assert.equal(payments.hasManualTrx('DURABLETRX'), true);
  console.log('  ok  invalid plan edits and duplicate/reused manual TrxIDs rejected'); passed++;

  revokeUserTokens(user.id);
  const child = spawnSync(process.execPath, ['-e', `
    const assert=require('node:assert/strict');
    const u=require('./models/userStore'); const p=require('./models/paymentStore');
    const r=require('./middleware/rbacMiddleware');
    assert.equal(u.findById('durable-user').isPremium,true);
    assert.equal(p.getPaymentByTranId('durable-payment').status,'SUCCESS');
    assert.equal(r.isUserRevoked('durable-user',Math.floor(Date.now()/1000)-10),true);
  `], { cwd: __dirname, env: { ...process.env }, encoding: 'utf8' });
  assert.equal(child.status, 0, child.stderr);
  console.log('  ok  users, ledger and revocations survive a fresh process'); passed++;

  const bootstrapDir = fs.mkdtempSync(path.join(os.tmpdir(), 'adoptmatch-bootstrap-'));
  try {
    const bootstrapEnv = { ...process.env, DATABASE_PATH: path.join(bootstrapDir, 'admin.sqlite'), NODE_ENV: 'test' };
    const args = ['scripts/bootstrap-admin.js', '--email', 'root@example.test', '--google-sub', '123456789012345'];
    const created = spawnSync(process.execPath, args, { cwd: __dirname, env: bootstrapEnv, encoding: 'utf8' });
    assert.equal(created.status, 0, created.stderr);
    const repeated = spawnSync(process.execPath, args, { cwd: __dirname, env: bootstrapEnv, encoding: 'utf8' });
    assert.equal(repeated.status, 1, 'bootstrap must not silently promote or duplicate an account');
    const verified = spawnSync(process.execPath, ['-e', `const assert=require('node:assert/strict');
      const u=require('./models/userStore').findByEmail('root@example.test');
      assert.equal(u.role,'SUPER_ADMIN'); assert.equal(u.googleId,'123456789012345');`],
      { cwd: __dirname, env: bootstrapEnv, encoding: 'utf8' });
    assert.equal(verified.status, 0, verified.stderr);
    console.log('  ok  admin bootstrap creates a durable Google-bound account once'); passed++;
  } finally { fs.rmSync(bootstrapDir, { recursive: true, force: true }); }

  for (const [module, envPatch, label] of [
    ['./models/database', { NODE_ENV: 'production', DATABASE_PATH: '' }, 'production requires durable DATABASE_PATH'],
    ['./middleware/rbacMiddleware', { NODE_ENV: 'production', JWT_SECRET: 'short' }, 'production rejects short JWT secret'],
  ]) {
    const env = { ...process.env, ...envPatch };
    const child = spawnSync(process.execPath, ['-e', `require('${module}')`], { cwd: __dirname, env, encoding: 'utf8' });
    assert.notEqual(child.status, 0, `${label} must fail closed`);
  }
  console.log('  ok  production persistence and JWT configuration fail closed'); passed++;
  console.log(`All ${passed} persistence/concurrency tests passed.`);
} finally {
  db.close();
  fs.rmSync(dir, { recursive: true, force: true });
}
