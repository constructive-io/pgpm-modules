-- Revert schemas/function_resolution/procedures/frame_default_bucket from pg

BEGIN;

DROP FUNCTION function_resolution.frame_default_bucket(uuid, text, uuid, boolean, text);

COMMIT;
