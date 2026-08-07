-- Deploy schemas/object_store_utils/procedures/array_utils to pg

-- requires: schemas/object_store_utils/schema

BEGIN;

CREATE FUNCTION object_store_utils.zip_arrays(
  a text[],
  b anyarray
) returns jsonb as $$
DECLARE
  obj jsonb;
BEGIN
	IF (cardinality(a) != cardinality(b)) THEN 
		RAISE EXCEPTION 'cannot zip arrays of different cardinality';
	END IF;

	-- A null key is a hard error and a null value makes the whole object
	-- null, as the equivalent per-element jsonb_set chain did (a null path
	-- element raises; to_jsonb and jsonb_set are strict).
	IF EXISTS (
		SELECT 1 FROM generate_series(1, cardinality(a)) AS i WHERE a[i] IS NULL
	) THEN
		RAISE EXCEPTION 'cannot zip arrays with a null key';
	END IF;

	IF EXISTS (
		SELECT 1 FROM generate_series(1, cardinality(a)) AS i WHERE b[i] IS NULL
	) THEN
		RETURN NULL;
	END IF;

	-- Later duplicate keys win, matching the assignment order of the loop.
	SELECT coalesce(jsonb_object_agg(a[i], to_jsonb(b[i]::text) ORDER BY i), '{}'::jsonb)
	  INTO obj
	  FROM generate_series(1, cardinality(a)) AS i;

	RETURN obj;
END;
$$
LANGUAGE 'plpgsql' IMMUTABLE;

CREATE FUNCTION object_store_utils.unzip_obj_to_ktree_and_kids(
  obj jsonb
) returns table ( ktree text[], kids uuid[] ) as $$
BEGIN
	-- Aggregated in jsonb_each_text's own emission order, the order the
	-- per-key append loop produced; both arrays feed the node hash.
	SELECT array_agg(e.key), array_agg(e.value::uuid)
	  INTO ktree, kids
	  FROM jsonb_each_text(obj) AS e;

	RETURN next;
END;
$$
LANGUAGE 'plpgsql' IMMUTABLE;

COMMIT;
