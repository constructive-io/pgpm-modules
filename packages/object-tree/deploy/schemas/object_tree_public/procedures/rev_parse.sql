-- Deploy schemas/object_tree_public/procedures/rev_parse to pg

-- requires: schemas/object_tree_public/schema
-- requires: schemas/object_tree_public/tables/commit/table
-- requires: schemas/object_tree_public/tables/ref/table

BEGIN;

CREATE FUNCTION object_tree_public.rev_parse(
  s_id uuid,
  store_id uuid,
  refname text = 'main'
) returns uuid as $$
DECLARE
  tree_id uuid;
  commit_id uuid;
BEGIN

  SELECT r.commit_id FROM
    object_tree_public.ref r
      WHERE r.scope_id = s_id
      AND r.store_id = rev_parse.store_id
      AND r.name = refname
  INTO commit_id;

  IF (NOT FOUND) THEN
    RAISE EXCEPTION 'NOT_FOUND';
  END IF;

  SELECT c.tree_id FROM
    object_tree_public.commit c
      WHERE c.scope_id = s_id
      AND c.store_id = rev_parse.store_id
      AND c.id = commit_id
  INTO tree_id;

  IF (NOT FOUND) THEN
    RAISE EXCEPTION 'NOT_FOUND';
  END IF;

  RETURN tree_id;

END;
$$
LANGUAGE 'plpgsql' STABLE;

COMMIT;
