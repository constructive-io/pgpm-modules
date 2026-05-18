-- Deploy schemas/object_store_public/procedures/update_node_at_path to pg
-- requires: schemas/object_store_public/schema
-- requires: schemas/object_store_public/tables/object/table
-- requires: schemas/object_store_public/procedures/insert_node_at_path 


BEGIN;
CREATE FUNCTION object_store_public.update_node_at_path (
  s_id uuid,
  root uuid,
  path text[],
  data jsonb,
  -- TODO you need to test if you are actually using this!
  -- TODO need to double check circular refs!
  kids uuid[],
  ktree text[]
)
  RETURNS uuid
  AS $$
BEGIN
  RETURN object_store_public.insert_node_at_path(s_id, root, path, data, kids, ktree);
END;
$$
LANGUAGE plpgsql
VOLATILE;
COMMIT;
