-- 11 — Row Level Security.
--
-- Rules of the house:
--   * the client never decides its own role; policies read JWT claims
--   * money rows are written only by Edge Functions using the service role
--   * anything a policy needs to know about another table goes through a
--     SECURITY DEFINER helper, so policies never recurse into each other

create or replace function private.owns_pet(p_pet_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.pets p where p.id = p_pet_id and p.owner_id = auth.uid()
  );
$$;

create or replace function private.pet_owner(p_pet_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select p.owner_id from public.pets p where p.id = p_pet_id;
$$;

alter table public.profiles enable row level security;
alter table public.shelters enable row level security;
alter table public.pets enable row level security;
alter table public.pet_images enable row level security;
alter table public.favorites enable row level security;
alter table public.swipes enable row level security;
alter table public.adoption_requests enable row level security;
alter table public.appointments enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.community_posts enable row level security;
alter table public.post_likes enable row level security;
alter table public.post_comments enable row level security;
alter table public.subscription_plans enable row level security;
alter table public.payments enable row level security;
alter table public.subscriptions enable row level security;
alter table public.health_passports enable row level security;
alter table public.vaccine_records enable row level security;
alter table public.emergency_alerts enable row level security;
alter table public.device_tokens enable row level security;
alter table public.notifications enable row level security;
alter table public.audit_logs enable row level security;

-- profiles ------------------------------------------------------------------
create policy "profiles: read own or staff"
  on public.profiles for select to authenticated
  using (id = auth.uid() or (select private.has_staff_role()));

-- No subquery on `profiles` here: a policy that reads its own table recurses.
-- Protected columns are enforced by the trigger below instead.
create policy "profiles: update own"
  on public.profiles for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy "profiles: staff update any"
  on public.profiles for update to authenticated
  using ((select private.has_staff_role()))
  with check ((select private.has_staff_role()));

-- Role changes go through an Edge Function with the service role; the trigger
-- below stops a self-service UPDATE from promoting anyone.
create or replace function private.enforce_profile_role()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'UPDATE' and not (private.bypasses_guards() or private.is_admin_role()) then
    new.role := old.role;
    new.is_verified := old.is_verified;
  end if;
  return new;
end;
$$;

create trigger profiles_guard_role
  before update on public.profiles
  for each row execute function private.enforce_profile_role();

-- shelters ------------------------------------------------------------------
create policy "shelters: public reads approved"
  on public.shelters for select to anon, authenticated
  using (
    verification_status = 'approved'
    or owner_id = auth.uid()
    or (select private.has_staff_role())
  );

create policy "shelters: owner creates"
  on public.shelters for insert to authenticated
  with check (owner_id = auth.uid());

create policy "shelters: owner updates"
  on public.shelters for update to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy "shelters: staff update any"
  on public.shelters for update to authenticated
  using ((select private.has_staff_role()))
  with check ((select private.has_staff_role()));

create policy "shelters: owner or staff delete"
  on public.shelters for delete to authenticated
  using (owner_id = auth.uid() or (select private.has_staff_role()));

-- pets ----------------------------------------------------------------------
create policy "pets: public reads approved listings"
  on public.pets for select to anon, authenticated
  using (
    (is_active and moderation_status = 'approved' and adoption_status <> 'archived')
    or owner_id = auth.uid()
    or (select private.has_staff_role())
  );

create policy "pets: owner creates"
  on public.pets for insert to authenticated
  with check (owner_id = auth.uid());

create policy "pets: owner updates"
  on public.pets for update to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy "pets: staff update any"
  on public.pets for update to authenticated
  using ((select private.has_staff_role()))
  with check ((select private.has_staff_role()));

create policy "pets: owner or staff delete"
  on public.pets for delete to authenticated
  using (owner_id = auth.uid() or (select private.has_staff_role()));

-- pet gallery ---------------------------------------------------------------
create policy "pet images: readable with the listing"
  on public.pet_images for select to anon, authenticated
  using (exists (select 1 from public.pets p where p.id = pet_id));

create policy "pet images: owner writes"
  on public.pet_images for insert to authenticated
  with check ((select private.owns_pet(pet_id)) or (select private.has_staff_role()));

create policy "pet images: owner deletes"
  on public.pet_images for delete to authenticated
  using ((select private.owns_pet(pet_id)) or (select private.has_staff_role()));

-- favorites and swipes ------------------------------------------------------
create policy "favorites: read own"
  on public.favorites for select to authenticated
  using (user_id = auth.uid());

create policy "favorites: insert own"
  on public.favorites for insert to authenticated
  with check (user_id = auth.uid());

create policy "favorites: delete own"
  on public.favorites for delete to authenticated
  using (user_id = auth.uid());

create policy "swipes: read own"
  on public.swipes for select to authenticated
  using (user_id = auth.uid());

create policy "swipes: insert own"
  on public.swipes for insert to authenticated
  with check (user_id = auth.uid());

create policy "swipes: delete own"
  on public.swipes for delete to authenticated
  using (user_id = auth.uid());

-- adoption applications -----------------------------------------------------
create policy "applications: applicant, listing owner or staff read"
  on public.adoption_requests for select to authenticated
  using (
    applicant_id = auth.uid()
    or (select private.owns_pet(pet_id))
    or (select private.has_staff_role())
  );

create policy "applications: applicant creates for an adoptable pet"
  on public.adoption_requests for insert to authenticated
  with check (
    applicant_id = auth.uid()
    and exists (
      select 1 from public.pets p
      where p.id = pet_id
        and p.moderation_status = 'approved'
        and p.adoption_status in ('available', 'foster')
    )
  );

create policy "applications: applicant or listing owner updates"
  on public.adoption_requests for update to authenticated
  using (
    applicant_id = auth.uid()
    or (select private.owns_pet(pet_id))
    or (select private.has_staff_role())
  )
  with check (
    applicant_id = auth.uid()
    or (select private.owns_pet(pet_id))
    or (select private.has_staff_role())
  );

create policy "applications: staff deletes"
  on public.adoption_requests for delete to authenticated
  using ((select private.has_staff_role()));

-- appointments --------------------------------------------------------------
create policy "appointments: parties read"
  on public.appointments for select to authenticated
  using (
    requester_id = auth.uid()
    or host_id = auth.uid()
    or (select private.has_staff_role())
  );

create policy "appointments: requester creates"
  on public.appointments for insert to authenticated
  with check (requester_id = auth.uid());

create policy "appointments: parties update"
  on public.appointments for update to authenticated
  using (
    requester_id = auth.uid()
    or host_id = auth.uid()
    or (select private.has_staff_role())
  )
  with check (
    requester_id = auth.uid()
    or host_id = auth.uid()
    or (select private.has_staff_role())
  );

-- messaging -----------------------------------------------------------------
create policy "conversations: participants read"
  on public.conversations for select to authenticated
  using (adopter_id = auth.uid() or owner_id = auth.uid() or (select private.has_staff_role()));

create policy "conversations: adopter starts a thread with the real owner"
  on public.conversations for insert to authenticated
  with check (
    adopter_id = auth.uid()
    and owner_id = (select private.pet_owner(pet_id))
    and owner_id <> auth.uid()
  );

create policy "messages: participants read"
  on public.messages for select to authenticated
  using ((select private.is_conversation_participant(conversation_id)));

create policy "messages: sender writes"
  on public.messages for insert to authenticated
  with check (
    sender_id = auth.uid()
    and (select private.is_conversation_participant(conversation_id))
  );

create policy "messages: participant marks read"
  on public.messages for update to authenticated
  using ((select private.is_conversation_participant(conversation_id)))
  with check ((select private.is_conversation_participant(conversation_id)));

create policy "messages: sender deletes own"
  on public.messages for delete to authenticated
  using (sender_id = auth.uid());

-- Marking a message read must not become an edit. Only `read_at` is mutable.
create or replace function private.enforce_message_immutability()
returns trigger
language plpgsql
as $$
begin
  if new.body is distinct from old.body
     or new.attachment_url is distinct from old.attachment_url
     or new.sender_id is distinct from old.sender_id
     or new.conversation_id is distinct from old.conversation_id
     or new.created_at is distinct from old.created_at then
    raise exception 'Messages can only be marked as read' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger messages_guard_immutability
  before update on public.messages
  for each row execute function private.enforce_message_immutability();

-- community -----------------------------------------------------------------
create policy "posts: public reads approved"
  on public.community_posts for select to anon, authenticated
  using (
    moderation_status = 'approved'
    or author_id = auth.uid()
    or (select private.has_staff_role())
  );

create policy "posts: author writes"
  on public.community_posts for insert to authenticated
  with check (author_id = auth.uid());

create policy "posts: author or staff update"
  on public.community_posts for update to authenticated
  using (author_id = auth.uid() or (select private.has_staff_role()))
  with check (author_id = auth.uid() or (select private.has_staff_role()));

create policy "posts: author or staff delete"
  on public.community_posts for delete to authenticated
  using (author_id = auth.uid() or (select private.has_staff_role()));

create policy "likes: signed in users read"
  on public.post_likes for select to authenticated
  using (true);

create policy "likes: insert own"
  on public.post_likes for insert to authenticated
  with check (user_id = auth.uid());

create policy "likes: delete own"
  on public.post_likes for delete to authenticated
  using (user_id = auth.uid());

create policy "comments: signed in users read"
  on public.post_comments for select to authenticated
  using (true);

create policy "comments: author writes"
  on public.post_comments for insert to authenticated
  with check (author_id = auth.uid());

create policy "comments: author or staff delete"
  on public.post_comments for delete to authenticated
  using (author_id = auth.uid() or (select private.has_staff_role()));

-- plans, payments, subscriptions -------------------------------------------
create policy "plans: public reads active"
  on public.subscription_plans for select to anon, authenticated
  using (is_active);

create policy "payments: own or staff read"
  on public.payments for select to authenticated
  using (user_id = auth.uid() or (select private.has_staff_role()));

create policy "subscriptions: own or staff read"
  on public.subscriptions for select to authenticated
  using (user_id = auth.uid() or (select private.has_staff_role()));

-- Deliberately no INSERT/UPDATE/DELETE policies on payments and subscriptions:
-- only the service role (Edge Function) writes them.

-- health passport -----------------------------------------------------------
create policy "passports: pet owner or staff read"
  on public.health_passports for select to authenticated
  using ((select private.owns_pet(pet_id)) or (select private.has_staff_role()));

create policy "passports: pet owner writes"
  on public.health_passports for insert to authenticated
  with check ((select private.owns_pet(pet_id)));

create policy "passports: pet owner updates"
  on public.health_passports for update to authenticated
  using ((select private.owns_pet(pet_id)) or (select private.has_staff_role()))
  with check ((select private.owns_pet(pet_id)) or (select private.has_staff_role()));

create policy "vaccines: readable with the passport"
  on public.vaccine_records for select to authenticated
  using (
    exists (
      select 1 from public.health_passports hp
      where hp.id = passport_id
        and ((select private.owns_pet(hp.pet_id)) or (select private.has_staff_role()))
    )
  );

create policy "vaccines: pet owner writes"
  on public.vaccine_records for insert to authenticated
  with check (
    exists (
      select 1 from public.health_passports hp
      where hp.id = passport_id and (select private.owns_pet(hp.pet_id))
    )
  );

create policy "vaccines: pet owner updates"
  on public.vaccine_records for update to authenticated
  using (
    exists (
      select 1 from public.health_passports hp
      where hp.id = passport_id and (select private.owns_pet(hp.pet_id))
    )
  )
  with check (
    exists (
      select 1 from public.health_passports hp
      where hp.id = passport_id and (select private.owns_pet(hp.pet_id))
    )
  );

-- emergency alerts ----------------------------------------------------------
create policy "alerts: public reads active"
  on public.emergency_alerts for select to anon, authenticated
  using (
    status = 'active'
    or reporter_id = auth.uid()
    or (select private.has_staff_role())
  );

create policy "alerts: reporter creates"
  on public.emergency_alerts for insert to authenticated
  with check (reporter_id = auth.uid());

create policy "alerts: reporter or staff update"
  on public.emergency_alerts for update to authenticated
  using (reporter_id = auth.uid() or (select private.has_staff_role()))
  with check (reporter_id = auth.uid() or (select private.has_staff_role()));

create policy "alerts: reporter or staff delete"
  on public.emergency_alerts for delete to authenticated
  using (reporter_id = auth.uid() or (select private.has_staff_role()));

-- notifications -------------------------------------------------------------
create policy "device tokens: own"
  on public.device_tokens for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "notifications: own read"
  on public.notifications for select to authenticated
  using (user_id = auth.uid());

create policy "notifications: own mark read"
  on public.notifications for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- audit ---------------------------------------------------------------------
create policy "audit: staff read"
  on public.audit_logs for select to authenticated
  using ((select private.has_staff_role()));

-- RPC grants ----------------------------------------------------------------
grant execute on function public.pets_nearby(double precision, double precision, double precision, integer) to anon, authenticated;
grant execute on function public.my_subscription() to authenticated;
revoke execute on function public.my_subscription() from anon;
grant execute on function public.admin_dashboard_stats() to authenticated;
grant execute on function public.expire_subscriptions() to service_role;
