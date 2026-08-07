-- Revert schemas/partman/procedures/remove_parent_by_id from pg

BEGIN;

DROP FUNCTION partman.remove_parent_by_id(uuid);

COMMIT;
