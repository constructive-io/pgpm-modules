-- Revert schemas/partman/procedures/create_parent_by_id from pg

BEGIN;

DROP FUNCTION partman.create_parent_by_id(uuid, text, text, text, int4, text, bool);

COMMIT;
