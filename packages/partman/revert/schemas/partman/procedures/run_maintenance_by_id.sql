-- Revert schemas/partman/procedures/run_maintenance_by_id from pg

BEGIN;

DROP FUNCTION partman.run_maintenance_by_id(uuid, bool);

COMMIT;
