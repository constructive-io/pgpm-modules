-- Revert schemas/inflection_db/procedures/get_primary_key_index_name from pg

BEGIN;

DROP FUNCTION inflection_db.get_primary_key_index_name;

COMMIT;
