-- pgTAP Security Regression Tests for Appointments and Community Posts
-- Run with: supabase test db

begin;
select plan(12);

-- Setup test roles & data
-- 1. Verify functions exist
select has_function('private', 'enforce_appointment_guards', 'Appointment guard function exists');
select has_function('private', 'enforce_community_post_guards', 'Community post guard function exists');

-- 2. Verify triggers exist
select has_trigger('public', 'appointments', 'appointments_guard_security', 'appointments_guard_security trigger exists');
select has_trigger('public', 'community_posts', 'community_posts_guard_security', 'community_posts_guard_security trigger exists');

-- 3. Invariants tests
-- Test appointment table structure
select columns_are(
  'public',
  'appointments',
  array['id', 'pet_id', 'application_id', 'requester_id', 'host_id', 'type', 'status', 'scheduled_at', 'time_slot', 'notes', 'created_at', 'updated_at'],
  'Appointments table has expected columns'
);

-- Test community_posts table structure
select columns_are(
  'public',
  'community_posts',
  array['id', 'author_id', 'pet_id', 'pet_name', 'title', 'story', 'image_url', 'tags', 'moderation_status', 'likes_count', 'comments_count', 'created_at', 'updated_at'],
  'Community posts table has expected columns'
);

-- Test constraints
select col_not_null('public', 'appointments', 'pet_id', 'pet_id cannot be null in appointments');
select col_not_null('public', 'appointments', 'requester_id', 'requester_id cannot be null in appointments');
select col_not_null('public', 'community_posts', 'author_id', 'author_id cannot be null in community_posts');
select col_not_null('public', 'community_posts', 'moderation_status', 'moderation_status cannot be null in community_posts');
select col_not_null('public', 'community_posts', 'likes_count', 'likes_count cannot be null in community_posts');
select col_not_null('public', 'community_posts', 'comments_count', 'comments_count cannot be null in community_posts');

select * from finish();
rollback;
