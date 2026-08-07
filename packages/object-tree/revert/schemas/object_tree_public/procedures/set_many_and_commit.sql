-- Revert schemas/object_tree_public/procedures/set_many_and_commit from pg

BEGIN;

DROP FUNCTION object_tree_public.set_many_and_commit(uuid, uuid, text, jsonb, text);

COMMIT;
