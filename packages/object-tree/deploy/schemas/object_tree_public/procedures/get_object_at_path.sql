-- Deploy schemas/object_tree_public/procedures/get_object_at_path to pg

-- requires: schemas/object_tree_public/schema
-- requires: schemas/object_tree_public/tables/commit/table
-- requires: schemas/object_tree_public/tables/ref/table

-- requires: schemas/object_tree_public/procedures/rev_parse 

BEGIN;


CREATE FUNCTION object_tree_public.get_object_at_path(
  s_id uuid,
  store_id uuid,
  path text[],
  refname text = 'main'
) returns object_store_public.object as $$
DECLARE
  tree_id uuid;
  obj object_store_public.object;
BEGIN
  tree_id = object_tree_public.rev_parse(s_id, store_id, refname);
  SELECT * FROM object_store_public.get_node_at_path(s_id, tree_id, path)
  INTO obj;
  RETURN obj;
END;
$$
LANGUAGE 'plpgsql' STABLE;

COMMIT;
