-- Verify schemas/db_utils/procedures/jsonb_set_deep on pg

BEGIN;

SELECT assert_function('db_utils.jsonb_set_deep(jsonb, text[], jsonb)'::regprocedure);

ROLLBACK;
