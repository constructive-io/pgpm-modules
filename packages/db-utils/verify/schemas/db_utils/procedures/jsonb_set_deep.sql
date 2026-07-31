-- Verify schemas/db_utils/procedures/jsonb_set_deep on pg

BEGIN;

SELECT verify_function('db_utils.jsonb_set_deep');

ROLLBACK;
