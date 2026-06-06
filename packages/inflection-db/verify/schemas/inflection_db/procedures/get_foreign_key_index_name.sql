-- Verify schemas/inflection_db/procedures/get_foreign_key_index_name  on pg

BEGIN;

SELECT verify_function ('inflection_db.get_foreign_key_index_name');

ROLLBACK;
