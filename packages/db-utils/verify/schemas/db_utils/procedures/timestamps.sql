-- Verify schemas/db_utils/procedures/timestamps on pg

BEGIN;

SELECT verify_function('db_utils.timestamps');

ROLLBACK;
