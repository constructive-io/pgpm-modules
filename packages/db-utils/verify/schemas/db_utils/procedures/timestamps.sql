-- Verify schemas/db_utils/procedures/timestamps on pg

BEGIN;

SELECT assert_function('db_utils.timestamps(text, text)'::regprocedure);

ROLLBACK;
