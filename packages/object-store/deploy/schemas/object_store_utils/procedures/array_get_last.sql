-- Deploy schemas/object_store_utils/procedures/array_get_last to pg

-- requires: schemas/object_store_utils/schema

BEGIN;

CREATE FUNCTION object_store_utils.array_get_last(
  arr anyarray
) returns anyelement as $$
  SELECT arr[array_length(arr, 1)];
$$
LANGUAGE 'sql' IMMUTABLE;

GRANT EXECUTE ON FUNCTION object_store_utils.array_get_last(arr anyarray) TO authenticated;

COMMIT;
