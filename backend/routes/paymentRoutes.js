/**
 * AdoptMatch - SSLCommerz & bKash Payment Gateway Controller
 * Handles subscription initiation, server-to-server validation, idempotency, and manual bKash workflows.
 */

const express = require('express');
const router = express.Router();
const planStore = require('../models/planStore');
const paymentStore = require('../models/paymentStore');
const userStore = require('../models/userStore');

// Environment & Credentials Configuration
const STORE_ID = process.env.SSLCOMMERZ_STORE_ID || 'adoptmatch_sandbox';
const STORE_PASSWD = process.env.SSLCOMMERZ_STORE_PASSWORD || 'adoptmatch_sandbox@ssl';
const IS_LIVE = process.env.SSLCOMMERZ_IS_LIVE === 'true';
const BKASH_NUMBER = process.env.BKASH_OFFICIAL_NUMBER || '01711234567';
const BASE_URL = process.env.BACKEND_BASE_URL || 'http://localhost:5000';
const APP_DEEP_LINK = process.env.APP_DEEP_LINK_SCHEME || 'adoptmatch://payment-callback';

// SSLCommerz Host Endpoints
const SSL_SESSION_URL = IS_LIVE
  ? 'https://securepay.sslcommerz.com/gwprocess/v4/api.php'
  : 'https://sandbox.sslcommerz.com/gwprocess/v4/api.php';

const SSL_VALIDATION_URL = IS_LIVE
  ? 'https://securepay.sslcommerz.com/validator/api/validationserverAPI.php'
  : 'https://sandbox.sslcommerz.com/validator/api/validationserverAPI.php';

/**
 * GET /api/v1/payments/plans
 * Returns all active subscription plans stored dynamically
 */
router.get('/plans', (req, res) => {
  const plans = planStore.getAllPlans();
  res.json({
    success: true,
    currency: 'BDT',
    plans,
  });
});

/**
 * GET /api/v1/payments/bkash-number
 * Returns official bKash number and manual transfer guide
 */
router.get('/bkash-number', (req, res) => {
  res.json({
    success: true,
    bkashNumber: BKASH_NUMBER,
    accountType: 'Personal / Merchant',
    currency: 'BDT',
    instructionsEn: [
      `1. Open your bKash mobile application or dial *247#`,
      `2. Choose "Send Money" or "Payment" to ${BKASH_NUMBER}`,
      `3. Enter the exact plan amount in BDT (৳90, ৳200, or ৳499)`,
      `4. Put your User Name or Mobile Number in Reference`,
      `5. Once transaction succeeds, copy the bKash TrxID (e.g. 9G7A2K1092)`,
      `6. Submit the TrxID and your sender number below for instant admin verification`,
    ],
    instructionsBn: [
      `১. আপনার বিকাশ অ্যাপ ওপেন করুন অথবা *247# ডায়াল করুন`,
      `২. "Send Money" অথবা "Payment" অপশনে গিয়ে ${BKASH_NUMBER} নম্বরে টাকা পাঠান`,
      `৩. নির্বাচিত প্যাকেজের সমপরিমাণ টাকা প্রদান করুন (৳৯০, ৳২০০, অথবা ৳৪৯৯)`,
      `৪. রেফারেন্সে আপনার নাম অথবা মোবাইল নম্বর দিন`,
      `৫. লেনদেন সম্পন্ন হলে ফিরতি এসএমএস থেকে bKash TrxID কপি করুন`,
      `৬. নিচে TrxID এবং প্রেরকের নম্বর সাবমিট করে রিকোয়েস্ট পাঠান`,
    ],
  });
});

/**
 * POST /api/v1/payments/initiate-sslcommerz
 * Initiates an SSLCommerz payment session with server-side credentials
 */
router.post('/initiate-sslcommerz', async (req, res) => {
  try {
    const { planId, userId, userName, userEmail, userPhone } = req.body;

    const plan = planStore.getPlanById(planId);
    if (!plan) {
      return res.status(400).json({ success: false, error: 'Invalid planId selected' });
    }

    const effectiveUserId = userId || 'u-101';
    const effectiveUserName = userName || 'AdoptMatch Supporter';
    const effectiveEmail = userEmail || 'supporter@adoptmatch.org';
    const effectivePhone = userPhone || '+880 1711 234567';

    const tranId = `AM-SUB-${Date.now()}-${Math.random().toString(36).substring(2, 6).toUpperCase()}`;

    // Record initial pending transaction with snapshot of duration & pricing
    paymentStore.createPayment({
      tranId,
      userId: effectiveUserId,
      userName: effectiveUserName,
      userEmail: effectiveEmail,
      planId: plan.id,
      planName: plan.name,
      durationDays: plan.durationDays || 30,
      amount: plan.price,
      currency: 'BDT',
      status: 'PENDING',
      paymentMethod: 'SSLCommerz (bKash/Card/Nagad)',
    });

    // Form data payload for SSLCommerz
    const payload = new URLSearchParams({
      store_id: STORE_ID,
      store_passwd: STORE_PASSWD,
      total_amount: plan.price.toString(),
      currency: 'BDT',
      tran_id: tranId,
      success_url: `${BASE_URL}/api/v1/payments/sslcommerz-success`,
      fail_url: `${BASE_URL}/api/v1/payments/sslcommerz-fail`,
      cancel_url: `${BASE_URL}/api/v1/payments/sslcommerz-cancel`,
      ipn_url: `${BASE_URL}/api/v1/payments/sslcommerz-ipn`,
      shipping_method: 'NO',
      product_name: `AdoptMatch Premium - ${plan.name}`,
      product_category: 'Subscription',
      product_profile: 'non-physical-goods',
      cus_name: effectiveUserName,
      cus_email: effectiveEmail,
      cus_add1: 'Dhaka, Bangladesh',
      cus_city: 'Dhaka',
      cus_country: 'Bangladesh',
      cus_phone: effectivePhone,
      value_a: effectiveUserId,
      value_b: plan.id,
      value_c: plan.durationDays.toString(),
      value_d: 'adoptmatch-mobile',
    });

    let gatewayUrl = null;

    try {
      const sslResponse = await fetch(SSL_SESSION_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: payload.toString(),
      });

      const responseText = await sslResponse.text();
      let sslData;
      try {
        sslData = JSON.parse(responseText);
      } catch (_) {
        sslData = null;
      }

      if (sslData && (sslData.status === 'SUCCESS' || sslData.status === 'success') && sslData.GatewayPageURL) {
        gatewayUrl = sslData.GatewayPageURL;
      }
    } catch (netErr) {
      console.warn('[SSLCommerz API warning]:', netErr.message);
    }

    // In sandbox or test environments if live SSLCommerz session cannot be opened,
    // provide an interactive Sandbox Payment Simulator URL so testers can simulate bKash/Card payment
    if (!gatewayUrl) {
      if (IS_LIVE || process.env.NODE_ENV === 'production') {
        return res.status(502).json({
          success: false,
          error: 'Gateway unreachable. Cannot initiate live payment session.',
        });
      }
      gatewayUrl = `${BASE_URL}/api/v1/payments/sandbox-simulator?tran_id=${tranId}&amount=${plan.price}&plan_id=${plan.id}&user_id=${effectiveUserId}`;
    }

    res.json({
      success: true,
      tranId,
      amount: plan.price,
      currency: 'BDT',
      plan,
      gatewayUrl,
      message: 'SSLCommerz payment session created successfully',
    });
  } catch (err) {
    console.error('[INITIATE PAYMENT ERROR]', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * Sandbox Payment Simulator (For developer testing without active merchant keys)
 */
router.get('/sandbox-simulator', (req, res) => {
  const { tran_id, amount, plan_id, user_id } = req.query;
  const plan = planStore.getPlanById(plan_id) || { name: 'Premium Plan' };

  res.send(`
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="utf-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
        <title>SSLCommerz Sandbox Simulator - AdoptMatch</title>
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0F172A; color: #F8FAFC; margin: 0; padding: 24px; display: flex; align-items: center; justify-content: center; min-height: 100vh; }
          .card { background: #1E293B; border: 1px solid #334155; border-radius: 20px; max-width: 440px; width: 100%; padding: 28px; box-shadow: 0 10px 25px rgba(0,0,0,0.5); }
          .badge { display: inline-block; background: #E05626; color: white; padding: 4px 10px; border-radius: 8px; font-size: 12px; font-weight: bold; margin-bottom: 12px; }
          h2 { margin: 0 0 6px 0; color: #FFF; font-size: 22px; }
          p { color: #94A3B8; font-size: 14px; margin-top: 0; }
          .receipt { background: #0F172A; border-radius: 12px; padding: 16px; margin: 18px 0; border: 1px solid #334155; }
          .receipt-row { display: flex; justify-content: space-between; font-size: 14px; margin-bottom: 8px; }
          .btn-bkash { width: 100%; background: #D12053; color: white; border: none; padding: 14px; border-radius: 12px; font-size: 16px; font-weight: bold; cursor: pointer; margin-bottom: 10px; }
          .btn-fail { width: 100%; background: #334155; color: #CBD5E1; border: none; padding: 12px; border-radius: 12px; font-size: 14px; cursor: pointer; }
        </style>
      </head>
      <body>
        <div class="card">
          <span class="badge">SSLCommerz Sandbox Gateway</span>
          <h2>AdoptMatch Checkout</h2>
          <p>Select your payment method below to simulate transaction:</p>
          
          <div class="receipt">
            <div class="receipt-row"><span>Package:</span> <b>${plan.name}</b></div>
            <div class="receipt-row"><span>Amount:</span> <b>৳${amount} BDT</b></div>
            <div class="receipt-row"><span>Tran ID:</span> <code>${tran_id}</code></div>
          </div>

          <form action="/api/v1/payments/sslcommerz-success" method="POST">
            <input type="hidden" name="tran_id" value="${tran_id}" />
            <input type="hidden" name="val_id" value="SIMULATED-VAL-${Date.now()}" />
            <input type="hidden" name="amount" value="${amount}" />
            <input type="hidden" name="currency" value="BDT" />
            <input type="hidden" name="bank_tran_id" value="BKASH-SIM-${Math.floor(Math.random()*1000000)}" />
            <input type="hidden" name="card_type" value="BKASH-bKash" />
            <input type="hidden" name="status" value="VALID" />
            <input type="hidden" name="value_a" value="${user_id}" />
            <input type="hidden" name="value_b" value="${plan_id}" />
            <button type="submit" class="btn-bkash">Pay ৳${amount} with bKash (Sandbox)</button>
          </form>

          <form action="/api/v1/payments/sslcommerz-cancel" method="POST">
            <input type="hidden" name="tran_id" value="${tran_id}" />
            <button type="submit" class="btn-fail">Cancel Transaction</button>
          </form>
        </div>
      </body>
    </html>
  `);
});

/**
 * Server-Side Validation Helper (Validates transaction directly with SSLCommerz)
 */
async function verifyWithSslCommerzServer(valId) {
  if (!valId) {
    return { isValid: false, error: 'val_id is required' };
  }

  // Strictly block simulated validation IDs in live or production environments
  if (valId.startsWith('SIMULATED-VAL-')) {
    if (IS_LIVE || process.env.NODE_ENV === 'production') {
      return { isValid: false, error: 'Simulated payment verification is strictly disallowed in live or production environments.' };
    }
    return { isValid: true, status: 'VALID', isSimulated: true };
  }

  try {
    const url = `${SSL_VALIDATION_URL}?val_id=${valId}&store_id=${STORE_ID}&store_passwd=${STORE_PASSWD}&v=1&format=json`;
    const res = await fetch(url);
    const data = await res.json();

    const isValid = data && (data.status === 'VALID' || data.status === 'VALIDATED');
    return {
      isValid,
      status: data ? data.status : 'INVALID',
      amount: data ? data.amount : null,
      currency: data ? data.currency : null,
      bankTranId: data ? data.bank_tran_id : null,
      cardType: data ? data.card_type : null,
      tranId: data ? data.tran_id : null,
    };
  } catch (err) {
    console.error('[SSL VALIDATION REQUEST ERROR]', err);
    return { isValid: false, error: err.message };
  }
}

/**
 * POST /api/v1/payments/sslcommerz-success
 * SSLCommerz Success Callback with Server-Side Validation & Idempotent Activation
 */
router.post('/sslcommerz-success', async (req, res) => {
  try {
    const { tran_id, val_id, amount, card_type, bank_tran_id } = req.body;

    const payment = paymentStore.getPaymentByTranId(tran_id);
    if (!payment) {
      return res.status(404).send('Transaction record not found.');
    }

    // 1. Strict Server-Side SSLCommerz Validation
    const validation = await verifyWithSslCommerzServer(val_id);
    if (!validation.isValid) {
      paymentStore.markPaymentFailed(tran_id, 'Server-to-server validation failed with SSLCommerz');
      return res.redirect(`${APP_DEEP_LINK}?status=failed&tran_id=${tran_id}`);
    }

    // Verify transaction amount and currency against recorded payment if gateway returned them
    if (validation.amount && Math.abs(Number(validation.amount) - Number(payment.amount)) > 0.01) {
      paymentStore.markPaymentFailed(tran_id, `Amount mismatch: Gateway reported ${validation.amount}, expected ${payment.amount}`);
      return res.redirect(`${APP_DEEP_LINK}?status=failed&tran_id=${tran_id}`);
    }

    if (validation.currency && validation.currency.toUpperCase() !== payment.currency.toUpperCase()) {
      paymentStore.markPaymentFailed(tran_id, `Currency mismatch: Gateway reported ${validation.currency}, expected ${payment.currency}`);
      return res.redirect(`${APP_DEEP_LINK}?status=failed&tran_id=${tran_id}`);
    }

    // 2. Idempotent Activation
    const { alreadySuccess } = paymentStore.markPaymentSuccess(tran_id, {
      valId: val_id,
      bankTranId: bank_tran_id || validation.bankTranId,
      cardType: card_type || validation.cardType || 'bKash',
    });

    if (!alreadySuccess) {
      const duration = payment.durationDays || 30;
      userStore.activateUserSubscription(payment.userId, payment.planId, duration, tran_id);
      console.log(`[SUBSCRIPTION ACTIVATED] User: ${payment.userId} Plan: ${payment.planId} Tran: ${tran_id}`);
    }

    // Return HTML success response with auto deep-link redirect
    const deepLinkUrl = `${APP_DEEP_LINK}?status=success&tran_id=${tran_id}&plan_id=${payment.planId}&amount=${payment.amount}`;

    res.send(`
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="utf-8"/>
          <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
          <title>Payment Successful - AdoptMatch</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0F172A; color: #FFF; text-align: center; padding: 40px 20px; }
            .card { background: #1E293B; border-radius: 20px; max-width: 420px; margin: 0 auto; padding: 32px 24px; border: 1px solid #334155; }
            .icon-circle { width: 72px; height: 72px; background: #10B981; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 20px; font-size: 36px; }
            h2 { color: #FFF; margin: 0 0 8px; font-size: 24px; }
            p { color: #94A3B8; font-size: 14px; margin-top: 0; line-height: 1.5; }
            .badge { background: #0F766E; color: #5EEAD4; padding: 6px 14px; border-radius: 20px; font-size: 13px; font-weight: bold; display: inline-block; margin: 12px 0; }
            .btn { display: block; background: #E05626; color: white; text-decoration: none; padding: 14px; border-radius: 12px; font-weight: bold; font-size: 15px; margin-top: 24px; }
          </style>
          <script>
            // Attempt automatic deep link navigation back into Flutter app
            setTimeout(() => {
              window.location.href = "${deepLinkUrl}";
            }, 600);
          </script>
        </head>
        <body>
          <div class="card">
            <div class="icon-circle">✓</div>
            <h2>Payment Successful!</h2>
            <div class="badge">AdoptMatch Premium Active 🐾</div>
            <p>Your subscription payment of <b>৳${payment.amount} BDT</b> has been verified and your premium benefits are now active!</p>
            <p><small style="color: #64748B">Transaction ID: ${tran_id}</small></p>
            <a href="${deepLinkUrl}" class="btn">Return to AdoptMatch App</a>
          </div>
        </body>
      </html>
    `);
  } catch (err) {
    console.error('[SUCCESS CALLBACK ERROR]', err);
    res.status(500).send('Error processing payment confirmation.');
  }
});

/**
 * POST /api/v1/payments/sslcommerz-fail
 */
router.post('/sslcommerz-fail', (req, res) => {
  const { tran_id, error } = req.body;
  paymentStore.markPaymentFailed(tran_id, error || 'Payment failed on SSLCommerz gateway');
  const deepLink = `${APP_DEEP_LINK}?status=failed&tran_id=${tran_id || ''}`;
  res.redirect(deepLink);
});

/**
 * POST /api/v1/payments/sslcommerz-cancel
 */
router.post('/sslcommerz-cancel', (req, res) => {
  const { tran_id } = req.body;
  paymentStore.markPaymentCancelled(tran_id);
  const deepLink = `${APP_DEEP_LINK}?status=cancelled&tran_id=${tran_id || ''}`;
  res.redirect(deepLink);
});

/**
 * POST /api/v1/payments/sslcommerz-ipn
 * Webhook handler for Instant Payment Notification
 */
router.post('/sslcommerz-ipn', async (req, res) => {
  const { tran_id, val_id, status } = req.body;
  if (!tran_id || !val_id) {
    return res.status(400).json({ success: false, error: 'Missing tran_id or val_id' });
  }

  const payment = paymentStore.getPaymentByTranId(tran_id);
  if (!payment) return res.status(404).send('Transaction not found');

  // Verify directly with SSLCommerz server instead of trusting submitted status
  const validation = await verifyWithSslCommerzServer(val_id);
  if (!validation.isValid) {
    return res.status(400).json({ success: false, error: 'IPN validation with SSLCommerz failed' });
  }

  if (validation.amount && Math.abs(Number(validation.amount) - Number(payment.amount)) > 0.01) {
    return res.status(400).json({ success: false, error: 'Amount mismatch detected in IPN' });
  }

  const { alreadySuccess } = paymentStore.markPaymentSuccess(tran_id, {
    valId: val_id,
    bankTranId: validation.bankTranId,
    cardType: validation.cardType,
  });

  if (!alreadySuccess) {
    const duration = payment.durationDays || 30;
    userStore.activateUserSubscription(payment.userId, payment.planId, duration, tran_id);
  }

  res.json({ success: true, message: 'IPN verified and processed successfully' });
});

/**
 * POST /api/v1/payments/manual-bkash
 * Submits a manual bKash payment for Administrator verification
 */
router.post('/manual-bkash', (req, res) => {
  const { planId, userId, userName, userEmail, senderPhone, trxId } = req.body;

  if (!senderPhone || !trxId) {
    return res.status(400).json({
      success: false,
      error: 'Both bKash Sender Phone Number and Transaction ID (TrxID) are required.',
    });
  }

  const plan = planStore.getPlanById(planId);
  if (!plan) {
    return res.status(400).json({ success: false, error: 'Invalid planId' });
  }

  const tranId = `AM-BKASH-${Date.now()}-${Math.random().toString(36).substring(2, 6).toUpperCase()}`;

  const payment = paymentStore.createPayment({
    tranId,
    userId: userId || 'u-101',
    userName: userName || 'Adopter',
    userEmail: userEmail || '',
    planId: plan.id,
    planName: plan.name,
    amount: plan.price,
    currency: 'BDT',
    status: 'PENDING_APPROVAL',
    paymentMethod: 'bKash (Manual)',
    senderPhone: senderPhone.trim(),
    trxId: trxId.trim().toUpperCase(),
  });

  res.json({
    success: true,
    message: 'Manual bKash payment request submitted successfully! An administrator will review your TrxID and activate your subscription shortly.',
    payment,
  });
});

/**
 * GET /api/v1/payments/my-subscription
 * Returns the authenticated user's active subscription, expiry details & payment history
 */
router.get('/my-subscription', (req, res) => {
  const userId = req.query.userId || req.headers['x-user-id'] || 'u-101';

  const subscription = userStore.getUserSubscription(userId);
  const history = paymentStore.getPaymentsByUserId(userId);

  let activePlan = null;
  if (subscription && subscription.premiumPlanId) {
    activePlan = planStore.getPlanById(subscription.premiumPlanId);
  }

  res.json({
    success: true,
    subscription,
    activePlan,
    history,
  });
});

/**
 * GET /api/v1/payments/verify/:tranId
 * Poll or check transaction status by tranId
 */
router.get('/verify/:tranId', (req, res) => {
  const { tranId } = req.params;
  const payment = paymentStore.getPaymentByTranId(tranId);

  if (!payment) {
    return res.status(404).json({ success: false, error: 'Payment record not found' });
  }

  res.json({
    success: true,
    payment,
  });
});

module.exports = router;

