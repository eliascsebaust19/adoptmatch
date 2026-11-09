-- 09 — Push tokens, in-app notifications, and the admin audit trail.

create table public.device_tokens (
  user_id uuid not null references public.profiles (id) on delete cascade,
  token text not null,
  platform text not null default 'android',
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  primary key (user_id, token),
  constraint device_tokens_platform_check check (platform in ('android', 'ios', 'web'))
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  title text not null,
  body text not null default '',
  category text not null default 'general',
  data jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index notifications_user_idx on public.notifications (user_id, created_at desc);

-- Append-only. Writes come from Edge Functions with the service role; staff can
-- read, nobody can edit or delete through the API.
create table public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles (id) on delete set null,
  actor_email text,
  action text not null,
  target_table text,
  target_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index audit_logs_created_idx on public.audit_logs (created_at desc);
create index audit_logs_actor_idx on public.audit_logs (actor_id, created_at desc);

create or replace function public.log_audit(
  p_actor_id uuid,
  p_action text,
  p_target_table text default null,
  p_target_id text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  insert into public.audit_logs (actor_id, actor_email, action, target_table, target_id, metadata)
  values (
    p_actor_id,
    (select email from public.profiles where id = p_actor_id),
    p_action,
    p_target_table,
    p_target_id,
    coalesce(p_metadata, '{}'::jsonb)
  );
$$;

revoke execute on function public.log_audit(uuid, text, text, text, jsonb) from public, anon, authenticated;
grant execute on function public.log_audit(uuid, text, text, text, jsonb) to service_role;
