-- Deploy schemas/object_store_private/procedures/node_hash_uuid to pg

-- requires: schemas/object_store_private/schema
-- requires: schemas/object_store_public/tables/object/table
-- requires: schemas/object_store_private/procedures/object_hash_uuid

BEGIN;

-- The content hash of a node from its hashed fields alone, without a row to
-- read it off. A set-based writer needs the ids of the rows it is about to
-- insert in order to name them in their parents' child maps, which the
-- BEFORE INSERT trigger's RETURNING id can only give one row at a time. The
-- record is built by name so this stays correct if the table gains a column.
CREATE FUNCTION object_store_private.node_hash_uuid (data jsonb, kids uuid[], ktree text[])
  RETURNS uuid
  AS $$
  SELECT
    object_store_public.object_hash_uuid (jsonb_populate_record(NULL::object_store_public.object, jsonb_build_object('data', node_hash_uuid.data, 'kids', to_jsonb(node_hash_uuid.kids), 'ktree', to_jsonb(node_hash_uuid.ktree))));
$$
LANGUAGE sql
IMMUTABLE;

COMMIT;
