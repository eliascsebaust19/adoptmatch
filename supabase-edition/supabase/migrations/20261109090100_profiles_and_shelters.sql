-- 02 — Identity: profiles mirror auth.users 1:1.

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null default 'Pet Lover',
  email text,
  phone text,
  avatar_url text,
  bio text not null default '',
  location text not null default 'Dhaka, Bangladesh',
  preferred_pet_type text not null default 'All Pets',
  role public.user_role not null default 'adopter',
  status text not null default 'active',
  is_verified boolean not null default false,
  fcm_token text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_status_check check (status in ('active', 'suspended', 'banned'))
);

create unique index profiles_email_key on public.profiles (lower(email)) where email is not null;
create index profiles_role_idx on public.profiles (role);
create index profiles_name_trgm_idx on public.profiles (lower(full_name));

create trigger profiles_touch_updated_at
  before update on public.profiles
  for each row execute function private.touch_updated_at();

-- Every auth.users row gets a profile. The role is always `adopter`: accepting
-- a role from user metadata would let anyone sign up as an admin.
create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.profiles (id, full_name, email, phone, avatar_url)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data ->> 'full_name', ''),
      nullif(new.raw_user_meta_data ->> 'name', ''),
      nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
      'Pet Lover'
    ),
    new.email,
    new.phone,
    nullif(new.raw_user_meta_data ->> 'avatar_url', '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- Shelters are owned by a profile. One owner may run one shelter in this app.
create table public.shelters (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  name text not null,
  about text not null default '',
  address text not null default '',
  city text not null default 'Dhaka',
  phone text,
  email text,
  logo_url text,
  verification_status public.shelter_status not null default 'pending',
  verified_at timestamptz,
  rating numeric(2, 1) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint shelters_rating_range check (rating >= 0 and rating <= 5)
);

create unique index shelters_one_per_owner on public.shelters (owner_id);
create index shelters_status_idx on public.shelters (verification_status);

create trigger shelters_touch_updated_at
  before update on public.shelters
  for each row execute function private.touch_updated_at();

-- A shelter's trust level is a staff decision, never a self-service field.
create or replace function private.enforce_shelter_verification()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not (private.bypasses_guards() or private.has_staff_role()) then
    if tg_op = 'INSERT' then
      new.verification_status := 'pending';
      new.verified_at := null;
    else
      new.verification_status := old.verification_status;
      new.verified_at := old.verified_at;
      new.rating := old.rating;
    end if;
  end if;
  return new;
end;
$$;

create trigger shelters_guard_verification
  before insert or update on public.shelters
  for each row execute function private.enforce_shelter_verification();

-- Community posts and listings need an author name without exposing emails and
-- phone numbers. This view is owned by the migration role and is deliberately
-- readable by `anon`; it selects a fixed, non-sensitive column list.
create or replace view public.public_profiles as
select
  p.id,
  p.full_name,
  p.avatar_url,
  p.role,
  p.location,
  p.is_verified
from public.profiles p;

grant select on public.public_profiles to anon, authenticated;
