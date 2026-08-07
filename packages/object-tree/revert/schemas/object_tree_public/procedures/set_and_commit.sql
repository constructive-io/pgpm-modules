-- Revert schemas/object_tree_public/procedures/set_and_commit from pg

BEGIN;

DROP FUNCTION object_tree_public.set_props_and_commit(uuid, uuid, text, text[], jsonb);
DROP FUNCTION object_tree_public.set_and_commit(uuid, uuid, text, text[], jsonb, uuid[], text[]);

COMMIT;
