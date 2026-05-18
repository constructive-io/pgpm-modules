-- Deploy schemas/object_store_public/procedures/get_all_objects_from_root to pg

-- requires: schemas/object_store_public/schema
-- requires: schemas/object_store_public/tables/object/table 


BEGIN;

CREATE FUNCTION object_store_public.get_all_objects_from_root( s_id uuid, id uuid )
    RETURNS SETOF object_store_public.object
AS $$ WITH RECURSIVE hierarchy AS (
    SELECT
        *
    FROM
        object_store_public.object o
    WHERE
        o.id = get_all_objects_from_root.id AND o.scope_id=s_id
    UNION
    SELECT
        object.*
    FROM
        object_store_public.object AS object
        JOIN hierarchy a ON (object.id = ANY (a.kids) AND object.scope_id=a.scope_id))
SELECT
    *
FROM
    hierarchy;
$$
LANGUAGE sql STABLE;

COMMIT;
