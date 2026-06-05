-- Verify schemas/inflection_db/procedures/get_index_name on pg

BEGIN;

SELECT verify_function ('inflection_db.get_index_name');

ROLLBACK;
