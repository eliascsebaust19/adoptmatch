-- pgTAP Security Regression Tests for Appointments, Profiles, and Storage Security
-- Run with: supabase test db

begin;
select plan(18);

-- 1. Security guard functions exist
select has_function('private', 'enforce_appointment_guards', 'Appointment guard function exists');
select has_function('private', 'enforce_community_post_guards', 'Community post guard function exists');
select has_function('private', 'enforce_profile_role', 'Profile role protection function exists');
select has_function('private', 'can_read_attachment', 'Storage attachment access check function exists');
select has_function('private', 'can_read_application_doc', 'Storage application document access check function exists');

-- 2. Security triggers exist
select has_trigger('public', 'appointments', 'appointments_guard_security', 'appointments_guard_security trigger exists');
select has_trigger('public', 'community_posts', 'community_posts_guard_security', 'community_posts_guard_security trigger exists');
select has_trigger('public', 'profiles', 'profiles_guard_role', 'profiles_guard_role trigger exists');

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

-- Test payment table structure
select columns_are(
  'public',
  'payments',
  array['id', 'tran_id', 'user_id', 'plan_id', 'amount', 'currency', 'method', 'status', 'val_id', 'bank_tran_id', 'card_type', 'sender_phone', 'trx_id', 'gateway_payload', 'failure_reason', 'applied_at', 'verified_at', 'verified_by', 'created_at', 'updated_at'],
  'Payments table has expected columns'
);

-- Test constraints
select col_not_null('public', 'appointments', 'pet_id', 'pet_id cannot be null in appointments');
select col_not_null('public', 'appointments', 'requester_id', 'requester_id cannot be null in appointments');
select col_not_null('public', 'community_posts', 'author_id', 'author_id cannot be null in community_posts');
select col_not_null('public', 'community_posts', 'moderation_status', 'moderation_status cannot be null in community_posts');
select col_not_null('public', 'community_posts', 'likes_count', 'likes_count cannot be null in community_posts');
select col_not_null('public', 'community_posts', 'comments_count', 'comments_count cannot be null in community_posts');
select col_not_null('public', 'payments', 'amount', 'amount cannot be null in payments');

select * from finish();
rollback;
