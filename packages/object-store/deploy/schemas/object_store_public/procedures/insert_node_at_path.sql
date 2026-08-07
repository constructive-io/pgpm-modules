-- Deploy schemas/object_store_public/procedures/insert_node_at_path to pg

-- requires: schemas/object_store_public/schema
-- requires: schemas/object_store_public/tables/object/table
-- requires: schemas/object_store_utils/procedures/array_index_of
-- requires: schemas/object_store_utils/procedures/array_utils

BEGIN;

-- One-element wrapper over object_store_public.insert_nodes_at_paths, which is
-- created later in the plan and resolved at call time. Identical signature,
-- identical result: batching is no longer a mode, only how much a caller
-- passes in.
CREATE FUNCTION object_store_public.insert_node_at_path (s_id uuid, root uuid, path text[], data jsonb, kids uuid[], ktree text[])
  RETURNS uuid
  AS $$
BEGIN
  RETURN object_store_public.insert_nodes_at_paths (s_id := insert_node_at_path.s_id, root := insert_node_at_path.root, paths := jsonb_build_array(coalesce(to_jsonb(insert_node_at_path.path), '[]'::jsonb)), datas := ARRAY[insert_node_at_path.data]::jsonb[], kids_list := jsonb_build_array(to_jsonb(insert_node_at_path.kids)), ktree_list := jsonb_build_array(to_jsonb(insert_node_at_path.ktree)));
END;
$$
LANGUAGE plpgsql
VOLATILE;

COMMIT;
