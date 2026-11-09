-- 10 — JWT claims hook, geo query, admin aggregates.

-- ---------------------------------------------------------------------------
-- Role claims.
--
-- RLS needs the caller's role without querying `profiles` on every row (that
-- would recurse into profiles' own policies). The hook copies the role into the
-- access token, so policies read it from the JWT instead.
--
-- Register it in the dashboard (Authentication → Hooks → Custom access token)
-- or in supabase/config.toml for local development.
-- ---------------------------------------------------------------------------
create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := (event ->> 'user_id')::uuid;
  v_role text;
  v_shelter uuid;
  v_claims jsonb;
begin
  select p.role::text into v_role from public.profiles p where p.id = v_user_id;
  select s.id into v_shelter
    from public.shelters s
   where s.owner_id = v_user_id
     and s.verification_status = 'approved'
   limit 1;

  v_claims := coalesce(event -> 'claims', '{}'::jsonb);
  v_claims := jsonb_set(v_claims, '{app_role}', to_jsonb(coalesce(v_role, 'adopter')));

  if v_shelter is null then
    v_claims := v_claims - 'shelter_id';
  else
    v_claims := jsonb_set(v_claims, '{shelter_id}', to_jsonb(v_shelter));
  end if;

  return jsonb_set(event, '{claims}', v_claims);
end;
$$;

-- The hook runs as the auth admin role, which only exists on a live Supabase
-- project. Guarding keeps these migrations runnable on a plain Postgres too.
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'supabase_auth_admin') then
    execute 'grant usage on schema public to supabase_auth_admin';
    execute 'grant select on table public.profiles to supabase_auth_admin';
    execute 'grant select on table public.shelters to supabase_auth_admin';
    execute 'grant execute on function public.custom_access_token_hook(jsonb) to supabase_auth_admin';
  end if;
end;
$$;

revoke execute on function public.custom_access_token_hook(jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Geo search. Haversine in SQL avoids a PostGIS dependency for a radius filter
-- over a few thousand rows.
-- ---------------------------------------------------------------------------
create or replace function public.pets_nearby(
  p_lat double precision,
  p_lng double precision,
  p_radius_km double precision default 25,
  p_limit integer default 50
)
returns setof public.pets
language sql
stable
security invoker
set search_path = public, pg_temp
as $$
  select p.*
  from public.pets p
  where p.is_active
    and p.moderation_status = 'approved'
    and p.adoption_status in ('available', 'foster')
    and p.latitude is not null
    and p.longitude is not null
    and 6371 * 2 * asin(sqrt(
          power(sin(radians(p.latitude - p_lat) / 2), 2)
        + cos(radians(p_lat)) * cos(radians(p.latitude))
        * power(sin(radians(p.longitude - p_lng) / 2), 2)
        )) <= p_radius_km
  order by 6371 * 2 * asin(sqrt(
          power(sin(radians(p.latitude - p_lat) / 2), 2)
        + cos(radians(p_lat)) * cos(radians(p.latitude))
        * power(sin(radians(p.longitude - p_lng) / 2), 2)
        ))
  limit greatest(1, least(coalesce(p_limit, 50), 200));
$$;

-- ---------------------------------------------------------------------------
-- Admin aggregates. Kept server-side so the dashboard cannot invent numbers.
-- ---------------------------------------------------------------------------
create or replace function public.admin_dashboard_stats()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_result jsonb;
begin
  -- Staff calling with their own JWT, or an Edge Function that already checked
  -- the caller's role and is using the service role.
  if not (private.has_staff_role() or private.bypasses_guards()) then
    raise exception 'Staff access required' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'total_users', (select count(*) from public.profiles),
    'premium_users', (
      select count(distinct s.user_id) from public.subscriptions s
      where s.status = 'active' and s.expires_at > now()
    ),
    'total_pets', (select count(*) from public.pets),
    'available_pets', (
      select count(*) from public.pets
      where moderation_status = 'approved' and adoption_status = 'available'
    ),
    'pending_pets', (select count(*) from public.pets where moderation_status = 'pending'),
    'pending_shelters', (select count(*) from public.shelters where verification_status = 'pending'),
    'applications_open', (
      select count(*) from public.adoption_requests
      where status in ('submitted', 'under_review', 'home_visit_scheduled', 'foster_trial')
    ),
    'adoptions_completed', (
      select count(*) from public.adoption_requests where status = 'approved'
    ),
    'active_alerts', (select count(*) from public.emergency_alerts where status = 'active'),
    'revenue_bdt', coalesce((
      select sum(amount) from public.payments
      where status = 'paid' and currency = 'BDT'
    ), 0),
    'unverified_payments', (
      select count(*) from public.payments where status = 'pending' and method = 'bkash_manual'
    )
  ) into v_result;

  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- Housekeeping. Run from pg_cron (or a scheduled Edge Function) once per hour.
-- ---------------------------------------------------------------------------
create or replace function public.expire_subscriptions()
returns integer
language sql
security definer
set search_path = public, pg_temp
as $$
  with updated as (
    update public.subscriptions
       set status = 'expired'
     where status = 'active' and expires_at <= now()
    returning 1
  )
  select count(*)::integer from updated;
$$;
