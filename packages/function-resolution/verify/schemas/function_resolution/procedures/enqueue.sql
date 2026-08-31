-- Verify schemas/function_resolution/procedures/enqueue  on pg

BEGIN;

SELECT assert_function('function_resolution.enqueue(text, json, text, uuid, uuid, text, text, text, timestamptz, int4, int4, uuid, text, bool, text, uuid, uuid, uuid, uuid)'::regprocedure);

ROLLBACK;
