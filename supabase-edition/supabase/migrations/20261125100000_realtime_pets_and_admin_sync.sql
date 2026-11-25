-- 16 — Real-time pet feed publication, gallery aggregation, and soft-archive visibility.

alter table public.pets replica identity full;
alter table public.pet_images replica identity full;

do $$
begin
  alter publication supabase_realtime add table public.pets;
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.pet_images;
exception
  when duplicate_object then null;
end $$;

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
  ) as is_favorite,
  coalesce(
    (
      select jsonb_agg(pi.url order by pi.sort_order)
      from public.pet_images pi
      where pi.pet_id = p.id
    ),
    '[]'::jsonb
  ) as gallery_urls
from public.pets p
left join public.shelters s on s.id = p.shelter_id
left join public.public_profiles owner on owner.id = p.owner_id
where p.is_active = true and p.adoption_status <> 'archived';
