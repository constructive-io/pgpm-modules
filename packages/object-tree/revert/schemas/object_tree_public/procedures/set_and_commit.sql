-- Revert schemas/object_tree_public/procedures/set_and_commit from pg

BEGIN;

DROP FUNCTION object_tree_public.set_and_commit;

COMMIT;
