/**
 * AdoptMatch - Payments & Subscriptions Record Store
 * Secure server-side ledger with idempotency checks and manual bKash approval workflows.
 */

let paymentsDb = [
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

const createPayment = (data) => {
  const existing = paymentsDb.find(p => p.tranId === data.tranId);
  if (existing) return existing;

  const payment = {
    tranId: data.tranId,
    userId: data.userId,
    userName: data.userName || 'Adopter',
    userEmail: data.userEmail || '',
    planId: data.planId,
    planName: data.planName || 'AdoptMatch Premium',
    amount: Number(data.amount),
    currency: data.currency || 'BDT',
    status: data.status || 'PENDING',
    paymentMethod: data.paymentMethod || 'SSLCommerz',
    valId: data.valId || null,
    bankTranId: data.bankTranId || null,
    cardType: data.cardType || null,
    senderPhone: data.senderPhone || null,
    trxId: data.trxId || null,
    createdAt: new Date().toISOString(),
    verifiedAt: null,
    adminNote: data.adminNote || null,
    approvedBy: null,
  };

  paymentsDb.unshift(payment);
  return payment;
};

const getPaymentByTranId = (tranId) => {
  return paymentsDb.find(p => p.tranId === tranId) || null;
};

const getPaymentsByUserId = (userId) => {
  return paymentsDb.filter(p => p.userId === userId);
};

const getAllPayments = (filter = {}) => {
  let list = [...paymentsDb];

  if (filter.status && filter.status !== 'ALL') {
    list = list.filter(p => p.status === filter.status);
  }

  if (filter.search) {
    const q = filter.search.toLowerCase().trim();
    list = list.filter(p =>
      p.tranId.toLowerCase().includes(q) ||
      (p.trxId && p.trxId.toLowerCase().includes(q)) ||
      (p.userEmail && p.userEmail.toLowerCase().includes(q)) ||
      (p.userName && p.userName.toLowerCase().includes(q)) ||
      (p.senderPhone && p.senderPhone.toLowerCase().includes(q))
    );
  }

  return list;
};

const markPaymentSuccess = (tranId, details = {}) => {
  const payment = getPaymentByTranId(tranId);
  if (!payment) return null;

  // Idempotency: if already success, do not reactivate
  const alreadySuccess = payment.status === 'SUCCESS';

  payment.status = 'SUCCESS';
  payment.valId = details.valId || payment.valId;
  payment.bankTranId = details.bankTranId || payment.bankTranId;
  payment.cardType = details.cardType || payment.cardType;
  payment.verifiedAt = new Date().toISOString();

  return { payment, alreadySuccess };
};

const markPaymentFailed = (tranId, reason = '') => {
  const payment = getPaymentByTranId(tranId);
  if (!payment) return null;

  payment.status = 'FAILED';
  payment.adminNote = reason;
  return payment;
};

const markPaymentCancelled = (tranId) => {
  const payment = getPaymentByTranId(tranId);
  if (!payment) return null;

  payment.status = 'CANCELLED';
  return payment;
};

const approveManualPayment = (tranId, adminEmail = 'admin@adoptmatch.org') => {
  const payment = getPaymentByTranId(tranId);
  if (!payment) return null;

  payment.status = 'SUCCESS';
  payment.verifiedAt = new Date().toISOString();
  payment.approvedBy = adminEmail;

  return payment;
};

const rejectManualPayment = (tranId, reason = 'Invalid bKash TrxID', adminEmail = 'admin@adoptmatch.org') => {
  const payment = getPaymentByTranId(tranId);
  if (!payment) return null;

  payment.status = 'FAILED';
  payment.adminNote = reason;
  payment.approvedBy = adminEmail;

  return payment;
};

const getPaymentStats = () => {
  const successfulPayments = paymentsDb.filter(p => p.status === 'SUCCESS');
  const totalRevenue = successfulPayments.reduce((sum, p) => sum + p.amount, 0);
  const pendingApprovals = paymentsDb.filter(p => p.status === 'PENDING_APPROVAL').length;
  const totalTransactions = paymentsDb.length;

  return {
    totalRevenue,
    currency: 'BDT',
    successfulTransactionsCount: successfulPayments.length,
    pendingApprovalsCount: pendingApprovals,
    totalTransactionsCount: totalTransactions
  };
};

module.exports = {
  createPayment,
  getPaymentByTranId,
  getPaymentsByUserId,
  getAllPayments,
  markPaymentSuccess,
  markPaymentFailed,
  markPaymentCancelled,
  approveManualPayment,
  rejectManualPayment,
  getPaymentStats,
};

