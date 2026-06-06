-- Verify schemas/inflection_db/procedures/get_table_name  on pg

BEGIN;

SELECT verify_function ('inflection_db.get_table_name');

ROLLBACK;
