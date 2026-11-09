/**
 * Payments: SSLCommerz (hosted checkout) and manual bKash.
 *
 * Trust boundary: the client only ever sends a plan id. Amount and currency come
 * from `subscription_plans`, the gateway response is verified against SSLCommerz'
 * validation API, and entitlement is granted by `apply_paid_payment`, which is
 * idempotent per transaction.
 *
 * Routes (all under /functions/v1/payments):
 *   GET  plans
 *   POST initiate-sslcommerz
 *   POST sslcommerz/ipn | sslcommerz/success | sslcommerz/fail | sslcommerz/cancel
 *   POST manual-bkash
 *   GET  my-subscription
 *   GET  verify/{tran_id}
 */

import {
  ApiError,
  errorResponse,
  json,
  preflight,
  readForm,
  readJson,
  redirectTo,
  routeOf,
  text,
} from '../_shared/http.ts';
import { optional, required, supabaseUrl } from '../_shared/env.ts';
import { requireUser, roleOf, serviceClient } from '../_shared/supabase.ts';

type Plan = {
  id: string;
  name: string;
  price: number;
  currency: string;
  duration_days: number;
};

type Payment = {
  id: string;
  tran_id: string;
  user_id: string;
  plan_id: string;
  amount: number;
  currency: string;
  method: 'sslcommerz' | 'bkash_manual';
  status: string;
  applied_at: string | null;
};

const VALID_GATEWAY_STATES = ['VALID', 'VALIDATED'];

Deno.serve(async (req: Request): Promise<Response> => {
  const options = preflight(req);
  if (options) return options;

  try {
    const route = routeOf(req, 'payments');
    const method = req.method;

    if (method === 'GET' && route === 'plans') {
      return json({ status: 'success', data: await listPlans() });
    }
    if (method === 'POST' && route === 'initiate-sslcommerz') {
      return await initiateSslcommerz(req);
    }
    if (method === 'POST' && route.startsWith('sslcommerz/')) {
      return await handleGatewayCallback(route.split('/')[1], req);
    }
    if (method === 'POST' && route === 'manual-bkash') {
      return await manualBkash(req);
    }
    if (method === 'GET' && route === 'my-subscription') {
      return await mySubscription(req);
    }
    if (method === 'GET' && route.startsWith('verify/')) {
      return await verifyTransaction(req, route.slice('verify/'.length));
    }

    throw new ApiError(404, 'NOT_FOUND', `No payments route for ${method} /${route}`);
  } catch (error) {
    return errorResponse(error);
  }
});

// ---------------------------------------------------------------------------
// Read paths
// ---------------------------------------------------------------------------

async function listPlans(): Promise<Plan[]> {
  const { data, error } = await serviceClient()
    .from('subscription_plans')
    .select('id,name,price,currency,duration_days')
    .eq('is_active', true)
    .order('price', { ascending: true });

  if (error) throw new ApiError(500, 'PLANS_UNAVAILABLE', 'Could not load the plans.');
  return (data ?? []) as Plan[];
}

async function loadPlan(planId: string): Promise<Plan> {
  const { data, error } = await serviceClient()
    .from('subscription_plans')
    .select('id,name,price,currency,duration_days')
    .eq('id', planId)
    .eq('is_active', true)
    .maybeSingle();

  if (error) throw new ApiError(500, 'PLAN_LOOKUP_FAILED', 'Could not read the plan.');
  if (!data) throw new ApiError(400, 'UNKNOWN_PLAN', 'That plan is not available.');
  return data as Plan;
}

async function mySubscription(req: Request): Promise<Response> {
  const user = await requireUser(req);
  const sb = serviceClient();

  const { data, error } = await sb
    .from('subscriptions')
    .select('plan_id,status,started_at,expires_at')
    .eq('user_id', user.id)
    .eq('status', 'active')
    .gt('expires_at', new Date().toISOString())
    .maybeSingle();

  if (error) throw new ApiError(500, 'SUBSCRIPTION_UNAVAILABLE', 'Could not read your subscription.');

  const { data: pending, error: pendingError } = await sb
    .from('payments')
    .select('tran_id,plan_id,amount,currency,method,status,created_at')
    .eq('user_id', user.id)
    .in('status', ['pending', 'processing'])
    .order('created_at', { ascending: false })
    .limit(5);

  if (pendingError) {
    throw new ApiError(500, 'PAYMENTS_UNAVAILABLE', 'Could not read your pending payments.');
  }

  const active = data
    ? {
      is_premium: true,
      plan_id: data.plan_id,
      status: data.status,
      started_at: data.started_at,
      expires_at: data.expires_at,
      remaining_days: Math.max(
        0,
        Math.ceil((new Date(data.expires_at).getTime() - Date.now()) / 86_400_000),
      ),
    }
    : { is_premium: false, plan_id: null, status: 'none', started_at: null, expires_at: null, remaining_days: 0 };

  return json({ status: 'success', data: { subscription: active, pending: pending ?? [] } });
}

async function verifyTransaction(req: Request, tranId: string): Promise<Response> {
  const user = await requireUser(req);
  const role = await roleOf(user.id);

  const { data, error } = await serviceClient()
    .from('payments')
    .select('tran_id,user_id,plan_id,amount,currency,method,status,val_id,bank_tran_id,trx_id,created_at,verified_at,applied_at,failure_reason')
    .eq('tran_id', tranId)
    .maybeSingle();

  if (error) throw new ApiError(500, 'PAYMENT_LOOKUP_FAILED', 'Could not read the payment.');
  if (!data) throw new ApiError(404, 'PAYMENT_NOT_FOUND', 'No payment with that transaction id.');

  const isStaff = role === 'moderator' || role === 'admin' || role === 'super_admin';
  if (data.user_id !== user.id && !isStaff) {
    throw new ApiError(403, 'FORBIDDEN', 'That payment belongs to another account.');
  }

  return json({ status: 'success', data });
}

// ---------------------------------------------------------------------------
// SSLCommerz
// ---------------------------------------------------------------------------

function gatewayBase(): string {
  return optional('SSLCOMMERZ_SANDBOX') === 'false'
    ? 'https://securepay.sslcommerz.com'
    : 'https://sandbox.sslcommerz.com';
}

function callbackBase(): string {
  return optional('PAYMENT_CALLBACK_BASE') ?? `${supabaseUrl()}/functions/v1/payments`;
}

function appReturnUrl(): string {
  return optional('PAYMENT_RETURN_URL') ?? 'https://adoptmatch.app/payments/result';
}

function newTranId(): string {
  // SSLCommerz caps tran_id at 30 characters.
  const random = crypto.randomUUID().replaceAll('-', '').slice(0, 10);
  return `AM${Date.now().toString(36)}${random}`.slice(0, 30);
}

async function initiateSslcommerz(req: Request): Promise<Response> {
  const user = await requireUser(req);
  const body = await readJson<{
    plan_id?: string;
    customer?: { name?: string; email?: string; phone?: string; address?: string; city?: string };
  }>(req);

  const planId = String(body.plan_id ?? '').trim();
  if (!planId) throw new ApiError(400, 'PLAN_REQUIRED', 'Choose a plan before paying.');

  const plan = await loadPlan(planId);
  const storeId = required('SSLCOMMERZ_STORE_ID');
  const storePassword = required('SSLCOMMERZ_STORE_PASSWORD');

  const sb = serviceClient();
  const tranId = newTranId();

  const { error: insertError } = await sb.from('payments').insert({
    tran_id: tranId,
    user_id: user.id,
    plan_id: plan.id,
    amount: plan.price,
    currency: plan.currency,
    method: 'sslcommerz',
    status: 'pending',
  });

  if (insertError) {
    throw new ApiError(500, 'PAYMENT_CREATE_FAILED', 'Could not start the payment.');
  }

  const form = new URLSearchParams({
    store_id: storeId,
    store_passwd: storePassword,
    total_amount: Number(plan.price).toFixed(2),
    currency: plan.currency,
    tran_id: tranId,
    success_url: `${callbackBase()}/sslcommerz/success`,
    fail_url: `${callbackBase()}/sslcommerz/fail`,
    cancel_url: `${callbackBase()}/sslcommerz/cancel`,
    ipn_url: `${callbackBase()}/sslcommerz/ipn`,
    cus_name: body.customer?.name?.trim() || user.email?.split('@')[0] || 'AdoptMatch supporter',
    cus_email: body.customer?.email?.trim() || user.email || 'support@adoptmatch.app',
    cus_add1: body.customer?.address?.trim() || 'Dhaka',
    cus_city: body.customer?.city?.trim() || 'Dhaka',
    cus_country: 'Bangladesh',
    cus_phone: body.customer?.phone?.trim() || '01700000000',
    shipping_method: 'NO',
    num_of_item: '1',
    product_name: plan.name,
    product_category: 'subscription',
    product_profile: 'general',
    value_a: user.id,
  });

  let session: Record<string, unknown>;
  try {
    const response = await fetch(`${gatewayBase()}/gwprocess/v4/api.php`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: form.toString(),
    });
    session = await response.json() as Record<string, unknown>;
  } catch {
    await sb.from('payments').update({ status: 'failed', failure_reason: 'gateway unreachable' })
      .eq('tran_id', tranId);
    throw new ApiError(502, 'GATEWAY_UNREACHABLE', 'The payment gateway did not respond. Try again.');
  }

  const gatewayUrl = typeof session.GatewayPageURL === 'string' ? session.GatewayPageURL : '';
  if (String(session.status).toUpperCase() !== 'SUCCESS' || !gatewayUrl) {
    const reason = String(session.failedreason ?? session.status ?? 'session rejected').slice(0, 200);
    await sb.from('payments').update({ status: 'failed', failure_reason: reason }).eq('tran_id', tranId);
    throw new ApiError(502, 'GATEWAY_REJECTED', 'The payment gateway rejected this checkout. Try again.');
  }

  // Only non-sensitive session metadata is kept; card data never reaches us.
  await sb.from('payments')
    .update({ gateway_payload: { session_key: session.sessionkey ?? null, gateway: 'sslcommerz' } })
    .eq('tran_id', tranId);

  return json({
    status: 'success',
    data: { tran_id: tranId, gateway_url: gatewayUrl, amount: plan.price, currency: plan.currency },
  });
}

async function handleGatewayCallback(outcome: string, req: Request): Promise<Response> {
  const form = await readForm(req);
  const isIpn = outcome === 'ipn';

  const tranId = (form.get('tran_id') ?? '').trim();
  if (!tranId) {
    return isIpn ? text('MISSING TRAN ID', 400) : redirectTo(`${appReturnUrl()}?status=error`);
  }

  const settled = await settlePayment(form, tranId);

  if (isIpn) return text(settled.ok ? 'OK' : 'FAILED');

  const status = settled.ok ? 'paid' : (outcome === 'success' ? 'failed' : outcome);
  const url = new URL(appReturnUrl());
  url.searchParams.set('tran_id', tranId);
  url.searchParams.set('status', status);
  return redirectTo(url.toString());
}

type SettleResult = { ok: boolean; reason?: string };

async function settlePayment(form: URLSearchParams, tranId: string): Promise<SettleResult> {
  const sb = serviceClient();

  const { data: payment, error } = await sb
    .from('payments')
    .select('id,tran_id,user_id,plan_id,amount,currency,method,status,applied_at')
    .eq('tran_id', tranId)
    .maybeSingle<Payment>();

  if (error) {
    console.error('[payments] lookup failed', error);
    return { ok: false, reason: 'lookup failed' };
  }
  if (!payment) return { ok: false, reason: 'unknown transaction' };

  // Replay of a callback we already processed must not double-grant entitlement.
  if (payment.status === 'paid') {
    await applyEntitlement(tranId);
    return { ok: true };
  }

  const gatewayStatus = (form.get('status') ?? '').trim().toUpperCase();
  const valId = (form.get('val_id') ?? '').trim();

  if (!VALID_GATEWAY_STATES.includes(gatewayStatus) || !valId) {
    await markFailed(tranId, `gateway reported ${gatewayStatus || 'no status'}`);
    return { ok: false, reason: 'not successful' };
  }

  const validation = await validateWithGateway(valId);
  const problems: string[] = [];

  if (!validation || !VALID_GATEWAY_STATES.includes(String(validation.status ?? '').toUpperCase())) {
    problems.push('validation rejected');
  }
  if (String(validation?.tran_id ?? '') !== tranId) problems.push('transaction mismatch');
  if (Math.abs(Number(validation?.amount ?? 0) - Number(payment.amount)) > 0.01) {
    problems.push('amount mismatch');
  }
  if (String(validation?.currency ?? '').toUpperCase() !== String(payment.currency).toUpperCase()) {
    problems.push('currency mismatch');
  }

  if (problems.length > 0) {
    await markFailed(tranId, problems.join('; '));
    return { ok: false, reason: problems.join('; ') };
  }

  const { error: updateError } = await sb.from('payments').update({
    status: 'paid',
    val_id: valId,
    bank_tran_id: (form.get('bank_tran_id') ?? validation?.bank_tran_id ?? '').toString().slice(0, 64) || null,
    card_type: (form.get('card_type') ?? validation?.card_type ?? '').toString().slice(0, 64) || null,
    verified_at: new Date().toISOString(),
    failure_reason: null,
  }).eq('id', payment.id).neq('status', 'paid');

  if (updateError) {
    console.error('[payments] could not mark paid', updateError);
    return { ok: false, reason: 'write failed' };
  }

  await applyEntitlement(tranId);
  return { ok: true };
}

async function validateWithGateway(valId: string): Promise<Record<string, unknown> | null> {
  const storeId = required('SSLCOMMERZ_STORE_ID');
  const storePassword = required('SSLCOMMERZ_STORE_PASSWORD');
  const url = new URL(`${gatewayBase()}/validator/api/validationserverAPI.php`);
  url.searchParams.set('val_id', valId);
  url.searchParams.set('store_id', storeId);
  url.searchParams.set('store_passwd', storePassword);
  url.searchParams.set('format', 'json');

  try {
    const response = await fetch(url.toString(), { method: 'GET' });
    if (!response.ok) return null;
    return await response.json() as Record<string, unknown>;
  } catch (error) {
    console.error('[payments] validation call failed', error);
    return null;
  }
}

async function markFailed(tranId: string, reason: string): Promise<void> {
  // A paid transaction is terminal; a late failure callback cannot undo it.
  await serviceClient()
    .from('payments')
    .update({ status: 'failed', failure_reason: reason.slice(0, 240) })
    .eq('tran_id', tranId)
    .neq('status', 'paid');
}

async function applyEntitlement(tranId: string): Promise<void> {
  const { error } = await serviceClient().rpc('apply_paid_payment', { p_tran_id: tranId });
  if (error) {
    // The money is recorded; support can re-run this from the admin endpoint.
    console.error('[payments] entitlement failed', error);
  }
}

// ---------------------------------------------------------------------------
// Manual bKash
// ---------------------------------------------------------------------------

async function manualBkash(req: Request): Promise<Response> {
  const user = await requireUser(req);
  const body = await readJson<{ plan_id?: string; trx_id?: string; sender_phone?: string }>(req);

  const planId = String(body.plan_id ?? '').trim();
  const trxId = String(body.trx_id ?? '').trim();
  const senderPhone = String(body.sender_phone ?? '').trim();

  if (!planId) throw new ApiError(400, 'PLAN_REQUIRED', 'Choose a plan first.');
  if (!/^[A-Za-z0-9]{6,32}$/.test(trxId)) {
    throw new ApiError(400, 'INVALID_TRX_ID', 'Enter the bKash TrxID exactly as shown in the SMS.');
  }
  if (!/^(\+?88)?01[3-9]\d{8}$/.test(senderPhone.replaceAll(' ', ''))) {
    throw new ApiError(400, 'INVALID_PHONE', 'Enter the bKash number that sent the money.');
  }

  const plan = await loadPlan(planId);
  const tranId = `BK${newTranId()}`.slice(0, 30);

  const { error } = await serviceClient().from('payments').insert({
    tran_id: tranId,
    user_id: user.id,
    plan_id: plan.id,
    amount: plan.price,
    currency: plan.currency,
    method: 'bkash_manual',
    status: 'pending',
    trx_id: trxId,
    sender_phone: senderPhone,
  });

  if (error) {
    if (error.code === '23505') {
      throw new ApiError(409, 'TRX_ALREADY_USED', 'That TrxID has already been submitted.');
    }
    throw new ApiError(500, 'PAYMENT_CREATE_FAILED', 'Could not record this payment.');
  }

  return json({
    status: 'success',
    data: {
      tran_id: tranId,
      status: 'pending',
      message: 'Submitted. Premium activates after an admin verifies the TrxID.',
    },
  }, 201);
}
