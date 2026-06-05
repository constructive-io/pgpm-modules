-- Verify schemas/inflection_db/procedures/get_schema_name on pg

BEGIN;

SELECT verify_function ('inflection_db.get_schema_name');

ROLLBACK;
