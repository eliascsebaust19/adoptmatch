/**
 * AdoptMatch - Payments & Subscriptions Record Store
 * Secure server-side ledger with idempotency checks and manual bKash approval workflows.
 */

const demoPayments = [
  {
    tranId: 'AM-SUB-INIT-101',
    userId: 'u-101',
    userName: 'Elias Ahmed',
    userEmail: 'elias3224@gmail.com',
    planId: 'plan-quarterly',
    planName: '3 Months Saver',
    amount: 200,
    currency: 'BDT',
    status: 'SUCCESS',
    paymentMethod: 'bKash via SSLCommerz',
    valId: 'VAL-TEST-9021',
    bankTranId: 'BT-BKASH-8812',
    cardType: 'BKASH-bKash',
    senderPhone: '+880 1711 234567',
    trxId: 'BK902198',
    createdAt: '2026-10-25T14:30:00.000Z',
    verifiedAt: '2026-10-25T14:31:05.000Z',
  },
  {
    tranId: 'AM-SUB-INIT-102',
    userId: 'u-102',
    userName: 'Care For Paws Staff',
    userEmail: 'info@careforpaws.bd',
    planId: 'plan-annual',
    planName: '1 Year VIP Rescuer',
    amount: 499,
    currency: 'BDT',
    status: 'SUCCESS',
    paymentMethod: 'bKash (Manual)',
    valId: null,
    bankTranId: null,
    cardType: 'bKash Manual Transfer',
    senderPhone: '+880 1712 345678',
    trxId: '9G7A2K1092',
    createdAt: '2026-10-20T10:15:00.000Z',
    verifiedAt: '2026-10-20T10:45:00.000Z',
    approvedBy: 'superadmin@adoptmatch.org',
  },
  {
    tranId: 'AM-SUB-INIT-103',
    userId: 'u-104',
    userName: 'Suspicious Lister 99',
    userEmail: 'petshopdhaka@fake.com',
    planId: 'plan-monthly',
    planName: '1 Month Supporter',
    amount: 90,
    currency: 'BDT',
    status: 'FAILED',
    paymentMethod: 'SSLCommerz',
    valId: null,
    bankTranId: null,
    cardType: 'VISA',
    senderPhone: null,
    trxId: null,
    createdAt: '2026-10-18T09:00:00.000Z',
    verifiedAt: null,
  }
];

const store = require('./recordStore')('payments', process.env.NODE_ENV === 'production' ? [] : demoPayments);
const { db, transaction } = require('./database');
// A rejected TrxID is still consumed: database uniqueness closes the race left by hasManualTrx().
db.exec(`CREATE UNIQUE INDEX IF NOT EXISTS idx_manual_bkash_trx
  ON records(json_extract(data, '$.trxId'))
  WHERE namespace = 'payments'
    AND json_extract(data, '$.paymentMethod') = 'bKash (Manual)'
    AND json_extract(data, '$.trxId') IS NOT NULL`);
const userStore = require('./userStore');
const TERMINAL = new Set(['SUCCESS', 'FAILED', 'CANCELLED', 'REJECTED']);
const createPayment = (data) => {
  if (store.find(data.tranId)) throw new Error('Transaction id already exists.');
  if (!Number.isFinite(Number(data.amount)) || Number(data.amount) <= 0 ||
      !Number.isInteger(data.durationDays) || data.durationDays < 1 || (data.currency || 'BDT') !== 'BDT') {
    throw new Error('A positive BDT amount and valid purchased duration are required.');
  }
  return store.insert({ ...data, amount: Number(data.amount), createdAt: new Date().toISOString(),
    status: data.status || 'PENDING', verifiedAt: null, approvedBy: null }, { prepend: true });
};
const getPaymentByTranId = (tranId) => store.find(tranId);
const getPaymentsByUserId = (userId) => store.all().filter(p => p.userId === userId);
const getAllPayments = (filter = {}) => store.all().filter(p => {
  if (filter.status && filter.status !== 'ALL' && p.status !== filter.status) return false;
  const q = String(filter.search || '').toLowerCase().trim();
  return !q || [p.tranId, p.trxId, p.userEmail, p.userName, p.senderPhone].some(v => String(v || '').toLowerCase().includes(q));
});
const settle = (tranId, details, manual, adminEmail) => transaction(() => {
  const payment = getPaymentByTranId(tranId);
  if (!payment) return null;
  if (payment.status === 'SUCCESS') return { payment, alreadySuccess: true };
  if (TERMINAL.has(payment.status) || (manual && payment.status !== 'PENDING_APPROVAL') ||
      (!manual && payment.status !== 'PENDING')) throw new Error('This transaction is not payable.');
  if (manual && payment.paymentMethod !== 'bKash (Manual)') throw new Error('Only manual bKash requests may be approved here.');
  const updated = store.update(tranId, { status: 'SUCCESS', ...details,
    verifiedAt: new Date().toISOString(), ...(manual ? { approvedBy: adminEmail } : {}) });
  userStore.activateUserSubscription(payment.userId, payment.planId, payment.durationDays, tranId);
  return { payment: updated, alreadySuccess: false };
});
const markPaymentSuccess = (tranId, details = {}) => settle(tranId, details, false);
const approveManualPayment = (tranId, adminEmail) => settle(tranId, {}, true, adminEmail);
const fail = (tranId, status, reason, adminEmail) => transaction(() => {
  const payment = getPaymentByTranId(tranId);
  if (!payment) return null;
  if (TERMINAL.has(payment.status)) return payment;
  return store.update(tranId, { status, adminNote: reason || null, ...(adminEmail ? { approvedBy: adminEmail } : {}) });
});
const markPaymentFailed = (id, reason = '') => fail(id, 'FAILED', reason);
const markPaymentCancelled = (id) => fail(id, 'CANCELLED');
const rejectManualPayment = (id, reason, adminEmail) => {
  const payment = getPaymentByTranId(id);
  if (payment && payment.status !== 'PENDING_APPROVAL') return payment;
  return fail(id, 'REJECTED', reason, adminEmail);
};
const hasManualTrx = (trxId) => store.all().some(p => p.paymentMethod === 'bKash (Manual)' &&
  p.trxId === trxId && ['PENDING_APPROVAL', 'SUCCESS'].includes(p.status));
const getPaymentStats = () => {
  const payments = store.all(), successful = payments.filter(p => p.status === 'SUCCESS');
  return { totalRevenue: successful.reduce((sum, p) => sum + p.amount, 0), currency: 'BDT',
    successfulTransactionsCount: successful.length, pendingApprovalsCount: payments.filter(p => p.status === 'PENDING_APPROVAL').length,
    totalTransactionsCount: payments.length };
};
module.exports = { createPayment, getPaymentByTranId, getPaymentsByUserId, getAllPayments,
  markPaymentSuccess, markPaymentFailed, markPaymentCancelled, approveManualPayment,
  rejectManualPayment, getPaymentStats, hasManualTrx };
