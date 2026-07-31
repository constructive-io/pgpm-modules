-- Verify schemas/db_utils/procedures/get_column_smart_comment  on pg

BEGIN;

SELECT verify_function ('db_utils.get_column_smart_comment');

ROLLBACK;
