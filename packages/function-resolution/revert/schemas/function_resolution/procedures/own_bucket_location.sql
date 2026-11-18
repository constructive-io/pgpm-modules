-- Revert schemas/function_resolution/procedures/own_bucket_location from pg

BEGIN;

DROP FUNCTION function_resolution.own_bucket_location(uuid);

COMMIT;
