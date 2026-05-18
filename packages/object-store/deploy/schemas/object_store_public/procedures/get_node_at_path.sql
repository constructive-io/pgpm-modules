-- Deploy schemas/object_store_public/procedures/get_node_at_path to pg

-- requires: schemas/object_store_public/schema
-- requires: schemas/object_store_public/tables/object/table
-- requires: schemas/object_store_utils/procedures/array_index_of
-- requires: schemas/object_store_utils/procedures/array_shift

BEGIN;

CREATE FUNCTION object_store_public.get_node_at_path( s_id uuid, id uuid, path text[]=ARRAY[]::text[] )
    RETURNS object_store_public.object
AS $$ 

DECLARE
  _path text[] = path;
  _obj object_store_public.object;

  i int;
  pos int;
  curpath text;

  _node text;
  _node_id uuid;
BEGIN

  SELECT * FROM object_store_public.object o
    WHERE o.id = get_node_at_path.id
    AND o.scope_id = s_id
  INTO _obj;

  IF (array_length(_path, 1) > 0) THEN
    FOR i IN SELECT * FROM generate_subscripts(_path, 1) g(i)
    LOOP

      curpath = _path[1];
      pos = object_store_utils.array_index_of(_obj.ktree, curpath);

      IF (pos > 0) THEN
        _node_id = _obj.kids[pos];
        SELECT * FROM object_store_public.object o
          WHERE o.id = _node_id
          AND o.scope_id = s_id
        INTO _obj;
        -- TODO check if 1 is correct
        -- NOTE is only NULL, not 0 for whatver reason if you need to use that...
        -- IF (array_length(_path, 1) IS NULL) THEN
        IF (array_length(_path, 1) = 1) THEN
            RETURN _obj;
        END IF;

      END IF;
      _path = object_store_utils.array_shift(_path);
    END LOOP;
  ELSE
    RETURN _obj;
  END IF;

  RETURN NULL;
END;
$$
LANGUAGE plpgsql STABLE;

COMMIT;
