-- Deploy schemas/object_store_private/procedures/object_hash_uuid to pg

-- requires: schemas/object_store_private/schema
-- requires: schemas/object_store_public/tables/object/table

BEGIN;

CREATE FUNCTION object_store_public.object_hash_uuid(
  obj object_store_public.object
) returns uuid as $$
DECLARE
  _cash jsonb = '{}'::jsonb;
  hash1 uuid;
  hash2 uuid;
BEGIN
  IF (obj.data IS NOT NULL) THEN
    hash1 = uuid_generate_v5 (uuid_ns_url (), obj.data::text);
  END IF;

  IF (obj.kids IS NOT NULL AND obj.ktree IS NOT NULL) THEN
    -- TODO for future feature, this is where you can put an IF statement to allow order. Not sure where to put the meta data for allowing order, but could be as simple as a bool field on all objects called "order"
    -- _cash is the children hash, it is ordered using jsonb lexically
    _cash =  json_object(obj.ktree::text[], obj.kids::text[]);
    hash2 = uuid_generate_v5 (uuid_ns_url (), _cash::text);
  END IF;

  RETURN uuid_generate_v5 (uuid_ns_url (), concat(hash1, hash2)::text);
END;
$$
LANGUAGE 'plpgsql' STABLE;

COMMIT;
