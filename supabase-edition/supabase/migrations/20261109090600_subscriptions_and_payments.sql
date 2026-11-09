-- 07 — Money. Prices come from this table, never from the client.
-- Rows are written only by the payment Edge Function using the service role.

create table public.subscription_plans (
  id text primary key,
  name text not null,
  name_bn text not null default '',
  price numeric(10, 2) not null,
  currency text not null default 'BDT',
  duration_days integer not null,
  tag text not null default '',
  is_best_value boolean not null default false,
  is_active boolean not null default true,
  features text[] not null default '{}',
  features_bn text[] not null default '{}',
  created_at timestamptz not null default now(),
  constraint subscription_plans_price_non_negative check (price >= 0),
  constraint subscription_plans_duration_positive check (duration_days > 0)
);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  tran_id text not null unique,
  user_id uuid not null references public.profiles (id) on delete restrict,
  plan_id text not null references public.subscription_plans (id) on delete restrict,
  amount numeric(10, 2) not null,
  currency text not null default 'BDT',
  method public.payment_method not null,
  status public.payment_status not null default 'pending',

  -- Gateway identifiers, kept for reconciliation and support.
  val_id text,
  bank_tran_id text,
  card_type text,
  sender_phone text,
  trx_id text,

  gateway_payload jsonb not null default '{}'::jsonb,
  failure_reason text,

  -- Set exactly once, when the paid row is turned into entitlement.
  applied_at timestamptz,
  verified_at timestamptz,
  verified_by uuid references public.profiles (id) on delete set null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- A manual bKash TrxID is consumed for good: a rejected one cannot be reused.
  constraint payments_manual_trx_required check (
    method <> 'bkash_manual' or (trx_id is not null and length(trim(trx_id)) > 0)
  ),
  constraint payments_amount_positive check (amount > 0)
);

create unique index payments_manual_trx_key
  on public.payments (upper(trx_id))
  where method = 'bkash_manual';

create index payments_user_idx on public.payments (user_id, created_at desc);
create index payments_status_idx on public.payments (status, created_at desc);

create trigger payments_touch_updated_at
  before update on public.payments
  for each row execute function private.touch_updated_at();

create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  plan_id text not null references public.subscription_plans (id) on delete restrict,
  status public.subscription_status not null default 'active',
  started_at timestamptz not null default now(),
  expires_at timestamptz not null,
  payment_id uuid references public.payments (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- One live subscription per account.
create unique index subscriptions_one_active_per_user
  on public.subscriptions (user_id)
  where status = 'active';

create index subscriptions_expiry_idx on public.subscriptions (expires_at);

create trigger subscriptions_touch_updated_at
  before update on public.subscriptions
  for each row execute function private.touch_updated_at();

-- Turns a paid payment into entitlement, exactly once.
--
-- Called by the payments/admin Edge Functions with the service role after the
-- gateway response has been validated. Re-calling for the same tran_id returns
-- the same subscription instead of stacking a second period.
create or replace function public.apply_paid_payment(p_tran_id text)
returns public.subscriptions
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_payment public.payments;

  v_plan public.subscription_plans;
  v_sub public.subscriptions;
  v_start timestamptz;
  v_expiry timestamptz;
begin
  select * into v_payment from public.payments where tran_id = p_tran_id for update;

  if v_payment.id is null then
    raise exception 'Unknown transaction %', p_tran_id using errcode = 'P0002';
  end if;

  if v_payment.status <> 'paid' then
    raise exception 'Transaction % is not paid (status %)', p_tran_id, v_payment.status
      using errcode = '22023';
  end if;

  if v_payment.applied_at is not null then
    select * into v_sub from public.subscriptions where payment_id = v_payment.id;
    return v_sub;
  end if;

  select * into v_plan from public.subscription_plans where id = v_payment.plan_id;
  if v_plan.id is null then
    raise exception 'Unknown plan %', v_payment.plan_id using errcode = 'P0002';
  end if;

  -- Renewal extends the current period instead of throwing days away.
  select * into v_sub
    from public.subscriptions
   where user_id = v_payment.user_id and status = 'active'
   for update;

  v_start := greatest(now(), coalesce(v_sub.expires_at, now()));
  v_expiry := v_start + make_interval(days => v_plan.duration_days);

  if v_sub.id is null then
    insert into public.subscriptions (user_id, plan_id, status, started_at, expires_at, payment_id)
    values (v_payment.user_id, v_plan.id, 'active', now(), v_expiry, v_payment.id)
    returning * into v_sub;
  else
    update public.subscriptions
       set plan_id = v_plan.id,
           status = 'active',
           expires_at = v_expiry,
           payment_id = v_payment.id
     where id = v_sub.id
    returning * into v_sub;
  end if;

  update public.payments
     set applied_at = now(),
         verified_at = coalesce(verified_at, now())
   where id = v_payment.id;

  return v_sub;
end;
$$;

revoke execute on function public.apply_paid_payment(text) from public, anon, authenticated;
grant execute on function public.apply_paid_payment(text) to service_role;

-- Expired subscriptions should stop granting premium the moment they lapse.
create or replace function public.my_subscription()
returns table (
  user_id uuid,
  is_premium boolean,
  plan_id text,
  status public.subscription_status,
  started_at timestamptz,
  expires_at timestamptz,
  remaining_days integer
)
language sql
stable
security invoker
set search_path = public, pg_temp
as $$
  select
    s.user_id,
    true,
    s.plan_id,
    s.status,
    s.started_at,
    s.expires_at,
    greatest(0, ceil(extract(epoch from (s.expires_at - now())) / 86400)::integer)
  from public.subscriptions s
  where s.user_id = auth.uid()
    and s.status = 'active'
    and s.expires_at > now();
$$;
