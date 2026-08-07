-- Revert schemas/object_tree_public/procedures/get_object_at_path from pg

BEGIN;

DROP FUNCTION object_tree_public.get_object_at_path(uuid, uuid, text[], text);

COMMIT;
