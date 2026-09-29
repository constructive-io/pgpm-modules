-- Verify schemas/db_utils/procedures/get_column_smart_comment  on pg

BEGIN;

SELECT assert_function('db_utils.get_column_smart_comment(text, text, text)'::regprocedure);

ROLLBACK;
