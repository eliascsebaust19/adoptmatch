-- 15 — Schema Optimization, Indexing, and Profile State Protection
--
-- Invariants enforced:
--   1. Profiles: Normal users cannot modify their own account status (e.g. self-unbanning).
--      Role, is_verified, and status remain strictly protected.
--   2. Messages: Service-role and automated triggers can deliver system messages.
--   3. Indexing: Adds performance indexes on swipes (pet_id), appointments (status, scheduled_at),
--      profiles (role), and community_posts tags (GIN).

-- 1. Profiles Status & Role Protection
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
    new.status := old.status;
  end if;
  return new;
end;
$$;

-- 2. Message Trigger Resilience for Service Role
create or replace function private.handle_new_message()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_allowed boolean;
begin
  if private.bypasses_guards() then
    update public.conversations
       set last_message = case
             when length(trim(new.body)) > 0 then left(new.body, 160)
             else '[attachment]'
           end,
           last_message_at = new.created_at
     where id = new.conversation_id;
    return new;
  end if;

  select exists (
    select 1 from public.conversations c
    where c.id = new.conversation_id
      and new.sender_id = auth.uid()
      and (c.adopter_id = auth.uid() or c.owner_id = auth.uid())
  ) into v_allowed;

  if not v_allowed then
    raise exception 'Sender is not part of this conversation' using errcode = '42501';
  end if;

  update public.conversations
     set last_message = case
           when length(trim(new.body)) > 0 then left(new.body, 160)
           else '[attachment]'
         end,
         last_message_at = new.created_at
   where id = new.conversation_id;

  return new;
end;
$$;

-- 3. Additional Performance Indexes
create index if not exists swipes_pet_idx on public.swipes (pet_id);
create index if not exists profiles_role_idx on public.profiles (role);
create index if not exists appointments_status_idx on public.appointments (status, scheduled_at desc);
create index if not exists community_posts_tags_idx on public.community_posts using gin (tags);
