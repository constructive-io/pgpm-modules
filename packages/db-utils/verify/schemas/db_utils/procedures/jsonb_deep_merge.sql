-- Verify schemas/db_utils/procedures/jsonb_deep_merge on pg

BEGIN;

SELECT verify_function('db_utils.jsonb_deep_merge');

ROLLBACK;
