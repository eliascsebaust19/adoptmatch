-- 12 — Storage buckets and their policies.
--
-- Convention: every object is written under `{owner}/...` so a single prefix
-- check covers uploads, and reads for shared content stay explicit.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('pet-images', 'pet-images', true, 5242880, array['image/jpeg', 'image/png', 'image/webp']),
  ('avatars', 'avatars', true, 2097152, array['image/jpeg', 'image/png', 'image/webp']),
  ('chat-attachments', 'chat-attachments', false, 10485760,
    array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']),
  ('application-docs', 'application-docs', false, 10485760,
    array['application/pdf', 'image/jpeg', 'image/png'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Chat attachments are stored under `{conversation_id}/{user_id}/{file}`, so a
-- participant check on the first segment is enough to read them.
create or replace function private.can_read_attachment(object_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_conversation uuid;
begin
  begin
    v_conversation := split_part(object_name, '/', 1)::uuid;
  exception when others then
    return false;
  end;

  return private.is_conversation_participant(v_conversation)
      or private.has_staff_role();
end;
$$;

-- Application documents are stored under `{application_id}/{user_id}/{file}`.
create or replace function private.can_read_application_doc(object_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_application uuid;
begin
  begin
    v_application := split_part(object_name, '/', 1)::uuid;
  exception when others then
    return false;
  end;

  return exists (
    select 1 from public.adoption_requests a
    where a.id = v_application
      and (
        a.applicant_id = auth.uid()
        or private.owns_pet(a.pet_id)
        or private.has_staff_role()
      )
  );
end;
$$;

-- pet-images ---------------------------------------------------------------
create policy "pet images: anyone reads"
  on storage.objects for select to anon, authenticated
  using (bucket_id = 'pet-images');

create policy "pet images: owner uploads under their prefix"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'pet-images'
    and (private.owns_storage_prefix(name) or private.has_staff_role())
  );

create policy "pet images: owner removes"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'pet-images'
    and (private.owns_storage_prefix(name) or private.has_staff_role())
  );

-- avatars -------------------------------------------------------------------
create policy "avatars: anyone reads"
  on storage.objects for select to anon, authenticated
  using (bucket_id = 'avatars');

create policy "avatars: owner uploads under their prefix"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and private.owns_storage_prefix(name));

create policy "avatars: owner updates"
  on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and private.owns_storage_prefix(name))
  with check (bucket_id = 'avatars' and private.owns_storage_prefix(name));

create policy "avatars: owner removes"
  on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and private.owns_storage_prefix(name));

-- chat attachments ----------------------------------------------------------
create policy "chat attachments: participants read"
  on storage.objects for select to authenticated
  using (bucket_id = 'chat-attachments' and private.can_read_attachment(name));

create policy "chat attachments: sender uploads"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'chat-attachments'
    and private.is_conversation_participant(split_part(name, '/', 1)::uuid)
    and split_part(name, '/', 2) = auth.uid()::text
  );

create policy "chat attachments: sender removes"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'chat-attachments'
    and private.can_read_attachment(name)
    and split_part(name, '/', 2) = auth.uid()::text
  );

-- application documents ------------------------------------------------------
create policy "application docs: applicant, owner or staff read"
  on storage.objects for select to authenticated
  using (bucket_id = 'application-docs' and private.can_read_application_doc(name));

create policy "application docs: applicant uploads"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'application-docs'
    and split_part(name, '/', 2) = auth.uid()::text
    and private.can_read_application_doc(name)
  );
