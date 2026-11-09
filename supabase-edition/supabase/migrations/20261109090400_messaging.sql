-- 05 — Direct messaging between an adopter and a listing owner, scoped to a pet.

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null references public.pets (id) on delete cascade,
  adopter_id uuid not null references public.profiles (id) on delete cascade,
  owner_id uuid not null references public.profiles (id) on delete cascade,
  last_message text not null default '',
  last_message_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint conversations_distinct_parties check (adopter_id <> owner_id)
);

create unique index conversations_pair_key on public.conversations (pet_id, adopter_id, owner_id);
create index conversations_adopter_idx on public.conversations (adopter_id, last_message_at desc);
create index conversations_owner_idx on public.conversations (owner_id, last_message_at desc);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_id uuid not null references public.profiles (id) on delete cascade,
  body text not null default '',
  attachment_url text,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  constraint messages_body_or_attachment check (
    length(trim(body)) > 0 or attachment_url is not null
  )
);

create index messages_conversation_idx on public.messages (conversation_id, created_at desc);

create or replace function private.is_conversation_participant(conversation uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.conversations c
    where c.id = conversation
      and (c.adopter_id = auth.uid() or c.owner_id = auth.uid())
  );
$$;

-- A message must come from one of the two parties, and it updates the thread
-- preview in the same transaction so the inbox never shows a stale line.
create or replace function private.handle_new_message()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_allowed boolean;
begin
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

create trigger messages_after_insert
  after insert on public.messages
  for each row execute function private.handle_new_message();
