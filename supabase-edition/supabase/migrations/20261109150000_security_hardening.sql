-- 13 — Security Hardening: Appointment verification and Community Post integrity guards.

-- ---------------------------------------------------------------------------
-- 1. Appointment Security Guards
--
-- Invariants enforced:
--   * On INSERT: host must be the pet's actual owner. Requester must be auth.uid().
--     Requester cannot book an appointment for their own pet.
--     If application_id is provided, it must belong to this pet and requester.
--     Initial status is locked to 'requested'.
--   * On UPDATE: relations (pet_id, requester_id, host_id, application_id)
--     are immutable.
--   * Requester can only cancel ('cancelled') or edit notes/schedule while requested.
--   * Host (pet owner) can confirm, complete, cancel, or mark no-show.
--   * Unauthorized third-parties cannot modify the appointment.
-- ---------------------------------------------------------------------------

create or replace function private.enforce_appointment_guards()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actual_owner uuid;
  v_app_pet uuid;
  v_app_applicant uuid;
begin
  -- Service role and migrations bypass trigger guards
  if private.bypasses_guards() then
    return new;
  end if;

  if tg_op = 'INSERT' then
    -- Verify requester identity
    if not private.has_staff_role() and (new.requester_id is null or new.requester_id <> auth.uid()) then
      raise exception 'Requester must be the current authenticated user' using errcode = '42501';
    end if;

    -- Lookup actual pet owner
    select p.owner_id into v_actual_owner from public.pets p where p.id = new.pet_id;
    if v_actual_owner is null then
      raise exception 'Pet not found' using errcode = '22023';
    end if;

    -- Host must be the pet's actual owner
    if new.host_id is not null and new.host_id <> v_actual_owner then
      raise exception 'Host must be the actual owner of the pet' using errcode = '42501';
    end if;
    new.host_id := v_actual_owner;

    -- Requester cannot book an appointment with themselves for their own pet
    if new.requester_id = new.host_id then
      raise exception 'Pet owner cannot book an appointment for their own pet' using errcode = '22023';
    end if;

    -- If application_id is provided, verify it links to this pet and requester
    if new.application_id is not null then
      select pet_id, applicant_id into v_app_pet, v_app_applicant
        from public.adoption_requests where id = new.application_id;
      if v_app_pet is distinct from new.pet_id or v_app_applicant is distinct from new.requester_id then
        raise exception 'Application does not match this pet and requester' using errcode = '22023';
      end if;
    end if;

    -- Normal users always start in 'requested' status
    if not private.has_staff_role() then
      new.status := 'requested';
    end if;

    return new;
  end if;

  -- ON UPDATE:
  -- Prevent tampering with relationship identifiers
  if new.pet_id is distinct from old.pet_id
     or new.requester_id is distinct from old.requester_id
     or new.host_id is distinct from old.host_id
     or new.application_id is distinct from old.application_id then
    raise exception 'Unauthorized modification of appointment relations (pet, requester, host, application)' using errcode = '42501';
  end if;

  -- Staff can modify any appointment fields and status transitions
  if private.has_staff_role() then
    return new;
  end if;

  -- Caller must be requester or host
  if auth.uid() <> old.requester_id and auth.uid() <> old.host_id then
    raise exception 'Not authorized to update this appointment' using errcode = '42501';
  end if;

  -- If caller is the requester (adopter):
  if auth.uid() = old.requester_id and auth.uid() <> old.host_id then
    if new.status is distinct from old.status then
      if new.status <> 'cancelled' then
        raise exception 'Requesters can only cancel an appointment' using errcode = '42501';
      end if;
      if old.status in ('completed', 'cancelled', 'no_show') then
        raise exception 'Cannot cancel a completed or already closed appointment' using errcode = '22023';
      end if;
    end if;
    -- Requester cannot change scheduled_at if already confirmed
    if old.status = 'confirmed' and (new.scheduled_at is distinct from old.scheduled_at or new.time_slot is distinct from old.time_slot) then
      raise exception 'Cannot reschedule a confirmed appointment without host action' using errcode = '42501';
    end if;
    return new;
  end if;

  -- If caller is the host (pet owner):
  if auth.uid() = old.host_id then
    if new.status is distinct from old.status then
      if old.status = 'cancelled' then
        raise exception 'Cannot update a cancelled appointment' using errcode = '22023';
      end if;
      if old.status = 'completed' and new.status <> 'completed' then
        raise exception 'Cannot change status of a completed appointment' using errcode = '22023';
      end if;
      if new.status not in ('confirmed', 'completed', 'cancelled', 'no_show') then
        raise exception 'Invalid status transition for host' using errcode = '42501';
      end if;
    end if;
    return new;
  end if;

  return new;
end;
$$;

drop trigger if exists appointments_guard_security on public.appointments;
create trigger appointments_guard_security
  before insert or update on public.appointments
  for each row execute function private.enforce_appointment_guards();


-- ---------------------------------------------------------------------------
-- 2. Community Post Security Guards
--
-- Invariants enforced:
--   * On INSERT: normal author cannot spoof author_id, cannot set moderation_status
--     (defaults to 'pending'), and cannot set non-zero likes_count or comments_count.
--   * On UPDATE: author_id is immutable.
--   * Only staff or internal SECURITY DEFINER counter triggers (sync_like_count,
--     sync_comment_count) can mutate likes_count or comments_count.
--   * Only staff or service_role can mutate moderation_status.
-- ---------------------------------------------------------------------------

create or replace function private.enforce_community_post_guards()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_is_staff boolean;
begin
  if private.bypasses_guards() then
    return new;
  end if;

  v_is_staff := private.has_staff_role();

  if tg_op = 'INSERT' then
    if not v_is_staff then
      new.author_id := auth.uid();
      new.likes_count := 0;
      new.comments_count := 0;
      new.moderation_status := 'pending';
    else
      new.author_id := coalesce(new.author_id, auth.uid());
      new.likes_count := coalesce(new.likes_count, 0);
      new.comments_count := coalesce(new.comments_count, 0);
      new.moderation_status := coalesce(new.moderation_status, 'approved');
    end if;
    return new;
  end if;

  -- ON UPDATE
  new.author_id := old.author_id;

  -- Like counter guard: only internal triggers (running as postgres/supabase_admin) or staff can mutate
  if new.likes_count is distinct from old.likes_count then
    if current_user not in ('postgres', 'supabase_admin') and not v_is_staff then
      raise exception 'likes_count cannot be directly modified' using errcode = '42501';
    end if;
  end if;

  -- Comment counter guard: only internal triggers or staff can mutate
  if new.comments_count is distinct from old.comments_count then
    if current_user not in ('postgres', 'supabase_admin') and not v_is_staff then
      raise exception 'comments_count cannot be directly modified' using errcode = '42501';
    end if;
  end if;

  -- Moderation status guard: only staff or superusers can change status
  if new.moderation_status is distinct from old.moderation_status then
    if not v_is_staff and current_user not in ('postgres', 'supabase_admin') then
      raise exception 'Only staff can change moderation_status' using errcode = '42501';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists community_posts_guard_security on public.community_posts;
create trigger community_posts_guard_security
  before insert or update on public.community_posts
  for each row execute function private.enforce_community_post_guards();
