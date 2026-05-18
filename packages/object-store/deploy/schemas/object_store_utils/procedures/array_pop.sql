-- Deploy schemas/object_store_utils/procedures/array_pop to pg

-- requires: schemas/object_store_utils/schema

BEGIN;

CREATE FUNCTION object_store_utils.array_pop( srcarr anyarray )
    RETURNS SETOF anyarray
AS $$ 
SELECT ARRAY (
 SELECT UNNEST(srcarr) LIMIT (
  SELECT array_upper(srcarr, 1) - 1
 )
)
$$
LANGUAGE sql IMMUTABLE;

COMMIT;
