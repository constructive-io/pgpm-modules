-- Revert schemas/supabase_integration/schema from pg

BEGIN;

DROP SCHEMA supabase_integration;

COMMIT;
