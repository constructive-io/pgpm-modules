-- Deploy schemas/object_store_utils/procedures/array_index_of to pg

-- requires: schemas/object_store_utils/schema

BEGIN;

CREATE FUNCTION object_store_utils.array_index_of( arr anyarray, el anyelement )
    RETURNS int
AS $$ 
DECLARE
  val int = -1;
  i int;
BEGIN
  FOR i IN SELECT * FROM generate_subscripts(arr, 1) g(i)
  LOOP
    IF (el = arr[i]) THEN
      val = i;
      RETURN val;
    END IF;
  END LOOP;
  RETURN val;
END
$$
LANGUAGE plpgsql IMMUTABLE;

COMMIT;
