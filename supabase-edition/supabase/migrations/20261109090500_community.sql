-- 06 — Happy Tails community feed: posts, likes, comments.

create table public.community_posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles (id) on delete cascade,
  pet_id uuid references public.pets (id) on delete set null,
  pet_name text not null default '',
  title text not null,
  story text not null default '',
  image_url text,
  tags text[] not null default '{}',
  moderation_status public.moderation_status not null default 'approved',
  likes_count integer not null default 0,
  comments_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint community_posts_title_length check (length(trim(title)) between 3 and 160)
);

create index community_posts_feed_idx on public.community_posts (moderation_status, created_at desc);
create index community_posts_author_idx on public.community_posts (author_id, created_at desc);

create trigger community_posts_touch_updated_at
  before update on public.community_posts
  for each row execute function private.touch_updated_at();

create table public.post_likes (
  post_id uuid not null references public.community_posts (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table public.post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.community_posts (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now(),
  constraint post_comments_body_length check (length(trim(body)) between 1 and 1000)
);

create index post_comments_post_idx on public.post_comments (post_id, created_at);

-- Counters are maintained by triggers so two clients liking at once cannot
-- write a stale number.
create or replace function private.sync_like_count()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_post uuid;
begin
  -- `new` is unassigned on DELETE and `old` on INSERT; branch before touching either.
  v_post := case when tg_op = 'DELETE' then old.post_id else new.post_id end;

  update public.community_posts p
     set likes_count = (select count(*) from public.post_likes l where l.post_id = p.id)
   where p.id = v_post;
  return null;
end;
$$;

create trigger post_likes_sync_count
  after insert or delete on public.post_likes
  for each row execute function private.sync_like_count();

create or replace function private.sync_comment_count()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_post uuid;
begin
  v_post := case when tg_op = 'DELETE' then old.post_id else new.post_id end;

  update public.community_posts p
     set comments_count = (select count(*) from public.post_comments c where c.post_id = p.id)
   where p.id = v_post;
  return null;
end;
$$;

create trigger post_comments_sync_count
  after insert or delete on public.post_comments
  for each row execute function private.sync_comment_count();
