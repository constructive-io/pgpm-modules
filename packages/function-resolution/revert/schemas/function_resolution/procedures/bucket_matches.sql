-- Revert schemas/function_resolution/procedures/bucket_matches from pg

BEGIN;

DROP FUNCTION function_resolution.bucket_matches(uuid, text, uuid, text[], text);

COMMIT;
