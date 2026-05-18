-- Deploy schemas/object_store_utils/procedures/array_shift to pg

-- requires: schemas/object_store_utils/schema

BEGIN;

CREATE FUNCTION object_store_utils.array_shift( srcarr anyarray )
    RETURNS SETOF anyarray
AS $$ 
SELECT srcarr[2:array_length(srcarr, 1)]
$$
LANGUAGE sql IMMUTABLE;

COMMIT;
