-- Verify schemas/inflection_db/procedures/get_table_singular_name on pg

BEGIN;

SELECT verify_function ('inflection_db.get_table_singular_name');

ROLLBACK;
