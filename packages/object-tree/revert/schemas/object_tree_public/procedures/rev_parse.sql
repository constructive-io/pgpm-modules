-- Revert schemas/object_tree_public/procedures/rev_parse from pg

BEGIN;

DROP FUNCTION object_tree_public.rev_parse(uuid, uuid, text);

COMMIT;
