-- 03 — Listings: pets, gallery images, favorites and swipe decisions.

create table public.pets (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  shelter_id uuid references public.shelters (id) on delete set null,
  name text not null,
  species text not null,
  breed text not null default 'Mixed',
  age_months integer not null default 12,
  gender text not null default 'unknown',
  size text not null default 'medium',
  weight_kg numeric(5, 2),
  story text not null default '',
  medical_history text not null default '',
  vaccination_status text not null default 'unknown',
  is_vaccinated boolean not null default false,
  is_neutered boolean not null default false,
  is_house_trained boolean not null default false,
  is_kid_safe boolean not null default false,
  is_apartment_friendly boolean not null default false,
  is_urgent boolean not null default false,
  is_featured boolean not null default false,
  is_foster boolean not null default false,
  adoption_fee numeric(10, 2) not null default 0,
  adoption_status public.adoption_status not null default 'available',
  moderation_status public.moderation_status not null default 'pending',
  image_url text,
  qr_hash text,
  city text not null default 'Dhaka',
  latitude double precision,
  longitude double precision,
  contact_phone text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint pets_age_non_negative check (age_months >= 0),
  constraint pets_gender_check check (gender in ('male', 'female', 'unknown')),
  constraint pets_size_check check (size in ('small', 'medium', 'large', 'giant')),
  constraint pets_coordinates_pair check (
    (latitude is null and longitude is null) or (latitude is not null and longitude is not null)
  ),
  constraint pets_latitude_range check (latitude is null or (latitude between -90 and 90)),
  constraint pets_longitude_range check (longitude is null or (longitude between -180 and 180))
);

create index pets_feed_idx on public.pets (moderation_status, adoption_status, created_at desc);
create index pets_owner_idx on public.pets (owner_id);
create index pets_shelter_idx on public.pets (shelter_id);
create index pets_species_idx on public.pets (species);
create index pets_city_idx on public.pets (city);
create index pets_name_trgm_idx on public.pets (lower(name));

create trigger pets_touch_updated_at
  before update on public.pets
  for each row execute function private.touch_updated_at();

-- Moderation, featured placement and premium-looking fields are staff decisions.
-- A listing owner can edit content but cannot approve their own listing.
create or replace function private.enforce_pet_moderation()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if private.bypasses_guards() or private.has_staff_role() then
    return new;
  end if;

  -- `old` is only assigned on UPDATE; touching it during INSERT raises.
  if tg_op = 'INSERT' then
    new.moderation_status := 'pending';
    new.is_featured := false;
    return new;
  end if;

  new.moderation_status := old.moderation_status;
  new.is_featured := old.is_featured;
  new.adoption_status := old.adoption_status;
  new.owner_id := old.owner_id;
  new.shelter_id := old.shelter_id;

  return new;
end;
$$;

create trigger pets_guard_moderation
  before insert or update on public.pets
  for each row execute function private.enforce_pet_moderation();

create table public.pet_images (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null references public.pets (id) on delete cascade,
  url text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create index pet_images_pet_idx on public.pet_images (pet_id, sort_order);

create table public.favorites (
  user_id uuid not null references public.profiles (id) on delete cascade,
  pet_id uuid not null references public.pets (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, pet_id)
);

create index favorites_pet_idx on public.favorites (pet_id);

-- Swipes are separate from favorites: liking a card is not a bookmark.
create table public.swipes (
  user_id uuid not null references public.profiles (id) on delete cascade,
  pet_id uuid not null references public.pets (id) on delete cascade,
  direction text not null check (direction in ('like', 'dislike')),
  created_at timestamptz not null default now(),
  primary key (user_id, pet_id)
);

-- Feed view: listing fields plus shelter branding and the caller's favorite
-- flag. `security_invoker` keeps the pets RLS policies in force.
create or replace view public.pets_feed
with (security_invoker = true)
as
select
  p.id,
  p.owner_id,
  p.name,
  p.species,
  p.breed,
  p.age_months,
  p.gender,
  p.size,
  p.weight_kg,
  p.story,
  p.medical_history,
  p.is_vaccinated,
  p.is_neutered,
  p.is_house_trained,
  p.is_kid_safe,
  p.is_apartment_friendly,
  p.is_urgent,
  p.is_featured,
  p.is_foster,
  p.adoption_fee,
  p.adoption_status,
  p.moderation_status,
  p.image_url,
  p.qr_hash,
  p.city,
  p.latitude,
  p.longitude,
  p.created_at,
  coalesce(s.name, owner.full_name, 'Independent rescuer') as shelter_name,
  s.phone as shelter_phone,
  s.address as shelter_address,
  coalesce(s.rating, 0) as shelter_rating,
  exists (
    select 1 from public.favorites f
    where f.pet_id = p.id and f.user_id = auth.uid()
  ) as is_favorite
from public.pets p
left join public.shelters s on s.id = p.shelter_id
left join public.public_profiles owner on owner.id = p.owner_id;
