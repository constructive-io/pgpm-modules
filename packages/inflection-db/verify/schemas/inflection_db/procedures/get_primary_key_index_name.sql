-- Verify schemas/inflection_db/procedures/get_primary_key_index_name  on pg

BEGIN;

SELECT verify_function ('inflection_db.get_primary_key_index_name');

ROLLBACK;
