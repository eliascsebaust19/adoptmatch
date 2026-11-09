-- 04 — Adoption workflow: applications, review trail, appointments.

create table public.adoption_requests (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null references public.pets (id) on delete cascade,
  applicant_id uuid not null references public.profiles (id) on delete cascade,

  -- The 28-field dossier the Flutter form already collects. Kept as jsonb
  -- because the questionnaire changes more often than the workflow does.
  applicant_data jsonb not null default '{}'::jsonb,
  signature_data text,
  is_e_signed boolean not null default false,

  status public.application_status not null default 'submitted',
  reviewer_id uuid references public.profiles (id) on delete set null,
  reviewer_notes text,
  home_visit_at timestamptz,
  decided_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint adoption_requests_signature_check check (
    not is_e_signed or (signature_data is not null and length(trim(signature_data)) > 0)
  )
);

create index adoption_requests_pet_idx on public.adoption_requests (pet_id);
create index adoption_requests_applicant_idx on public.adoption_requests (applicant_id, created_at desc);
create index adoption_requests_status_idx on public.adoption_requests (status);

-- One live application per person per pet. A rejected one can be replaced.
create unique index adoption_requests_one_live_per_pet
  on public.adoption_requests (pet_id, applicant_id)
  where status in ('draft', 'submitted', 'under_review', 'home_visit_scheduled', 'foster_trial');

create trigger adoption_requests_touch_updated_at
  before update on public.adoption_requests
  for each row execute function private.touch_updated_at();

-- Applicants may withdraw, but only the listing owner or staff can move an
-- application through review.
create or replace function private.enforce_application_transitions()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_is_listing_owner boolean;
begin
  if tg_op = 'INSERT' then
    new.status := 'submitted';
    new.reviewer_id := null;
    new.reviewer_notes := null;
    new.decided_at := null;
    return new;
  end if;

  new.applicant_id := old.applicant_id;
  new.pet_id := old.pet_id;

  if private.bypasses_guards() or private.has_staff_role() then
    return new;
  end if;

  select exists (
    select 1 from public.pets p
    where p.id = old.pet_id and p.owner_id = auth.uid()
  ) into v_is_listing_owner;

  if v_is_listing_owner then
    -- A shelter may review, but a decision must be recorded with a reason.
    if new.status in ('rejected', 'approved') and old.status is distinct from new.status then
      if coalesce(length(trim(new.reviewer_notes)), 0) = 0 then
        raise exception 'A decision needs reviewer_notes' using errcode = '22023';
      end if;
      new.decided_at := now();
      new.reviewer_id := coalesce(new.reviewer_id, auth.uid());
    end if;
    return new;
  end if;

  if old.applicant_id <> auth.uid() then
    raise exception 'Not allowed to update this application' using errcode = '42501';
  end if;

  if new.status <> 'withdrawn' then
    raise exception 'Applicants can only withdraw an application' using errcode = '42501';
  end if;

  new.reviewer_id := old.reviewer_id;
  new.reviewer_notes := old.reviewer_notes;
  new.home_visit_at := old.home_visit_at;
  new.decided_at := old.decided_at;
  return new;
end;
$$;

create trigger adoption_requests_guard_transitions
  before insert or update on public.adoption_requests
  for each row execute function private.enforce_application_transitions();

create table public.appointments (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null references public.pets (id) on delete cascade,
  application_id uuid references public.adoption_requests (id) on delete set null,
  requester_id uuid not null references public.profiles (id) on delete cascade,
  host_id uuid references public.profiles (id) on delete set null,
  type public.appointment_type not null default 'shelter_visit',
  status public.appointment_status not null default 'requested',
  scheduled_at timestamptz not null,
  time_slot text not null default '',
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index appointments_requester_idx on public.appointments (requester_id, scheduled_at desc);
create index appointments_host_idx on public.appointments (host_id, scheduled_at desc);
create index appointments_pet_idx on public.appointments (pet_id);

create trigger appointments_touch_updated_at
  before update on public.appointments
  for each row execute function private.touch_updated_at();
