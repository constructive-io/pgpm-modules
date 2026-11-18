-- Revert schemas/function_resolution/procedures/compute_entry from pg

BEGIN;

DROP FUNCTION function_resolution.compute_entry(uuid);

COMMIT;
