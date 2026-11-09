-- 01 — Extensions, enums, and the private helper schema.
--
-- Supabase records applied migrations, so each file runs exactly once per
-- project. Applying it again by hand is not supported; `supabase db reset`
-- rebuilds from scratch instead.

create extension if not exists pgcrypto;

-- Helpers live outside `public` so PostgREST never exposes them as RPC routes.
create schema if not exists private;

create type public.user_role as enum (
  'adopter', 'foster', 'pet_owner', 'shelter', 'moderator', 'admin', 'super_admin'
);

create type public.shelter_status as enum ('pending', 'approved', 'rejected', 'suspended');

create type public.adoption_status as enum (
  'available', 'foster', 'pending', 'adopted', 'archived'
);

create type public.moderation_status as enum ('pending', 'approved', 'rejected', 'flagged');

create type public.application_status as enum (
  'draft', 'submitted', 'under_review', 'home_visit_scheduled',
  'foster_trial', 'approved', 'rejected', 'withdrawn'
);

create type public.appointment_type as enum (
  'shelter_visit', 'home_visit', 'vet_checkup', 'foster_intro'
);

create type public.appointment_status as enum (
  'requested', 'confirmed', 'completed', 'cancelled', 'no_show'
);

create type public.payment_status as enum (
  'pending', 'processing', 'paid', 'failed', 'cancelled', 'refunded', 'disputed'
);

create type public.payment_method as enum ('sslcommerz', 'bkash_manual');

create type public.subscription_status as enum ('active', 'expired', 'cancelled');

create type public.alert_status as enum ('active', 'resolved', 'expired');

-- Updated-at bookkeeping used by every mutable table.
create or replace function private.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Role helpers. Every policy and trigger reads the role from the JWT, never
-- from a client-supplied row field. `app_role` is injected by the custom access
-- token hook in 20261109091000_functions_and_hooks.sql.
-- ---------------------------------------------------------------------------

create or replace function private.current_app_role()
returns text
language sql
stable
as $$
  select coalesce(nullif(auth.jwt() ->> 'app_role', ''), 'anon');
$$;

create or replace function private.has_staff_role()
returns boolean
language sql
stable
as $$
  select private.current_app_role() in ('moderator', 'admin', 'super_admin');
$$;

create or replace function private.is_admin_role()
returns boolean
language sql
stable
as $$
  select private.current_app_role() in ('admin', 'super_admin');
$$;

-- Storage objects are written under `{user_id}/...`; this checks the first
-- path segment without trusting anything else in the object name.
create or replace function private.owns_storage_prefix(object_name text)
returns boolean
language sql
stable
as $$
  select auth.uid() is not null
     and split_part(coalesce(object_name, ''), '/', 1) = auth.uid()::text;
$$;

-- Guard triggers must not fight the trusted paths. Edge Functions write with the
-- service role (its JWT claim is `role = service_role`), and migrations/seed run
-- as the session owner. Inside a SECURITY DEFINER function `current_user` is the
-- function owner, so the session role is the only reliable signal here.
create or replace function private.bypasses_guards()
returns boolean
language sql
stable
as $$
  select session_user in ('postgres', 'supabase_admin')
      or coalesce(auth.jwt() ->> 'role', '') = 'service_role';
$$;
