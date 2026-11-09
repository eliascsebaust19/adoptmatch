-- 08 — Health passport and lost-pet alerts.

create table public.health_passports (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null references public.pets (id) on delete cascade,
  microchip_id text,
  blood_type text not null default '',
  allergies text not null default '',
  emergency_phone text,
  emergency_clinic text,
  reminders_active boolean not null default true,
  qr_hash text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index health_passports_pet_key on public.health_passports (pet_id);

create trigger health_passports_touch_updated_at
  before update on public.health_passports
  for each row execute function private.touch_updated_at();

create table public.vaccine_records (
  id uuid primary key default gen_random_uuid(),
  passport_id uuid not null references public.health_passports (id) on delete cascade,
  title text not null,
  administered_on date not null,
  next_due_on date,
  clinic_name text not null default '',
  veterinarian text not null default '',
  batch_number text not null default '',
  is_completed boolean not null default false,
  created_at timestamptz not null default now()
);

create index vaccine_records_passport_idx on public.vaccine_records (passport_id, administered_on desc);

create table public.emergency_alerts (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles (id) on delete cascade,
  pet_id uuid references public.pets (id) on delete set null,
  pet_name text not null,
  pet_breed text not null default '',
  image_url text,
  last_seen_location text not null,
  latitude double precision not null,
  longitude double precision not null,
  radius_km integer not null default 5,
  reward_bdt integer not null default 0,
  description text not null default '',
  contact_phone text,
  status public.alert_status not null default 'active',
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint emergency_alerts_radius_check check (radius_km between 1 and 50),
  constraint emergency_alerts_reward_check check (reward_bdt >= 0),
  constraint emergency_alerts_latitude_range check (latitude between -90 and 90),
  constraint emergency_alerts_longitude_range check (longitude between -180 and 180)
);

create index emergency_alerts_active_idx on public.emergency_alerts (status, created_at desc);
create index emergency_alerts_reporter_idx on public.emergency_alerts (reporter_id, created_at desc);

create trigger emergency_alerts_touch_updated_at
  before update on public.emergency_alerts
  for each row execute function private.touch_updated_at();

-- Alerts are a trust feature: only the reporter or staff can resolve one.
create or replace function private.enforce_alert_ownership()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if private.bypasses_guards() or private.has_staff_role() then
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.status := 'active';
    new.resolved_at := null;
    return new;
  end if;

  if old.reporter_id <> auth.uid() then
    raise exception 'Only the reporter can update this alert' using errcode = '42501';
  end if;

  new.reporter_id := old.reporter_id;
  return new;
end;
$$;

create trigger emergency_alerts_guard
  before insert or update on public.emergency_alerts
  for each row execute function private.enforce_alert_ownership();
