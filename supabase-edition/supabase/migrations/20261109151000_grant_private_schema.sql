-- 14 — Grant usage on schema private so RLS policies can invoke helper functions.

grant usage on schema private to anon, authenticated, service_role;
grant execute on all functions in schema private to anon, authenticated, service_role;
alter default privileges in schema private grant execute on functions to anon, authenticated, service_role;
