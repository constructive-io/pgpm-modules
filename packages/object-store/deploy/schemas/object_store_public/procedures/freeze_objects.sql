-- Deploy schemas/object_store_public/procedures/freeze_objects to pg

-- requires: schemas/object_store_public/schema
-- requires: schemas/object_store_public/tables/object/table

BEGIN;

CREATE FUNCTION object_store_public.freeze_objects(
  s_id uuid, id uuid
) returns void as $$
BEGIN

WITH RECURSIVE hierarchy AS (
    SELECT
        *
    FROM
        object_store_public.object o
    WHERE
        o.id = freeze_objects.id AND o.scope_id=s_id
    UNION
    SELECT
        object.*
    FROM
        object_store_public.object AS object
        JOIN hierarchy a ON (object.id = ANY (a.kids) AND object.scope_id=a.scope_id))

UPDATE object_store_public.object o
  SET frzn = TRUE
FROM hierarchy
  WHERE hierarchy.id = o.id;

END;
$$
LANGUAGE 'plpgsql' VOLATILE;

COMMIT;
