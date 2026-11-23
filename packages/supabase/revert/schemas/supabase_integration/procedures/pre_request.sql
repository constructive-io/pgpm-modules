-- Revert schemas/supabase_integration/procedures/pre_request from pg

BEGIN;

DROP FUNCTION supabase_integration.pre_request();

COMMIT;
