-- Revert schemas/function_resolution/procedures/frame_candidates from pg

BEGIN;

DROP FUNCTION function_resolution.frame_candidates(uuid, text, uuid);

COMMIT;
