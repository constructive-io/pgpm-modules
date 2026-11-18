-- Revert schemas/function_resolution/procedures/storage_cors_resync_candidates from pg

BEGIN;

DROP FUNCTION function_resolution.storage_cors_resync_candidates(uuid);

COMMIT;
