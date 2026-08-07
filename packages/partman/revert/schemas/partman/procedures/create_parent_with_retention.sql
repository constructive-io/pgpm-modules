-- Revert schemas/partman/procedures/create_parent_with_retention from pg

BEGIN;

DROP FUNCTION partman.create_parent_with_retention(text, text, text, text, int4, text, bool);

COMMIT;
