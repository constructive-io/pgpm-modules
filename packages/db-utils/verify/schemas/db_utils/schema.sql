-- Verify schemas/db_utils/schema  on pg

BEGIN;

SELECT verify_schema ('db_utils');

ROLLBACK;
