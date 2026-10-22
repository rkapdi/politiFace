-- The service role bypasses RLS but NOT schema ACLs. Without these grants
-- any service-role write that fires a trigger touching the app schema
-- fails (found in production E2E: publishing a question via the service
-- role hit 403 because the publish trigger reads app.question_keys).
-- Client roles (anon, authenticated) stay fully revoked from app.

grant usage on schema app to service_role;
grant select, insert, update, delete on all tables in schema app to service_role;
grant execute on all functions in schema app to service_role;

alter default privileges in schema app
  grant select, insert, update, delete on tables to service_role;
alter default privileges in schema app
  grant execute on functions to service_role;
