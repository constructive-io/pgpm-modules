-- Revert schemas/function_resolution/procedures/bound_bucket_id from pg

BEGIN;

DROP FUNCTION function_resolution.bound_bucket_id(uuid, text, uuid, uuid, text);

COMMIT;
