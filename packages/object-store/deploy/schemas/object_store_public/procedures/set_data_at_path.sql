-- Deploy schemas/object_store_public/procedures/set_data_at_path to pg

-- requires: schemas/object_store_public/schema
-- requires: schemas/object_store_public/tables/object/table
-- requires: schemas/object_store_public/procedures/get_node_at_path
-- requires: schemas/object_store_public/procedures/insert_node_at_path

BEGIN;

CREATE FUNCTION object_store_public.set_data_at_path(s_id uuid, root uuid, path text[], data jsonb)
  RETURNS uuid
  AS $$
DECLARE
  _node object_store_public.object;
  _kids uuid[] = ARRAY[]::uuid[];
  _ktree text[] = ARRAY[]::text[];
BEGIN
  -- Look up existing node to preserve its children
  SELECT * FROM object_store_public.get_node_at_path(s_id, root, path)
  INTO _node;

  IF (_node.id IS NOT NULL) THEN
    _kids = _node.kids;
    _ktree = _node.ktree;
  END IF;

  -- Delegate to insert_node_at_path with preserved children
  RETURN object_store_public.insert_node_at_path(
    s_id, root, path, data, _kids, _ktree
  );
END;
$$
LANGUAGE plpgsql
VOLATILE;

COMMIT;
