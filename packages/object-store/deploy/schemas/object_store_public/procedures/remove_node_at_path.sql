-- Deploy schemas/object_store_public/procedures/remove_node_at_path to pg

-- requires: schemas/object_store_public/schema
-- requires: schemas/object_store_public/tables/object/table
-- requires: schemas/object_store_utils/procedures/array_pop
-- requires: schemas/object_store_public/procedures/get_node_at_path
-- requires: schemas/object_store_utils/procedures/array_get_last 
-- requires: schemas/object_store_utils/procedures/array_utils 

-- requires: schemas/object_store_public/procedures/insert_node_at_path 

BEGIN;

CREATE FUNCTION object_store_public.remove_node_at_path(
  s_id uuid,
  root uuid,
  path text[]
) returns uuid as $$
DECLARE
  _node object_store_public.object;
  _parent object_store_public.object;

  _newparent_id uuid;
  _path text[] = path;

  child_to_remove text;

  vkids uuid[];
  vktree text[];
  children_hash jsonb;
BEGIN

    IF (cardinality(path) < 1) THEN 
      RAISE EXCEPTION 'cannot remove root node';
    END IF;


  -- STEP 1
  -- check if it exists
  SELECT
    *
  FROM
    object_store_public.get_node_at_path
     (s_id, root, path)
  INTO _node;

  -- NOTE cannot use FOUND/NOT FOUND here
  IF (_node.id IS NULL) THEN
    RETURN root;
  END IF;

  -- STEP 2(a) get child to remove
  child_to_remove = object_store_utils.array_get_last(_path);

  -- STEP 2(b) get parent
  _path = object_store_utils.array_pop(_path);

  SELECT
    *
  FROM
    object_store_public.get_node_at_path
    (s_id, root, _path)
  INTO _parent;

  children_hash = object_store_utils.zip_arrays(
    _parent.ktree,
    _parent.kids
  );

  children_hash = children_hash - child_to_remove;

  SELECT h.ktree, h.kids FROM object_store_utils.unzip_obj_to_ktree_and_kids(
    children_hash
  ) h INTO vktree, vkids;


  -- STEP 3 update new parent
  RETURN object_store_public.insert_node_at_path(
    s_id,
    root,
    _path,
    _parent.data,
    vkids,
    vktree
  );

END;
$$
LANGUAGE 'plpgsql' VOLATILE;

COMMIT;
