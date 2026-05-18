-- Deploy schemas/object_store_utils/procedures/array_utils to pg

-- requires: schemas/object_store_utils/schema

BEGIN;

CREATE FUNCTION object_store_utils.zip_arrays(
  a text[],
  b anyarray
) returns jsonb as $$
DECLARE
  obj jsonb = '{}'::jsonb;
  i int;
BEGIN
	IF (cardinality(a) != cardinality(b)) THEN 
		RAISE EXCEPTION 'cannot zip arrays of different cardinality';
	END IF;
	
	FOR i IN
	SELECT * FROM generate_series(1, cardinality(a))
	LOOP
		obj = jsonb_set(obj, ARRAY[a[i]]::text[], to_jsonb( (b[i]::text) ) );
	END LOOP;
	RETURN obj;
END;
$$
LANGUAGE 'plpgsql' IMMUTABLE;

CREATE FUNCTION object_store_utils.unzip_obj_to_ktree_and_kids(
  obj jsonb
) returns table ( ktree text[], kids uuid[] ) as $$
DECLARE
  key text;
  value text;
BEGIN
	FOR key, value IN 
	SELECT * FROM jsonb_each_text(obj)
	LOOP
		ktree = array_append(ktree, key);
  	kids = array_append(kids, value::uuid);
	END LOOP;
	
	RETURN next;
END;
$$
LANGUAGE 'plpgsql' IMMUTABLE;

COMMIT;
