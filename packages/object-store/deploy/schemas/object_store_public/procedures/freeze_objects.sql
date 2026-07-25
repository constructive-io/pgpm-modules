-- Deploy schemas/object_store_public/procedures/freeze_objects to pg

-- requires: schemas/object_store_public/schema
-- requires: schemas/object_store_public/tables/object/table

BEGIN;

CREATE FUNCTION object_store_public.freeze_objects(
  s_id uuid, id uuid
) returns void as $$
BEGIN

-- Unnest kids so each recursion step joins through the (id, scope_id)
-- primary key instead of scanning the whole table per level.
WITH RECURSIVE hierarchy AS (
    SELECT
        o.id, o.scope_id, o.kids
    FROM
        object_store_public.object o
    WHERE
        o.id = freeze_objects.id AND o.scope_id=s_id
    UNION
    SELECT
        object.id, object.scope_id, object.kids
    FROM
        hierarchy a
        CROSS JOIN LATERAL unnest(a.kids) AS kid(id)
        JOIN object_store_public.object AS object
          ON (object.id = kid.id AND object.scope_id=a.scope_id))

UPDATE object_store_public.object o
  SET frzn = TRUE
FROM hierarchy
  WHERE hierarchy.id = o.id AND hierarchy.scope_id = o.scope_id;

END;
$$
LANGUAGE 'plpgsql' VOLATILE;

COMMIT;
