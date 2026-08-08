-- Revert schemas/function_resolution/procedures/default_bucket_tag from pg

BEGIN;

DROP FUNCTION function_resolution.default_bucket_tag(boolean);

COMMIT;
