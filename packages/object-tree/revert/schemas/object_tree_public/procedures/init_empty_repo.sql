-- Revert schemas/object_tree_public/procedures/init_empty_repo from pg

BEGIN;

DROP FUNCTION object_tree_public.init_empty_repo;

COMMIT;
