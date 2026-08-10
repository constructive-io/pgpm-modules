-- Revert schemas/function_resolution/procedures/staging_bucket_tag from pg

BEGIN;

DROP FUNCTION function_resolution.staging_bucket_tag();

COMMIT;
