-- Verify schemas/inflection_db/schema on pg

BEGIN;

SELECT verify_schema ('inflection_db');

ROLLBACK;
